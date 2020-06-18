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

/// A type whose full identity is known to the type system.
///
/// Generic function/method APIs often accept a `T.Type` parameter, where `T` is
/// a generic parameter, to drive deduction, for example:
///
///     extension UnsafeRawPointer {
///       func assumingMemoryBound<T>(to _: T.Type) -> UnsafePointer<T> { ... }
///     }
///
/// which is then used as follows:
///
///     someRawPointer.assumingMemoryBound(to: Foo.self)
///
/// The problem with such interfaces is that you can easily end up driving type
/// deduction with a value that doesn't match the deduced type:
///
///     let foo: Any.Type = Foo.self
///     assert(foo == Foo.self)
///     someRawPointer.assumingMemoryBound(to: foo) // not what you might expect
///
/// Despite the fact that the function argument is equal to `Foo.self`, the
/// deduced type of `T` is `Any`.  It isn't always obvious at the use site of
/// such an API that the *value* of the function argument is irrelevant and only
/// its type matters. To avoid this problem, we can instead use `Type<T>` in the
/// function signature:
///
///     extension UnsafeRawPointer {
///       func assumingMemoryBound<T>(to _: Type<T>) -> UnsafePointer<T> { ... }
///     }
///
/// which is then used as follows:
///
///     someRawPointer.assumingMemoryBound(to: Type<Foo>())
///
public struct Type<T> {
  public init() {}
}
