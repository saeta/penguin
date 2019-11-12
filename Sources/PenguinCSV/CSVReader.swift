import Foundation

public class CSVReader {
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

    // TODO: support more effective incremental parsing / handling of data.

    private var parser: CSVRowParser<String.Iterator>
}

enum CSVErrors: Error {
    case invalidFile(filename: String)
}
