---
layout: post
title: "Building a Binary Ninja deobfuscation plugin in C++"
tags: [binaryninja, c++, deobfuscation, plugin-dev, deobfninja]
lang: en
---

Most people working with Binary Ninja stick to the Python API. It makes sense, Python is easy to get started with and the bindings are well documented. But when you are doing deobfuscation, you end up iterating over every instruction in a function, pattern matching against obfuscator signatures, rewriting IL trees. Python just cannot keep up, especially on real binaries that are not tiny crackmes.

That is why I wrote [deobfninja](https://github.com/mitsuakki/deobfninja) in C++. It was a lot more work to set up, but the performance difference made it worth it.

## Why I did not stick with Python

The Python API is fine for quick scripts. I still use it when I need to check something fast or write a one-off analysis. But deobfuscation makes you feel every millisecond, and the interpreter overhead adds up really fast.

With C++ you get direct access to Binary Ninja's IL, there is no GIL so you can parallelize across functions, and you can use zero-copy buffers for the pattern matcher. I tested it on a 5 MB binary with moderate obfuscation: the C++ plugin runs in under a second. The Python version took 42 seconds.

That is not an optimization. That is the difference between "I can iterate on this" and "I am going to make coffee while it runs."

## How I structured it

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

I work on BN's Medium Level IL, not raw assembly. MLIL sits at a sweet spot: it is high level enough that patterns survive across compiler versions, but low level enough that obfuscator tricks do not get optimized away. If you match on raw assembly, a different register allocation ruins your pattern. If you match on HLIL, the obfuscator's dead code might already be cleaned up and you lose the signal.

Each obfuscation technique is a detector class:

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

All detectors get chained together. Every function goes through every detector: match, rewrite, next. It sounds simple but composing detectors is where things get tricky. You have to remove opaque predicates before untangling control flow flattening, otherwise the state variable trace breaks because the fake branches confuse the path reconstruction.

### Control flow flattening

Control flow flattening is probably the most common obfuscation I run into. The obfuscator takes a normal function and turns it into a state machine: each basic block updates a state variable, then jumps to a central dispatcher. The original logic is still there, but the structure is completely gone. It looks like spaghetti.

My detector looks for three signals:

1. A loop containing a dispatcher block with an abnormally high in-degree (the dispatcher receives jumps from every real basic block)
2. A state variable that gets updated before each indirect jump
3. All original basic blocks present as switch cases, just scattered in the binary

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

`traceStateVariable` is the hard part. You follow the state value backwards through phi nodes, which gets messy when the obfuscator sprinkles in fake assignments to throw you off. I do a simple use-def walk and bail when I hit a constant or function argument. It works most of the time but I am sure there are edge cases I have not seen yet.

### The recipe system

Not everything fits a template. Sometimes you run into custom protectors that need a specific combination of passes. So I added a recipe system: JSON files that describe a deobfuscation pass. No need to recompile.

```json
{
  "name": "xor_strings",
  "description": "Decode XOR-obfuscated string references",
  "detectors": ["constant_xor_loop"],
  "max_iterations": 3,
  "requires": ["function_analysis"]
}
```

The engine runs up to `max_iterations` passes. Some transforms only make sense after you peel the previous layer. Run MBA simplification before CFF untangling and the output is garbage because you simplified expressions that the CFF detector needed to trace the state variable. Order matters a lot and I learned that by getting wrong results.

## Building it

CMake + Ninja. The BN API is vendored as a git submodule, pinned to a specific revision. I learned this the hard way: the API changes between BN versions and if you do not pin it, your plugin randomly breaks after an update.

```bash
git clone https://github.com/mitsuakki/deobfninja
cd deobfninja
git submodule update --init
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build
cmake --install build
```

Set `$BN_INSTALL_DIR` to your Binary Ninja install path.

## Numbers

Here is what I measured on a 5 MB obfuscated binary, 12-core machine:

| Approach | Time | Memory |
|----------|------|--------|
| Python (BN API) | 42s | 1.2 GB |
| C++ single thread | 3.1s | 180 MB |
| C++ parallel | 0.8s | 240 MB |

About 4x improvement from parallelization on top of the C++ baseline. The memory usage is also way lower because you are not paying for Python's object overhead on every IL instruction. I will take these numbers.

## Things that broke along the way

Binary Ninja's IL changes between versions. Pin your submodule. I am serious about this, I lost an afternoon to a segfault that was just a function signature change.

MLIL lifting fails sometimes on heavily obfuscated code. Always check `mlil_inst.operation` before casting. I wasted an evening on a crash that turned out to be a null operation node that I assumed would never be null.

Recipe ordering is not smart. It will not warn you if two passes conflict. You notice when the output gets worse instead of better, and then you have to binary-search which pass broke things.

## What I want to add next

More detectors: opaque predicate patterns, more MBA simplification passes. Maybe a pattern DSL so people can write detection rules without touching C++, that would lower the barrier for contributions a lot. The `tests/` directory has sample binaries if you want to try it. PRs are welcome, or open an issue if something breaks.
