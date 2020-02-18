import Foundation

public enum CSVCellParserOutput {
    case newline
    case cell(_ contents: String)
}

public struct CSVCellParser<T: IteratorProtocol>: Sequence, IteratorProtocol where T.Element == Character {
    public typealias Element = CSVCellParserOutput

    public mutating func next() -> CSVCellParserOutput? {
        if emitNewlineNext {
            emitNewlineNext = false
            return .newline
        }
        if reachedEoF { return nil }
        guard let first = underlying.next() else {
            if mustEmitCell {
                mustEmitCell = false
                emitNewlineNext = true
                return .cell("")
            }
            return nil
        }
        if first == delimiter {
            return .cell("")  // Empty string
        }
        if first == "\n" {
            if mustEmitCell {
                emitNewlineNext = true
                mustEmitCell = false
                return .cell("")
            }
            return .newline
        }
        // Unquoted cell parsing.
        if first != "\"" {
            var cellStr = "\(first)"
            while true {
                guard let char = underlying.next() else {
                    reachedEoF = true
                    break
                }
                if char == delimiter {
                    mustEmitCell = true
                    break
                }
                if char == "\n" {
                    emitNewlineNext = true
                    mustEmitCell = false
                    break
                }
                cellStr.append(char)
            }
            return .cell(cellStr)
        }
        // Quoted cell parsing.
        var escapeNextChar = false
        var cellStr = ""
        while true {
            guard let char = underlying.next() else {
                reachedEoF = true
                warn(invalidParseMessage)
                return .cell(cellStr)
            }
            if escapeNextChar {
                switch char {
                case "\\":
                    cellStr.append("\\")
                case "n":
                    cellStr.append("\n")
                case "\"":
                    cellStr.append("\"")
                default:
                    warn("Unexpected escaped character: \(char).")
                    cellStr.append("\\")
                    cellStr.append(char)
                }
                escapeNextChar = false
                continue
            } else {
                if char == "\\" {
                    escapeNextChar = true
                    continue
                }
                if char == "\"" {
                    guard let nextChar = underlying.next() else {
                        return .cell(cellStr)
                    }
                    if nextChar == delimiter {
                        mustEmitCell = true
                        return .cell(cellStr)
                    }
                    if nextChar == "\n" {
                        emitNewlineNext = true
                        return .cell(cellStr)
                    }
                    warn("Unexpected \" encountered.")
                    cellStr.append(char)
                    cellStr.append(nextChar)
                    continue
                }
                cellStr.append(char)
            }
        }
    }

    public init(underlying: T, delimiter: Character = ",", emitWarnings: Bool = false) {
        self.underlying = underlying
        self.emitWarnings = emitWarnings
        self.delimiter = delimiter
    }

    private func warn(_ msg: String) {
        if emitWarnings {
            print(msg)
        }
    }

    var emitNewlineNext = false
    var reachedEoF = false
    var mustEmitCell = false
    var underlying: T
    let emitWarnings: Bool  // TODO: convert to warning sink in some fashion.
    let delimiter: Character

    let invalidParseMessage: String = """
        Encountered the end of the sequence before reaching a closing quote while parsing \
        a quoted cell.
        """
}

public struct CSVRowParser<T: IteratorProtocol>: Sequence, IteratorProtocol where T.Element == Character {

    public mutating func next() -> [String]? {
        var row = [String]()
        while true {
            if let output = cellParser.next() {
                switch output {
                case let .cell(contents):
                    row.append(contents)
                case .newline:
                    return row
                }
            } else {
                if !row.isEmpty { return row }
                else { return nil }
            }
        }
    }

    public init(_ underlying: T, delimiter: Unicode.Scalar = ",") {
        self.cellParser = CSVCellParser(underlying: underlying, delimiter: Character(delimiter))
    }

    public init(_ underlying: CSVCellParser<T>) {
        self.cellParser = underlying
    }

    var cellParser: CSVCellParser<T>

    public static func createFromFile(file: String, fileManager: FileManager = FileManager.default) throws -> CSVRowParser<String.Iterator> {
        guard let data = fileManager.contents(atPath: file) else {
            throw CSVErrors.invalidFile(filename: file)
        }
        // TODO: support more efficient processing here.
        let str = String(decoding: data, as: UTF8.self)
        return CSVRowParser<String.Iterator>(str.makeIterator())
    }
}
