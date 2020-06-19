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

extension BinaryInteger {
  /// Returns a collection of the positive integers that are coprime with `self`.
  ///
  /// Definition: Two numbers are coprime if their GCD is 1.
  public var positiveCoprimes: PositiveCoprimes<Self> { .init(self) }

  /// Returns positive integers that are coprime with, and smaller than, `self`.
  ///
  /// - SeeAlso: `positiveCoprimes`.
  public var smallerPositiveCoprimes: [Self] {
    var positiveSelf = self
    if positiveSelf < 0 {
      positiveSelf *= -1  // Workaround for lack of `Swift.abs` on `BinaryInteger`.
    }
    return positiveCoprimes.prefix { $0 < positiveSelf }
  }
}

/// The positive values that are coprime with *N*.
///
/// Example:
/// ```
/// print(Array(10.positiveCoprimes.prefix(8)))  // [1, 3, 7, 9, 11, 13, 17, 19]
/// ```
///
/// Note: Although there are infinitely many positive prime numbers, `PositiveCoprimes` is bounded
/// by the maximum representable integer in `Domain`.
// TODO: Specialize SubSequence for efficiency.
public struct PositiveCoprimes<Domain: BinaryInteger>: Collection {
  /// The number to find coprimes relative to.
  public let target: Domain

  /// The index into the collection of positive coprimes are the coprimes themselves.
  ///
  /// Note: the indices are not dense or contiguous in `Domain`.
  public typealias Index = Domain

  /// Creates a collection of numbers coprime relative to `n`.
  internal init(_ target: Domain) {
    var target = target
    if target < 0 {
      target = target * -1  // Make positive; Swift.abs is unavailable.
    }
    self.target = target
  }

  /// `Int.max`, as there are infinitely many prime numbers, and thus infinitely many coprimes
  /// to a given target.
  public var count: Int {
    if _slowPath(target == 0) { return 0 }
    return Int.max
  }

  /// Accesses the coprime at `index`.
  public subscript(index: Index) -> Domain {
    index
  }

  /// The first valid coprime (1).
  public var startIndex: Index { 1 }

  /// The largest positive reasonable coprime.
  ///
  /// Note: if a `BinaryInteger` larger than `UInt64.max` is used, the `endIndex` might leave off
  /// potentially useful integers.
  public var endIndex: Index {
    if _slowPath(target == 0) { return startIndex }
    return Domain(clamping: UInt64.max)
  }

  /// Computes the next index after `index`.
  public func index(after index: Index) -> Index {
    var nextCandidate = index
    while true {
      nextCandidate += 1
      if gcd(nextCandidate, target) == 1 { return nextCandidate }
    }
  }
}

/// Returns the greatest common divisor of `a` and `b`.
///
/// - Complexity: O(n^2) where `n` is the number of bits in `Domain`.
// TODO: Switch to the Binary GCD algorithm which avoids expensive modulo operations.
public func gcd<Domain: BinaryInteger>(_ a: Domain, _ b: Domain) -> Domain {
  var a = a
  var b = b

  if a < 0 {
    a *= -1
  }

  if b < 0 {
    b *= -1
  }

  if a > b {
    swap(&a, &b)
  }
  while b != 0 {
    let tmp = a
    a = b
    b = tmp % b
  }
  return a
}
