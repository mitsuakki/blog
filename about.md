---
layout: default
title: about
permalink: /about/
lang: en
---

<div class="profile-block">
  <img src="{{ '/assets/img/avatar.png' | relative_url }}" alt="mitsuakki" class="profile-avatar">
  <div class="profile-text">
    <h1>Alexis M. Daugé <span style="color: var(--fg-muted); font-size: 0.85rem; font-weight: 400;">@mitsuakki</span></h1>
    <p>Software &amp; reverse engineer. Cognitive science student at <a href="https://ensc.bordeaux-inp.fr/">ENSC Bordeaux INP</a>.</p>
  </div>
</div>

## projects

<dl>
  <dt><a href="https://github.com/mitsuakki/deobfninja">deobfninja</a></dt>
  <dd>C++ deobfuscation plugin for Binary Ninja. Opaque predicates, control flow flattening, mixed boolean arithmetic. ~50× faster than equivalent Python.</dd>

  <dt><a href="https://github.com/mitsuakki/reverse-mcp">reverse-mcp</a></dt>
  <dd>Docker-based RE lab. Ghidra, radare2, angr + shell, exposed as MCP servers for AI agents. 5 specialized Claude Code agents included.</dd>

  <dt><a href="https://github.com/mitsuakki/x86-kernel">x86-kernel</a></dt>
  <dd>From-scratch x86_64 kernel. Bare metal, NASM, QEMU. No AI used — written to learn.</dd>

  <dt><a href="https://github.com/sarumc/bds-sdk-generator">bds-sdk-generator</a> <span class="badge badge-yellow">archived</span></dt>
  <dd>Reconstructing PDB symbols into compilable C headers for Bedrock Dedicated Server modding.</dd>
</dl>

## tools

<table>
  <thead><tr><th>category</th><th>stack</th></tr></thead>
  <tbody>
    <tr>
      <td>RE platforms</td>
      <td><code>Binary Ninja</code> <code>Ghidra</code> <code>radare2</code> <code>x64dbg</code></td>
    </tr>
    <tr>
      <td>dynamic analysis</td>
      <td><code>Frida</code> <code>angr</code></td>
    </tr>
    <tr>
      <td>languages</td>
      <td><code>C++</code> <code>Python</code> <code>Go</code> <code>Java</code> <code>PHP</code> <code>V</code> <code>NASM</code></td>
    </tr>
    <tr>
      <td>infra &amp; tooling</td>
      <td><code>Docker</code> <code>CMake</code> <code>MCP</code> <code>QEMU</code></td>
    </tr>
  </tbody>
</table>

## elsewhere

- GitHub: [mitsuakki](https://github.com/mitsuakki)
- LinkedIn: [alexis-dauge](https://linkedin.com/in/alexis-dauge)
