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

/// `VertexColor` is used to represent which vertices have been seen during graph searches.
///
/// Note: although there are vague interpretations for what each color means, their exact properties
/// are dependent upon the kind of graph search algorithm being executed.
public enum VertexColor {
  /// white is used for unseen vertices in the graph.
  case white
  /// gray is used for vertices that are being processed.
  case gray
  /// black is used for vertices that have finished processing.
  case black
}

public enum DFSEvent<Graph: GraphProtocol> {
  case start(Graph.VertexId)
  case discover(Graph.VertexId)
  case examine(Graph.EdgeId)
  case treeEdge(Graph.EdgeId)
  case backEdge(Graph.EdgeId)
  case forwardOrCrossEdge(Graph.EdgeId)
  case finish(Graph.VertexId)
}

extension IncidenceGraph where Self: VertexListGraph {

  public typealias DFSCallback = (DFSEvent<Self>, inout Self) throws -> Void

  /// Expores `self` depth-first starting at `source`, using `vertexVisitationState` to keep track of
  /// visited vertices, invoking `visitor`'s methods to reflect changes to the search state.
  ///
  /// - Note: this is a mutating method because the `vertexVisitationState` or `visitor` may store
  ///   data within the graph itself.
  /// - Precondition: `VertexVisitationState` has been initialized for every vertex to `.white`.
  public mutating func depthFirstSearch<
    VertexVisitationState: MutableGraphVertexPropertyMap
  >(
    startingAt source: VertexId,
    vertexVisitationState: inout VertexVisitationState,
    callback: DFSCallback
  ) rethrows
  where
    VertexVisitationState.Graph == Self,
    VertexVisitationState.Value == VertexColor
  {
    try callback(.start(source), &self)

    // We use an explicit stack to avoid a recursive implementation for performance.
    //
    // The stack contains the vertex we're traversing, as well as the (partially consumed) iterator
    // for the edges.
    //
    // Invariant: vertexVisitationState.get(vertex: v, in: graph) should be .gray for all `v` in `stack`.
    var stack = [(VertexId, VertexEdgeCollection.Iterator)]()
    vertexVisitationState.set(vertex: source, in: &self, to: .gray)
    stack.append((source, edges(from: source).makeIterator()))

    do {
      try callback(.discover(source), &self)
    } catch GraphErrors.stopSearch {
      // stop searching!
      return
    }

    while var (v, itr) = stack.popLast() {
      while let edge = itr.next() {
        let dest = destination(of: edge)
        try callback(.examine(edge), &self)
        let destinationColor = vertexVisitationState.get(self, dest)
        if destinationColor == .white {
          // We have a tree edge; push the current iteration state onto the stack and
          // "recurse" into dest.
          try callback(.treeEdge(edge), &self)
          vertexVisitationState.set(vertex: dest, in: &self, to: .gray)
          do {
            try callback(.discover(dest), &self)
          } catch GraphErrors.stopSearch {
            return
          }
          stack.append((v, itr))
          v = dest
          itr = edges(from: v).makeIterator()
        } else {
          if destinationColor == .gray {
            try callback(.backEdge(edge), &self)
          } else {
            try callback(.forwardOrCrossEdge(edge), &self)
          }
        }
      }
      // Finished iterating over all edges from our vertex.
      vertexVisitationState.set(vertex: v, in: &self, to: .black)
      try callback(.finish(v), &self)
    }
  }

  /// Runs depth first search repeatedly until all vertices have been visited.
  public mutating func depthFirstTraversal<
    VertexVisitationState: MutableGraphVertexPropertyMap
  >(
    vertexVisitationState: inout VertexVisitationState,
    callback: DFSCallback
  ) rethrows where VertexVisitationState.Graph == Self, VertexVisitationState.Value == VertexColor {
    var index = vertices.startIndex
    while let startIndex = vertices[index..<vertices.endIndex].firstIndex(where: {
      vertexVisitationState.get(self, $0) == .white
    }) {
      index = startIndex
      let startVertex = vertices[index]
      try self.depthFirstSearch(
        startingAt: startVertex, vertexVisitationState: &vertexVisitationState, callback: callback)
    }
  }
}

extension IncidenceGraph where Self: VertexListGraph, VertexId: IdIndexable {
  /// Expores `self` depth-first starting at `source`, invoking `visitor`'s methods to reflect
  /// changes to the search state.
  ///
  /// - Note: this is a mutating method because the `visitor` may store data within the graph
  ///   itself.
  public mutating func depthFirstSearch(
    startingAt source: VertexId,
    callback: DFSCallback
  ) rethrows {
    var vertexVisitationState = TableVertexPropertyMap(repeating: VertexColor.white, for: self)
    try depthFirstSearch(
      startingAt: source, vertexVisitationState: &vertexVisitationState, callback: callback)
  }


  /// Runs depth first search repeatedly until all vertices have been visited.
  public mutating func depthFirstTraversal(
    callback: DFSCallback
  ) rethrows {
    var vertexVisitationState = TableVertexPropertyMap(repeating: VertexColor.white, for: self)
    try depthFirstTraversal(vertexVisitationState: &vertexVisitationState, callback: callback)
  }
}
