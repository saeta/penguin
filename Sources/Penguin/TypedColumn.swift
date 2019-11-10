
public typealias ElementRequirements = Equatable & Hashable & Comparable


public struct PTypedColumn<T: ElementRequirements>: Equatable, Hashable {
    public init(_ contents: [T]) {
        impl = contents
    }

    public func map<U>(_ transform: (T) throws -> U) rethrows -> PTypedColumn<U> {
        let newData = try impl.map(transform)
        return PTypedColumn<U>(newData)
    }

    public func reduce(_ initial: T, _ reducer: (T, T) throws -> T) rethrows -> T {
        return try impl.reduce(initial, reducer)
    }

    // TODO: Add forEach (supporting in-place modification)
    // TODO: Add sharded fold (supporting parallel iteration)
    // TODO: Add sorting support
    // TODO: Add filtering & subsetting support
    // TODO: Add distinct()

    public var count: Int {
        impl.count
    }

    public subscript(index: Int) -> T {
        assert(index < count, "Index out of range; request \(index), count: \(count)")
        return impl[index]
    }

    public subscript(indexSet: PIndexSet) -> PTypedColumn {
        assert(indexSet.count == count,
               "Count mismatch; indexSet.count: \(indexSet.count); TypedColumn count: \(count)")
        var newImpl = [T]()
        newImpl.reserveCapacity(indexSet.setCount)
        for i in 0..<count {
            if indexSet[i] {
                newImpl.append(impl[i])
            }
        }
        return PTypedColumn(newImpl)
    }

    public subscript(strAt index: Int) -> String? {
        assert(index < count, "Index out of range; requested \(index), count: \(count)")
        return String(describing: impl[index])
    }

    public static func == (lhs: PTypedColumn, rhs: T) -> PIndexSet {
        var bits = Array(repeating: false, count: lhs.count)
        var numSet = 0
        for i in 0..<lhs.count {
            if lhs[i] == rhs {
                bits[i] = true
                numSet += 1
            }
        }
        return PIndexSet(bits, setCount: numSet)
    }

    public static func != (lhs: PTypedColumn, rhs: T) -> PIndexSet {
        return !(lhs == rhs)
    }

    public func filter(_ body: (T) -> Bool) -> PIndexSet {
        var bits = [Bool]()
        bits.reserveCapacity(count)
        var numSet = 0
        for i in 0..<count {  // TODO: Convert to using an iterator / parallel iterators. (Here and elsewhere.)
            let val = body(self[i])
            bits.append(val)
            numSet += val.asInt
        }
        return PIndexSet(bits, setCount: numSet)
    }

    var impl: [T]  // TODO: Switch to PTypedColumnImpl
}

public extension PTypedColumn where T: Numeric {
    func sum() -> T {
        reduce(T.zero, +)
    }
}

extension PTypedColumn where T: Comparable {
    public func min() -> T {
        reduce(self[0]) {
            if $0 < $1 { return $0 } else { return $1 }
        }
    }

    public func max() -> T {
        reduce(self[0]) {
            if $0 > $1 { return $0 } else { return $1 }
        }
    }

    fileprivate static func forEachToIndex(_ lhs: PTypedColumn, _ rhs: T, _ op: (T, T) -> Bool) -> PIndexSet {
        var bits = Array(repeating: false, count: lhs.count)
        var numSet = 0
        for i in 0..<lhs.count {
            if op(lhs[i], rhs) {
                bits[i] = true
                numSet += 1
            }
        }
        return PIndexSet(bits, setCount: numSet)
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
