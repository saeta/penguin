
public enum CSVError: Error {
    case tooShort
    case nonUtf8Encoding(_ addlInfo: String? = nil)
}

