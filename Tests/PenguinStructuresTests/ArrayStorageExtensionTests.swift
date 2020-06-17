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

class PopularityRatedArrayDispatchBase {
  class func popularity(_ me: UnsafeRawPointer) -> Double {
    fatalError("implement me.")
  }
}

class PopularityRatedArrayDispatch<Element: PopularityRated>
  : PopularityRatedArrayDispatchBase, ArrayDispatchProtocol
{
  override class func popularity(_ me: UnsafeRawPointer) -> Double {
    asStorage(me).popularity
  }
}

typealias AnyPopularityRatedArrayBuffer
  = AnyArrayBuffer_<PopularityRatedArrayDispatchBase>

extension AnyArrayBuffer_ where Dispatch == PopularityRatedArrayDispatchBase {
  init<Element: PopularityRated>(_ src: ArrayBuffer<Element>) {
    self.init(
      storage: src.storage,
      dispatch: PopularityRatedArrayDispatch<Element>.self)
  }
}

extension AnyArrayBuffer_ where Dispatch: PopularityRatedArrayDispatchBase {
  var popularity: Double {
    withUnsafePointer(to: storage) { dispatch.popularity($0) }
  }
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

extension ArrayDispatchProtocol where Element : Factoid {
  static func asNews(_ p: UnsafeRawPointer) -> Element.News {
    p.assumingMemoryBound(to: Element.News.self).pointee
  }
}

class FactoidArrayDispatchBase: PopularityRatedArrayDispatchBase {
  class func totalError(_ me: UnsafeRawPointer, latest: UnsafeRawPointer)
    -> Double
  {
    fatalError("implement me.")
  }
}

class FactoidArrayDispatch<Element: Factoid>
  : FactoidArrayDispatchBase, ArrayDispatchProtocol
{
  override class func popularity(_ me: UnsafeRawPointer) -> Double {
    asStorage(me).popularity
  }
  override class func totalError(
    _ me: UnsafeRawPointer, latest: UnsafeRawPointer
  ) -> Double
  {
    asStorage(me).totalError(latest: asNews(latest))
  }
}

typealias AnyFactoidArrayBuffer = AnyArrayBuffer_<FactoidArrayDispatchBase>

extension AnyArrayBuffer_ where Dispatch == FactoidArrayDispatchBase {
  init<Element: Factoid>(_ src: ArrayBuffer<Element>) {
    self.init(
      storage: src.storage,
      dispatch: FactoidArrayDispatch<Element>.self)
  }
}

extension AnyArrayBuffer_ where Dispatch: FactoidArrayDispatchBase {
  func totalError(latest: UnsafeRawPointer) -> Double {
    withUnsafePointer(to: storage) { dispatch.totalError($0, latest: latest) }
  }
}

extension Tracked: Factoid, PopularityRated where T: Factoid {
  func error(latest: T.News) -> Double { value.error(latest: latest) }
  var popularity: Double { value.popularity }
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
  static func test_totalError() {
    let s = ArrayStorage(factoids(0..<10))
    let latest = Tracked(0.5) { _ in }
    let total = s.totalError(latest: latest)
    
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
  
  func test_totalErrorArrayBuffer() {
    let s = ArrayBuffer<Truthy>(factoids(0..<10))
    let latest = Tracked(0.5) { _ in }
    let total = s.totalError(latest: latest)
    XCTAssertEqual(total, expectedTotalError(0..<10, latest: 0.5))
  }

  func test_totalErrorAnyArrayBuffer() {
    let s = AnyArrayBuffer(ArrayBuffer<Truthy>(factoids(0..<10)))
    let latest = Tracked(0.5) { _ in }
    let expected = expectedTotalError(0..<10, latest: 0.5)

    // Safely convert `s` to a buffer of known Element type and invoke
    // totalError.
    let total0 = ArrayBuffer<Truthy>(s)?.totalError(latest: latest)
    XCTAssertEqual(total0, expected)
    
    // Efficiently convert `s` to a buffer of known Element type and invoke
    // totalError.
    let total1 = ArrayBuffer<Truthy>(unsafelyDowncasting: s)
      .totalError(latest: latest)
    XCTAssertEqual(total1, expected)

    // Show that the safe conversion can fail detectably.
    let total2 = ArrayBuffer<Int>(s)?.count
    XCTAssertEqual(total2, nil)
  }

  func test_dynamicElementType() {
    let b0: AnyPopularityRatedArrayBuffer
      = .init(ArrayBuffer<Truthy>(factoids(0..<10)))
    XCTAssertEqual(b0.popularity, 35)
    
    let b1: AnyFactoidArrayBuffer = .init(ArrayBuffer<Truthy>(factoids(0..<10)))
    XCTAssertEqual(b1.popularity, 35)
    let latest = Tracked(0.5) { _ in }
    let expected = expectedTotalError(0..<10, latest: 0.5)
    let total = withUnsafePointer(to: latest) { b1.totalError(latest: $0)}
    XCTAssertEqual(total, expected)
  }
  
  static var allTests = [
    ("test_create", test_emptyInit),
    ("test_append", test_append),
    ("test_withUnsafeMutableBufferPointer", test_withUnsafeMutableBufferPointer),
    ("test_elementType", test_elementType),
    ("test_replacementStorage", test_replacementStorage),
    ("test_makeCopy", test_makeCopy),
    ("test_deinit", test_deinit),
    ("test_copyingInit", test_copyingInit),
    ("test_unsafeInitializingInit", test_unsafeInitializingInit),
    ("test_collectionSemantics", test_collectionSemantics),
    ("test_totalError", test_totalError),
    ("test_totalErrorArrayBuffer", test_totalErrorArrayBuffer),
    ("test_totalErrorAnyArrayBuffer", test_totalErrorAnyArrayBuffer),
    ("test_dynamicElementType", test_dynamicElementType),
  ]
}
