
public enum PError: Error {
    case dtypeMisMatch(have: String, want: String)
    case colCountMisMatch
    case indexSetMisMatch(lhs: Int, rhs: Int, extendingAvailable: Bool)
    case conflictingColumnName(existingName: String, columnToRename: String)
    case unknownColumn(colName: String)
    case internalInconsistency(msg: String)
    case empty(file: String)
    case unexpectedCsvColumn(expectedColCount: Int, row: [String])
    case unparseable(value: String, type: String)
    case unknownFormat(file: String)
    case duplicateColumnName(name: String, allColumns: [String])
    case unimplemented(msg: String)
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
        case let .empty(file):
            return "Empty file: \(file)."
        case let .unexpectedCsvColumn(expectedColCount, row):
            return "Expected \(expectedColCount) columns, but found \(row.count) columns; row: \(row)."
        case let .unparseable(value, type):
            return "Could not parse \"\(value)\" as \(type)."
        case let .unknownFormat(file):
            return "Unknown format of file \"\(file)\"."
        case let .duplicateColumnName(name, allColumns):
            return "Column name \"\(name)\" appears to be duplicated. (All columns: \(allColumns).)"
        case let .unimplemented(msg):
            return "Unimplemented: \(msg)."
        }
    }
}
