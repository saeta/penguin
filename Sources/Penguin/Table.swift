


/// A collection of columns.
public struct PTable {

    public init(_ columns: [(String, PColumn)]) throws {
        guard allColumnLengthsEquivalent(columns) else {
            throw PError.colCountMisMatch
        }
        self.columnOrder = columns.map { $0.0 }
        self.columnMapping = columns.reduce(into: [:]) { $0[$1.0] = $1.1 }
    }

    public init(_ columns: [String: PColumn]) throws {
        try self.init(columns.sorted { $0.key < $1.key })
    }

    public subscript (_ columnName: String) -> PColumn? {
        get {
            columnMapping[columnName]
        }
        set {
            if let firstCount = columnMapping.first?.value.count,
               let newCount = newValue?.count,
               newCount != firstCount {
                // TODO: Convert to throwing when Swift supports throwing
                // subscripts. (bugs.swift.org/browse/SR-238)
                // throw PError.colCountMisMatch

                preconditionFailure(
                    "Column count mis-match; new column count \(newCount) != \(firstCount)")
            }

            if let newValue = newValue {
                if columnMapping[columnName] != nil {
                    columnMapping[columnName] = newValue
                } else {
                    columnOrder.append(columnName)
                    columnMapping[columnName] = newValue
                }
            } else {
                columnMapping[columnName] = nil
                columnOrder.removeAll { $0 == columnName }
            }
        }
    }

    public var columns: [String] {
        get {
            columnOrder
        }
        set {
            guard newValue.count <= columnOrder.count else {
                // TODO: Convert to throwing when Swift supports throwing properties.
                preconditionFailure("""
                    Too many column names; only \(columnOrder.count) columns available, \
                    \(newValue.count) column names provided.
                    """)
            }
            let existingMappings = self.columnMapping
            self.columnMapping = [:]  // New mappings.
            // Iterate through the new column names and update mappings.
            for i in 0..<newValue.count {
                self.columnMapping[newValue[i]] = existingMappings[columnOrder[i]]
            }
            self.columnOrder = newValue
        }
    }

    private var columnMapping: [String: PColumn]
    private var columnOrder: [String]
}

extension PTable: CustomStringConvertible {
    public var description: String {
        "\(makeHeader())\n\(makeString())"
    }

    func makeHeader() -> String {
        let columnNames = columnOrder.joined(separator: "\t")
        return "\t\(columnNames)"
    }

    func makeString(maxCount requestedRows: Int = 10) -> String {
        let maxRows = min(requestedRows, columnMapping.first?.value.count ?? 0)
        var str = ""
        for i in 0..<maxRows {
            str.append("\(i)")
            for column in columnOrder {
                str.append("\t")
                str.append(columnMapping[column]?[strAt: i] ?? "")
            }
            str.append("\n")
        }
        return str
    }
}

fileprivate func allColumnLengthsEquivalent(_ columns: [(String, PColumn)]) -> Bool {
    if let firstCount = columns.first?.1.count {
        return !columns.contains { $0.1.count != firstCount }
    }
    return true
}
