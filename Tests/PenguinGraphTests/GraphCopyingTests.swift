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

final class GraphCopyingTests: XCTestCase {

  func testUndirectedCopying() {
    let s = UndirectedStarGraph(n: 5)

    do {    
      let l = SimpleAdjacencyList(s)  // Double edges.
      XCTAssertEqual(2 * s.edgeCount, l.edgeCount)

      for v in s.vertices {
        let listEdges = l.edges(from: v)
        let starEdges = s.edges(from: v)
        XCTAssertEqual(listEdges.count, starEdges.count)
        for (lEdge, sEdge) in zip(listEdges, starEdges) {
          XCTAssertEqual(l.source(of: lEdge), s.source(of: sEdge))
          XCTAssertEqual(l.destination(of: lEdge), s.destination(of: sEdge))
        }
      }
    }

    let l = SimpleUndirectedAdjacencyList(s.uniquingUndirectedEdges())
    XCTAssertEqual(s.edgeCount, l.edgeCount)

    for eStar in s.edges {
      let listEdges = l.edges(from: s.source(of: eStar))
      XCTAssertEqual(1, listEdges.count)
      let eList = listEdges.first!
      XCTAssertEqual(l.destination(of: eList), s.destination(of: eStar))
    }
  }

  func testProperyGraphCopying() {
    var src = UndirectedAdjacencyList<String, String, Int>()
    src.reserveCapacity(vertexCount: 3)
    _ = src.addVertex(storing: "0")
    _ = src.addVertex(storing: "1")
    _ = src.addVertex(storing: "2")

    _ = src.addEdge(from: 0, to: 1, storing: "0->1")
    _ = src.addEdge(from: 0, to: 2, storing: "0->2")
    _ = src.addEdge(from: 1, to: 2, storing: "1->2")


    // Convert to directed.
    let dst = DirectedAdjacencyList(src)

    XCTAssertEqual(3, dst.vertexCount)
    XCTAssertEqual(6, dst.edgeCount)

    do {
      let edges = dst.edges(from: 0)
      XCTAssertEqual(2, edges.count)
      XCTAssertEqual("0->1", dst[edge: edges[0]])
      XCTAssertEqual("0->2", dst[edge: edges[1]])
    }

    do {
      let edges = dst.edges(from: 1)
      XCTAssertEqual(2, edges.count)
      XCTAssertEqual("1->2", dst[edge: edges[0]])
      XCTAssertEqual("0->1", dst[edge: edges[1]])
    }

    do {
      let edges = dst.edges(from: 2)
      XCTAssertEqual(2, edges.count)
      XCTAssertEqual("0->2", dst[edge: edges[0]])
      XCTAssertEqual("1->2", dst[edge: edges[1]])
    }
  }

  func testProperyGraphCopyingBidirectional() {
    var src = UndirectedAdjacencyList<String, String, Int>()
    src.reserveCapacity(vertexCount: 3)
    _ = src.addVertex(storing: "0")
    _ = src.addVertex(storing: "1")
    _ = src.addVertex(storing: "2")

    _ = src.addEdge(from: 0, to: 1, storing: "0->1")
    _ = src.addEdge(from: 0, to: 2, storing: "0->2")
    _ = src.addEdge(from: 1, to: 2, storing: "1->2")

    let dst = BidirectionalAdjacencyList(src.uniquingUndirectedEdges())

    XCTAssertEqual(3, dst.vertexCount)
    XCTAssertEqual(3, dst.edgeCount)

    XCTAssertEqual(2, dst.edges(from: 0).count)
    XCTAssertEqual(1, dst.edges(from: 1).count)
    XCTAssertEqual(0, dst.edges(from: 2).count)

    XCTAssertEqual(0, dst.edges(to: 0).count)
    XCTAssertEqual(1, dst.edges(to: 1).count)
    XCTAssertEqual(2, dst.inDegree(of: 2))
  }

  func testAddingEdges() {
    var src = DirectedAdjacencyList<String, String, Int>()
    _ = src.addVertex()
    let srcV1 = src.addVertex()
    let srcV2 = src.addVertex()

    _ = src.addEdge(from: srcV1, to: srcV2, storing: "1->2 (src)")

    var dst = UndirectedAdjacencyList<String, String, Int>()
    let dstV0 = dst.addVertex()
    let dstV1 = dst.addVertex()
    let dstV2 = dst.addVertex()

    _ = dst.addEdge(from: dstV0, to: dstV1, storing: "0->1 (dst)")
    var edgeCallback = false
    dst.addEdges(from: src) { e, g in
      XCTAssertFalse(edgeCallback)
      edgeCallback = true
      XCTAssertEqual(srcV1, g.source(of: e))
      XCTAssertEqual(srcV2, g.destination(of: e))
    }
    XCTAssert(edgeCallback)

    let edges = dst.edges(from: dstV2)
    XCTAssertEqual(1, edges.count)
    XCTAssertEqual(dstV2, dst.source(of: edges[dstV0]))
    XCTAssertEqual(dstV1, dst.destination(of: edges[0]))
    XCTAssertEqual("1->2 (src)", dst[edge: edges[0]])
  }

  static var allTests = [
    ("testUndirectedCopying", testUndirectedCopying),
    ("testProperyGraphCopying", testProperyGraphCopying),
    ("testProperyGraphCopyingBidirectional", testProperyGraphCopyingBidirectional),
    ("testAddingEdges", testAddingEdges),
  ]
}
