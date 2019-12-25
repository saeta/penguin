public struct GeneratorPipelineIterator<T>: PipelineIteratorProtocol {
    public typealias Element = T
    public typealias GenFunc = () throws -> T?

    public let isNextReady = true  // TODO(saeta): this is wrong!

    public mutating func next() throws -> T? {
        return try f()
    }

    let f: GenFunc
}

public extension PipelineIterator {
    static func generate<T>(from function: @escaping () throws -> T?) -> GeneratorPipelineIterator<T> {
        return GeneratorPipelineIterator<T>(f: function)
    }
}
