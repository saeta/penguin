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

/// UniqueIndex represents an index on a PColumn containing `Element`'s.
protocol UniqueIndex {
  // TODO: should this really be a protocol?

  /// The element contained by the index.
  associatedtype Element

  /// Retrieves the row index corresponding to a given element.
  ///
  /// Note: because elements within a PColumn can be missing (nil), the
  /// subscript takes an Optional Element.
  subscript(unique elem: Element?) -> Int? { get }

  /// The number of elements contained within the index.
  var count: Int { get }

  // TODO: support range operations?
}

// TODO: Convert to B-Tree to support range operations too!
struct HashIndex<Element: ElementRequirements>: UniqueIndex, Equatable {
  var count: Int {
    dictionary.count + (nilRow == nil ? 0 : 1)
  }

  subscript(unique elem: Element?) -> Int? {
    guard let elem = elem else { return nilRow }
    return dictionary[elem]
  }

  var nilRow: Int?
  var dictionary = [Element: Int]()
}
