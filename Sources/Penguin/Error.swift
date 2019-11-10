
public enum PError: Error {
    case dtypeMisMatch(have: String, want: String)
    case colCountMisMatch
    case indexSetMisMatch(lhs: Int, rhs: Int, extendingAvailable: Bool)
    case conflictingColumnName(existingName: String, columnToRename: String)
    case unknownColumn(colName: String)
    case internalInconsistency(msg: String)
}

extension PError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .indexSetMisMatch(lhs, rhs, extendingAvailable):
            var extra = ""
            if extendingAvailable {
                extra = " Consider passing `extending: true`."
            }
            return "PIndexSet sizes were not equal (\(lhs) vs \(rhs)).\(extra)"

        case .colCountMisMatch:
            return "Column count mis-match."

        case let .dtypeMisMatch(have, want):
            return "DType mis-match; have: \(have), want: \(want)."

        case let .conflictingColumnName(existingName, columnToRename):
            return """
            Cannot rename \(columnToRename) to \(existingName), as there is a column with that name already!
            If you would like to rename \(columnToRename) to \(existingName), drop the existing column first.
            """
        case let .unknownColumn(colName):
            return "Unknown column name '\(colName)'."
        case let .internalInconsistency(msg):
            return "Internal inconsistency error: \(msg)"
        }
    }
}
