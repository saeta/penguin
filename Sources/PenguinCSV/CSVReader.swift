import Foundation

public class CSVReader: Sequence {
    public init(file filename: String, fileManager: FileManager = FileManager.default) throws {
        guard fileManager.isReadableFile(atPath: filename) else {
            throw CSVErrors.invalidFile(filename: filename)
        }
        guard let data = fileManager.contents(atPath: filename) else {
            throw CSVErrors.invalidFile(filename: filename)
        }
        // TODO: support more efficient processing here.
        let str = String(decoding: data, as: UTF8.self)
        self.metadata = try? Self.sniffMetadata(contents: str)
        self.parser = CSVRowParser(str.makeIterator(), delimiter: metadata?.separator ?? ",")
    }

    public init(contents: String) throws {
        self.metadata = try? Self.sniffMetadata(contents: contents)
        self.parser = CSVRowParser(contents.makeIterator(), delimiter: metadata?.separator ?? ",")
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
        if self.metadata?.hasHeaderRow ?? false {
            _ = parser.next()  // Strip off the header row.
        }
        return CSVReaderIterator(self)
    }

    private static func sniffMetadata(contents: String) throws -> CSVGuess {
        var str = contents
        return try str.withUTF8 { str in
            let first100Kb = UnsafeBufferPointer<UInt8>(start: str.baseAddress, count: Swift.min(str.count, 100_000))
            return try sniffCSV(buffer: first100Kb)
        }
    }

    fileprivate var parser: CSVRowParser<String.Iterator>
    public let metadata: CSVGuess?
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
