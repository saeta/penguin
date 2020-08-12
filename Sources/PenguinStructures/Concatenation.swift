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


/// A collection that is all the elements of one collection followed by all the elements of a second
/// collection.
public struct Concatenation<First: Collection, Second: Collection>: Collection where
First.Element == Second.Element {
  /// The elements in `self`.
  public typealias Element = First.Element
  /// The collection whose elements appear first.
  @usableFromInline
  var first: First
  /// The collection whose elements appear second.
  @usableFromInline
  var second: Second

  /// Concatenates `first` with `second`.
  public init(_ first: First, _ second: Second) {
    self.first = first
    self.second = second
  }

  /// A position in a `Concatenation`.
  public struct Index: Comparable {
    /// A position into one of the two underlying collections.
    @usableFromInline
    var position: Either<First.Index, Second.Index>

    /// Creates a new index into the first underlying collection.
    @usableFromInline
    internal init(first i: First.Index) {
      self.position = .a(i)
    }

    /// Creates a new index into the first underlying collection.
    @usableFromInline
    internal init(second i: Second.Index) {
      self.position = .b(i)
    }

    /// Returns `true` iff `lhs` precedes `rhs`.
    public static func < (lhs: Self, rhs: Self) -> Bool {
      return lhs.position < rhs.position
    }
  }

  /// The position of the first element, or `endIndex` if `self.isEmpty`
  @inlinable
  public var startIndex: Index {
    if !first.isEmpty { return Index(first: first.startIndex) }
    return Index(second: second.startIndex)
  }

  /// The collection’s “past the last” position—that is, the position one greater than the last
  /// valid subscript argument.
  @inlinable
  public var endIndex: Index { Index(second: second.endIndex) }

  /// Returns the next index after `i`.
  public func index(after i: Index) -> Index {
    switch i.position {
    case .a(let index):
      let newIndex = first.index(after: index)
      guard newIndex != first.endIndex else { return Index(second: second.startIndex) }
      return Index(first: newIndex)
    case .b(let index):
      return Index(second: second.index(after: index))
    }
  }

  /// Accesses the element at `i`.
  @inlinable
  public subscript(i: Index) -> Element {
    switch i.position {
    case .a(let index): return first[index]
    case .b(let index): return second[index]
    }
  }

  /// The number of elements in `self`.
  @inlinable
  public var count: Int { first.count + second.count }

  /// True iff `self` contains no elements.
  @inlinable
  public var isEmpty: Bool { first.isEmpty && second.isEmpty }

  /// Returns the distance between two indices.
  @inlinable
  public func distance(from start: Index, to end: Index) -> Int {
    switch (start.position, end.position) {
    case (.a(let start), .a(let end)):
      return first.distance(from: start, to: end)
    case (.a(let start), .b(let end)):
      return first.distance(from: start, to: first.endIndex) + second.distance(from: second.startIndex, to: end)
    case (.b(let start), .a(let end)):
      return second.distance(from: start, to: second.startIndex) + first.distance(from: first.endIndex, to: end)
    case (.b(let start), .b(let end)):
      return second.distance(from: start, to: end)
    }
  }
}

extension Concatenation: BidirectionalCollection
where First: BidirectionalCollection, Second: BidirectionalCollection {
  /// Returns the next position before `i`.
  @inlinable
  public func index(before i: Index) -> Index {
    switch i.position {
    case .a(let index): return Index(first: first.index(before: index))
    case .b(let index):
      if index == second.startIndex {
        return Index(first: first.index(before: first.endIndex))
      }
      return Index(second: second.index(before: index))
    }
  }
}

extension Concatenation: RandomAccessCollection
  where First: RandomAccessCollection, Second: RandomAccessCollection
{
  @inlinable
  public func index(_ i: Index, offsetBy n: Int) -> Index {
    if n == 0 { return i }
    if n < 0 { return offsetBackward(i, by: n) }
    return offsetForward(i, by: n)
  }

  @usableFromInline
  func offsetForward(_ i: Index, by n: Int) -> Index {
    switch i.position {
    case .a(let index):
      let d = first.distance(from: index, to: first.endIndex)
      if n < d {
        return Index(first: first.index(index, offsetBy: n))
      } else {
        return Index(second: second.index(second.startIndex, offsetBy: n - d))
      }
    case .b(let index):
      return Index(second: second.index(index, offsetBy: n))
    }
  }

  @usableFromInline
  func offsetBackward(_ i: Index, by n: Int) -> Index {
    switch i.position {
    case .a(let index):
      return Index(first: first.index(index, offsetBy: n))
    case .b(let index):
      let d = second.distance(from: second.startIndex, to: index)
      if -n <= d {
        return Index(second: second.index(index, offsetBy: n))
      } else {
        return Index(first: first.index(first.endIndex, offsetBy: n + d))
      }
    }
  }
}

// TODO: Add RandomAccessCollection conformance.
// TODO: Add MutableCollection conformance.

extension Collection {
  /// Returns a new collection where all the elements of `self` appear before all the elements of
  /// `other`.
  @inlinable
  public func joined<Other: Collection>(to other: Other) -> Concatenation<Self, Other>
    where Other.Element == Element
  {
    return Concatenation(self, other)
  }
}
