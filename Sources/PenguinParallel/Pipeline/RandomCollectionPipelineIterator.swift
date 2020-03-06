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
