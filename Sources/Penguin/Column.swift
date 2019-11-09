
/// A dtype-erased column of data.
public protocol PColumn {
    var count: Int { get }
    func asDType<DT: ElementRequirements>() throws -> PTypedColumn<DT>
    subscript (strAt index: Int) -> String? { get }
}

extension PColumn {
    public func asString() -> PTypedColumn<String> {
        try! asDType()
    }

    public func asInt() -> PTypedColumn<Int> {
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
}
