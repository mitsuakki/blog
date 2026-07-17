---
layout: post
title: "Building a Binary Ninja deobfuscation plugin in C++"
tags: [binaryninja, c++, deobfuscation, plugin-dev, deobfninja]
lang: en
---

Binary Ninja's C++ API is kind of a hidden gem. Everyone uses the Python API
because it's easy. But when you're doing deobfuscation, iterating over every
instruction in a function, pattern matching against obfuscator signatures,
rewriting IL... Python just dies. Especially on real binaries.

So I started [deobfninja](https://github.com/mitsuakki/deobfninja) in C++.
Here is what I learned.

## Why not Python

Look, the Python API is great for quick scripts. I still use it for one-off
analysis. But deobfuscation is one of those problems where you feel every
millisecond of interpreter overhead.

In C++ you get direct access to BN's IL. No GIL, so you can parallelize across
functions. Zero copy buffer manipulation for pattern matching. On a 5 MB
binary with moderate obfuscation, the C++ plugin runs in under a second.
The Python equivalent took 42 seconds. That's not an optimization, it's the
difference between "usable" and "I'll go make coffee".

## The plugin architecture

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
patterns are recognizable across compiler versions, but low enough that
obfuscator tricks still show up clearly.

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
When something matches, the rewriter replaces the obfuscated IL nodes with
clean ones. It's simple, but composing detectors is where the power is.

### Spotting control flow flattening

CFG flattening is the thing I run into most. The obfuscator takes a normal
function and turns it into a state machine: every basic block updates a state
variable, then jumps to a central dispatcher. The original logic is still
there, but the structure is gone.

My detector looks for three things:

1. A loop containing a switch or dispatcher block with high in-degree
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

The fun part is `traceStateVariable`. You have to follow the state value
backwards through phi nodes, which is a bit of a maze when the obfuscator
deliberately inserts extra assignments. I use a simple use-def chain walk,
stopping when I hit a constant or a function argument.

### Recipes: users need configurability

Not all obfuscation fits a template. Some people run into custom protectors.
So I added a recipe system: JSON configs that describe a deobfuscation pass.
No recompilation needed.

```json
{
  "name": "xor_strings",
  "description": "Decode XOR-obfuscated string references",
  "detectors": ["constant_xor_loop"],
  "max_iterations": 3,
  "requires": ["function_analysis"]
}
```

The engine runs up to `max_iterations` passes. Some transforms only work after
a previous layer gets peeled. You do MBA simplification before CFF untangling
and the output is garbage. Order matters, a lot.

## Build setup

CMake + Ninja. Binary Ninja API vendored as a git submodule, pinned to a
specific revision because the API changes between BN versions.

```bash
git clone https://github.com/mitsuakki/deobfninja
cd deobfninja
git submodule update --init
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build
cmake --install build
```

`$BN_INSTALL_DIR` points to your Binary Ninja install path.

## Numbers

Tested on a ~5 MB obfuscated binary, 12-core machine:

| Approach | Time | Memory |
|----------|------|--------|
| Python (BN API) | 42s | 1.2 GB |
| C++ single thread | 3.1s | 180 MB |
| C++ parallel | 0.8s | 240 MB |

Parallelism adds roughly 4x on top of the C++ baseline. Not bad.

## Things that bit me

BN's IL changes between versions. Pin your submodule. Seriously.

MLIL lifting can fail on heavily obfuscated code. Always check
`mlil_inst.operation` before casting. I spent an evening debugging a
segfault that turned out to be a `null` operation node.

Recipe ordering is not smart. It won't warn you if your passes conflict.
You learn by watching the output get worse.

## What's next

I want to add more detectors: opaque predicate patterns, MBA simplification
passes, maybe a generic pattern language so people can write detection rules
without touching C++. The `tests/` directory has sample binaries if you want
to play with it. PRs welcome, or just open an issue if something breaks.
