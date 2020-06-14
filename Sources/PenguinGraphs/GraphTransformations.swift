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

/// Allows dynamically excluding edges that meet a given criteria from a graph.
public protocol EdgeFilterProtocol {
  /// The graph to filter edges from.
  associatedtype Graph: GraphProtocol

  /// Returns `true` if `edge` should be excluded from a filtered representation of `graph`.
  func excludeEdge(_ edge: Graph.EdgeId, _ graph: Graph) -> Bool
}

/// A filter that excludes edges whose source and destiation is the same.
public struct ExcludeSelfEdges<Graph: IncidenceGraph>: EdgeFilterProtocol, DefaultInitializable {
  public init() {}

  /// Returns `true` if `edge` should be excluded from a filtered representation of `graph`.
  public func excludeEdge(_ edge: Graph.EdgeId, _ graph: Graph) -> Bool {
    return graph.source(of: edge) == graph.destination(of: edge)
  }
}

// TODO: Add a predicate edge filter.

/// Wraps an underlying graph and filters out undesired edges.
public struct EdgeFilterGraph<Underlying, EdgeFilter: EdgeFilterProtocol>: GraphProtocol
where EdgeFilter.Graph == Underlying {
  /// The underlying graph data structure.
  fileprivate var underlying: Underlying
  /// The filter to apply.
  fileprivate let filter: EdgeFilter

  /// The name of a vertex in `self`.
  public typealias VertexId = Underlying.VertexId

  /// The name of an edge in `self`.
  public typealias EdgeId = Underlying.EdgeId
}

extension EdgeFilterGraph: VertexListGraph where Underlying: VertexListGraph {
  /// All vertices in `self`.
  public var vertices: Underlying.VertexCollection { underlying.vertices }
}

extension EdgeFilterGraph {
  /// A sparse collection that excludes edges based on the user-provided filter.
  public struct EdgeFilteringCollection<C: Collection>: Collection where C.Element == EdgeId {
    /// Indices into `self`.
    public typealias Index = C.Index
    /// The elements in `self`.
    public typealias EdgeId = Underlying.EdgeId

    fileprivate var underlying: Underlying
    fileprivate var underlyingEdges: C
    fileprivate var edgeFilter: EdgeFilter

    /// The first valid index in `self`.
    public var startIndex: Index {
      underlyingEdges.indices.first { !edgeFilter.excludeEdge(underlyingEdges[$0], underlying) } ?? endIndex
    }

    /// One past the last valid index in `self`.
    public var endIndex: Index {
      underlyingEdges.endIndex
    }

    /// Returns the next valid index in `self` after `index`.
    public func index(after index: Index) -> Index {
      var i = underlyingEdges.index(after: index)
      while i != underlyingEdges.endIndex {
        if !edgeFilter.excludeEdge(underlyingEdges[i], underlying) { return i }
        i = underlyingEdges.index(after: i)
      }
      return underlyingEdges.endIndex
    }

    /// Accesses the element at `index`.
    public subscript(index: Index) -> EdgeId {
      assert(!edgeFilter.excludeEdge(underlyingEdges[index], underlying),
        "Accessing excluded edge \(underlyingEdges[index])")
      return underlyingEdges[index]
    }
  }
}

extension EdgeFilterGraph: EdgeListGraph where Underlying: EdgeListGraph {
  public var edges: EdgeFilteringCollection<Underlying.EdgeCollection> {
    EdgeFilteringCollection(
      underlying: underlying,
      underlyingEdges: underlying.edges,
      edgeFilter: filter)
  }
  /// Returns the source of `edge`.
  public func source(of edge: EdgeId) -> VertexId { underlying.source(of: edge) }
  /// Returns the destination of `edge`.
  public func destination(of edge: EdgeId) -> VertexId { underlying.destination(of: edge) }
}

extension EdgeFilterGraph: IncidenceGraph where Underlying: IncidenceGraph {
  /// Returns a collection of all edges whose source is `vertex` in `self`.
  public func edges(from vertex: VertexId) -> EdgeFilteringCollection<Underlying.VertexEdgeCollection> {
    EdgeFilteringCollection(
      underlying: underlying,
      underlyingEdges: underlying.edges(from: vertex),
      edgeFilter: filter)
  }
  /// Returns the source of `edge`.
  public func source(of edge: EdgeId) -> VertexId { underlying.source(of: edge) }
  /// Returns the destination of `edge`.
  public func destination(of edge: EdgeId) -> VertexId { underlying.destination(of: edge) }
}

extension EdgeFilterGraph: BidirectionalGraph where Underlying: BidirectionalGraph {
  public func edges(to vertex: VertexId) -> EdgeFilteringCollection<Underlying.VertexInEdgeCollection> {
    EdgeFilteringCollection(
      underlying: underlying,
      underlyingEdges: underlying.edges(to: vertex),
      edgeFilter: filter)
  }
}

extension EdgeFilterGraph: PropertyGraph where Underlying: PropertyGraph {
  public subscript(vertex vertex: VertexId) -> Underlying.Vertex {
    get { underlying[vertex: vertex] }
    _modify { yield &underlying[vertex: vertex] }
  }

  public subscript(edge edge: EdgeId) -> Underlying.Edge {
    get { underlying[edge: edge] }
    _modify { yield &underlying[edge: edge] }
  }
}

extension GraphProtocol {
  /// Returns a graph where all edges that do not pass a filter are excluded.
  public func filterEdges<EdgeFilter: EdgeFilterProtocol>(
    _ filter: EdgeFilter
  ) -> EdgeFilterGraph<Self, EdgeFilter> where EdgeFilter.Graph == Self {
    EdgeFilterGraph(underlying: self, filter: filter)
  }
}

extension IncidenceGraph {
  /// Returns a graph that contains no edges whose source and destination is the same.
  public func excludingSelfLoops() -> EdgeFilterGraph<Self, ExcludeSelfEdges<Self>> {
    filterEdges(ExcludeSelfEdges())
  }
}
