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

extension IncidenceGraph where Self: VertexListGraph {

  /// Runs breadth first search on `graph`; `visitor` is notified at regular intervals during the
  /// search.
  ///
  /// - Precondition: `startVertices` is non-empty.
  public mutating func breadthFirstSearch<
    Visitor: BFSVisitor,
    StartVertices: Collection
  >(
    visitor: inout Visitor,
    startAt startVertices: StartVertices
  ) throws
  where
    Visitor.Graph == Self,
    StartVertices.Element == VertexId,
    VertexId: IdIndexable
  {
    var vertexVisitationState = TableVertexPropertyMap(repeating: VertexColor.white, for: self)
    try self.breadthFirstSearch(visitor: &visitor, vertexVisitationState: &vertexVisitationState, startAt: startVertices)
  }

  /// Runs breadth first search on `graph` using `vertexVisitationState` to keep track of search progress;
  /// `visitor` is notified at regular intervals during the search.
  ///
  /// - Precondition: `vertexVisitationState` must be initialized for every `VertexId` in `Graph` to be
  ///   `.white`. (Note: this precondition is not checked.)
  /// - Precondition: `startVertices` is non-empty.
  public mutating func breadthFirstSearch<
    Visitor: BFSVisitor,
    VertexVisitationState: MutableGraphVertexPropertyMap,
    StartVertices: Collection
  >(
    visitor: inout Visitor,
    vertexVisitationState: inout VertexVisitationState,
    startAt startVertices: StartVertices
  ) throws
  where
    Visitor.Graph == Self,
    VertexVisitationState.Graph == Self,
    VertexVisitationState.Value == VertexColor,
    StartVertices.Element == VertexId
  {
    precondition(!startVertices.isEmpty, "startVertices was empty.")
    for startVertex in startVertices {
      vertexVisitationState.set(vertex: startVertex, in: &self, to: .gray)
      try visitor.start(vertex: startVertex, &self)
      try visitor.discover(vertex: startVertex, &self)
    }

    while let vertex = visitor.popVertex() {
      try visitor.examine(vertex: vertex, &self)
      for edge in edges(from: vertex) {
        let v = destination(of: edge)
        try visitor.examine(edge: edge, &self)
        let vColor = vertexVisitationState.get(self, v)
        if vColor == .white {
          try visitor.discover(vertex: v, &self)
          try visitor.treeEdge(edge, &self)
          vertexVisitationState.set(vertex: v, in: &self, to: .gray)
        } else {
          try visitor.nonTreeEdge(edge, &self)
          if vColor == .gray {
            try visitor.grayDestination(edge, &self)
          } else {
            try visitor.blackDestination(edge, &self)
          }
        }
      }  // end edge for-loop.
      vertexVisitationState.set(vertex: vertex, in: &self, to: .black)
      try visitor.finish(vertex: vertex, &self)
    }  // end while loop
  }
}

/// The BFSVisitor that implements breadth first search.
public struct BFSQueueVisitor<Graph: GraphProtocol>: BFSVisitor {
  var queue = Deque<Graph.VertexId>()

  /// Initialize an empty `BFSQueueVisitor`.
  public init() {}

  /// Called upon first discovering `vertex` in the graph.
  ///
  /// This visitor keeps track of the vertex (and put it in a backlog) so that it can be
  /// returned in the future when `popVertex()` is called.
  public mutating func discover(vertex: Graph.VertexId, _ graph: inout Graph) {
    queue.pushBack(vertex)
  }

  /// Retrieves the next vertex to visit.
  public mutating func popVertex() -> Graph.VertexId? {
    guard !queue.isEmpty else { return nil }
    return queue.popFront()
  }

}
