
/// Generates a random purmutation  of the integers `0` to `count`.
///
/// Internally, it uses a variation of the Fisher-Yates shuffle to ensure an unbaised sequence (assuming
/// the underlying random number generator is itself unbiased).
public struct RandomIndicesIterator<T: RandomNumberGenerator>: PipelineIteratorProtocol {
    public typealias Element = Int
    public init(count: Int, rng: T) {
        precondition(count > 1, "count must be > 1; got \(count).")
        indices = Array(0..<count)
        self.rng = rng
        j = UInt(count)
    }

    public mutating func next() -> Int? {
        guard indices != nil else {
            return nil
        }
        if j == 1 {
            let val = indices![0]
            self.indices = nil  // Free the array; iteration complete.
            return val
        }
        let i = rng.next(upperBound: j)
        j -= 1
        // Note: we use force unwrapping to ensure no extra copies of the array are made.
        if i != j {
            let tmp = indices![Int(i)]
            indices![Int(i)] = indices![Int(j)]
            indices![Int(j)] = tmp
        }
        let outputValue = indices![Int(j)]
        return outputValue
    }

    var indices: [Int]?
    var rng: T
    var j: UInt
}

extension PipelineIteratorProtocol {
    /// Runs the iterator, collecting the outputs into an array.
    public mutating func collect() throws -> [Element] {
        var output = [Element]()
        while let elem = try next() {
            output.append(elem)
        }
        return output
    }
}
