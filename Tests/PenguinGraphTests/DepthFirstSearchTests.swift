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

final class DepthFirstSearchTests: XCTestCase {
  typealias Graph = SimpleAdjacencyList<Int>

  struct RecorderVisiter {
    typealias Graph = DepthFirstSearchTests.Graph
    let expectedStart: Graph.VertexId
    var discoveredVerticies = [Graph.VertexId]()
    var examinedEdges = [Graph.EdgeId]()
    var treeEdges = [Graph.EdgeId]()
    var backEdges = [Graph.EdgeId]()
    var forwardEdges = [Graph.EdgeId]()
    var finishedVerticies = [Graph.VertexId]()

    init(expectedStart: Graph.VertexId) {
      self.expectedStart = expectedStart
    }

    mutating func consume(_ event: DFSEvent<Graph>) {
      switch event {
      case let .start(vertex):
        XCTAssertEqual(vertex, expectedStart)
      case let .discover(vertex):
        discoveredVerticies.append(vertex)
      case let .examine(edge):
        examinedEdges.append(edge)
      case let .treeEdge(edge):
        treeEdges.append(edge)
      case let .backEdge(edge):
        backEdges.append(edge)
      case let .forwardOrCrossEdge(edge):
        forwardEdges.append(edge)
      case let .finish(vertex):
        finishedVerticies.append(vertex)
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

    var recorder = RecorderVisiter(expectedStart: v0)
    var vertexVisitationState = TablePropertyMap(repeating: VertexColor.white, forVerticesIn: g)
    g.depthFirstSearch(startingAt: v0, vertexVisitationState: &vertexVisitationState) { e, g in
      recorder.consume(e)
    }

    XCTAssertEqual([v0, v1, v2, v3, v4], recorder.discoveredVerticies)
    XCTAssertEqual([e0, e1, e2, e3], recorder.examinedEdges)
    XCTAssertEqual([e0, e1, e2, e3], recorder.treeEdges)
    XCTAssertEqual([], recorder.backEdges)
    XCTAssertEqual([], recorder.forwardEdges)
    XCTAssertEqual([v2, v4, v3, v1, v0], recorder.finishedVerticies)
  }

  func testEarlyStopping() throws {
    // v0 -> v1 -> v2
    var g = Graph()
    let v0 = g.addVertex()
    let v1 = g.addVertex()
    let v2 = g.addVertex()
    let e0 = g.addEdge(from: v0, to: v1)
    _ = g.addEdge(from: v1, to: v2)

    var recorder = RecorderVisiter(expectedStart: v0)
    var vertexVisitationState = TablePropertyMap(repeating: VertexColor.white, forVerticesIn: g)
    try g.depthFirstSearch(startingAt: v0, vertexVisitationState: &vertexVisitationState) { e, g in
      recorder.consume(e)
      if case let .discover(vertex) = e, vertex == v1 { throw GraphErrors.stopSearch }
    }

    XCTAssertEqual([v0, v1], recorder.discoveredVerticies)
    XCTAssertEqual([e0], recorder.examinedEdges)
    XCTAssertEqual([e0], recorder.treeEdges)
    XCTAssertEqual([], recorder.backEdges)
    XCTAssertEqual([], recorder.forwardEdges)
    XCTAssertEqual([], recorder.finishedVerticies)
  }

  func testBackEdge() throws {
    // v0 -> v1 -> v2
    //  ^----------'
    var g = Graph()
    let v0 = g.addVertex()
    let v1 = g.addVertex()
    let v2 = g.addVertex()
    let e0 = g.addEdge(from: v0, to: v1)
    let e1 = g.addEdge(from: v1, to: v2)
    let e2 = g.addEdge(from: v2, to: v0)

    var recorder = RecorderVisiter(expectedStart: v0)
    g.depthFirstSearch(startingAt: v0) { e, g in recorder.consume(e) }

    XCTAssertEqual([v0, v1, v2], recorder.discoveredVerticies)
    XCTAssertEqual([e0, e1, e2], recorder.examinedEdges)
    XCTAssertEqual([e0, e1], recorder.treeEdges)
    XCTAssertEqual([e2], recorder.backEdges)
    XCTAssertEqual([], recorder.forwardEdges)
    XCTAssertEqual([v2, v1, v0], recorder.finishedVerticies)
  }

  func testForwardOrCrossEdge() throws {
    // v0 -> v1 -> v2 <-,
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
    let e4 = g.addEdge(from: v4, to: v2)

    var recorder = RecorderVisiter(expectedStart: v0)
    var vertexVisitationState = TablePropertyMap(repeating: VertexColor.white, forVerticesIn: g)
    g.depthFirstSearch(startingAt: v0, vertexVisitationState: &vertexVisitationState) { e, g in
      recorder.consume(e)
    }

    XCTAssertEqual([v0, v1, v2, v3, v4], recorder.discoveredVerticies)
    XCTAssertEqual([e0, e1, e2, e3, e4], recorder.examinedEdges)
    XCTAssertEqual([e0, e1, e2, e3], recorder.treeEdges)
    XCTAssertEqual([], recorder.backEdges)
    XCTAssertEqual([e4], recorder.forwardEdges)
    XCTAssertEqual([v2, v4, v3, v1, v0], recorder.finishedVerticies)
  }

  func testPredecessorTrackingAndVisitorChaining() throws {
    // v0 -> v1 -> v2 <-,
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
    let e4 = g.addEdge(from: v4, to: v2)

    var testRecorder = RecorderVisiter(expectedStart: v0)
    var predecessorVisitor = TablePredecessorRecorder(for: g)
    var vertexVisitationState = TablePropertyMap(repeating: VertexColor.white, forVerticesIn: g)
    g.depthFirstSearch(startingAt: v0, vertexVisitationState: &vertexVisitationState) { e, g in
      testRecorder.consume(e)
      predecessorVisitor.record(e, graph: g)
    }

    /// Ensure the RecorderVisiter recorded correctly.
    XCTAssertEqual([v0, v1, v2, v3, v4], testRecorder.discoveredVerticies)
    XCTAssertEqual([e0, e1, e2, e3, e4], testRecorder.examinedEdges)
    XCTAssertEqual([e0, e1, e2, e3], testRecorder.treeEdges)
    XCTAssertEqual([], testRecorder.backEdges)
    XCTAssertEqual([e4], testRecorder.forwardEdges)
    XCTAssertEqual([v2, v4, v3, v1, v0], testRecorder.finishedVerticies)

    XCTAssertEqual([nil, v0, v1, v1, v3], predecessorVisitor.predecessors)

  }

  static var allTests = [
    ("testSimple", testSimple),
    ("testEarlyStopping", testEarlyStopping),
    ("testBackEdge", testBackEdge),
    ("testForwardOrCrossEdge", testForwardOrCrossEdge),
    ("testPredecessorTrackingAndVisitorChaining", testPredecessorTrackingAndVisitorChaining),
  ]
}
