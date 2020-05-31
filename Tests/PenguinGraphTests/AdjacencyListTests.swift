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

struct TestError: Error {}

final class AdjacencyListTests: XCTestCase {

  // MARK: - DirectedAdjacencyList tests

  typealias SimpleGraph = SimpleAdjacencyList
  typealias PropertyGraph = DirectedAdjacencyList<Vertex, Edge, Int32>

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

  func testDirectedMutatingOperations() {
    var g = SimpleGraph()
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

  func testDirectedParallelEdges() throws {
    var g = SimpleGraph()

    let v0 = g.addVertex()
    let v1 = g.addVertex()

    let e0 = g.addEdge(from: v0, to: v1)
    let e1 = g.addEdge(from: v0, to: v1)
    XCTAssertEqual(Array(g.edges), [e0, e1])
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
    let e1New = Array(g.edges)[0]
    XCTAssertEqual(v0, g.source(of: e1New))
    XCTAssertEqual(v1, g.destination(of: e1New))

    let e2 = g.addEdge(from: v1, to: v0)
    let e3 = g.addEdge(from: v1, to: v0)
    XCTAssertEqual(Array(g.edges), [e1New, e2, e3])

    XCTAssert(g.removeEdge(from: v1, to: v0))  // Invalidates e2 & e3
    XCTAssertEqual(Array(g.edges), [e1New])

    g.clear(vertex: v0)
    XCTAssertEqual(g.edgeCount, 0)
  }

  func testDirectedPropertyMapOperations() {
    var g = makePropertyGraph()
    let vertices = g.vertices
    XCTAssertEqual(3, vertices.count)
    XCTAssertEqual("", g[vertex: vertices[0]].name)
    XCTAssertEqual("Alice", g[vertex: vertices[1]].name)
    XCTAssertEqual("Bob", g[vertex: vertices[2]].name)

    let edgeIds = Array(g.edges)
    XCTAssertEqual(4, edgeIds.count)
    let expectedWeights = [0.5, 0.5, 1, 1]
    XCTAssertEqual(expectedWeights, edgeIds.map { g[edge: $0].weight })

    let tmp = g  // make a copy to avoid overlapping accesses to `g` below.
    g.removeEdges { tmp.source(of: $0) == vertices[0] }
    XCTAssertEqual(2, g.edges.count)

    g.edges.forEach { edgeId in
      XCTAssertNotEqual(vertices[0], g.source(of: edgeId))
      XCTAssertNotEqual(vertices[0], g.destination(of: edgeId))
      XCTAssertEqual(1.0, g[edge: edgeId].weight)
    }

    g.removeEdges { _ in true }
    XCTAssertEqual(0, g.edgeCount)
  }

  func testRemovingMultipleEdges() {
    var g = makePropertyGraph()
    XCTAssertEqual(4, g.edgeCount)
    let source = g.vertices[0]
    let tmp = g
    g.removeEdges { edgeId in
      tmp.source(of: edgeId) == source
    }
    XCTAssertEqual(2, g.edgeCount)
  }

  func testThrowingVertexParallel() throws {
    var g = makePropertyGraph()
    let vertices = g.vertices
    XCTAssertEqual(3, vertices.count)
    XCTAssertEqual("", g[vertex: vertices[0]].name)
    XCTAssertEqual("Alice", g[vertex: vertices[1]].name)
    XCTAssertEqual("Bob", g[vertex: vertices[2]].name)

    do {
      var tmpMailboxes = SequentialMailboxes(for: g, sending: Empty.self)
      _ = try g.parallelStep(mailboxes: &tmpMailboxes, globalState: Empty()) {
        (ctx, v) in
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

  // MARK: - BidirectionalAdjacencyList tests

  func testBidirectionalMutatingOperations() {
    var g = BidirectionalAdjacencyList<Empty, Empty, UInt32>()
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
    XCTAssertEqual(1, g.inDegree(of: v1))
    XCTAssertEqual(0, g.inDegree(of: v0))
    XCTAssertEqual(1, g.degree(of: v0))
    XCTAssertEqual(1, g.degree(of: v1))

    let e1 = g.addEdge(from: v1, to: v0)
    XCTAssertEqual(2, g.edgeCount)
    XCTAssertEqual(1, g.outDegree(of: v0))
    XCTAssertEqual(1, g.outDegree(of: v1))
    XCTAssertEqual(2, g.vertexCount)
    XCTAssertEqual(1, g.inDegree(of: v1))
    XCTAssertEqual(1, g.inDegree(of: v0))
    XCTAssertEqual(2, g.degree(of: v0))
    XCTAssertEqual(2, g.degree(of: v1))

    XCTAssertEqual([e1], g.edges(to: v0))
    XCTAssertEqual([e0], g.edges(to: v1))

    // TODO: Test mutation operations!
  }

  func testBidirectionalParallelEdges() throws {
    // TODO: Test mutation operations
    var g = BidirectionalAdjacencyList<Empty, Empty, UInt32>()

    let v0 = g.addVertex()
    let v1 = g.addVertex()

    let e0 = g.addEdge(from: v0, to: v1)
    let e1 = g.addEdge(from: v0, to: v1)
    XCTAssertEqual(Array(g.edges), [e0, e1])
    XCTAssertEqual(2, g.outDegree(of: v0))
    XCTAssertEqual(2, g.inDegree(of: v1))
    XCTAssertEqual(2, g.degree(of: v0))
    XCTAssertEqual(2, g.degree(of: v1))
    XCTAssertEqual([e0, e1], Array(g.edges(from: v0)))
    XCTAssertEqual([e0, e1], Array(g.edges(to: v1)))

    // TODO: remove one parallel edge & ensure state is updated as appropriate.
    let e2 = g.addEdge(from: v1, to: v0)
    let e3 = g.addEdge(from: v1, to: v0)
    XCTAssertEqual(Array(g.edges), [e0, e1, e2, e3])

    // TODO: remove all edges from v1 to v0 and ensure everything works appropriately.
  }

  func testBidirectionalPropertyMapOperations() {
    var g = BidirectionalAdjacencyList<Vertex, Edge, UInt32>()
    // Add vertices
    _ = g.addVertex()  // Default init.
    _ = g.addVertex(storing: Vertex(name: "Alice"))
    _ = g.addVertex(storing: Vertex(name: "Bob"))

    // Add edges
    _ = g.addEdge(from: 1, to: 2, storing: Edge(weight: 1))
    _ = g.addEdge(from: 2, to: 1, storing: Edge(weight: 1))
    _ = g.addEdge(from: 0, to: 1, storing: Edge(weight: 0.5))
    _ = g.addEdge(from: 0, to: 2, storing: Edge(weight: 0.25))

    XCTAssertEqual(3, g.vertices.count)
    XCTAssertEqual("", g[vertex: 0].name)
    XCTAssertEqual("Alice", g[vertex: 1].name)
    XCTAssertEqual("Bob", g[vertex: 2].name)

    let edgeIds = Array(g.edges)
    XCTAssertEqual(4, edgeIds.count)
    let expectedWeights = [0.5, 0.25, 1, 1]
    XCTAssertEqual(expectedWeights, edgeIds.map { g[edge: $0].weight })

    XCTAssertEqual([1, 0.5], g.edges(to: 1).map { g[edge: $0].weight })
    XCTAssertEqual([1, 0.25], g.edges(to: 2).map { g[edge: $0].weight })
  }

  // MARK: - UndirectedAdjacencyList tests

  func testUndirectedMutatingOperations() {
    var g = UndirectedAdjacencyList<Empty, Empty, UInt32>()
    XCTAssertEqual(0, g.vertexCount)
    XCTAssertEqual(0, g.edgeCount)

    let v0 = g.addVertex()
    let v1 = g.addVertex()
    XCTAssertEqual(2, g.vertexCount)
    XCTAssertEqual(0, g.edgeCount)

    let e0 = g.addEdge(from: v0, to: v1)
    XCTAssertEqual(1, g.edgeCount)
    XCTAssertEqual(1, g.outDegree(of: v0))
    XCTAssertEqual(1, g.outDegree(of: v1))
    XCTAssertEqual(Array(g.edges(from: v0)), Array(g.edges(from: v1)))

    let e1 = g.addEdge(from: v1, to: v0)
    XCTAssertEqual(2, g.edgeCount)
    XCTAssertEqual(2, g.outDegree(of: v0))
    XCTAssertEqual(2, g.outDegree(of: v1))
    XCTAssertEqual(2, g.vertexCount)
    XCTAssertEqual([e0, e1], Array(g.edges(from: v0)))
    XCTAssertEqual([e1, e0], Array(g.edges(from: v1)))
    // TODO: Test mutation operations!
  }

  func testUndirectedParallelEdges() throws {
    // TODO: Test mutation operations
    var g = UndirectedAdjacencyList<Empty, Empty, UInt32>()

    let v0 = g.addVertex()
    let v1 = g.addVertex()

    let e0 = g.addEdge(from: v0, to: v1)
    let e1 = g.addEdge(from: v0, to: v1)
    XCTAssertEqual(Array(g.edges), [e0, e1])
    XCTAssertEqual(2, g.outDegree(of: v0))
    XCTAssertEqual(2, g.outDegree(of: v1))
    XCTAssertEqual([e0, e1], Array(g.edges(from: v0)))
    XCTAssertEqual([e0, e1], Array(g.edges(from: v1)))

    // TODO: remove one parallel edge & ensure state is updated as appropriate.
    let e2 = g.addEdge(from: v1, to: v0)
    let e3 = g.addEdge(from: v1, to: v0)
    XCTAssertEqual(Array(g.edges), [e0, e1, e2, e3])

    // TODO: remove all edges from v1 to v0 and ensure everything works appropriately.
  }

  func testUndirectedPropertyMapOperations() {
    var g = UndirectedAdjacencyList<Vertex, Edge, UInt32>()
    // Add vertices
    _ = g.addVertex()  // Default init.
    _ = g.addVertex(storing: Vertex(name: "Alice"))
    _ = g.addVertex(storing: Vertex(name: "Bob"))

    // Add edges
    _ = g.addEdge(from: 1, to: 2, storing: Edge(weight: 1))
    _ = g.addEdge(from: 2, to: 1, storing: Edge(weight: 1))
    _ = g.addEdge(from: 0, to: 1, storing: Edge(weight: 0.5))
    _ = g.addEdge(from: 0, to: 2, storing: Edge(weight: 0.25))

    XCTAssertEqual(3, g.vertices.count)
    XCTAssertEqual("", g[vertex: 0].name)
    XCTAssertEqual("Alice", g[vertex: 1].name)
    XCTAssertEqual("Bob", g[vertex: 2].name)

    let edgeIds = Array(g.edges)
    XCTAssertEqual(4, edgeIds.count)
    let expectedWeights = [0.5, 0.25, 1, 1]
    XCTAssertEqual(expectedWeights, edgeIds.map { g[edge: $0].weight })

    XCTAssertEqual([0.5, 0.25], g.edges(from: 0).map { g[edge: $0].weight })
    XCTAssertEqual([1, 1, 0.5], g.edges(from: 1).map { g[edge: $0].weight })
    XCTAssertEqual([1, 1, 0.25], g.edges(from: 2).map { g[edge: $0].weight })
  }

  func testUndirectedEdgeEquality() {
    var g = UndirectedAdjacencyList<Empty, Empty, UInt32>()

    _ = g.addVertex()
    _ = g.addVertex()

    _ = g.addEdge(from: 0, to: 1)

    XCTAssertEqual(Array(g.edges(from: 0)), Array(g.edges(from: 1)))
    XCTAssertEqual(0, g.source(of: g.edges(from: 0)[0]))
    XCTAssertEqual(1, g.destination(of: g.edges(from: 0)[0]))
    XCTAssertEqual(1, g.source(of: g.edges(from: 1)[0]), "\(g.edges(from: 1)[0])")
    XCTAssertEqual(0, g.destination(of: g.edges(from: 1)[0]))
  }

  static var allTests = [
    ("testDirectedMutatingOperations", testDirectedMutatingOperations),
    ("testDirectedParallelEdges", testDirectedParallelEdges),
    ("testDirectedPropertyMapOperations", testDirectedPropertyMapOperations),
    ("testRemovingMultipleEdges", testRemovingMultipleEdges),
    ("testThrowingVertexParallel", testThrowingVertexParallel),
    ("testBidirectionalMutatingOperations", testBidirectionalMutatingOperations),
    ("testBidirectionalParallelEdges", testBidirectionalParallelEdges),
    ("testBidirectionalPropertyMapOperations", testBidirectionalPropertyMapOperations),
    ("testUndirectedMutatingOperations", testUndirectedMutatingOperations),
    ("testUndirectedParallelEdges", testUndirectedParallelEdges),
    ("testUndirectedPropertyMapOperations", testUndirectedPropertyMapOperations),
    ("testUndirectedEdgeEquality", testUndirectedEdgeEquality),
  ]
}

extension AdjacencyListTests {
  func makePropertyGraph() -> PropertyGraph {
    var g = PropertyGraph()

    let v0 = g.addVertex()  // Default init.
    let v1 = g.addVertex(storing: Vertex(name: "Alice"))
    let v2 = g.addVertex(storing: Vertex(name: "Bob"))

    _ = g.addEdge(from: v1, to: v2, storing: Edge(weight: 1))
    _ = g.addEdge(from: v2, to: v1, storing: Edge(weight: 1))

    _ = g.addEdge(from: v0, to: v1, storing: Edge(weight: 0.5))
    _ = g.addEdge(from: v0, to: v2, storing: Edge(weight: 0.5))
    return g
  }
}
