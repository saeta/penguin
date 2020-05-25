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
  /// Returns a sequence of the positive integers that are coprime with `self`.
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
public struct PositiveCoprimes<Domain: BinaryInteger>: Sequence {
  /// The number to find coprimes relative to.
  let target: Domain

  /// Constructs a `PositiveCoprimes` sequence of numbers coprime relative to `n`.
  internal init(_ target: Domain) {
    var target = target
    if target < 0 {
      target = target * -1  // Make positive; Swift.abs is unavailable.
    }
    self.target = target
  }

  /// Returns an iterator that incrementally computes coprimes relative to `n`.
  public func makeIterator() -> Iterator {
    Iterator(target: target)
  }

  /// Iteratively computes coprimes relative to `n` starting from 1.
  public struct Iterator: IteratorProtocol {
    /// The number we are finding coprimes relative to.
    let target: Domain
    /// The next candidate to test for relative primality.
    var nextCandidate: Domain = 1

    /// Returns the next positive coprime, or nil if no coprimes are defined.
    mutating public func next() -> Domain? {
      if _slowPath(target == 0) { return nil }  // Nothing is coprime with 0.
      while true {
        let candidate = nextCandidate
        nextCandidate += 1
        if gcd(candidate, target) == 1 { return candidate }
      }
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
