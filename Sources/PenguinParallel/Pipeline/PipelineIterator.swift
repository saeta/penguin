
/// A protocol for pipelined iterators that work in a streaming fashion.
///
/// TODO: Convert to be a move-only type when they become available in Swift.
public protocol PipelineIteratorProtocol {
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

/// An empty enum to hang API calls off of.
public enum PipelineIterator {

}
