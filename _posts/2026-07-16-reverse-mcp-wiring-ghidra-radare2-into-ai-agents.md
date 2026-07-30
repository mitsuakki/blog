---
layout: post
title: "reverse-mcp: wiring Ghidra and radare2 into AI agents"
tags: [mcp, ghidra, radare2, docker, ai-agents, tooling]
lang: en
---

I got tired of switching windows all the time. Disassemble in one terminal, decompile in another, grep cross-references somewhere else, shell out for `strings` or `checksec` in yet another tab. Every reverse engineering tool has its own CLI, its own output format, its own little annoyances that add up when you are trying to stay focused on the binary.

So I built [reverse-mcp](https://github.com/mitsuakki/reverse-mcp). It is a single Docker container with Ghidra, radare2, angr, and a shell inside. All of them are exposed as MCP servers behind one HTTP endpoint. Claude Code connects to it and suddenly every RE tool is just a function call away. No more context switching.

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

The gateway runs on port 3100. Each backend runs as a child process and the gateway merges all their tools into one namespace. Every backend gets a prefix so you know which tool you are calling:

| Prefix | Back-end | What you get |
|--------|----------|--------------|
| `r2__` | radare2 (r2mcp) | disassemble, decompile (r2ghidra), hexdump, xrefs, emulation |
| `ghidra__` | Ghidra headless :8089 | project management, import, auto-analysis, 200+ tools: decompiler, patcher, BinDiff, debugger |
| `shell__` | shell-mcp | anything: strings, checksec, ent, gdb, lldb, apktool, whatever you need |
| `angr__` | angr MCP | CFG, symbolic execution, VFG, dependency analysis |

If a backend dies, the gateway logs it and keeps running. Tools from that backend just disappear from the namespace. No cascading failure, everything else keeps working. I spent some time making sure one broken tool does not take down the whole setup.

### The Ghidra situation

Ghidra tools are split into two categories. Static tools like `import_file`, `list_instances`, `create_project` are always available because they do not need a loaded binary. Instance tools like `decompile`, `rename`, `xrefs`, `patch` only show up after you have loaded a program into Ghidra.

The flow goes like this: import a file, the system auto-connects to the new instance, the gateway fetches the instance's tool schema, and suddenly over 200 tools unlock. It is a bit clunky as a user experience but it holds together. I could probably make it smoother but it works for now.

## Getting started

```bash
git clone https://github.com/mitsuakki/reverse-mcp
cd reverse-mcp
docker compose build
docker compose up -d
```

Drop your binaries in `./workspace/`. They show up at `/workspace` inside the container, and all the tools can see them.

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

## The agents

I wrote five Claude Code agents that live in `.claude/agents/`. Each one does a specific part of the reverse engineering workflow:

| Agent | Model | Role |
|-------|-------|------|
| `binary-triage` | Haiku | Fast surface recon: radare2 + shell |
| `ghidra-importer` | Sonnet | Import into Ghidra, auto-analysis |
| `ghidra-analyst` | Sonnet | Static RE: decompile, xrefs, rename |
| `ghidra-debugger` | Sonnet | Dynamic: attach, breakpoints, trace |
| `re-orchestrator` | Opus | Runs the whole pipeline, triage to report |

The orchestrator chains them together. It starts with triage for a quick surface look, and if the binary seems interesting enough, it hands off to the Ghidra pipeline. Sometimes you just want a fast answer and you do not need the full heavyweight analysis, so the two-stage approach saves time.

## What is inside

Everything runs in the container. No GUI, no VNC, no desktop environment. Terminal or MCP only, the way I like it.

Here is the full tool list: radare2 with the r2ghidra decompiler. Ghidra headless plus analyzeHeadless and a helper script I wrote. BinDiff CLI for diffing. angr, pwntools, ropper, ROPgadget, capstone, unicorn, keystone, z3, LIEF, r2pipe. For fuzzing there is AFL++ with QEMU mode, and honggfuzz. For Android reversing: apktool, jadx, Frida, objection. And the standard tools: gdb, lldb, strace, ltrace, nasm, objdump, patchelf, gcc, clang.

Basically everything I use day to day in my reverse engineering work, containerized so I do not have to think about dependencies or version conflicts anymore.

## Security notes

There is no authentication on the gateway. This is a local dev tool, so do not expose it to a network. If you are running untrusted binaries, use a VM. The Docker compose file adds `SYS_PTRACE` and drops seccomp so that gdb and AFL can work. These are necessary for dynamic analysis but they do reduce container isolation, so be aware of that.

## CI and releases

GitHub Actions runs on push and pull requests. Tagged versions get pushed to GHCR as Docker images. MIT license, do whatever you want with it.

## What I want to build next

A Binary Ninja MCP bridge using BN's headless mode, because I use both Ghidra and BN depending on the project. A Frida bridge for mobile reverse engineering. And ideally, importing Ghidra CFGs into angr for hybrid static and symbolic analysis -- combining the two would be really powerful for certain kinds of problems where you need both the decompiler view and the symbolic engine.

I will write up a guide on how to build a custom MCP server for a reverse engineering tool. The pattern is actually pretty simple: subprocess the tool, parse its output, expose everything as typed MCP tools with JSON schemas. You can build a basic disassembler bridge in under 200 lines of Python. Once you have done it once, you can do it for any tool.
