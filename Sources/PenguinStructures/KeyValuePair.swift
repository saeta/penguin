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

/// A nominal version of the tuple type that is the `Element` of
/// `Swift.Dictionary`.
public struct KeyValuePair<Key, Value> {
  /// Creates an instance with the given key and value.
  public init(key: Key, value: Value) {
    (self.key, self.value) = (key, value)
  }
  public var key: Key
  public var value: Value
}

extension KeyValuePair: Equatable where Key: Equatable, Value: Equatable {}
extension KeyValuePair: Comparable where Key: Comparable, Value: Comparable {
  public static func < (a: Self, b: Self) -> Bool {
    a.key < b.key || a.key == b.key && a.value < b.value
  }
}
extension KeyValuePair: Hashable where Key: Hashable, Value: Hashable {}

/// Useful extensions for Dictionary interop.
extension KeyValuePair {
  internal init(tuple x: (key: Key, value: Value)) {
    self.init(key: x.key, value: x.value)
  }
  internal var tuple: (key: Key, value: Value) { (key, value) }
}
