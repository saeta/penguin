public struct ReduceWindowPipelineIterator<Underlying: PipelineIteratorProtocol, Output>: PipelineIteratorProtocol {
    public typealias Element = Output
    public typealias ReduceFunction = (inout Iterator) throws -> Output

    /// Note: copying this iterator outside of the function will result in undefined behavior!
    public struct Iterator: PipelineIteratorProtocol {
        public mutating func next() throws -> Underlying.Element? {
            guard !parent.pointee.encounteredNil else {
                return nil
            }
            count -= 1
            if count < 0 { return nil }
            let elem = try parent.pointee.underlying.next()
            if elem == nil {
                parent.pointee.encounteredNil = true
            }
            return elem
        }

        mutating func finishConsuming() {
            while count != 0 {
                do {
                    let tmp = try next()
                    if tmp == nil {
                        return
                    }
                } catch {
                    // Ignored.
                }
            }
        }

        let parent: UnsafeMutablePointer<ReduceWindowPipelineIterator<Underlying, Output>>
        var count: Int
    }

    public mutating func next() throws -> Output? {
        guard !encounteredNil else { return nil }
        var itr = Iterator(parent: &self, count: windowSize)
        defer { itr.finishConsuming() }
        return try f(&itr)
    }

    var underlying: Underlying
    let windowSize: Int
    let f: ReduceFunction
    var encounteredNil: Bool = false
}

extension PipelineIteratorProtocol {
    public func reduceWindow<T>(
        windowSize: Int,
        f: @escaping (inout ReduceWindowPipelineIterator<Self, T>.Iterator) throws -> T
    ) -> PrefetchPipelineIterator<ReduceWindowPipelineIterator<Self, T>> {
        return ReduceWindowPipelineIterator(underlying: self, windowSize: windowSize, f: f).prefetch()
    }

    public func naiveBatch(size: Int) -> PrefetchPipelineIterator<ReduceWindowPipelineIterator<Self, [Element]>> {
        return ReduceWindowPipelineIterator(
            underlying: self,
            windowSize: size,
            f: { itr in return try itr.collect() }
        ).prefetch(1)
    }
}
