# Penguin #

Explore the ideas of data frames, accelerated compute, tables, and
distributed data in Swift.

## Roadmap ##

Below is the aspirational roadmap (at an extremely high level) for the high-level goals:

 - Parse from CSV.
 - Finish up base API & document it. (Incomplete list of needs: appending rows, support in-place mutations everywhere, more powerful sorting, remove unnecessary APIs)
 - Optimize `PIndexSet` representations.
 - Refactor internals around an iterator model.
 - Optimize backing store for `PTypedColumn`, including adding support for larger-than-RAM.
 - Add querying / group-by support (including support for a `PTableGroup` --- alternate names wanted).
 - Parallelize the implementation of the operators.
 - Investigate hardware acceleration & JIT code-gen.
 - Distributed orchestration of computation.

Extensions (help wanted):
 - Connect to databases.
 - Parse additional file formats.

This is not an officially supported Google product.
