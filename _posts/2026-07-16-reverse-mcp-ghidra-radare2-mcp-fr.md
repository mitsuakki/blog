---
layout: post
title: "reverse-mcp : connecter Ghidra et radare2 aux agents IA"
tags: [mcp, ghidra, radare2, docker, ai-agents, tooling]
lang: fr
permalink: /fr/reverse-mcp-wiring-ghidra-radare2-into-ai-agents/
---

J'en ai eu marre de changer de fenêtre tout le temps. Désassembler dans un
terminal, décompiler dans un autre, grep les cross-références ailleurs, puis
lancer un shell pour `strings` ou `checksec` ou je ne sais quoi. Chaque outil
a son propre CLI, son propre format de sortie, ses propres emmerdes.

Alors j'ai construit [reverse-mcp](https://github.com/mitsuakki/reverse-mcp).
Un seul conteneur Docker. Ghidra, radare2, angr et un shell complet. Le tout
exposé comme serveurs MCP derrière un seul endpoint HTTP. Claude Code s'y
connecte et d'un coup chaque outil de reverse devient un appel de fonction.

## Comment ça marche

```
┌──────────────┐     HTTP      ┌──────────────┐
│  Claude Code │ ────────────→ │   Passerelle │
│  (client MCP)│               │   :3100      │
└──────────────┘               └──┬───┬───┬──┘
                                  │   │   │
                    ┌─────────────┘   │   └─────────────┐
                    ▼                 ▼                 ▼
              ┌──────────┐   ┌──────────────┐   ┌──────────┐
              │  r2mcp   │   │  Ghidra      │   │  shell   │
              │  (r2pm)  │   │  headless    │   │  mcp.py  │
              └──────────┘   │  :8089       │   └──────────┘
                             └──────────────┘
```

### La passerelle

Un script Python, `gateway.py`, qui écoute sur le port 3100. Il lance chaque
back-end MCP comme un processus enfant, puis combine leurs outils dans un seul
namespace.

Chaque back-end a un préfixe pour éviter les collisions :

| Préfixe | Back-end | Ce que ça donne |
|---------|----------|-----------------|
| `r2__` | radare2 (r2mcp) | désassembler, décompiler avec r2ghidra, hexdump, xrefs, émulation |
| `ghidra__` | Ghidra headless :8089 | gestion de projet, import, auto-analyse, 200+ outils dont décompilateur, patcher, BinDiff, débogueur |
| `shell__` | shell-mcp | n'importe quelle commande : strings, checksec, ent, gdb, lldb, apktool, tout |
| `angr__` | angr MCP | CFG, exécution symbolique, VFG, analyse de dépendances |

Si un back-end plante au démarrage, la passerelle le logue et continue. Les
outils de ce back-end n'apparaissent juste pas dans le client. Pas d'effet
domino.

### Le truc Ghidra

Les outils Ghidra sont en deux groupes. Les outils statiques (import_file,
list_instances, create_project) sont toujours disponibles. Les outils d'instance
(decompile, rename, xrefs, patch) n'apparaissent qu'après avoir chargé un
programme dans une instance Ghidra.

Le flux : importer un fichier, connexion auto, la passerelle récupère le schéma
de l'instance, et les 200+ outils se débloquent. C'est un peu bancal mais ça
tourne.

## Pour démarrer

```bash
git clone https://github.com/mitsuakki/reverse-mcp
cd reverse-mcp
docker compose build
docker compose up -d
```

Balance tes binaires dans `./workspace/`. Ils apparaissent dans `/workspace`
à l'intérieur du conteneur.

Config client MCP pour Claude Code :

```json
{
  "mcpServers": {
    "reverse-mcp": {
      "type": "http",
      "url": "http://localhost:3100/mcp"
    }
  }
}
```

## Les agents livrés avec

Cinq agents Claude Code spécialisés dans `.claude/agents/`. Chacun fait un
truc :

| Agent | Modèle | Rôle |
|-------|--------|------|
| `binary-triage` | Haiku | Premier regard : radare2 et shell, rapide et léger |
| `ghidra-importer` | Sonnet | Import dans Ghidra, lance l'auto-analyse |
| `ghidra-analyst` | Sonnet | RE statique : décompiler, suivre les xrefs, renommer |
| `ghidra-debugger` | Sonnet | Dynamique : attacher le débogueur, breakpoints, trace |
| `re-orchestrator` | Opus | Pipeline complet du triage au rapport final |

L'orchestrateur les enchaîne. Le triage part d'abord pour une évaluation de
surface. Si le binaire a l'air intéressant, il passe la main au pipeline
Ghidra. Je l'ai écrit comme ça parce que parfois tu veux juste un coup d'œil
rapide sans lancer l'analyse lourde.

## Ce qu'il y a dedans

Tout vit dans le conteneur. Pas de GUI, pas de VNC. Terminal ou MCP uniquement.

radare2 avec le décompilateur r2ghidra. Ghidra headless plus analyzeHeadless
et un script load-ghidra.sh. BinDiff en CLI. angr, pwntools, ropper, ROPgadget,
capstone, unicorn, keystone, z3, LIEF, r2pipe. Pour le fuzzing : AFL++ avec le
mode QEMU, honggfuzz. Pour Android : apktool, jadx, Frida, objection. Le
standard : gdb, lldb, strace, ltrace, nasm, objdump, patchelf, gcc, clang.

En gros tout ce que j'utilise au quotidien, dans un conteneur.

## Note sécurité

Pas d'authentification sur la passerelle. C'est un outil de dev local, pas un
truc à exposer sur internet. Lance les binaires douteux dans une VM. Le fichier
docker compose ajoute `SYS_PTRACE` et vire seccomp pour gdb et AFL.

## Builds

GitHub Actions CI à chaque push et PR. Les tags versionnés poussent les images
sur GHCR. Licence MIT, fais ce que tu veux avec.

## La suite

Je veux ajouter un pont Binary Ninja MCP en utilisant le mode headless de BN.
Et peut-être un pont Frida pour le reverse mobile. Et un moyen d'importer les
CFG Ghidra dans angr pour de l'analyse hybride.

Je vais écrire un article sur comment construire un serveur MCP perso pour un
outil de reverse. Le pattern est simple : tu subprocess l'outil, tu parse la
sortie, tu exposes des outils MCP typés avec des schémas JSON. Moins de 200
lignes de Python pour un pont désassembleur basique.
