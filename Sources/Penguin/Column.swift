
/// A dtype-erased column of data.
public protocol PColumn {
    var count: Int { get }
    func asDType<DT: ElementRequirements>() throws -> PTypedColumn<DT>
    subscript (strAt index: Int) -> String? { get }
    subscript (indexSet: PIndexSet) -> PColumn { get }
    var nils: PIndexSet { get }
    var nonNils: PIndexSet { get }
    func hasNils() -> Bool
    func compare(lhs: Int, rhs: Int) -> PThreeWayOrdering
    @discardableResult mutating func append(_ entry: String) -> Bool
    mutating func appendNil()

    mutating func _sort(_ indices: [Int])

    // A "poor-man's" equality check (without breaking PColumn as an existential type).
    func _equals(_ rhs: PColumn) -> Bool

    // Ensure no one else can conform to PColumn other than PTypedColumn. This is to ensure
    // equality behaves in a reasonable manner, due to having to work around Swift's
    // existential type implementation.
    var _doNotConformToPColumn: _PTypedColumnToken { get }
}

extension PColumn {
    public func asString() -> PTypedColumn<String> {
        try! asDType()
    }

    public func asInt() -> PTypedColumn<Int> {
        try! asDType()
    }

    public func asDouble() -> PTypedColumn<Double> {
        try! asDType()
    }
}

extension PTypedColumn: PColumn {

    public func asDType<DT: ElementRequirements>() throws -> PTypedColumn<DT> {
        // TODO: support automatic conversion between compatible types.
        guard T.self == DT.self else {
            throw PError.dtypeMisMatch(have: String(describing: T.self), want: String(describing: DT.self))
        }
        return self as! PTypedColumn<DT>
    }

    // This extra indirection is necessary to work around a compiler bug.
    public subscript(indexSet: PIndexSet) -> PColumn {
        let tmp: PTypedColumn = self[indexSet]
        return tmp
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

    public func _equals(_ rhs: PColumn) -> Bool {
        if type(of: self) != type(of: rhs) { return false }
        let rhsC = rhs as! PTypedColumn<T>
        return self == rhsC
    }

    public var _doNotConformToPColumn: _PTypedColumnToken {
        _PTypedColumnToken()
    }
}

/// A token type that has a package-private initializer to ensure that no other type other than PTypedColumn can confirm to PColumn
public struct _PTypedColumnToken {
    fileprivate init() {}
}
