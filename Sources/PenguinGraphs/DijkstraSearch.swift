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

/// The events that occur during Dijkstra's search within a graph.
///
/// - SeeAlso: `IncidenceGraph.VertexListGraph`.
public enum DijkstraSearchEvent<SearchSpace: GraphProtocol> {
  /// Identifies a vertex in the search space.
  public typealias Vertex = SearchSpace.VertexId
  /// Identifies an edge in the search space.
  public typealias Edge = SearchSpace.EdgeId

  /// The start of search, recording the starting vertex.
  case start(Vertex)

  /// When a new vertex is discovered in the search space.
  case discover(Vertex)

  /// When a vertex is popped off the priority queue for processing.
  case examineVertex(Vertex)

  /// When an edge is traversed to look for new vertices to discover.
  case examineEdge(Edge)

  /// When the edge forms the final segment in the new shortest path to the destination vertex.
  case edgeRelaxed(Edge)

  /// When the edge does not make up part of a shortest path in the search space.
  case edgeNotRelaxed(Edge)

  /// When a vertex's outgoing edges have all been analyzed.
  case finish(Vertex)
}

// TODO: consider making this more generic / reusible!
private struct HeapQueue<Element: Hashable & IdIndexable, Priority: Comparable & GraphDistanceMeasure>: Queue {
  typealias Underlying = ConfigurableHeap<
    Element,
    Priority,
    Int32,  // TODO: make configurable!
    _IdIndexibleDictionaryHeapIndexer<Element, _ConfigurableHeapCursor<Int32>>
  >
  var underlying = Underlying()

  mutating func push(_ element: Element) {
    underlying.add(element, with: Priority.effectiveInfinity)
  }

  mutating func pop() -> Element? {
    underlying.popFront()
  }
}

// TODO: relax requirements on `VertexId`.
extension IncidenceGraph where Self: VertexListGraph, VertexId: IdIndexable & Hashable {
  /// A hook to observe events that occur during Dijkstra's search.
  public typealias DijkstraSearchCallback = (DijkstraSearchEvent<Self>, inout Self) throws -> Void

  // TODO: modify to take a Priority Queue. Also update doc comment about initialization of data structures!

  /// Executes Dijkstra's graph search algorithm in `self` using the supplied property maps; 
  /// `callback` is called at key events during the search.
  public mutating func dijkstraSearch<
    Distance: GraphDistanceMeasure,
    EdgeLengths: PropertyMap,
    DistancesToVertex: PropertyMap,
    VertexVisitationState: PropertyMap
  >(
    startingAt startVertex: VertexId,
    vertexVisitationState: inout VertexVisitationState,
    distancesToVertex: inout DistancesToVertex,
    edgeLengths: EdgeLengths,
    callback: DijkstraSearchCallback
  ) rethrows
  where
    EdgeLengths.Graph == Self,
    EdgeLengths.Key == EdgeId,
    EdgeLengths.Value == Distance,
    DistancesToVertex.Graph == Self,
    DistancesToVertex.Key == VertexId,
    DistancesToVertex.Value == Distance,
    VertexVisitationState.Graph == Self,
    VertexVisitationState.Key == VertexId,
    VertexVisitationState.Value == VertexColor
  {
    distancesToVertex.set(startVertex, in: &self, to: Distance.zero)
    var workList = HeapQueue<VertexId, Distance>()
    try breadthFirstSearch(
      startingAt: [startVertex],
      workList: &workList,
      vertexVisitationState: &vertexVisitationState) { event, g, q in

      // Determines if the newly discovered path through `edge` is shorter than the previously best
      // known path. If it is shorter, it updates the destination of `edge` with the new distance
      // measurement, and returns true.
      func relaxTarget(_ edge: EdgeId) -> Bool {
        let destination = g.destination(of: edge)
        let sourceDistance = distancesToVertex.get(g.source(of: edge), in: g)
        let destinationDistance = distancesToVertex.get(destination, in: g)
        let edgeDistance = edgeLengths.get(edge, in: g)
        let pathDistance = sourceDistance + edgeDistance

        if pathDistance < destinationDistance {
          distancesToVertex.set(destination, in: &g, to: pathDistance)
          q.underlying.update(destination, withNewPriority: pathDistance)
          return true
        } else {
          return false
        }
      }

      switch event {
      case .start(let v): try callback(.start(v), &g)
      case .discover(let v): try callback(.discover(v), &g)
      case .examineVertex(let v): try callback(.examineVertex(v), &g)
      case .examineEdge(let edge): try callback(.examineEdge(edge), &g)
      case .treeEdge(let edge),
           .grayDestination(let edge):
        if relaxTarget(edge) {
          try callback(.edgeRelaxed(edge), &g)
        } else {
          try callback(.edgeNotRelaxed(edge), &g)
        }
      case .nonTreeEdge: break
      case .blackDestination(let edge): try callback(.edgeNotRelaxed(edge), &g)
      case .finish(let v): try callback(.finish(v), &g)
      }
    }
  }

  /// Executes Dijkstra's search algorithm over `self` from `startVertex` using edge weights from
  /// `edgeLengths`; `callback` is called at key events of the search.
  public mutating func dijkstraSearch<
    Distance: GraphDistanceMeasure,
    EdgeLengths: PropertyMap
  >(
    startingAt startVertex: VertexId,
    edgeLengths: EdgeLengths,
    callback: DijkstraSearchCallback
  ) rethrows -> TablePropertyMap<Self, VertexId, Distance>
  where
    EdgeLengths.Graph == Self,
    EdgeLengths.Key == EdgeId,
    EdgeLengths.Value == Distance
  {
    var vertexVisitationState = TablePropertyMap(repeating: VertexColor.white, forVerticesIn: self)
    var distancesToVertex = TablePropertyMap(
      repeating: Distance.effectiveInfinity,
      forVerticesIn: self)

    try dijkstraSearch(
      startingAt: startVertex,
      vertexVisitationState: &vertexVisitationState,
      distancesToVertex: &distancesToVertex,
      edgeLengths: edgeLengths,
      callback: callback)

    return distancesToVertex
  }
}
