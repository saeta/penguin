
/// Returns a random permutation of elements in collection C.
public struct RandomCollectionPipelineIterator<C: Collection, R: RandomNumberGenerator>: PipelineIteratorProtocol where C.Index == Int {
    public typealias Element = C.Element

    public init(_ c: C, _ itr: RandomIndicesIterator<R>) {
        self.c = c
        self.indices = itr
    }


    /// Returns the next random element out of the collection.
    public mutating func next() -> C.Element? {
        guard let i = indices.next() else {
            return nil
        }
        return c[i]
    }

    let c: C
    var indices: RandomIndicesIterator<R>
}

public struct RandomCollectionPipelineSequence<C: Collection, R: RandomNumberGenerator>: PipelineSequence where C.Index == Int {
    public typealias Element = C.Element

    public init(_ c: C, _ rng: R) {
        self.c = c
        self.indicesSequence = RandomIndicesPipelineSequence(count: c.count, rng: rng)
    }

    public func makeIterator() -> RandomCollectionPipelineIterator<C, R> {
        RandomCollectionPipelineIterator(c, indicesSequence.makeIterator())
    }

    let c: C
    var indicesSequence: RandomIndicesPipelineSequence<R>
}

public extension Collection where Index == Int {
    func asRandomizedPipelineSequence<R: RandomNumberGenerator>(_ rng: R) -> RandomCollectionPipelineSequence<Self, R> {
        RandomCollectionPipelineSequence(self, rng)
    }
}
