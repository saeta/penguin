
public struct RangePipelineIterator: PipelineIteratorProtocol {
    public typealias Element = Int

    public init(start: Int = 0, end: Int? = nil, step: Int = 1) {
        self.current = start
        self.end = end
        self.step = step
    }

    public let isNextReady = true

    public mutating func next() throws -> Int? {
        if let end = end, current > end { return nil }
        let tmp = current
        current += step
        return tmp
    }

    var current: Int
    let end: Int?
    let step: Int
}

public extension PipelineIteratorProtocol {
    func enumerated() -> Zip2PipelineIterator<RangePipelineIterator, Self> {
        PipelineIterator.zip(PipelineIterator.range(), self)
    }
}

public extension PipelineIterator {
    static func range(from: Int = 0, to: Int? = nil, step: Int = 1) -> RangePipelineIterator {
        RangePipelineIterator(start: from, end: to, step: step)
    }

    static func range(_ range: ClosedRange<Int>) -> RangePipelineIterator {
        RangePipelineIterator(start: range.lowerBound, end: range.upperBound)
    }

    static func range(_ range: Range<Int>) -> RangePipelineIterator {
        RangePipelineIterator(start: range.lowerBound, end: range.upperBound - 1)
    }
}
