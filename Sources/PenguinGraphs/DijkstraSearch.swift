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

/// Represents a distance measure on a graph.
public protocol GraphDistanceMeasure: AdditiveArithmetic, Comparable {
  /// A value that is effectively always higher than any reasonable possible distance within the
  /// graph.
  static var effectiveInfinity: Self { get }
}

extension GraphDistanceMeasure where Self: FixedWidthInteger {
  public static var effectiveInfinity: Self { Self.max }
}

extension GraphDistanceMeasure where Self: FloatingPoint {
  public static var effectiveInfinity: Self { Self.infinity }
}

extension Int: GraphDistanceMeasure {}
extension Int32: GraphDistanceMeasure {}
extension Float: GraphDistanceMeasure {}
extension Double: GraphDistanceMeasure {}

/// Implements the majority of Dijkstra's algorithm in terms of BreadthFirstSearch.
private struct DijkstraBFSVisitor<
  SearchSpace: IncidenceGraph,
  PathLength: GraphDistanceMeasure,
  EdgeLengths: GraphEdgePropertyMap,
  DistancesToVertex: MutableGraphVertexPropertyMap,
  UserVisitor: DijkstraVisitor
>: BFSVisitor
where
  SearchSpace.VertexId: IdIndexable,
  EdgeLengths.Graph == SearchSpace,
  EdgeLengths.Value == PathLength,
  DistancesToVertex.Graph == SearchSpace,
  DistancesToVertex.Value == PathLength,
  UserVisitor.Graph == SearchSpace
{
  /// The graph we're operating on is `SearchSpace`.
  public typealias Graph = SearchSpace

  /// The queue of verticies to visit.
  var workList = ConfigurableHeap<
    SearchSpace.VertexId,
    PathLength,
    Int32,  // TODO: make configurable!
    _IdIndexibleDictionaryHeapIndexer<SearchSpace.VertexId, _ConfigurableHeapCursor<Int32>>
  >()
  /// The weights of the edges.
  let edgeLengths: EdgeLengths
  /// The distances from the start vertex to the final verticies.
  var distancesToVertex: DistancesToVertex
  /// The visitor to be called throughout execution.
  var userVisitor: UserVisitor

  init(
    userVisitor: UserVisitor, edgeLengths: EdgeLengths, distancesToVertex: DistancesToVertex,
    startVertex: SearchSpace.VertexId
  ) {
    self.userVisitor = userVisitor
    self.edgeLengths = edgeLengths
    self.distancesToVertex = distancesToVertex
  }

  public mutating func popVertex() -> SearchSpace.VertexId? {
    let tmp = workList.popFront()
    return tmp
  }

  public mutating func discover(vertex: SearchSpace.VertexId, _ graph: inout Graph) throws {
    workList.add(vertex, with: PathLength.effectiveInfinity)  // Add to the back of the workList.
    try userVisitor.discover(vertex: vertex, &graph)
  }

  public mutating func examine(vertex: SearchSpace.VertexId, _ graph: inout Graph) throws {
    try userVisitor.examine(vertex: vertex, &graph)
  }

  public mutating func examine(edge: SearchSpace.EdgeId, _ graph: inout Graph) throws {
    try userVisitor.examine(edge: edge, &graph)
  }

  public mutating func treeEdge(_ edge: SearchSpace.EdgeId, _ graph: inout Graph) throws {
    let decreased = relaxTarget(edge, &graph)
    if decreased {
      try userVisitor.edgeRelaxed(edge, &graph)
    } else {
      try userVisitor.edgeNotRelaxed(edge, &graph)
    }
  }

  public mutating func grayDestination(_ edge: SearchSpace.EdgeId, _ graph: inout Graph) throws {
    let decreased = relaxTarget(edge, &graph)
    if decreased {
      try userVisitor.edgeRelaxed(edge, &graph)
    } else {
      try userVisitor.edgeNotRelaxed(edge, &graph)
    }
  }

  public mutating func blackDestination(_ edge: SearchSpace.EdgeId, _ graph: inout Graph) throws {
    try userVisitor.edgeNotRelaxed(edge, &graph)
  }

  public mutating func finish(vertex: SearchSpace.VertexId, _ graph: inout Graph) throws {
    try userVisitor.finish(vertex: vertex, &graph)
  }

  /// Returns `true` if `edge` relaxes the distance to `graph.target(of: edge)`, false otherwise.
  private mutating func relaxTarget(_ edge: SearchSpace.EdgeId, _ graph: inout Graph) -> Bool {
    let destination = graph.destination(of: edge)
    let sourceDistance = distancesToVertex.get(graph, graph.source(of: edge))
    let destinationDistance = distancesToVertex.get(graph, destination)
    let edgeDistance = edgeLengths.get(graph, edge)
    let pathDistance = sourceDistance + edgeDistance

    if pathDistance < destinationDistance {
      distancesToVertex.set(vertex: destination, in: &graph, to: pathDistance)
      workList.update(destination, withNewPriority: pathDistance)
      return true
    } else {
      return false
    }
  }
}

extension IncidenceGraph where Self: VertexListGraph, VertexId: IdIndexable {
  /// Executes Dijkstra's graph search algorithm, without initializing any data structures.
  ///
  /// This function is designed to be used as a zero-overhead abstraction to be called from other
  /// graph algorithms. Use this overload if you are interested in manually controlling every
  /// aspect. If you would like a higher-level abstraction, consider `dijkstraSearch`.
  public mutating func dijkstraSearch<
    Distance: GraphDistanceMeasure,
    EdgeLengths: GraphEdgePropertyMap,
    DistancesToVertex: MutableGraphVertexPropertyMap,
    VertexVisitationState: MutableGraphVertexPropertyMap,
    Visitor: DijkstraVisitor
  >(
    visitor: inout Visitor,
    vertexVisitationState: inout VertexVisitationState,
    distancesToVertex: inout DistancesToVertex,
    edgeLengths: EdgeLengths,
    startAt startVertex: VertexId
  ) throws
  where
    EdgeLengths.Graph == Self,
    EdgeLengths.Value == Distance,
    DistancesToVertex.Graph == Self,
    DistancesToVertex.Value == Distance,
    VertexVisitationState.Graph == Self,
    VertexVisitationState.Value == VertexColor,
    Visitor.Graph == Self
  {
    distancesToVertex.set(vertex: startVertex, in: &self, to: Distance.zero)
    var dijkstraVisitor = DijkstraBFSVisitor(
      userVisitor: visitor,
      edgeLengths: edgeLengths,
      distancesToVertex: distancesToVertex,
      startVertex: startVertex)
    try breadthFirstSearch(
      visitor: &dijkstraVisitor,
      vertexVisitationState: &vertexVisitationState,
      startAt: [startVertex]
    )
    visitor = dijkstraVisitor.userVisitor
    distancesToVertex = dijkstraVisitor.distancesToVertex
  }

  /// Executes Dijkstra's search algorithm over `graph` from `startVertex` using edge weights from
  /// `edgeLengths`, calling `userVisitor` along the way.
  public mutating func dijkstraSearch<
    Distance: GraphDistanceMeasure,
    EdgeLengths: GraphEdgePropertyMap,
    Visitor: DijkstraVisitor
  >(
    visitor: inout Visitor,
    edgeLengths: EdgeLengths,
    startAt startVertex: VertexId
  ) throws -> TableVertexPropertyMap<Self, Distance>
  where
    EdgeLengths.Graph == Self,
    EdgeLengths.Value == Distance,
    Visitor.Graph == Self
  {
    var vertexVisitationState = TableVertexPropertyMap(repeating: VertexColor.white, for: self)
    var distancesToVertex = TableVertexPropertyMap(
      repeating: Distance.effectiveInfinity,
      for: self)

    try dijkstraSearch(
      visitor: &visitor,
      vertexVisitationState: &vertexVisitationState,
      distancesToVertex: &distancesToVertex,
      edgeLengths: edgeLengths,
      startAt: startVertex)

    return distancesToVertex
  }
}
