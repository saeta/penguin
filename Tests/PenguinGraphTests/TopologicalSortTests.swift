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

import PenguinGraphs
import PenguinStructures
import XCTest

final class TopologicalSortTests: XCTestCase {
  typealias Graph = SimpleAdjacencyList

  func testSimple() throws {
    // v0 -> v1 -> v2
    //        '-> v3 -> v4
    var g = Graph()
    let v0 = g.addVertex()
    let v1 = g.addVertex()
    let v2 = g.addVertex()
    let v3 = g.addVertex()
    let v4 = g.addVertex()
    _ = g.addEdge(from: v0, to: v1)
    _ = g.addEdge(from: v1, to: v2)
    _ = g.addEdge(from: v1, to: v3)
    _ = g.addEdge(from: v3, to: v4)

    let sort = try g.topologicalSort()

    XCTAssertEqual([v0, v1, v3, v4, v2], sort)
  }

  func testDisconnected() throws {
    var g = Graph()
    let v0 = g.addVertex()
    let v1 = g.addVertex()
    let v2 = g.addVertex()
    let v3 = g.addVertex()
    let v4 = g.addVertex()

    let sort = try g.topologicalSort()

    XCTAssertEqual([v0, v1, v2, v3, v4].reversed(), sort)
  }

  func testCycle() throws {
    // v0 -> v1 -> v2
    //        '-> v3 -> v4
    //             ^-----'
    var g = Graph()
    let v0 = g.addVertex()
    let v1 = g.addVertex()
    let v2 = g.addVertex()
    let v3 = g.addVertex()
    let v4 = g.addVertex()
    _ = g.addEdge(from: v0, to: v1)
    _ = g.addEdge(from: v1, to: v2)
    _ = g.addEdge(from: v1, to: v3)
    _ = g.addEdge(from: v3, to: v4)
    _ = g.addEdge(from: v4, to: v3)  // Cycle edge!

    do {
      _ = try g.topologicalSort()
      XCTFail("Should have thrown a cycle detected error!")
    } catch GraphErrors.cycleDetected {
      // Success.
      return
    }
    XCTFail("Wrong error thrown!")
  }

  static var allTests = [
    ("testSimple", testSimple),
    ("testDisconnected", testDisconnected),
    ("testCycle", testCycle),
  ]
}
