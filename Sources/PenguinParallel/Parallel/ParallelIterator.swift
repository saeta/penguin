
/// Document & actually implement me!
// TODO: Add methods to make this actually go in parallel. (i.e. a `split` operation.)
protocol ParallelIteratorProtocol {
    associatedtype Element

    mutating func next() throws -> Element?

    /// A precise count, used for parallelism purposes.
    var preciseCount: Int { get }
}

// TODO: Refine this, document it, and then make it public.
protocol ParallelSequence {
    associatedtype Element
    associatedtype ParallelIterator : ParallelIteratorProtocol where ParallelIterator.Element == Element

    __consuming func makeParItr() -> ParallelIterator
}

extension ParallelSequence where Self: ParallelIteratorProtocol {
    @inlinable
    __consuming func makeParItr() -> Self {
        return self
    }
}
