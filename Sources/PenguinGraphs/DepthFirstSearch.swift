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

extension IncidenceGraph where Self: VertexListGraph {

  /// Runs depth first search on starting at `startVertex`; `visitor` is called regularly to allow
  /// arbitrary state to be computed during search.
  ///
  /// - Note: this is a mutating function because the `visitor` may store data within the graph
  ///   itself.
  public mutating func depthFirstSearch<
    Visitor: DFSVisitor
  >(
    startingAt startVertex: VertexId,
    visitor: inout Visitor
  ) throws
  where VertexId: IdIndexable, Visitor.Graph == Self {
    var vertexVisitationState = TableVertexPropertyMap(repeating: VertexColor.white, for: self)
    try depthFirstSearch(
      startingAt: startVertex, vertexVisitationState: &vertexVisitationState, visitor: &visitor)
  }

  /// Runs depth first search on starting at `startVertex` using `vertexVisitationState` to keep track of
  /// visited vertices; `visitor` is called regularly to allow arbitrary state to be computed during
  /// search.
  ///
  /// - Note: this is a mutating function because the `vertexVisitationState` or `visitor` may store data within the
  ///   graph itself.
  /// - Precondition: `VertexVisitationState` has been initialized for every vertex to `.white`.
  public mutating func depthFirstSearch<
    VertexVisitationState: MutableGraphVertexPropertyMap,
    Visitor: DFSVisitor
  >(
    startingAt startVertex: VertexId,
    vertexVisitationState: inout VertexVisitationState,
    visitor: inout Visitor
  ) throws
  where
    VertexVisitationState.Graph == Self,
    VertexVisitationState.Value == VertexColor,
    Visitor.Graph == Self
  {
    try visitor.start(vertex: startVertex, &self)

    // We use an explicit stack to avoid a recursive implementation for performance.
    //
    // The stack contains the vertex we're traversing, as well as the (partially consumed) iterator
    // for the edges.
    //
    // Invariant: vertexVisitationState.get(vertex: v, in: graph) should be .gray for all `v` in `stack`.
    var stack = [(VertexId, VertexEdgeCollection.Iterator)]()
    vertexVisitationState.set(vertex: startVertex, in: &self, to: .gray)
    stack.append((startVertex, edges(from: startVertex).makeIterator()))

    do {
      try visitor.discover(vertex: startVertex, &self)
    } catch GraphErrors.stopSearch {
      // stop searching!
      return
    }

    while var (v, itr) = stack.popLast() {
      while let edge = itr.next() {
        let dest = destination(of: edge)
        try visitor.examine(edge: edge, &self)
        let destinationColor = vertexVisitationState.get(self, dest)
        if destinationColor == .white {
          // We have a tree edge; push the current iteration state onto the stack and
          // "recurse" into dest.
          try visitor.treeEdge(edge, &self)
          vertexVisitationState.set(vertex: dest, in: &self, to: .gray)
          do {
            try visitor.discover(vertex: dest, &self)
          } catch GraphErrors.stopSearch {
            return
          }
          stack.append((v, itr))
          v = dest
          itr = edges(from: v).makeIterator()
        } else {
          if destinationColor == .gray {
            try visitor.backEdge(edge, &self)
          } else {
            try visitor.forwardOrCrossEdge(edge, &self)
          }
        }
      }
      // Finished iterating over all edges from our vertex.
      vertexVisitationState.set(vertex: v, in: &self, to: .black)
      try visitor.finish(vertex: v, &self)
    }
  }

  /// Runs depth first search repeatedly until all vertices have been visited.
  public mutating func depthFirstTraversal<
    Visitor: DFSVisitor
  >(
    visitor: inout Visitor
  ) throws where Visitor.Graph == Self, VertexId: IdIndexable {
    var vertexVisitationState = TableVertexPropertyMap(repeating: VertexColor.white, for: self)

    var index = vertices.startIndex
    while let startIndex = vertices[index..<vertices.endIndex].firstIndex(where: {
      vertexVisitationState.get(self, $0) == .white
    }) {
      index = startIndex
      let startVertex = vertices[index]
      try self.depthFirstSearch(
        startingAt: startVertex, vertexVisitationState: &vertexVisitationState, visitor: &visitor)
    }
  }
}
