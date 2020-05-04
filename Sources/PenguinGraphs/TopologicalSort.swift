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

extension Graphs {

  /// Computes a [topological sort](https://en.wikipedia.org/wiki/Topological_sorting) of `graph`.
  ///
  /// - Parameter graph: the graph upon whose vertices the topological sort will be computed.
  /// - Parameter reverseSink: this function will be called once for every vertex in reverse
  ///   topological sort order.
  /// - Throws: if a cycle is detected.
  public static func topologicalSort<Graph: IncidenceGraph & VertexListGraph>(
    _ graph: inout Graph,
    reverseSink: (Graph.VertexId) -> Void
  ) throws where Graph.VertexId: IdIndexable {
    try withoutActuallyEscaping(reverseSink) { reverseSink in
      var visitor = TopologicalSortVisitor<Graph>(reverseSink: reverseSink)
      try Graphs.depthFirstTraversal(&graph, visitor: &visitor)
    }
  }

  /// Computes a [topological sort](https://en.wikipedia.org/wiki/Topological_sorting) of `graph`.
  ///
  /// A topological sort means that for every 0 <= i < j < graph.vertexCount,
  /// there does not exist an edge from `returnValue[j]` to `returnValue[i]`
  /// (i.e. backwards in the array).
  ///
  /// - Throws: if a cycle is detected.
  public static func topologicalSort<Graph: IncidenceGraph & VertexListGraph>(
    _ graph: inout Graph
  ) throws -> [Graph.VertexId] where Graph.VertexId: IdIndexable {
    let vertexCount = graph.vertexCount
    let output = try [Graph.VertexId](unsafeUninitializedCapacity: vertexCount) { buffer, filled in
      var ptr = buffer.baseAddress! + vertexCount

      var visitor = TopologicalSortVisitor<Graph> { vId in
        ptr -= 1
        ptr.initialize(to: vId)
      }
      try Graphs.depthFirstTraversal(&graph, visitor: &visitor)  // Memory leaked if VertexId non-trivial.
      filled = vertexCount
    }
    return output
  }
}

private struct TopologicalSortVisitor<Graph: GraphProtocol>: DFSVisitor {
  let reverseSink: (Graph.VertexId) -> Void

  mutating func backEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) throws {
    throw GraphErrors.cycleDetected
  }

  mutating func finish(vertex: Graph.VertexId, _ graph: inout Graph) {
    reverseSink(vertex)
  }
}
