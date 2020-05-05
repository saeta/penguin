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

import PenguinPipeline
import XCTest

final class FunctionGeneratorPipelineIteratorTests: XCTestCase {

  func testSimpleFunctionGenerator() {
    var i = 0
    var itr: FunctionGeneratorPipelineIterator<Int> = PipelineIterator.fromFunction {
      if i >= 3 { return nil }
      i += 1
      return i
    }
    XCTAssertEqual(1, try! itr.next())
    XCTAssertEqual(2, try! itr.next())
    XCTAssertEqual(3, try! itr.next())
    XCTAssertEqual(nil, try! itr.next())
  }

  func testSimpleInfiniteFunctionGenerator() {
    var i = 0
    var itr = PipelineIterator.fromFunction(Int.self) {
      i += 1
      return i
    }.take(3)
    XCTAssertEqual(1, try! itr.next())
    XCTAssertEqual(2, try! itr.next())
    XCTAssertEqual(3, try! itr.next())
    XCTAssertEqual(nil, try! itr.next())
  }

  func testThrowingFunctionGenerator() throws {
    var i = 0
    var itr: FunctionGeneratorPipelineIterator<Int> = PipelineIterator.fromFunction {
      i += 1
      if i == 2 {
        throw TestErrors.silly
      }
      if i > 3 { return nil }
      return i
    }
    XCTAssertEqual(1, try! itr.next())
    do {
      _ = try itr.next()
      XCTFail("Should have thrown.")
    } catch TestErrors.silly {
      // Success
    }
    XCTAssertEqual(3, try! itr.next())
    XCTAssertEqual(nil, try! itr.next())
  }

  static var allTests = [
    ("testSimpleFunctionGenerator", testSimpleFunctionGenerator),
    ("testSimpleInfiniteFunctionGenerator", testSimpleInfiniteFunctionGenerator),
    ("testThrowingFunctionGenerator", testThrowingFunctionGenerator),
  ]
}

fileprivate enum TestErrors: Error {
  case silly
}
