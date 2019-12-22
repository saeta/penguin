
public struct ArrayParallelIterator<T>: ParallelIteratorProtocol {
    public typealias Element = T

    var underlying: [T]
    var currentIndex: Int
    var maxIndex: Int

    public mutating func next() throws -> T? {
        guard currentIndex < maxIndex else { return nil }
        let elem = underlying[currentIndex]
        currentIndex += 1
        return elem
    }

    public var preciseCount: Int {
        underlying.count
    }

}

extension Array: ParallelSequence {
    __consuming public func makeParItr() -> ArrayParallelIterator<Element> {
        return ArrayParallelIterator(underlying: self, currentIndex: 0, maxIndex: count)
    }
}
