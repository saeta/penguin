
/// A type that supplies the value of a sequence one at a time.
///
/// Modern computers have multiple cores that make it efficient to process data in parallel.
/// While the standard swift `IteratorProtocol` is extremely versitile for general data-structures,
/// when operating on large in-memory datasets, it is often very valueable to operate on multiple cores
/// concurrently. Additionally, when operating on datasets that do not fit in memory, it is very important to
/// overlap the I/O work with the computation in order to keep all hardware components utilized.
///
/// `PipelineIteratorProtocol` is a common interface to a family of parallel compute abstractions
/// that are a twist on the standard `IteratorProtocol`. The primary mental model is that of a pipeline,
/// where the output of one iterator feeds into the input of the next. Almost all operations preserve a deterministic
/// ordering of the elements (but it's not required).
///
/// Although these transformations are broadly applicable to a variety of applications, they work extremely
/// well when building high performance input pipelines for training neural networks. We thus use neural networks as
/// a motivating example for how to use this part of the `PenguinParallel` library. When training a
/// neural network using a supervised learning algorithm, training data is:
///  (1) *read from storage* (such as a local SSD, or a remote object storage, or even in remote
///    RAM) into local memory.
///  (2) *transformed* such as decompressed or parsed, and often augmented (such as image
///    normalizaiton, or random masking of tokens in a sentence). Other transformations can occur
///    such as batching, or shuffling the order of elements.
///  (3) *output* for use in training the neural network.
///
/// To build such a pipeline using `PenguinParallel`, we start by generating a list of filenames for
/// our training data. If we have them in a sequence, we can call `.makePipelineIterator()`. If
/// there are too many to keep in memory at once, we could use `PipelineIterator.generate`
/// to generate them incrementally. If we can programmatically construct their names (e.g. if their names
/// are `training_data_1`, `training_data_2`, etc), then we could build their names by calling
/// `PipelineIterator.range(1...15).map { "training_data_\($0)" }`. (Recall,
/// the `.map` function is a higher-order function that takes a closure. This closure takes as input a
/// single argument of type `Element` and returns a single new element that is passed along to
/// subsequent transformations. Here we use Swift's short-hand for closures, where `$0` refers to
/// the 0th argument, and because the closure is only a single expressoin we can omit the `return`
/// keyword.)
///
/// We now need to read the data from storage. If there is only a single training example stored in any one
/// file, we could read it using `itr.map { ReadFromFile($0) }`. Note: this will read up to `n` files
/// in parallel. Because large datasets are often stored more efficiently with mulitple elements per file,
/// we can use `itr.interleave` to read from mulitple files in parallel and combine their aggregate
/// output.
///
/// Now that we have a paralle iterator containing our training data, we can transform it. Here, you can
/// use any arbitrary Swift (or C/C++) function you would like by calling:
/// `itr.map { transform($0) }`. If you would like to batch up mulitple elements into a single
/// element, you can call `.reduceWindow`, passing in the batch size, and a function to take an
/// iterator over the window size and returns the batched element.
///
/// Finally, in order to ensure all of this work happens in parallel with the main body of your training loop,
/// call `.prefetch()` on the resulting iterator, which will use a background thread to do as much work
/// as possible before your main loop calls `.next()`. Et voilà, we have now built a high performance
/// input pipeline for training a neural network.
///
/// There are a few differences between `PipelineIteratorProtocol` and the normal Swift
/// `IteratorProtocol`. The primary difference is that `next()` can `throw`. This is
/// important because many transformations along a pipeline can fail, such as reading a file or
/// allocating a batch output. Additionally, (by convention) `next()` should always return quickly.
/// If a lot of computation could happen, you can pipeline the work on a background thread by
/// calling `.prefetch()`.
///
/// A note on copying: `PipelineIteratorProtocol` objects should never be copied, but
/// instead only mutated in place. If you need to pass an iterator to a function, be sure to pass
/// it `inout`. (Calling `next()` on a copy of an iterator invalidates other copies of the
/// iterator, and can result in undefined behavior.)
///
/// TODO: Convert to be a move-only type when they become available in Swift.
///
/// The design of `PipelineIteratorProtocol` is heavily inspired by TensorFlow's
/// `tf.data` abstractions and their internals, generalized to support arbitrary types and
/// functions.
public protocol PipelineIteratorProtocol {

    /// The type of the elements to be produced by the iterator.
    associatedtype Element

    /// Retrieves the next element in the sequence.
    ///
    /// Note: implementations of this method are not guaranteed to be thread safe. It
    /// is up to the caller to ensure that there is only a single thread calling `next()`
    /// at a time.
    ///
    /// Invariant: Implementations of this method should ensure that it returns with
    /// low latency. If the implementation is expected to be computationally expensive
    /// the computation should be pipelined using background threads. (Consider
    /// using TransformPipelineIterator (or PrefetchPipelineIterator if your computation cannot
    /// be parallelized) as part of your implementation.)
    mutating func next() throws -> Element?
}

/// PipelineIterator contains methods that are useful for creating `PipelineIteratorProtocol` types.
///
/// Use methods on `PipelineIterator` to help start building up a pipeline iterator, such
/// as `PipelineIterator.range` or `PipelineIterator.generate`. For additional
/// details on how to use Pipeline iterators, see the documentation on `PipelineIteratorProtocol`.
public enum PipelineIterator {

}
