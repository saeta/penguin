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

  /// Runs breadth first search on `graph`; `visitor` is notified at regular intervals during the
  /// search.
  ///
  /// - Precondition: `colorMap` must be initialized for every `VertexId` in `Graph` to be
  ///   `.white`. (Note: this precondition is not checked.)
  /// - Precondition: `startVertices` is non-empty.
  public static func breadthFirstSearch<
    SearchSpace: IncidenceGraph & VertexListGraph,
    UserVisitor: BFSVisitor,
    StartVertices: Collection
  >(
    _ graph: inout SearchSpace,
    visitor: inout UserVisitor,
    startAt startVertices: StartVertices
  ) throws
  where
    UserVisitor.Graph == SearchSpace,
    StartVertices.Element == SearchSpace.VertexId,
    SearchSpace.VertexId: IdIndexable
  {
    var colorMap = TableVertexPropertyMap(repeating: VertexColor.white, for: graph)
    try breadthFirstSearchNoInit(&graph, visitor: &visitor, colorMap: &colorMap, startAt: startVertices)
  }

  /// Runs breadth first search on `graph` using `colorMap` to keep track of search progress;
  /// `visitor` is notified at regular intervals during the search.
  ///
  /// - Precondition: `colorMap` must be initialized for every `VertexId` in `Graph` to be
  ///   `.white`. (Note: this precondition is not checked.)
  /// - Precondition: `startVertices` is non-empty.
  public static func breadthFirstSearchNoInit<
    SearchSpace: IncidenceGraph,
    UserVisitor: BFSVisitor,
    ColorMap: MutableGraphVertexPropertyMap,
    StartVertices: Collection
  >(
    _ graph: inout SearchSpace,
    visitor: inout UserVisitor,
    colorMap: inout ColorMap,
    startAt startVertices: StartVertices
  ) throws
  where
    UserVisitor.Graph == SearchSpace,
    ColorMap.Graph == SearchSpace,
    ColorMap.Value == VertexColor,
    StartVertices.Element == SearchSpace.VertexId
  {
    precondition(!startVertices.isEmpty, "startVertices was empty.")
    for startVertex in startVertices {
      colorMap.set(vertex: startVertex, in: &graph, to: .gray)
      try visitor.start(vertex: startVertex, &graph)
      try visitor.discover(vertex: startVertex, &graph)
    }

    while let vertex = visitor.popVertex() {
      try visitor.examine(vertex: vertex, &graph)
      for edge in graph.edges(from: vertex) {
        let v = graph.destination(of: edge)
        try visitor.examine(edge: edge, &graph)
        let vColor = colorMap.get(graph, v)
        if vColor == .white {
          try visitor.discover(vertex: v, &graph)
          try visitor.treeEdge(edge, &graph)
          colorMap.set(vertex: v, in: &graph, to: .gray)
        } else {
          try visitor.nonTreeEdge(edge, &graph)
          if vColor == .gray {
            try visitor.grayDestination(edge, &graph)
          } else {
            try visitor.blackDestination(edge, &graph)
          }
        }
      }  // end edge for-loop.
      colorMap.set(vertex: vertex, in: &graph, to: .black)
      try visitor.finish(vertex: vertex, &graph)
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
