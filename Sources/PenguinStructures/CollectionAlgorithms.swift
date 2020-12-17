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

  /// Moves all elements in `self` at `indices` to the end of `self`, while maintaining the relative
  /// order among the other elements.
  ///
  /// Example:
  /// ```
  /// var c = [100, 101, 102, 103, 104, 105]
  /// c.halfStablePartition(delaying: [0, 2])
  /// print(c)  // prints: [101, 103, 104, 105, 102, 100]
  /// ```
  ///
  /// In the above example, the relative ordering of the unselected indices (i.e. the numbers 101,
  /// 103, 104, 105) is maintained, and they are consecutively found at the beginning of the
  /// collection. The unselected elements are all contiguous at the end of the collection. These
  /// selected elements can be in any order.
  ///
  /// As a result of this computation, indices before `sortedIndices.first` are unchanged. The index
  /// of the first delayed element is: `index(startIndex, offsetBy: count - sortedIndices.count)`.
  ///
  /// - Complexity: O(`count`)
  /// - Precondition: `sortedIndices` is sorted and all indices are valid indices in `self`.
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

/// Low-level copying algorithms
extension MutableCollection {
  /// Copies elements from `source` into elements of `self` until either `source` or `self` is
  /// exhausted, returning the number of elements written and the position after the last element
  /// written.
  ///
  /// If no elements are written, returns `(0, startIndex)`.
  ///
  /// - Complexity: O(`min(count,` N`)`), where N is the number of elements in `source`.
  public mutating func writePrefix<I: IteratorProtocol>(from source: inout I)
    -> (writtenCount: Int, afterLastWritten: Index)
    where I.Element == Element
  {
    var writtenCount = 0
    var afterLastWritten = startIndex
    while afterLastWritten != endIndex, let x = source.next() {
      self[afterLastWritten] = x
      self.formIndex(after: &afterLastWritten)
      writtenCount += 1
    }
    return (writtenCount, afterLastWritten)
  }

  /// Copies elements from `source` into elements of `self` until either `source` or `self` is
  /// exhausted, returning the number of elements written, the position after the last element
  /// written into `self`, and the position after the last element read from `source`.
  ///
  /// If no elements are written, returns `(0, startIndex, source.startIndex)`.
  ///
  /// - Complexity: O(`min(self.count, source.count)`).
  public mutating func writePrefix<Source: Collection>(from source: Source)
    -> (writtenCount: Int, afterLastWritten: Index, afterLastRead: Source.Index)
    where Source.Element == Element
  {
    var writtenCount = 0
    var afterLastWritten = startIndex
    var afterLastRead = source.startIndex
    while afterLastWritten != endIndex && afterLastRead != source.endIndex {
      self[afterLastWritten] = source[afterLastRead]
      self.formIndex(after: &afterLastWritten)
      source.formIndex(after: &afterLastRead)
      writtenCount += 1
    }
    return (writtenCount, afterLastWritten, afterLastRead)
  }

  /// Copies the elements from `sourceElements` into `self`, returning `self.count`.
  ///
  /// - Complexity: O(`count`).
  /// - Precondition: `sourceElements` has exactly `count` elements.
  @discardableResult
  public mutating func assign<Source: Sequence>(_ sourceElements: Source) -> Int
    where Source.Element == Element
  {
    var stream = sourceElements.makeIterator()
    let (count, unwritten) = writePrefix(from: &stream)
    precondition(unwritten == endIndex, "source too short")
    precondition(stream.next() == nil, "source too long")
    return count
  }
  
  /// Copies the elements from `sourceElements` into `self`, returning `self.count`
  ///
  /// - Complexity: O(`count`).
  /// - Precondition: `sourceElements.count == self.count`.
  @discardableResult
  public mutating func assign<Source: Collection>(_ sourceElements: Source) -> Int
    where Source.Element == Element
  {
    let (writtenCount, unwritten, unread) = writePrefix(from: sourceElements)
    precondition(unwritten == endIndex, "source too short")
    precondition(unread == sourceElements.endIndex, "source too long")
    return writtenCount
  }

  /// Applies `mutation` to each element in order until it returns `false`; returns the position of
  /// the element for which `false` was returned, or `endIndex` if no such element exists.
  @discardableResult
  public mutating func update(while mutation: (inout Element)->Bool) -> Index {
    var i = startIndex, e = endIndex
    while i != e {
      if !mutation(&self[i]) { break }
      formIndex(after: &i)
    }
    return i
  }

  /// Applies `mutation` to each element in order.
  public mutating func updateAll(_ mutation: (inout Element)->Void) {
    update { mutation(&$0); return true }
  }
}

extension Collection {
  /// Returns the position `n` steps from the beginning of `self`.
  ///
  /// - Precondition: `n >= 0`
  /// - Complexity: O(`n`) worst case.  O(1) if `Self` conforms to `RandomAccessCollection`.
  public func index(atOffset n: Int) -> Index {
    index(startIndex, offsetBy: n)
  }
}

