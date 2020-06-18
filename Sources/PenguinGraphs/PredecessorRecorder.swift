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

import PenguinStructures

/// A table that records the parents of every discovered vertex in a graph search algorithm.
///
/// Example:
///
/// ```
/// var g = makeAdjacencyList()
/// let predecessors = TablePredecessorRecorder(for: g)
/// g.breadthFirstSearch(startingAt: g.vertices.first!) { e, g in
///   predecessors.record(e, graph: g)
/// }
/// ```
public struct TablePredecessorRecorder<Graph: IncidenceGraph> where Graph.VertexId: IdIndexable {
  /// A table of the predecessor for a vertex, organized by `Graph.VertexId.index`.
  public private(set) var predecessors: [Graph.VertexId?]

  /// Creates a PredecessorVisitor for use on graph `Graph` with `vertexCount` verticies.
  public init(vertexCount: Int) {
    predecessors = Array(repeating: nil, count: vertexCount)
  }

  /// Returns the sequence of vertices on the recorded path to `vertex`.
  public func path(to vertex: Graph.VertexId) -> ReversedCollection<[Graph.VertexId]>? {
    guard var i = predecessors[vertex.index] else { return nil }
    var reversePath = [vertex, i]
    while let next = predecessors[i.index] {
      reversePath.append(next)
      i = next
    }
    return reversePath.reversed()
  }
}

extension TablePredecessorRecorder where Graph: VertexListGraph {
  /// Creates a `PredecessorVisitor` for use on `graph`.
  ///
  /// Note: use this initializer to avoid spelling out the types, as this initializer helps along
  /// type inference nicely.
  public init(for graph: Graph) {
    self.init(vertexCount: graph.vertexCount)
  }
}

extension TablePredecessorRecorder {
  /// Captures predecessor information during depth first search.
  public mutating func record(_ event: DFSEvent<Graph>, graph: Graph) {
    if case .treeEdge(let edge) = event {
      predecessors[graph.destination(of: edge).index] = graph.source(of: edge)
    }
  }

  /// Captures predecessor information during Dijkstra's search.
  public mutating func record(_ event: DijkstraSearchEvent<Graph>, graph: Graph) {
    if case .edgeRelaxed(let edge) = event {
      predecessors[graph.destination(of: edge).index] = graph.source(of: edge)
    }
  }

  /// Captures predecessor information during breadth first search.
  public mutating func record(_ event: BFSEvent<Graph>, graph: Graph) {
    if case .treeEdge(let edge) = event {
      predecessors[graph.destination(of: edge).index] = graph.source(of: edge)
    }
  }
}

/// A dictionary that records the parents of every discovered vertex in a graph search algorithm.
///
/// Example:
///
/// ```
/// var g = CompleteInfiniteGrid()
/// let preds = DictionaryPredecessorRecorder(for: g)
/// g.breadthFirstSearch(startingAt: .origin) { e, g in preds.record(e, graph: g) }
/// ```
///
public struct DictionaryPredecessorRecorder<Graph: IncidenceGraph>: DefaultInitializable
where Graph.VertexId: Hashable {
  /// A dictionary of the predecessor for a vertex.
  public private(set) var predecessors: [Graph.VertexId: Graph.VertexId]

  /// Creates an empty predecessor recorder.
  public init() {
    self.predecessors = .init()
  }

  /// Creates an empty predecessor recorder (uses `graph` for type inference).
  public init(for graph: Graph) {
    self.init()
  }

  public subscript(vertex: Graph.VertexId) -> Graph.VertexId? {
    predecessors[vertex]
  }

  /// Captures predecessor information during depth first search.
  public mutating func record(_ event: DFSEvent<Graph>, graph: Graph) {
    if case .treeEdge(let edge) = event {
      predecessors[graph.destination(of: edge)] = graph.source(of: edge)
    }
  }

  /// Captures predecessor information during Dijkstra's search.
  public mutating func record(_ event: DijkstraSearchEvent<Graph>, graph: Graph) {
    if case .edgeRelaxed(let edge) = event {
      predecessors[graph.destination(of: edge)] = graph.source(of: edge)
    }
  }

  /// Captures predecessor information during breadth first search.
  public mutating func record(_ event: BFSEvent<Graph>, graph: Graph) {
    if case .treeEdge(let edge) = event {
      predecessors[graph.destination(of: edge)] = graph.source(of: edge)
    }
  }

  /// Returns the sequence of vertices on the recorded path to `vertex`.
  public func path(to vertex: Graph.VertexId) -> ReversedCollection<[Graph.VertexId]>? {
    guard var i = predecessors[vertex] else { return nil }
    var reversePath = [vertex, i]
    while let next = predecessors[i] {
      reversePath.append(next)
      i = next
    }
    return reversePath.reversed()
  }
}
