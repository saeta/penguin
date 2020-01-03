
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
    if buff.count < 1000 {  // TODO: tune this constant
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

fileprivate func buffer_pmap<T, U>(
    source: UnsafeBufferPointer<T>,
    dest: UnsafeMutableBufferPointer<U>,
    mapFunc: (T) -> U
) {
    assert(source.count == dest.count)

    var threshold = 1000  // TODO: tune this constant
    assert({ threshold = 10; return true }(), "Hacky workaround for no #if OPT.")

    if source.count < threshold {
        for i in 0..<source.count {
            dest[i] = mapFunc(source[i])
        }
        return
    }
    let middle = source.count / 2
    let srcLower = source[0..<middle]
    let dstLower = dest[0..<middle]
    let srcUpper = source[middle..<source.count]
    let dstUpper = dest[middle..<source.count]
    pjoin({ buffer_pmap(source: UnsafeBufferPointer(rebasing: srcLower),
                        dest: UnsafeMutableBufferPointer(rebasing: dstLower),
                        mapFunc: mapFunc)},
          { buffer_pmap(source: UnsafeBufferPointer(rebasing: srcUpper),
                        dest: UnsafeMutableBufferPointer(rebasing: dstUpper),
                        mapFunc: mapFunc)})
}

public extension Array {
    // TODO: support throwing.
    func pmap<T>(_ f: (Element) -> T) -> Array<T> {
        withUnsafeBufferPointer { selfBuffer in
            Array<T>(unsafeUninitializedCapacity: count) { destBuffer, cnt in
                cnt = count
                buffer_pmap(source: selfBuffer, dest: destBuffer, mapFunc: f)
            }
        }
    }
}
