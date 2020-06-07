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
import XCTest
@testable import PenguinStructures

public class Base : FactoryInitializable {
  /// Constructs an instance whose dynamic type depends on the value of `one`.
  public convenience init(optimallyBeDerived1 one: Bool) {
    self.init(unsafelyAliasing: one ? Derived1() : Derived2())
  }

  /// Constructs an instance whose dynamic type depends on the value of `one`
  public convenience init(safelyBeDerived1 one: Bool) {
    self.init(aliasing: one ? Derived1() : Derived2())
  }
}

internal class Derived1 : Base {
  override public init() { super.init() }
}

internal class Derived2 : Base {
  override public init() { super.init() }
}

class FactoryInitializableTests: XCTestCase {
  func test_initAliasing() {
    XCTAssert(Base(safelyBeDerived1: true) is Derived1)
    XCTAssert(Base(safelyBeDerived1: false) is Derived2)
  }

  func test_initUnsafelyAliasing() {
    XCTAssert(Base(optimallyBeDerived1: true) is Derived1)
    XCTAssert(Base(optimallyBeDerived1: false) is Derived2)
  }
  
  static var allTests = [
    ("test_initAliasing", test_initAliasing),
    ("test_initUnsafelyAliasing", test_initUnsafelyAliasing),
  ]
}
