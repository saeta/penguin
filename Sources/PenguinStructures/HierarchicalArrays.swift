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

/// LeafArray wraps an `Array` to form a `HierarchicalCollection`.
///
/// LeafArray is a "bottom" type within a HierarchicalCollection.
public struct LeafArray<Element>: HierarchicalCollection { // , MutableHierarchicalCollection { // TODO!
    var underlying: [Element]

    public typealias Cursor = Int

    /// Wrap `array` to form a `HierarchicalCollection`.
    public init(_ array: [Element]) {
        self.underlying = array
    }

    /// Wrap `elements` to form a `HierarchicalCollection`.
    public init(_ elements: Element...) {
        self.underlying = elements
    }

    @discardableResult
    public func forEachWhile(startingAt cursor: Int? = nil, _ fn: (Element) throws -> Bool) rethrows -> Cursor? {
        if let start = cursor {
            for (i, elem) in underlying[start...].enumerated() {
                if try !fn(elem) { return i }
            }
            return nil
        } else {
            for (i, elem) in underlying.enumerated() {
                if try !fn(elem) { return i }
            }
            return nil
        }
    }

    public func flatten() -> [Element] { underlying }
    public func flatten<T: RangeReplaceableCollection>(into collection: inout T) where T.Element == Element {
        collection.append(contentsOf: underlying)
    }

    public func mapAndFlatten<T>(_ fn: (Element) throws -> T) rethrows -> [T] {
        try underlying.map(fn)
    }

    public func compactMapAndFlatten<T>(_ fn: (Element) throws -> T?) rethrows -> [T] {
        try underlying.compactMap(fn)
    }

    public var count: Int { underlying.count }
}

public struct HierarchicalArray<T: HierarchicalCollection>: HierarchicalCollection {
    public typealias Element = T.Element

    public struct Cursor: Comparable {
        let index: Int
        let underlying: T.Cursor

        public static func < (lhs: Self, rhs: Self) -> Bool {
            if lhs.index < rhs.index { return true }
            if lhs.index == rhs.index { return lhs.underlying < rhs.underlying }
            return false
        }
    }

    var underlying: [T]

    public init(_ array: [T]) {
        self.underlying = array
    }

    @discardableResult
    public func forEachWhile(startingAt cursor: Cursor? = nil, _ fn: (Element) throws -> Bool) rethrows -> Cursor? {
        if let start = cursor {
            for (i, elem) in underlying[start.index...].enumerated() {
                let startUnderlying = start.index == i ? start.underlying : nil
                if let cursor = try elem.forEachWhile(startingAt: startUnderlying, fn) {
                    return Cursor(index: i, underlying: cursor)
                }
            }
            return nil
        } else {
            for (i, elem) in underlying.enumerated() {
                if let cursor = try elem.forEachWhile(startingAt: nil, fn) {
                    return Cursor(index: i, underlying: cursor)
                }
            }
            return nil
        }
    }

    public func flatten<T: RangeReplaceableCollection>(into collection: inout T) where T.Element == Element {
        for elem in underlying {
            elem.flatten(into: &collection)
        }
    }

    public func compactMapAndFlatten<T>(_ fn: (Element) throws -> T?) rethrows -> [T] {
        var output = [T]()
        for elem in underlying {
            let tmp = try elem.compactMapAndFlatten(fn)
            output.append(contentsOf: tmp)
        }
        return output
    }

    public var count: Int {
        var sum = 0
        for c in underlying {
            sum += c.count
        }
        return sum
    }
}
