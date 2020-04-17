// Copyright 2020 Penguin Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
    guard let str = String(data: data, encoding: .utf8) else {
      throw CSVErrors.invalidFormat(filename: filename)
    }
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
      let first100Kb = UnsafeBufferPointer<UInt8>(
        start: str.baseAddress, count: Swift.min(str.count, 100_000))
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
  case invalidFormat(filename: String)
}
