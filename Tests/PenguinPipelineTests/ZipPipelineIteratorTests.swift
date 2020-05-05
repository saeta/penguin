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

final class ZipPipelineIteratorTests: XCTestCase {

  func testZipAndMapTwoArrays() {
    let arr = [0, 1, 2, 3, 4]
    let tmp = PipelineIterator.zip(
      arr.makePipelineIterator(), arr.makePipelineIterator().map(name: "first") { $0 + 1 })
    var itr = tmp.map(name: "second") { $0.0 + $0.1 }
    XCTAssertEqual(1, try! itr.next())
    XCTAssertEqual(3, try! itr.next())
    XCTAssertEqual(5, try! itr.next())
    XCTAssertEqual(7, try! itr.next())
    XCTAssertEqual(9, try! itr.next())
    XCTAssertEqual(nil, try! itr.next())
  }

  func testZipEndEarly() {
    var itr = PipelineIterator.zip(
      [0, 1, 2].makePipelineIterator(), [0, 1].makePipelineIterator())
    XCTAssert(try! itr.next() != nil)
    XCTAssert(try! itr.next() != nil)
    XCTAssert(try! itr.next() == nil)
  }

  static var allTests = [
    ("testZipAndMapTwoArrays", testZipAndMapTwoArrays),
    ("testZipEndEarly", testZipEndEarly),
  ]
}
