import Foundation

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
                rowCopy.append(String(i))
            }
            contents.append(rowCopy)
        }
        return contents
    }

    /// Calls `f` for each row in the CSV file.
    ///
    /// The strings passed to `f` must not escape or be used once `f` has returned. If the
    /// strings must be persisted, a copy must be made.
    ///
    /// - Throws: forEach throws if any of the following occur: (1) if the CSVProcessor has
    ///   already been used to traverse the file, (2) if `f` throws, or (3) if the file is not UTF-8
    ///   formatted.
    @inlinable
    public func forEach(f: ([String], Int) throws -> Void) throws {
        assert(metadata.separator.isASCII)
        guard buffer.count != 0 else { throw CSVProcessorErrors.reused }
        var offset = 0
        var cellArray = [String]()
        var parsedValidRow = false
        cellArray.reserveCapacity(metadata.columns.count)
        if metadata.hasHeaderRow {
            parsedValidRow = try parseRow(
                buf: &buffer, offset: &offset, cellArray: &cellArray, row: 0)
            cellArray.removeAll(keepingCapacity: true)
        }
        var rowCount = 0
        while true {
            parsedValidRow = try parseRow(
                buf: &buffer,
                offset: &offset,
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
        buf: inout UnsafeMutableBufferPointer<UInt8>,
        offset: inout Int,
        cellArray: inout [String],
        row: Int
    ) throws -> Bool {
        cellArray.removeAll(keepingCapacity: true)  // Clear cellArray

        // Encountered EoBuffer right at start.
        if offset == validBufferBytes {
            if buf.count != validBufferBytes || buf.count == 0 {
                // Non-full buffer... implies we've reached EoF.
                return false
            } else {
                // Refill the buffer & continue.
                try fetchNewData(buf: &buf, lineStart: buf.count)
                offset = 0
            }
        }

        // Incrementally scan forward, looking for the separator or the line
        // ending character, adding non-copying strings along the way.

        // The start of the line; this is important when the line spans a
        // buffer block.
        let lineStart = offset  
        var cellStart = lineStart
        rowLoop: while true {
            // Note: we leverage the fact that all our known delimiters are
            // ASCII, and so we can use single byte patterns.
            let first = Unicode.Scalar(buf[offset])
            switch first {
            case metadata.separator:
                // Empty cell.
                cellArray.append("")
                offset += 1
            case "\r":
                if Unicode.Scalar(buf[offset + 1]) == "\n" {
                    offset += 2
                    return true
                } else {
                    throw CSVProcessorErrors.unexpectedCarriageReturn(
                        fileOffset: bufferStartOffset + offset, row: row)
                }
            case "\n":
                cellArray.append("")
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
                    let value = Unicode.Scalar(buf[i])
                    switch value {
                    case "\"":
                        if i + 2 >= validBufferBytes && input.hasBytesAvailable {
                            // Extend the buffer.
                            try fetchNewData(buf: &buf, lineStart: lineStart)
                            offset = 0
                            return try parseRow(
                                buf: &buf,
                                offset: &offset,
                                cellArray: &cellArray,
                                row: row)
                        }
                        let next = Unicode.Scalar(buf[i + 1])
                        if next == metadata.separator {
                            cellArray.append(cellValue)
                            offset = i + 2
                            cellStart = offset
                            if offset == validBufferBytes {
                                // Special case handling for reaching EoF.
                                cellArray.append("")
                                return true
                            }
                            continue rowLoop
                        } else if next == "\n" || (next == "\r" && Unicode.Scalar(buf[i+2]) == "\n") {
                            cellArray.append(cellValue)
                            offset = i + (next == "\n" ? 2 : 3)
                            return true
                        } else {
                            throw CSVProcessorErrors.unexpectedCloseQuote(
                                fileOffset: bufferStartOffset + i,
                                row: row)
                        }
                    case "\\":
                        let next = Unicode.Scalar(buf[i + 1])
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
                // If the line started at 0, we've already attempted to re-load,
                // so throw an error.
                if lineStart == 0 {
                    throw CSVProcessorErrors.rowTooLarge(row: row)
                }
                // Extend the array.
                try fetchNewData(buf: &buf, lineStart: lineStart)
                offset = 0
                return try parseRow(
                    buf: &buf,
                    offset: &offset,
                    cellArray: &cellArray,
                    row: row)
            default:
                // Un-quoted cell parsing.
                cellLoop: for i in (offset+1)..<validBufferBytes {
                    let value = Unicode.Scalar(buf[i])
                    switch value {
                    case metadata.separator:
                        guard let cellStr = String(
                            bytesNoCopy: buf.baseAddress! + cellStart,
                            length: i - cellStart,
                            encoding: .utf8,
                            freeWhenDone: false) else {
                            throw CSVProcessorErrors.nonUtf8(row: row)
                        }
                        cellArray.append(cellStr)
                        offset = i + 1
                        cellStart = offset
                        if offset == validBufferBytes {
                            if input.hasBytesAvailable {
                                // If the line started at 0, we've already
                                // attempted to re-load, so throw an error.
                                if lineStart == 0 {
                                    throw CSVProcessorErrors.rowTooLarge(row: row)
                                }
                                // Extend the array.
                                try fetchNewData(buf: &buf, lineStart: lineStart)
                                offset = 0
                                return try parseRow(
                                    buf: &buf,
                                    offset: &offset,
                                    cellArray: &cellArray,
                                    row: row)
                            } else  {
                                // Special case handling for reaching EoF.
                                cellArray.append("")
                                return true
                            }
                        }
                        continue rowLoop
                    case "\n":
                        guard let cellStr = String(
                            bytesNoCopy: buf.baseAddress! + cellStart,
                            length: i - cellStart,
                            encoding: .utf8,
                            freeWhenDone: false) else {
                            throw CSVProcessorErrors.nonUtf8(row: row)
                        }
                        cellArray.append(cellStr)
                        offset = i + 1
                        return true
                    case "\r":
                        if Unicode.Scalar(buf[i + 1]) == "\n" {
                            guard let cellStr = String(
                                bytesNoCopy: buf.baseAddress! + cellStart,
                                length: i - cellStart - 1,
                                encoding: .utf8,
                                freeWhenDone: false) else {
                                throw CSVProcessorErrors.nonUtf8(row: row)
                            }
                            cellArray.append(cellStr)
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
                    guard let cellStr = String(
                        bytesNoCopy: buf.baseAddress! + cellStart,
                        length: validBufferBytes - cellStart,
                        encoding: .utf8,
                        freeWhenDone: false) else {
                        throw CSVProcessorErrors.nonUtf8(row: row)
                    }
                    cellArray.append(cellStr)
                    // Signal stopping conditions.
                    offset = 0
                    buf = UnsafeMutableBufferPointer(
                        start: buf.baseAddress!,
                        count: 0)
                    validBufferBytes = 0
                    return true
                }
                // If the line started at 0, we've already attempted to re-load,
                // so throw an error.
                if lineStart == 0 {
                    throw CSVProcessorErrors.rowTooLarge(row: row)
                }
                // Extend the array.
                try fetchNewData(buf: &buf, lineStart: lineStart)
                offset = 0
                return try parseRow(
                    buf: &buf,
                    offset: &offset,
                    cellArray: &cellArray,
                    row: row)
            }

            if !input.hasBytesAvailable {
                if !cellArray.isEmpty {
                    return true
                } else {
                    return false  // No data.
                }
            }
            // If the line started at 0, we've already attempted to re-load,
            // so throw an error.
            if lineStart == 0 {
                throw CSVProcessorErrors.rowTooLarge(row: row)
            }
            // Extend the array.
            try fetchNewData(buf: &buf, lineStart: lineStart)
            offset = 0
            return try parseRow(
                buf: &buf,
                offset: &offset,
                cellArray: &cellArray,
                row: row)
        }
    }

    /// Fetches new data from the InputStream, preserving data from
    /// lineStart until the end of the buffer at the beeginning of
    /// the buffer.
    @usableFromInline
    func fetchNewData(
        buf: inout UnsafeMutableBufferPointer<UInt8>,
        lineStart: Int
    ) throws {
        assert(
            validBufferBytes == buf.count,
            "buf.count: \(buf.count), validBufferBytes: \(validBufferBytes)"
        )
        let moveCount = buf.count - lineStart
        bufferStartOffset += buf.count - moveCount
        memmove(buf.baseAddress!, buf.baseAddress! + lineStart, moveCount)
        let readCount = input.read(
            buf.baseAddress! + moveCount,
            maxLength: buf.count - moveCount)
        validBufferBytes = readCount + moveCount
    }

    public let metadata: CSVGuess

    @usableFromInline
    var input: Input

    @usableFromInline
    var buffer: UnsafeMutableBufferPointer<UInt8>

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
