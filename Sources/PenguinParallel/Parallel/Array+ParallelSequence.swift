
fileprivate func buffer_psum<Pool: ThreadPool, T: Numeric>(
    _ pool: Pool,
    _ buff: UnsafeBufferPointer<T>
) -> T {
    if buff.count < 1000 {  // TODO: tune this constant
        return buff.reduce(0, +)
    }
    let middle = buff.count / 2
    let lhs = buff[0..<middle]
    let rhs = buff[middle..<buff.count]
    var lhsSum = T.zero
    var rhsSum = T.zero
    pool.pJoin({ _ in lhsSum = buffer_psum(pool, UnsafeBufferPointer(rebasing: lhs))},
               { _ in rhsSum = buffer_psum(pool, UnsafeBufferPointer(rebasing: rhs))})
    return lhsSum + rhsSum
}

public extension Array where Element: Numeric {
    /// Computes the sum of all the elements in parallel.
    func psum() -> Element {
        withUnsafeBufferPointer { buff in
            buffer_psum(NaiveThreadPool.global,  // TODO: Take defaulted-arg & thread local to allow for composition!
                        buff)
        }
    }
}

fileprivate func buffer_pmap<Pool: ThreadPool, T, U>(
    pool: Pool,
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
    pool.pJoin({ _ in buffer_pmap(pool: pool,
                                  source: UnsafeBufferPointer(rebasing: srcLower),
                                  dest: UnsafeMutableBufferPointer(rebasing: dstLower),
                                  mapFunc: mapFunc)},
               { _ in buffer_pmap(pool: pool,
                                  source: UnsafeBufferPointer(rebasing: srcUpper),
                                  dest: UnsafeMutableBufferPointer(rebasing: dstUpper),
                                  mapFunc: mapFunc)})
}

public extension Array {

    /// Makes a new array, where every element in the new array is `f(self[i])` for all `i` in `0..<count`.
    ///
    /// Note: this function applies `f` in parallel across all available threads on the local machine.
    func pmap<T>(_ f: (Element) -> T) -> Array<T> {
        // TODO: support throwing.
        withUnsafeBufferPointer { selfBuffer in
            Array<T>(unsafeUninitializedCapacity: count) { destBuffer, cnt in
                cnt = count
                buffer_pmap(
                    pool: NaiveThreadPool.global,  // TODO: Take a defaulted-arg / pull from threadlocal for better composition!
                    source: selfBuffer,
                    dest: destBuffer,
                    mapFunc: f
                )
            }
        }
    }
}
