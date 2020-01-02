import PenguinCSV
import PenguinParallel

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

    public subscript <T: ElementRequirements>(columnName: String, index: Int) -> T {
        get {
            precondition(columnMapping[columnName] != nil, "Unknown column \(columnName).")
            precondition(index < count!, "Index \(index) is out of range from 0..<\(count!).")
            let col = columnMapping[columnName]
            precondition(col is PTypedColumn<T>,
                         "Unexpected dtype \(T.self); column \(columnName) has type \(type(of: col)).")
            let tCol = col as! PTypedColumn<T>
            return tCol[index]
        }
        set {
            precondition(columnMapping[columnName] != nil, "Unknown column \(columnName).")
            precondition(index < count!, "Index \(index) is out of range from 0..<\(count!).")
            let col = columnMapping[columnName]
            precondition(col is PTypedColumn<T>,
                         "Unexpected dtype \(T.self); column \(columnName) has type \(type(of: col)).")
            columnMapping[columnName] = nil  // Set to nil to remove extra reference to it for possible in-place updates.
            var tCol = col as! PTypedColumn<T>
            tCol[index] = newValue
            columnMapping[columnName] = tCol
        }
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

    public mutating func rename(_ col: String, to newName: String) throws {
        guard columnMapping[newName] == nil else {
            throw PError.conflictingColumnName(existingName: newName, columnToRename: col)
        }
        guard let colContents = columnMapping[col] else {
            throw PError.unknownColumn(colName: col)
        }
        guard let colIndex = columnOrder.firstIndex(of: col) else {
            throw PError.internalInconsistency(msg: """
                Could not find index of \(col) in \(columnOrder) when trying to rename \(col) to \(newName).
                """)
        }
        columnMapping[newName] = colContents
        columnMapping[col] = nil
        columnOrder[colIndex] = newName
    }

    /// Drops columns.
    ///
    /// This is the safe variation of drop(_:), which will throw an error if there is a problem with
    /// a provided column name.
    ///
    /// Note: this function is implemented such that it either fully succeeds or throws an error, and
    /// will never leave the Table in an inconsistent state.
    public mutating func drop(columns: String...) throws {
        // Verify all columns are there before making any modifications. This ensures
        // either the operation atomically succeeds or fails.
        for col in columns {
            if columnMapping[col] == nil {
                throw PError.unknownColumn(colName: col)
            }
        }
        for col in columns {
            columnMapping[col] = nil
        }
        let colNames = Set(columns)
        columnOrder.removeAll { colNames.contains($0) }
    }

    /// Drops columns.
    ///
    /// If a column name does not exist in the PTable, it is silently ignored.
    public mutating func drop(_ columns: String...) {
        for col in columns {
            columnMapping[col] = nil
        }
        let colNames = Set(columns)
        columnOrder.removeAll { colNames.contains($0) }
    }

    public mutating func dropNils() {
        let indexSets = columnMapping.values.map { $0.nils }
        let indexSet = indexSets.reduce(PIndexSet(all: false, count: count!)) {
            try! $0.unioned($1)
        }
        self = self[!indexSet]  // TODO: add an in-place "gather" operation.
    }

    public func droppedNils() -> PTable {
        var copy = self
        copy.dropNils()
        return copy
    }

    // TODO: support generalizing sorting by multiple columns.

    public mutating func sort(by columnName: String, ascending order: Bool = true) {
        guard let column = self.columnMapping[columnName] else {
            preconditionFailure("Could not find column \(columnName).")  // TODO: make throwing instead?
        }
        var indices = Array(0..<count!)
        indices.sort {
            switch column.compare(lhs: $0, rhs: $1) {
            case .lt: return order
            case .eq: return $0 < $1  // A stable sort.
            case .gt: return !order
            }
        }
        self.columnMapping = self.columnMapping.mapValues {
            var copy = $0
            copy._sort(indices)
            return copy
        }
    }

    public mutating func sort(by columnName1: String, ascending c1Order: Bool = true, _ columnName2: String, ascending c2Order: Bool = true) {
        guard let c1 = self.columnMapping[columnName1] else {
            preconditionFailure("Could not find column \(columnName1).")  // TODO: make throwing instead?
        }
        guard let c2 = self.columnMapping[columnName2] else {
            preconditionFailure("Could not find column \(columnName2).")  // TODO: make throwing instead?
        }
        var indices = Array(0..<count!)
        indices.sort {
            switch c1.compare(lhs: $0, rhs: $1) {
            case .lt: return c1Order
            case .eq:
                switch c2.compare(lhs: $0, rhs: $1) {
                case .lt: return c2Order
                case .eq: return $0 < $1  // A stable sort.
                case .gt: return !c2Order
                }
            case .gt: return !c1Order
            }
        }
        self.columnMapping = self.columnMapping.mapValues {
            var copy = $0
            copy._sort(indices)
            return copy
        }
    }

    public func sorted(by columnName: String, ascending: Bool = true) -> PTable {
        var copy = self
        copy.sort(by: columnName, ascending: ascending)
        return copy
    }

    public func sorted(by c1: String, ascending c1Order: Bool = true, _ c2: String, ascending c2Order: Bool = true) -> PTable {
        var copy = self
        copy.sort(by: c1, ascending: c1Order, c2, ascending: c2Order)
        return copy
    }

    public var count: Int? {
        columnMapping.first?.value.count
    }

    var columnMapping: [String: PColumn]
    var columnOrder: [String]
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
            if !cl._equals(cr) { return false }
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


extension PTable {
    public init(fromCsv file: String, headerRow: Bool? = nil) throws {
        var itr = try CSVRowParser<String.Iterator>.createFromFile(file: file)
        try self.init(&itr, headerRow: headerRow, fileName: file)
    }

    public init(fromCsvContents contents: String, headerRow: Bool? = nil) throws {
        var itr = CSVRowParser(contents.makeIterator())
        try self.init(&itr, headerRow: headerRow, fileName: nil)
    }

    // TODO: Make generic over iterator type!
    init(_ itr: inout CSVRowParser<String.Iterator>, headerRow: Bool? = nil, fileName: String?) throws {
        // Helper type that helps build up the PTypedColumn's.
        struct TableData {
            typealias ColData = [String]
            var columns: [ColData]

            init(colCount: Int) {
                columns = [ColData]()
                for _ in 0..<colCount {
                    columns.append([String]())
                }
            }

            mutating func append(row: [String]) throws {
                guard row.count == columns.count else {
                    throw PError.unexpectedCsvColumn(expectedColCount: columns.count, row: row)
                }
                for i in 0..<columns.count {
                    columns[i].append(row[i])
                }
            }

            func toColumns() -> [PTypedColumn<String>] {
                columns.map { PTypedColumn($0) }
            }
        }

        // TODO: sniff the types, auto-guess header row existance, optimize implementation / etc.
        guard let firstRow = itr.next() else {
            throw PError.empty(file: fileName ?? "<string>")
        }
        guard let secondRow = itr.next() else {
            // Special case handling for only one row in the csv file!
            columnOrder = (0..<firstRow.count).map { "col\($0)" }
            let columns = firstRow.map { PTypedColumn([$0]) }
            columnMapping = zip(columnOrder, columns).toDictionary()
            return
        }
        let columnNames: [String]
        var table = TableData(colCount: firstRow.count)
        // If unspecified, assume there exists a header row.
        if headerRow == false {
            try table.append(row: firstRow)
            columnNames = (0..<firstRow.count).map { "col\($0)" }
        } else {
            columnNames = firstRow
        }
        try table.append(row: secondRow)
        while let row = itr.next() {
            try table.append(row: row)
        }

        columnOrder = columnNames
        columnMapping = zip(columnOrder, table.toColumns()).toDictionary()
    }
}

fileprivate extension Zip2Sequence where Sequence1.Element: Hashable {
    func toDictionary() -> [Sequence1.Element: Sequence2.Element] {
        reduce(into: [:]) { $0[$1.0] = $1.1 }
    }
}
