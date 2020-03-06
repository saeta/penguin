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

import XCTest
import PenguinParallel

final class TakePipelineIteratorTests: XCTestCase {
    func testTake() throws {
        var itr = PipelineIterator.range(to: 10).take(3)
        XCTAssertEqual(0, try! itr.next())
        XCTAssertEqual(1, try! itr.next())
        XCTAssertEqual(2, try! itr.next())
        XCTAssertNil(try! itr.next())
    }

    func testDrop() throws {
        var itr = PipelineIterator.range(to: 5).drop(2)
        XCTAssertEqual(2, try! itr.next())
        XCTAssertEqual(3, try! itr.next())
        XCTAssertEqual(4, try! itr.next())
        XCTAssertEqual(5, try! itr.next())
        XCTAssertNil(try! itr.next())
    }

    static var allTests = [
        ("testTake", testTake),
        ("testDrop", testDrop),
    ]
}
