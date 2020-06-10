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
import PenguinParallelWithFoundation
import PenguinStructures
import XCTest

final class EdgeInfoTests: XCTestCase {
  typealias Graph = DirectedAdjacencyList<Empty, Empty, Int>

  func testParallelEdges() {
    var g = Graph()
    for _ in 0..<10 {
      _ = g.addVertex()
    }
    XCTAssertFalse(g.hasParallelEdges)

    for i in 0..<10 {
      for j in 0..<10 {
        _ = g.addEdge(from: i, to: j)
      }
    }
    XCTAssertFalse(g.hasParallelEdges)

    _ = g.addEdge(from: 3, to: 4)
    XCTAssert(g.hasParallelEdges)
  }

  func testSelfEdges() {
    var g = Graph()
    for _ in 0..<5 {
      _ = g.addVertex()
    }
    XCTAssertFalse(g.hasSelfEdge)

    for i in 0..<5 {
      for j in 0..<5 {
        if i == j { continue }
        _ = g.addEdge(from: i, to: j)
      }
    }
    XCTAssertFalse(g.hasSelfEdge)

    _ = g.addEdge(from: 3, to: 3)
    XCTAssert(g.hasSelfEdge)
  }

  static var allTests = [
    ("testParallelEdges", testParallelEdges),
    ("testSelfEdges", testSelfEdges),
  ]
}
