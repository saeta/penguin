import Foundation

public class CSVReader: Sequence {
    public init(file filename: String, fileManager: FileManager = FileManager.default) throws {
        guard let data = fileManager.contents(atPath: filename) else {
            throw CSVErrors.invalidFile(filename: filename)
        }
        // TODO: support more efficient processing here.
        let str = String(decoding: data, as: UTF8.self)
        self.parser = CSVRowParser(str.makeIterator())
    }

    public init(contents: String) throws {
        self.parser = CSVRowParser(contents.makeIterator())
    }

    public func readAll() -> [[String]] {
        var rows = [[String]]()
        for row in parser {
            rows.append(row)
        }
        return rows
    }

    public typealias Element = [String]

    public func makeIterator() -> CSVReaderIterator {
        CSVReaderIterator(self)
    }

    fileprivate var parser: CSVRowParser<String.Iterator>
}

public struct CSVReaderIterator: IteratorProtocol {
    public typealias Element = [String]

    public mutating func next() -> [String]? {
        return reader.parser.next()
    }

    fileprivate init(_ reader: CSVReader) {
        self.reader = reader
    }
    private var reader: CSVReader
}

enum CSVErrors: Error {
    case invalidFile(filename: String)
}
