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

/// Fast pseudorandom number generator using [permuted congruential
/// generators](https://www.pcg-random.org/).
public struct PCGRandomNumberGenerator: RandomNumberGenerator {
  static var stream: UInt64 { 0xda3e_39cb_94b9_5bdb }

  var state: UInt64

  public init(state: UInt64) {
    self.state = state
  }

  public mutating func next() -> UInt32 {
    let current = state
    // Update the internal state
    state = current &* 6_364_136_223_846_793_005 &+ Self.stream
    // Calculate output function (XSH-RS scheme), uses old state for max ILP.
    let base = (current ^ (current >> 22))
    let shift = Int(22 + (current >> 61))
    return UInt32(truncatingIfNeeded: base >> shift)
  }
}
