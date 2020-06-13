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

/// The events that occur during breadth first search within a graph.
///
/// - SeeAlso: `IncidenceGraph.BFSCallback`
public enum BFSEvent<SearchSpace: GraphProtocol> {
  /// Identifies a vertex in the search space.
  public typealias Vertex = SearchSpace.VertexId
  /// Identifies an edge in the search space.
  public typealias Edge = SearchSpace.EdgeId

  /// When search begins, identifying the the start vertex.
  ///
  /// Note: this event may trigger multiple times if there are multiple start vertices.
  case start(Vertex)

  /// When a new vertex is discovered in the search space.
  case discover(Vertex)

  /// When a vertex is popped off the front of the queue for processing.
  case examineVertex(Vertex)

  /// When an edge is traversed to look for new vertices to discover.
  case examineEdge(Edge)

  /// When an edge's destination has not been encountered before in the search; this edge forms part
  /// of the search tree.
  case treeEdge(Edge)

  /// When an edge's destination has already been encountered before in the search.
  ///
  /// Note: this edge could have either a "gray" or a "black" destination.
  case nonTreeEdge(Edge)

  /// When the edge's destination has previously been discovered, but has not been examined.
  case grayDestination(Edge)

  /// When the edge's destination has already been discovered and examined.
  case blackDestination(Edge)

  /// When all edges from a vertex have been traversed.
  case finish(Vertex)
}

extension IncidenceGraph {
  /// A hook to observe events that occur during depth first search.
  public typealias BFSCallback = (BFSEvent<Self>, inout Self) throws -> Void

  /// A hook to (1) observe events that occur during depth first search, and (2) to optionally
  /// modify the work list of vertices.
  public typealias BFSCallbackWithWorkList<WorkList: Queue> =
    (BFSEvent<Self>, inout Self, inout WorkList) throws -> Void

  /// Runs breadth first search on `self` using `vertexVisitationState` to keep track of search
  /// progress; `callback` is invoked at key events during the search.
  ///
  /// - Precondition: `vertexVisitationState` must be initialized for every `VertexId` in `Graph` to
  ///   be `.white`. (Note: this precondition is not checked.)
  /// - Precondition: `startVertices` is non-empty.
  public mutating func breadthFirstSearch<
    VertexVisitationState: PropertyMap,
    WorkList: Queue,
    StartVertices: Collection
  >(
    startingAt startVertices: StartVertices,
    workList: inout WorkList,
    vertexVisitationState: inout VertexVisitationState,
    callback: BFSCallbackWithWorkList<WorkList>
  ) rethrows
  where
    VertexVisitationState.Graph == Self,
    VertexVisitationState.Key == VertexId,
    VertexVisitationState.Value == VertexColor,
    WorkList.Element == VertexId,
    StartVertices.Element == VertexId
  {
    precondition(!startVertices.isEmpty, "startVertices was empty.")
    for startVertex in startVertices {
      vertexVisitationState.set(startVertex, in: &self, to: .gray)
      try callback(.start(startVertex), &self, &workList)
      try callback(.discover(startVertex), &self, &workList)
      workList.push(startVertex)
    }

    while let vertex = workList.pop() {
      try callback(.examineVertex(vertex), &self, &workList)
      for edge in edges(from: vertex) {
        let v = destination(of: edge)
        try callback(.examineEdge(edge), &self, &workList)
        let vColor = vertexVisitationState.get(v, in: self)
        if vColor == .white {
          try callback(.discover(v), &self, &workList)
          workList.push(v)
          try callback(.treeEdge(edge), &self, &workList)
          vertexVisitationState.set(v, in: &self, to: .gray)
        } else {
          try callback(.nonTreeEdge(edge), &self, &workList)
          if vColor == .gray {
            try callback(.grayDestination(edge), &self, &workList)
          } else {
            try callback(.blackDestination(edge), &self, &workList)
          }
        }
      }  // end edge for-loop.
      vertexVisitationState.set(vertex, in: &self, to: .black)
      try callback(.finish(vertex), &self, &workList)
    }  // end while loop
  }

  /// Runs breadth first search on `self` starting from `startVertices`; `callback` is invoked at
  /// key events during the search.
  ///
  /// - Precondition: `startVertices` is non-empty.
  public mutating func breadthFirstSearch<
    StartVertices: Collection,
    VertexVisitationState: PropertyMap
  >(
    startingAt startVertices: StartVertices,
    vertexVisitationState: inout VertexVisitationState,
    callback: BFSCallback
  ) rethrows
  where
    StartVertices.Element == VertexId,
    VertexVisitationState.Graph == Self,
    VertexVisitationState.Key == VertexId,
    VertexVisitationState.Value == VertexColor
  {
    var queue = Deque<VertexId>()
    try self.breadthFirstSearch(
      startingAt: startVertices,
      workList: &queue,
      vertexVisitationState: &vertexVisitationState
    ) { e, g, q in
      try callback(e, &g)
    }
  }
}

extension IncidenceGraph where Self: SearchDefaultsGraph {
  /// Runs breadth first search on `self` starting from `startVertices`; `callback` is invoked at
  /// key events during the search.
  ///
  /// - Precondition: `startVertices` is non-empty.
  public mutating func breadthFirstSearch<
    StartVertices: Collection
  >(
    startingAt startVertices: StartVertices,
    callback: BFSCallback
  ) rethrows
  where
    StartVertices.Element == VertexId
  {
    var vertexVisitationState = makeDefaultColorMap(repeating: .white)
    try self.breadthFirstSearch(
      startingAt: startVertices,
      vertexVisitationState: &vertexVisitationState,
      callback: callback)
  }

  /// Runs breadth first search on `self` starting from `startVertex`; `callback` is invoked at
  /// key events during the search.
  public mutating func breadthFirstSearch(
    startingAt startVertex: VertexId,
    callback: BFSCallback
  ) rethrows {
    try breadthFirstSearch(startingAt: [startVertex], callback: callback)
  }

  /// Runs breadth first search on `self` starting from `startVertex` terminating once `endVertex`
  /// has been encountered; `callback` is invoked at key events during the search.
  public mutating func breadthFirstSearch(
    startingAt startVertex: VertexId,
    endingAt endVertex: VertexId,
    callback: BFSCallback
  ) rethrows {
    do {
      try breadthFirstSearch(startingAt: startVertex) { e, g in
        try callback(e, &g)
        // Note: we interrupt after the `.treeEdge` event (instead of at the `.discover` event)
        // to allow callbacks like the predecessor recorders to run.
        if case .treeEdge(let edge) = e, g.destination(of: edge) == endVertex {
          throw GraphErrors.stopSearch
        }
      }
    } catch GraphErrors.stopSearch {
      return
    }
  }
}
