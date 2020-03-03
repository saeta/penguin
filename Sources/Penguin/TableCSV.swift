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
