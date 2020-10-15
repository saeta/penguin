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

/// `KeyPath`s with a statically known `Value` endpoint.
// This protocol is only needed because we can't represent `: KeyPath<_,V>` as a constraint in the
// type system.
public protocol KeyPathProtocol: AnyKeyPath {
  associatedtype Value
}

extension KeyPath: KeyPathProtocol {}

/// Types that represent, in the type system, a specific key path.
public protocol Lens {
  /// The specific subclass of `KeyPath<Focus.Root,Value>` whose value `Self` represents.
  ///
  /// For example, `Focus` might be `WritableKeyPath<(Int, String), Int>` in a `Lens` that supported
  /// writing.
  associatedtype Focus: KeyPathProtocol
  
  /// The `Value` type of the represented key path.
  ///
  /// Models of `Lens` should not define this type, but instead allow the default to take effect.
  associatedtype Value = Focus.Value

  /// The key path value represented by `Self`.
  static var focus: Focus { get }
}

