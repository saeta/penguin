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

  struct RecorderVisiter: DFSVisitor {
    let expectedStart: Graph.VertexId
    let earlyStopAt: Graph.VertexId?
    var discoveredVerticies = [Graph.VertexId]()
    var examinedEdges = [Graph.EdgeId]()
    var treeEdges = [Graph.EdgeId]()
    var backEdges = [Graph.EdgeId]()
    var forwardEdges = [Graph.EdgeId]()
    var finishedVerticies = [Graph.VertexId]()

    init(expectedStart: Graph.VertexId, earlyStopAt: Graph.VertexId? = nil) {
      self.expectedStart = expectedStart
      self.earlyStopAt = earlyStopAt
    }

    mutating func start(vertex: Graph.VertexId, _ graph: inout Graph) {
      XCTAssertEqual(vertex, expectedStart)
    }

    mutating func discover(vertex: Graph.VertexId, _ graph: inout Graph) throws {
      discoveredVerticies.append(vertex)
      if vertex == earlyStopAt { throw GraphErrors.stopSearch }
    }

    mutating func examine(edge: Graph.EdgeId, _ graph: inout Graph) {
      examinedEdges.append(edge)
    }

    mutating func treeEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) {
      treeEdges.append(edge)
    }

    mutating func backEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) {
      backEdges.append(edge)
    }

    mutating func forwardOrCrossEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) {
      forwardEdges.append(edge)
    }

    mutating func finish(vertex: Graph.VertexId, _ graph: inout Graph) {
      finishedVerticies.append(vertex)
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
    var vertexVisitationState = TableVertexPropertyMap(repeating: VertexColor.white, for: g)
    try g.depthFirstSearchNoInit(vertexVisitationState: &vertexVisitationState, visitor: &recorder, start: v0)

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

    var recorder = RecorderVisiter(expectedStart: v0, earlyStopAt: v1)
    var vertexVisitationState = TableVertexPropertyMap(repeating: VertexColor.white, for: g)
    try g.depthFirstSearchNoInit(vertexVisitationState: &vertexVisitationState, visitor: &recorder, start: v0)

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
    var vertexVisitationState = TableVertexPropertyMap(repeating: VertexColor.white, for: g)
    try g.depthFirstSearchNoInit(vertexVisitationState: &vertexVisitationState, visitor: &recorder, start: v0)

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
    var vertexVisitationState = TableVertexPropertyMap(repeating: VertexColor.white, for: g)
    try g.depthFirstSearchNoInit(vertexVisitationState: &vertexVisitationState, visitor: &recorder, start: v0)

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

    let testRecorder = RecorderVisiter(expectedStart: v0)
    let predecessorVisitor = TablePredecessorVisitor(for: g)
    var visitor = DFSVisitorChain(testRecorder, predecessorVisitor)
    var vertexVisitationState = TableVertexPropertyMap(repeating: VertexColor.white, for: g)
    try g.depthFirstSearchNoInit(vertexVisitationState: &vertexVisitationState, visitor: &visitor, start: v0)

    /// Ensure the RecorderVisiter recorded correctly.
    XCTAssertEqual([v0, v1, v2, v3, v4], visitor.head.discoveredVerticies)
    XCTAssertEqual([e0, e1, e2, e3, e4], visitor.head.examinedEdges)
    XCTAssertEqual([e0, e1, e2, e3], visitor.head.treeEdges)
    XCTAssertEqual([], visitor.head.backEdges)
    XCTAssertEqual([e4], visitor.head.forwardEdges)
    XCTAssertEqual([v2, v4, v3, v1, v0], visitor.head.finishedVerticies)

    XCTAssertEqual([nil, v0, v1, v1, v3], visitor.tail.predecessors)

  }

  static var allTests = [
    ("testSimple", testSimple),
    ("testEarlyStopping", testEarlyStopping),
    ("testBackEdge", testBackEdge),
    ("testForwardOrCrossEdge", testForwardOrCrossEdge),
    ("testPredecessorTrackingAndVisitorChaining", testPredecessorTrackingAndVisitorChaining),
  ]
}
