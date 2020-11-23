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
  typealias SimpleGraph = SimpleAdjacencyList

  for size in [10, 100, 1000] {
    suite.benchmark("build a complete graph of size \(size)") {
      var g = SimpleGraph()
      for i in 0..<size {
        _ = g.addVertex()
      }

      for i in 0..<size {
        for j in 0..<size {
          if i == j { continue }
          _ = g.addEdge(from: i, to: j)
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
    _ = oneEdge.addEdge(from: i, to: dest)
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
      _ = twoEdges.addEdge(from: i, to: dest)
    }
  }

  var completeGraph = SimpleGraph()
  for i in 0..<graphSize {
    _ = completeGraph.addVertex()
  }

  for i in 0..<graphSize {
    for j in 0..<graphSize {
      if i == j { continue }  // No self-edges.
      _ = completeGraph.addEdge(from: i, to: j)
    }
  }

  suite.benchmark("DFS on oneEdge graph, counting visitor") {
    var counter = Counter<SimpleGraph>()
    oneEdge.depthFirstTraversal { event, _ in
      counter.observe(event)
    }
  }

  suite.benchmark("BFS on oneEdge graph, counting visitor") {
    var counter = Counter<SimpleGraph>()
    oneEdge.breadthFirstSearch(startingAt: [0]) { event, _ in
      counter.observe(event)
    }
  }

  suite.benchmark("Dijkstra on oneEdge graph, counting visitor") {
    var counter = Counter<SimpleGraph>()
    let edgeLengths = ConstantEdgeProperty<SimpleGraph, Float>(value: 1.0)
    _ = oneEdge.dijkstraSearch(startingAt: 0, edgeLengths: edgeLengths) { event, _ in
      counter.observe(event)
    }
  }

  suite.benchmark("DFS on twoEdges graph, counting visitor") {
    var counter = Counter<SimpleGraph>()
    twoEdges.depthFirstTraversal { event, _ in
      counter.observe(event)
    }
  }

  suite.benchmark("BFS on twoEdges graph, counting visitor") {
    var counter = Counter<SimpleGraph>()
    twoEdges.breadthFirstSearch(startingAt: [0]) { event, _ in
      counter.observe(event)
    }
  }

  suite.benchmark("Dijkstra on twoEdges graph, counting visitor") {
    var counter = Counter<SimpleGraph>()
    let edgeLengths = ConstantEdgeProperty<SimpleGraph, Float>(value: 1.0)
    _ = twoEdges.dijkstraSearch(startingAt: 0, edgeLengths: edgeLengths) { event, _ in
      counter.observe(event)
    }
  }

  suite.benchmark("DFS on completeGraph graph, counting visitor") {
    var counter = Counter<SimpleGraph>()
    completeGraph.depthFirstTraversal { event, _ in
      counter.observe(event)
    }
  }

  suite.benchmark("BFS on completeGraph graph, counting visitor") {
    var counter = Counter<SimpleGraph>()
    completeGraph.breadthFirstSearch(startingAt: [0]) { event, _ in
      counter.observe(event)
    }
  }

  suite.benchmark("Dijkstra on completeGraph graph, counting visitor") {
    var counter = Counter<SimpleGraph>()
    let edgeLengths = ConstantEdgeProperty<SimpleGraph, Float>(value: 1.0)
    _ = completeGraph.dijkstraSearch(startingAt: 0, edgeLengths: edgeLengths) { event, _ in
      counter.observe(event)
    }
  }

  var completeDAG = SimpleGraph()
  for i in 0..<graphSize {
    _ = completeDAG.addVertex()
  }
  for i in 0..<graphSize {
    for j in (i+1)..<graphSize {
      _ = completeDAG.addEdge(from: i, to: j)
    }
  }

  suite.benchmark("DFS on completeDAG graph, counting visitor") {
    var counter = Counter<SimpleGraph>()
    completeDAG.depthFirstTraversal { event, _ in
      counter.observe(event)
    }
  }

  suite.benchmark("BFS on completeDAG graph, counting visitor") {
    var counter = Counter<SimpleGraph>()
    completeDAG.breadthFirstSearch(startingAt: [0]) { event, _ in
      counter.observe(event)
    }
  }

  suite.benchmark("Dijkstra on completeDAG graph, counting visitor") {
    var counter = Counter<SimpleGraph>()
    let edgeLengths = ConstantEdgeProperty<SimpleGraph, Float>(value: 1.0)
    _ = completeDAG.dijkstraSearch(startingAt: 0, edgeLengths: edgeLengths) { event, _ in
      counter.observe(event)
    }
  }

  suite.benchmark("Topological sort on completeDAG") {
    _ = try! completeDAG.topologicalSort()
  }
}

fileprivate struct ConstantEdgeProperty<Graph: GraphProtocol, Value>: ExternalPropertyMap {
  typealias Key = Graph.EdgeId
  let value: Value
  subscript(key: Key) -> Value {
    get { value }
    set { fatalError() }
  }
}

fileprivate struct Counter<Graph: GraphProtocol> {
  var vertexCount = 0
  var edgeCount = 0

  mutating func observe(_ event: DFSEvent<Graph>) {
    if case .discover = event {
      vertexCount += 1
    } else if case .examine = event {
      edgeCount += 1
    }
  }

  mutating func observe(_ event: BFSEvent<Graph>) {
    if case .examineVertex = event {
      vertexCount += 1
    } else if case .examineEdge = event {
      edgeCount += 1
    }
  }

  mutating func observe(_ event: DijkstraSearchEvent<Graph>) {
    if case .examineVertex = event {
      vertexCount += 1
    } else if case .examineEdge = event {
      edgeCount += 1
    }
  }
}
