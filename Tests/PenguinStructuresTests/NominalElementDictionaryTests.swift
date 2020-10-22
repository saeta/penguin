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

final class NominalElementDictionaryTests: XCTestCase {
  private static let uniqueUnlabeledTuples = (0..<9).map { ($0, String($0)) }
  private static let uniqueLabeledTuples
    = (0..<9).map { (key: $0, value: String($0)) }
  private static let uniqueKeyValues = (0..<9).map {
    KeyValuePair(key: $0, value: String($0))
  }
  private let p0 = NominalElementDictionary(
    uniqueKeysWithValues: NominalElementDictionaryTests.uniqueKeyValues)
  private let p1 = Dictionary<Int, String>(
      uniqueKeysWithValues: NominalElementDictionaryTests.uniqueUnlabeledTuples)
    
  func test_interopFunctions() {
    var d = NominalElementDictionary<Int, String>()
    d.merge(Self.uniqueUnlabeledTuples.keyValuePairs()) { _,_ in fatalError() }
    XCTAssert(Self.uniqueUnlabeledTuples.allSatisfy { d[$0.0] == $0.1 })

    d.removeAll()
    d.merge(Self.uniqueLabeledTuples.keyValuePairs()) { _,_ in fatalError() }
    XCTAssert(Self.uniqueLabeledTuples.allSatisfy { d[$0.key] == $0.value })

    XCTAssert(d.keyValueTuples().count == d.count)
    XCTAssert(d.keyValueTuples().allSatisfy { d[$0.0] == $0.1 } )
  }

  func test_collectionSemantics() {
    let d = p0
    let expectedContents = Self.uniqueKeyValues.sorted {
      d.index(forKey: $0.key) ?? d.endIndex
        < d.index(forKey: $1.key) ?? d.endIndex
    }
    d.checkCollectionSemantics(expecting: expectedContents)
  }

  func test_initFromDictionary() {
    let d0: [Int: String] = .init(uniqueKeysWithValues: Self.uniqueLabeledTuples)
    let d1 = NominalElementDictionary(d0)
    XCTAssertEqual(Array(d0.keyValuePairs()), Array(d1))
  }
  
  func test_defaultInit() {
    let d = NominalElementDictionary<Int, String>()
    XCTAssert(d.isEmpty)
  }

  func test_initMinimumCapacity() {
    let d = NominalElementDictionary<Int, String>(minimumCapacity: 100)
    XCTAssert(d.capacity >= 100)
  }

  func test_initUniqueKeysWithValues() {
    let d = p0
    XCTAssertEqual(d.count, Self.uniqueKeyValues.count)
    XCTAssert(Self.uniqueKeyValues.allSatisfy { d[$0.key] == $0.value })
    // TODO: test for traps when keys are not unique.
    // https://github.com/saeta/penguin/issues/64
  }

  func test_initUniquingKeys() {
    let dups = repeatElement(Self.uniqueKeyValues, count: 2).joined()
    let d0 = NominalElementDictionary(dups, uniquingKeysWith: +)
    let d1 = Dictionary<Int, String>(
      dups.lazy.map { ($0.key, $0.value) }, uniquingKeysWith: +)
    XCTAssertEqual(d0.base, d1)
  }

  func test_initGrouping() {
    let d0 = NominalElementDictionary(grouping: 0..<100, by: { $0 % 13 })
    let d1 = Dictionary(grouping: 0..<100, by: { $0 % 13 })
    XCTAssertEqual(d0.base, d1)
  }

  func test_filter() {
    let d0 = p0.filter { (kv: KeyValuePair)->Bool in (kv.key % 3) == 0 }
    let d1 = p1.filter { kv in (kv.key % 3) == 0 }
    
    XCTAssertEqual(d0.base, d1)
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
  }
  
  func test_mapValues() {
    let d0 = p0.mapValues { v in Int(v) }
    let d1 = p1.mapValues { v in Int(v) }
    XCTAssertEqual(d0.base, d1)
  }
  
  func test_merge() {
    var d0 = p0
    var d1 = p1
    d0.merge(d0, uniquingKeysWith: +)
    d1.merge(d1, uniquingKeysWith: +)
    XCTAssertEqual(d0.base, d1)
  }
  
  func test_mergingGeneric() {
    let d0 = p0.merging(p0.sorted(), uniquingKeysWith: +)
    let d1 = p1.merging(Array(p1), uniquingKeysWith: +)
    XCTAssertEqual(d0.base, d1)
  }
  
  func test_merging() {
    let d0 = p0.merging(p0, uniquingKeysWith: +)
    let d1 = p1.merging(p1, uniquingKeysWith: +)
    XCTAssertEqual(d0.base, d1)
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
    XCTAssertEqual(d0.base, d1)
  }
  
  func test_removeValueForKey() {
    var d0 = p0
    var d1 = p1
    for k in ((0..<5).lazy.map { $0 * 3 }) {
      let v0 = d0.removeValue(forKey: k)
      let v1 = d1.removeValue(forKey: k)
      XCTAssertEqual(v0, v1)
    }
    XCTAssertEqual(d0.base, d1)
  }
  
  func test_removeAll() {
    let freshEmpty = NominalElementDictionary<Int, String>()
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
    XCTAssertEqual(p0.keys, p1.keys)
  }
  
  func test_values() {
    XCTAssertEqual(p0.values.sorted(), p1.values.sorted())
    var d0 = p0
    var d1 = p1
    d0.values[d0.index(forKey: 3)!] = "boogie"
    d1.values[d1.index(forKey: 3)!] = "boogie"
    XCTAssertEqual(d0.base, d1)
  }

  func test_popFirst() {
    var d0 = p0
    var pops = 0
    while let e = d0.popFirst() {
      pops += 1
      XCTAssert(p0.contains(e))
      XCTAssert(!d0.contains(e))
      XCTAssertEqual(pops, p0.count - d0.count)
    }
    XCTAssert(d0.isEmpty)
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

  // TODO: test Encodable/Decodable semantics.
  
  static var allTests = [
    ("test_interopFunctions", test_interopFunctions),
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
    ("test_popFirst", test_popFirst),
    ("test_capacity", test_capacity),
    ("test_reserveCapacity", test_reserveCapacity),
  ]
}

