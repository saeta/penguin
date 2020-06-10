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

final class DijkstraSearchTests: XCTestCase {
  typealias Graph = SimpleAdjacencyList
  struct Recorder {
    typealias VertexId = DijkstraSearchTests.Graph.VertexId
    typealias EdgeId = DijkstraSearchTests.Graph.EdgeId

    var startVertices = [VertexId]()
    var discoveredVerticies = [VertexId]()
    var examinedVerticies = [VertexId]()
    var examinedEdges = [EdgeId]()
    var relaxedEdges = [EdgeId]()
    var notRelaxedEdges = [EdgeId]()
    var finishedVerticies = [VertexId]()

    mutating func consume(_ event: DijkstraSearchEvent<DijkstraSearchTests.Graph>) {
      switch event {
      case .start(let v): startVertices.append(v)
      case .discover(let v): discoveredVerticies.append(v)
      case .examineVertex(let v): examinedVerticies.append(v)
      case .examineEdge(let e): examinedEdges.append(e)
      case .edgeRelaxed(let e): relaxedEdges.append(e)
      case .edgeNotRelaxed(let e): notRelaxedEdges.append(e)
      case .finish(let v): finishedVerticies.append(v)
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
    let e0 = g.addEdge(from: v0, to: v1)  // 2
    let e1 = g.addEdge(from: v1, to: v2)  // 3
    let e2 = g.addEdge(from: v1, to: v3)  // 4
    let e3 = g.addEdge(from: v3, to: v4)  // 1

    let edgeWeights = DictionaryPropertyMap([e0: 2, e1: 3, e2: 4, e3: 1], forEdgesIn: g)
    var recorder = Recorder()

    let vertexDistances = g.dijkstraSearch(
      startingAt: v0,
      edgeLengths: edgeWeights
    ) { e, g in recorder.consume(e) }

    XCTAssertEqual([v0], recorder.startVertices)
    XCTAssertEqual([v0, v1, v2, v3, v4], recorder.discoveredVerticies)
    XCTAssertEqual([v0, v1, v2, v3, v4], recorder.examinedVerticies)
    XCTAssertEqual([e0, e1, e2, e3], recorder.examinedEdges)
    XCTAssertEqual([e0, e1, e2, e3], recorder.relaxedEdges)
    XCTAssertEqual([], recorder.notRelaxedEdges)
    XCTAssertEqual([v0, v1, v2, v3, v4], recorder.finishedVerticies)

    XCTAssertEqual(0, vertexDistances[v0])
    XCTAssertEqual(2, vertexDistances[v1])
    XCTAssertEqual(5, vertexDistances[v2])
    XCTAssertEqual(6, vertexDistances[v3])
    XCTAssertEqual(7, vertexDistances[v4])
  }

  func testMultiPath() throws {
    // v0 -> v1 -> v2       v5
    //  |     '-> v3 -> v4
    //   ---------^      ^
    //  '----------------'
    var g = Graph()
    let v0 = g.addVertex()
    let v1 = g.addVertex()
    let v2 = g.addVertex()
    let v3 = g.addVertex()
    let v4 = g.addVertex()
    let v5 = g.addVertex()  // Disconnected vertex!
    let e0 = g.addEdge(from: v0, to: v1)  // 2
    let e1 = g.addEdge(from: v1, to: v2)  // 3
    let e2 = g.addEdge(from: v1, to: v3)  // 4
    let e3 = g.addEdge(from: v3, to: v4)  // 1
    let e4 = g.addEdge(from: v0, to: v3)  // 10
    let e5 = g.addEdge(from: v0, to: v4)  // 3

    let edgeWeights = DictionaryPropertyMap(
      [e0: 2, e1: 3, e2: 4, e3: 1, e4: 10, e5: 3],
      forEdgesIn: g)
    var vertexDistanceMap = TablePropertyMap(repeating: Int.max, forVerticesIn: g)
    var vertexVisitationState = TablePropertyMap(repeating: VertexColor.white, forVerticesIn: g)
    var recorder = Recorder()
    var predecessors = TablePredecessorRecorder(for: g)

    g.dijkstraSearch(
      startingAt: v0,
      vertexVisitationState: &vertexVisitationState,
      distancesToVertex: &vertexDistanceMap,
      edgeLengths: edgeWeights,
      workList: [PriorityQueueElement<Int, UInt32>](),
      workListIndex: ArrayPriorityQueueIndexer(count: g.vertexCount),
      effectivelyInfinite: Int.max
    ) { e, g in
      recorder.consume(e)
      predecessors.record(e, graph: g)
    }

    XCTAssertEqual([v0], recorder.startVertices)
    XCTAssertEqual([v0, v1, v3, v4, v2], recorder.discoveredVerticies)
    XCTAssertEqual([v0, v1, v4, v2, v3], recorder.examinedVerticies)
    XCTAssertEqual([e0, e4, e5, e1, e2, e3], recorder.examinedEdges)
    XCTAssertEqual([e0, e4, e5, e1, e2], recorder.relaxedEdges)
    XCTAssertEqual([e3], recorder.notRelaxedEdges)
    XCTAssertEqual([v0, v1, v4, v2, v3], recorder.finishedVerticies)

    XCTAssertEqual(0, vertexDistanceMap[v0])
    XCTAssertEqual(2, vertexDistanceMap[v1])
    XCTAssertEqual(5, vertexDistanceMap[v2])
    XCTAssertEqual(6, vertexDistanceMap[v3])
    XCTAssertEqual(3, vertexDistanceMap[v4])
    XCTAssertEqual(Int.max, vertexDistanceMap[v5])

    XCTAssertEqual([nil, v0, v1, v1, v0, nil], predecessors.predecessors)
  }

  // TODO: Add test to ensure visitor / vertexDistanceMap is not copied.

  static var allTests = [
    ("testSimple", testSimple),
    ("testMultiPath", testMultiPath),
  ]
}
