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
import PenguinCSV

extension PTable {
    public init(csv file: String) throws {
        let reader = try CSVProcessor(fileAtPath: file)
        try self.init(reader: reader, fileName: file)
    }

    init(csvContents: String) throws {
        let reader = try CSVProcessor(contents: csvContents)
        try self.init(reader: reader, fileName: nil)
    }

    init(reader: CSVProcessor, fileName: String?) throws {
        // TODO: have some way of tracking errors other than printing to the console?
        let columnNames = reader.metadata.columns.map { $0.name }
        if columnNames.count != Set(columnNames).count {
            var colNames = Set<String>()
            for col in columnNames {
                if colNames.contains(col) {
                    throw PError.duplicateColumnName(name: col, allColumns: columnNames)
                }
                colNames.insert(col)
            }
            fatalError("""
                Internal error: discovered a duplicate name, but didn't find it?!?! \
                Columns: \(columnNames)
                """)
        }
        var columns = reader.metadata.columns.map { $0.makeColumn() }

        try reader.forEach { (row, i) in
            // After 1k rows, see if we can optimize ourselves a bit...
            if i == 1000 {
                columns = columns.map { $0.optimized() }
            }
            if row.count > columnNames.count {
                print("""
                    Encountered extra column(s) at row \(i); \
                    expected \(columnNames.count) columns, found: \
                    \(row.count) columns.
                    """)
            }

            let definedCols = min(row.count, columns.count)
            for i in 0..<definedCols {
                columns[i].append(row[i])
            }
            if !(definedCols..<columns.count).isEmpty {
                print("Row \(i) missing columns \(definedCols) - \(columns.count - 1).")
                for i in definedCols..<columns.count {
                    columns[i].appendNil()
                }
            }
        }

        self.columnMapping = Dictionary(uniqueKeysWithValues: zip(
            columnNames, columns.map { $0.finish() }))
        self.columnOrder = columnNames
    }
}

/// ColumnBuilder allows for efficient appending to (untyped) columns.
///
/// After creating a ColumnBuilder, append a few thousand entries into the
/// builder, and then call `optimize`, which will return a new ColumnBuilder
/// which can be used to continue appending. When file processing is complete,
/// call `finish` to get the built `PColumn`.
///
/// This design allows for more efficient parsing, and reduces virtual function
/// dispatch overhead.
protocol ColumnBuilder {
    mutating func append(_ cell: CSVCell)
    mutating func appendNil()

    func optimized() -> ColumnBuilder

    func finish() -> PColumn
}

struct NumericColumnBuilder<T: Numeric & ElementRequirements>: ColumnBuilder {
    mutating func append(_ cell: CSVCell) {
        guard let tmp = T(cell) else {
            appendNil()
            return
        }
        elements.append(tmp)
        nils.append(false)
    }

    mutating func appendNil() {
        elements.append(T())
        nils.append(true)
    }

    func optimized() -> ColumnBuilder { self }  // No optimizations.

    func finish() -> PColumn {
        let typedColumn = PTypedColumn(elements, nils: nils)
        return PColumn(typedColumn)
    }

    private var elements = [T]()
    private var nils = PIndexSet(empty: true)
}

/// BasicStringColumnBuilder does nothing fancy during append operations,
/// and simply adds strings to an array.
struct BasicStringColumnBuilder: ColumnBuilder {
    mutating func append(_ cell: CSVCell) {
        guard let tmp = String(cell) else {
            appendNil()
            return
        }
        elements.append(tmp)
        nils.append(false)
    }

    mutating func appendNil() {
        elements.append("")
        nils.append(true)
    }

    func optimized() -> ColumnBuilder {
        let subset = elements[0..<1000]
        if Set(subset).count < (subset.count / 2) {
            return SmallSetStringColumnBuilder(elements: elements, nils: nils)
        }
        return self
    }

    func finish() -> PColumn {
        return PColumn(PTypedColumn(elements, nils: nils))
    }

    private var elements = [String]()
    private var nils = PIndexSet(empty: true)
}

struct SmallSetStringColumnBuilder: ColumnBuilder {
    init() {
        self.nils = PIndexSet(empty: true)
    }

    init(elements: [String], nils: PIndexSet) {
        self.nils = nils
        handles.reserveCapacity(elements.count)
        for elem in elements {
            let handle = encoder[encode: elem]
            trie[elem] = handle
            handles.append(handle)
        }
    }

    mutating func append(_ cell: CSVCell) {
        switch cell {
        case .empty:
            appendNil()
            return
        case let .raw(buf):
            if let handle = trie[buf] {
                handles.append(handle)
                nils.append(false)
                return
            }
            guard let str = String(cell) else {
                handles.append(.nilHandle)
                nils.append(true)
                return
            }
            let handle = encoder[encode: str]
            trie[buf] = handle
            handles.append(handle)
            nils.append(false)
        case let .escaped(str):
            let handle = encoder[encode: str]
            handles.append(handle)
            nils.append(false)
        }
    }

    mutating func appendNil() {
        handles.append(EncodedHandle.nilHandle)
        nils.append(true)
    }

    func optimized() -> ColumnBuilder { self }
    func finish() -> PColumn {
        PColumn(PTypedColumn(impl: PTypedColumnImpl.encoded(encoder, handles),
                             nils: nils))
    }

    // We use the trie to avoid paying the utf8 verification cost.
    var trie = Trie<EncodedHandle>()
    var encoder = Encoder<String>()
    var handles = [EncodedHandle]()
    var nils: PIndexSet
}

struct BooleanColumnBuilder: ColumnBuilder {
    mutating func append(_ cell: CSVCell) {
        switch cell {
        case .empty:
            appendNil()
            return
        case let .raw(buf):
            guard buf.count > 0 else {
                appendNil()
                return
            }
            var i = 0
            // Ignore early whitespace.
            while i < buf.count {
                if Unicode.Scalar(buf[i]) != " " { break }
                i += 1
            }
            switch Unicode.Scalar(buf[i]) {
            case "0", "1":
                if buf.count == i + 1 || Unicode.Scalar(buf[i + 1]) == " " {
                    append(Unicode.Scalar(buf[i]) != "0")
                    return
                }
            case "T", "t":
                if buf.count == i + 1 {
                    append(true)
                    return
                }
                if buf.count <= i + 3 {
                    // Too short!
                    appendNil()
                    return
                }
                let charR = Unicode.Scalar(buf[i + 1])
                let charU = Unicode.Scalar(buf[i + 2])
                let charE = Unicode.Scalar(buf[i + 3])
                if (charR == "r" || charR == "R") && 
                   (charU == "u" || charU == "U") &&
                   (charE == "e" || charE == "E") {
                    append(true)
                    return
                }
                appendNil()
                return
            case "F", "f":
                if buf.count == i + 1 {
                    append(false)
                    return
                }
                if buf.count <= i + 4 {
                    // Too Short!
                    appendNil()
                    return
                }
                let charA = Unicode.Scalar(buf[i + 1])
                let charL = Unicode.Scalar(buf[i + 2])
                let charS = Unicode.Scalar(buf[i + 3])
                let charE = Unicode.Scalar(buf[i + 4])
                if (charA == "a" || charA == "A") &&
                   (charL == "l" || charL == "L") &&
                   (charS == "s" || charS == "S") &&
                   (charE == "e" || charE == "E") {
                    append(false)
                    return
                }
                appendNil()
                return
            default:
                appendNil()
                return
            }
        case let .escaped(str):
            // Slow path.
            guard let parsed = Bool(parsing: str) else {
                appendNil()
                return
            }
            append(parsed)
            return
        }
    }

    private mutating func append(_ value: Bool) {
        elements.append(value)
        nils.append(false)
    }

    mutating func appendNil() {
        elements.append(Bool())
        nils.append(true)
    }

    func optimized() -> ColumnBuilder { self }
    func finish() -> PColumn {
        let typedColumn = PTypedColumn(elements, nils: nils)
        return PColumn(typedColumn)
    }

    private var elements = [Bool]()
    private var nils = PIndexSet(empty: true)
}

fileprivate extension CSVColumnMetadata {
    func makeColumn() -> ColumnBuilder {
        switch type {
        case .string:
            return BasicStringColumnBuilder()
        case .int:
            return NumericColumnBuilder<Int>()
        case .double:
            return NumericColumnBuilder<Double>()
        case .bool:
            return BooleanColumnBuilder()
        }
    }
}
