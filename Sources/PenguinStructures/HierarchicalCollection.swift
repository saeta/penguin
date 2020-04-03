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

/// Represents a hierarchical collection of data.
///
/// Many efficient data structures naturally contain some hierarchy. Examples include B-trees,
/// adjacency lists in graphs, and elements within a hash table (if using bucket chaining). By
/// explicitly encoding the hierarchical nature of a collection into the the static type, more
/// efficient algorithms are possible to express.
///
/// For additional details, please see:
///  - "Segmented Iterators and Hierarchical Algorithms", Matthew H. Austern, 2000.
///  - "Hierarchical Data Structures and Related Concepts for the C++ Standard Library", Reiter &
///    Rivera, 2013.
///
/// Note: due to limitations in Swift's type system, a single type cannot be both a
/// `HierarchicalCollection` and a `Collection`.
///
/// When conforming to `HierarchicalCollection`, only `forEachWhile` and `count` are required.
public protocol HierarchicalCollection {
    /// The type of element contained within this hierarchical collection.
    associatedtype Element

    /// A cursor represents a location within the collection.
    ///
    /// Beware: mutations to the collection may invalidate the Cursor.
    associatedtype Cursor: Comparable

    // TODO: reconsider algorithmic guarantees here!
    /// The total number of elements within this collection.
    ///
    /// Beware: this might be O(n) in some collections!
    var count: Int { get }

    // /// A subcollection
    // associatedtype SubCollection: HierarchicalCollection where SubCollection.Element == Element

    /// Call `fn` for each element in the collection until `fn` returns false.
    ///
    /// - Parameter start: Start iterating at elements corresponding to this index. If nil, starts at
    ///   the beginning of the collection.
    /// - Returns: a cursor into the data structure corresponding to the first element that returns
    ///   false.
    @discardableResult
    func forEachWhile(startingAt start: Cursor?, _ fn: (Element) throws -> Bool) rethrows -> Cursor?

    /// Call `fn` for each element in the collection.
    ///
    /// Note: this is identical to `Sequence.forEach`, however we cannot re-use the name.
    func forEach(_ fn: (Element) throws -> Void) rethrows

    /// Finds the first index where `predicate` is `true`, and returns a cursor that points to that
    /// location. If `predicate` never returns `true`, `nil` is returned.
    func firstIndex(where predicate: (Element) throws -> Bool) rethrows -> Cursor?

    /// Copies all elements in this hierarchical data structure into a flat array.
    func flatten() -> [Element]

    /// Copies all elements in this hierarchical data structure into the end of a collection.
    func flatten<T: RangeReplaceableCollection>(into collection: inout T) where T.Element == Element

    // Note: due to Swift's lack of HKT's, it's impossible to implement `map`. :-(

    /// Applies `fn` on each element in the collection, and concatenates the results.
    func mapAndFlatten<T>(_ fn: (Element) throws -> T) rethrows -> [T]

    /// Applies `fn` on each element in the collection, and concatenates the non-nil results.
    func compactMapAndFlatten<T>(_ fn: (Element) throws -> T?) rethrows -> [T]

    // TODO: Add cursor-based algorithms!
    // TODO: Add subscript access for a cursor.
    // TODO: Add a formCursor(after: inout Cursor)
    // TODO: Add bidirectional hierarchical collection.
}

/// MutableHierarchicalCollection extends `HierarchicalCollection`s to allow mutation of contents.
///
/// While many algorithms simply query the data structure in order to do their work, some algorithms
/// modify the data structure. This protocol abstracts over a set of common mutation operations of
/// hierarchical data structures.
public protocol MutableHierarchicalCollection: HierarchicalCollection {

    /// Swaps the contents of `lhs` and `rhs`.
    mutating func swapAt(_ lhs: Self.Cursor, _ rhs: Self.Cursor)

    /// Applies `fn` to each element in the hierarchical collection.
    mutating func forEachMut( _ fn: (inout Element) throws -> Void) rethrows

    // TODO: add insert and clear cursor operations.
}

public extension HierarchicalCollection {
    func forEach(_ fn: (Element) throws -> Void) rethrows {
        try forEachWhile(startingAt: nil) { try fn($0); return true }
    }

    func flatten() -> [Element] {
        var arr = [Element]()
        forEach {
            arr.append($0)
        }
        return arr
    }

    func flatten<T: RangeReplaceableCollection>(into collection: inout T) where T.Element == Element {
        forEach {
            collection.append($0)
        }
    }

    func mapAndFlatten<T>(_ fn: (Element) throws -> T) rethrows -> [T] {
        var arr = [T]()
        try forEach {
            arr.append(try fn($0))
        }
        return arr
    }

    func compactMapAndFlatten<T>(_ fn: (Element) throws -> T?) rethrows -> [T] {
        var arr = [T]()
        try forEach {
            if let elem = try fn($0) {
                arr.append(elem)
            }
        }
        return arr
    }

    func firstIndex(where predicate: (Element) throws -> Bool) rethrows -> Cursor? {
        try forEachWhile(startingAt: nil) { element in
            return try !predicate(element)
        }
    }
}
