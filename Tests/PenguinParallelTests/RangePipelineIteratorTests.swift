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

import PenguinParallel
import XCTest

final class RangePipelineIteratorTests: XCTestCase {

  func testRangePipelineIterator() {
    var itr = RangePipelineIterator(start: 1, end: 6, step: 2)
    XCTAssertEqual(1, try! itr.next())
    XCTAssertEqual(3, try! itr.next())
    XCTAssertEqual(5, try! itr.next())
    XCTAssertEqual(nil, try! itr.next())
  }

  func testRangeInit() {
    var itr = PipelineIterator.range(1..<4)
    XCTAssertEqual(1, try! itr.next())
    XCTAssertEqual(2, try! itr.next())
    XCTAssertEqual(3, try! itr.next())
    XCTAssertEqual(nil, try! itr.next())
  }

  func testClosedRangeInit() {
    var itr = PipelineIterator.range(1...4)
    XCTAssertEqual(1, try! itr.next())
    XCTAssertEqual(2, try! itr.next())
    XCTAssertEqual(3, try! itr.next())
    XCTAssertEqual(4, try! itr.next())
    XCTAssertEqual(nil, try! itr.next())
  }

  func testEnumerated() {
    var itr = ["zero", "one", "two"].makePipelineIterator().enumerated()
    var tmp = try! itr.next()
    XCTAssertEqual(0, tmp?.0)
    XCTAssertEqual("zero", tmp?.1)
    tmp = try! itr.next()
    XCTAssertEqual(1, tmp?.0)
    XCTAssertEqual("one", tmp?.1)
    tmp = try! itr.next()
    XCTAssertEqual(2, tmp?.0)
    XCTAssertEqual("two", tmp?.1)
    XCTAssert(try! itr.next() == nil)
  }

  static var allTests = [
    ("testRangePipelineIterator", testRangePipelineIterator),
    ("testRangeInit", testRangeInit),
    ("testClosedRangeInit", testClosedRangeInit),
    ("testEnumerated", testEnumerated),
  ]
}
