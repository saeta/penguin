
/// ...
// TODO: Add methods to make this actually go in parallel.
public protocol ParallelIteratorProtocol {
    associatedtype Element

    mutating func next() throws -> Element?

    /// A precise count, used for parallelism purposes.
    var preciseCount: Int { get }
}

public protocol ParallelSequence {
    associatedtype Element
    associatedtype ParallelIterator : ParallelIteratorProtocol where ParallelIterator.Element == Element

    __consuming func makeParItr() -> ParallelIterator
}

extension ParallelSequence where Self: ParallelIteratorProtocol {
    @inlinable
    public __consuming func makeParItr() -> Self {
        return self
    }
}
