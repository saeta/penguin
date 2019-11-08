
public enum PError: Error {
    case dtypeMisMatch(have: String, want: String)
    case colCountMisMatch
}
