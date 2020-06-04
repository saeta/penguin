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

extension MutableCollection {
  /// Moves all elements in `self` at `indices` to the end of `self` while maintaining the relative
  /// order among the other elements.
  ///
  /// - Complexity: O(`count`)
  public mutating func halfStablePartition<C: Collection>(delaying sortedIndices: C) where C.Element == Index {
    var skipIndices = sortedIndices.makeIterator()
    guard var i = skipIndices.next() else { return }  // No work to do!
    var j = index(after: i)
    while let nextToSkip = skipIndices.next() {
      while j < nextToSkip {
        swapAt(i, j)
        i = index(after: i)
        j = index(after: j)
      }
      j = index(after: j)  // Move j, keep i the same.
    }
    // Swap all elements after our last index to skip.
    while j < endIndex {
      swapAt(i, j)
      i = index(after: i)
      j = index(after: j)
    }
  }
}
