# Penguin Parallel: Parallel abstractions #

`PenguinParallel` is a toolkit of abstractions for parallel programming. It
contains a number of small, single-purpose components that can be combined to
build higher-level abstractions.

## User-friendly APIs ##

The user-friendly APIs for expression parallelism represent the two key types of
parallelism explored in this library.

Key abstractions include:

<!-- TODO: Switch to PipelineSequence instead! -->

 - **Pipeline Iterators** allow users to structure data and compute using
   iterators that can be parallelized across multiple cores. Pipeline iterators
   leverage 2 kinds of parallelism: (a) homogenous parallelism, where the same
   function is applied to data in parallel, and (b) heterogeneous (pipeline)
   parallelism, where two different kinds of operations occur simultaneously on
   two independent threads. Homogenous parallelism is exposed via
   transformations such as `interleave`, and `map` which run the same
   computation on different data in two or more threads concurrently. Pipeline
   parallelism is epitomised by the `prefetch` transform, which runs the
   computation "before" the transformation on a background thread, so that all
   operations that come "after" can occur in parallel.
 - **Parallel operations on array** allow users to commpute data-parallel
   algorithms easily. Operations such as `reduce` (and friends `max`, `min`,
   `sum`, `product`, ...), `sort`, `filter`, `group`, `map` (and many more) can
   be easily parallelized across all available cores of a machine.

For more details, please check out the documentation for each type.


## Thread pool ##

From first-principles, a (CPU) compute-bound application will run at peak performance when overheads
are minimized. Once enough parallelism is exposed to leverage all cores, one of the key overheads to
minmiize is context switching, and thead creation & destruction. The optimal system configuration is
thus a fixed-size threadpool where there is exactly one thread per CPU core (or rather, hyperthread).
This configuration results in zero context switching, no additional kernel calls for thread creation &
deletion, and full utilization of the hardware.

Unfortunately, in practice, it is infeasible to statically schedule work apriori onto a fixed pool of threads.
Even when applying the same operation to a homogenous dataset, there will inevitably be variability in
execution time. (This can arise from I/O interrupts taking over a core [briefly], or page faults, or even
different latencies for memory access across NUMA domains.) As a result, it is important for peak
performance to build abstractions that are flexible and dynamic in their work allocation.

The ThreadPool protocol is a foundational API designed to enable efficient use of hardware resources.
There are two APIs exposed to support the two kinds of parallelism:

 - **prun** is used as "fire-and-forget" style parallelism where closures are
   dynamically scheduled to execute on the (fixed-size) threadpool.

 - **pJoin** is used for Cilk-style fork-join parallelism using work-stealing
   to efficiently leverage available resources on a machine. The key abstraction
   is a single function `pJoin` which takes 2 closures and runs then
   (optionally) in parallel.

Note: while there should be only one "physical" threadpool process-wide, there can be many virtual
threadpools that compose on top of this one to allow configuration and tuning. (This is why
`ThreadPool` is a protocol and not static methods.) Examples of additional threadpool abstractions
could include a separate threadpool per-NUMA domain, to support different priorities for tasks, or
higher-level parallelism primitives such as "wait-groups".
