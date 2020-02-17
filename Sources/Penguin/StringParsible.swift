import Foundation

public protocol PStringParsible {
    init?(parsing: String)
    init(parseOrThrow value: String) throws
}

extension PStringParsible {
    public init?(parsing: String) {
        do {
            self = try Self.init(parseOrThrow: parsing)
        } catch {
            return nil
        }
    }
}

extension String: PStringParsible {
    public init(parseOrThrow value: String) {
        self = value
    }
}

extension Int: PStringParsible {
    public init(parseOrThrow value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let tmp = Int(trimmed) else {
            throw PError.unparseable(value: value, type: "Int")
        }
        self = tmp
    }
}

extension Float: PStringParsible {
    public init(parseOrThrow value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let tmp = Float(trimmed) else {
            throw PError.unparseable(value: value, type: "Float")
        }
        self = tmp
    }
}

extension Double: PStringParsible {
    public init(parseOrThrow value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let tmp = Double(trimmed) else {
            throw PError.unparseable(value: value, type: "Double")
        }
        self = tmp
    }
}

extension Bool: PStringParsible {
    public init(parseOrThrow value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let tmp = Bool(trimmed) {
            self = tmp
            return
        }
        if trimmed == "t" || trimmed == "true" {
            self = true
            return
        }
        if trimmed == "f" || trimmed == "false" {
            self = false
            return
        }
        if let asInt = Int(trimmed) {
            if asInt == 0 {
                self = false
                return
            }
            if asInt == 1 {
                self = true
                return
            }
            throw PError.unparseable(value: value, type: "Bool")
        }
        throw PError.unparseable(value: value, type: "Bool")
    }
}
