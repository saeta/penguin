//******************************************************************************
// Copyright 2020 Google LLC
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
  final func totalError(latestAt p: UnsafeRawPointer) -> Double {
    factoidImplementation.totalError_(latestAt: p)
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
    withUnsafeMutableBufferPointer { elements in
      elements.reduce(0.0) { $0 + $1.error(latest: latest) }
    }
  }
  
  func totalError_(latestAt p: UnsafeRawPointer) -> Double {
    totalError(latest: p.assumingMemoryBound(to: Element.News.self)[0])
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

class test_ExtendedStorage: XCTestCase {
  final func factoids(_ r: Range<Int>) -> LazyMapCollection<Range<Int>, Truthy> {
    r.lazy.map { Truthy(denominator: Double($0)) }
  }
  
  func test_create() {
    FactoidArrayStorage<Truthy>.test_create()
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

  func test_withUnsafeMutableRawBufferPointer() {
    FactoidArrayStorage<Truthy>.test_withUnsafeMutableBufferPointer(
      sortedSource: factoids(99..<199), raw: true)
  }

  func test_deinit() {
    FactoidArrayStorage<Tracked<Truthy>>.test_deinit {
      Tracked(Truthy(denominator: 2), track: $0)
    }
  }

  func test_totalError() {
    let s = FactoidArrayStorage<Truthy>.create(minimumCapacity: 10)
    for f in factoids(0..<10) { _ = s.append(f) }
    let latest = Tracked(0.5) { _ in }
    let total = withUnsafePointer(to: latest) {
      s.totalError(latestAt: $0)
    }
    let expected = (0..<10).reduce(0.0) { $0 + 0.5 / Double($1) }
    XCTAssertEqual(total, expected)
  }
}
