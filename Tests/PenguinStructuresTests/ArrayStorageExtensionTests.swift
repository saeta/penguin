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

/// Types whose total popularity can be measured.
protocol PopularityRated {
  /// A value describing how many times `self` has been quoted on Twitter.
  var popularity: Double { get }
}

/// Types that may represent erroneous statements.
///
/// Functionality depending on `Factoid` is built into the type-erased storage
/// tested in this file.
protocol Factoid: PopularityRated {
  /// A type that represents news relevant to this factoid.
  associatedtype News
  
  /// Returns a value describing just how erroneous `self` is, given today's
  /// news.
  func error(latest: News) -> Double
}

extension Tracked: Factoid, PopularityRated where T: Factoid {
  func error(latest: T.News) -> Double { value.error(latest: latest) }
  var popularity: Double { value.popularity }
}

extension AnyArrayStorage {
  /// Returns the sum of all stored errors, given the address of today's news.
  ///
  /// - Requires: `Element.self == Self.elementType`
  func totalError<Element: Factoid>(
    assumingElementType _: Element.Type, latest: Element.News
  ) -> Double {
    withUnsafeMutableBufferPointer(assumingElementType: Element.self) {
      $0.reduce(0.0) { $0 + $1.error(latest: latest) }
    }
  }
}

extension AnyArrayBuffer {
  func totalError<Element: Factoid>(
    assumingElementType _: Element.Type, latest: Element.News
  ) -> Double {
    storage.totalError(assumingElementType: Element.self, latest: latest)
  }
}

/// APIs that depend on the `Factoid` `Element` type.
extension ArrayStorage: PopularityRated where Element: PopularityRated {
  var popularity: Double { self.lazy.map(\.popularity).reduce(0.0, +) }
}

extension ArrayStorage where Element: Factoid {
  func totalError(latest: Element.News) -> Double {
    reduce(0.0) { $0 + $1.error(latest: latest) }
  }
}

extension ArrayBuffer where Element: Factoid {
  func totalError(latest: Element.News) -> Double {
    storage.totalError(latest: latest)
  }
}

/// A sample Factoid we can use for testing.
struct Truthy: Factoid, Comparable {
  var denominator: Double

  // Using `Tracked<Double>` for `News` to help verify that type erasure is
  // working properly.
  func error(latest: Tracked<Double>) -> Double {
    return latest.value / denominator
  }

  static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.denominator < rhs.denominator
  }
  
  var popularity: Double { 3.5 }
}

/// Returns a collection of `Factoids` with the given denominators.
func factoids(_ r: Range<Int>) -> LazyMapCollection<Range<Int>, Truthy> {
    r.lazy.map { Truthy(denominator: Double($0)) }
}

/// Returns the correct total error for `Factoids` with denominators given by `r`.
func expectedTotalError(_ r: Range<Int>, latest: Double) -> Double {
  r.reduce(0.0) { $0 + 0.5 / Double($1) }
}

extension ArrayStorage where Element == Truthy {
  static func test_totalError(typeErased: Bool = false) {
    let s = ArrayStorage(factoids(0..<10))
    let latest = Tracked(0.5) { _ in }
    let total = typeErased
      ? s.totalError(assumingElementType: Element.self, latest: latest)
      : s.totalError(latest: latest)
    
    XCTAssertEqual(total, expectedTotalError(0..<10, latest: 0.5))
  }
}

class ArrayStorageExtensionTests: XCTestCase {
  func test_emptyInit() {
    ArrayStorage<Truthy>.test_emptyInit()
  }

  func test_append() {
    ArrayStorage<Truthy>.test_append(source: factoids(0..<100))
  }

  func test_typeErasedAppend() {
    ArrayStorage<Truthy>.test_append(
      source: factoids(0..<100), typeErased: true)
  }
  
  func test_withUnsafeMutableBufferPointer() {
    ArrayStorage<Truthy>.test_withUnsafeMutableBufferPointer(
      sortedSource: factoids(99..<199))
  }

  func test_elementType() {
    XCTAssert(ArrayStorage<Truthy>.elementType == Truthy.self)
  }
  
  func test_replacementStorage() {
    ArrayStorage<Truthy>.test_replacementStorage(source: factoids(0..<10))
  }
  
  func test_makeCopy() {
    ArrayStorage<Truthy>.test_makeCopy(source: factoids(0..<10))
  }
  
  func test_deinit() {
    ArrayStorage<Tracked<Truthy>>.test_deinit {
      Tracked(Truthy(denominator: 2), track: $0)
    }
  }

  func test_copyingInit() {
    ArrayStorage<Truthy>.test_copyingInit(source: factoids(0..<50))
  }

  func test_unsafeInitializingInit() {
    ArrayStorage<Truthy>.test_unsafeInitializingInit(
      source: factoids(0..<50))
  }

  func test_collectionSemantics() {
    let expected = factoids(0..<35)
    var s = ArrayStorage(expected)
    s.checkRandomAccessCollectionSemantics(expectedValues: expected)
    s.checkMutableCollectionSemantics(source: factoids(35..<70))
  }

  
  func test_totalError() {
    ArrayStorage<Truthy>.test_totalError()
  }
  
  func test_typeErasedTotalError() {
    ArrayStorage<Truthy>.test_totalError(typeErased: true)
  }

  func test_totalErrorArrayBuffer() {
    let s = ArrayBuffer<Truthy>(factoids(0..<10))
    let latest = Tracked(0.5) { _ in }
    let total = s.totalError(latest: latest)
    XCTAssertEqual(total, expectedTotalError(0..<10, latest: 0.5))
  }

  func test_totalErrorAnyArrayBuffer() {
    let s = AnyArrayBuffer(ArrayBuffer<Truthy>(factoids(0..<10)))
    let latest = Tracked(0.5) { _ in }
    let total = s.totalError(assumingElementType: Truthy.self, latest: latest)
    XCTAssertEqual(total, expectedTotalError(0..<10, latest: 0.5))
  }

  func test_dynamicType() {
    let typeErasedBuffers: [AnyArrayBuffer] = [
      .init(ArrayBuffer<Int>()), .init(ArrayBuffer<Truthy>(factoids(0..<10)))]

    XCTAssert(typeErasedBuffers[0].storage as? PopularityRated == nil)
    XCTAssert(typeErasedBuffers[1].storage as? PopularityRated != nil)
    XCTAssertEqual(
      (typeErasedBuffers[1].storage as? PopularityRated)?.popularity, 35)
  }
  
  static var allTests = [
    ("test_create", test_emptyInit),
    ("test_append", test_append),
    ("test_typeErasedAppend", test_typeErasedAppend),
    ("test_withUnsafeMutableBufferPointer", test_withUnsafeMutableBufferPointer),
    ("test_elementType", test_elementType),
    ("test_replacementStorage", test_replacementStorage),
    ("test_makeCopy", test_makeCopy),
    ("test_deinit", test_deinit),
    ("test_copyingInit", test_copyingInit),
    ("test_unsafeInitializingInit", test_unsafeInitializingInit),
    ("test_collectionSemantics", test_collectionSemantics),
    ("test_totalError", test_totalError),
    ("test_typeErasedTotalError", test_typeErasedTotalError),
    ("test_totalErrorArrayBuffer", test_totalErrorArrayBuffer),
    ("test_totalErrorAnyArrayBuffer", test_totalErrorAnyArrayBuffer),
    ("test_dynamicType", test_dynamicType),
  ]
}
