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
///
/// Invariants:
///   - Each column must have the same number of elements.
///   - Column names are unique.
public struct PTable {

  /// Initializes a `PTable` from a sequence of `String`, `PColumn` pairs.
  ///
  /// - Throws: `PError.colCountMisMatch` if the column lengths are not equal.
  /// - Throws: `PError.duplicateColumnName` if the name of a column is duplicated.
  public init(_ columns: [(String, PColumn)]) throws {
    // TODO: Convert to taking a sequence!
    guard allColumnLengthsEquivalent(columns) else {
      throw PError.colCountMisMatch
    }
    self.columnOrder = columns.map { $0.0 }
    preconditionUnique(self.columnOrder)  // TODO: throw PError.duplicateColumnName!!
    self.columnMapping = columns.reduce(into: [:]) { $0[$1.0] = $1.1 }
  }

  /// Initializes a `PTable` from a dictionary mapping from `String`s to `PColumn`s.
  ///
  /// - Throws: `PError.colCountMisMatch` if the column lengths are not equal.
  public init(_ columns: [String: PColumn]) throws {
    // Note: `PError.duplicateColumnName` will never be thrown because the invariants of
    // dictionary guarantee this.
    try self.init(columns.sorted { $0.key < $1.key })
  }

  // Internal fast-path initializer.
  init(_ order: [String], _ mapping: [String: PColumn]) {
    assert(
      order.count == mapping.count,
      "Mismatched sizes \(order.count) vs \(mapping.count). \(order), \(mapping.keys)")
    assert(allColumnLengthsEquivalent(mapping.sorted { $0.key < $1.key }))
    self.columnOrder = order
    self.columnMapping = mapping
  }

  /// Accesses the `PColumn` with a given name.
  ///
  /// - Parameter columnName: The name of the column to access.
  public subscript(columnName: String) -> PColumn? {
    get {
      columnMapping[columnName]
    }
    _modify {
      // TODO: Ensure invariants hold!!
      yield &columnMapping[columnName]
    }
    set {
      if let firstCount = columnMapping.first?.value.count,
        let newCount = newValue?.count,
        newCount != firstCount
      {
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

  /// Selects a subset of columns to form a new `PTable`.
  ///
  /// - Parameter columnNames: The list of column names to include in the
  ///   new `PTable`. Each element must be unique, and must refer to a valid
  ///   column in this `PTable`.
  public subscript(columnNames: [String]) -> PTable {
    // TODO: make generic over any {Sequence|Collection} of columns?
    precondition(
      columnNames.allSatisfy { columnMapping[$0] != nil },
      """
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

  /// Builds a new `PTable` selecting only rows set in the index set.
  ///
  /// - Parameter indexSet: The set of rows to include in the new table. The `PIndexSet` must have
  ///   the same number of rows (`count`) as the `PTable.
  public subscript(indexSet: PIndexSet) -> PTable {
    guard let count = count else {
      // TODO: Why?
      return self
    }
    precondition(
      indexSet.count == count,
      "Count mis-match; indexSet.count: \(indexSet.count), self.count: \(count)")

    let newColumns = columnMapping.mapValues { col -> PColumn in
      let tmp = col[indexSet]
      return tmp
    }
    return PTable(columnOrder, newColumns)
  }

  /// Access an element at a given row and column.
  ///
  /// Note: this subscript operation is generic over the return type; as a result you need to tell
  /// Swift what type you expect to come out based on your knowledge of the storage type of the
  /// underlying column. See the following example:
  ///
  /// ```swift
  /// var myValue: Double = myTable["myColumnOfDoubles", 23]
  /// myValue += 103
  /// myTable["myColumnOfDoubles", 23] = myValue
  /// ```
  ///
  /// Note: although this is an O(1) operation, it is relatively inefficient. If you need to
  /// compute a result over a large number of rows, look at the writing your operation against a
  /// `PTypedColumn` type instead.
  ///
  /// - Parameter columnName: The name of the column to access.
  /// - Parameter index: The offset into the column to access.
  public subscript<T: ElementRequirements>(columnName: String, index: Int) -> T? {
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

  /// The names of the columns contained in this `PTable`.
  public var columnNames: [String] {
    get {
      columnOrder
    }
    set {
      guard newValue.count <= columnOrder.count else {
        // TODO: Convert to throwing when Swift supports throwing properties.
        preconditionFailure(
          """
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

  /// Rename a column.
  ///
  /// - Parameter col: The name of the column currently.
  /// - Parameter newName: The new name of the column.
  public mutating func rename(_ col: String, to newName: String) throws {
    guard columnMapping[newName] == nil else {
      throw PError.conflictingColumnName(existingName: newName, columnToRename: col)
    }
    guard let colContents = columnMapping[col] else {
      throw PError.unknownColumn(colName: col)
    }
    guard let colIndex = columnOrder.firstIndex(of: col) else {
      throw PError.internalInconsistency(
        msg: """
          Could not find index of \(col) in \(columnOrder) when trying to rename \(col) to \(newName).
          """)
    }
    columnMapping[newName] = colContents
    columnMapping[col] = nil
    columnOrder[colIndex] = newName
  }

  /// Drops columns.
  ///
  /// This is the safe variation of `drop(_:)`, which will throw an error if there is a problem
  /// with a provided column name.
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

  /// Drops rows that contain nils.
  ///
  /// - Parameter columns: if `nil` (default), filtering occurs over all columns, otherwise only
  ///   rows containing nils in the specified subset of columns are dropped.
  public mutating func dropNils(columns: [String]? = nil) {
    let indexSets: [PIndexSet]
    if let columns = columns {
      indexSets = columns.map { columnMapping[$0]!.nils }
    } else {
      indexSets = columnMapping.values.map { $0.nils }
    }
    let indexSet = indexSets.reduce(PIndexSet(all: false, count: count!)) {
      try! $0.unioned($1)
    }
    self = self[!indexSet]  // TODO: add an in-place "gather" operation.
  }

  /// Returns a new `PTable` where rows containing nils have been dropped.
  ///
  /// - Parameter columns: if `nil` (default), filtering occurs over all columns, otherwise only
  ///   rows containing nils in the specified subset of columns are dropped.
  public func droppedNils(columns: [String]? = nil) -> PTable {
    var copy = self
    copy.dropNils(columns: columns)
    return copy
  }

  /// Sorts the `PTable` (in place) based on elements in the named column.
  ///
  /// This sort is guaranteed to be stable, such that if the elements of column `columnName` are
  /// equal, than they will appear in the same order after sorting as before.
  ///
  /// - Parameter columnName: The name of the column to use to sort.
  /// - Parameter order: `true` (default) for ascending, false for descending.
  public mutating func sort(by columnName: String, ascending order: Bool = true) {
    // TODO: support generalizing sorting by multiple columns.
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

  /// Sorts the `PTable` (in place) based on elements in the named columns.
  ///
  /// This sort is guaranteed to be stable.
  ///
  /// - Parameter columnName1: The name of the first column to use to sort.
  /// - Parameter c1Order: `true` for ascending ordering of `columnName1`, false otherwise.
  /// - Parameter columnName2: The name of the second column to use to sort.
  /// - Parameter c2Order: `true` for ascending ordering of `columnName2`, false otherwise.
  public mutating func sort(
    by columnName1: String, ascending c1Order: Bool = true, _ columnName2: String,
    ascending c2Order: Bool = true
  ) {
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

  public func sorted(
    by c1: String, ascending c1Order: Bool = true, _ c2: String, ascending c2Order: Bool = true
  ) -> PTable {
    var copy = self
    copy.sort(by: c1, ascending: c1Order, c2, ascending: c2Order)
    return copy
  }

  // TODO: Improve the following doc comment.
  /// Perform a "group-by" operation, reducing the groups with aggregations.
  ///
  /// - Parameter column: Group rows in `PTable` based on elements in this column.
  /// - Parameter aggregations: The set of aggregations to apply.
  public func group(
    by column: String,
    applying aggregations: Aggregation...
  ) throws -> PTable {
    return try group(by: [column], applying: aggregations)
  }

  // TODO: Improve the following doc comment.
  /// Perform a "group-by" operation, reducing the groups with aggregations.
  ///
  /// - Parameter columnNames: Group rows in `PTable` based on elements in these columns.
  /// - Parameter aggregations: The set of aggregations to apply.
  public func group(
    by columnNames: [String],
    applying aggregations: Aggregation...
  ) throws -> PTable {
    return try group(by: columnNames, applying: aggregations)
  }

  // TODO: Improve the following doc comment.
  /// Perform a "group-by" operation, reducing the groups with aggregations.
  ///
  /// - Parameter columnNames: Group rows in `PTable` based on elements in these columns.
  /// - Parameter aggregations: The set of aggregations to apply.
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

    precondition(
      !nonGroupedByColumnNames.isEmpty,
      "No non-grouped by column names. \(columnNames)\n\(self)")

    for op in aggregations where op.isGlobal {
      // Pick a random column to use.
      guard let engine = op.build(for: columnMapping[nonGroupedByColumnNames.first!]!) else {
        preconditionFailure(
          "Could not build op \(op.name) on column \(nonGroupedByColumnNames.first!)")
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

  // TODO: support other joins other than left-outer join!
  public mutating func joined(with other: PTable, onColumn joinColumnName: String) throws {
    guard let driverColumn = self[joinColumnName] else {
      throw PError.unknownColumn(colName: joinColumnName)
    }

    guard let indexColumn = other[joinColumnName] else {
      throw PError.unknownColumn(colName: joinColumnName)
    }

    let joinIndices = try driverColumn.makeJoinIndices(for: indexColumn)

    // Gather from all the respective columns in the new table and append them.
    for columnName in other.columnOrder where columnName != joinColumnName {
      columnOrder.append(columnName)
      let newColumn = other[columnName]!.gather(joinIndices)
      columnMapping[columnName] = newColumn
    }
  }

  public func join(with other: PTable, onColumn joinColumnName: String) throws -> PTable {
    var tmp = self
    try tmp.joined(with: other, onColumn: joinColumnName)
    return tmp
  }

  /// The number of rows contained within the `PTable`.
  ///
  /// If there are no `PColumn`s in the table, `count` returns `nil`.
  public var count: Int? {
    columnMapping.first?.value.count
  }

  /// Computes summaries for each column contained within this `PTable`.
  public func summarize() -> [(String, PColumnSummary)] {
    columnOrder.map { ($0, columnMapping[$0]!.summarize()) }
  }

  var columnMapping: [String: PColumn]
  var columnOrder: [String]
}

fileprivate func preconditionUnique(
  _ names: [String], file: StaticString = #file, line: UInt = #line
) {
  precondition(
    Set(names).count == names.count, "Duplicate column name detected in \(names)", file: file,
    line: line)
}

extension PTable: CustomStringConvertible {
  /// A string representation of a (subset) of the table.
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
  /// Returns true iff `lhs` and `rhs` contain identical data, false otherwise.
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
