
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

fileprivate func buffer_psum<T: Numeric>(_ buff: UnsafeBufferPointer<T>) -> T {
    if buff.count < 10 {
        return buff.reduce(0, +)
    }
    let middle = buff.count / 2
    let lhs = buff[0..<middle]
    let rhs = buff[middle..<buff.count]
    var lhsSum = T.zero
    var rhsSum = T.zero
    pjoin({ lhsSum = buffer_psum(UnsafeBufferPointer(rebasing: lhs))},
          { rhsSum = buffer_psum(UnsafeBufferPointer(rebasing: rhs))})
    return lhsSum + rhsSum
}

public extension Array where Element: Numeric {
    func psum() -> Element {
        withUnsafeBufferPointer { buff in
            buffer_psum(buff)
        }
    }
}
