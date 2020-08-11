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

/// Classes having initializers that actually create derived classes.
///
/// To use, make your class conform and forward to `init(aliasing:)` or
/// `init(unsafelyAliasing:)` from a `convenience init`:
///
/// ```
/// public class Base : FactoryInitializable {
///   /// Constructs an instance whose dynamic type depends on the value of `one`
///   public convenience init(_ one: Bool) {
///     self.init(aliasing: one ? Derived1() : Derived2())
///   }
/// }
/// ```
public protocol FactoryInitializable {
  // This associatedtype is a trick that captures `Self` at the point where
  // `FactoryInitializable` enters a class hierarchy; in other contexts, `Self`
  // refers to the most-derived type.

  /// The type of the least-derived class declared to be FactoryInitializable.
  ///
  /// - Warning: Allow the default value to take effect, and do not define or
  ///   use this type explicitly.
  associatedtype FactoryBase: AnyObject, FactoryInitializable = Self
}

extension FactoryInitializable where Self: AnyObject {
  /// Optimally “creates” an instance that is just another reference to `me`.
  ///
  /// - Requires: `me is Self`.
  /// 
  /// Taking `FactoryBase` as a parameter prevents, at compile-time, the
  /// category of bugs where `me` is not derived from the least-derived ancestor
  /// of `Self` conforming to `FactoryInitializable`.
  ///
  /// However, there are still ways `me` might not be derived from `Self`.  If
  /// you have factory initializers at more than one level of your class
  /// hierarchy and you can't control exactly what is passed here, use
  /// `init(aliasing:)` instead.
  public init(unsafelyAliasing me: FactoryBase) {
    self = unsafeDowncast(me, to: Self.self)
  }

  /// Safely “creates” an instance that is just another reference to `me`.
  ///
  /// - Requires: `me is Self`.
  public init(aliasing me: FactoryBase) {
    self = me as! Self
  }

  /// “Creates” an instance that is just another reference to `me`, regardless of the dynamic type
  /// of “me”.
  ///
  /// - Warning: do not use this initializer unless you're really, absolutely, sure you know what
  ///   you're doing; it breaks type safety.
  public init(unsafelyBitCasting me: FactoryBase) {
    self = unsafeBitCast(me as AnyObject, to: Self.self)
  }
}
