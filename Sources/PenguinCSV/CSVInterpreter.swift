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

/// CSVs often have implicit information

import Foundation

/// CSVType represents a guess as to the type of a particular column.
///
public enum CSVType: CaseIterable {
    // TODO: once it is possible to determine all linked in types that
    // have been linked into the binary, it should be straight forward to
    // make this open and extensible.

    case string
    case double
    case int
    case bool
    // TODO: add more like date/time, currency, etc.

}

/// CSVColumnMetadata represents the best guess for what is in a column.
///
///
public struct CSVColumnMetadata {
    public var name: String
    public var type: CSVType
}

public struct CSVGuess {
    @usableFromInline
    var separator: Unicode.Scalar

    @usableFromInline
    var hasHeaderRow: Bool

    public var columns: [CSVColumnMetadata]
}

/// Attempts to sniff information about a CSV.
func sniffCSV(buffer: UnsafeBufferPointer<UInt8>) throws -> CSVGuess {
    // We first attempt to split into lines.
    let lines = buffer.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: false)  // TODO: handle escape sequences.
    if lines.count < 2 { throw CSVError.tooShort }
    let separatorHeuristics = computeSeparatorHeuristics(lines[0..<lines.count])
    let separator = pickSeparator(separatorHeuristics)
    let separatorHeuristic = separatorHeuristics.first { $0.separator == separator }!
    let columnCount = separatorHeuristic.columnCount

    let fullLines: UnparsedLines
    if separatorHeuristic.incompleteLastColumn {
        fullLines = lines[0..<lines.count-1]  // Drop last line as it could be incomplete.
    } else {
        fullLines = lines[0..<lines.count]  // Keep all lines.
    }

    let columnTypeOptions = try computeColumnTypes(fullLines, separator: separator, columnCount: columnCount)
    let hasHeader = guessHasHeader(
        withFirstRowGuesses: columnTypeOptions.withFirstRow.map { $0.bestGuess },
        withoutFirstRowGuesses: columnTypeOptions.withoutFirstRow.map { $0.bestGuess })

    let columnTypes: [CSVType]
    if hasHeader {
        columnTypes = columnTypeOptions.withoutFirstRow.map { $0.bestGuess }
    } else {
        columnTypes = columnTypeOptions.withFirstRow.map { $0.bestGuess }
    }

    let columnNames: [String]
    if hasHeader {
        columnNames = try computeColumnNames(headerRow: lines[0], separator: separator, columnCount: columnCount)
    } else {
        columnNames = (0..<columnCount).map { "c\($0)" }
    }
    let columnMetadata = zip(columnTypes, columnNames).map { CSVColumnMetadata(name: $0.1, type: $0.0) }
    return CSVGuess(separator: separator, hasHeaderRow: hasHeader, columns: columnMetadata)
}

/// Attempts to sniff information about a CSV.
func sniffCSV(contents: String) throws -> CSVGuess {
    var c = contents
    return try c.withUTF8 {
        try sniffCSV(buffer: $0)
    }
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///   Internal implementation details below here!  /////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/// Possible separators, ordered by priority of likelihood.
internal let possibleSeparators: [Unicode.Scalar] = [
    ",",
    "\t",
    "|",
]

/// Information about how to parse the CSV.
internal struct SeparatorHeuristics: Equatable {
    var separator: Unicode.Scalar
    var nonEmpty: Bool
    var differentCount: Int
    var columnCount: Int
    var firstRowColumnCount: Int
    var incompleteLastColumn: Bool
}

/// UnparsedLines represents the unparsed lines in our CSVBuffer we're operating on.
///
/// The type is built up as follows:
/// 1. We start with an UnsafeBuffer of bytes (UInt8's).
/// 2. We then split it at newlines, resulting in an Array of slices of UnsafeBufferPointer's
/// 3. We then slice off the last (potentially incomplete) line, giving us the ArraySlice on the outside.
internal typealias UnparsedLines = ArraySlice<Slice<UnsafeBufferPointer<UInt8>>>

// TODO: Make more efficient & smarter!
struct CSVColumnGuesser {
    // candidate types is a mapping from a candidate type to the number of rows it was incompatible with.
    var possibleTypes = Set(CSVType.allCases)

    mutating func updateCompatibilities(cell: String) {
        var toRemove = Set<CSVType>()
        for type in possibleTypes {
            if !type.isCompatibleWith(cell) {
                toRemove.insert(type)
            }
        }
        possibleTypes.subtract(toRemove)
    }

    var bestGuess: CSVType {
        possibleTypes.max { $0.priority < $1.priority }!
    }
}

func guessHasHeader(withFirstRowGuesses: [CSVType], withoutFirstRowGuesses: [CSVType]) -> Bool {
    // If we have a column that's non-string even with the first row, we guess that there's no header.
    if withFirstRowGuesses.first(where: { $0 != .string }) != nil {
        return false
    } else {
        // If we have a column that's non-string excluding the header row, we assume there is a header.
        if withoutFirstRowGuesses.first(where: { $0 != .string }) != nil {
            return true
        } else {
            // TODO: actually look at the first row and do some more sniffing (e.g. look for repeated values, capital letters, etc.)?
            return false
        }
    }
}

func computeColumnNames(headerRow: Slice<UnsafeBufferPointer<UInt8>>, separator: Unicode.Scalar, columnCount: Int) throws -> [String] {
    let columns = headerRow.split(separator: UInt8(ascii: separator), omittingEmptySubsequences: false)
    var result = [String]()
    result.reserveCapacity(columnCount)
    for (i, col) in columns.enumerated() {
        try col.withUnsafeBytes { col in
            guard let str = String(
                bytesNoCopy: UnsafeMutableRawPointer(mutating: col.baseAddress!),
                length: col.count, encoding: .utf8, freeWhenDone: false) else {
                    throw CSVError.nonUtf8Encoding("Could not parse header for column \(i) as UTF-8.")
            }
            result.append(String(str))  // Force an extra copy.
        }
    }
    for i in result.count..<columnCount {
        result.append("col_\(i)")
    }
    return result
}

func computeColumnTypes(
    _ lines: UnparsedLines,
    separator: Unicode.Scalar,
    columnCount: Int
) throws -> (withFirstRow: [CSVColumnGuesser], withoutFirstRow: [CSVColumnGuesser]) {
    var withFirstRow = Array(repeating: CSVColumnGuesser(), count: columnCount)
    var withoutFirstRow = Array(repeating: CSVColumnGuesser(), count: columnCount)

    for (i, line) in lines.enumerated() {
        let columns = line.split(separator: UInt8(ascii: separator), omittingEmptySubsequences: false)
        if columnCount < columns.count {
            print("""
                Warning: heuristics are getting confused on line \(i). \
                (Expected count: \(columnCount), found: \(columns.count)) \
                Please file bug with steps to reproduce at: https://github.com/saeta/penguin. \
                Thanks!
                """)
            continue
        }
        for (j, col) in columns.enumerated() {
            try col.withUnsafeBytes { col in
                guard let str = String(
                    bytesNoCopy: UnsafeMutableRawPointer(mutating: col.baseAddress!),
                    length: col.count,
                    encoding: .utf8,
                    freeWhenDone: false) else {
                        throw CSVError.nonUtf8Encoding("Non-UTF8 encountered at line \(i), column \(j)")
                }
                withFirstRow[j].updateCompatibilities(cell: str)
                if i != 0 {
                    withoutFirstRow[j].updateCompatibilities(cell: str)
                }
            }
        }
    }
    return (withFirstRow, withoutFirstRow)
}

func computeSeparatorHeuristics(_ lines: UnparsedLines) -> [SeparatorHeuristics] {
    precondition(!lines.isEmpty, "No lines to parse!")
    return possibleSeparators.map { separator in
        // TODO: make more efficient && handle escape sequences.
        let colCounts = lines.map { $0.split(separator: UInt8(ascii: separator), omittingEmptySubsequences: false).count }
        let nonEmpty = colCounts.allSatisfy { $0 > 1 } || colCounts[0..<colCounts.count-1].allSatisfy { $0 > 1 }
        var differentCount = 0
        for count in colCounts {
            if count != colCounts.first {
                differentCount += 1
            }
        }
        let columnCount = colCounts.max()!
        return SeparatorHeuristics(
            separator: separator,
            nonEmpty: nonEmpty,
            differentCount: differentCount,
            columnCount: columnCount,
            firstRowColumnCount: colCounts.first!,
            incompleteLastColumn: colCounts.last! != columnCount)
    }
}

func pickSeparator(_ heuristics: [SeparatorHeuristics]) -> Unicode.Scalar {
    return heuristics.first { $0.nonEmpty && $0.differentCount == 0 }.map { $0.separator } ??
        heuristics.filter { $0.nonEmpty }.sorted { $0.differentCount < $1.differentCount }.first.map { $0.separator } ??
        possibleSeparators.first!
}

extension CSVType {
    /// Priority signifies which types are more precise.
    ///
    /// Because everything can be represented by a string, we ensure
    var priority: Int {
        switch self {
        case .string: return 0
        case .double: return 10
        case .int: return 100
        case .bool: return 50
        }
    }

    func isCompatibleWith(_ element: String) -> Bool {
        guard !element.isEmpty else { return true }
        switch self {
        case .string: return true
        case .double: return Self.match(element, Self.doubleRegex)
        case .int: return Self.match(element, Self.intRegex)
        case .bool: return Self.match(element, Self.boolRegex)
        }
    }

    private static func match(_ elem: String, _ regex: NSRegularExpression) -> Bool {
        return regex.firstMatch(in: elem, range: NSRange(location: 0, length: elem.utf8.count)) != nil
    }

    private static let boolRegex = try! NSRegularExpression(pattern: """
        ^     # Must match at the beginning.
        \\s*  # Optional whitespace at the beginning.
        (?:   # Non-capturing group of potential patterns.
          (?:[Tt](?:[Rr][Uu][Ee])?)       # Match t or true (any capitalization)
        |
          (?:[Ff](?:[Aa][Ll][Ss][Ee])?)   # Match f or false (any capitalization)
        |
          (?:0|1)                         # Match 0 or 1
        )?    # End non-capturing group.
        \\s*  # Optional whitespace at the end
        $     # Must match at the end.
        """, options: [.allowCommentsAndWhitespace])
    private static let doubleRegex = try! NSRegularExpression(pattern: """
        ^     # Must match at the beginning.
        \\s*  # Optional whitespace at the beginning
        (?:   # Non-capturing group of potential patterns.
          (?:-?\\d+(\\.\\d*)?)  # Match a decimal digit
        |
          (?:[Nn][Aa][Nn])      # Match NaN (any case)
        |
          (?:-?[Ii][Nn][Ff])    # Match Inf (any case)
        )?    # End non-capturing group.
        \\s*  # Optional whitespace at the end
        $     # Must match at the end.
        """, options: [.allowCommentsAndWhitespace])
    // TODO: consider something that's potentially more efficient than regexes.
    private static let intRegex = try! NSRegularExpression(pattern: #"^\s*-?\d+\s*$"#)
}
