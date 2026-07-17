---
layout: post
title: "Building a Binary Ninja deobfuscation plugin in C++"
tags: [binaryninja, c++, deobfuscation, plugin-dev, deobfninja]
lang: en
---

Binary Ninja's C++ API is kind of a hidden gem. Everyone defaults to Python
because it's easy. But deobfuscation means iterating over every instruction
in a function, pattern matching against obfuscator signatures, rewriting IL.
Python just dies. Especially on real binaries.

So I wrote [deobfninja](https://github.com/mitsuakki/deobfninja) in C++.

## Why not Python

The Python API is fine for quick scripts. I still use it for one-off analysis.
But deobfuscation is one of those problems where you feel every millisecond
of interpreter overhead.

C++ gives you direct access to BN's IL. No GIL, so you parallelize across
functions. Zero-copy buffer manipulation for pattern matching. On a 5 MB binary
with moderate obfuscation, the C++ plugin runs in under a second. The Python
equivalent took 42 seconds.

That's not an optimization. That's the difference between "usable" and
"I'm going to make coffee while this runs."

## Architecture

```
┌──────────────────────────────────┐
│         Binary Ninja             │
│  ┌────────────────────────────┐  │
│  │    Plugin Loader           │  │
│  └──────────┬─────────────────┘  │
│             │                    │
│  ┌──────────▼─────────────────┐  │
│  │  deobfninja core           │  │
│  │  ┌───────────┐ ┌────────┐  │  │
│  │  │ Pattern   │ │ IL     │  │  │
│  │  │ Matcher   │ │ Rewrite│  │  │
│  │  └───────────┘ └────────┘  │  │
│  │  ┌───────────┐ ┌────────┐  │  │
│  │  │ Recipe    │ │ Metrics│  │  │
│  │  │ Engine    │ │        │  │  │
│  │  └───────────┘ └────────┘  │  │
│  └────────────────────────────┘  │
└──────────────────────────────────┘
```

### Pattern matching on MLIL

I work on BN's Medium Level IL, not raw assembly. MLIL is high enough that
patterns survive across compiler versions, but low enough that obfuscator
tricks don't get optimized away.

Each obfuscation technique registers as a detector:

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

All detectors get chained. Every function gets piped through every detector.
Match → rewrite → next. Dead simple, but composing detectors is where
the interesting stuff happens.

### Control flow flattening

CFG flattening is everywhere. The obfuscator turns a normal function into a
state machine: each basic block updates a state variable, jumps to a central
dispatcher. Original logic is still there, structure is gone.

My detector looks for three signals:

1. A loop containing a dispatcher block with abnormally high in-degree
2. A state variable updated before each indirect jump
3. All original basic blocks present as switch cases, just scattered

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

`traceStateVariable` is the fun part. You follow the state value backwards
through phi nodes, which gets messy when the obfuscator sprinkles in fake
assignments. I do a simple use-def walk, bail when I hit a constant or
function argument. Works most of the time.

### Recipes

Not everything fits a template. Some people hit custom protectors. So there's
a recipe system: JSON files describing a deobfuscation pass. No recompilation.

```json
{
  "name": "xor_strings",
  "description": "Decode XOR-obfuscated string references",
  "detectors": ["constant_xor_loop"],
  "max_iterations": 3,
  "requires": ["function_analysis"]
}
```

The engine runs up to `max_iterations` passes. Some transforms only make sense
after a previous layer gets peeled. Run MBA simplification before CFF untangling
and the output is garbage. Order matters a lot.

## Build setup

CMake + Ninja. BN API vendored as a git submodule, pinned to a specific
revision. The API changes between BN versions and I learned this the hard way.

```bash
git clone https://github.com/mitsuakki/deobfninja
cd deobfninja
git submodule update --init
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build
cmake --install build
```

`$BN_INSTALL_DIR` points to your BN install.

## Numbers

5 MB obfuscated binary, 12-core machine:

| Approach | Time | Memory |
|----------|------|--------|
| Python (BN API) | 42s | 1.2 GB |
| C++ single thread | 3.1s | 180 MB |
| C++ parallel | 0.8s | 240 MB |

~4× from parallelization on top of the C++ baseline. I'll take it.

## Things that broke

BN's IL changes between versions. Pin your submodule. I'm serious.

MLIL lifting fails sometimes on heavily obfuscated code. Always check
`mlil_inst.operation` before casting. I lost an evening to a segfault
that was just a null operation node.

Recipe ordering isn't smart. It won't warn you if two passes conflict.
You notice when the output gets worse instead of better.

## What's missing

More detectors: opaque predicate patterns, MBA simplification passes.
Maybe a pattern DSL so people can write detection rules without touching C++.
The `tests/` directory has sample binaries. PRs welcome, or open an issue
if something breaks.
