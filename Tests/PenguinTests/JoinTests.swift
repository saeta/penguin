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

@testable import Penguin

final class JoinTests: XCTestCase {

  func testSimpleJoin() throws {
    let c1 = PColumn([1, 2, 3, 1, 2, 1])
    let c2 = PColumn([100, 200, 300, -100, 250, 500])
    let table = try! PTable([("id", c1), ("c2", c2)])

    let m1 = PColumn([1, 2, 3])
    let m2 = PColumn(["Alice", "Bob", "Eve"])
    let metadataTable = try! PTable(["id": m1, "name": m2])

    let joined = try table.join(with: metadataTable, onColumn: "id")

    let j1 = PColumn([1, 2, 3, 1, 2, 1])
    let j2 = PColumn([100, 200, 300, -100, 250, 500])
    let j3 = PColumn(["Alice", "Bob", "Eve", "Alice", "Bob", "Alice"])
    let expected = try! PTable([("id", j1), ("c2", j2), ("name", j3)])

    XCTAssertEqual(expected, joined)
  }

  static var allTests = [
    ("testSimpleJoin", testSimpleJoin),
  ]
}
