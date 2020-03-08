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


import PenguinCSV

public typealias ElementRequirements = Comparable & Hashable & PDefaultInit & PStringParsible & PCSVParsible

public struct PTypedColumn<T: ElementRequirements>: Equatable {
    public init(_ contents: [T]) {
        self.impl = PTypedColumnImpl(contents)
        self.nils = PIndexSet(all: false, count: contents.count)
    }

    public init(_ contents: [Optional<T>]) {
        impl = PTypedColumnImpl()
        impl.reserveCapacity(contents.count)
        var indexSet = [Bool]()
        indexSet.reserveCapacity(contents.count)
        var setCount = 0

        for elem in contents {
            if let elem = elem {
                impl.append(elem)
                indexSet.append(false)
            } else {
                impl.append(T())
                indexSet.append(true)
                setCount += 1
            }
        }
        self.nils = PIndexSet(indexSet, setCount: setCount)
    }

    init(_ contents: [T], nils: PIndexSet) {
        self.impl = PTypedColumnImpl(contents)
        self.nils = nils
    }

    init(empty: T.Type) {
        self.impl = PTypedColumnImpl<T>()
        self.nils = PIndexSet(all: false, count: 0)
    }

    init(impl: PTypedColumnImpl<T>, nils: PIndexSet) {
        self.impl = impl
        self.nils = nils
    }

    public func map<U>(_ transform: (T) throws -> U) rethrows -> PTypedColumn<U> {
        var newImpl = [U]()
        newImpl.reserveCapacity(impl.count)
        var newNils = [Bool]()
        newNils.reserveCapacity(impl.count)
        var nilSetCount = 0

        for (i, cell) in impl.enumerated() {
            if nils[i] {
                newImpl.append(U())
                newNils.append(true)
                nilSetCount += 1
            } else {
                try newImpl.append(transform(cell))
                newNils.append(false)
            }
        }
        return PTypedColumn<U>(newImpl, nils: PIndexSet(newNils, setCount: nilSetCount))
    }

    public func reduce(_ initial: T, _ reducer: (T, T) throws -> T) rethrows -> T {
        var acc = initial
        for (isNil, elem) in zip(nils.impl, impl) {
            if !isNil {
                acc = try reducer(acc, elem)
            }
        }
        return acc
    }

    var firstNonNil: T? {
        for (isNil, elem) in zip(nils.impl, impl) {
            if !isNil {
                return elem
            }
        }
        return nil
    }

    // TODO: Add forEach (supporting in-place modification)
    // TODO: Add sharded fold (supporting parallel iteration)
    // TODO: Add distinct()

    public var count: Int {
        impl.count
    }

    public subscript(index: Int) -> Optional<T> {
        get {
            assert(index < count, "Index out of range; request \(index), count: \(count).")
            if self.nils[index] { return nil }
            return self.impl[index]
        }
        set {
            assert(index < count, "Index out of range; request \(index), count: \(count).")
            if let newValue = newValue {
                self.nils[index] = false
                self.impl[index] = newValue
            } else {
                self.nils[index] = true
                self.impl[index] = T()
            }
        }
    }

    public subscript(indexSet: PIndexSet) -> PTypedColumn {
        assert(indexSet.count == count,
               "Count mismatch; indexSet.count: \(indexSet.count); TypedColumn count: \(count)")
        var newImpl = [T]()
        var newNils = [Bool]()
        var nilsCount = 0
        newImpl.reserveCapacity(indexSet.setCount)
        newNils.reserveCapacity(indexSet.setCount)
        for i in 0..<count {
            if indexSet[i] {
                newNils.append(nils[i])
                if nils[i] { nilsCount += 1 }
                newImpl.append(impl[i])
            }
        }
        return PTypedColumn(newImpl, nils: PIndexSet(newNils, setCount: nilsCount))
    }

    public subscript(strAt index: Int) -> String? {
        assert(index < count, "Index out of range; requested \(index), count: \(count)")
        if self.nils[index] {
            return "<nil>"
        }
        return String(describing: impl[index])
    }

    public static func == (lhs: PTypedColumn, rhs: T) -> PIndexSet {
        forEachToIndex(lhs, rhs, ==)
    }

    public static func != (lhs: PTypedColumn, rhs: T) -> PIndexSet {
        forEachToIndex(lhs, rhs, !=)
    }

    public func filter(_ body: (T) -> Bool) -> PIndexSet {
        var bits = [Bool]()
        bits.reserveCapacity(count)
        var numSet = 0
        for i in 0..<count {  // TODO: Convert to using an iterator / parallel iterators. (Here and elsewhere.)
            if nils[i] {
                bits.append(false)
            } else {
                let val = body(impl[i])
                bits.append(val)
                numSet += val.asInt
            }
        }
        return PIndexSet(bits, setCount: numSet)
    }

    public func compare(lhs: Int, rhs: Int) -> PThreeWayOrdering {
        // Put the nil's at the end.
        switch (self.nils[lhs], self.nils[rhs]) {
        case (true, true): return .eq
        case (false, true): return .lt
        case (true, false): return .gt
        case (false, false): break
        }
        if impl[lhs] == impl[rhs] {
            return .eq
        }
        return impl[lhs] < impl[rhs] ? .lt : .gt
    }

    public mutating func _sort(_ indices: [Int]) {
        self.nils.sort(indices)
        self.impl.sort(indices)
    }

    public func hasNils() -> Bool {
        !nils.isEmpty
    }

    public var nonNils: PIndexSet {
        !nils
    }

    @discardableResult public mutating func append(_ entry: String) -> Bool {
        guard let tmp = T(parsing: entry) else {
            nils.append(true)
            impl.append(T())
            return false
        }
        nils.append(false)
        impl.append(tmp)
        return true
    }

    public mutating func appendNil() {
        nils.append(true)
        impl.append(T())
    }

    @discardableResult public mutating func append(_ cell: CSVCell) -> Bool {
        guard let tmp = T(cell) else {
            nils.append(true)
            impl.append(T())
            return false
        }
        nils.append(false)
        impl.append(tmp)
        return true
    }

    mutating func optimize() {
        impl.optimize()
    }

    var impl: PTypedColumnImpl<T>
    public internal(set) var nils: PIndexSet
}

public extension PTypedColumn where T: Numeric {
    func sum() -> T {
        reduce(T.zero, +)
    }
}

extension PTypedColumn where T: Comparable {
    public func min() -> T {
        reduce(firstNonNil!) { // TODO: Fix me!
            if $0 < $1 { return $0 } else { return $1 }
        }
    }

    public func max() -> T {
        reduce(firstNonNil!) { // TODO: Fix me!
            if $0 > $1 { return $0 } else { return $1 }
        }
    }

    public static func < (lhs: PTypedColumn, rhs: T) -> PIndexSet {
        return forEachToIndex(lhs, rhs, <)
    }

    public static func <= (lhs: PTypedColumn, rhs: T) -> PIndexSet {
        return forEachToIndex(lhs, rhs, <=)
    }

    public static func > (lhs: PTypedColumn, rhs: T) -> PIndexSet {
        return forEachToIndex(lhs, rhs, >)
    }

    public static func >= (lhs: PTypedColumn, rhs: T) -> PIndexSet {
        return forEachToIndex(lhs, rhs, >=)
    }
}

public extension PTypedColumn where T: DoubleConvertible {
    func avg() -> Double {
        sum().asDouble / Double(count)
    }

    func numericSummary() -> PColumnSummary {
        return computeNumericSummary(impl, nils)
    }
}

public extension PTypedColumn where T == String {
    func stringSummary() -> PColumnSummary {
        return computeStringSummary(impl, nils)
    }
}

extension PTypedColumn: CustomStringConvertible {
    public var description: String {
        "\(makeHeader())\n\(makeString())"
    }

    func makeHeader() -> String {
        "i\t\(String(describing: T.self))"
    }

    func makeString(maxCount requestedRows: Int = 10) -> String {
        let numRows = Swift.min(count, requestedRows)
        var buf = ""
        for i in 0..<numRows {
            buf.append("\(i)\t\(self[strAt: i] ?? "")\n")
        }
        return buf
    }

}

fileprivate func forEachToIndex<T>(_ lhs: PTypedColumn<T>, _ rhs: T, _ op: (T, T) -> Bool) -> PIndexSet {
    var bits = [Bool]()
    bits.reserveCapacity(lhs.count)
    var numSet = 0
    for i in 0..<lhs.count {
        if lhs.nils[i] {
            bits.append(false)
            continue
        }
        if op(lhs.impl[i], rhs) {
            bits.append(true)
            numSet += 1
        } else {
            bits.append(false)
        }
    }
    return PIndexSet(bits, setCount: numSet)
}

/// PTypedColumnImpl encapsulates a variety of different implementation representations of the logical column.
///
/// This type is used as part of the implementation of Penguin.
enum PTypedColumnImpl<T: ElementRequirements>: Equatable, Hashable {
    // TODO: Include additional backing stores, such as:
    //  - Arrow-backed
    //  - File-backed
    //  - ...

    /// An array-backed implementation of a column.
    case array(_ contents: [T])

    /// A special-case optimization for a column of identical values.
    case constant(_ value: T, _ count: Int)

    /// A subset of an existing column.
    ///
    /// Note: we intentionally only support a single layer of nesting!
    case subset(underlying: [T], range: Range<Int>)

    /// For large heap-objects (e.g. strings), it can be valuable to "de-dupe"
    /// or "intern" the objects, as this saves memory and can enable some
    /// optimizations for certain operations.
    case encoded(_ encoder: Encoder<T>, _ handles: [EncodedHandle])

    public init(_ contents: [T]) {
        self = .array(contents)
    }

    public init() {
        self = .array([])
    }

    mutating func reserveCapacity(_ capacity: Int) {
        if case var .array(contents) = self {
            self = .constant(T(), 0)  // Must overwrite self!
            contents.reserveCapacity(capacity)
            self = .array(contents)
            return
        }
        if case .encoded(let encoder, var handles) = self {
            self = .constant(T(), 0)  // Must overwrite self!
            handles.reserveCapacity(capacity)
            self = .encoded(encoder, handles)
            return
        }
    }

    subscript(index: Int) -> T {
        get {
            switch self {
            case let .array(contents):
                return contents[index]
            case let .constant(value, count):
                assert(index >= 0 && index < count,
                       "index \(index) is out of range.")
                return value
            case let .subset(underlying, range):
                let trueIndex = range.startIndex + index
                return underlying[trueIndex]
            case let .encoded(encoding, handles):
                let handle = handles[index]
                return encoding[decode: handle]
            }
        }
        _modify {
            if case var .array(contents) = self {
                self = .constant(T(), 0) // Must overwrite self!
                yield &contents[index]
                self = .array(contents)
                return
            }
            if case let .constant(value, count) = self {
                var newValue = value
                yield &newValue
                if newValue != value {
                    var arr = Array(repeating: value, count: count)
                    arr[index] = newValue
                    self = .array(arr)
                }
                return
            }
            if case let .subset(underlying, range) = self {
                var arr = Array(underlying[range])
                yield &arr[index]
                self = .array(arr)
                return
            }
            if case var .encoded(encoder, handles) = self {
                self = .constant(T(), 0)  // Must overwrite self!
                var value = encoder[decode: handles[index]]
                yield &value
                handles[index] = encoder[encode: value]
                return
            }
            fatalError("Unimplemented for \(self)")
        }
    }

    mutating func optimize() {
        if T.self == String.self {
            if case let .array(contents) = self {
                let strs = Set(contents[0..<1000])
                if strs.count == 1 {
                    self = .constant(strs.first!, contents.count)
                } else if strs.count < 500 {
                    // 50% savings... convert to encoded representation.
                    self = .constant(T(), 1)  // Must overwrite self!
                    var encoder = Encoder<T>()
                    var handles = [EncodedHandle]()
                    handles.reserveCapacity(contents.count)
                    for elem in contents {
                        let encoded = encoder[encode: elem]
                        handles.append(encoded)
                    }
                    self = .encoded(encoder, handles)
                }
            }
        }
        if case let .array(contents) = self {
            if !contents.isEmpty && contents.allSatisfy({ $0 == contents.first }) {
                self = .constant(contents.first!, contents.count)
                return
            }
        }
        // TODO: add more optimizations
    }

    mutating func sort(_ indices: [Int]) {
        if case .constant(_, _) = self {
            return
        }
        if case let .subset(underlying, range) = self {
            self = .array(Array(underlying[range]))
            // Fall through intentional!
        }
        if case let .array(contents) = self {
            assert(indices.count == contents.count,
                   "contents: \(contents.count), indices: \(indices.count)")
            var newContents = [T]()
            newContents.reserveCapacity(count)
            for index in indices {
                newContents.append(contents[index])
            }
            self = .array(newContents)
            return
        }
        if case let .encoded(encoder, handles) = self {
            self = .constant(T(), 0)  // Must overwrite self!
            assert(handles.count == indices.count)
            var newHandles = [EncodedHandle]()
            newHandles.reserveCapacity(indices.count)
            for index in indices {
                newHandles.append(handles[index])
            }
            self = .encoded(encoder, newHandles)
            return
        }
        fatalError("Unimplemented!")
    }

    var count: Int {
        switch self {
        case let .array(contents):
            return contents.count
        case let .constant(_, count):
            return count
        case let .subset(_, range):
            return range.count
        case let .encoded(_, handles):
            return handles.count
        }
    }

    mutating func append(_ elem: T) {
        // Note: we use this implementation instead of a switch, or else we're
        // accidentally quadratic!
        if case var .array(contents) = self {
            self = .constant(T(), 0)  // Must overwrite self!
            contents.append(elem)
            self = .array(contents)
            return
        }
        if case let .constant(value, count) = self {
            if elem == value {
                self = .constant(value, count + 1)
            } else {
                var arr = Array(repeating: value, count: count)
                arr.append(elem)
                self = .array(arr)
            }
            return
        }
        if case let .subset(underlying, range) = self {
            var arr = Array(underlying[range])  // Make our own array.
            arr.append(elem)
            self = .array(arr)
            return
        }
        if case var .encoded(encoder, handles) = self {
            self = .constant(T(), 0)  // Must overwrite self!
            let encoded = encoder[encode: elem]
            handles.append(encoded)
            self = .encoded(encoder, handles)
            return
        }
        fatalError("Unimplemented append for \(self)!")
    }
}

extension PTypedColumnImpl: Collection {
    typealias Element = T
    typealias Index = Int
    var startIndex: Int { 0 }
    var endIndex: Int { count }
    func index(after i: Int) -> Int { i + 1 }

    typealias SubSequence = PTypedColumnImpl
    subscript(bounds: Range<Int>) -> PTypedColumnImpl {
        switch self {
        case let .array(contents):
            return .subset(underlying: contents, range: bounds)
        case let .constant(value, _):
            return .constant(value, bounds.count)
        case let .subset(underlying, existingRange):
            assert(bounds.lowerBound + bounds.count < existingRange.count)
            let newBase = existingRange.lowerBound + bounds.lowerBound
            let newEnd = existingRange.lowerBound + bounds.upperBound
            let newRange = newBase..<newEnd
            return .subset(underlying: underlying, range: newRange)
        case let .encoded(encoder, handles):
            let handleSubset = Array(handles[bounds])
            return .encoded(encoder, handleSubset)
        }
    }

    // TODO: Implement custom iterator!
}

/// Represents an encoded value
struct EncodedHandle: Equatable, Hashable {
    var value: UInt32

    static var nilHandle: EncodedHandle {
        EncodedHandle(value: UInt32.max)
    }
}

/// Encodes hashable values T into a dense integer representation.
struct Encoder<T: ElementRequirements>: Equatable, Hashable {

    /// Encodes the mapping from T to the encoded handles.
    private var forward = [T: EncodedHandle]()
    private var reverse = [T]()

    subscript(encode value: T) -> EncodedHandle {
        mutating get {
            assertInvariants()
            if let found = forward[value] {
                return found
            }
            let index = UInt32(reverse.count)
            let encoded = EncodedHandle(value: index)
            forward[value] = encoded
            reverse.append(value)
            return encoded
        }
    }

    subscript(decode value: EncodedHandle) -> T {
        return reverse[Int(value.value)]
    }

    private func assertInvariants() {
        assert(forward.count == reverse.count)
        assert(forward.count < UInt32.max)
    }
}
