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


public enum DijkstraSearchEvent<Graph: GraphProtocol> {
  public typealias Vertex = Graph.VertexId
  public typealias Edge = Graph.EdgeId

  case discover(Vertex)
  case examineVertex(Vertex)
  case examineEdge(Edge)
  case edgeRelaxed(Edge)
  case edgeNotRelaxed(Edge)
  case finish(Vertex)
}

// TODO: make this more generic / reusible!!
private struct HeapQueue<Element: Hashable & IdIndexable, Priority: Comparable & GraphDistanceMeasure>: Queue {
  typealias Underlying = ConfigurableHeap<
    Element,
    Priority,
    Int32,  // TODO: make configurable!
    _IdIndexibleDictionaryHeapIndexer<Element, _ConfigurableHeapCursor<Int32>>
  >
  var underlying = Underlying()

  public mutating func push(_ element: Element) {
    underlying.add(element, with: Priority.effectiveInfinity)
  }

  public mutating func pop() -> Element? {
    underlying.popFront()
  }
}

extension IncidenceGraph where Self: VertexListGraph, VertexId: IdIndexable & Hashable {
  public typealias DijkstraSearchCallback = (DijkstraSearchEvent<Self>, inout Self) throws -> Void

  // TODO: modify to take a Priority Queue. Also update doc comment about initialization of data structures!
  /// Executes Dijkstra's graph search algorithm, without initializing any data structures.
  ///
  /// This function is designed to be used as a zero-overhead abstraction to be called from other
  /// graph algorithms. Use this overload if you are interested in manually controlling every
  /// aspect. If you would like a higher-level abstraction, consider `dijkstraSearch`.
  public mutating func dijkstraSearch<
    Distance: GraphDistanceMeasure,
    EdgeLengths: GraphEdgePropertyMap,
    DistancesToVertex: MutableGraphVertexPropertyMap,
    VertexVisitationState: MutableGraphVertexPropertyMap
  >(
    startingAt startVertex: VertexId,
    vertexVisitationState: inout VertexVisitationState,
    distancesToVertex: inout DistancesToVertex,
    edgeLengths: EdgeLengths,
    callback: DijkstraSearchCallback
  ) rethrows
  where
    EdgeLengths.Graph == Self,
    EdgeLengths.Value == Distance,
    DistancesToVertex.Graph == Self,
    DistancesToVertex.Value == Distance,
    VertexVisitationState.Graph == Self,
    VertexVisitationState.Value == VertexColor
  {
    distancesToVertex.set(vertex: startVertex, in: &self, to: Distance.zero)
    var workList = HeapQueue<VertexId, Distance>()
    try breadthFirstSearch(
      startingAt: [startVertex],
      workList: &workList,
      vertexVisitationState: &vertexVisitationState) { e, g, q in

      func relaxTarget(_ edge: EdgeId) -> Bool {
        let destination = g.destination(of: edge)
        let sourceDistance = distancesToVertex.get(g, g.source(of: edge))
        let destinationDistance = distancesToVertex.get(g, destination)
        let edgeDistance = edgeLengths.get(g, edge)
        let pathDistance = sourceDistance + edgeDistance

        if pathDistance < destinationDistance {
          distancesToVertex.set(vertex: destination, in: &g, to: pathDistance)
          q.underlying.update(destination, withNewPriority: pathDistance)
          return true
        } else {
          return false
        }
      }

      switch e {
      case .start: break // TODO: REMOVE ME!
      case let .discover(v): try callback(.discover(v), &g)
      case let .examineVertex(v): try callback(.examineVertex(v), &g)
      case let .examineEdge(e): try callback(.examineEdge(e), &g)
      case let .treeEdge(e):
        if relaxTarget(e) {
          try callback(.edgeRelaxed(e), &g)
        } else {
          try callback(.edgeNotRelaxed(e), &g)
        }
      case .nonTreeEdge: break
      case let .grayDestination(e): // TODO: Unify two pattern matches into one!
        if relaxTarget(e) {
          try callback(.edgeRelaxed(e), &g)
        } else {
          try callback(.edgeNotRelaxed(e), &g)
        }
      case let .blackDestination(e): try callback(.edgeNotRelaxed(e), &g)
      case let .finish(v): try callback(.finish(v), &g)
      }
    }
  }

  /// Executes Dijkstra's search algorithm over `graph` from `startVertex` using edge weights from
  /// `edgeLengths`, calling `userVisitor` along the way.
  public mutating func dijkstraSearch<
    Distance: GraphDistanceMeasure,
    EdgeLengths: GraphEdgePropertyMap
  >(
    startingAt startVertex: VertexId,
    edgeLengths: EdgeLengths,
    callback: DijkstraSearchCallback
  ) rethrows -> TableVertexPropertyMap<Self, Distance>
  where
    EdgeLengths.Graph == Self,
    EdgeLengths.Value == Distance
  {
    var vertexVisitationState = TableVertexPropertyMap(repeating: VertexColor.white, for: self)
    var distancesToVertex = TableVertexPropertyMap(
      repeating: Distance.effectiveInfinity,
      for: self)

    try dijkstraSearch(
      startingAt: startVertex,
      vertexVisitationState: &vertexVisitationState,
      distancesToVertex: &distancesToVertex,
      edgeLengths: edgeLengths,
      callback: callback)

    return distancesToVertex
  }
}
