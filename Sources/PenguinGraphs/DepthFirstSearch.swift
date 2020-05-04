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

extension Graphs {

  /// Runs depth first search on `graph` starting at `startVertex` using `colorMap` to keep track of
  /// visited vertices; `visitor` is called regularly to allow arbitrary state to be computed during
  /// search.
  ///
  /// - Note: `graph` is taken `inout` because the `colorMap` or `visitor` may store data within the
  ///   graph itself.
  /// - Precondition: `ColorMap` has been initialized for every vertex to `.white`.
  public static func depthFirstSearchNoInit<
    Graph: IncidenceGraph & VertexListGraph,
    ColorMap: MutableGraphVertexPropertyMap,
    Visitor: DFSVisitor
  >(
    _ graph: inout Graph,
    colorMap: inout ColorMap,
    visitor: inout Visitor,
    start startVertex: Graph.VertexId
  ) throws
  where
    ColorMap.Graph == Graph,
    ColorMap.Value == VertexColor,
    Visitor.Graph == Graph
  {
    try visitor.start(vertex: startVertex, &graph)

    // We use an explicit stack to avoid a recursive implementation for performance.
    //
    // The stack contains the vertex we're traversing, as well as the (partially consumed) iterator
    // for the edges.
    //
    // Invariant: colorMap.get(vertex: v, in: graph) should be .gray for all `v` in `stack`.
    var stack = [(Graph.VertexId, Graph.VertexEdgeCollection.Iterator)]()
    colorMap.set(vertex: startVertex, in: &graph, to: .gray)
    stack.append((startVertex, graph.edges(from: startVertex).makeIterator()))

    do {
      try visitor.discover(vertex: startVertex, &graph)
    } catch GraphErrors.stopSearch {
      // stop searching!
      return
    }

    while var (v, itr) = stack.popLast() {
      while let edge = itr.next() {
        let destination = graph.destination(of: edge)
        try visitor.examine(edge: edge, &graph)
        let destinationColor = colorMap.get(graph, destination)
        if destinationColor == .white {
          // We have a tree edge; push the current iteration state onto the stack and
          // "recurse" into destination.
          try visitor.treeEdge(edge, &graph)
          colorMap.set(vertex: destination, in: &graph, to: .gray)
          do {
            try visitor.discover(vertex: destination, &graph)
          } catch GraphErrors.stopSearch {
            return
          }
          stack.append((v, itr))
          v = destination
          itr = graph.edges(from: v).makeIterator()
        } else {
          if destinationColor == .gray {
            try visitor.backEdge(edge, &graph)
          } else {
            try visitor.forwardOrCrossEdge(edge, &graph)
          }
        }
      }
      // Finished iterating over all edges from our vertex.
      colorMap.set(vertex: v, in: &graph, to: .black)
      try visitor.finish(vertex: v, &graph)
    }
  }

  /// Runs depth first search repeatedly until all vertices have been visited.
  public static func depthFirstTraversal<
    Graph: IncidenceGraph & VertexListGraph,
    Visitor: DFSVisitor
  >(
    _ graph: inout Graph,
    visitor: inout Visitor
  ) throws where Visitor.Graph == Graph, Graph.VertexId: IdIndexable {
    var colorMap = TableVertexPropertyMap(repeating: VertexColor.white, for: graph)

    let vertices = graph.vertices
    var index = vertices.startIndex
    while let startIndex = vertices[index..<vertices.endIndex].firstIndex(where: {
      colorMap.get(graph, $0) == .white
    }) {
      index = startIndex
      let startVertex = vertices[index]
      try depthFirstSearchNoInit(&graph, colorMap: &colorMap, visitor: &visitor, start: startVertex)
    }
  }
}
