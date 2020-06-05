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

extension RandomAccessCollection where Index == Int {
  public func randomSelectionWithoutReplacement<Randomness: RandomNumberGenerator>(
    k: Int,
    using randomness: inout Randomness
  ) -> [Element] {
    let icount = count
    guard icount > k else { return Array(self) }
    guard k > 0 else { return [] }
    var selected = [Element]()
    selected.reserveCapacity(k)
    if k * k > icount || icount < 100 {
      return randomSelectionWithoutReplacementBase(k: k, using: &randomness)
    }
    var tmp: [Int] = (0..<k).map { _ in Int(randomness.next(upperBound: UInt(icount))) }
    while true {
      var ok = true
      tmp.sort()
      var prev = -1
      for i in 0..<k {
        let v = tmp[i]
        if prev == v {
          tmp[i] = Int(randomness.next(upperBound: UInt(icount)))
          ok = false
        }
        prev = v
      }
      if ok { return tmp.map { self[Index($0)] } }
    }
  }
}

extension Collection {
  public func randomSelectionWithoutReplacement<Randomness: RandomNumberGenerator>(
    k: Int,
    using randomness: inout Randomness
  ) -> [Element] {
    guard count > k else { return Array(self) }
    guard k > 0 else { return [] }
    return randomSelectionWithoutReplacementBase(k: k, using: &randomness)
  }

  internal func randomSelectionWithoutReplacementBase<Randomness: RandomNumberGenerator>(
    k: Int,
    using randomness: inout Randomness
  ) -> [Element] {
    var selected = [Element]()
    selected.reserveCapacity(k)
    for (i, elem) in self.enumerated() {
      let remainingToPick = k - selected.count
      let remainingInSelf = count - i
      if randomness.next(upperBound: UInt(remainingInSelf)) < remainingToPick {
        selected.append(elem)
        if selected.count == k { return selected }
      }
    }
    fatalError("Should not have reached here: \(self), \(selected)")
  }

  public func randomSelectionWithoutReplacement(k: Int) -> [Element] {
    var g = SystemRandomNumberGenerator()
    return randomSelectionWithoutReplacement(k: k, using: &g)
  }
}
