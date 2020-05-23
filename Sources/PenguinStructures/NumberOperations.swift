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
  /// Returns a sequence of the positive integers that are co-prime with `self`.
  ///
  /// Definition: Two numbers are co-prime if their GCD is 1.
  public var positiveCoprimes: PositiveCoprimes<Self> { PositiveCoprimes(self) }
}

/// A sequence of numbers that are co-prime with `n`, up to `n`.
public struct PositiveCoprimes<Number: BinaryInteger>: Sequence {
  /// The number to find co-primes relative to.
  let n: Number

  /// Constructs a `PositiveCoprimes` sequence of numbers co-prime relative to `n`.
  internal init(_ n: Number) {
    precondition(n > 0, "\(n) doees not have defined positive co-primes.")
    self.n = n
  }

  /// Returns an iterator that incrementally computes co-primes relative to `n`.
  public func makeIterator() -> Iterator {
    Iterator(n: n, i: 0)
  }

  /// Iteratively computes co-primes relative to `n` starting from 1.
  public struct Iterator: IteratorProtocol {
    /// The number we are finding co-primes relative to.
    let n: Number
    /// A sequence counter representing one less than the next candidate to try.
    var i: Number

    /// Returns the next co-prime, or nil if all co-primes have been found.
    mutating public func next() -> Number? {
      while (i+1) < n {
        i += 1
        if greatestCommonDivisor(i, n) == 1 { return i }
      }
      return nil
    }
  }
}

/// Returns the greatest common divisor between two numbers.
///
/// This implementation uses Euclid's algorithm.
// TODO: Switch to the Binary GCD algorithm which avoids expensive modulo operations.
public func greatestCommonDivisor<Number: BinaryInteger>(_ a: Number, _ b: Number) -> Number {
  var a = a
  var b = b
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
