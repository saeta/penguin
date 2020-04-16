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

final class PropertyAdjacencyListTests: XCTestCase {
	typealias Graph = PropertyAdjacencyList<Vertex, Edge, Int32>

	struct Vertex: DefaultInitializable, Equatable {
		var name: String

		init(name: String) {
			self.name = name
		}

		init() {
			self.name = ""
		}
	}

	struct Edge: DefaultInitializable, Equatable {
		var weight: Double

		init() {
			weight = 0.0
		}

		init(weight: Double) {
			self.weight = weight
		}
	}

	func makeSimpleGraph() -> Graph {
		var g = Graph()

		let v0 = g.addVertex()  // Default init.
		let v1 = g.addVertex(with: Vertex(name: "Alice"))
		let v2 = g.addVertex(with: Vertex(name: "Bob"))

		_ = g.addEdge(from: v1, to: v2, with: Edge(weight: 1))
		_ = g.addEdge(from: v2, to: v1, with: Edge(weight: 1))

		_ = g.addEdge(from: v0, to: v1, with: Edge(weight: 0.5))
		_ = g.addEdge(from: v0, to: v2, with: Edge(weight: 0.5))
		return g
	}

	func testMutatingOperations() {
		var g = Graph()
		XCTAssertEqual(0, g.vertexCount)
		XCTAssertEqual(0, g.edgeCount)

		let v0 = g.addVertex()
		let v1 = g.addVertex()
		XCTAssertEqual(2, g.vertexCount)
		XCTAssertEqual(0, g.edgeCount)

		let e0 = g.addEdge(from: v0, to: v1)
		XCTAssertEqual(1, g.edgeCount)
		let e1 = g.addEdge(from: v1, to: v0)
		XCTAssertEqual(2, g.edgeCount)
		XCTAssertEqual(2, g.vertexCount)

		XCTAssertEqual([e0], Array(g.edges(from: v0)))
		XCTAssertEqual([e1], Array(g.edges(from: v1)))
		XCTAssertEqual(1, g.outDegree(of: v0))
		XCTAssertEqual(1, g.outDegree(of: v1))

		g.remove(edge: e0)
		XCTAssertEqual(1, g.edgeCount)
		XCTAssertEqual(2, g.vertexCount)

		g.removeEdges(from: v1) { e in
			XCTAssertEqual(e, e1)
			return true
		}

		XCTAssertEqual(2, g.vertexCount)
		XCTAssertEqual(0, g.edgeCount)
	}

	func testPropertyMapOperations() {
		var g = makeSimpleGraph()
		let vertices = g.vertices().flatten()
		XCTAssertEqual(3, vertices.count)
		XCTAssertEqual("", g[vertex: vertices[0]].name)
		XCTAssertEqual("Alice", g[vertex: vertices[1]].name)
		XCTAssertEqual("Bob", g[vertex: vertices[2]].name)

		let edgeIds = g.edges().flatten()
		XCTAssertEqual(4, edgeIds.count)
		let expectedWeights = [0.5, 0.5, 1, 1]
		XCTAssertEqual(expectedWeights, edgeIds.map { g[edge: $0].weight })

		let tmp = g  // make a copy to avoid overlapping accesses to `g` below.
		g.removeEdges { tmp.source(of: $0) == vertices[0] }
		XCTAssertEqual(2, g.edges().flatten().count)

		g.edges().forEach { edgeId in
			XCTAssertNotEqual(vertices[0], g.source(of: edgeId))
			XCTAssertNotEqual(vertices[0], g.destination(of: edgeId))
			XCTAssertEqual(1.0, g[edge: edgeId].weight)
		}

		g.removeEdges { _ in true }
		XCTAssertEqual(0, g.edgeCount)
	}

	func testRemovingMultipleEdges() {
		var g = makeSimpleGraph()
		XCTAssertEqual(4, g.edgeCount)
		let source = g.vertices().flatten()[0]
		let tmp = g
		g.removeEdges { edgeId in
			tmp.source(of: edgeId) == source
		}
		XCTAssertEqual(2, g.edgeCount)
	}

	func testThrowingVertexParallel() throws {
		var g = makeSimpleGraph()
		let vertices = g.vertices().flatten()
		XCTAssertEqual(3, vertices.count)
		XCTAssertEqual("", g[vertex: vertices[0]].name)
		XCTAssertEqual("Alice", g[vertex: vertices[1]].name)
		XCTAssertEqual("Bob", g[vertex: vertices[2]].name)

		do {
			var tmpMailboxes = SequentialMailboxes(for: g, sending: EmptyMergeableMessage.self)
			_ = try g.parallelStep(mailboxes: &tmpMailboxes, globalState: EmptyMergeableMessage()) { (ctx, v) in
				if v.name == "" { throw TestError() }
				return nil
			}
			XCTFail("Should have thrown an error!")
		} catch is TestError {}  // Expected error.
		// Vertex properties should still be there & accessible.
		XCTAssertEqual(3, vertices.count)
		XCTAssertEqual("", g[vertex: vertices[0]].name)
		XCTAssertEqual("Alice", g[vertex: vertices[1]].name)
		XCTAssertEqual("Bob", g[vertex: vertices[2]].name)
	}

	static var allTests = [
		("testMutatingOperations", testMutatingOperations),
		("testPropertyMapOperations", testPropertyMapOperations),
		("testRemovingMultipleEdges", testRemovingMultipleEdges),
		("testThrowingVertexParallel", testThrowingVertexParallel),
	]
}
