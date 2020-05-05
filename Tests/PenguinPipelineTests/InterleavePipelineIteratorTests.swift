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

final class InterleavePipelineIteratorTests: XCTestCase {
  func testInterleave() throws {
    var itr = PipelineIterator.range(to: 3).interleave(cycleCount: 2) {
      PipelineIterator.range(from: (10 * $0), to: (10 * $0) + $0)
    }
    XCTAssertEqual(0, try! itr.next())
    XCTAssertEqual(10, try! itr.next())
    XCTAssertEqual(11, try! itr.next())
    XCTAssertEqual(20, try! itr.next())
    XCTAssertEqual(21, try! itr.next())
    XCTAssertEqual(30, try! itr.next())
    XCTAssertEqual(22, try! itr.next())
    XCTAssertEqual(31, try! itr.next())
    XCTAssertEqual(32, try! itr.next())
    XCTAssertEqual(33, try! itr.next())
    XCTAssertNil(try! itr.next())
  }

  static var allTests = [
    ("testInterleave", testInterleave)
  ]
}
