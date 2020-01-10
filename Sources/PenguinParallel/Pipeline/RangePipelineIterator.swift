/// A parallel iterator producing a sequence of integers.
///
/// RangePipelineIterator is used to produce counters or similar sequences. It
/// supports non-unit stepping to allow for more complicated sequence
/// generation.
///
/// It is often constructed using the `range` functions on `PipelineIterator`.
public struct RangePipelineIterator: PipelineIteratorProtocol {
    public typealias Element = Int

    public init(start: Int = 0, end: Int? = nil, step: Int = 1) {
        self.current = start
        self.end = end
        self.step = step
    }

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

/// A parallel sequence representing a sequence of integers.
///
/// `RangePipelineSequence` is used to produce counters or similar sequences. It
/// supports non-unit stepping to allow for more complicated sequence
/// generation.
///
/// It is often constructed using the `range` functions on `PipelineIterator`.
public struct RangePipelineSequence: PipelineSequence {
    public typealias Element = Int

    public init(start: Int = 0, end: Int? = nil, step: Int = 1) {
        self.start = start
        self.end = end
        self.step = step
    }

    public func makeIterator() -> RangePipelineIterator {
        RangePipelineIterator(start: start, end: end, step: step)
    }

    var start: Int
    let end: Int?
    let step: Int
}

public extension PipelineSequence {
    /// Adds a sequentially increasing counter to this pipeline sequence.
    ///
    /// Enumerated modifies a pipeline sequence to add a sequentially increasing
    /// counter to each element. If `self` used to return a type `Element`, the
    /// new pipeline iterator produces elements that are tuples of type
    /// `(Int, Element)`. For example, if the iterator used to produce `String`s
    /// it will now produce `(Int, String)`s.
    ///
    /// TODO: update the example below.
    ///
    /// Example:
    ///
    ///      var itr = ["aardvark", "beluga", "chimp"].makePipelineIterator().enumerated()
    ///      while let elem = try itr.next() {
    ///          print(elem)
    ///      }
    ///      // Prints "(0, aardvark)"
    ///      // Prints "(1, beluga)"
    ///      // Prints "(2, chimp)"
    ///
    func enumerated() -> Zip2PipelineSequence<RangePipelineSequence, Self> {
        Zip2PipelineSequence(RangePipelineSequence(), self)
    }
}

public extension PipelineIteratorProtocol {
    /// Adds a sequentially increasing counter to this pipeline iterator.
    ///
    /// Enumerated modifies a pipeline iterator to add a sequentially increasing
    /// counter to each element. If `self` used to return a type `Element`, the
    /// new pipeline iterator produces elements that are tuples of type
    /// `(Int, Element)`. For example, if the iterator used to produce `String`s
    /// it will now produce `(Int, String)`s.
    ///
    /// Example:
    ///
    ///      var itr = ["aardvark", "beluga", "chimp"].makePipelineIterator().enumerated()
    ///      while let elem = try itr.next() {
    ///          print(elem)
    ///      }
    ///      // Prints "(0, aardvark)"
    ///      // Prints "(1, beluga)"
    ///      // Prints "(2, chimp)"
    ///
    func enumerated() -> Zip2PipelineIterator<RangePipelineIterator, Self> {
        PipelineIterator.zip(PipelineIterator.range(), self)
    }
}

public extension PipelineIterator {
    /// Constructs a sequentially increasing counter.
    ///
    /// Example:
    ///
    ///      var itr = PipelineIterator.range(from: 1, to: 5, step: 2)
    ///      while let i = try itr.next() {
    ///          print(i)
    ///      }
    ///      // Prints 1
    ///      // Prints 3
    ///      // Prints 5
    ///
    /// - Parameter from: The start of the sequence (defaults to `0`).
    /// - Parameter to: The end of the sequence. If nil, the sequence continues
    ///   indefinitely.
    /// - Parameter step: The step size (defaults to `1`).
    /// - Returns: A pipeline iterator that will incrementally produce a sequence of
    ///   integers.
    static func range(from: Int = 0, to: Int? = nil, step: Int = 1) -> RangePipelineIterator {
        RangePipelineIterator(start: from, end: to, step: step)
    }

    /// Constructs a sequentially increasing counter covering range `range`.
    ///
    /// Example:
    ///
    ///      var itr = PipelineIterator.range(0...3)
    ///      while let i = try itr.next() {
    ///          print(i)
    ///      }
    ///      // Prints 0
    ///      // Prints 1
    ///      // Prints 2
    ///      // Prints 3
    ///
    /// - Parameter range: The range of integers to produce.
    /// - Returns: A pipeline iterator that will incrementally produce a sequence of
    ///   integers.
    static func range(_ range: ClosedRange<Int>) -> RangePipelineIterator {
        RangePipelineIterator(start: range.lowerBound, end: range.upperBound)
    }

    /// Constructs a sequentially increasing counter covering range `range`.
    ///
    /// Example:
    ///
    ///      var itr = PipelineIterator.range(0..<3)
    ///      while let i = try itr.next() {
    ///          print(i)
    ///      }
    ///      // Prints 0
    ///      // Prints 1
    ///      // Prints 2
    ///
    /// - Parameter range: The range of integers to produce.
    /// - Returns: A pipeline iterator that will incrementally produce a sequence of
    ///   integers.
    static func range(_ range: Range<Int>) -> RangePipelineIterator {
        RangePipelineIterator(start: range.lowerBound, end: range.upperBound - 1)
    }
}
