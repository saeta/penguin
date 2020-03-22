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

/// PIndexSet represents a (non-strict) subset of indices of a column or table.
///
/// PIndexSet is used for masking and other operations on a `PTypedColumn`, a `PColumn`, and a
/// `PTable`. A `PIndexSet` is most often created via operations on the column types, such as
/// `PColumn`'s `nils` property, which returns a `PIndexSet` representing all the indices (rows)
/// containing nils.
///
/// To help catch errors, operations on `PIndexSet`s check to ensure they represent collections of
/// the same size. e.g. When a `PIndexSet` is used to select rows out of a `PTable`, the `count`
/// property of the `PIndexSet` is checked to ensure it is exactly equal to the `PTable`'s `count`
/// property.
///
/// `PIndexSet` supports both in-place and chaining set operations.
public struct PIndexSet: Equatable {

    /// Initializes a `PIndexSet` given a set of indices.
    ///
    /// - Parameter indices: The indices to include in the set.
    /// - Parameter count: The number of rows this `PIndexSet` covers.
    public init(indices: [Int], count: Int) {
        self.impl = Array(repeating: false, count: count)
        self.setCount = indices.count
        for index in indices {
            self.impl[index] = true
        }
    }

    /// Initializes a `PIndexSet` where every index is set to `value`.
    ///
    /// - Parameter value: Every index is included when `value` is true. If `value` is false, then
    ///   no indices are included.
    /// - Parameter count: The number of rows in this `PIndexSet`.
    public init(all value: Bool, count: Int) {
        // TODO: Optimize internal representation!
        self.impl = Array(repeating: value, count: count)
        self.setCount = value ? count : 0
    }

    init(_ bitset: [Bool], setCount: Int) {
        self.setCount = setCount
        self.impl = bitset
    }

    init(empty dummy: Bool) {
        self.init(all: false, count: 0)
    }

    /// Include all indices in `rhs` into `self`.
    public mutating func union(_ rhs: PIndexSet, extending: Bool? = nil) throws {
        if count != rhs.count {
            if extending == nil || extending == false {
                throw PError.indexSetMisMatch(lhs: count, rhs: rhs.count, extendingAvailable: extending == nil)
            }
            self.impl.reserveCapacity(max(count, rhs.count))
        }
        let unionStop = min(count, rhs.count)
        var newSetCount = 0
        for i in 0..<unionStop {
            let newValue = self.impl[i] || rhs.impl[i]
            newSetCount += newValue.asInt
            self.impl[i] = newValue
        }
        if count < rhs.count {
            self.impl.append(contentsOf: rhs.impl[unionStop...])
            for i in unionStop..<rhs.impl.count {
                newSetCount += rhs.impl[i].asInt
            }
        } else {
            for i in unionStop..<impl.count {
                newSetCount += impl[i].asInt
            }
        }
        self.setCount = newSetCount
    }

    /// Return a new `PIndexSet` that includes all indices from both `self` and `rhs`.
    public func unioned(_ rhs: PIndexSet, extending: Bool? = nil) throws -> PIndexSet {
        var copy = self
        try copy.union(rhs, extending: extending)
        return copy
    }

    /// Retain only indicies in both `self` and `rhs.
    public mutating func intersect(_ rhs: PIndexSet, extending: Bool? = nil) throws {
        if count != rhs.count {
            if extending == nil || extending == false {
                throw PError.indexSetMisMatch(lhs: count, rhs: rhs.count, extendingAvailable: extending == nil)
            }
            self.impl.reserveCapacity(rhs.count)
        }
        let intersectionStop = min(count, rhs.count)
        let newSize = max(count, rhs.count)
        var newSetCount = 0
        for i in 0..<intersectionStop {
            let newValue = self.impl[i] && rhs.impl[i]
            newSetCount += newValue.asInt
            self.impl[i] = newValue
        }
        self.setCount = newSetCount
        if count < rhs.count {
            for _ in intersectionStop..<newSize {
                self.impl.append(false)
            }
        } else {
            for i in intersectionStop..<newSize {
                self.impl[i] = false
            }
        }
    }

    /// Return a new `PIndexSet` that includes only indices in both `self` and `rhs`.
    public func intersected(_ rhs: PIndexSet, extending: Bool? = nil) throws -> PIndexSet {
        var copy = self
        try copy.intersect(rhs, extending: extending)
        return copy
    }

    /// Return a new `PIndexSet` where all indices included in `a` are excluded, and all excluded
    /// in `a` are included.
    public static prefix func ! (a: PIndexSet) -> PIndexSet {
        let bitSet = a.count - a.setCount
        if bitSet == 0 {
            return PIndexSet(Array(repeating: false, count: a.count), setCount: 0)
        }
        if bitSet == a.count {
            return PIndexSet(Array(repeating: false, count: a.count), setCount: a.count)
        }
        var newSet = [Bool]()
        newSet.reserveCapacity(a.count)
        for b in a.impl {
            newSet.append(!b)
        }
        return PIndexSet(newSet, setCount: bitSet)
    }

    /// Total size of the collection represented by the `PIndexSet`.
    ///
    /// Note: this should not be confused with the number of indices set within the `PIndexSet`.
    public var count: Int {
        impl.count
    }

    /// Returns `true` if there is at least one index included in this `PIndexSet`, false otherwise.
    public var isEmpty: Bool {
        setCount == 0
    }

    /// Returns true if the index `i` is included in the set, false otherwise.
    subscript(i: Int) -> Bool {
        get {
            impl[i]
        }
        set {
            impl[i] = newValue
        }
    }

    /// Grows the `count` of `self` by 1, and includes the final index in the set iff `value`.
    mutating func append(_ value: Bool) {
        impl.append(value)
        if value {
            setCount += 1
        }
    }

    /// Rearrange `self` such that `afterSelf[i] == beforeSelf[indices[i]]`.
    mutating func gather(_ indices: [Int]) {
        var newImpl = [Bool]()
        newImpl.reserveCapacity(impl.count)
        for index in indices {
            newImpl.append(impl[index])
        }
        self.impl = newImpl
    }

    /// Rearrange `self` such that `afterSelf[i] == beforeSelf[indices[i]]`.
    func gathering(_ indices: [Int]) -> Self {
        var copy = self
        copy.gather(indices)
        return copy
    }

    /// Similar to `gathering`, except if `indices[i]` is `nil`, then the index is always included.
    ///
    /// This behavior is helpful when using `PIndexSet` as a `nil`-set.
    func gathering(_ indices: [Int?]) -> PIndexSet {
        // TODO: Optimize me!
        var setCount = 0
        var output = [Bool]()
        output.reserveCapacity(indices.count)
        for index in indices {
            if let index = index {
                let isSet = impl[index]
                if isSet {
                    setCount += 1
                }
                output.append(isSet)
            } else {
                setCount += 1
                output.append(true)
            }
        }
        return Self(output, setCount: setCount)
    }

    public private(set) var setCount: Int
    var impl: [Bool]  // TODO: support alternate representations.
}

extension PIndexSet {
    func makeIterator() -> PIndexSetIterator<Array<Bool>.Iterator> {
        PIndexSetIterator(underlying: impl.makeIterator())
    }
}

// We don't want to make public key APIs on PIndexSet that would be required
// if we were to conform PIndexSet to the Collection protocol. So instead we
// implement our own iterator.
struct PIndexSetIterator<Underlying: IteratorProtocol>: IteratorProtocol where Underlying.Element == Bool {
    mutating func next() -> Bool? {
        underlying.next()
    }

    var underlying: Underlying
}


extension Bool {
    var asInt: Int {
        switch self {
        case false:
            return 0
        case true:
            return 1
        }
    }
}
