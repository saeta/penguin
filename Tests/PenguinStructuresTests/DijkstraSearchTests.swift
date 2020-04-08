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
import PenguinStructures

final class DijkstraSearchTests: XCTestCase {
	typealias Graph = AdjacencyList<Int>
	struct Recorder: DijkstraVisitor {
		var discoveredVerticies = [Graph.VertexId]()
		var examinedVerticies = [Graph.VertexId]()
		var examinedEdges = [Graph.EdgeId]()
		var relaxedEdges = [Graph.EdgeId]()
		var notRelaxedEdges = [Graph.EdgeId]()
		var finishedVerticies = [Graph.VertexId]()

		/// Called upon first discovering `vertex` in the graph.
		mutating func discover(vertex: Graph.VertexId, _ graph: inout Graph) {
			discoveredVerticies.append(vertex)
		}

		/// Called when `vertex` is at the front of the priority queue and is examined.
		mutating func examine(vertex: Graph.VertexId, _ graph: inout Graph) {
			examinedVerticies.append(vertex)
		}

		/// Called for each edge associated when examining a vertex.
		mutating func examine(edge: Graph.EdgeId, _ graph: inout Graph) {
			examinedEdges.append(edge)
		}

		/// Called for each edge that results in a shorter path to its destination vertex.
		mutating func edgeRelaxed(_ edge: Graph.EdgeId, _ graph: inout Graph) {
			relaxedEdges.append(edge)
		}

		/// Called for each edge that does not result in a shorter path to its destination vertex.
		mutating func edgeNotRelaxed(_ edge: Graph.EdgeId, _ graph: inout Graph) {
			notRelaxedEdges.append(edge)
		}

		/// Called once for each vertex right after it is colored black.
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
		let e0 = g.addEdge(from: v0, to: v1)  // 2
		let e1 = g.addEdge(from: v1, to: v2)  // 3
		let e2 = g.addEdge(from: v1, to: v3)  // 4
		let e3 = g.addEdge(from: v3, to: v4)  // 1

		let edgeWeights = DictionaryEdgePropertyMap([e0: 2, e1: 3, e2: 4, e3: 1], for: g)
		var vertexDistanceMap = TableVertexPropertyMap(repeating: Int.max, for: g)
		var colorMap = TableVertexPropertyMap(repeating: VertexColor.white, for: g)
		var recorder = Recorder()

		try Graphs.dijkstraSearchNoInit(
			&g,
			visitor: &recorder,
			colorMap: &colorMap,
			vertexDistanceMap: &vertexDistanceMap,
			edgeWeightMap: edgeWeights,
			startAt: v0
		)

		XCTAssertEqual([v0, v1, v2, v3, v4], recorder.discoveredVerticies)
		XCTAssertEqual([v0, v1, v2, v3, v4], recorder.examinedVerticies)
		XCTAssertEqual([e0, e1, e2, e3], recorder.examinedEdges)
		XCTAssertEqual([e0, e1, e2, e3], recorder.relaxedEdges)
		XCTAssertEqual([], recorder.notRelaxedEdges)
		XCTAssertEqual([v0, v1, v2, v3, v4], recorder.finishedVerticies)

		XCTAssertEqual(0, vertexDistanceMap.get(g, v0))
		XCTAssertEqual(2, vertexDistanceMap.get(g, v1))
		XCTAssertEqual(5, vertexDistanceMap.get(g, v2))
		XCTAssertEqual(6, vertexDistanceMap.get(g, v3))
		XCTAssertEqual(7, vertexDistanceMap.get(g, v4))
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

		let edgeWeights = DictionaryEdgePropertyMap(
			[e0: 2, e1: 3, e2: 4, e3: 1, e4: 10, e5: 3],
			for: g)
		var vertexDistanceMap = TableVertexPropertyMap(repeating: Int.max, for: g)
		var colorMap = TableVertexPropertyMap(repeating: VertexColor.white, for: g)
		var recorder = Recorder()
		var predecessors = TablePredecessorVisitor(for: g)
		var visitor = DijkstraVisitorChain(recorder, predecessors)

		try Graphs.dijkstraSearchNoInit(
			&g,
			visitor: &visitor,
			colorMap: &colorMap,
			vertexDistanceMap: &vertexDistanceMap,
			edgeWeightMap: edgeWeights,
			startAt: v0
		)
		recorder = visitor.head
		predecessors = visitor.tail

		XCTAssertEqual([v0, v1, v3, v4, v2], recorder.discoveredVerticies)
		XCTAssertEqual([v0, v1, v4, v2, v3], recorder.examinedVerticies)
		XCTAssertEqual([e0, e4, e5, e1, e2, e3], recorder.examinedEdges)
		XCTAssertEqual([e0, e4, e5, e1, e2], recorder.relaxedEdges)
		XCTAssertEqual([e3], recorder.notRelaxedEdges)
		XCTAssertEqual([v0, v1, v4, v2, v3], recorder.finishedVerticies)

		XCTAssertEqual(0, vertexDistanceMap.get(g, v0))
		XCTAssertEqual(2, vertexDistanceMap.get(g, v1))
		XCTAssertEqual(5, vertexDistanceMap.get(g, v2))
		XCTAssertEqual(6, vertexDistanceMap.get(g, v3))
		XCTAssertEqual(3, vertexDistanceMap.get(g, v4))
		XCTAssertEqual(Int.max, vertexDistanceMap.get(g, v5))

		XCTAssertEqual([nil, v0, v1, v1, v0, nil], predecessors.predecessors)
	}

	// TODO: Add test to ensure visitor / vertexDistanceMap is not copied.

	static var allTests = [
		("testSimple", testSimple),
		("testMultiPath", testMultiPath),
	]
}
