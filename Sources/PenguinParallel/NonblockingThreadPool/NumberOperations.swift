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

/// Returns the positive integers that are coprime with `n`.
///
/// Two numbers are co-prime if their GCD is 1.
internal func positiveCoprimes(_ n: Int) -> [Int] {
  var coprimes = [Int]()
  for i in 1...n {
    var a = i
    var b = n
    // If GCD(a, b) == 1, then a and b are coprimes.
    while b != 0 {
      let tmp = a
      a = b
      b = tmp % b
    }
    if a == 1 { coprimes.append(i) }
  }
  return coprimes
}
