
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

    // TODO: Add forEach (supporting in-placee modification)
    // TODO: Add sharded fold (supporting parallel iteration)
    // TODO: Add sorting support
    // TODO: Add filtering & subsetting support
    // TODO: Add distinct()

    public var count: Int {
        impl.count
    }

    public subscript(strAt index: Int) -> String? {
        assert(index < count, "Index out of range; requested \(index), count: \(count)")
        return String(describing: impl[index])
    }

    var impl: [T]  // TODO: Switch to PTypedColumnImpl
}

public extension PTypedColumn where T: Numeric {
    func sum() -> T {
        reduce(T.zero, +)
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
        let numRows = min(count, requestedRows)
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
