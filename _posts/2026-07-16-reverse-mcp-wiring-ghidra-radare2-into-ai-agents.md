---
layout: post
title: "reverse-mcp: wiring Ghidra and radare2 into AI agents"
tags: [mcp, ghidra, radare2, docker, ai-agents, tooling]
lang: en
---

I got tired of switching windows. Disassemble in one terminal. Decompile in
another. Grep xrefs somewhere else. Shell out for `strings` or `checksec`.
Every tool has its own CLI. Its own output format. Its own annoyances.

So I built [reverse-mcp](https://github.com/mitsuakki/reverse-mcp). One Docker
container. Ghidra, radare2, angr, and a shell. All exposed as MCP servers behind
a single HTTP endpoint. Claude Code connects, and every RE tool is one function
call away.

## How it works

```
┌──────────────┐     HTTP      ┌──────────────┐
│  Claude Code │ ────────────→ │   Gateway    │
│  (MCP client)│               │   :3100      │
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

### The gateway

`gateway.py`, port 3100. Each back-end runs as a child process. The gateway
merges their tools into one namespace. Each back-end gets a prefix:

| Prefix | Back-end | What you get |
|--------|----------|--------------|
| `r2__` | radare2 (r2mcp) | disassemble, decompile (r2ghidra), hexdump, xrefs, emulation |
| `ghidra__` | Ghidra headless :8089 | project management, import, auto-analysis, 200+ tools: decompiler, patcher, BinDiff, debugger |
| `shell__` | shell-mcp | anything: strings, checksec, ent, gdb, lldb, apktool, whatever |
| `angr__` | angr MCP | CFG, symbolic execution, VFG, dependency analysis |

If a back-end dies, the gateway logs it and keeps running. Tools from that
back-end just don't appear. No cascading failure.

### The Ghidra situation

Ghidra tools are split in two. Static tools (`import_file`, `list_instances`,
`create_project`) are always available. Instance tools (`decompile`, `rename`,
`xrefs`, `patch`) only show up after you load a program.

Flow: import file → auto-connect → gateway fetches the instance schema →
200+ tools unlock. A bit clunky but it holds together.

## Getting started

```bash
git clone https://github.com/mitsuakki/reverse-mcp
cd reverse-mcp
docker compose build
docker compose up -d
```

Drop binaries in `./workspace/`. They show up at `/workspace` inside the
container.

MCP client config:

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

## Agents

Five Claude Code agents in `.claude/agents/`. Each does one thing:

| Agent | Model | Role |
|-------|-------|------|
| `binary-triage` | Haiku | Fast surface recon: radare2 + shell |
| `ghidra-importer` | Sonnet | Import into Ghidra, auto-analysis |
| `ghidra-analyst` | Sonnet | Static RE: decompile, xrefs, rename |
| `ghidra-debugger` | Sonnet | Dynamic: attach, breakpoints, trace |
| `re-orchestrator` | Opus | Runs the whole pipeline, triage → report |

The orchestrator chains them. Triage first for a quick surface look. If the
binary seems interesting, it hands off to Ghidra. Sometimes you just want a
fast answer and don't need the heavyweight pipeline.

## What's inside

Everything in the container. No GUI, no VNC. Terminal or MCP only.

radare2 + r2ghidra decompiler. Ghidra headless + analyzeHeadless + a helper
script. BinDiff CLI. angr, pwntools, ropper, ROPgadget, capstone, unicorn,
keystone, z3, LIEF, r2pipe. Fuzzing: AFL++ with QEMU mode, honggfuzz.
Android: apktool, jadx, Frida, objection. Standard: gdb, lldb, strace,
ltrace, nasm, objdump, patchelf, gcc, clang.

Basically everything I use day to day, containerized so I don't have to think
about dependencies.

## Security

No auth on the gateway. Local dev tool, don't expose it. Run untrusted
binaries in a VM. The compose file adds `SYS_PTRACE` and drops seccomp
for gdb/AFL to work.

## CI

GitHub Actions on push and PR. Tagged versions push to GHCR. MIT license.

## Next

Binary Ninja MCP bridge using BN headless mode. Frida bridge for mobile RE.
Import Ghidra CFGs into angr for hybrid analysis.

I'll write up how to build a custom MCP server for an RE tool. The pattern
is simple: subprocess the tool, parse output, expose as typed MCP tools with
JSON schemas. Under 200 lines of Python for a basic disassembler bridge.
