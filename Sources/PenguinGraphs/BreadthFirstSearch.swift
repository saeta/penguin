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

public protocol Queue {
  associatedtype Element
  mutating func pop() -> Element?
  mutating func push(_ element: Element)
}

public struct DequeQueue<Element>: Queue {
  var underlying = Deque<Element>()

  public mutating func pop() -> Element? {
    if underlying.isEmpty {
      return nil
    }
    return underlying.popFront()
  }

  public mutating func push(_ element: Element) {
    underlying.pushBack(element)
  }
}

public enum BFSEvent<Graph: GraphProtocol> {
  public typealias Vertex = Graph.VertexId
  public typealias Edge = Graph.EdgeId

  case start(Vertex)  // TODO: REMOVE ME?!?!?
  case discover(Vertex)
  case examineVertex(Vertex)
  case examineEdge(Edge)
  case treeEdge(Edge)
  case nonTreeEdge(Edge)
  case grayDestination(Edge)
  case blackDestination(Edge)
  case finish(Vertex)
}

extension IncidenceGraph where Self: VertexListGraph {

  // TODO(saeta): Document me. Something about the "standard" BFS callback, but see also the queue
  // modifying one.
  public typealias BFSCallback = (BFSEvent<Self>, inout Self) throws -> Void

  // TODO(saeta): Document me!
  public typealias BFSCompleteCallback<WorkList: Queue> = (BFSEvent<Self>, inout Self, inout WorkList) throws -> Void

  /// Runs breadth first search on `graph`; `visitor` is notified at regular intervals during the
  /// search.
  ///
  /// - Precondition: `startVertices` is non-empty.
  public mutating func breadthFirstSearch<
    StartVertices: Collection
  >(
    startingAt startVertices: StartVertices,
    callback: BFSCallback
  ) rethrows
  where
    StartVertices.Element == VertexId,
    VertexId: IdIndexable
  {
    var vertexVisitationState = TableVertexPropertyMap(repeating: VertexColor.white, for: self)
    var queue = DequeQueue<VertexId>()
    try self.breadthFirstSearch(
      startingAt: startVertices,
      workList: &queue,
      vertexVisitationState: &vertexVisitationState
    ) { e, g, q in
      try callback(e, &g)
    }
  }

  /// Runs breadth first search on `graph` using `vertexVisitationState` to keep track of search progress;
  /// `visitor` is notified at regular intervals during the search.
  ///
  /// - Precondition: `vertexVisitationState` must be initialized for every `VertexId` in `Graph` to be
  ///   `.white`. (Note: this precondition is not checked.)
  /// - Precondition: `startVertices` is non-empty.
  public mutating func breadthFirstSearch<
    VertexVisitationState: MutableGraphVertexPropertyMap,
    WorkList: Queue,
    StartVertices: Collection
  >(
    startingAt startVertices: StartVertices,
    workList: inout WorkList,
    vertexVisitationState: inout VertexVisitationState,
    callback: BFSCompleteCallback<WorkList>
  ) rethrows
  where
    VertexVisitationState.Graph == Self,
    VertexVisitationState.Value == VertexColor,
    WorkList.Element == VertexId,
    StartVertices.Element == VertexId
  {
    precondition(!startVertices.isEmpty, "startVertices was empty.")
    for startVertex in startVertices {
      vertexVisitationState.set(vertex: startVertex, in: &self, to: .gray)
      try callback(.start(startVertex), &self, &workList)
      try callback(.discover(startVertex), &self, &workList)
      workList.push(startVertex)
    }

    while let vertex = workList.pop() {
      try callback(.examineVertex(vertex), &self, &workList)
      for edge in edges(from: vertex) {
        let v = destination(of: edge)
        try callback(.examineEdge(edge), &self, &workList)
        let vColor = vertexVisitationState.get(self, v)
        if vColor == .white {
          try callback(.discover(v), &self, &workList)
          workList.push(v)
          try callback(.treeEdge(edge), &self, &workList)
          vertexVisitationState.set(vertex: v, in: &self, to: .gray)
        } else {
          try callback(.nonTreeEdge(edge), &self, &workList)
          if vColor == .gray {
            try callback(.grayDestination(edge), &self, &workList)
          } else {
            try callback(.blackDestination(edge), &self, &workList)
          }
        }
      }  // end edge for-loop.
      vertexVisitationState.set(vertex: vertex, in: &self, to: .black)
      try callback(.finish(vertex), &self, &workList)
    }  // end while loop
  }
}
