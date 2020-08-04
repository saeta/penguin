# Contributing #

Contributions welcome in the form of:
 - Bug reports (with accompagnied test cases)
 - Feature requests
 - Documentation PRs
 - Feature PRs
 - Tutorials
 - Benchmarks

## Benchmarking

To run all the benchmarks:

```
swift run -c release -Xswiftc -cross-module-optimization Benchmarks
```

To run specific benchmarks:

```
swift run -c release -Xswiftc -cross-module-optimization Benchmarks --filter MyBenchmarkPattern
```

**For more detail:** see the [Performance Optimization Guide](Sources/PenguinStructures/Documentation/Guides/Perf.md).

> Coming soon: details on how to contribute.
