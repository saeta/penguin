
public typealias ElementRequirements = Comparable & Hashable & PDefaultInit & PStringParsible

public struct PTypedColumn<T: ElementRequirements>: Equatable {
    public init(_ contents: [T]) {
        self.impl = contents
        self.nils = PIndexSet(all: false, count: contents.count)
    }

    public init(_ contents: [Optional<T>]) {
        impl = []
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
        self.impl = contents
        self.nils = nils
    }

    init(empty: T.Type) {
        self.impl = Array<T>()
        self.nils = PIndexSet(all: false, count: 0)
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
        var newImpl = [T]()
        newImpl.reserveCapacity(count)
        for i in 0..<count {
            newImpl.append(impl[indices[i]])
        }
        self.nils.sort(indices)
        self.impl = newImpl
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

    var impl: [T]  // TODO: Switch to PTypedColumnImpl
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
indirect enum PTypedColumnImpl<T: ElementRequirements>: Equatable, Hashable {
    // TODO: Include additional backing stores, such as:
    //  - Arrow-backed
    //  - File-backed
    //  - ...

    /// An array-backed implementation of a column.
    case array(_ contents: [T])
    /// A special-case optimization for a column of identical values.
    case constant(_ value: T, _ count: Int)
    /// A subset of an existing column.
    case subset(underlying: PTypedColumnImpl<T>, range: Range<Int>)

    public init(_ contents: [T]) {
        self = .array(contents)
    }
}
