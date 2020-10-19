//******************************************************************************
// Copyright 2020 Penguin Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
import XCTest
import PenguinStructures

/// XCTests that `x` is non-nil and returns `x`, reporting test failures with the given message,
/// file, and line.
///
/// - Example:
///
///     if let a = expectNonNil(b) {
///        XCTAssertLessThan(a, 10)
///     }
///
#if swift(>=5.3)
internal func expectNonNil<T>(
  _ x: T?, _ message: @autoclosure () -> String = "",
  file: StaticString = #filePath, line: UInt = #line
) -> T? {
  XCTAssertNotNil(x)
  return x
}
#else
internal func expectNonNil<T>(
  _ x: T?, _ message: @autoclosure () -> String = "",
  file: StaticString = #file, line: UInt = #line
) -> T? {
  XCTAssertNotNil(x)
  return x
}
#endif

extension InsertionOrderedDictionary {
  /// Validates that keys appear in `self` in the same order as their first appearance in `source`.
  fileprivate func checkKeyOrder<ExpectedKeys: Collection>(_ source: ExpectedKeys)
    where ExpectedKeys.Element == Key
  {
    // Validate that keys appear in insertion order
    var knownKeys: Set<Key> = []
    var expectedUnknownKeyIndex = 0
    for k in source {
      if let i = expectNonNil(self.index(forKey: k), "expected key not found") {
        if knownKeys.contains(k) {
            XCTAssertLessThan(i, expectedUnknownKeyIndex)
        }
        else {
          XCTAssertEqual(i, expectedUnknownKeyIndex)
          knownKeys.insert(k)
          expectedUnknownKeyIndex += 1
        }
      }
    }
  }
}

final class InsertionOrderedDictionaryTests: XCTestCase {
  private static let uniqueUnlabeledTuples = (0..<9).map { ($0, String($0)) }
  private static let uniqueLabeledTuples = (0..<9).map { (key: $0, value: String($0)) }
  private static let uniqueKeyValues = (0..<9).map { KeyValuePair(key: $0, value: String($0)) }

  private let p0 = InsertionOrderedDictionary(
    uniqueKeysWithValues: InsertionOrderedDictionaryTests.uniqueKeyValues)
  
  private let p1 = Dictionary<Int, String>(
    uniqueKeysWithValues: InsertionOrderedDictionaryTests.uniqueUnlabeledTuples)
    
  func test_collectionSemantics() {
    let d = p0
    let expectedContents = Self.uniqueKeyValues.sorted {
      d.index(forKey: $0.key) ?? d.endIndex
        < d.index(forKey: $1.key) ?? d.endIndex
    }
    d.checkRandomAccessCollectionSemantics(expecting: expectedContents)
  }

  func test_initFromDictionary() {
    let d0: [Int: String] = .init(uniqueKeysWithValues: Self.uniqueLabeledTuples)
    let d1 = InsertionOrderedDictionary(d0)
    XCTAssertEqual(Array(d0.keyValuePairs()), Array(d1))
  }
  
  func test_defaultInit() {
    let d = InsertionOrderedDictionary<Int, String>()
    XCTAssert(d.isEmpty)
  }

  func test_initMinimumCapacity() {
    let d = InsertionOrderedDictionary<Int, String>(minimumCapacity: 100)
    XCTAssert(d.capacity >= 100)
  }

  func test_initUniqueKeysWithValues() {
    let d = InsertionOrderedDictionary(
      uniqueKeysWithValues: InsertionOrderedDictionaryTests.uniqueKeyValues) 
    XCTAssertEqual(d.count, Self.uniqueKeyValues.count)
    XCTAssert(InsertionOrderedDictionaryTests.uniqueKeyValues.elementsEqual(d))
    // TODO: test for traps when keys are not unique.
    // https://github.com/saeta/penguin/issues/64
  }

  func test_initUniquingKeys() {
    // Create something with some repeitition in it
    let more = stride(from: -2, through: 20, by: 3).map {
      KeyValuePair(key: $0, value: "a")
    }
    let moreStill = stride(from: 1, through: 9, by: 2).map {
      KeyValuePair(key: $0, value: "b")
    }
    let source = Self.uniqueKeyValues + more + moreStill
    
    let d0 = InsertionOrderedDictionary(source, uniquingKeysWith: +)
    let d1 = Dictionary<Int, String>(
      source.lazy.map { ($0.key, $0.value) }, uniquingKeysWith: +)
    XCTAssertEqual(Dictionary(d0), d1)
    
    // Validate that keys appear in insertion order
    d0.checkKeyOrder(source.lazy.map(\.key))
  }

  func test_initGrouping() {
    let d0 = InsertionOrderedDictionary(grouping: 0..<100, by: { $0 % 13 })
    let d1 = Dictionary(grouping: 0..<100, by: { $0 % 13 })
    XCTAssertEqual(Dictionary(d0), d1)
    XCTAssert(d0.keys.elementsEqual(0..<13), "check for insertion order")
  }

  func test_filter() {
    let d0 = p0.filter { (kv: KeyValuePair)->Bool in (kv.key % 3) == 0 }
    let d1 = p1.filter { kv in (kv.key % 3) == 0 }
    
    XCTAssertEqual(Dictionary(d0), d1)
    XCTAssertEqual(Array(d0), Array(p0.filter { (kv: KeyValuePair)->Bool in (kv.key % 3) == 0 }))
  }
  
  func test_subscript() {
    var d0 = p0
    for (k, v) in p1 {
      XCTAssertEqual(d0[k], v)
      d0[k]?.append("*")
      XCTAssertEqual(d0[k], v + "*")
    }
    XCTAssertEqual(d0[99], nil)
  }
  
  func test_subscriptDefaultValue() {
    var d0 = p0
    for (k, v) in p1 {
      XCTAssertEqual(d0[k, default: "nope"], v)
      d0[k, default: "nope"] += "*"
      XCTAssertEqual(d0[k], v + "*")
      XCTAssertEqual(d0[k, default: "nix"], v + "*")
    }
    for k in 99...101 {
      XCTAssertEqual(d0[k, default: "nada"], "nada")
      d0[k, default: "nada"] += "*"
      XCTAssertEqual(d0[k], "nada*")
      XCTAssertEqual(d0[k, default: "nix"], "nada*")
    }
    d0.checkKeyOrder(Array(p0.keys) + p1.keys + (99...101))
  }
  
  func test_mapValues() {
    let d0 = p0.mapValues { v in Int(v) }
    XCTAssertEqual(
      Array(d0),
      Array(p0).map { .init(key: $0.key, value: Int($0.value)) })
  }

  /// A set of pairs with keys that intersect those in uniqueKeyValues but contain some new keys.
  let mergeSource = InsertionOrderedDictionaryTests.uniqueKeyValues.map {
    KeyValuePair(key: $0.key % 3 == 1 ? 4 * $0.key : $0.key, value: $0.value)
  }
  
  let mergeSourceTuples = InsertionOrderedDictionaryTests.uniqueKeyValues.map {
    (key: $0.key % 3 == 1 ? 4 * $0.key : $0.key, value: $0.value)
  }
  
  func test_merge() {
    var d0 = p0
    var d1 = p1
    d0.merge(mergeSource, uniquingKeysWith: +)
    d1.merge(mergeSourceTuples, uniquingKeysWith: +)
    XCTAssertEqual(Dictionary(d0), d1)
    d0.checkKeyOrder(Array(p0.keys) + mergeSource.lazy.map(\.key))
  }
  
  func test_mergingGeneric() {
    let d0 = p0.merging(mergeSource, uniquingKeysWith: +)
    let d1 = p1.merging(mergeSourceTuples, uniquingKeysWith: +)
    XCTAssertEqual(Dictionary(d0), d1)
    d0.checkKeyOrder(Array(p0.keys) + mergeSource.lazy.map(\.key))
  }
  
  func test_merging() {
    let mergeSource = InsertionOrderedDictionary(uniqueKeysWithValues: self.mergeSource)
    let d0 = p0.merging(mergeSource, uniquingKeysWith: +)
    let d1 = p1.merging(mergeSourceTuples, uniquingKeysWith: +)
    XCTAssertEqual(Dictionary(d0), d1)
    d0.checkKeyOrder(Array(p0.keys) + mergeSource.lazy.map(\.key))
  }
  
  func test_removeAt() {
    var d0 = p0
    var d1 = p1
    for k in ((0..<5).lazy.map { $0 * 3 }) {
      if let i = d0.index(forKey: k) {
        let e0 = d0.remove(at: i)
        let e1 = d1.remove(at: d1.index(forKey: k)!)
        XCTAssertEqual(e0.key, e1.key)
        XCTAssertEqual(e0.value, e1.value)
      }
    }
    XCTAssertEqual(Dictionary(d0), d1)
    d0.checkKeyOrder(p0.keys.filter { d0.index(forKey: $0) != nil })
  }
  
  func test_removeValueForKey() {
    var d0 = p0
    var d1 = p1
    for k in ((0..<5).lazy.map { $0 * 3 }) {
      let v0 = d0.removeValue(forKey: k)
      let v1 = d1.removeValue(forKey: k)
      XCTAssertEqual(v0, v1)
    }
    XCTAssertEqual(Dictionary(d0), d1)
    d0.checkKeyOrder(p0.keys.filter { d0.index(forKey: $0) != nil })
  }
  
  func test_removeAll() {
    let freshEmpty = InsertionOrderedDictionary<Int, String>()
    XCTAssertNotEqual(
      p0.capacity, freshEmpty.capacity,
      "Not a bug in the code under test, but p0 probably needs more elements")
    
    var d0 = p0
    d0.removeAll()
    XCTAssert(d0.isEmpty)
    XCTAssertEqual(d0.capacity, freshEmpty.capacity)
    
    d0 = p0
    d0.removeAll(keepingCapacity: false)
    XCTAssert(d0.isEmpty)
    XCTAssertEqual(d0.capacity, freshEmpty.capacity)

    d0 = p0
    d0.removeAll(keepingCapacity: true)
    XCTAssert(d0.isEmpty)
    XCTAssertEqual(d0.capacity, p0.capacity)
  }
  
  func test_keys() {
    XCTAssertEqual(Array(p0.keys), InsertionOrderedDictionaryTests.uniqueKeyValues.map(\.key))
  }
  
  func test_values() {
    XCTAssertEqual(Array(p0.values), InsertionOrderedDictionaryTests.uniqueKeyValues.map(\.value))
    var d0 = p0
    var d1 = p1
    // mutate through values
    d0.values[d0.index(forKey: 3)!] = "boogie"
    d1.values[d1.index(forKey: 3)!] = "boogie"
    XCTAssertEqual(Dictionary(d0), d1)
  }

  func test_capacity() {
    var d0 = p0
    while d0.count < p0.capacity {
      d0[d0.count + 100] = "*"
    }
    XCTAssertEqual(d0.count, d0.capacity)
    XCTAssertEqual(d0.capacity, p0.capacity)
    d0[d0.count + 100] = "*"
    XCTAssertGreaterThan(d0.capacity, p0.capacity)
    XCTAssertGreaterThanOrEqual(d0.capacity, d0.count)
  }
  
  func test_reserveCapacity() {
    var d0 = p0
    d0.reserveCapacity(d0.capacity * 2)
    while d0.count < p0.capacity * 2 {
      d0[d0.count + 100] = "*"
    }
    XCTAssertEqual(d0.count, d0.capacity)
    XCTAssertEqual(d0.capacity, p0.capacity * 2)
  }

  func test_Dictionary_init() {
    XCTAssert(Dictionary(p0) == Dictionary(uniqueKeysWithValues: p0.map { ($0.key, $0.value) }))
  }
  // TODO: test Encodable/Decodable semantics.
  
  static var allTests = [
    ("test_collectionSemantics", test_collectionSemantics),
    ("test_initFromDictionary", test_initFromDictionary),
    ("test_defaultInit", test_defaultInit),
    ("test_initMinimumCapacity", test_initMinimumCapacity),
    ("test_initUniqueKeysWithValues", test_initUniqueKeysWithValues),
    ("test_initUniquingKeys", test_initUniquingKeys),
    ("test_initGrouping", test_initGrouping),
    ("test_filter", test_filter),
    ("test_subscript", test_subscript),
    ("test_subscriptDefaultValue", test_subscriptDefaultValue),
    ("test_mapValues", test_mapValues),
    ("test_merge", test_merge),
    ("test_mergingGeneric", test_mergingGeneric),
    ("test_merging", test_merging),
    ("test_removeAt", test_removeAt),
    ("test_removeValueForKey", test_removeValueForKey),
    ("test_removeAll", test_removeAll),
    ("test_keys", test_keys),
    ("test_values", test_values),
    ("test_capacity", test_capacity),
    ("test_reserveCapacity", test_reserveCapacity),
    ("test_Dictionary_init", test_Dictionary_init)
  ]
}

