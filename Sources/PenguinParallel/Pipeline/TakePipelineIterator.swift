/// Truncates an underlying iterator to the first `takeCount` elements.
///
/// For more documentation, please see `PipelineIteratorProtocol`'s `take` method.
public struct TakePipelineIterator<U: PipelineIteratorProtocol>: PipelineIteratorProtocol {
    public mutating func next() throws -> U.Element? {
        guard takeCount > 0 else { return nil }
        takeCount -= 1
        return try underlying.next()
    }

    var underlying: U
    var takeCount: Int
}

/// Skips the first `count` elements of an underlying iterator.
///
/// For more documentation, please see `PipelineIteratorProtocol`'s `drop` method.
public struct DropPipelineIterator<U: PipelineIteratorProtocol>: PipelineIteratorProtocol {

    public mutating func next() throws -> U.Element? {
        while count > 0 {
            _ = try? underlying.next()
            count -= 1
        }
        return try underlying.next()
    }

    var underlying: U
    var count: Int
}

public extension PipelineIteratorProtocol {
    // TODO: include examples in this documentation.

    /// Drops the first `count` elements of the current iterator.
    ///
    /// - Parameter count: The number of elements to drop.
    func drop(_ count: Int) -> DropPipelineIterator<Self> {
        DropPipelineIterator(underlying: self, count: count)
    }

    /// Truncates the current iterator to the first `count` elements.
    ///
    /// - Parameter count: The number of elements to keep.
    func take(_ count: Int) -> TakePipelineIterator<Self> {
        TakePipelineIterator(underlying: self, takeCount: count)
    }
}
