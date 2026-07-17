---
layout: post
title: "Créer un plugin de désobfuscation pour Binary Ninja en C++"
tags: [binaryninja, c++, deobfuscation, plugin-dev, deobfninja]
lang: fr
permalink: /fr/building-binary-ninja-deobfuscation-plugin/
---

L'API C++ de Binary Ninja, c'est un peu le trésor caché du truc. Tout le monde
passe par l'API Python parce que c'est simple. Mais quand tu fais de la
désobfuscation, que tu itères sur chaque instruction d'une fonction, que tu
cherches des patterns contre des signatures d'obfuscateurs, que tu réécris
l'IL... Python crève. Surtout sur des vrais binaires.

Du coup j'ai commencé [deobfninja](https://github.com/mitsuakki/deobfninja) en
C++. Voilà ce que j'en ai tiré.

## Pourquoi pas Python

Alors oui, l'API Python est super pour des scripts rapides. Je l'utilise encore
pour de l'analyse ponctuelle. Mais la désobfuscation fait partie de ces problèmes
où tu sens chaque milliseconde de surcoût de l'interpréteur.

En C++ t'as accès direct à l'IL de BN. Pas de GIL, donc tu parallélises sur les
fonctions. Manipulation de buffers sans copie pour le pattern matching. Sur un
binaire de 5 Mo avec une obfuscation modérée, le plugin C++ tourne en moins d'une
seconde. L'équivalent Python prenait 42 secondes. C'est pas une optimisation,
c'est la différence entre "utilisable" et "je vais me faire un café".

## L'architecture du plugin

```
┌──────────────────────────────────┐
│         Binary Ninja             │
│  ┌────────────────────────────┐  │
│  │    Plugin Loader           │  │
│  └──────────┬─────────────────┘  │
│             │                    │
│  ┌──────────▼─────────────────┐  │
│  │  coeur deobfninja          │  │
│  │  ┌───────────┐ ┌────────┐  │  │
│  │  │ Pattern   │ │ IL     │  │  │
│  │  │ Matcher   │ │ Rewrite│  │  │
│  │  └───────────┘ └────────┘  │  │
│  │  ┌───────────┐ ┌────────┐  │  │
│  │  │ Moteur    │ │ Métri- │  │  │
│  │  │ Recettes  │ │ ques   │  │  │
│  │  └───────────┘ └────────┘  │  │
│  └────────────────────────────┘  │
└──────────────────────────────────┘
```

### Pattern matching sur le MLIL

Je bosse sur le Medium Level IL de BN, pas sur l'assembleur brut. Le MLIL est
assez haut niveau pour que les patterns survivent aux changements de compilateur,
mais assez bas pour que les astuces d'obfuscation restent visibles.

Chaque technique d'obfuscation s'enregistre comme un détecteur :

{% highlight cpp %}
class ObfuscationDetector {
public:
    virtual ~ObfuscationDetector() = default;
    virtual bool match(mlil_inst inst) = 0;
    virtual mlil_inst rewrite(mlil_inst inst) = 0;
    virtual const char* name() const = 0;
    virtual float confidence() const { return 1.0f; }
};
{% endhighlight %}

Tous les détecteurs sont chaînés. Chaque fonction passe dans chaque détecteur.
Quand y'a un match, le rewriter remplace les nœuds IL obfusqués par des nœuds
propres. C'est simple, mais c'est la composition des détecteurs qui fait la
force du truc.

### Détecter le control flow flattening

Le CFG flattening, c'est ce que je croise le plus souvent. L'obfuscateur prend
une fonction normale et la transforme en machine à état : chaque basic block
modifie une variable d'état, puis saute vers un dispatcher central. La logique
d'origine est toujours là, mais la structure est détruite.

Mon détecteur cherche trois choses :

1. Une boucle qui contient un switch ou un bloc dispatcher avec un in-degree élevé
2. Une variable d'état mise à jour avant chaque saut indirect
3. Tous les basic blocks d'origine présents comme cases du switch, juste éparpillés

{% highlight cpp %}
bool CFFDetector::match(mlil_inst inst) {
    auto* func = inst.function();
    auto cfg = func->mlil();

    auto dispatcher = findDispatcher(cfg);
    if (!dispatcher) return false;

    auto stateVar = traceStateVariable(dispatcher);
    if (!stateVar) return false;

    auto edges = recoverEdges(cfg, dispatcher, stateVar);
    return edges.size() > 0;
}
{% endhighlight %}

Le morceau intéressant c'est `traceStateVariable`. Il faut remonter la valeur
d'état à travers les nœuds phi, ce qui devient vite un labyrinthe quand
l'obfuscateur insère délibérément des assignations supplémentaires. J'utilise
un simple parcours de chaîne use-def, en m'arrêtant quand je tombe sur une
constante ou un argument de fonction.

### Recettes : les utilisateurs veulent configurer

Toutes les obfuscations ne rentrent pas dans un template. Certains croisent des
protecteurs maison. Donc j'ai ajouté un système de recettes : des configs JSON
qui décrivent une passe de désobfuscation. Pas besoin de recompiler.

```json
{
  "name": "xor_strings",
  "description": "Décode les références de chaînes obfusquées par XOR",
  "detectors": ["constant_xor_loop"],
  "max_iterations": 3,
  "requires": ["function_analysis"]
}
```

Le moteur lance jusqu'à `max_iterations` passes. Certaines transformations ne
marchent qu'après avoir retiré une couche précédente. Tu fais la simplification
MBA avant le désaplatissement CFG et la sortie est n'importe quoi. L'ordre est
super important.

## Build

CMake + Ninja. L'API Binary Ninja est vendored en submodule git, pinnée à une
révision précise parce que l'API change entre les versions de BN.

```bash
git clone https://github.com/mitsuakki/deobfninja
cd deobfninja
git submodule update --init
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build
cmake --install build
```

`$BN_INSTALL_DIR` pointe vers ton installation Binary Ninja.

## Les chiffres

Testé sur un binaire obfusqué de ~5 Mo, machine 12 cœurs :

| Approche | Temps | Mémoire |
|----------|-------|---------|
| Python (API BN) | 42s | 1.2 Go |
| C++ single thread | 3.1s | 180 Mo |
| C++ parallèle | 0.8s | 240 Mo |

Le parallélisme ajoute environ 4x sur la base C++. Pas dégueu.

## Ce qui m'a mordu

L'IL de BN change entre les versions. Pin ton submodule. Vraiment.

Le lifting MLIL peut échouer sur du code bien obfusqué. Toujours vérifier
`mlil_inst.operation` avant de caster. J'ai passé une soirée à déboguer un
segfault qui était juste un nœud d'opération null.

L'ordonnancement des recettes est débile. Il te prévient pas si tes passes
sont incompatibles. Tu apprends en voyant la sortie se dégrader.

## La suite

Je veux ajouter plus de détecteurs : patterns d'opaques predicates, passes de
simplification MBA, peut-être un langage de pattern générique pour que les gens
puissent écrire des règles de détection sans toucher au C++. Le dossier `tests/`
a des binaires d'exemple si tu veux jouer avec. Les PRs sont bienvenues, ou
ouvre une issue si ça casse.
