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

import Benchmark
import PenguinGraphs

let adjacencyList = BenchmarkSuite(name: "AdjacencyList") { suite in
  typealias SimpleGraph = SimpleAdjacencyList<Int32>

  for size in [10, 100, 1000] {
    suite.benchmark("build a complete graph of size \(size)") {
      var g = SimpleGraph()
      for i in 0..<size {
        _ = g.addVertex()
      }

      for i in 0..<size {
        for j in 0..<size {
          if i == j { continue }
          _ = g.addEdge(from: Int32(i), to: Int32(j))
        }
      }
    }
  }

  // A graph with 1 edge coming out of each vertex, with very long cycles.
  let graphSize = 1000
  var oneEdge = SimpleGraph()
  for i in 0..<graphSize {
    _ = oneEdge.addVertex()
  }
  for i in 0..<graphSize {
    var dest = i + 1
    if dest == graphSize {
      dest = 0
    }
    _ = oneEdge.addEdge(from: Int32(i), to: Int32(dest))
  }

  var twoEdges = SimpleGraph()
  for i in 0..<graphSize {
    _ = twoEdges.addVertex()
  }
  for i in 0..<graphSize {
    for j in 1...2 {
      var dest = i + j
      if dest >= graphSize {
        dest -= graphSize
      }
      _ = twoEdges.addEdge(from: Int32(i), to: Int32(dest))
    }
  }

  var completeGraph = SimpleGraph()
  for i in 0..<graphSize {
    _ = completeGraph.addVertex()
  }

  for i in 0..<graphSize {
    for j in 0..<graphSize {
      if i == j { continue }  // No self-edges.
      _ = completeGraph.addEdge(from: Int32(i), to: Int32(j))
    }
  }

  suite.benchmark("DFS on oneEdge graph, counting visitor") {
    var visitor = CountingVisitor<SimpleGraph>()
    try! oneEdge.depthFirstTraversal(visitor: &visitor)
  }

  suite.benchmark("BFS on oneEdge graph, counting visitor") {
    var chain = BFSVisitorChain(CountingVisitor<SimpleGraph>(), BFSQueueVisitor<SimpleGraph>())
    try! oneEdge.breadthFirstSearch(startingAt: [0], visitor: &chain)
  }

  suite.benchmark("Dijkstra on oneEdge graph, counting visitor") {
    let edgeLengths = ConstantEdgeProperty<SimpleGraph, Float>(value: 1.0)
    var visitor = CountingVisitor<SimpleGraph>()
    _ = try! oneEdge.dijkstraSearch(startingAt: 0, visitor: &visitor, edgeLengths: edgeLengths)
  }

  suite.benchmark("DFS on twoEdges graph, counting visitor") {
    var visitor = CountingVisitor<SimpleGraph>()
    try! twoEdges.depthFirstTraversal(visitor: &visitor)
  }

  suite.benchmark("BFS on twoEdges graph, counting visitor") {
    var chain = BFSVisitorChain(CountingVisitor<SimpleGraph>(), BFSQueueVisitor<SimpleGraph>())
    try! twoEdges.breadthFirstSearch(startingAt: [0], visitor: &chain)
  }

  suite.benchmark("Dijkstra on twoEdges graph, counting visitor") {
    let edgeLengths = ConstantEdgeProperty<SimpleGraph, Float>(value: 1.0)
    var visitor = CountingVisitor<SimpleGraph>()
    _ = try! twoEdges.dijkstraSearch(startingAt: 0, visitor: &visitor, edgeLengths: edgeLengths)
  }

  suite.benchmark("DFS on completeGraph graph, counting visitor") {
    var visitor = CountingVisitor<SimpleGraph>()
    try! completeGraph.depthFirstTraversal(visitor: &visitor)
  }

  suite.benchmark("BFS on completeGraph graph, counting visitor") {
    var chain = BFSVisitorChain(CountingVisitor<SimpleGraph>(), BFSQueueVisitor<SimpleGraph>())
    try! completeGraph.breadthFirstSearch(startingAt: [0], visitor: &chain)
  }

  suite.benchmark("Dijkstra on completeGraph graph, counting visitor") {
    let edgeLengths = ConstantEdgeProperty<SimpleGraph, Float>(value: 1.0)
    var visitor = CountingVisitor<SimpleGraph>()
    _ = try! completeGraph.dijkstraSearch(startingAt: 0, visitor: &visitor, edgeLengths: edgeLengths)
  }

  var completeDAG = SimpleGraph()
  for i in 0..<graphSize {
    _ = completeDAG.addVertex()
  }
  for i in 0..<graphSize {
    for j in (i+1)..<graphSize {
      _ = completeDAG.addEdge(from: Int32(i), to: Int32(j))
    }
  }

  suite.benchmark("DFS on completeDAG graph, counting visitor") {
    var visitor = CountingVisitor<SimpleGraph>()
    try! completeDAG.depthFirstTraversal(visitor: &visitor)
  }

  suite.benchmark("BFS on completeDAG graph, counting visitor") {
    var chain = BFSVisitorChain(CountingVisitor<SimpleGraph>(), BFSQueueVisitor<SimpleGraph>())
    try! completeDAG.breadthFirstSearch(startingAt: [0], visitor: &chain)
  }

  suite.benchmark("Dijkstra on completeDAG graph, counting visitor") {
    let edgeLengths = ConstantEdgeProperty<SimpleGraph, Float>(value: 1.0)
    var visitor = CountingVisitor<SimpleGraph>()
    _ = try! completeDAG.dijkstraSearch(startingAt: 0, visitor: &visitor, edgeLengths: edgeLengths)
  }

  suite.benchmark("Topological sort on completeDAG") {
    _ = try! completeDAG.topologicalSort()
  }
}

fileprivate struct CountingVisitor<Graph: GraphProtocol>: GraphVisitor, DFSVisitor, BFSVisitor, DijkstraVisitor {
  var vertexCount: Int = 0
  var edgeCount: Int = 0
  mutating func examine(vertex: Graph.VertexId, _ graph: inout Graph) {
    vertexCount += 1
  }
  mutating func examine(edge: Graph.EdgeId, _ graph: inout Graph) {
    edgeCount += 1
  }
}

fileprivate struct ConstantEdgeProperty<Graph: GraphProtocol, Value>: GraphEdgePropertyMap {
  let value: Value
  func get(_ g: Graph, _ edge: Graph.EdgeId) -> Value { value }
}
