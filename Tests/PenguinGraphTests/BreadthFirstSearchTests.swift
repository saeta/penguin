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

final class BreadthFirstSearchTests: XCTestCase {
  typealias Graph = SimpleAdjacencyList<Int>

  struct RecorderVisitor {
    typealias VertexId = BreadthFirstSearchTests.Graph.VertexId
    typealias EdgeId = BreadthFirstSearchTests.Graph.EdgeId

    var startVerticies = [VertexId]()
    var discoveredVerticies = [VertexId]()
    var examinedVerticies = [VertexId]()
    var examinedEdges = [EdgeId]()
    var treeEdges = [EdgeId]()
    var nonTreeEdges = [EdgeId]()
    var grayDestinationEdges = [EdgeId]()
    var blackDestinationEdges = [EdgeId]()
    var finishedVerticies = [VertexId]()

    mutating func consume(_ e: BFSEvent<BreadthFirstSearchTests.Graph>) {
      switch e {
      case let .start(v): startVerticies.append(v)
      case let .discover(v): discoveredVerticies.append(v)
      case let .examineVertex(v): examinedVerticies.append(v)
      case let .examineEdge(e): examinedEdges.append(e)
      case let .treeEdge(e): treeEdges.append(e)
      case let .nonTreeEdge(e): nonTreeEdges.append(e)
      case let .grayDestination(e): grayDestinationEdges.append(e)
      case let .blackDestination(e): blackDestinationEdges.append(e)
      case let .finish(v): finishedVerticies.append(v)
      }
    }
  }

  func testSimple() throws {
    // v0 -> v1 -> v2
    //        '-> v3 -> v4
    var g = Graph()
    let v0 = g.addVertex()
    let v1 = g.addVertex()
    let v2 = g.addVertex()
    let v3 = g.addVertex()
    let v4 = g.addVertex()
    let e0 = g.addEdge(from: v0, to: v1)
    let e1 = g.addEdge(from: v1, to: v2)
    let e2 = g.addEdge(from: v1, to: v3)
    let e3 = g.addEdge(from: v3, to: v4)

    var recorder = RecorderVisitor()

    g.breadthFirstSearch(startingAt: [v0]) { e, g in
      recorder.consume(e)
    }

    XCTAssertEqual([v0], recorder.startVerticies)
    XCTAssertEqual([v0, v1, v2, v3, v4], recorder.discoveredVerticies)
    XCTAssertEqual([v0, v1, v2, v3, v4], recorder.examinedVerticies)
    XCTAssertEqual([e0, e1, e2, e3], recorder.examinedEdges)
    XCTAssertEqual([e0, e1, e2, e3], recorder.treeEdges)
    XCTAssertEqual([], recorder.nonTreeEdges)
    XCTAssertEqual([], recorder.grayDestinationEdges)
    XCTAssertEqual([], recorder.blackDestinationEdges)
    XCTAssertEqual([v0, v1, v2, v3, v4], recorder.finishedVerticies)
  }

  func testPredecessorTracking() throws {
    // v0 -> v1 -> v2
    //        '-> v3 -> v4
    var g = Graph()
    let v0 = g.addVertex()
    let v1 = g.addVertex()
    let v2 = g.addVertex()
    let v3 = g.addVertex()
    let v4 = g.addVertex()
    let e0 = g.addEdge(from: v0, to: v1)
    let e1 = g.addEdge(from: v1, to: v2)
    let e2 = g.addEdge(from: v1, to: v3)
    let e3 = g.addEdge(from: v3, to: v4)

    var recorder = RecorderVisitor()
    var predecessors = TablePredecessorVisitor(for: g)

    g.breadthFirstSearch(startingAt: [v0]) { e, g in
      recorder.consume(e)
      predecessors.consume(e, graph: g)
    }

    XCTAssertEqual([v0], recorder.startVerticies)
    XCTAssertEqual([v0, v1, v2, v3, v4], recorder.discoveredVerticies)
    XCTAssertEqual([v0, v1, v2, v3, v4], recorder.examinedVerticies)
    XCTAssertEqual([e0, e1, e2, e3], recorder.examinedEdges)
    XCTAssertEqual([e0, e1, e2, e3], recorder.treeEdges)
    XCTAssertEqual([], recorder.nonTreeEdges)
    XCTAssertEqual([], recorder.grayDestinationEdges)
    XCTAssertEqual([], recorder.blackDestinationEdges)
    XCTAssertEqual([v0, v1, v2, v3, v4], recorder.finishedVerticies)

    XCTAssertEqual([nil, v0, v1, v1, v3], predecessors.predecessors)
  }

  static var allTests = [
    ("testSimple", testSimple),
    ("testPredecessorTracking", testPredecessorTracking),
  ]
}
