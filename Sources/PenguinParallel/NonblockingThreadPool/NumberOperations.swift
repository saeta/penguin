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

/// Returns a value deterministically selected from `0..<size`.
///
/// This is a faster variation than computing `x % size`. For additional context, please see:
///     https://lemire.me/blog/2016/06/27/a-fast-alternative-to-the-modulo-reduction
internal func fastFit(_ lhs: Int, into size: Int) -> Int {
  let l = UInt32(lhs)
  let r = UInt32(size)
  return Int(l.multipliedFullWidth(by: r).high)
}

/// Fast pseudorandom number generator using [permuted congruential
/// generators](https://www.pcg-random.org/).
internal struct PCGRandomNumberGenerator: RandomNumberGenerator {
  var state: UInt64
  static var stream: UInt64 { 0xda3e_39cb_94b9_5bdb }

  mutating func next() -> UInt32 {
    let current = state
    // Update the internal state
    state = current &* 6_364_136_223_846_793_005 &+ Self.stream
    // Calculate output function (XSH-RS scheme), uses old state for max ILP.
    let base = (current ^ (current >> 22))
    let shift = Int(22 + (current >> 61))
    return UInt32(truncatingIfNeeded: base >> shift)
  }
}
