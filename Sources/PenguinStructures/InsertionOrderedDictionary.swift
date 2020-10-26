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

extension KeyValuePair {
  /// A lens that projects the `key` part.
  public struct ProjectKey: Lens {
    /// The key path value represented by this lens type.
    public static var focus: KeyPath<KeyValuePair, Key> { \.key }
  }

  /// A lens that projects the `value` part.`
  public struct ProjectValue: Lens {
    /// The key path value represented by this lens type.
    public static var focus: WritableKeyPath<KeyValuePair, Value> { \.value }
  }
}

/// A Dictionary with a deterministic sequence traversal order determined by the order in which keys
/// are added.
public struct InsertionOrderedDictionary<Key: Hashable, Value> {
  /// The elements of `self`.
  public private(set) var elements: [KeyValuePair<Key, Value>]
  
  /// A mapping from keys to indices in `elements`.
  public private(set) var indexForKey: [Key: Int]

  /// Returns `true` unless the invariants have been violated.
  internal func invariant() -> Bool {
    if elements.count != indexForKey.count { return false }
    for (e, i) in zip(elements, elements.indices) {
      if indexForKey[e.key] != i { return false }
    }
    return true
  }
  
  /// Traps in debug mode iff the invariants of `self` are violated
  ///
  /// - Complexity: O(`count`)
  internal func assertInvariant() {
    assert(
      invariant(),
      """
      Broken InsertionOrderedDictionary with
        elements(count: \(elements.count)) = \(elements)
        indexForKey(count: \(indexForKey.count)) = \(indexForKey)
      """)
  }
}

extension InsertionOrderedDictionary {
  /// The element type of a dictionary, just like a tuple containing an
  /// individual key-value pair, but nominal.
  public typealias Element = KeyValuePair<Key, Value>

  /// The position of a key-value pair in a dictionary.
  public typealias Index = Keys.Index

  public typealias Keys = Projections<[Element], Element.ProjectKey>
  public var keys: Keys { .init(base: elements) }
  
  public typealias Values = Projections<[Element], Element.ProjectValue>
  public var values: Values {
    get { .init(base: elements) }
    set { values.assign(newValue) }
    _modify {
      var r = self.values
      self.elements = .init() // Prevent needless CoW
      
      var yieldSucceeded = false
      defer {
        if yieldSucceeded { self.elements = r.base }
        else {
          // Preserve the invariant: elements.count == indexForKey.count
          indexForKey.removeAll()
        }
      }
      yield &r
      yieldSucceeded = true
    }
  }

  /// Creates an instance equivalent to `source`.
  public init(_ source: [Key: Value]) {
    self.elements = source.map(Element.init(key:value:))
    var i = 0
    self.indexForKey = source.mapValues { _ in (i, i += 1).0 }
    assertInvariant()
  }

  /// Creates an empty instance.
  public init() {
    elements = []
    indexForKey = [:]
    assertInvariant()
  }
  
  /// Creates an empty dictionary with preallocated space for at least the
  /// specified number of elements.
  public init(minimumCapacity: Int) {
    elements = .init()
    elements.reserveCapacity(minimumCapacity)
    indexForKey = .init(minimumCapacity: minimumCapacity)
    assertInvariant()
  }

  /// Creates a new dictionary from the key-value pairs in the given sequence.
  ///
  /// The keys in the result are ordered in the same order as in
  /// `uniqueKeysWithValues`.
  public init<S>(
    uniqueKeysWithValues keysAndValues: S)
    where S : Sequence, S.Element == Element
  {
    elements = .init(keysAndValues)
    indexForKey = .init(
      uniqueKeysWithValues: elements.indices.lazy.map { [elements] in (elements[$0].key,$0) })
    assertInvariant()
  }

  /// Returns `index(forKey: key) ?? endIndex`, inserting the indexForKey entry with value
  /// `endIndex` iff `endIndex` is returned.
  ///
  /// - Note: breaks the invariant if `endIndex` is returned; you are expected to add an entry to
  /// `elements` in that case.
  private mutating func demandIndex(forKey key: Key) -> Index {
    /// Returns its argument, while forcing it into an `inout` context.
    func inoutIdentity(_ x: inout Index) -> Index { x }

    // Use of `inoutIdentity` ensures the default gets written if key is missing.
    // The local `endIndex` prevents an exclusivity violation in the `default:` autoclosure.
    let endIndex = self.endIndex 
    return inoutIdentity(&indexForKey[key, default: endIndex])
  }

  /// Creates a new dictionary from the key-value pairs in the given sequence,
  /// using a combining closure to determine the value for any duplicate keys.
  ///
  /// The keys in the result are ordered according to their first appearance in
  /// `keysAndValues`.
  public init<S>(
    _ keysAndValues: S,
    uniquingKeysWith combine: (Value, Value) throws -> Value
  ) rethrows where S : Sequence, S.Element == Element {
    self.init()

    for kv in keysAndValues {
      let i = demandIndex(forKey: kv.key)
      if i == endIndex {
        elements.append(kv)
      }
      else {
        try elements[i].value = combine(elements[i].value, kv.value)
      }
    }
    assertInvariant()
  }

  /// Creates a new dictionary whose keys are the groupings returned by the
  /// given closure and whose values are arrays of the elements that returned
  /// each key.
  ///
  /// The keys in the result are ordered according to their first appearance in
  /// `source`.
  public init<S>(
    grouping source: S, by keyForSourceElement: (S.Element) throws -> Key)
    rethrows where Value == [S.Element], S : Sequence
  {
    self.init()
    
    for s in source {
      let k = try keyForSourceElement(s)
      let i = demandIndex(forKey: k)
      if i == endIndex {
        elements.append(.init(key: k, value: [s]))
      }
      else {
        elements[i].value.append(s)
      }
    }
    assertInvariant()
  }

  /// Returns a new dictionary containing the key-value pairs of the dictionary
  /// that satisfy the given predicate.
  @available(swift 4.0)
  public func filter(
    _ isIncluded: (Element) throws -> Bool
  ) rethrows -> InsertionOrderedDictionary {
    try .init(uniqueKeysWithValues: self.lazy.filter { try isIncluded($0) })
  }

  /// Accesses the value associated with the given key, producing `nil` when the value of a key not
  /// in the dictionary is read, and erasing the key if `nil` is written.
  ///
  /// - Complexity: amortized O(1) unless a key is deleted, in which case O(`count`).
  public subscript(key: Key) -> Value? {
    get {
      indexForKey[key].map { elements[$0].value }
    }
    set {
      defer { assertInvariant() }
      if let v = newValue {
        let i = demandIndex(forKey: key)
        if i == endIndex {
          elements.append(.init(key: key, value: v))
        }
        else {
          elements[i].value = v
        }
      }
      else {
        _ = self.removeValue(forKey: key)
      }
    }
    // `modify` is difficult to write because of the synthesized optional, but it also seems like
    // something that isn't commonly used: `Optional` doesn't have mutating methods and given the
    // special semantics of writing `nil` into a dictionary, the result of this subscript isn't
    // likely to make a good `inout` argument in most cases.  The big exception occurs when it's
    // used with optional chaining, e.g. d[k]?.append(x), which turns the optional into a
    // non-optional for any code that follows.  If we *were* going to write `modify`, we'd want to
    // switch to using `ArrayBuffer` for `elements` so that we could destructively `move` the
    // element out for the duration of the yield, to avoid retaining an extra CoW-inducing
    // reference.
  }

  /// Accesses the value for `key`, or `defaultValue` no such key exists in the dictionary, on write
  /// first inserting `key` with value `defaultValue` if it does not exist in the dictionary.
  public subscript(
    key: Key, default defaultValue: @autoclosure () -> Value
  ) -> Value {
    get {
      indexForKey[key].map { elements[$0].value } ?? defaultValue()
    }
    _modify {
      defer { assertInvariant() }
      let i = demandIndex(forKey: key)
      if i == endIndex {
        elements.append(.init(key: key, value: defaultValue()))
      }
      yield &elements[i].value
    }
  }

  /// Returns a new dictionary containing the keys of this dictionary with the
  /// values transformed by the given closure.
  public func mapValues<T>(
    _ transform: (Value) throws -> T
  ) rethrows -> InsertionOrderedDictionary<Key, T> {
    try .init(
      elements: elements.map { try .init(key: $0.key, value: transform($0.value)) },
      indexForKey: indexForKey)
  }

  /// Returns a new dictionary containing only the key-value pairs that have
  /// non-`nil` values as the result of transformation by the given closure.
  public func compactMapValues<T>(
    _ transform: (Value) throws -> T?
  ) rethrows -> InsertionOrderedDictionary<Key, T> {
    var r = InsertionOrderedDictionary<Key, T>()
    for kv in self {
      if let v1 = try transform(kv.value) { r[kv.key] = v1 }
    }
    return r
  }

  /// Updates the value stored in the dictionary for the given key and returns the old value, or
  /// adds a new key-value pair if the key does not exist and returns nil .
  public mutating func updateValue(
    _ newValue: Value, forKey key: Key
  ) -> Value? {
    defer { assertInvariant() }
    guard let i = indexForKey.updateValue(endIndex, forKey: key) else {
      elements.append(.init(key: key, value: newValue))
      return nil
    }
    var r = newValue
    swap(&r, &elements[i].value)
    return r
  }

  /// Merges the key-value pairs in the given sequence into the dictionary,
  /// using a combining closure to determine the value for any duplicate keys.
  public mutating func merge<S>(
    _ other: S,
    uniquingKeysWith combiner: (Value, Value) throws -> Value
  ) rethrows where S : Sequence, S.Element == Element
  {
    defer { assertInvariant() }
    for kv in other {
      var keyIsNew = false
      func combine(_ newValue: Value, into existingValue: inout Value) throws {
        if !keyIsNew {
          try existingValue = combiner(existingValue, newValue)
        }
      }
      try combine(kv.value, into: &self[kv.key, default: (kv.value, keyIsNew.toggle()).0])
    }
  }

  /// Creates a dictionary by merging key-value pairs in a sequence into the
  /// dictionary, using a combining closure to determine the value for
  /// duplicate keys.
  public func merging<S>(
    _ other: S, uniquingKeysWith combine: (Value, Value) throws -> Value
  ) rethrows -> Self where S : Sequence, S.Element == Element {
    var r = self
    try r.merge(other, uniquingKeysWith: combine)
    return r
  }

  /// Creates a dictionary by merging the given dictionary into this
  /// dictionary, using a combining closure to determine the value for
  /// duplicate keys.
  public func merging(
    _ other: Self, uniquingKeysWith combine: (Value, Value) throws -> Value
  ) rethrows -> Self {
    // Merge into the larger of self and other (less potential rehashing)
    var r = self
    var o = other
    if r.count < o.count { swap(&r, &o) }
    try r.merge(o, uniquingKeysWith: combine)
    return r
  }

  /// Removes the element at `i` from `elements`, adjusting the references to following elements in
  /// `indexForKey`.
  ///
  /// - Complexity: O(`count`).
  /// - Precondition: `indexForKey.allSatisfy { $0.1 != i }`.
  private mutating func partiallyRemove(at i: Index) {
    // The precondition is not strictly needed in this function
    elements.remove(at: i)
    // Fix up references to later elements
    
    /// Adjusts `j` to point at the same element as before the deletion
    func adjust(_ j: inout Index) {
      assert(j != i) // This is the precondition check.  
      if j > i { j -= 1 }
    }
    
    for j in indexForKey.indices {
      adjust(&indexForKey.values[j])
    }
  }
  
  /// Removes and returns the key-value pair at `i`.
  ///
  /// - Complexity: O(`count`).
  public mutating func remove(at i: Index) -> Element {
    defer { assertInvariant() }
    let r = elements[i]
    indexForKey.removeValue(forKey: r.key)
    partiallyRemove(at: i)
    return r
  }

  /// Removes the given key and its associated value from the dictionary.
  ///
  /// - Complexity: O(`count`)
  public mutating func removeValue(forKey key: Key) -> Value? {
    defer { assertInvariant() }
    guard let i = indexForKey.removeValue(forKey: key) else { return nil }
    let r = elements[i].value
    partiallyRemove(at: i)
    return r
  }

  /// Removes all key-value pairs from the dictionary.
  public mutating func removeAll(
    keepingCapacity keepCapacity: Bool = false
  ) {
    defer { assertInvariant() }
    indexForKey.removeAll(keepingCapacity: keepCapacity)
    elements.removeAll(keepingCapacity: keepCapacity)
  }

  /// An iterator over the members of a `InsertionOrderedDictionary<Key, Value>`.
  public typealias Iterator = Array<Element>.Iterator
  
  /// The total number of key-value pairs that the dictionary can contain without
  /// allocating new storage.
  public var capacity: Int { Swift.min(elements.capacity, indexForKey.capacity) }

  /// Reserves enough space to store the specified number of key-value pairs.
  public mutating func reserveCapacity(_ minimumCapacity: Int) {
    defer { assertInvariant() }
    indexForKey.reserveCapacity(minimumCapacity)
    elements.reserveCapacity(minimumCapacity)
  }
}

extension InsertionOrderedDictionary : RandomAccessCollection {
  /// The position of the first element in a nonempty dictionary.
  public var startIndex: Index { elements.startIndex }

  /// The dictionary's "past the end" position---that is, the position one
  /// greater than the last valid subscript argument.
  public var endIndex: Index { elements.endIndex }

  /// Returns the index for the given key.
  public func index(forKey key: Key) -> Index? {
    indexForKey[key]
  }

  /// Accesses the key-value pair at the specified position.
  public subscript(position: Index) -> Element {
    elements[position]
  } 

  /// The number of key-value pairs in the dictionary.
  public var count: Int { indexForKey.count }

  /// A Boolean value that indicates whether the dictionary is empty.
  public var isEmpty: Bool { indexForKey.isEmpty }
}

extension InsertionOrderedDictionary : Sequence {
  /// Returns an iterator over the dictionary's key-value pairs.
  public func makeIterator() -> Iterator {
    return elements.makeIterator()
  }
}

extension InsertionOrderedDictionary : CustomReflectable {
  /// A mirror that reflects the dictionary.
  public var customMirror: Mirror { indexForKey.customMirror }
}

extension InsertionOrderedDictionary
  : CustomStringConvertible, CustomDebugStringConvertible
{
  /// A string that represents the contents of the dictionary.
  public var description: String { indexForKey.description }

  /// A string that represents the contents of the dictionary, suitable for
  /// debugging.
  public var debugDescription: String { indexForKey.debugDescription }
}

extension InsertionOrderedDictionary : Hashable where Value : Hashable {}
extension InsertionOrderedDictionary : Equatable where Value : Equatable {}

extension InsertionOrderedDictionary
  : Decodable where Key : Decodable, Value : Decodable
{
  /// Creates a new dictionary by decoding from the given decoder.
  public init(from decoder: Decoder) throws {
    try elements = .init(from: decoder)
    indexForKey = [:]
    indexForKey.reserveCapacity(elements.count)
    for (i, kv) in zip(elements.indices, elements) {
      indexForKey[kv.key] = i
    }
    assertInvariant()
  }
}

extension InsertionOrderedDictionary : Encodable
  where Key : Encodable, Value : Encodable
{
  /// Encodes the contents of this dictionary into the given encoder.
  public func encode(to encoder: Encoder) throws {
    try elements.encode(to: encoder)
  }
}

extension Dictionary {
  /// Creates an instance equivalent to `source`.
  public init(_ source: InsertionOrderedDictionary<Key, Value>) {
    self = source.indexForKey.mapValues { source.elements[$0].value }
  }
}
