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

public typealias KeyValueTuple<Key, Value> = (key: Key, value: Value)

/// Interoperability with legacy sequences of non-nominal Swift tuples.
extension Sequence {
  /// Returns a sequence of `KeyValuePair` whose elements are semantically
  /// equivalent to the corresponding (non-nominal tuple) elements of `self`.
  public func keyValuePairs<K, V>() -> LazyMapSequence<Self, KeyValuePair<K, V>>
    where Element == (key: K, value: V)
  {
    self.lazy.map { .init(key: $0.key, value: $0.value) }
  }
  
  /// Returns a sequence of `KeyValuePair` whose elements are semantically
  /// equivalent to the corresponding (non-nominal tuple) elements of `self`.
  public func keyValuePairs<K, V>() -> LazyMapSequence<Self, KeyValuePair<K, V>>
    where Element == (K, V)
  {
    self.lazy.map { .init(key: $0, value: $1) }
  }
  
  /// Returns a sequence of non-nominal tuples whose elements are semantically
  /// equivalent to the corresponding `KeyValuePair` elements of `self`.
  public func keyValueTuples<K, V>() -> LazyMapSequence<Self, (K, V)>
    where Element == KeyValuePair<K, V>
  {
    self.lazy.map { ($0.key, $0.value) }
  }
}

/// A Dictionary with a nominal `Element` type, that can conform to things.
public struct NominalElementDictionary<Key: Hashable, Value> {
  /// The underlying Swift dictionary.
  public typealias Base = [Key : Value]
  
  /// A view of a dictionary's keys.
  public typealias Keys = Base.Keys
  
  /// A view of a dictionary's values.
  public typealias Values = Base.Values
  
  /// The position of a key-value pair in a dictionary.
  public typealias Index = Base.Index

  /// The underlying Swift Dictionary
  public var base: Base

  /// Creates an instance equivalent to `base`.
  public init(_ base: Base) {
    self.base = base
  }
  
  /// The element type of a dictionary, just like a tuple containing an
  /// individual key-value pair, but nominal.
  public typealias Element = KeyValuePair<Key, Value>

  /// Creates an empty dictionary.
  public init() { base = .init() }

  /// Creates an empty dictionary with preallocated space for at least the
  /// specified number of elements.
  public init(minimumCapacity: Int) {
    base = .init(minimumCapacity: minimumCapacity)
  }

  /// Creates a new dictionary from the key-value pairs in the given sequence.
  public init<S>(
    uniqueKeysWithValues keysAndValues: S)
    where S : Sequence, S.Element == Element
  {
    base = .init(uniqueKeysWithValues: keysAndValues.keyValueTuples())
  }

  /// Creates a new dictionary from the key-value pairs in the given sequence,
  /// using a combining closure to determine the value for any duplicate keys.
  public init<S>(
    _ keysAndValues: S,
    uniquingKeysWith combine: (Value, Value) throws -> Value
  ) rethrows where S : Sequence, S.Element == Element {
    try base = .init(keysAndValues.keyValueTuples(), uniquingKeysWith: combine)
  }

  /// Creates a new dictionary whose keys are the groupings returned by the
  /// given closure and whose values are arrays of the elements that returned
  /// each key.
  public init<S>(
    grouping values: S, by keyForValue: (S.Element) throws -> Key)
    rethrows where Value == [S.Element], S : Sequence
  {
    try base = .init(grouping: values, by: keyForValue)
  }
  
  /// Returns a new dictionary containing the key-value pairs of the dictionary
  /// that satisfy the given predicate.
  @available(swift 4.0)
  public func filter(
    _ isIncluded: (Element) throws -> Bool
  ) rethrows -> NominalElementDictionary {
    try .init(base.filter { try isIncluded(.init(tuple: $0)) })
  }

  /// Accesses the value associated with the given key for reading and writing.
  public subscript(key: Key) -> Value? {
    get {
      base[key]
    }
    _modify {
      yield &base[key]
    }
  }

  /// Accesses the value with the given key. If the dictionary doesn't contain
  /// the given key, accesses the provided default value as if the key and
  /// default value existed in the dictionary.
  public subscript(
    key: Key, default defaultValue: @autoclosure () -> Value
  ) -> Value {
    get {
      base[key, default: defaultValue()]
    }
    _modify {
      yield &base[key, default: defaultValue()]
    }
  }

  /// Returns a new dictionary containing the keys of this dictionary with the
  /// values transformed by the given closure.
  public func mapValues<T>(
    _ transform: (Value) throws -> T
  ) rethrows -> NominalElementDictionary<Key, T> {
    try .init(base.mapValues(transform))
  }

  /// Returns a new dictionary containing only the key-value pairs that have
  /// non-`nil` values as the result of transformation by the given closure.
  public func compactMapValues<T>(
    _ transform: (Value) throws -> T?
  ) rethrows -> [Key : T] { try base.compactMapValues(transform) }

  /// Updates the value stored in the dictionary for the given key and returns the old value, or
  /// adds a new key-value pair if the key does not exist and returns nil .
  public mutating func updateValue(
    _ value: Value, forKey key: Key
  ) -> Value? {
    base.updateValue(value, forKey: key)
  }

  /// Merges the key-value pairs in the given sequence into the dictionary,
  /// using a combining closure to determine the value for any duplicate keys.
  public mutating func merge<S>(
    _ other: S,
    uniquingKeysWith combine: (Value, Value) throws -> Value
  ) rethrows where S : Sequence, S.Element == Element
  {
    try base.merge(other.keyValueTuples(), uniquingKeysWith: combine)
  }

  /// Merges the given dictionary into this dictionary, using a combining
  /// closure to determine the value for any duplicate keys.
  public mutating func merge(
    _ other: Self,
    uniquingKeysWith combine: (Value, Value) throws -> Value
  ) rethrows {
    try base.merge(other.base, uniquingKeysWith: combine)
  }

  /// Creates a dictionary by merging key-value pairs in a sequence into the
  /// dictionary, using a combining closure to determine the value for
  /// duplicate keys.
  public func merging<S>(
    _ other: S, uniquingKeysWith combine: (Value, Value) throws -> Value
  ) rethrows -> Self where S : Sequence, S.Element == Element {
    try .init(base.merging(other.keyValueTuples(), uniquingKeysWith: combine))
  }

  /// Creates a dictionary by merging the given dictionary into this
  /// dictionary, using a combining closure to determine the value for
  /// duplicate keys.
  public func merging(
    _ other: Self, uniquingKeysWith combine: (Value, Value) throws -> Value
  ) rethrows -> Self {
    try .init(base.merging(other.base, uniquingKeysWith: combine))
  }

  /// Removes and returns the key-value pair at the specified index.
  public mutating func remove(at index: Index) -> Element {
    .init(tuple: base.remove(at: index))
  }

  /// Removes the given key and its associated value from the dictionary.
  public mutating func removeValue(forKey key: Key) -> Value? {
    base.removeValue(forKey: key)
  }

  /// Removes all key-value pairs from the dictionary.
  public mutating func removeAll(
    keepingCapacity keepCapacity: Bool = false
  ) {
    base.removeAll(keepingCapacity: keepCapacity)
  }

  /// A collection containing just the keys of the dictionary.
  @available(swift 4.0)
  public var keys: Keys { base.keys }

  /// A collection containing just the values of the dictionary.
  @available(swift 4.0)
  public var values: Values {
    get {
      base.values
    }
    _modify {
      yield &base.values
    }
  }


  /// An iterator over the members of a `NominalElementDictionary<Key, Value>`.
  public struct Iterator : IteratorProtocol {
    internal typealias Base = Swift.Dictionary<Key,Value>.Iterator
    
    init(base: Base) { self.base = base }
    
    var base: Base
    
    public mutating func next() -> Element? {
      return base.next().map(Element.init(tuple:))
    }
  }

  /// Removes and returns the first key-value pair of the dictionary if the
  /// dictionary isn't empty.
  public mutating func popFirst() -> Element? {
    base.popFirst().map(Element.init(tuple:))
  }

  /// The total number of key-value pairs that the dictionary can contain without
  /// allocating new storage.
  public var capacity: Int { base.capacity }

  /// Reserves enough space to store the specified number of key-value pairs.
  public mutating func reserveCapacity(_ minimumCapacity: Int) {
    base.reserveCapacity(minimumCapacity)
  }
}

extension NominalElementDictionary : Collection {
  /// The position of the first element in a nonempty dictionary.
  public var startIndex: Index { base.startIndex }

  /// The dictionary's "past the end" position---that is, the position one
  /// greater than the last valid subscript argument.
  public var endIndex: Index { base.endIndex }

  /// Returns the position immediately after the given index.
  public func index(after i: Index) -> Index {
    base.index(after: i)
  }

  /// Replaces the given index with its successor.
  public func formIndex(after i: inout Index) {
    base.formIndex(after: &i)
  }

  /// Returns the index for the given key.
  public func index(forKey key: Key) -> Index? {
    base.index(forKey: key)
  }

  /// Accesses the key-value pair at the specified position.
  public subscript(position: Index) -> Element {
    .init(tuple: base[position])
  } 

  /// The number of key-value pairs in the dictionary.
  public var count: Int { base.count }

  /// A Boolean value that indicates whether the dictionary is empty.
  public var isEmpty: Bool { base.isEmpty }
}

extension NominalElementDictionary : Sequence {
  /// Returns an iterator over the dictionary's key-value pairs.
  public func makeIterator() -> Iterator {
    return .init(base: base.makeIterator())
  }
}

extension NominalElementDictionary : CustomReflectable {
  /// A mirror that reflects the dictionary.
  public var customMirror: Mirror { base.customMirror }
}

extension NominalElementDictionary
  : CustomStringConvertible, CustomDebugStringConvertible
{
  /// A string that represents the contents of the dictionary.
  public var description: String { base.description }

  /// A string that represents the contents of the dictionary, suitable for
  /// debugging.
  public var debugDescription: String { base.debugDescription }
}

extension NominalElementDictionary : Hashable where Value : Hashable {}
extension NominalElementDictionary : Equatable where Value : Equatable {}

extension NominalElementDictionary
  : Decodable where Key : Decodable, Value : Decodable
{
  /// Creates a new dictionary by decoding from the given decoder.
  public init(from decoder: Decoder) throws {
    try base = .init(from: decoder)
  }
}

extension NominalElementDictionary : Encodable
  where Key : Encodable, Value : Encodable
{
  /// Encodes the contents of this dictionary into the given encoder.
  public func encode(to encoder: Encoder) throws {
    try base.encode(to: encoder)
  }
}
    
