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

/// Removes half of all edges, such that if both (u, v) and (v, u) were in the graph previously,
/// only one will remain afterwards.
///
/// When applied to an `IncidenceGraph` that models an undirected graph (i.e. there are incident
/// edges when queried from both sides), UniqueUndirectedEdges will filter out half.
///
/// If UniqueUndirectedEdges is applied to a graph that doesn't include the edge (u, v) in the
/// `VertexEdgeCollection` of both `u`, and `v`, unspecified behavior will occur.
///
/// To keep using your property maps, simply wrap them with `EdgeFilterPropertyMapAdapter`'s.
public struct UniqueUndirectedEdges<Graph: IncidenceGraph>: EdgeFilterProtocol, DefaultInitializable
where Graph.VertexId: Comparable {
  public init() {}

  /// Returns `true` if `edge` should be excluded from a filtered representation of `graph`.
  public func excludeEdge(_ edge: Graph.EdgeId, _ graph: Graph) -> Bool {
    return graph.source(of: edge) > graph.destination(of: edge)
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

/// Adapts a `PropertyMap` to work on an edge-filtered version of a graph.
public struct EdgeFilterPropertyMapAdapter<
  Underlying: PropertyMap, Filter: EdgeFilterProtocol
>: PropertyMap where Underlying.Graph == Filter.Graph {
  public typealias Graph = EdgeFilterGraph<Underlying.Graph, Filter>
  /// The key to access properties in `self`.
  public typealias Key = Underlying.Key
  /// The values stored in `self`.
  public typealias Value = Underlying.Value

  /// The underlying property map.
  private var underlying: Underlying

  /// Wraps `underlying`.
  public init(_ underlying: Underlying) {
    self.underlying = underlying
  }

  /// Wraps `underlying` for use with `graph`. (This initializer helps type inference along.)
  public init(_ underlying: Underlying, for graph: __shared Graph) {
    self.init(underlying)
  }

  /// Retrieves the property value for `key` in `graph`.
  public func get(_ key: Key, in graph: Graph) -> Value {
    underlying.get(key, in: graph.underlying)
  }

  /// Sets the property `newValue` for `key` in `graph`.
  public mutating func set(_ key: Key, in graph: inout Graph, to newValue: Value) {
    underlying.set(key, in: &graph.underlying, to: newValue)
  }
}

extension EdgeFilterPropertyMapAdapter: ExternalPropertyMap where Underlying: ExternalPropertyMap {
  /// Accesses the `Value` for a given `Key`.
  public subscript(key: Key) -> Value {
    get { underlying[key] }
    set { underlying[key] = newValue }
  }
}

extension EdgeFilterGraph: SearchDefaultsGraph where Underlying: SearchDefaultsGraph {
  /// Makes a default color map where every vertex is set to `color`.
  public func makeDefaultColorMap(repeating color: VertexColor) -> EdgeFilterPropertyMapAdapter<Underlying.DefaultColorMap, EdgeFilter> {
    EdgeFilterPropertyMapAdapter(underlying.makeDefaultColorMap(repeating: color))
  }

  /// Makes a default int map for every vertex.
  public func makeDefaultVertexIntMap(repeating value: Int) -> EdgeFilterPropertyMapAdapter<Underlying.DefaultVertexIntMap, EdgeFilter> {
    EdgeFilterPropertyMapAdapter(underlying.makeDefaultVertexIntMap(repeating: value))
  }

  /// Makes a default vertex property map mapping vertices.
  public func makeDefaultVertexVertexMap(repeating vertex: VertexId) -> EdgeFilterPropertyMapAdapter<Underlying.DefaultVertexVertexMap, EdgeFilter> {
    EdgeFilterPropertyMapAdapter(underlying.makeDefaultVertexVertexMap(repeating: vertex))
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

extension IncidenceGraph where VertexId: Comparable {
  /// Returns a graph where undirected edges are de-duplicated so they only appear once when
  /// traversing all incidences for all vertices.
  ///
  /// This transformation is especially useful when copying from an undirected representation to
  /// another undirected representation. Example:
  ///
  /// ```
  /// let s = UndirectedStarGraph(n: 5)
  /// let l = SimpleUndirectedAdjacencyList(s.uniquingUndirectedEdges())
  /// // s and l now represent the same logical graph.
  /// ```
  public func uniquingUndirectedEdges() -> EdgeFilterGraph<Self, UniqueUndirectedEdges<Self>> {
    filterEdges(UniqueUndirectedEdges())
  }
}

/// Transposes an underlying graph.
///
/// The transpose of a graph of the same number of vertices, but where the source and destination of
/// every edge is reversed. `TransposeGraph` adapts a graph in constant space and constant time to
/// operate as its transpose.
///
/// To continue to use property maps with the new graph, simply wrap them in
/// `TransposeGraphPropertyMapAdapter`.
///
/// Note: the VerteId's and EdgeId's from the original graph are preserved, which ensures property
/// maps continue to function.
///
/// All operations on a `TransposeGraph` operate with identical complexity as the underlying graph.
public struct TransposeGraph<Underlying: BidirectionalGraph>: BidirectionalGraph {
  /// The underlying graph to transpose.
  fileprivate var underlying: Underlying

  /// Creates a graph that is a transpose of `underlying`.
  public init(_ underlying: Underlying) {
    self.underlying = underlying
  }

  /// The name of a vertex in `self`.
  public typealias VertexId = Underlying.VertexId
  /// The name of an edge in `self`.
  public typealias EdgeId = Underlying.EdgeId

  /// Returns the collection of edges whose source is vertex.
  public func edges(from vertex: VertexId) -> Underlying.VertexInEdgeCollection {
    underlying.edges(to: vertex)
  }

  /// Returns the source of `edge`.
  public func source(of edge: EdgeId) -> VertexId {
    underlying.destination(of: edge)
  }

  /// Returns the destination of `edge`.
  public func destination(of edge: EdgeId) -> VertexId {
    underlying.source(of: edge)
  }

  /// Returns the number of edges whose source is `vertex`.
  public func outDegree(of vertex: VertexId) -> Int {
    underlying.inDegree(of: vertex)
  }

  /// Returns the collection of edges whose destination is `vertex`.
  public func edges(to vertex: VertexId) -> Underlying.VertexEdgeCollection {
    underlying.edges(from: vertex)
  }

  /// Returns the number of "in-edges" of `vertex`.
  public func inDegree(of vertex: VertexId) -> Int {
    underlying.outDegree(of: vertex)
  }

  /// Returns the number of "in-edges" plus "out-edges" of `vertex` in `self`.
  public func degree(of vertex: VertexId) -> Int {
    underlying.degree(of: vertex)
  }
}

extension TransposeGraph: VertexListGraph where Underlying: VertexListGraph {
  public var vertices: Underlying.VertexCollection { underlying.vertices }
  public var vertexCount: Int { underlying.vertexCount }
}

extension TransposeGraph: EdgeListGraph where Underlying: EdgeListGraph {
  public var edgeCount: Int { underlying.edgeCount }
  public var edges: Underlying.EdgeCollection { underlying.edges }
}

extension TransposeGraph: PropertyGraph where Underlying: PropertyGraph {
  /// Accesses the storage associated with `vertex`.
  public subscript(vertex vertex: VertexId) -> Underlying.Vertex {
    get { underlying[vertex: vertex] }
    _modify { yield &underlying[vertex: vertex] }
  }

  /// Accesses the storage associated with `edge`.
  public subscript(edge edge: EdgeId) -> Underlying.Edge {
    get { underlying[edge: edge] }
    _modify { yield &underlying[edge: edge] }
  }
}

// TODO: Consider having a MutableGraph conformance for TransposeGraph.

extension TransposeGraph: SearchDefaultsGraph where Underlying: SearchDefaultsGraph {
  /// Makes a default color map where every vertex is set to `color`.
  public func makeDefaultColorMap(repeating color: VertexColor) -> TransposeGraphPropertyMapAdapter<Underlying.DefaultColorMap> {
    TransposeGraphPropertyMapAdapter(underlying.makeDefaultColorMap(repeating: color))
  }

  /// Makes a default int map for every vertex.
  public func makeDefaultVertexIntMap(repeating value: Int) -> TransposeGraphPropertyMapAdapter<Underlying.DefaultVertexIntMap> {
    TransposeGraphPropertyMapAdapter(underlying.makeDefaultVertexIntMap(repeating: value))
  }

  /// Makes a default vertex property map mapping vertices.
  public func makeDefaultVertexVertexMap(repeating vertex: VertexId) -> TransposeGraphPropertyMapAdapter<Underlying.DefaultVertexVertexMap> {
    TransposeGraphPropertyMapAdapter(underlying.makeDefaultVertexVertexMap(repeating: vertex))
  }
}

/// Adapts a property map for a graph to be used with its transpose.
///
/// - SeeAlso: `TransposeGraph`
public struct TransposeGraphPropertyMapAdapter<Underlying: PropertyMap>: PropertyMap where Underlying.Graph: BidirectionalGraph {
  /// The graph this property map operates upon.
  public typealias Graph = TransposeGraph<Underlying.Graph>
  /// The identifier used to access data.
  public typealias Key = Underlying.Key
  /// The value of data stored in `self`.
  public typealias Value = Underlying.Value

  /// The underlying property map.
  private var underlying: Underlying

  /// Wraps `underlying` for use with a transposed version of .
  public init(_ underlying: Underlying) {
    self.underlying = underlying
  }

  /// Retrieves the property value for `key` in `graph`.
  public func get(_ key: Key, in graph: Graph) -> Value {
    underlying.get(key, in: graph.underlying)
  }

  /// Sets the property `newValue` for `key` in `graph`.
  public mutating func set(_ key: Key, in graph: inout Graph, to newValue: Value) {
    underlying.set(key, in: &graph.underlying, to: newValue)
  }
}

extension TransposeGraphPropertyMapAdapter: ExternalPropertyMap where Underlying: ExternalPropertyMap {
  /// Accesses the `Value` for a given `Key`.
  public subscript(key: Key) -> Value {
    get { underlying[key] }
    set { underlying[key] = newValue }
  }
}

extension BidirectionalGraph {

  /// Returns a transposed representation of `self`.
  ///
  /// A graph transpose is a graph of the same size and shape, but where the source and destination
  /// of every edge has simpliy been reversed.
  ///
  /// To use property maps with the resulting transposed graph, simpliy wrap them in
  /// `TransposeGraphPropertyMapAdapter`.
  ///
  /// - Complexity: O(1)
  public func transposed() -> TransposeGraph<Self> {
    TransposeGraph(self)
  }
}

/// A graph containing all the vertices and edges of a base graph, augmented with all the edges of
/// a second graph data structure.
///
/// A `UnionEdgesGraph` allows overlaying the edges of one graph onto the edges of another graph.
/// This operation can be useful when viewing the same set of vertices in multiple ways. The
/// `UnionEdgesGraph` does not modify or even copy either of the two underlying graphs, and all
/// operations on the `UnionEdgesGraph` occur with identical complexity to the underlying graphs'
/// operations.
///
/// Note: If many operations will be done on the resulting graph, it can sometimes be more efficient
/// to flatten the extra edges into the base graph (so long as `Base` is a `MutableGraph`) by
/// calling `base.addEdges(from: extraEdges)`.
///
/// Beware: it is up to the user to ensure that all edges in `ExtraEdges` point to valid vertices in
/// `Base`, and that `ExtraEdges.edges(from:)` can be called with every valid vertex in `Base`.
///
/// - SeeAlso: `UnionEdgesGraphVertexPropertyMapAdapter`.
public struct UnionEdgesGraph<Base: IncidenceGraph, ExtraEdges: IncidenceGraph>: IncidenceGraph
where Base.VertexId == ExtraEdges.VertexId {
  /// The name of a vertex in `self`.
  public typealias VertexId = Base.VertexId
  /// The name of a vertex in `self`.
  public typealias EdgeId = Either<Base.EdgeId, ExtraEdges.EdgeId>

  /// The base graph.
  fileprivate var base: Base
  /// A graph containing extra edges.
  fileprivate var extraEdges: ExtraEdges

  /// Creates a graph based on `base`, augmented with edges in `extraEdges`.
  public init(_ base: Base, _ extraEdges: ExtraEdges) {
    self.base = base
    self.extraEdges = extraEdges
  }

  /// A collection of edges from a single vertex in `self`.
  public typealias VertexEdgeCollection =
    ConcatenatedCollection<
      LazyMapCollection<Base.VertexEdgeCollection, EdgeId>,
      LazyMapCollection<ExtraEdges.VertexEdgeCollection, EdgeId>>

  /// A collection of edges from a single vertex.
  public func edges(from vertex: VertexId) -> VertexEdgeCollection {
    base.edges(from: vertex).lazy.map(EdgeId.a).concatenated(with:
      extraEdges.edges(from: vertex).lazy.map(EdgeId.b))
  }

  /// Returns the source vertex of `edge`.
  public func source(of edge: EdgeId) -> VertexId {
    switch edge {
    case .a(let edge): return base.source(of: edge)
    case .b(let edge): return extraEdges.source(of: edge)
    }
  }

  /// Returns the destionation vertex of `edge`.
  public func destination(of edge: EdgeId) -> VertexId {
    switch edge {
    case .a(let edge): return base.destination(of: edge)
    case .b(let edge): return extraEdges.destination(of: edge)
    }
  }
}

extension UnionEdgesGraph: BidirectionalGraph where Base: BidirectionalGraph, ExtraEdges: BidirectionalGraph {
  /// A collection of edges to a vertex.
  public typealias VertexInEdgeCollection = ConcatenatedCollection<
    LazyMapCollection<Base.VertexInEdgeCollection, EdgeId>,
    LazyMapCollection<ExtraEdges.VertexInEdgeCollection, EdgeId>>

  /// Returns a collection of all edges in `self` whose destination is `vertex`.
  public func edges(to vertex: VertexId) -> VertexInEdgeCollection {
    base.edges(to: vertex).lazy.map(EdgeId.a).concatenated(with:
      extraEdges.edges(to: vertex).lazy.map(EdgeId.b))
  }
}

extension UnionEdgesGraph: PropertyGraph
where Base: PropertyGraph, ExtraEdges: PropertyGraph, ExtraEdges.Edge == Base.Edge {
  /// Arbitrary data asssociated with every vertex.
  public typealias Vertex = Base.Vertex

  /// Arbitrary data associated with every edge.
  public typealias Edge = Base.Edge

  /// Accesses the data associated with `vertex`.
  public subscript(vertex vertex: VertexId) -> Vertex {
    get { base[vertex: vertex] }
    _modify { yield &base[vertex: vertex] }
  }

  /// Access the data associated with `edge`.
  public subscript(edge edge: EdgeId) -> Edge {
    get {
      switch edge {
      case .a(let edge): return base[edge: edge]
      case .b(let edge): return extraEdges[edge: edge]
      }
    }

    _modify {
      switch edge {
      case .a(let edge): yield &base[edge: edge]
      case .b(let edge): yield &extraEdges[edge: edge]
      }
    }
  }
}

extension UnionEdgesGraph: VertexListGraph where Base: VertexListGraph {
  /// The number of vertices in `self`.
  public var vertexCount: Int { base.vertexCount }
  /// The collection of all vertices in `self`.
  public var vertices: Base.VertexCollection { base.vertices }
}

extension UnionEdgesGraph: EdgeListGraph where Base: EdgeListGraph, ExtraEdges: EdgeListGraph {
  public typealias EdgeCollection = ConcatenatedCollection<
    LazyMapCollection<Base.EdgeCollection, EdgeId>,
    LazyMapCollection<ExtraEdges.EdgeCollection, EdgeId>>

  /// All edges in `self`.
  public var edges: EdgeCollection {
    base.edges.lazy.map(EdgeId.a).concatenated(with: extraEdges.edges.lazy.map(EdgeId.b))
  }
}

extension UnionEdgesGraph: SearchDefaultsGraph where Base: SearchDefaultsGraph {
  /// Makes a default color map where every vertex is set to `color`.
  public func makeDefaultColorMap(repeating color: VertexColor) -> UnionEdgesGraphVertexPropertyMapAdapter<Base.DefaultColorMap, ExtraEdges> {
    UnionEdgesGraphVertexPropertyMapAdapter(base.makeDefaultColorMap(repeating: color))
  }

  /// Makes a default int map for every vertex.
  public func makeDefaultVertexIntMap(repeating value: Int) -> UnionEdgesGraphVertexPropertyMapAdapter<Base.DefaultVertexIntMap, ExtraEdges> {
    UnionEdgesGraphVertexPropertyMapAdapter(base.makeDefaultVertexIntMap(repeating: value))
  }

  /// Makes a default vertex property map mapping vertices.
  public func makeDefaultVertexVertexMap(repeating vertex: VertexId) -> UnionEdgesGraphVertexPropertyMapAdapter<Base.DefaultVertexVertexMap, ExtraEdges> {
    UnionEdgesGraphVertexPropertyMapAdapter(base.makeDefaultVertexVertexMap(repeating: vertex))
  }
}

/// Adapts a property map for a graph to be used with the graph unioned with extra edges.
///
/// - SeeAlso: `UnionEdgesGraph`
public struct UnionEdgesGraphVertexPropertyMapAdapter<
  Underlying: PropertyMap,
  ExtraEdges: IncidenceGraph
>: PropertyMap
where
  Underlying.Graph: IncidenceGraph,
  Underlying.Graph.VertexId == ExtraEdges.VertexId,
  Underlying.Key == Underlying.Graph.VertexId
{
  /// The graph this property map operates upon.
  public typealias Graph = UnionEdgesGraph<Underlying.Graph, ExtraEdges>
  /// The identifier used to access data.
  public typealias Key = Graph.VertexId
  /// The value of data stored in `self`.
  public typealias Value = Underlying.Value

  /// The underlying property map.
  private var underlying: Underlying

  /// Wraps `underlying` for use with a transposed version of its graph.
  public init(_ underlying: Underlying) {
    self.underlying = underlying
  }

  /// Wraps `underlying` for use with `graph`. (`graph` is taken to help type inference along.)
  public init(_ underlying: Underlying, for graph: __shared Graph) {
    self.init(underlying)
  }

  /// Retrieves the property value for `key` in `graph`.
  public func get(_ key: Key, in graph: Graph) -> Value {
    underlying.get(key, in: graph.base)
  }

  /// Sets the property `newValue` for `key` in `graph`.
  public mutating func set(_ key: Key, in graph: inout Graph, to newValue: Value) {
    underlying.set(key, in: &graph.base, to: newValue)
  }
}

extension UnionEdgesGraphVertexPropertyMapAdapter: ExternalPropertyMap where Underlying: ExternalPropertyMap {
  /// Accesses the `Value` for a given `Key`.
  public subscript(key: Key) -> Value {
    get { underlying[key] }
    set { underlying[key] = newValue }
  }
}

extension IncidenceGraph {
  /// Returns a new graph containing all the vertices in `self`, augmented with edges from `other`.
  ///
  /// - Complexity: O(1)
  public func unionEdges<Other: IncidenceGraph>(with other: Other) -> UnionEdgesGraph<Self, Other>
  where Other.VertexId == VertexId
  {
    UnionEdgesGraph(self, other)
  }
}
