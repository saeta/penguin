
public enum PError: Error {
    case dtypeMisMatch(have: String, want: String)
    case colCountMisMatch
    case indexSetMisMatch(lhs: Int, rhs: Int, extendingAvailable: Bool)
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
        }
    }
}
