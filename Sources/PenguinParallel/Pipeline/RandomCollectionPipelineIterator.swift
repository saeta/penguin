
/// Returns a random permutation of elements in collection C.
public struct RandomCollectionPipelineIterator<C: Collection, R: RandomNumberGenerator>: PipelineIteratorProtocol where C.Index == Int {
    public typealias Element = C.Element

    public init(_ c: C, _ rng: R) {
        self.c = c
        self.indices = RandomIndicesIterator(count: c.count, rng: rng)
    }


    public mutating func next() -> C.Element? {
        guard let i = indices.next() else {
            return nil
        }
        return c[i]
    }

    let c: C
    var indices: RandomIndicesIterator<R>
}
