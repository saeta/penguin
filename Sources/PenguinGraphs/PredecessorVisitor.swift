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
public struct TablePredecessorRecorder<Graph: IncidenceGraph> where Graph.VertexId: IdIndexable {
  /// A table of the predecessor for a vertex, organized by `Graph.VertexId.index`.
  public private(set) var predecessors: [Graph.VertexId?]

  /// Creates a PredecessorVisitor for use on graph `Graph` with `vertexCount` verticies.
  public init(vertexCount: Int) {
    predecessors = Array(repeating: nil, count: vertexCount)
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
  public mutating func record(_ event: DFSEvent<Graph>, graph: Graph) {
    if case .treeEdge(let edge) = event {
      predecessors[graph.destination(of: edge).index] = graph.source(of: edge)
    }
  }

  public mutating func record(_ event: DijkstraSearchEvent<Graph>, graph: Graph) {
    if case .edgeRelaxed(let edge) = event {
      predecessors[graph.destination(of: edge).index] = graph.source(of: edge)
    }
  }

  public mutating func record(_ event: BFSEvent<Graph>, graph: Graph) {
    if case .treeEdge(let edge) = event {
      predecessors[graph.destination(of: edge).index] = graph.source(of: edge)
    }
  }
}
