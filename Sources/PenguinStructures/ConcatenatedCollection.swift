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
public struct ConcatenatedCollection<First: Collection, Second: Collection>: Collection where
First.Element == Second.Element {
  /// The elements in `self`.
  public typealias Element = First.Element
  /// The collection whose elements appear first.
  private var first: First
  /// The collection whose elements appear second.
  private var second: Second

  /// Concatenates `first` with `second`.
  public init(_ first: First, _ second: Second) {
    self.first = first
    self.second = second
  }

  /// A handle into elements in `self`.
  public enum Index: Equatable, Comparable {
    case first(First.Index)
    case second(Second.Index)

    /// Returns true if `lhs` should be ordered before `rhs`.
    public static func < (lhs: Self, rhs: Self) -> Bool {
      switch (lhs, rhs) {
      case (.first(let lhs), .first(let rhs)): return lhs < rhs
      case (.first, _): return true
      case (.second(let lhs), .second(let rhs)): return lhs < rhs
      default: return false
      }
    }
  }

  /// The first valid index into `self`.
  public var startIndex: Index { .first(first.startIndex) }
  /// One beyond the last valid index into `self`.
  public var endIndex: Index { .second(second.endIndex) }
  /// Returns the next valid index after `index`.
  public func index(after index: Index) -> Index {
    switch index {
    case .first(let index):
      let newIndex = first.index(after: index)
      guard newIndex != first.endIndex else { return .second(second.startIndex) }
      return .first(newIndex)
    case .second(let index):
      return .second(second.index(after: index))
    }
  }
  /// Accesses element at `index`.
  public subscript(index: Index) -> Element {
    switch index {
    case .first(let index): return first[index]
    case .second(let index): return second[index]
    }
  }
  /// The number of elements in `self`.
  public var count: Int { first.count + second.count }
  /// True if `self` contains no elements.
  public var isEmpty: Bool { first.isEmpty && second.isEmpty }
}

extension ConcatenatedCollection.Index: Hashable where First.Index: Hashable, Second.Index: Hashable {
  /// Hashes `self` into `hasher`.
  public func hash(into hasher: inout Hasher) {
    switch self {
    case .first(let i): i.hash(into: &hasher)
    case .second(let i): i.hash(into: &hasher)
    }
  }
}

extension ConcatenatedCollection: BidirectionalCollection
where First: BidirectionalCollection, Second: BidirectionalCollection {
  /// Returns the next valid index before `index`.
  public func index(before index: Index) -> Index {
    switch index {
    case .first(let index): return .first(first.index(before: index))
    case .second(let index):
      if index == second.startIndex {
        return .first(first.index(before: first.endIndex))
      }
      return .second(second.index(before: index))
    }
  }
}

// TODO: Add RandomAccessCollection conformance.
// TODO: Add MutableCollection conformance.

extension Collection {
  /// Returns a new collection where all the elements of `self` appear before all the elements of
  /// `other`.
  public func concatenated<Other: Collection>(with other: Other)
  -> ConcatenatedCollection<Self, Other>
  where Other.Element == Element {
    return ConcatenatedCollection(self, other)
  }
}
