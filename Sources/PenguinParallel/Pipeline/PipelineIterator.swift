
/// A protocol for pipelined iterators that work in a streaming fashion.
public protocol PipelineIteratorProtocol {
    associatedtype Element

    mutating func next() throws -> Element?
}

/// An empty enum to hang API calls off of.
public enum PipelineIterator {

}
