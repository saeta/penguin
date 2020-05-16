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

extension IncidenceGraph where Self: VertexListGraph, VertexId: IdIndexable {

  // TODO: add an implementation of topologicalSort that doesn't require VertexId to be IdIndexable.
  /// Computes a [topological sort](https://en.wikipedia.org/wiki/Topological_sorting) of `self`.
  ///
  /// - Parameter reverseSink: this function will be called once for every vertex in reverse
  ///   topological sort order.
  /// - Throws: if a cycle is detected.
  public mutating func topologicalSort(
    reverseSink: (VertexId) -> Void
  ) throws {
    try depthFirstTraversal { event, graph in
      if case .finish(let vertex) = event {
        reverseSink(vertex)
      } else if case .backEdge = event {
        throw GraphErrors.cycleDetected
      }
    }
  }

  /// Computes a [topological sort](https://en.wikipedia.org/wiki/Topological_sorting) of `self`.
  ///
  /// A topological sort means that for every 0 <= i < j < vertexCount,
  /// there does not exist an edge from `returnValue[j]` to `returnValue[i]`
  /// (i.e. backwards in the array).
  ///
  /// - Throws: if a cycle is detected.
  public mutating func topologicalSort() throws -> [VertexId] {
    let output = try [VertexId](unsafeUninitializedCapacity: vertexCount) { buffer, filled in
      var ptr = buffer.baseAddress! + vertexCount
      // Memory leaked if VertexId non-trivial & a cycle is detected!
      try topologicalSort { v in
        ptr -= 1
        ptr.initialize(to: v)
      }
      filled = vertexCount
    }
    return output
  }
}
