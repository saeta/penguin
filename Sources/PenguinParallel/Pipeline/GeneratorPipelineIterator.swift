public struct FunctionGeneratorPipelineIterator<T>: PipelineIteratorProtocol {
    public typealias Element = T
    public typealias GenFunc = () throws -> T?

    public mutating func next() throws -> T? {
        return try f()
    }

    let f: GenFunc
}

public extension PipelineIterator {
    /// Constructs a pipeline iterator type from a generator function.
    ///
    /// Use `PipelineIterator.generate` to build a pipeline iterator that will repeatedly
    /// call the function to produce a sequence. The function should return `nil` to signal the
    /// end of the sequence.
    ///
    /// Example:
    ///
    ///       var counter = 0
    ///       var itr = PipelineIterator.fromFunction(Int.self) {
    ///           counter += 1
    ///           return counter
    ///       }
    ///
    /// Note: if the function is expected to be expensive, it's often a good idea to call `.prefetch()`
    /// on the returned iterator.
    static func fromFunction<T>(_ typeHint: T.Type, _ function: @escaping () throws -> T?) -> FunctionGeneratorPipelineIterator<T> {
        return FunctionGeneratorPipelineIterator<T>(f: function)
    }

    /// Constructs a pipeline iterator type from a generator function.
    ///
    /// Use `PipelineIterator.generate` to build a pipeline iterator that will repeatedly
    /// call the function to produce a sequence. The function should return `nil` to signal the
    /// end of the sequence.
    ///
    /// Example:
    ///
    ///       func loadRemoteData() -> Int? {
    ///           return makeRpcToRemoteServerForData()
    ///       }
    ///       var itr = PipelineIterator.fromFunction(loadRemoteData)
    ///
    /// Note: if the function is expected to be expensive, it's often a good idea to call `.prefetch()`
    /// on the returned iterator.
    static func fromFunction<T>(_ function: @escaping() throws -> T?) -> FunctionGeneratorPipelineIterator<T> {
        return FunctionGeneratorPipelineIterator<T>(f: function)
    }
}
