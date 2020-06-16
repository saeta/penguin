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

import PenguinStructures
import PenguinGraphs
import XCTest

final class GraphTransformationsTests: XCTestCase {

  func testUnionEdges() {
    var g1 = BidirectionalAdjacencyList<Int, String, Int>()
    _ = g1.addVertex(storing: 10)
    _ = g1.addVertex(storing: 11)
    _ = g1.addVertex(storing: 12)
    _ = g1.addEdge(from: 0, to: 1, storing: "0->1 (g1)")

    var g2 = BidirectionalAdjacencyList<Empty, String, Int>()
    _ = g2.addVertex()
    _ = g2.addVertex()
    _ = g2.addVertex()
    _ = g2.addEdge(from: 1, to: 2, storing: "1->2 (g2)")

    var g = g1.unionEdges(with: g2)

    XCTAssertEqual(3, g.vertexCount)
    XCTAssertEqual(Array(0..<3), Array(g.vertices))
    XCTAssertEqual(Array(10..<13), g.vertices.map { g[vertex: $0] })

    var recorder = TablePredecessorRecorder(for: g)
    g.breadthFirstSearch(startingAt: 0) { recorder.record($0, graph: $1) }
    XCTAssertEqual([0, 1, 2], Array(recorder.path(to: 2)!))
  }

  static var allTests = [
    ("testUnionEdges", testUnionEdges),
  ]
}
