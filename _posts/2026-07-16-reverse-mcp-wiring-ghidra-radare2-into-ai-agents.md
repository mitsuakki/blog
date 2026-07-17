---
layout: post
title: "reverse-mcp: wiring Ghidra and radare2 into AI agents"
tags: [mcp, ghidra, radare2, docker, ai-agents, tooling]
lang: en
---

I got tired of switching windows. Disassemble in one terminal, decompile in
another, grep cross references somewhere else, then shell out to run `strings`
or `checksec` or whatever. Each tool has its own CLI, its own output format,
its own annoyances.

So I built [reverse-mcp](https://github.com/mitsuakki/reverse-mcp). One Docker
container. Ghidra, radare2, angr, and a full shell. All exposed as MCP servers
behind a single HTTP endpoint. Claude Code connects to it and suddenly every RE
tool is one function call away.

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

A Python script, `gateway.py`, listens on port 3100. It spawns each MCP
back-end as a child process, then composites their tools into one namespace.

Each back-end gets a prefix so tools never collide:

| Prefix | Back-end | What it gives you |
|--------|----------|-------------------|
| `r2__` | radare2 (r2mcp) | disassemble, decompile with r2ghidra, hexdump, xrefs, emulation |
| `ghidra__` | Ghidra headless on :8089 | project management, import, auto-analysis, 200+ tools including decompiler, patcher, BinDiff, debugger |
| `shell__` | shell-mcp | any command: strings, checksec, ent, gdb, lldb, apktool, whatever |
| `angr__` | angr MCP | CFG, symbolic execution, VFG, dependency analysis |

If a back-end fails to start, the gateway logs it and keeps running. The tools
from that back-end just don't show up in the client. No crash cascade.

### The Ghidra thing

Ghidra tools are split in two groups. Static tools (import_file, list_instances,
create_project) are always there. Instance tools (decompile, rename, xrefs,
patch) only appear after you load a program into a Ghidra instance.

The flow goes: import a file, auto connect, the gateway fetches the instance
schema, then all 200+ tools unlock. It's a bit clunky but it works.

## Getting started

```bash
git clone https://github.com/mitsuakki/reverse-mcp
cd reverse-mcp
docker compose build
docker compose up -d
```

Throw binaries in `./workspace/`. They show up at `/workspace` inside the
container.

MCP client config for Claude Code:

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

## The agents I ship with it

Five specialized Claude Code agents sit in `.claude/agents/`. Each one does
one thing:

| Agent | Model | Role |
|-------|-------|------|
| `binary-triage` | Haiku | First look: radare2 and shell recon, fast and cheap |
| `ghidra-importer` | Sonnet | Import into Ghidra, run auto-analysis |
| `ghidra-analyst` | Sonnet | Static RE: decompile, follow xrefs, rename things |
| `ghidra-debugger` | Sonnet | Dynamic: attach debugger, set breakpoints, trace |
| `re-orchestrator` | Opus | Runs the whole pipeline, triage to final report |

The orchestrator chains them. Triage fires first for surface assessment. If
the binary looks interesting, it hands off to the Ghidra pipeline. I wrote
it this way because sometimes you just want a quick look and don't need the
full heavyweight analysis.

## What's inside

Everything lives in the container. No GUI, no VNC. Terminal or MCP only.

radare2 with r2ghidra decompiler. Ghidra headless plus analyzeHeadless and a
load-ghidra.sh helper. BinDiff CLI. angr, pwntools, ropper, ROPgadget,
capstone, unicorn, keystone, z3, LIEF, r2pipe. For fuzzing: AFL++ with QEMU
mode, honggfuzz. For Android: apktool, jadx, Frida, objection. Standard stuff:
gdb, lldb, strace, ltrace, nasm, objdump, patchelf, gcc, clang.

Basically everything I use day to day, containerized.

## Security note

No authentication on the gateway. It's a local dev tool, not something you
expose to the internet. Run untrusted binaries in a VM. The docker compose
file adds `SYS_PTRACE` and drops seccomp for gdb and AFL.

## Builds

GitHub Actions CI on push and PR. Tagged versions push images to GHCR.
MIT license, do whatever you want with it.

## Next

I want to add a Binary Ninja MCP bridge using BN's headless mode. And maybe
a Frida bridge for mobile RE. And a way to import Ghidra CFGs into angr for
hybrid analysis.

I'll write up how to build a custom MCP server for an RE tool soon. The
pattern is simple: subprocess the tool, parse output, expose as typed MCP
tools with JSON schemas. Under 200 lines of Python for a basic disassembler
bridge.
