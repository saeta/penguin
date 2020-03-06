// Copyright 2020 Penguin Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


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
        indices!.swapAt(Int(i), Int(j))
        let outputValue = indices![Int(j)]
        return outputValue
    }

    var indices: [Int]?
    var rng: T
    var j: UInt
}

/// The `RandomIndicesPipelineSequence` will return a random permutation of the numbers in `0..<count`.
///
/// This pipeline sequence is useful for shuffling a finite set of elements.
public struct RandomIndicesPipelineSequence<T: RandomNumberGenerator>: PipelineSequence {
    public typealias Element = Int

    public init(count: Int, rng: T) {
        self.count = count
        self.rngConfig = .fixed(rng: rng)
    }

    /// Makes a PipelineIterator that generates the random permutation of the indices.
    public func makeIterator() -> RandomIndicesIterator<T> {
        // TODO: increment the seequence counter.
        let rng = rngConfig.makeRng(sequenceCounter: sequenceCounter)
        return RandomIndicesIterator(count: count, rng: rng)
    }

    let count: Int
    let rngConfig: RngConfig
    var sequenceCounter: Int = 0

    enum RngConfig {
        case fixed(rng: T)
        case changing(start: Int, gen: (Int) -> T)

        func makeRng(sequenceCounter: Int) -> T {
            switch self {
            case let .fixed(rng: rng):
                return rng
            case let .changing(start: start, gen: generator):
                return generator(start + sequenceCounter)
            }
        }
    }
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
