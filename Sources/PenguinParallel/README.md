# Penguin Parallel: Parallel abstractions #

`PenguinParallel` is a toolkit of abstractions for parallel programming. It
contains a number of small, single-purpose components that can be combined to
build higher-level abstractions.

Key abstractions include:

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
 - **pjoin** is used for Cilk-style fork-join parallelism using work-stealing
   to efficiently leverage available resources on a machine. The key abstraction
   is a single function `pjoin` which takes 2 closures and runs then
   (optionally) in parallel.

For more details, please check out the documentation for each type.
