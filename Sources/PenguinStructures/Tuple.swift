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
//

/// Generalized algebraic product types
///
/// Swift's built-in tuple types are algebraic product types, but since they are
/// not nominal and not easily decomposed, they don't lend themselves to many
/// types of useful processing.  Models of `Tuple` don't have those problems.
public protocol AlgebraicProduct {
  /// The type of the first element.
  associatedtype Head

  /// An algebriac product formed by composing the remaining elements.
  associatedtype Tail: AlgebraicProduct

  /// The first element.
  var head: Head { get set }
  
  /// All elements but the first.
  var tail: Tail { get set }
}

extension Empty: AlgebraicProduct {
  /// The first element, when `self` is viewed as an instance of algebraic
  /// product type.
  public var head: Never { get {  fatalError() } set {  } }
  
  /// All elements but the first, when `self` is viewed as an instance of
  /// algebraic product type.
  public var tail: Self { get { self } set { } }
}

/// An algebraic product type whose first element is of type `Head` and
/// whose remaining elements can be stored in `Tail`.
public struct Tuple<Head, Tail: AlgebraicProduct>: AlgebraicProduct {
  /// The first element.
  public var head: Head
  
  /// All elements but the first.
  public var tail: Tail
}

extension Tuple: DefaultInitializable
  where Head: DefaultInitializable, Tail: DefaultInitializable
{
  // Initialize `self`.
  public init() {
    head = Head()
    tail = Tail()
  }
}

extension Tuple: Equatable where Head: Equatable, Tail: Equatable {}
extension Tuple: Hashable where Head: Hashable, Tail: Hashable {}
extension Tuple: Comparable where Head: Comparable, Tail: Comparable {
  public static func < (lhs: Self, rhs: Self) -> Bool {
    if lhs.head < rhs.head { return true }
    if lhs.head > rhs.head { return false }
    return lhs.tail < rhs.tail
  }
}

private let prefixLength = "Tuple(".count

extension Tuple: CustomStringConvertible {
  public var description: String {
    if Tail.self == Empty.self {
      return "Tuple(\(String(reflecting:head )))"
    }
    else {
      return "Tuple(\(String(reflecting: head)), "
        + String(reflecting: tail).dropFirst(prefixLength)
    }
  }
}

// ======== Conveniences ============

public typealias Tuple0 = Empty
public typealias Tuple1<T0> = Tuple<T0, Tuple0>
public typealias Tuple2<T0, T1> = Tuple<T0, Tuple1<T1>>
public typealias Tuple3<T0, T1, T2> = Tuple<T0, Tuple2<T1, T2>>
public typealias Tuple4<T0, T1, T2, T3> = Tuple<T0, Tuple3<T1, T2, T3>>
public typealias Tuple5<T0, T1, T2, T3, T4> = Tuple<T0, Tuple4<T1, T2, T3, T4>>
public typealias Tuple6<T0, T1, T2, T3, T4, T5>
  = Tuple<T0, Tuple5<T1, T2, T3, T4, T5>>
public typealias Tuple7<T0, T1, T2, T3, T4, T5, T6>
  = Tuple<T0, Tuple6<T1, T2, T3, T4, T5, T6>>

public extension Tuple where Tail == Empty {
  /// Creates an instance containing the arguments, in order.
  init(_ a0: Head) {
    head = a0; tail = Tuple0()
  }
}
public extension Tuple {
  /// Creates an instance containing the arguments, in order.
  init<T1>(_ a0: Head, _ a1: T1) where Tail == Tuple1<T1> {
    head = a0; tail = Tuple1(a1)
  }
  /// Creates an instance containing the arguments, in order.
  init<T1, T2>(_ a0: Head, _ a1: T1, _ a2: T2) where Tail == Tuple2<T1, T2> {
    head = a0; tail = Tuple2(a1, a2)
  }
  /// Creates an instance containing the arguments, in order.
  init<T1, T2, T3>(_ a0: Head, _ a1: T1, _ a2: T2, _ a3: T3)
    where Tail == Tuple3<T1, T2, T3>
  {
    head = a0; tail = Tuple3(a1, a2, a3)
  }
  /// Creates an instance containing the arguments, in order.
  init<T1, T2, T3, T4>(_ a0: Head, _ a1: T1, _ a2: T2, _ a3: T3, _ a4: T4)
    where Tail == Tuple4<T1, T2, T3, T4>
  {
    head = a0; tail = Tuple4(a1, a2, a3, a4)
  }
  /// Creates an instance containing the arguments, in order.
  init<T1, T2, T3, T4, T5>(
    _ a0: Head, _ a1: T1, _ a2: T2, _ a3: T3, _ a4: T4, _ a5: T5
  )
    where Tail == Tuple5<T1, T2, T3, T4, T5>
  {
    head = a0; tail = Tuple5(a1, a2, a3, a4, a5)
  }
  /// Creates an instance containing the arguments, in order.
  init<T1, T2, T3, T4, T5, T6>(
    _ a0: Head, _ a1: T1, _ a2: T2, _ a3: T3, _ a4: T4, _ a5: T5, _ a6: T6
  )
    where Tail == Tuple6<T1, T2, T3, T4, T5, T6>
  {
    head = a0; tail = Tuple6(a1, a2, a3, a4, a5, a6)
  }
}
