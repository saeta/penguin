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

/// Types that may represent erroneous statements.
///
/// Functionality depending on `Factoid` is built into the type-erased storage
/// tested in this file.
protocol Factoid {
  /// A type that represents news relevant to this factoid.
  associatedtype News
  
  /// Returns a value describing just how erroneous `self` is, given today's
  /// news.
  func error(latest: News) -> Double
}

extension Tracked: Factoid where T: Factoid {
  func error(latest: T.News) -> Double { value.error(latest: latest) }
}

/// Contiguous storage of homogeneous `Factoid`s of statically unknown type.
///
/// This class provides the element-type-agnostic API for FactoidArrayStorage<T>.
class AnyFactoidArrayStorage: AnyArrayStorage {
  typealias FactoidImplementation = AnyFactoidArrayStorageImplementation

  var factoidImplementation: FactoidImplementation {
    fatalError("implement me!")
  }

  /// Returns the sum of all stored errors, given the address of today's news.
  final func unsafeTotalError<News>(latest p: UnsafeRawPointer) -> Double {
    factoidImplementation.totalError_(latestAt: p)
  }

  final var newsType: Any.Type { factoidImplementation.newsType }
}

extension AnyArrayBuffer where Storage: AnyFactoidArrayStorage {
  func totalError(latestAt p: UnsafeRawPointer) -> Double {
    storage.totalError(latestAt: p)
  }
}

/// Contiguous storage of homogeneous `Factoid`s of statically unknown type.
///
/// Conformances to this protocol provide the implementations for
/// `AnyFactoidArrayStorage` APIs.
protocol AnyFactoidArrayStorageImplementation: AnyFactoidArrayStorage {
  func totalError_(latestAt p: UnsafeRawPointer) -> Double
}

/// APIs that depend on the `Factoid` `Element` type.
extension ArrayStorageImplementation where Element: Factoid {
  func totalError(latest: Element.News) -> Double {
    reduce(0.0) { $0 + $1.error(latest: latest) }
  }
  
  func totalError_(latestAt p: UnsafeRawPointer) -> Double {
    totalError(latest: p.assumingMemoryBound(to: Element.News.self)[0])
  }
}

extension ArrayBuffer where Element: Factoid {
  func totalError(latest: Element.News) -> Double {
    storage.totalError(latest: latest)
  }
}

/// Type-erasable storage for contiguous `Factoid` `Element` instances.
///
/// Note: instances have reference semantics.
final class FactoidArrayStorage<Element: Factoid>:
  AnyFactoidArrayStorage, AnyFactoidArrayStorageImplementation,
  ArrayStorageImplementation
{
  override var implementation: AnyArrayStorageImplementation { self }
  override var factoidImplementation: AnyFactoidArrayStorageImplementation { self }
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
}

/// Returns a collection of `Factoids` with the given denominators.
func factoids(_ r: Range<Int>) -> LazyMapCollection<Range<Int>, Truthy> {
    r.lazy.map { Truthy(denominator: Double($0)) }
}

/// Returns the correct total error for `Factoids` with denominators given by `r`.
func expectedTotalError(_ r: Range<Int>, latest: Double) -> Double {
  r.reduce(0.0) { $0 + 0.5 / Double($1) }
}

extension FactoidArrayStorage where Element == Truthy {
  static func test_totalError(typeErased: Bool = false) {
    let s = FactoidArrayStorage(factoids(0..<10))
    let latest = Tracked(0.5) { _ in }
    let total = typeErased
      ? withUnsafePointer(to: latest) { s.totalError(latestAt: $0) }
      : s.totalError(latest: latest)
    
    XCTAssertEqual(total, expectedTotalError(0..<10, latest: 0.5))
  }
}

class ArrayStorageExtensionTests: XCTestCase {
  func test_emptyInit() {
    FactoidArrayStorage<Truthy>.test_emptyInit()
  }

  func test_append() {
    FactoidArrayStorage<Truthy>.test_append(source: factoids(0..<100))
  }

  func test_typeErasedAppend() {
    FactoidArrayStorage<Truthy>.test_append(
      source: factoids(0..<100), typeErased: true)
  }
  
  func test_withUnsafeMutableBufferPointer() {
    FactoidArrayStorage<Truthy>.test_withUnsafeMutableBufferPointer(
      sortedSource: factoids(99..<199))
  }

  func test_typeErasedWithUnsafeMutableBufferPointer() {
    FactoidArrayStorage<Truthy>.test_withUnsafeMutableBufferPointer(
      sortedSource: factoids(99..<199), typeErased: true)
  }

  func test_elementType() {
    XCTAssert(
      FactoidArrayStorage<Truthy>(minimumCapacity: 0).elementType
        == Truthy.self)
  }
  
  func test_replacementStorage() {
    FactoidArrayStorage<Truthy>.test_replacementStorage(source: factoids(0..<10))
  }
  
  func test_makeCopy() {
    FactoidArrayStorage<Truthy>.test_makeCopy(source: factoids(0..<10))
  }
  
  func test_deinit() {
    FactoidArrayStorage<Tracked<Truthy>>.test_deinit {
      Tracked(Truthy(denominator: 2), track: $0)
    }
  }

  func test_copyingInit() {
    FactoidArrayStorage<Truthy>.test_copyingInit(source: factoids(0..<50))
  }

  func test_unsafeInitializingInit() {
    FactoidArrayStorage<Truthy>.test_unsafeInitializingInit(
      source: factoids(0..<50))
  }

  func test_collectionSemantics() {
    let expected = factoids(0..<35)
    var s = FactoidArrayStorage(expected)
    s.checkRandomAccessCollectionSemantics(expectedValues: expected)
    s.checkMutableCollectionSemantics(source: factoids(35..<70))
  }

  
  func test_totalError() {
    FactoidArrayStorage<Truthy>.test_totalError()
  }
  
  func test_typeErasedTotalError() {
    FactoidArrayStorage<Truthy>.test_totalError(typeErased: true)
  }

  func test_totalErrorArrayBuffer() {
    let s = ArrayBuffer<FactoidArrayStorage<Truthy>>(factoids(0..<10))
    let latest = Tracked(0.5) { _ in }
    let total = s.totalError(latest: latest)
    XCTAssertEqual(total, expectedTotalError(0..<10, latest: 0.5))
  }

  func test_totalErrorAnyArrayBuffer() {
    let s: AnyArrayBuffer<FactoidArrayStorage<Truthy>> =
      AnyArrayBuffer(ArrayBuffer<FactoidArrayStorage<Truthy>>(factoids(0..<10)))
    let latest = Tracked(0.5) { _ in }
    let total = withUnsafePointer(to: latest) { s.totalError(latestAt: $0) }
    XCTAssertEqual(total, expectedTotalError(0..<10, latest: 0.5))
  }

  static var allTests = [
    ("test_create", test_emptyInit),
    ("test_append", test_append),
    ("test_typeErasedAppend", test_typeErasedAppend),
    ("test_withUnsafeMutableBufferPointer", test_withUnsafeMutableBufferPointer),
    (
      "test_typeErasedWithUnsafeMutableBufferPointer",
     test_typeErasedWithUnsafeMutableBufferPointer),
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
  ]
}
