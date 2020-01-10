import Dispatch

public struct SequencePipelineIterator<T: Sequence>: PipelineIteratorProtocol {
    public typealias Element = T.Element
    typealias UnderlyingIterator = T.Iterator

    init(underlying: T, name: String) {
        self.underlying = underlying.makeIterator()
        self.queue = DispatchQueue(label: "PenguinParallel.PipelineSequence.\(name)")
    }

    public mutating func next() throws -> Element? {
        // Ensure access to the underlying iterator is thread safe.
        return queue.sync {
            underlying.next()
        }
    }

    var underlying: UnderlyingIterator
    let queue: DispatchQueue
}

public struct SequencePipelineSequence<T: Sequence>: PipelineSequence {
    public typealias Element = T.Element
    typealias UnderlyingIterator = T.Iterator

    init(underlying: T, name: String) {
        self.underlying = underlying
        self.name = name
    }

    public func makeIterator() -> SequencePipelineIterator<T> {
        SequencePipelineIterator(underlying: underlying, name: name)
    }

    let underlying: T
    let name: String
}

public extension Sequence {

    func asPipelineSequence(
        name: String? = nil,
        file: StaticString = #file,
        function: StaticString = #function,
        line: Int = #line
    ) -> SequencePipelineSequence<Self> {
        return SequencePipelineSequence(underlying: self, name: name ?? "\(file):\(line):\(function).")
    }

    func makePipelineIterator(
        name: String? = nil,
        file: StaticString = #file,
        function: StaticString = #function,
        line: Int = #line
    ) -> SequencePipelineIterator<Self> {
        return SequencePipelineIterator(underlying: self, name: name ?? "\(file):\(line):\(function)")
    }
}
