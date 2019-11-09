


/// A collection of named `PColumns`.
///
/// A PTable, also known as a data frame, represents a tabular collection of data.
public struct PTable {

    public init(_ columns: [(String, PColumn)]) throws {
        guard allColumnLengthsEquivalent(columns) else {
            throw PError.colCountMisMatch
        }
        self.columnOrder = columns.map { $0.0 }
        preconditionUnique(self.columnOrder)
        self.columnMapping = columns.reduce(into: [:]) { $0[$1.0] = $1.1 }
    }

    public init(_ columns: [String: PColumn]) throws {
        try self.init(columns.sorted { $0.key < $1.key })
    }

    init(_ order: [String], _ mapping: [String: PColumn]) {
        self.columnOrder = order
        self.columnMapping = mapping
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

    public subscript (columnNames: [String]) -> PTable {
        precondition(columnNames.allSatisfy { columnMapping[$0] != nil }, """
            Invalid column names;
                asked: \(columnNames)
                have: \(columnOrder)
                missing: \(columnNames.filter { columnMapping[$0] == nil })
        """)
        preconditionUnique(columnNames)
        var newMapping: [String: PColumn] = [:]
        for name in columnNames {
            newMapping[name] = columnMapping[name]
        }
        return PTable(columnNames, newMapping)
    }

    public subscript (indexSet: PIndexSet) -> PTable {
        guard let count = count else {
            return self
        }
        precondition(indexSet.count == count,
                     "Count mis-match; indexSet.count: \(indexSet.count), self.count: \(count)")

        let newColumns = columnMapping.mapValues { col -> PColumn in
            let tmp = col[indexSet]
            return tmp
        }
        return PTable(columnOrder, newColumns)
    }

    public var columnNames: [String] {
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
            preconditionUnique(newValue)
            let existingMappings = self.columnMapping
            self.columnMapping = [:]  // New mappings.
            // Iterate through the new column names and update mappings.
            for i in 0..<newValue.count {
                self.columnMapping[newValue[i]] = existingMappings[columnOrder[i]]
            }
            self.columnOrder = newValue
        }
    }

    public var count: Int? {
        columnMapping.first?.value.count
    }

    private var columnMapping: [String: PColumn]
    private var columnOrder: [String]
}

fileprivate func preconditionUnique(_ names: [String], file: StaticString = #file, line: UInt = #line) {
    precondition(Set(names).count == names.count, "Duplicate column name detected in \(names)", file: file, line: line)
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

extension PTable: Equatable {
    public static func == (lhs: PTable, rhs: PTable) -> Bool {
        if lhs.columnOrder != rhs.columnOrder {
            return false
        }

        for column in lhs.columnOrder {
            guard let cl = lhs[column] else { return false }
            guard let cr = rhs[column] else { return false }
            if !cl.equals(cr) { return false }
        }
        return true
    }
}

fileprivate func allColumnLengthsEquivalent(_ columns: [(String, PColumn)]) -> Bool {
    if let firstCount = columns.first?.1.count {
        return !columns.contains { $0.1.count != firstCount }
    }
    return true
}
