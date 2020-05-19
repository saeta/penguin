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

/// The events that occur during depth first search within a graph.
///
/// - SeeAlso: `IncidenceGraph.DFSCallback`
public enum DFSEvent<SearchSpace: GraphProtocol> {
  /// The start of the depth first search, recording the starting vertex.
  case start(SearchSpace.VertexId)

  /// When a new vertex is discovered in the search space.
  case discover(SearchSpace.VertexId)

  /// When an edge is traversed to explore the destination.
  case examine(SearchSpace.EdgeId)

  /// When the edge is determined to form part of the search tree.
  ///
  /// This event occurs when the destination of the edge is newly discovered.
  case treeEdge(SearchSpace.EdgeId)

  /// When the edge's destination is being processed (i.e. already on the stack).
  case backEdge(SearchSpace.EdgeId)

  /// When the edge's destination has already been processed.
  case forwardOrCrossEdge(SearchSpace.EdgeId)

  /// When all edges from a vertex have been explored.
  case finish(SearchSpace.VertexId)
}

extension IncidenceGraph where Self: VertexListGraph {

  /// A hook to observe events that occur during depth first search.
  public typealias DFSCallback = (DFSEvent<Self>, inout Self) throws -> Void

  /// Expores `self` depth-first starting at `source`, using `vertexVisitationState` to keep track of
  /// visited vertices, invoking `callback` at key events of the search.
  ///
  /// - Note: this is a mutating method because the `vertexVisitationState` or `visitor` may store
  ///   data within the graph itself.
  /// - Precondition: `VertexVisitationState` has been initialized for every vertex to `.white`.
  public mutating func depthFirstSearch<
    VertexVisitationState: PropertyMap
  >(
    startingAt source: VertexId,
    vertexVisitationState: inout VertexVisitationState,
    callback: DFSCallback
  ) rethrows
  where
    VertexVisitationState.Graph == Self,
    VertexVisitationState.Key == VertexId,
    VertexVisitationState.Value == VertexColor
  {
    assert(
      vertexVisitationState.get(source, in: self) == .white,
      "vertexVisitationState was not properly initialized.")
    try callback(.start(source), &self)

    // We use an explicit stack to avoid a recursive implementation for performance & scale.
    //
    // The stack contains the vertex we're traversing, as well as the (partially consumed) iterator
    // for the edges.
    //
    // Invariant: vertexVisitationState.get(vertex: v, in: graph) should be .gray for all `v` in `stack`.
    var stack = [(VertexId, VertexEdgeCollection.Iterator)]()
    vertexVisitationState.set(source, in: &self, to: .gray)
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
        let destinationColor = vertexVisitationState.get(dest, in: self)
        if destinationColor == .white {
          // We have a tree edge; push the current iteration state onto the stack and
          // "recurse" into dest.
          try callback(.treeEdge(edge), &self)
          vertexVisitationState.set(dest, in: &self, to: .gray)
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
      vertexVisitationState.set(v, in: &self, to: .black)
      try callback(.finish(v), &self)
    }
  }

  /// Runs depth first search repeatedly until all vertices have been visited.
  public mutating func depthFirstTraversal<
    VertexVisitationState: PropertyMap
  >(
    vertexVisitationState: inout VertexVisitationState,
    callback: DFSCallback
  ) rethrows where VertexVisitationState.Graph == Self, VertexVisitationState.Key == VertexId, VertexVisitationState.Value == VertexColor {
    var index = vertices.startIndex
    while let startIndex = vertices[index..<vertices.endIndex].firstIndex(where: {
      vertexVisitationState.get($0, in: self) == .white
    }) {
      index = startIndex
      let startVertex = vertices[index]
      try self.depthFirstSearch(
        startingAt: startVertex, vertexVisitationState: &vertexVisitationState, callback: callback)
    }
  }
}

extension IncidenceGraph where Self: VertexListGraph, VertexId: IdIndexable {
  /// Expores `self` depth-first starting at `source`, invoking `callback` at key events during the
  /// search.
  ///
  /// - Note: this is a mutating method because the `callback` may modify the graph.
  public mutating func depthFirstSearch(
    startingAt source: VertexId,
    callback: DFSCallback
  ) rethrows {
    var vertexVisitationState = TablePropertyMap(repeating: VertexColor.white, forVerticesIn: self)
    try depthFirstSearch(
      startingAt: source, vertexVisitationState: &vertexVisitationState, callback: callback)
  }


  /// Runs depth first search repeatedly until all vertices have been visited.
  public mutating func depthFirstTraversal(
    callback: DFSCallback
  ) rethrows {
    var vertexVisitationState = TablePropertyMap(repeating: VertexColor.white, forVerticesIn: self)
    try depthFirstTraversal(vertexVisitationState: &vertexVisitationState, callback: callback)
  }
}
