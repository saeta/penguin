
Aggregations allow data to be effectively summarized. The aggregation system in Penguin has been
carefully designed to be type safe and extensible, while supporting efficient operations including
parallelization across multiple cores.

We start with the core operation: recall, aggregation operations execute across the rows of a single
column and compute a result. This behavior is represented by the protocol `AggregationOperation`.
At a high leve, the `update(with:)` method will be called once for each entry in the column being
aggregated. Once the operation has seen all the data in a given column, `finish()` is called, which
computes the result.

`AggregationOperation` is designed to be fully general, and thus both the `Input` and `Output` types
are generic, and represented with `associatedtype`'s. This means you can write an
`AggregationOperation` that takes `String`s and returns `Double`'s (e.g. computing the average
length of the strings in given column).

In order to support parallelism, the column may be divided into pieces and a separate instance of
the `AggregationOperation` may be initialized. In order to compute a single overall answer, the
`merge(with:)` method will be called until only a single instance remains, whose `finish()` method
will be called to compute the final result.

`Aggregation` and its subclasses (e.g. `ArbitraryTypedAggregation`, `NumericAggreegation`,
`StringAggregation`, ...) and`AggregationEngine`'s work together with `PTable` to efficiently
execute thee aggregation operation.

To learn how to write your own aggregation, check out the
[Custom Aggregations](custom-aggregation.html) tutorial.

<!-- TODO: explain more here! -->
