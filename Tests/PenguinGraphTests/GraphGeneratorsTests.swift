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
import XCTest

final class GraphGeneratorsTests: XCTestCase {

  func testDirectedStarGraph() {
    let g = DirectedStarGraph(vertexCount: 5)
    XCTAssertEqual(5, g.vertexCount)
    XCTAssertEqual(0..<5, g.vertices)
    for i in 0..<5 {
      let edges = g.edges(from: i)
      XCTAssertEqual(1, edges.count)
      let edge = edges.first!
      XCTAssertEqual(i, g.source(of: edge))
      XCTAssertEqual(0, g.destination(of: edge))
    }

    for i in 1..<5 {
      let reverseEdges = g.edges(to: i)
      XCTAssertEqual(0, reverseEdges.count)
    }

    let allEdges = g.edges(to: 0)
    XCTAssertEqual(5, allEdges.count)
    for i in 0..<5 {
      XCTAssertEqual(i, g.source(of: allEdges[i]))
      XCTAssertEqual(0, g.destination(of: allEdges[i]))
    }
  }

  func testUndirectedStarGraph() {
    let g = UndirectedStarGraph(vertexCount: 6)
    XCTAssertEqual(6, g.vertexCount)

    for i in 1..<6 {
      let edges = g.edges(from: i)
      XCTAssertEqual(1, edges.count)
      let edge = edges.first!
      XCTAssertEqual(i, g.source(of: edge))
      XCTAssertEqual(0, g.destination(of: edge))
    }

    let originEdges = g.edges(from: 0)
    XCTAssertEqual(5, originEdges.count)
    for (i, edge) in originEdges.enumerated() {
      XCTAssertEqual(0, g.source(of: edge))
      XCTAssertEqual(i + 1, g.destination(of: edge))

      let reverseEdge = g.edges(from: i + 1).first!
      XCTAssertEqual(edge, reverseEdge)
    }
  }

  func testCompleteGraph() {
    let g = CompleteGraph(vertexCount: 7)

    for i in 0..<7 {
      let edges = g.edges(from: i)
      XCTAssertEqual(7, edges.count)
      for (j, e) in edges.enumerated() {
        XCTAssertEqual(i, g.source(of: e))
        XCTAssertEqual(j, g.destination(of: e))
      }
    }

    for i in 0..<7 {
      let edges = g.edges(to: i)
      XCTAssertEqual(7, edges.count)
      for (j, e) in edges.enumerated() {
        XCTAssertEqual(i, g.destination(of: e))
        XCTAssertEqual(j, g.source(of: e))
      }
    }
  }

  func testCircleGraph() {
    let g1 = CircleGraph(vertexCount: 10, outDegree: 1)
    for i in 0..<9 {
      let edges = g1.edges(from: i)
      XCTAssertEqual(1, edges.count)
      let edge = edges.first!
      XCTAssertEqual(i, g1.source(of: edge))
      XCTAssertEqual(i + 1, g1.destination(of: edge))
    }
    let wrapAround = g1.edges(from: 9)
    XCTAssertEqual(1, wrapAround.count)
    let edge = wrapAround.first!
    XCTAssertEqual(9, g1.source(of: edge))
    XCTAssertEqual(0, g1.destination(of: edge))

    let g4 = CircleGraph(vertexCount: 10, outDegree: 4)
    for i in 0..<10 {
      let edges = g4.edges(from: i)
      XCTAssertEqual(4, edges.count)
      for (j, edge) in edges.enumerated() {
        XCTAssertEqual(i, g4.source(of: edge))
        XCTAssertEqual((i + j + 1) % 10, g4.destination(of: edge))
      }
    }
  }

  func testLollipopGraph() {
    let g = LollipopGraph(m: 8, n: 4)
    XCTAssertEqual(12, g.vertexCount)

    for i in 0..<7 {
      let edges = g.edges(from: i)
      XCTAssertEqual(7, edges.count)
      var seenVertices = Set([i])
      for edge in edges {
        XCTAssertEqual(i, g.source(of: edge))
        seenVertices.insert(g.destination(of: edge))
      }
      XCTAssertEqual(Set(0..<8), seenVertices)
    }
    do {
      // The special juncture vertex.
      let edges = g.edges(from: 7)
      XCTAssertEqual(8, edges.count)
      var seenVertices = Set([7])
      for edge in edges {
        XCTAssertEqual(7, g.source(of: edge))
        seenVertices.insert(g.destination(of: edge))
      }
      XCTAssertEqual(Set(0...8), seenVertices)
    }

    for i in 8..<11 {
      let edges = g.edges(from: i)
      XCTAssertEqual(2, edges.count)
    }
    XCTAssertEqual(1, g.edges(from: 11).count)
  }

  func testDirectedStarGraphTransposing() {
    let g = DirectedStarGraph(n: 10).transposed().excludingSelfLoops()
    for i in 1..<10 {
      XCTAssertEqual(0, g.outDegree(of: i))
    }
    XCTAssertEqual(9, g.outDegree(of: 0))
  }

  static var allTests = [
    ("testDirectedStarGraph", testDirectedStarGraph),
    ("testUndirectedStarGraph", testUndirectedStarGraph),
    ("testCompleteGraph", testCompleteGraph),
    ("testCircleGraph", testCircleGraph),
    ("testLollipopGraph", testLollipopGraph),
    ("testDirectedStarGraphTransposing", testDirectedStarGraphTransposing),
  ]
}
