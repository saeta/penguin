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

        self.columnMapping = Dictionary(uniqueKeysWithValues: zip(columnNames, columns))
        self.columnOrder = columnNames
    }
}

fileprivate extension CSVColumnMetadata {
    func makeColumn() -> PColumn {
        switch type {
        case .string:
            return PColumn(empty: String.self)
        case .int:
            return PColumn(empty: Int.self)
        case .double:
            return PColumn(empty: Double.self)
        case .bool:
            return PColumn(empty: Bool.self)
        }
    }
}
