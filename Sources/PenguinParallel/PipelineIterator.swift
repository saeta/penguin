
/// A protocol for pipelined iterators that work in a streaming fashion.
public protocol PipelineIteratorProtocol {
    associatedtype Element

    var nextIsReady: Bool { get }

    mutating func next() throws -> Element?
}

