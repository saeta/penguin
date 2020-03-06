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


/// Combines two iterators of types `L` and `R` into an iterator producing elements of type `(L.Element, R.Element)`.
///
/// For additional documentation, please see `PipelineIterator`'s `zip` method.
public struct Zip2PipelineIterator<L: PipelineIteratorProtocol, R: PipelineIteratorProtocol>: PipelineIteratorProtocol {
    public typealias Element = (L.Element, R.Element)

    public init(_ lhs: L, _ rhs: R) {
        self.lhs = lhs
        self.rhs = rhs
    }

    public mutating func next() throws -> Element? {
        var errL: Error? = nil
        var errR: Error? = nil
        var lhs: L.Element? = nil
        var rhs: R.Element? = nil
        // Must pump both iterators, even if the first one errors out.
        do {
            lhs = try self.lhs.next()
        } catch {
            errL = error
        }
        do {
            rhs = try self.rhs.next()
        } catch {
            errR = error
        }
        if let err = errL {
            throw err
        }
        if let err = errR {
            throw err
        }
        if let l = lhs, let r = rhs {
            return (l, r)
        }
        return nil
    }

    var lhs: L
    var rhs: R
}

/// Combines two pipeline sequences of types `L` and `R` into a pipeline sequence with elements of type `(L.Element, R.Element)`.
///
/// For additional documentation please see `PipelineIterator`'s `zip` methods.
public struct Zip2PipelineSequence<L: PipelineSequence, R: PipelineSequence>: PipelineSequence {
    public typealias Element = (L.Element, R.Element)

    public init(_ lhs: L, _ rhs: R) {
        self.lhs = lhs
        self.rhs = rhs
    }

    public func makeIterator() -> Zip2PipelineIterator<L.Iterator, R.Iterator> {
        Zip2PipelineIterator(lhs.makeIterator(), rhs.makeIterator())
    }

    let lhs: L
    let rhs: R
}

public extension PipelineIterator {
    /// Combines two pipeline iterators together to produce a single joined sequence.
    ///
    /// Example:
    ///
    ///     var lhs = ["a", "b", "c"].makePipelineIterator()
    ///     var rhs = ["x", "y", "z"].makePipelineIterator()
    ///     var itr = PipelineIterator.zip(lhs, rhs)
    ///     while let elem = try itr.next() {
    ///         print(elem)
    ///     }
    ///     // Prints "(a, x)"
    ///     // Prints "(b, y)"
    ///     // Prints "(c, z)"
    ///
    /// Note: if either the `lhs` iterator or the `rhs` iterator throws an error,
    /// it will be passed through to the caller of `next`. If both throw errors,
    /// the left-side error will be exposed.
    ///
    /// Note: the resulting iterator will stop iterating upon reaching the end
    /// of either of the underlying iterators.
    ///
    /// - Parameter lhs: The iterator to produce the left side of the tuple.
    /// - Parameter rhs: The iterator to produce the right side of the tuple.
    /// - Returns: A single pipeline iterator that combines `lhs`, and `rhs`.
    ///   Note: `lhs` and `rhs` should not be used after passing them to `zip`.
    static func zip<L: PipelineIteratorProtocol, R: PipelineIteratorProtocol>(_ lhs: L, _ rhs: R) -> Zip2PipelineIterator<L, R> {
        Zip2PipelineIterator(lhs, rhs)
    }
}
