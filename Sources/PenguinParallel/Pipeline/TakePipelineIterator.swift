
public struct TakePipelineIterator<U: PipelineIteratorProtocol>: PipelineIteratorProtocol {
    public mutating func next() throws -> U.Element? {
        guard takeCount > 0 else { return nil }
        takeCount -= 1
        return try underlying.next()
    }

    var underlying: U
    var takeCount: Int
}

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
    func drop(_ count: Int) -> DropPipelineIterator<Self> {
        DropPipelineIterator(underlying: self, count: count)
    }

    func take(_ count: Int) -> TakePipelineIterator<Self> {
        TakePipelineIterator(underlying: self, takeCount: count)
    }
}
