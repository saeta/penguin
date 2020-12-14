//******************************************************************************
// Copyright 2020 Penguin Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

/// A Sequence whose elements are projections, through a lens of type `BaseElementPart`, of the
/// elements of some `Base` sequence.
///
/// `Projections` is analogous to `LazyMapSequence` but doesn't store a closure or a `KeyPath`, and
/// when `Base` conforms to `MutableCollection`, so does `Projections<Base, L>`, as long as
/// `L.Focus` is-a `WritableKeyPath`.
public struct Projections<Base: Sequence, BaseElementPart: Lens>
  where BaseElementPart.Focus: KeyPath<Base.Element, BaseElementPart.Value>
{
  /// The base sequence whose elements are being projected.
  public var base: Base
}

extension Projections: Sequence {
  /// The type of each element of `self`.
  public typealias Element = BaseElementPart.Value

  /// Single-pass iteration interface and state for instances of `Self`.
  public struct Iterator: IteratorProtocol {
    /// An iterator over the `Base` elements
    var base: Base.Iterator

    /// Advances to and returns the next element, or returns `nil` if no next element exists.
    public mutating func next() -> Element? {
      base.next()?[keyPath: BaseElementPart.focus]
    }
  }

  /// Returns an iterator over the elements of this sequence.
  public func makeIterator() -> Iterator { Iterator(base: base.makeIterator()) }

  /// A value <= `self.count`.
  public var underestimatedCount: Int {
    base.underestimatedCount
  }
}

extension Projections: Collection where Base: Collection {
  /// A position in an instance of `Self`.
  public typealias Index = Base.Index
  
  /// The indices of the elements in an instance of `self`.
  public typealias Indices = Base.Indices

  /// The position of the first element, or `endIndex` if `self.isEmpty`.
  public var startIndex: Index { base.startIndex }
  
  /// The position immediately after the last element.
  public var endIndex: Index { base.endIndex }

  /// The indices of all elements, in order.
  public var indices: Indices { base.indices }

  /// The position following `x`.
  public func index(after x: Index) -> Index {
    base.index(after: x)
  }

  /// Replaces `x` with its successor
  public func formIndex(after x: inout Index) {
    base.formIndex(after: &x)
  }

  /// Accesses the element at `i`.
  public subscript(i: Index) -> Element {
    get { base[i][keyPath: BaseElementPart.focus] }
  }

  /// True iff `self` contains no elements.
  public var isEmpty: Bool { base.isEmpty }

  /// The number of elements in `self`.
  ///
  /// - Complexity: O(1) if `Base` conforms to `RandomAccessCollection`; otherwise, O(N) where N is
  ///   the number of elements.
  public var count: Int { base.count }

  /// Returns an index that is the specified distance from the given index.
  ///
  /// - Complexity: O(1) if `Base` conforms to `RandomAccessCollection`; otherwise, O(`distance`).
  public func index(_ i: Index, offsetBy distance: Int) -> Index {
    base.index(i, offsetBy: distance)
  }

  /// Returns `i` offset forward by `distance`, unless that distance is beyond a given limiting
  /// index, in which case nil is returned.
  ///
  /// - Complexity: O(1) if `Base` conforms to `RandomAccessCollection`; otherwise, O(`distance`).
  public func index(
    _ i: Index, offsetBy distance: Int, limitedBy limit: Index
  ) -> Index? {
    base.index(i, offsetBy: distance, limitedBy: limit)
  }

  /// Returns the number of positions between `start` to `end`.
  ///
  /// - Complexity: O(1) if `Base` conforms to `RandomAccessCollection`; otherwise, worst case
  ///   O(`count`).
  public func distance(from start: Index, to end: Index) -> Int {
    base.distance(from: start, to: end)
  }
}

extension Projections: MutableCollection
  where Base: MutableCollection,
        BaseElementPart.Focus : WritableKeyPath<Base.Element, BaseElementPart.Value>
{
  /// Accesses the element at `i`.
  public subscript(i: Index) -> Element {
    get { base[i][keyPath: BaseElementPart.focus] }
    set { base[i][keyPath: BaseElementPart.focus] = newValue }
    _modify { yield &base[i][keyPath: BaseElementPart.focus] }
  }
}

extension Projections: BidirectionalCollection
  where Base: BidirectionalCollection
{
  /// Returns the position immediately before `i`.
  public func index(before i: Index) -> Index {
    return base.index(before: i)
  }
  
  /// Replaces the value of `i` with its predecessor.
  public func formIndex(before i: inout Index) {
    return base.formIndex(before: &i)
  }
}

extension Projections: RandomAccessCollection
  where Base: RandomAccessCollection
{}

extension Sequence {
  /// Accesses a sequence consisting of the elements of `self` projected through the given lens.
  public subscript<L: Lens>(lens _: Type<L>) -> Projections<Self, L>
    where L.Focus: KeyPath<Element, L.Value>
  {
    .init(base: self)
  }
}

extension MutableCollection {
  /// Accesses a sequence consisting of the elements of `self` projected through the given lens.
  public subscript<L: Lens>(lens _: Type<L>) -> Projections<Self, L> {
    get { .init(base: self) }
    _modify {
      var r = Projections<Self, L>(base: self)
      defer { self = r.base }
      yield &r
    }
  }
}
