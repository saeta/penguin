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

public enum CSVCell {
    case empty
    case raw(_ ptr: UnsafeBufferPointer<UInt8>)
    case escaped(_ s: String)
}

/// CSVProcessor allows for efficient processing of CSV and related files.
///
/// The design of CSVProcessor attempts to avoid any more than a single copy of the
/// data (in expectation). CSVProcessor can only be used once. To re-read the file, you
/// must create a new CSVProcessor.
public class CSVProcessor {
    // Contents of the file are read in batches from the `InputStream`
    // into the buffer. Upon initialization, the first few bytes are
    // used to sniff the format of the file. From then on, data is
    // parsed in place and passed to the user's function to do
    // whatever it would like to do with the data. It is up to the user
    // to ensure that the strings parsed from the data do not excape the
    // call to `f`.

    public init(
        fileAtPath: String,
        bufferSize: Int = CSVProcessor.defaultBufferSize
    ) throws {
        guard let inputStream = InputStream(fileAtPath: fileAtPath) else {
            throw CSVProcessorErrors.invalidFile(filename: fileAtPath)
        }
        inputStream.open()
        guard inputStream.hasBytesAvailable else {
            throw CSVProcessorErrors.invalidFile(filename: fileAtPath)
        }

        self.input = .stream(inputStream)

        buffer = UnsafeMutableBufferPointer.allocate(capacity: bufferSize)
        validBufferBytes = inputStream.read(
            buffer.baseAddress!,
            maxLength: buffer.count)

        if validBufferBytes > 100_000 {
            // Only look at the first 100kb.
            let truncated = UnsafeBufferPointer<UInt8>(
                start: buffer.baseAddress,
                count: 100_000)
            metadata = try sniffCSV(buffer: truncated)
        } else {
            metadata = try sniffCSV(buffer: UnsafeBufferPointer(
                start: buffer.baseAddress,
                count: validBufferBytes))
        }

    }

    public init(
        contents: String,
        bufferSize: Int? = nil
    ) throws {
        var input = Input.str(contents, offset: 0)

        let buffer: UnsafeMutableBufferPointer<UInt8>
        if let bufferSize = bufferSize {
            buffer = UnsafeMutableBufferPointer.allocate(capacity: bufferSize)
        } else {
            buffer = UnsafeMutableBufferPointer.allocate(
                capacity: contents.count - 2)  // Force a read.
        }
        validBufferBytes = input.read(buffer.baseAddress!, maxLength: buffer.count)

        self.input = input
        self.buffer = buffer
        self.metadata = try sniffCSV(buffer: UnsafeBufferPointer(
            start: buffer.baseAddress,
            count: validBufferBytes))
    }

    deinit {
        buffer.deallocate()
    }

    /// Reads all the cells and rows in the file.
    ///
    /// Note: this is very inefficient compared ot the faster forEach method.
    public func readAll() throws -> [[String]] {
        var contents = [[String]]()
        try forEach { (row, i) in
            var rowCopy = [String]()
            rowCopy.reserveCapacity(row.count)
            for i in row {
                switch i {
                case .empty:
                    rowCopy.append("")
                case let .escaped(str):
                    rowCopy.append(str)
                case let .raw(buf):
                    guard let s = String(
                        bytesNoCopy: UnsafeMutableRawPointer(
                            mutating: buf.baseAddress!),
                        length: buf.count,
                        encoding: .utf8,
                        freeWhenDone: false) else {
                        rowCopy.append(String("<non-utf8 string>"))
                        continue
                    }
                    rowCopy.append(String(s))  // Make a copy.
                }
            }
            contents.append(rowCopy)
        }
        return contents
    }

    /// Calls `f` for each row in the CSV file.
    ///
    /// The buffer pointers passed to `f` must not escape or be used once `f`
    /// has returned. If the data must be persisted, a copy must be made.
    ///
    /// If a cell is empty, the buffer pointer will be nil.
    ///
    /// - Throws: forEach throws if any of the following occur: (1) if the CSVProcessor has
    ///   already been used to traverse the file, (2) if `f` throws, or (3) if the file is not UTF-8
    ///   formatted.
    @inlinable
    public func forEach(f: ([CSVCell], Int) throws -> Void) throws {
        assert(metadata.separator.isASCII)
        guard buffer.count != 0 else { throw CSVProcessorErrors.reused }
        var cellArray = [CSVCell]()
        var parsedValidRow = false
        cellArray.reserveCapacity(metadata.columns.count)
        if metadata.hasHeaderRow {
            parsedValidRow = try parseRow(
                cellArray: &cellArray, row: 0)
            cellArray.removeAll(keepingCapacity: true)
        }
        var rowCount = 0
        while true {
            parsedValidRow = try parseRow(
                cellArray: &cellArray,
                row: rowCount)
            if !parsedValidRow { return }
            try f(cellArray, rowCount)
            rowCount += 1
        }
    }


    /// Parses a row from the buffer.
    ///
    /// This function parses a row out of buf starting at offset and stores the
    /// string references into cellArray.
    ///
    /// - Returns: true iff it parsed a row, false otherwise (e.g. encountered
    ///   EoF).
    @usableFromInline
    func parseRow(
        cellArray: inout [CSVCell],
        row: Int
    ) throws -> Bool {
        cellArray.removeAll(keepingCapacity: true)  // Clear cellArray

        // Encountered EoBuffer right at start.
        if offset == validBufferBytes {
            if buffer.count != validBufferBytes || buffer.count == 0 {
                // Non-full buffer... implies we've reached EoF.
                return false
            } else {
                // Refill the buffer & continue.
                try fetchNewData(lineStart: buffer.count)
                offset = 0
            }
        }

        // Incrementally scan forward, looking for the separator or the line
        // ending character, adding non-copying strings along the way.

        // The start of the line; this is important when the line spans a
        // buffer block.
        let lineStart = offset  
        rowLoop: while true {
            let cellStart = offset
            if offset == validBufferBytes {
                return try retryRow(cellArray: &cellArray, row: row, lineStart: lineStart)
            }
            // Note: we leverage the fact that all our known delimiters are
            // ASCII, and so we can use single byte patterns.
            let first = Unicode.Scalar(buffer[offset])
            switch first {
            case metadata.separator:
                // Empty cell.
                cellArray.append(.empty)
                offset += 1
                continue rowLoop
            case "\r":
                if Unicode.Scalar(buffer[offset + 1]) == "\n" {
                    offset += 2
                    return true
                } else {
                    throw CSVProcessorErrors.unexpectedCarriageReturn(
                        fileOffset: bufferStartOffset + offset, row: row)
                }
            case "\n":
                cellArray.append(.empty)
                offset += 1
                return true
            case "\"":
                // Quoted cell parsing.
                // Note: for quoted cell parsing, we can't destructively modify
                // the buffer in-place due to potentially reaching the end of
                // the buffer. As a result, we must copy the bytes out.
                var cellValue = ""
                var i = offset + 1
                cellLoop: while i < validBufferBytes {
                    let value = Unicode.Scalar(buffer[i])
                    switch value {
                    case "\"":
                        if i + 2 >= validBufferBytes && input.hasBytesAvailable {
                            // Extend the buffer.
                            try fetchNewData(lineStart: lineStart)
                            offset = 0
                            return try parseRow(
                                cellArray: &cellArray,
                                row: row)
                        }
                        let next = Unicode.Scalar(buffer[i + 1])
                        if next == metadata.separator {
                            cellArray.append(.escaped(cellValue))
                            offset = i + 2
                            if offset == validBufferBytes {
                                // Special case handling for reaching EoF.
                                cellArray.append(.empty)
                                return true
                            }
                            continue rowLoop
                        } else if i + 1 == validBufferBytes {
                            cellArray.append(.escaped(cellValue))
                            offset = i + 1  // TODO: this is not right!
                            return true
                        } else if next == "\n" || (next == "\r" && Unicode.Scalar(buffer[i+2]) == "\n") {
                            cellArray.append(.escaped(cellValue))
                            offset = i + (next == "\n" ? 2 : 3)
                            return true
                        } else {
                            throw CSVProcessorErrors.unexpectedCloseQuote(
                                fileOffset: bufferStartOffset + i,
                                row: row)
                        }
                    case "\\":
                        if i + 1 == validBufferBytes {
                            assert(input.hasBytesAvailable)
                            try fetchNewData(lineStart: lineStart)
                            offset = 0
                            return try parseRow(
                                cellArray: &cellArray,
                                row: row)
                        }
                        let next = Unicode.Scalar(buffer[i + 1])
                        cellValue.append(Character(next))
                        i += 2
                    default:
                        cellValue.append(Character(value))
                        i += 1
                    }
                }
                if !input.hasBytesAvailable {
                    // Finished the file in the middle of a cell.
                    throw CSVProcessorErrors.truncatedCell(row: row)
                }
                return try retryRow(cellArray: &cellArray, row: row, lineStart: lineStart)
            default:
                // Un-quoted cell parsing.
                cellLoop: for i in (offset+1)..<validBufferBytes {
                    let value = Unicode.Scalar(buffer[i])
                    switch value {
                    case metadata.separator:
                        let cellBuffer = UnsafeBufferPointer<UInt8>(
                            start: buffer.baseAddress! + cellStart,
                            count: i - cellStart)
                        cellArray.append(.raw(cellBuffer))
                        offset = i + 1
                        if offset == validBufferBytes {
                            if input.hasBytesAvailable {
                                // If the line started at 0, we've already
                                // attempted to re-load, so throw an error.
                                if lineStart == 0 {
                                    throw CSVProcessorErrors.rowTooLarge(row: row)
                                }
                                // Extend the array.
                                try fetchNewData(lineStart: lineStart)
                                offset = 0
                                return try parseRow(
                                    cellArray: &cellArray,
                                    row: row)
                            } else  {
                                // Special case handling for reaching EoF.
                                cellArray.append(.empty)
                                return true
                            }
                        }
                        continue rowLoop
                    case "\n":
                        let cellBuffer = UnsafeBufferPointer<UInt8>(
                            start: buffer.baseAddress! + cellStart,
                            count: i - cellStart)
                        cellArray.append(.raw(cellBuffer))
                        offset = i + 1
                        return true
                    case "\r":
                        // We're reaching beyond i, so check to make sure valid
                        // data is there.
                        if i + 1 == validBufferBytes {
                            // Extend the array.
                            try fetchNewData(lineStart: lineStart)
                            offset = 0
                            return try parseRow(
                                cellArray: &cellArray,
                                row: row)
                        }
                        if Unicode.Scalar(buffer[i + 1]) == "\n" {
                            let cellBuffer = UnsafeBufferPointer<UInt8>(
                                start: buffer.baseAddress! + cellStart,
                                count: i - cellStart)
                            cellArray.append(.raw(cellBuffer))
                            offset = i + 2
                            return true
                        } else {
                            throw CSVProcessorErrors.unexpectedCarriageReturn(
                                fileOffset: bufferStartOffset + i, row: row)
                        }
                    default:
                        continue cellLoop
                    }
                }
                if !input.hasBytesAvailable {
                    let cellBuffer = UnsafeBufferPointer<UInt8>(
                            start: buffer.baseAddress! + cellStart,
                            count: validBufferBytes - cellStart)
                    cellArray.append(.raw(cellBuffer))
                    // Signal stopping conditions.
                    offset = 0
                    buffer = UnsafeMutableBufferPointer(
                        start: buffer.baseAddress!,
                        count: 0)
                    validBufferBytes = 0
                    return true
                }
                return try retryRow(cellArray: &cellArray, row: row, lineStart: lineStart)
            }
        }
    }

    /// Fetches new data from the InputStream, preserving data from
    /// lineStart until the end of the buffer at the beeginning of
    /// the buffer.
    @usableFromInline
    func fetchNewData(
        lineStart: Int
    ) throws {
        assert(
            validBufferBytes == buffer.count,
            "buffer.count: \(buffer.count), validBufferBytes: \(validBufferBytes)"
        )
        let moveCount = buffer.count - lineStart
        bufferStartOffset += buffer.count - moveCount
        memmove(buffer.baseAddress!, buffer.baseAddress! + lineStart, moveCount)
        let readCount = input.read(
            buffer.baseAddress! + moveCount,
            maxLength:  buffer.count - moveCount)
        validBufferBytes = readCount + moveCount
    }

    @usableFromInline
    func retryRow(
        cellArray: inout [CSVCell], row: Int, lineStart: Int
    ) throws -> Bool {
        // If the line started at 0, we've already attempted to re-load,
        // so throw an error.
        if lineStart == 0 {
            throw CSVProcessorErrors.rowTooLarge(row: row)
        }
        // Extend the array.
        try fetchNewData(lineStart: lineStart)
        offset = 0
        return try parseRow(
            cellArray: &cellArray,
            row: row)
    }

    public let metadata: CSVGuess

    @usableFromInline
    var input: Input

    @usableFromInline
    var buffer: UnsafeMutableBufferPointer<UInt8>

    @usableFromInline
    var offset = 0

    @usableFromInline
    var bufferStartOffset: Int = 0

    @usableFromInline
    var validBufferBytes: Int

    public static var defaultBufferSize = 4 << 20  // ~4 MB
}

@usableFromInline
enum Input {
    case stream(_ inputStream: InputStream)
    case str(_ contents: String, offset: Int)

    mutating func read(
        _ buf: UnsafeMutablePointer<UInt8>,
        maxLength: Int) -> Int {
        switch self {
        case let .stream(stream):
            return stream.read(buf, maxLength: maxLength)
        case let .str(contents, offset):
            var c = contents  // Must make a copy.
            let readAmt = c.withUTF8 { src -> Int in
                let readBytes = min(maxLength, src.count - offset)
                memcpy(buf, src.baseAddress! + offset, readBytes)
                return readBytes
            }
            self = .str(c, offset: offset + readAmt)
            return readAmt
        }
    }
    var hasBytesAvailable: Bool {
        switch self {
        case let .stream(stream):
            return stream.hasBytesAvailable
        case let .str(contents, offset):
            var c = contents
            return c.withUTF8 {
                return $0.count > offset
            }
        }
    }
}

public enum CSVProcessorErrors: Error {
    case reused
    case invalidFile(filename: String)
    case unexpectedCarriageReturn(fileOffset: Int, row: Int)
    case unexpectedCloseQuote(fileOffset: Int, row: Int)
    case rowTooLarge(row: Int)
    case nonUtf8(row: Int)
    case truncatedCell(row: Int)
}
