# Performance Optimization Guide

Writing fast programs doesn't magically happen. This guide contains tips and best practices for
making things go _fast_ in Swift.

## Preparation

> Performance optimization is incredibly subtle. Both hardware and the Swift compiler are very
> sophisticated; and both have non-obvious performance characteristics. By doing some preparation,
> you can remove a lot of guesswork and save yourself time.

 1. **Write a benchmark**: The current recommendation is to use the [Swift
    Benchmark](https://github.com/google/swift-benchmark) library, as it has a nice suite of
    features. Ensure it is representative of the program / subroutine you're trying to optimize.
    Try to write your benchmarks so they run quickly to enable a fast iteratation cycle. (Note: use
    Swift Benchmark's `--filter` flag to run only the relevant benchmarks you're trying to optimze.)

    When developing with SwiftPM, we've found that defining an (unexported) `Benchmarks` executable
    target that aggregates all your benchmarks across your project into a single binary works well.

 2. **Start a spreadsheet & gather baselines**: Keep track of what changes you're making, and how
    they affect performance. One spreadsheet template that works well looks like:

    | Perf (ns) | Hash       | Notes                                                              |
    |-----------|------------|--------------------------------------------------------------------|
    | 1234.5    | `abc123fd` | Baseline                                                           |
    | 1500.2    | `cba321df` | Switch to using classes instead of structs (whoops!)               |
    | 36.4      | `df123abc` | Avoid accidentally quadratic behavior by using in-place operations |
    | ...       | ...        | ...                                                                |

    Tip: Every time you run the benchmark, commit the changes. That way you know exactly what you
    ran and when. (You can always [squash commits & rewrite history
    later](https://git-scm.com/docs/git-rebase).) Additionally, always start with a baseline
    measurement for your benchmark on your machine. Don't rely on numbers from a previous version of
    the compiler or library, or having run them on another machine!

## Profile

Profiling occurs differently depending on which platform you're running on.

### Linux Profiling: Perf

Linux has sophisticated performance profiling infrastructure available. We currently recommend using
`perf` which is available on all modern Linux distributions & kernels. You can install it on Debian
or Ubuntu machines by executing: `sudo apt-get install linux-perf`.

To capture a profile, do something like the following:

```bash
swift build -c release -Xswiftc -cross-module-optimization
perf record -F 499 -g -- .build/release/Benchmarks --filter myBenchmark
```

where `Benchmarks` is the name of the SwiftPM executable containing the benchmarks, and the
specific benchmark you're trying to optimize has `myBenchmark` somewhere in its name. Once you've
captured the profile, it's time to analyze it!

#### Visualizing the profile: Flame Graphs

> Prerequisite: clone https://github.com/brendangregg/FlameGraph somewhere.

In the same directory where you ran `perf record` above, execute (assuming you checked out the
FlameGraph repository at `../FlameGraph`):

```bash
perf script | ../FlameGraph/stackcollapse-perf.pl | swift-demangle | ../FlameGraph/flamegraph.pl --width 1800 > flamegraph.svg
```

You can then visualize the resulting SVG file with your browser.

> Be sure to adjust the paths to the FlameGraph repository if you did not check it out in a sister
> directory to your current package.

To learn more about how to interpret flame graphs, check out:

 - [Flame Graphs](http://www.brendangregg.com/flamegraphs.html)
 - [Visualizing Performance with Flame Graphs (video)](https://www.youtube.com/watch?v=D53T1Ejig1Q)

#### Visualizing the profile: dot graph

[`gprof2dot`](https://github.com/jrfonseca/gprof2dot) can provide even more sophisticated insights
into the performance of a program.

> Prerequisite:
>  - Debian / Ubuntu: `sudo apt-get install python3 graphviz && pip install gprof2dot`
>  - RedHat / Fedora: `sudo yum install python3 graphviz && pip install gprof2dot`

In the same directory where you ran `perf record` above, execute:

```bash
perf script | swift-demangle | gprof2dot -f perf | dot -Tpng -o perf.png
```

You can the visualize the resulting PNG file with your browser or other image viewing software.

gprof2dot has a number of extra variations / configuration options that can help you understand
performance more deeply.

##### Prioritize self time

By default, `gprof2dot` colors vertices based on the total time spent, resulting in a similar
visualization to flame graphs. While this is very useful to understand where time is spent in the
program, it can sometimes be useful to understand which function is _itself_ consuming a significant
amount of time. You can use the `--color-nodes-by-selftime` to see this quickly. Example:


```bash
perf script | swift-demangle | gprof2dot -f perf --color-nodes-by-selftime | dot -Tpng -o perf-selftime.png
```

##### Filtering the graph

When optimizing reference counting overheads (e.g. retain / releases), it can be helpful to filter
down the graph to more easily identify where the ARC operations are coming from. (ARC traffic can
be especially bad in performance-critical code, as it involves CPU atomics.) The following command
filters down the graph to the subset that calls `swift_retain`. (You can perform similar analysis
looking for `swift_release` as well.)

```bash
perf script | swift-demangle | gprof2dot -f perf -l "swift_retain" | dot -Tpng -o perf-retains.png
```

Note: filtering for `swift_retain` and `swift_release` can of course be combined with the
`--color-nodes-by-selftime` option, as follows:

```bash
perf script | swift-demangle | gprof2dot -f perf -l "swift_retain" --color-nodes-by-selftime | dot -Tpng -o perf-retains-selftime.png
```

## Pin-pointing hot-spots

The Swift compiler is _very_ good at optimizing and inlining code. While this is great for
performance, it can sometimes make it very difficult to understand where a particular performance
problem is coming from. For example: if functions `b()`, `c()`, and `d()` are all inlined into
function `a()`, only `a()` will show up in the profiles and not `b()`, `c()`, or `d()`, even if
`a()` is itself fast, and it's actually `c()` that's a very slow function. To pinpoint where the
hotspots are, you can annotate `b()`, `c()`, and `d()` with `@inline(never)` (temporarily) and
capture a new profile.

> Be sure to remove unnecessary `@inline(never)` annotations, as they can adversely affect
> performance.

## Generated Code

When trying to understand why a particular piece of Swift code is performing poorly, it can be
helpful to look at the code the Swift compiler generates for a particular pattern.

### Godbolt Compiler Explorer

The [Godbolt compiler explorer](https://godbolt.org/) supports Swift, and is a great way to look at
small snippets of code in isolation. Be sure to set the `-O` flag when looking at the generated
assembly. Here is [a quick link that sets the compiler to Swift nightly and enables
optimizations](https://godbolt.org/z/5ffjmG).


### Inspecting code in context and/or SIL

While Godbolt is _fantastic_ for understanding what assembly is produced by the Swift compiler for
small snippets of code, it is sometimes more effective to look at the code generated by the compiler
in the context of your project. (e.g. Dependencies are difficult to disentangle / understand in
isolation, etc.) Additionally, it can sometimes be more effective to see higher level
representations of the program used by the compiler such as the
[SIL](https://github.com/apple/swift/blob/master/docs/SIL.rst) program instead of the [LLVM
IR](https://llvm.org/docs/LangRef.html) or [assembly
instructions](https://en.wikipedia.org/wiki/X86_instruction_listings). Advantages of looking at SIL
include much better tie-in with the original Swift code, and higher-level semantic operations.
Looking at LLVM or the assembly has the advantage of being closer to the hardware, and thus there
are fewer layers of abstraction to peer through. (Note that for the most performance critical
operations, you'll want to look into the details of your hardware to understand hardware ports,
instruction latency, prefetch buffer sizes, and beyond. This is out of scope for this document.)

[Debugging the compiler](https://github.com/apple/swift/blob/master/docs/DebuggingTheCompiler.md)
contains a section called ["Printing the Intermediate
Representations"](https://github.com/apple/swift/blob/master/docs/DebuggingTheCompiler.md#printing-the-intermediate-representations)
which describes how to print the intermediate representations based on direct `swiftc` invocations.
Thankfully, SwiftPM (when building) can be persuaded to tell you what `swiftc` invocations it's
doing when building your project. With a little bit of munging, you can get a command line
invocation you can use to dump the IR's for a given file:

 1. **Clean**: We begin by cleaning the generated artifacts: `swift package clean`
 2. **Build, capturing command lines**: Next, we re-build the project, capturing the command lines:

    ```bash
    swift build -v -c release -Xswiftc -cross-module-optimization | tee /tmp/build_commands.txt
    ```
 3. **Generate swiftc invocation**: We grep for the source filename that contains the code we'd like
    to analyze (in the example below: `CollectionAlgorithms.swift`), and perform some surgery to
    make it work independently from SwiftPM:

    ```bash
    cat /tmp/build_commands.txt | \
      grep "swiftc" | \
      grep "CollectionAlgorithms.swift" | \
      sed 's/-parseable-output //'
    ```

    This should get you a single command line like the following:

    ```bash
    /Library/Developer/Toolchains/swift-tensorflow-DEVELOPMENT-2020-04-15-a.xctoolchain/usr/bin/swiftc -module-name PenguinStructures -incremental -emit-dependencies -emit-module -emit-module-path /Users/saeta/tmp/penguin/.build/x86_64-apple-macosx/release/PenguinStructures.swiftmodule -output-file-map /Users/saeta/tmp/penguin/.build/x86_64-apple-macosx/release/PenguinStructures.build/output-file-map.json -parse-as-library -whole-module-optimization -num-threads 12 -c /Users/saeta/tmp/penguin/Sources/PenguinStructures/AnyArrayBuffer.swift /Users/saeta/tmp/penguin/Sources/PenguinStructures/ArrayBuffer.swift /Users/saeta/tmp/penguin/Sources/PenguinStructures/ArrayStorage.swift /Users/saeta/tmp/penguin/Sources/PenguinStructures/CollectionAlgorithms.swift /Users/saeta/tmp/penguin/Sources/PenguinStructures/DefaultInitializable.swift /Users/saeta/tmp/penguin/Sources/PenguinStructures/Deque.swift /Users/saeta/tmp/penguin/Sources/PenguinStructures/Empty.swift /Users/saeta/tmp/penguin/Sources/PenguinStructures/FactoryInitializable.swift /Users/saeta/tmp/penguin/Sources/PenguinStructures/FixedSizeArray.swift /Users/saeta/tmp/penguin/Sources/PenguinStructures/Heap.swift /Users/saeta/tmp/penguin/Sources/PenguinStructures/HierarchicalArrays.swift /Users/saeta/tmp/penguin/Sources/PenguinStructures/HierarchicalCollection.swift /Users/saeta/tmp/penguin/Sources/PenguinStructures/IdIndexable.swift /Users/saeta/tmp/penguin/Sources/PenguinStructures/KeyValuePair.swift /Users/saeta/tmp/penguin/Sources/PenguinStructures/NominalElementDictionary.swift /Users/saeta/tmp/penguin/Sources/PenguinStructures/PCGRandomNumberGenerator.swift /Users/saeta/tmp/penguin/Sources/PenguinStructures/Random.swift /Users/saeta/tmp/penguin/Sources/PenguinStructures/Tuple.swift /Users/saeta/tmp/penguin/Sources/PenguinStructures/UnsignedInteger+Reduced.swift -I /Users/saeta/tmp/penguin/.build/x86_64-apple-macosx/release -target x86_64-apple-macosx10.10 -swift-version 5 -sdk /Users/saeta/Downloads/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.15.sdk -F /Users/saeta/Downloads/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks -I /Users/saeta/Downloads/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib -L /Users/saeta/Downloads/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib -O -g -j12 -DSWIFT_PACKAGE -module-cache-path /Users/saeta/tmp/penguin/.build/x86_64-apple-macosx/release/ModuleCache -emit-objc-header -emit-objc-header-path /Users/saeta/tmp/penguin/.build/x86_64-apple-macosx/release/PenguinStructures.build/PenguinStructures-Swift.h -cross-module-optimization
    ```

 4. **Append dump operations**: You'll now need to modify the command line to request `swiftc` to
    dump whichever IR you'd like. You can see early SIL by passing `-emit-silgen`, or optimized SIL
    by passing `-emit-sil`. To see optimized LLVM IR, you can pass `-emit-ir`. Finally, it's often
    helpful to put the output into a file, which can be done by appending `-o $FILENAME.txt` as
    well.

    For example, to see optimized SIL, we would append `-emit-sil -o PenguinStructures.sil` to the
    command line generated in the previous step. After running the compiler, we can inspect the SIL
    by opening the file `PenguinStructures.sil` with our favorite text editor.

 5. **Making changes**: As you tweak the program, just re-run the command from the previous step,
    and it will output the updated SIL into the same file. This makes it very easy to see the effect
    different changes to the source has on the resulting program. Beware, if you change files in
    other modules, you may need to re-build with SwiftPM and re-generate the command line to dump
    IRs.

## Perennial Performance Pitfalls

The following are some common performance pitfalls in our experience:

 1. **Accidentally quadratic**: CoW-based data structures can make what should be a linear algorithm
    into an O(n^2) algorithm.

    - *Symptoms*: If you see a lot of `swift_arrayInitWithCopy`, `memcpy`, `_swift_release_dealloc`,
    `swift_release`, and `...makeMutableAndUnique...`, you likely are accidentally quadratic.

    - *Medicine*: Figure out where the copy is occuring (use `@inline(never)` as needed), and
      refactor the algorithm to either (a) avoid making mutations, or (b) avoid making a copy.

 2. **Classes inside Array's**: Avoid putting classes inside arrays, as this inhibits a variety of
    optimizations.

    - *Symptoms*: Lots of ARC traffic (`swift_retain`, `swift_release`) shows up in profiles (use
      `gperf2dot` instead of flame graphs).

    - *Medicine*: You can either (a) use a `struct` instead of a `class`, or (b) (dangerous) use
      one of the unsafe abstractions (`UnsafeBufferPointer`, `ManagedBuffer`, etc.), or (c) (even
      more dangerous) use `UnsafePointer` and/or `Unmanaged`.

 3. **Reflection**: Swift's optimizer is very good at optimizing protocols and generics, but is very
    bad at optimizing reflection-based code. Avoid using reflection-based code, and instead optimize
    for using protocols and generics instead.
