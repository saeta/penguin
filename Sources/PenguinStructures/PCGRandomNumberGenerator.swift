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
///
/// It combines two underlying 32-bit output PCG-XSH-RS random number generators
/// to balance speed with `RandomNumberGenerator`'s requirement of 64-bit
/// output.
public struct PCGRandomNumberGenerator: RandomNumberGenerator {
  var highBits: PCG_XSH_RS_32_Generator

  var lowBits: PCG_XSH_RS_32_Generator

  public init(state: UInt64) {
    self.init(seed: state, seq: 0xda3e_39cb_94b9_5bdb)
  }

  public init(seed: UInt64, seq: UInt64) {
    self.init(seed1: seed, seed2: seed, seq1: seq, seq2: seq)
  }

  public init(seed1: UInt64, seed2: UInt64, seq1: UInt64, seq2: UInt64) {
    let mask: UInt64 = ~0 >> 1;

    var (stream1, stream2) = (seq1, seq2)

    // Make sure the stream values of the underlying generators are distinct to
    // guarantee higher quality output.
    // Don't use the highest order bit for this comparison as it doesn't affect
    // the output values.
    if stream1 & mask == stream2 & mask {
      stream2 = ~stream2
    }

    highBits  = PCG_XSH_RS_32_Generator(state: seed1, stream: stream1)
    lowBits = PCG_XSH_RS_32_Generator(state: seed2, stream: stream2)
  }

  public mutating func next() -> UInt64 {
    UInt64(truncatingIfNeeded: highBits.next()) << 32 | UInt64(truncatingIfNeeded: lowBits.next())
  }
}


/// A 64-bit state, 32-bit output PCG random generator.
internal struct PCG_XSH_RS_32_Generator {
  var state: UInt64

  var stream: UInt64

  init(state: UInt64, stream: UInt64) {
    self.state = 0
    self.stream = (stream << 1) | 1
    step()
    self.state += state
    step()
  }

  mutating func next() -> UInt32 {
    let current = state

    step()

    // Calculate output function (XSH-RS scheme), uses old state for max ILP.
    let base = (current ^ (current >> 22))
    let shift = Int(22 + (current >> 61))
    return UInt32(truncatingIfNeeded: base >> shift)
  }

  private mutating func step() {
    state = state &* 6_364_136_223_846_793_005 &+ stream
  }
}
