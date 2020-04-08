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

final class BreadthFirstSearchTests: XCTestCase {
	typealias Graph = AdjacencyList<Int>
	struct RecorderVisitor: BFSVisitor {
		var startVerticies = [Graph.VertexId]()
		var discoveredVerticies = [Graph.VertexId]()
		var popVertexCount = 0
		var examinedVerticies = [Graph.VertexId]()
		var examinedEdges = [Graph.EdgeId]()
		var treeEdges = [Graph.EdgeId]()
		var nonTreeEdges = [Graph.EdgeId]()
		var grayDestinationEdges = [Graph.EdgeId]()
		var blackDestinationEdges = [Graph.EdgeId]()
		var finishedVerticies = [Graph.VertexId]()

		mutating func start(vertex: Graph.VertexId, _ graph: inout Graph) {
			startVerticies.append(vertex)
		}

		mutating func discover(vertex: Graph.VertexId, _ graph: inout Graph) {
			discoveredVerticies.append(vertex)
		}

		mutating func popVertex() -> Graph.VertexId? {
			popVertexCount += 1
			return nil
		}

		mutating func examine(vertex: Graph.VertexId, _ graph: inout Graph) {
			examinedVerticies.append(vertex)
		}

		mutating func examine(edge: Graph.EdgeId, _ graph: inout Graph) {
			examinedEdges.append(edge)
		}

		mutating func treeEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) {
			treeEdges.append(edge)
		}

		mutating func nonTreeEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) {
			nonTreeEdges.append(edge)
		}

		mutating func grayDestination(_ edge: Graph.EdgeId, _ graph: inout Graph) {
			grayDestinationEdges.append(edge)
		}

		mutating func blackDestination(_ edge: Graph.EdgeId, _ graph: inout Graph) {
			blackDestinationEdges.append(edge)
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

		let recorder = RecorderVisitor()
		let bfs = BFSQueueVisitor<Graph>()
		var chain = BFSVisitorChain(recorder, bfs)
		var colorMap = TableVertexPropertyMap(repeating: VertexColor.white, for: g)

		try Graphs.breadthFirstSearchNoInit(&g, visitor: &chain, colorMap: &colorMap, startAt: [v0])
		XCTAssertEqual([v0], chain.head.startVerticies)
		XCTAssertEqual([v0, v1, v2, v3, v4], chain.head.discoveredVerticies)
		XCTAssertEqual(6, chain.head.popVertexCount)
		XCTAssertEqual([v0, v1, v2, v3, v4], chain.head.examinedVerticies)
		XCTAssertEqual([e0, e1, e2, e3], chain.head.examinedEdges)
		XCTAssertEqual([e0, e1, e2, e3], chain.head.treeEdges)
		XCTAssertEqual([], chain.head.nonTreeEdges)
		XCTAssertEqual([], chain.head.grayDestinationEdges)
		XCTAssertEqual([], chain.head.blackDestinationEdges)
		XCTAssertEqual([v0, v1, v2, v3, v4], chain.head.finishedVerticies)
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
		let bfs = BFSQueueVisitor<Graph>()
		var chain = BFSVisitorChain(BFSVisitorChain(recorder, predecessors), bfs)
		var colorMap = TableVertexPropertyMap(repeating: VertexColor.white, for: g)

		try Graphs.breadthFirstSearchNoInit(&g, visitor: &chain, colorMap: &colorMap, startAt: [v0])

		recorder = chain.head.head
		predecessors = chain.head.tail

		XCTAssertEqual([v0], recorder.startVerticies)
		XCTAssertEqual([v0, v1, v2, v3, v4], recorder.discoveredVerticies)
		XCTAssertEqual(6, recorder.popVertexCount)
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
