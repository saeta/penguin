//******************************************************************************
// Copyright 2019 Google LLC
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

import XCTest
import PenguinStructures

// ************************************************************************
// A demonstration that we can write straightforward algorithms over tuples
// ************************************************************************

/// Function-like types that can be passed any argument type.
protocol GenericFunction {
  associatedtype Result
  func callAsFunction<T>(_: T) -> Result
}

/// Returns `[T].self`, given an argument of type `T`
struct ArrayType: GenericFunction {
  func callAsFunction<T>(_ x: T) -> Any.Type {
    [T].self
  }
}

struct X<T>: DefaultInitializable, Equatable {}

extension TupleProtocol {
  /// Returns `start` reduced via `reducer` into the result of calling `mapper` 
  /// on each element.
  func mapReduce<M: GenericFunction, R>(
    _ start: R, _ mapper: M, _ reducer: (R, M.Result)->R
  ) -> R {
    if Self.self == Empty.self { return start }
    let next = reducer(start, mapper(head))
    return tail.mapReduce(next, mapper, reducer)
  }
}

class TupleTests: XCTestCase {
  func test_mapReduce() {
    XCTAssertEqual(
      Tuple(2, 3.4, "Bar").mapReduce([], ArrayType()) { $0 + [$1] }
        .lazy.map(ObjectIdentifier.init),
      [[Int].self, [Double].self, [String].self]
        .lazy.map(ObjectIdentifier.init)
    )
  }

  func test_head() {
    XCTAssertEqual(Tuple(0).head, 0)
    XCTAssertEqual(Tuple(0.0, 1).head, 0.0)
    XCTAssertEqual(Tuple("foo", 0.0, 1).head, "foo")
  }
  
  func test_tail() {
    XCTAssertEqual(Tuple(0).tail, Empty())
    XCTAssertEqual(Tuple(0.0, 1).tail, Tuple(1))
    XCTAssertEqual(Tuple("foo", 0.0, 1).tail, Tuple(0.0, 1))
  }

  func test_count() {
    typealias I = Int
    XCTAssertEqual(Tuple0.count, 0)
    XCTAssertEqual(Tuple1<I>.count, 1)
    XCTAssertEqual(Tuple2<I, I>.count, 2)
    XCTAssertEqual(Tuple3<I, I, I>.count, 3)
  }

  func test_DefaultInitializable() {
    XCTAssertEqual(Tuple0(), Empty())
    XCTAssertEqual(Tuple1<X<Int>>(), Tuple(.init()))
    XCTAssertEqual(Tuple2<X<Int>, X<String>>(), Tuple(.init(), .init()))
  }
  
  func test_Equatable() {
    XCTAssertEqual(Tuple0(), Tuple0())
    
    XCTAssertEqual(Tuple(1), Tuple(1))
    XCTAssertNotEqual(Tuple(1), Tuple(2))
    
    XCTAssertEqual(Tuple(1, 2), Tuple(1, 2))
    XCTAssertNotEqual(Tuple(0, 2), Tuple(1, 2))
    XCTAssertNotEqual(Tuple(1, "2"), Tuple(1, "XXX"))
    
    XCTAssertEqual(Tuple(1, 2.3, "4"), Tuple(1, 2.3, "4"))
    XCTAssertNotEqual(Tuple(1, 2.3, "5"), Tuple(1, 2.3, "4"))
    XCTAssertNotEqual(Tuple(1, 2.9, "4"), Tuple(1, 2.3, "4"))
    XCTAssertNotEqual(Tuple(0, 2.3, "4"), Tuple(1, 2.3, "4"))
    // This effectively tests Hashable too; we know the conformance synthesizer
    // is considering all the fields in order.
  }

  func test_Comparable() {
    XCTAssertLessThanOrEqual(Tuple0(), Tuple0())
    XCTAssertGreaterThanOrEqual(Tuple0(), Tuple0())
    
    XCTAssertLessThan(Tuple(1), Tuple(2))
    // Consistency with equality
    XCTAssertLessThanOrEqual(Tuple(2), Tuple(2))
    XCTAssertGreaterThanOrEqual(Tuple(2), Tuple(2))

    XCTAssertLessThan(Tuple(1, 0.1), Tuple(2, 1.1))
    XCTAssertLessThan(Tuple(1, 1.1), Tuple(2, 1.1))
    XCTAssertLessThan(Tuple(2, 0.1), Tuple(2, 1.1))
    
    // Consistency with equality
    XCTAssertLessThanOrEqual(Tuple(2, 1.1), Tuple(2, 1.1))
    XCTAssertGreaterThanOrEqual(Tuple(2, 1.1), Tuple(2, 1.1))

    XCTAssertLessThan(Tuple(1, 0.1, 0 as UInt), Tuple(2, 1.1, 1 as UInt))
    XCTAssertLessThan(Tuple(1, 0.1, 1 as UInt), Tuple(2, 1.1, 1 as UInt))
    XCTAssertLessThan(Tuple(1, 1.1, 0 as UInt), Tuple(2, 1.1, 1 as UInt))
    XCTAssertLessThan(Tuple(1, 1.1, 1 as UInt), Tuple(2, 1.1, 1 as UInt))
    XCTAssertLessThan(Tuple(2, 0.1, 0 as UInt), Tuple(2, 1.1, 1 as UInt))
    XCTAssertLessThan(Tuple(2, 0.1, 1 as UInt), Tuple(2, 1.1, 1 as UInt))
    XCTAssertLessThan(Tuple(2, 1.1, 0 as UInt), Tuple(2, 1.1, 1 as UInt))
    
    // Consistency with equality
    XCTAssertLessThanOrEqual(Tuple(2, 1.1, 1 as UInt), Tuple(2, 1.1, 1 as UInt))
    XCTAssertGreaterThanOrEqual(Tuple(2, 1.1, 1 as UInt), Tuple(2, 1.1, 1 as UInt))
  }

  func test_CustomStringConvertible() {
    XCTAssertEqual("\(Empty())", "Empty()")
    XCTAssertEqual("\(Tuple(1))", "Tuple(1)")
    XCTAssertEqual("\(Tuple(1, 2.5, "foo"))", "Tuple(1, 2.5, \"foo\")")
  }

  func test_conveniences() {
    struct X0 {  }; let x0 = X0()
    struct X1 {  }; let x1 = X1()
    struct X2 {  }; let x2 = X2()
    struct X3 {  }; let x3 = X3()
    struct X4 {  }; let x4 = X4()
    struct X5 {  }; let x5 = X5()
    struct X6 {  }; let x6 = X6()

    XCTAssert(type(of: Tuple(x0)) == Tuple1<X0>.self)
    XCTAssert(type(of: Tuple(x0, x1)) == Tuple2<X0, X1>.self)
    XCTAssert(type(of: Tuple(x0, x1, x2)) == Tuple3<X0, X1, X2>.self)
    XCTAssert(type(of: Tuple(x0, x1, x2, x3)) == Tuple4<X0, X1, X2, X3>.self)
    XCTAssert(
      type(of: Tuple(x0, x1, x2, x3, x4)) == Tuple5<X0, X1, X2, X3, X4>.self)
    XCTAssert(
      type(of: Tuple(x0, x1, x2, x3, x4, x5))
        == Tuple6<X0, X1, X2, X3, X4, X5>.self)
    XCTAssert(
      type(of: Tuple(x0, x1, x2, x3, x4, x5, x6))
        == Tuple7<X0, X1, X2, X3, X4, X5, X6>.self)
  }
  
  static var allTests = [
    ("test_mapReduce", test_mapReduce),
  ]
}

