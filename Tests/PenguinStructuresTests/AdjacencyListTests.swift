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

final class AdjacencyListTests: XCTestCase {
	func testMutatingOperations() {
		var g = AdjacencyList<Int32>()
		XCTAssertEqual(0, g.vertexCount)
		XCTAssertEqual(0, g.edgeCount)

		let v0 = g.addVertex()
		let v1 = g.addVertex()
		XCTAssertEqual(2, g.vertexCount)
		XCTAssertEqual(0, g.edgeCount)

		let e0 = g.addEdge(from: v0, to: v1)
		XCTAssertEqual(1, g.edgeCount)
		XCTAssertEqual(1, g.outDegree(of: v0))
		XCTAssertEqual(0, g.outDegree(of: v1))

		let e1 = g.addEdge(from: v1, to: v0)
		XCTAssertEqual(2, g.edgeCount)
		XCTAssertEqual(1, g.outDegree(of: v0))
		XCTAssertEqual(1, g.outDegree(of: v1))
		XCTAssertEqual(2, g.vertexCount)

		g.remove(e0)
		XCTAssertEqual(1, g.edgeCount)
		XCTAssertEqual(2, g.vertexCount)
		XCTAssertEqual(0, g.outDegree(of: v0))
		XCTAssertEqual(1, g.outDegree(of: v1))

		g.removeEdges(from: v1) { e in
			XCTAssertEqual(e, e1)
			return true
		}

		XCTAssertEqual(2, g.vertexCount)
		XCTAssertEqual(0, g.edgeCount)
		XCTAssertEqual(0, g.outDegree(of: v0))
		XCTAssertEqual(0, g.outDegree(of: v1))
	}

	func testParallelEdges() throws {
		var g = AdjacencyList<Int32>()

		let v0 = g.addVertex()
		let v1 = g.addVertex()

		let e0 = g.addEdge(from: v0, to: v1)
		let e1 = g.addEdge(from: v0, to: v1)
		XCTAssertEqual(g.edges().flatten(), [e0, e1])
		XCTAssertEqual(2, g.outDegree(of: v0))
		do {
			var edgeItr = g.edges(from: v0).makeIterator()
			XCTAssertEqual(e0, edgeItr.next())
			XCTAssertEqual(e1, edgeItr.next())
			XCTAssertEqual(nil, edgeItr.next())
		}

		g.remove(e0)  // Invalidates e1.
		XCTAssertEqual(1, g.outDegree(of: v0))
		XCTAssertEqual(1, g.edgeCount)
		let e1New = g.edges().flatten()[0]
		XCTAssertEqual(v0, g.source(of: e1New))
		XCTAssertEqual(v1, g.destination(of: e1New))

		let e2 = g.addEdge(from: v1, to: v0)
		let e3 = g.addEdge(from: v1, to: v0)
		XCTAssertEqual(g.edges().flatten(), [e1New, e2, e3])

		try g.removeEdge(from: v1, to: v0)  // Invalidates e2 & e3
		XCTAssertEqual(g.edges().flatten(), [e1New])

		g.clear(vertex: v0)
		XCTAssertEqual(g.edgeCount, 0)
	}

	static var allTests = [
		("testMutatingOperations", testMutatingOperations),
		("testParallelEdges", testParallelEdges),
	]
}
