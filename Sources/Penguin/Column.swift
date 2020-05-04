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

/// A dtype-erased column of data.
public struct PColumn {
  public init<T: ElementRequirements>(_ col: PTypedColumn<T>) {
    self.underlying = PColumnBoxImpl(underlying: col)
  }

  public init<T: ElementRequirements>(empty: T.Type) {
    self.underlying = PColumnBoxImpl(underlying: PTypedColumn(empty: empty))
  }

  public init<T: ElementRequirements>(_ contents: [T]) {
    self.underlying = PColumnBoxImpl(underlying: PTypedColumn(contents))
  }

  public init<T: ElementRequirements>(_ contents: [T?]) {
    self.underlying = PColumnBoxImpl(underlying: PTypedColumn(contents))
  }

  init<T: ElementRequirements>(_ contents: [T], nils: PIndexSet) {
    self.underlying = PColumnBoxImpl(underlying: PTypedColumn(contents, nils: nils))
  }

  fileprivate init(_ underlying: PColumnBox) {
    self.underlying = underlying
  }

  fileprivate var underlying: PColumnBox
}

extension PColumn {
  public var count: Int { underlying.count }

  public func asDType<DT: ElementRequirements>() throws -> PTypedColumn<DT> {
    return try underlying.asDType()
  }

  public func asString() -> PTypedColumn<String> { try! asDType() }
  public func asInt() -> PTypedColumn<Int> { try! asDType() }
  public func asDouble() -> PTypedColumn<Double> { try! asDType() }
  public func asBool() -> PTypedColumn<Bool> { try! asDType() }

  public var dtypeString: String { underlying.dtypeString }

  public subscript(strAt index: Int) -> String? { underlying[strAt: index] }
  public subscript(indexSet: PIndexSet) -> PColumn { underlying[indexSet] }
  public subscript<T: ElementRequirements>(index: Int) -> T? {
    get {
      underlying[index]
    }
    set {
      underlying[index] = newValue
    }
  }
  public var nils: PIndexSet { underlying.nils }
  public func hasNils() -> Bool { underlying.hasNils() }

  /// Fill in missing entries in the column with `value`.
  public mutating func fillNils<T: ElementRequirements>(with value: T) {
    underlying.fillNils(with: value)
  }

  /// Returns a copy of `self`, with all missing entries in the column set to `value`.
  public func fillingNils<T: ElementRequirements>(with value: T) -> PColumn {
    PColumn(underlying.fillingNils(with: value))
  }
  @discardableResult public mutating func append(_ entry: String) -> Bool {
    underlying.append(entry)
  }
  public mutating func appendNil() { underlying.appendNil() }
  public mutating func _sort(_ indices: [Int]) { underlying._sort(indices) }
  public func summarize() -> PColumnSummary { underlying.summarize() }
  public mutating func optimize() { underlying.optimize() }
}

/// Non-public extensions.
extension PColumn {
  @discardableResult mutating func append(_ entry: CSVCell) -> Bool { underlying.append(entry) }
  func buildGroupByOp<O: ArbitraryTypedAggregation>(for op: O) -> AggregationEngine? {
    underlying.buildGroupByOp(for: op)
  }
  func buildNumericGroupByOp<O: NumericAggregation>(for op: O) -> AggregationEngine? {
    underlying.buildNumericGroupByOp(for: op)
  }
  func buildDoubleConvertibleGroupByOp<O: DoubleConvertibleAggregation>(
    for op: O
  ) -> AggregationEngine? { underlying.buildDoubleConvertibleGroupByOp(for: op) }
  func makeGroupByIterator() -> GroupByIterator { underlying.makeGroupByIterator() }
  func compare(lhs: Int, rhs: Int) -> PThreeWayOrdering { underlying.compare(lhs: lhs, rhs: rhs) }

  // TODO: avoid optional boxing for more efficient packing!
  func makeJoinIndices(for other: PColumn) throws -> [Int?] {
    try underlying.makeJoinIndices(for: other)
  }
  func gather(_ indices: [Int?]) -> PColumn { underlying.gather(indices) }

  // PTypedTable schema validation
  func validateColumnSchema<T>(_ keyPath: PartialKeyPath<T>) throws {
    try underlying.validateColumnSchema(keyPath)
  }
}

extension PColumn: Equatable {
  public static func == (lhs: PColumn, rhs: PColumn) -> Bool {
    return lhs.underlying._isEqual(to: rhs.underlying)
  }
}

fileprivate protocol PColumnBox {
  var count: Int { get }
  func asDType<DT: ElementRequirements>() throws -> PTypedColumn<DT>
  var dtypeString: String { get }
  subscript(strAt index: Int) -> String? { get }
  subscript(indexSet: PIndexSet) -> PColumn { get }
  subscript<T: ElementRequirements>(index: Int) -> T? { get set }
  var nils: PIndexSet { get }
  func hasNils() -> Bool
  mutating func fillNils<T: ElementRequirements>(with value: T)
  func fillingNils<T: ElementRequirements>(with value: T) -> PColumnBox
  func compare(lhs: Int, rhs: Int) -> PThreeWayOrdering
  @discardableResult mutating func append(_ entry: String) -> Bool
  mutating func appendNil()
  @discardableResult mutating func append(_ entry: CSVCell) -> Bool
  func buildGroupByOp<O: ArbitraryTypedAggregation>(for op: O) -> AggregationEngine?
  func buildNumericGroupByOp<O: NumericAggregation>(for op: O) -> AggregationEngine?
  func buildDoubleConvertibleGroupByOp<O: DoubleConvertibleAggregation>(
    for op: O
  ) -> AggregationEngine?

  func makeGroupByIterator() -> GroupByIterator
  // TODO: avoid optional boxing for more efficient packing!
  func makeJoinIndices(for other: PColumn) throws -> [Int?]
  // TODO: avoid optional boxing for more efficient packing!
  func gather(_ indices: [Int?]) -> PColumn
  func validateColumnSchema<T>(_ keyPath: PartialKeyPath<T>) throws

  mutating func _sort(_ indices: [Int])

  func summarize() -> PColumnSummary
  mutating func optimize()

  // A "poor-man's" equality check (without breaking PColumn as an existential
  func _isEqual(to box: PColumnBox) -> Bool
}

fileprivate struct PColumnBoxImpl<T: ElementRequirements>: PColumnBox, Equatable {
  var underlying: PTypedColumn<T>

  var count: Int { underlying.count }
  func asDType<DT: ElementRequirements>() throws -> PTypedColumn<DT> {
    guard T.self == DT.self else {
      throw PError.dtypeMisMatch(
        have: String(describing: T.self), want: String(describing: DT.self))
    }
    return underlying as! PTypedColumn<DT>
  }
  var dtypeString: String { String(describing: T.self) }

  subscript(strAt index: Int) -> String? { underlying[strAt: index] }
  subscript(indexSet: PIndexSet) -> PColumn {
    return PColumn(underlying[indexSet])
  }
  subscript<DT: ElementRequirements>(index: Int) -> DT? {
    get {
      guard T.self == DT.self else {
        preconditionFailure(
          PError.dtypeMisMatch(have: String(describing: T.self), want: String(describing: DT.self))
            .description)
      }
      let tmp: T? = underlying[index]  // TODO: remove the type annotation after the ambiguous subscript is removed.
      return tmp as! DT?
    }
    set {
      guard T.self == DT.self else {
        preconditionFailure(
          PError.dtypeMisMatch(have: String(describing: T.self), want: String(describing: DT.self))
            .description)
      }
      let tmp = newValue as! T?
      underlying[index] = tmp
    }
  }
  var nils: PIndexSet { underlying.nils }
  func hasNils() -> Bool { underlying.hasNils() }
  mutating func fillNils<DT: ElementRequirements>(with value: DT) {
    guard T.self == DT.self else {
      preconditionFailure(
        PError.dtypeMisMatch(have: String(describing: T.self), want: String(describing: DT.self))
          .description)
    }
    let tmp = value as! T
    underlying.fillNils(with: tmp)
  }
  func fillingNils<DT: ElementRequirements>(with value: DT) -> PColumnBox {
    var tmp = self
    tmp.fillNils(with: value)
    return tmp
  }
  func compare(lhs: Int, rhs: Int) -> PThreeWayOrdering { underlying.compare(lhs: lhs, rhs: rhs) }
  @discardableResult mutating func append(_ entry: String) -> Bool { underlying.append(entry) }
  mutating func appendNil() { underlying.appendNil() }
  @discardableResult mutating func append(_ entry: CSVCell) -> Bool { underlying.append(entry) }
  func buildGroupByOp<O: ArbitraryTypedAggregation>(for op: O) -> AggregationEngine? {
    underlying.buildGroupByOp(for: op)
  }
  func makeGroupByIterator() -> GroupByIterator { underlying.makeGroupByIterator() }
  func buildNumericGroupByOp<O: NumericAggregation>(for op: O) -> AggregationEngine? {
    if let s = underlying as? HasNumeric {
      return s.buildNumericGroupByOp(for: op)
    }
    return nil
  }
  func buildDoubleConvertibleGroupByOp<O: DoubleConvertibleAggregation>(
    for op: O
  ) -> AggregationEngine? {
    if let s = underlying as? HasDoubleConvertible {
      return s.buildDoubleConvertibleGroupByOp(for: op)
    }
    return nil
  }

  func makeJoinIndices(for other: PColumn) throws -> [Int?] {
    guard let otherColumn = other.underlying as? PColumnBoxImpl<T> else {
      throw PError.dtypeMisMatch(
        have: String(describing: T.self),
        want: String(describing: other.dtypeString))
    }
    return try underlying.makeJoinIndices(for: otherColumn.underlying)
  }

  func gather(_ indices: [Int?]) -> PColumn { PColumn(underlying.gather(indices)) }
  func validateColumnSchema<U>(_ keyPath: PartialKeyPath<U>) throws {
    if keyPath is KeyPath<U, T> {
    } else {
      throw PError.dtypeMisMatch(
        have: String(describing: T.self),
        want: String(describing: U.self))
    }
  }

  mutating func _sort(_ indices: [Int]) { underlying._sort(indices) }

  func summarize() -> PColumnSummary {
    if T.self == String.self {
      return (self as! PColumnBoxImpl<String>).underlying.stringSummary()
    }
    if let s = underlying as? HasDoubleConvertible {
      return s.numericSummary()
    }
    return PColumnSummary(rowCount: count, missingCount: nils.count, details: nil)
  }

  mutating func optimize() {
    underlying.optimize()
  }

  // A "poor-man's" equality check (without breaking PColumn as an existential
  func _isEqual(to box: PColumnBox) -> Bool {
    // TODO: IMPLEMENT ME!
    if type(of: self) != type(of: box) { return false }
    let rhsC = box as! PColumnBoxImpl<T>
    return self == rhsC
  }
}

fileprivate protocol HasNumeric {
  func buildNumericGroupByOp<O: NumericAggregation>(for op: O) -> AggregationEngine?
}

extension PTypedColumn: HasNumeric where T: Numeric {
  func buildNumericGroupByOp<O: NumericAggregation>(for op: O) -> AggregationEngine? {
    op.build(for: self)
  }
}

fileprivate protocol HasDoubleConvertible {
  func numericSummary() -> PColumnSummary
  func buildDoubleConvertibleGroupByOp<O: DoubleConvertibleAggregation>(
    for op: O
  ) -> AggregationEngine?
}

extension PTypedColumn: HasDoubleConvertible where T: DoubleConvertible {
  func buildDoubleConvertibleGroupByOp<O: DoubleConvertibleAggregation>(
    for op: O
  ) -> AggregationEngine? {
    op.build(for: self)
  }
}

extension PTypedColumn {
  func buildGroupByOp<O: ArbitraryTypedAggregation>(for op: O) -> AggregationEngine? {
    op.build(for: self)
  }
}
