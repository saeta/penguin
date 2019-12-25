
/// TransformPipelineIterator is used to run arbitrary user-supplied transformations in a pipelined fashion.
///
/// The transform function should return nil to skip the element.
// TODO: Add threading to pipeline the transformation!
public class TransformPipelineIterator<Underlying: PipelineIteratorProtocol, Output>: PipelineIteratorProtocol {
    public typealias Element = Output
    public typealias TransformFunction = (Underlying.Element) throws -> Output?

    public init(_ underlying: Underlying, transform: @escaping TransformFunction) {
        self.underlying = underlying
        self.transform = transform
    }

    public /* mutating */ func next() throws -> Output? {
        while true {
            guard let n = try underlying.next() else { return nil }
            guard let out = try transform(n) else { continue }
            return out
        }
    }

    var underlying: Underlying
    var transform: TransformFunction
}

public extension PipelineIteratorProtocol {
    func map<T>(f: @escaping (Element) throws -> T) -> TransformPipelineIterator<Self, T> {
        TransformPipelineIterator(self, transform: f)
    }

    func filter(f: @escaping (Element) throws -> Bool) -> TransformPipelineIterator<Self, Element> {
        TransformPipelineIterator(self) {
            if try f($0) { return $0 } else { return nil }
        }
    }

    func compactMap<T>(f: @escaping (Element) throws -> T?) -> TransformPipelineIterator<Self, T> {
        TransformPipelineIterator(self, transform: f)
    }
}
