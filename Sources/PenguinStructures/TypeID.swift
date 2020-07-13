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

/// A nominal wrapper around `Any.Type` that conforms to useful protocols.
///
/// Note that the `Comparable` conformance will not have a stable ordering across program
/// invocations.  If reproducible ordering is important, you can sacrifice performance for stability
/// by using `String(reflecting: self.value)` as a sort key.
public struct TypeID {
  /// Creates an instance identifying `t`
  public init(_ t: Any.Type) { self.value = t }

  /// The type identified by `self`.
  public let value: Any.Type
}

extension TypeID: Equatable {
  /// Returns true iff `a` and `b` represent the same type.
  public static func == (a: Self, b: Self) -> Bool { a.value == b.value }
}

extension TypeID: Comparable {
  /// Returns true iff `a` is ordered before `b` in a total ordering over all
  /// types.
  public static func < (a: Self, b: Self) -> Bool {
    ObjectIdentifier(a.value) < ObjectIdentifier(b.value)
  }
}

extension TypeID: Hashable {
  /// Accumulates the value of `self` into `h`.
  public func hash(into h: inout Hasher) {
    ObjectIdentifier(self.value).hash(into: &h)
  }
}

extension TypeID: CustomStringConvertible {
  /// A description of the value `self`.
  public var description: String { String(describing: self.value) }
}

extension TypeID: CustomDebugStringConvertible {
  /// An elaborated description of the value `self`.
  public var debugDescription: String {
    "TypeID(\(self.value).self)"
  }
}
