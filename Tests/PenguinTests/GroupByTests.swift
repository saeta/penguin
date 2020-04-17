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

final class GroupByTests: XCTestCase {

  func testSimpleGroupBy() throws {
    let c1 = PColumn([1, 2, 3, 1, 2, 1])
    let c2 = PColumn([10, 20, 30, 10, 20, 10])
    let c3 = PColumn([100, 200, 300, -100, 200, 500])
    let table = try! PTable(["c1": c1, "c2": c2, "c3": c3])

    let grouped = try table.group(by: "c1", applying: .count, .sum)

    let e1 = PColumn([1, 2, 3])
    let e2 = PColumn([3, 2, 1])
    let e3 = PColumn([30, 40, 30])
    let e4 = PColumn([500, 400, 300])
    let expected = try! PTable([("c1", e1), ("count", e2), ("c2_sum", e3), ("c3_sum", e4)])

    XCTAssertEqual(expected, grouped)
  }

  func testGroupByManyOperations() throws {
    let c1 = PColumn([1, 2, 3, 1, 2, 1, nil, 1, 1, 2, nil])
    let c2 = PColumn([10, 20, 30, 10, 20, 10, 5, 10, 10, 20, 5])
    let c3 = PColumn([100, 200, 300, -100, 200, 500, 10, 300, 200, 100, 10])
    let c4 = PColumn(["a", "a", "a", "bb", "bb", "ccc", nil, "d", "d", "e", nil])
    let table = try! PTable(["c1": c1, "c2": c2, "c3": c3, "c4": c4])

    let grouped = try table.group(by: "c1", applying: .count, .sum, .longest, .countNils)

    let e1 = PColumn([1, 2, 3, nil])
    let e2 = PColumn([5, 3, 1, 2])
    let e3 = PColumn([50, 60, 30, 10])
    let e4 = PColumn([1000, 500, 300, 20])
    let e5 = PColumn(["ccc", "bb", "a", nil])
    let e6 = PColumn([0, 0, 0, 0])
    let e7 = PColumn([0, 0, 0, 2])
    let expected = try! PTable([
      ("c1", e1),
      ("count", e2),
      ("c2_sum", e3),
      ("c2_nils_count", e6),
      ("c3_sum", e4),
      ("c3_nils_count", e6),
      ("c4_longest", e5),
      ("c4_nils_count", e7),
    ])

    XCTAssertEqual(expected, grouped)

  }

  func testGroupByMulitpleColumns() throws {
    let c1 = PColumn([1, 2, 3, 1, 2, 1, nil, 1, 1, 2, nil])
    let c2 = PColumn([10, 20, 30, 10, 20, 10, 5, 10, 10, 20, 5])
    let c3 = PColumn([100, 200, 300, -100, 200, 500, 10, 300, 200, 100, 10])
    let c4 = PColumn(["a", "a", "a", "bb", "bb", "ccc", nil, "d", "d", "e", nil])
    let table = try! PTable(["c1": c1, "c2": c2, "c3": c3, "c4": c4])

    let grouped = try table.group(by: ["c1", "c2"], applying: .count, .sum, .longest, .countNils)

    let e1 = PColumn([1, 2, 3, nil])
    let e2 = PColumn([10, 20, 30, 5])
    let e3 = PColumn([5, 3, 1, 2])
    let e4 = PColumn([1000, 500, 300, 20])
    let e5 = PColumn(["ccc", "bb", "a", nil])
    let e6 = PColumn([0, 0, 0, 0])
    let e7 = PColumn([0, 0, 0, 2])
    let expected = try! PTable([
      ("c1", e1),
      ("c2", e2),
      ("count", e3),
      ("c3_sum", e4),
      ("c3_nils_count", e6),
      ("c4_longest", e5),
      ("c4_nils_count", e7),
    ])

    XCTAssertEqual(expected, grouped)
  }

  func testGroupByMulitpleColumnsDistinctGroups() throws {
    let c1 = PColumn([1, 2, 3, 1, 2, 1, nil, 1, 1, 2, nil])
    let c2 = PColumn([10, 20, 30, 10, 20, 15, 5, 15, 15, 15, 5])
    let c3 = PColumn([100, 200, 300, -100, 200, 500, 10, 300, 200, 100, 10])
    let c4 = PColumn(["a", "a", "a", "bb", "bb", "ccc", nil, "d", "d", "e", nil])
    let table = try! PTable(["c1": c1, "c2": c2, "c3": c3, "c4": c4])

    let grouped = try table.group(by: ["c1", "c2"], applying: .count, .sum, .longest, .countNils)

    let e1 = PColumn([1, 2, 3, 1, nil, 2])
    let e2 = PColumn([10, 20, 30, 15, 5, 15])
    let e3 = PColumn([2, 2, 1, 3, 2, 1])
    let e4 = PColumn([0, 400, 300, 1000, 20, 100])
    let e5 = PColumn(["bb", "bb", "a", "ccc", nil, "e"])
    let e6 = PColumn([0, 0, 0, 0, 0, 0])
    let e7 = PColumn([0, 0, 0, 0, 2, 0])
    let expected = try! PTable([
      ("c1", e1),
      ("c2", e2),
      ("count", e3),
      ("c3_sum", e4),
      ("c3_nils_count", e6),
      ("c4_longest", e5),
      ("c4_nils_count", e7),
    ])

    XCTAssertEqual(expected, grouped)
  }

  static var allTests = [
    ("testSimpleGroupBy", testSimpleGroupBy),
    ("testGroupByManyOperations", testGroupByManyOperations),
    ("testGroupByMulitpleColumns", testGroupByMulitpleColumns),
    ("testGroupByMulitpleColumnsDistinctGroups", testGroupByMulitpleColumnsDistinctGroups),
  ]
}
