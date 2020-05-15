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
    var vertexCount = 0
    var edgeCount = 0
    oneEdge.depthFirstTraversal { e, g in
      if case let .discover(vertex) = e {
        vertexCount += 1
      } else if case let .examine(edge) = e {
        edgeCount += 1
      }
    }
  }

  suite.benchmark("BFS on oneEdge graph, counting visitor") {
    var vertexCount = 0
    var edgeCount = 0
    oneEdge.breadthFirstSearch(startingAt: [0]) { e, g in
      if case let .examineVertex(vertex) = e {
        vertexCount += 1
      } else if case let .examineEdge(edge) = e {
        edgeCount += 1
      }
    }
  }

  suite.benchmark("Dijkstra on oneEdge graph, counting visitor") {
    var vertexCount = 0
    var edgeCount = 0
    let edgeLengths = ConstantEdgeProperty<SimpleGraph, Float>(value: 1.0)
    _ = oneEdge.dijkstraSearch(startingAt: 0, edgeLengths: edgeLengths) { e, g in
      if case let .examineVertex(vertex) = e {
        vertexCount += 1
      } else if case let .examineEdge(edge) = e {
        edgeCount += 1
      }
    }
  }

  suite.benchmark("DFS on twoEdges graph, counting visitor") {
    var vertexCount = 0
    var edgeCount = 0
    twoEdges.depthFirstTraversal { e, g in
      if case let .discover(vertex) = e {
        vertexCount += 1
      } else if case let .examine(edge) = e {
        edgeCount += 1
      }
    }
  }

  suite.benchmark("BFS on twoEdges graph, counting visitor") {
    var vertexCount = 0
    var edgeCount = 0
    twoEdges.breadthFirstSearch(startingAt: [0]) { e, g in
      if case let .examineVertex(vertex) = e {
        vertexCount += 1
      } else if case let .examineEdge(edge) = e {
        edgeCount += 1
      }
    }
  }

  suite.benchmark("Dijkstra on twoEdges graph, counting visitor") {
    var vertexCount = 0
    var edgeCount = 0
    let edgeLengths = ConstantEdgeProperty<SimpleGraph, Float>(value: 1.0)
    _ = twoEdges.dijkstraSearch(startingAt: 0, edgeLengths: edgeLengths) { e, g in
      if case let .examineVertex(vertex) = e {
        vertexCount += 1
      } else if case let .examineEdge(edge) = e {
        edgeCount += 1
      }
    }
  }

  suite.benchmark("DFS on completeGraph graph, counting visitor") {
    var vertexCount = 0
    var edgeCount = 0
    completeGraph.depthFirstTraversal { e, g in
      if case let .discover(vertex) = e {
        vertexCount += 1
      } else if case let .examine(edge) = e {
        edgeCount += 1
      }
    }
  }

  suite.benchmark("BFS on completeGraph graph, counting visitor") {
    var vertexCount = 0
    var edgeCount = 0
    completeGraph.breadthFirstSearch(startingAt: [0]) { e, g in
      if case let .examineVertex(vertex) = e {
        vertexCount += 1
      } else if case let .examineEdge(edge) = e {
        edgeCount += 1
      }
    }
  }

  suite.benchmark("Dijkstra on completeGraph graph, counting visitor") {
    var vertexCount = 0
    var edgeCount = 0
    let edgeLengths = ConstantEdgeProperty<SimpleGraph, Float>(value: 1.0)
    _ = completeGraph.dijkstraSearch(startingAt: 0, edgeLengths: edgeLengths) { e, g in
      if case let .examineVertex(vertex) = e {
        vertexCount += 1
      } else if case let .examineEdge(edge) = e {
        edgeCount += 1
      }
    }
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
    var vertexCount = 0
    var edgeCount = 0
    completeDAG.depthFirstTraversal { e, g in
      if case let .discover(vertex) = e {
        vertexCount += 1
      } else if case let .examine(edge) = e {
        edgeCount += 1
      }
    }
  }

  suite.benchmark("BFS on completeDAG graph, counting visitor") {
    var vertexCount = 0
    var edgeCount = 0
    completeDAG.breadthFirstSearch(startingAt: [0]) { e, g in
      if case let .examineVertex(vertex) = e {
        vertexCount += 1
      } else if case let .examineEdge(edge) = e {
        edgeCount += 1
      }
    }
  }

  suite.benchmark("Dijkstra on completeDAG graph, counting visitor") {
    var vertexCount = 0
    var edgeCount = 0
    let edgeLengths = ConstantEdgeProperty<SimpleGraph, Float>(value: 1.0)
    _ = completeDAG.dijkstraSearch(startingAt: 0, edgeLengths: edgeLengths) { e, g in
      if case let .examineVertex(vertex) = e {
        vertexCount += 1
      } else if case let .examineEdge(edge) = e {
        edgeCount += 1
      }
    }
  }

  suite.benchmark("Topological sort on completeDAG") {
    _ = try! completeDAG.topologicalSort()
  }
}

fileprivate struct ConstantEdgeProperty<Graph: GraphProtocol, Value>: GraphEdgePropertyMap {
  let value: Value
  func get(_ g: Graph, _ edge: Graph.EdgeId) -> Value { value }
}
