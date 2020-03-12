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
        _modify {
            yield &columnMapping[columnName]
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

    public subscript <T: ElementRequirements>(columnName: String, index: Int) -> T? {
        get {
            precondition(columnMapping[columnName] != nil, "Unknown column \(columnName).")
            precondition(index < count!, "Index \(index) is out of range from 0..<\(count!).")
            return columnMapping[columnName]![index]
        }
        set {
            precondition(columnMapping[columnName] != nil, "Unknown column \(columnName).")
            precondition(index < count!, "Index \(index) is out of range from 0..<\(count!).")
            columnMapping[columnName]![index] = newValue
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

    public func group(
        by column: String,
        applying aggregations: Aggregation...
    ) throws -> PTable {
        return try group(by: [column], applying: aggregations)
    }

    public func group(
        by columnNames: [String],
        applying aggregations: Aggregation...
    ) throws -> PTable {
        return try group(by: columnNames, applying: aggregations)
    }

    public func group(
        by columnNames: [String],
        applying aggregations: [Aggregation]
    ) throws -> PTable {
        // TODO: parallelize the implementation!

        // Make the group by iterators.
        var groupByIterators: [GroupByIterator] = try columnNames.map {
            guard let col = self.columnMapping[$0] else {
                throw PError.unknownColumn(colName: $0)
            }
            return col.makeGroupByIterator()
        }
        // Set up the aggregtation engines.
        let groupedColumnNamesSet = Set(columnNames)
        let nonGroupedByColumnNames = columnOrder.filter { !groupedColumnNamesSet.contains($0) }
        var engines = [AggregationEngine]()
        var newColumnNames = [String]()

        precondition(!nonGroupedByColumnNames.isEmpty,
            "No non-grouped by column names. \(columnNames)\n\(self)")

        for op in aggregations where op.isGlobal {
            // Pick a random column to use.
            guard let engine = op.build(for: columnMapping[nonGroupedByColumnNames.first!]!) else {
                preconditionFailure("Could not build op \(op.name) on column \(nonGroupedByColumnNames.first!)")
            }
            engines.append(engine)
            newColumnNames.append(op.name)
        }

        for nonGroupedColumnName in nonGroupedByColumnNames {
            for op in aggregations where !op.isGlobal {
                if let engine = op.build(for: columnMapping[nonGroupedColumnName]!) {
                    engines.append(engine)
                    newColumnNames.append("\(nonGroupedColumnName)_\(op.name)")
                }
            }
        }

        // Run the group-by computation.
        var encoder = Encoder<[EncodedHandle]>()
        tableIterator: while true {
            // Compute the group
            var encoderKey = [EncodedHandle]()
            encoderKey.reserveCapacity(groupByIterators.count)
            for i in 0..<groupByIterators.count {
                if let key = groupByIterators[i].next() {
                    encoderKey.append(key)
                } else {
                    assert(i == 0, "\(i), \(encoderKey)")
                    for i in 1..<groupByIterators.count {
                        let tmp = groupByIterators[i].next()
                        assert(tmp == nil, "\(i): \(tmp!)")
                    }
                    break tableIterator
                }
            }
            let index = encoder[encode: encoderKey].value
            // Run the engines
            for i in 0..<engines.count {
                engines[i].next(is: Int(index))
            }
        }

        // Construct the "key" rows (logically, a transpose).
        var keys = Array(repeating: [EncodedHandle](), count: groupByIterators.count)
        for i in 0..<keys.count {
            keys[i].reserveCapacity(encoder.count)
        }
        for i in 0..<encoder.count {
            let row = encoder[decode: EncodedHandle(value: UInt32(i))]
            assert(row.count == keys.count)
            for j in 0..<row.count {
                keys[j].append(row[j])
            }
        }

        let newGroupNameColumns = zip(groupByIterators, keys).map { $0.0.buildColumn(from: $0.1) }
        let newAggregatedColumns = engines.map { $0.finish() }
        let newColumnOrder = columnNames + newColumnNames
        let newColumns = newGroupNameColumns + newAggregatedColumns
        let newColumnMapping = Dictionary(uniqueKeysWithValues: zip(newColumnOrder, newColumns))
        return PTable(newColumnOrder, newColumnMapping)
    }

    public var count: Int? {
        columnMapping.first?.value.count
    }

    public func summarize() -> [(String, PColumnSummary)] {
        columnOrder.map { ($0, columnMapping[$0]!.summarize() )}
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
        let columnTypes = columnOrder.map { columnMapping[$0]!.dtypeString }.joined(separator: "\t")
        return "\t\(columnNames)\n\t\(columnTypes)"
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
            if cl != cr { return false }
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
