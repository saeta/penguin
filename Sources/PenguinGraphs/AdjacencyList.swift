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

import PenguinParallel
import PenguinStructures

/*

Implementers note
=================

This file implements a variety of adjacency lists, each with different tradeoffs. Common
functionality is factored out into extensions on protocols so they can be shared among a variety
of concrete graph types. Additionally, this file defines a number of "internal" types (both
protocols and structs) that suppport the graph implementations. The structs are eventually exposed
publicly as typealiases for associated types on the concrete graph implementations.

The shared protocols are:
 - AdjacencyListProtocol. This protocol defines common implementations for:
     - VertexListGraph (minus the compiler bug... see below).
     - EdgeListGraph
 - DirectedAdjacencyListProtocol. THis protocol defines common implementations for:
     - IncidenceGraph
     - PropertyGraph (TODO: Move me to AdjacencyListProtocol.)
     - ParallelGraph

The concrete graph types defined in this file include:
 - DirectedAdjacencyList
 - BidirectionalAdjacencyList
 - UndirectedAdjacencyList
 - _DirectedAdjacencyList_ParallelProjection

Internal protocols include:
 - _AdjacencyListPerEdge
 - _AdjacencyListPerVertex

Internal struct's, that are used as part of the graph implementations include:
 - _AdjacencyList_EdgeId
 - _AdjacencyList_EdgeCollection
 - _AdjacencyList_VertexEdgeCollection

*/

/// A simple AdjacencyList with no data associated with each vertex or edge, and a maximum of 2^32-1
/// vertices.
public typealias SimpleAdjacencyList = DirectedAdjacencyList<
  Empty, Empty, UInt32
>

// MARK: - AdjacencyListProtocol

// TODO: Generalize `AdjacencyListProtocol` over collection type (e.g. slices, bufferpointers, etc).

/// A general purpose [adjacency list](https://en.wikipedia.org/wiki/Adjacency_list) graph.
///
/// Adjacency list representations of graphs are flexible and common. This protocol abstracts over
/// the specific underlying storage of the data structure, and implements a variety of graph APIs on
/// top of the basic storage:
///
///  - `VertexListGraph`
///  - `EdgeListGraph`
///  - `IncidenceGraph`
///  - `MutableGraph` (implied by `MutablePropertyGraph`)
///  - `PropertyGraph` (implied by `MutablePropertyGraph`)
/// 
/// And can additionally conform to:
///
///  - `BidirectionalGraph`
///
/// Types conforming to `AdjacencyList` can implement directed, bidirectional, or undirected graphs.
///
/// AdjacencyList types allow storing arbitrary additional data with each vertex and edge. If you
/// select a zero-sized type (such as `Empty`), all overhead is optimized away by the Swift
/// compiler.
///
/// > Note: because tuples cannot yet conform to protocols, we have to use a separate type instead
/// > of `Void`.
///
/// AdjacencyList is parameterized by the `RawId` which can be carefully tuned to save memory.
/// A good default is `UInt32`, unless you are trying to represent more than 2^31 vertices.
///
/// - SeeAlso: `DirectedAdjacencyList`
/// - SeeAlso: `BidirectionalAdjacencyList`
/// - SeeAlso: `UndirectedAdjacencyList`
public protocol AdjacencyListProtocol:
  VertexListGraph,
  EdgeListGraph,
  IncidenceGraph,
  MutablePropertyGraph,
  DefaultInitializable 
where
  VertexCollection == Range<RawId>,
  EdgeCollection == _AdjacencyList_EdgeCollection<_Storage>
{
  /// Storage for indices into arrays within `self`.
  ///
  /// Indices into arrays in Swift are always `Int`. But because a graph often needs to store a lot
  /// of indices, it can be valuable to store only a subset of the bits (e.g. only the lower 32), so
  /// long as the user promises there won't be an overflow. As long as no parallel edges are used,
  /// and the total number of vertices in `self` is below 2^31, then `UInt32` is sufficient,
  /// resulting in a ~2x increase in graph memory efficiency.
  associatedtype RawId where RawId.Stride: SignedInteger  // RawId: BinaryInteger is implied.

  /// Storage associated with each edge in `self`.
  associatedtype _EdgeData  // _EdgeData: _AdjacencyListPerEdge is implied.
    where _EdgeData.VertexId == VertexId, _EdgeData.Edge == Edge

  /// Storage associated with each vertex in `self`.
  associatedtype _VertexData: _AdjacencyListPerVertex
    where _VertexData.Vertex == Vertex, _VertexData.EdgeData == _EdgeData

  /// The data structure containing all of the information in `self`.
  typealias _Storage = [_VertexData]

  // TODO: We're hanging a bunch of implementation off of `AdjacencyListProtocol`... would be nice
  // if we didn't have to make `_storage` public.

  /// The data structure containing all of the information in `self`.
  var _storage: _Storage { get set }
}

/// An identifier for an edge.
///
/// - SeeAlso: `AdjacencyList.EdgeId`
public struct _AdjacencyList_EdgeId<RawId: BinaryInteger>: Equatable, Hashable, Comparable {
  /// An identifier for a vertex.
  public typealias VertexId = RawId
  /// The source vertex of the edge.
  fileprivate let source: VertexId
  /// The index into the array of edges associated with `source` to find information associated with
  /// the edge represented by `self`.
  fileprivate let offset: RawId

  /// Returns true if `lhs` should be ordered before `rhs`.
  static public func < (lhs: Self, rhs: Self) -> Bool {
    if lhs.source < rhs.source { return true }
    if lhs.source == rhs.source { return lhs.offset < rhs.offset }
    return false
  }

  /// Index into `AdjacencyList._storage` associated with the source vertex.
  fileprivate var srcIdx: Int { Int(source) }
  /// The logical index into `AdjacencyList._storage[srcIdx].edges`.
  fileprivate var edgeIdx: Int { Int(offset) }
}

/// Data associated with each edge in an `AdjacencyList`.
public protocol _AdjacencyListPerEdge {
  /// Identifier for a vertex in a graph.
  associatedtype VertexId: BinaryInteger
  /// Arbitrary, user-supplied data associated with each edge.
  associatedtype Edge: DefaultInitializable

  /// The destination vertex of the edge represented by `self`.
  var destination: VertexId { get set }

  /// The user-supplied arbitrary data associated with the edge represented by `self`.
  var data: Edge { get set }
}

/// Data associated with each vertex in an `AdjacencyList`.
public protocol _AdjacencyListPerVertex {
  /// Arbitrary, user-supplied data associated with each vertex.
  associatedtype Vertex: DefaultInitializable
  /// Collection of information regarding edges originating from this logical node.
  associatedtype EdgeData: _AdjacencyListPerEdge

  /// The arbitrary, user-supplied data associated with the vertex represented by `self`.
  var data: Vertex { get set }
  /// The collection of edges starting from the vertex represented by `self`.
  var edges: [EdgeData] { get set }
}

// MARK: - AdjacencyListProtocol implementation

extension AdjacencyListProtocol {
  /// Ensures `id` is a valid vertex in `self`, halting execution otherwise.
  fileprivate func assertValid(_ id: VertexId, name: StaticString? = nil) {
    func makeName() -> String {
      if let name = name { return " (\(name))" }
      return ""
    }
    assert(Int(id) < _storage.count, "Vertex \(id)\(makeName()) is not valid.")
  }

  /// Ensures `id` is a valid edge in `self`, halting execution otherwise.
  fileprivate func assertValid(_ id: EdgeId) {
    assertValid(id.source, name: "source")
    assert(id.edgeIdx < _storage[id.srcIdx].edges.count, "EdgeId \(id) is not valid.")
  }

  /// Ensures there is sufficient storage for `capacity` vertices in `self`.
  public mutating func reserveVertexStorage(_ capacity: Int) {
    _storage.reserveCapacity(capacity)
  }

  /// Ensures there is sufficient storage for `capacity` edges whose source is `vertex`.
  public mutating func reserveEdgeStorage(_ capacity: Int, for vertex: VertexId) {
    // TODO: verify we're not accidentally quadratic!
    _storage[Int(vertex)].edges.reserveCapacity(capacity)
  }
}

// MARK: - AdjacencyListProtocol: VertexListGraph

extension AdjacencyListProtocol {
  /// The total number of vertices in the graph.
  public var vertexCount: Int { _storage.count }

  // Uncommenting the followign line (as an alternate implementation) crashes the compiler!
  // public var vertices: Range<RawId> { 0..<RawId(vertexCount) }  
}

// MARK: - AdjacencyListProtocol: EdgeListGraph

extension AdjacencyListProtocol {
  /// The total number of edges within the graph.
  ///
  /// - Complexity: O(|V|)
  public var edgeCount: Int { _storage.reduce(0) { $0 + $1.edges.count } }

  /// A collection of all edges in `self`.
  public var edges: EdgeCollection { EdgeCollection(storage: _storage) }

  /// Returns the source vertex of `edge`.
  public func source(of edge: EdgeId) -> VertexId {
    edge.source
  }

  /// Returns the destination vertex of `edge`.
  public func destination(of edge: EdgeId) -> VertexId {
    _storage[edge.srcIdx].edges[edge.edgeIdx].destination
  }
}

// TODO: _AdjacencyList_EdgeCollection would be a good candidate for a "2-dimensional" or 
// "hierarchical collection".

/// A collection of all edges in an `AdjacencyList`.
public struct _AdjacencyList_EdgeCollection<Storage: Collection>: Collection
where Storage.Element: _AdjacencyListPerVertex, Storage.Index == Int {
  /// The index corresponding to a vertex.
  public typealias VertexId = Storage.Element.EdgeData.VertexId

  /// The (optionally compressed) binary representation of an index into an `AdjacencyList`'s data
  /// structures.
  public typealias RawId = VertexId

  /// A name for an edge.
  public typealias EdgeId =  _AdjacencyList_EdgeId<VertexId>

  /// A handle for an element in `self`.
  public struct Index: Equatable, Comparable, Hashable {
    /// The index into `_AdjacencyList_EdgeCollection.storage` for the source vertex of the edge
    /// identified by `self`.
    fileprivate var sourceIndex: VertexId
    /// The offset into `_AdjacencyList_EdgeCollection.storage[sourceIndex].edges` for the edge
    /// identified by `self`.
    fileprivate var destinationIndex: RawId

    /// Returns true if `lhs` should be ordered before `rhs`.
    public static func < (lhs: Self, rhs: Self) -> Bool {
      if lhs.sourceIndex < rhs.sourceIndex { return true }
      if lhs.sourceIndex == rhs.sourceIndex {
        return lhs.destinationIndex < rhs.destinationIndex
      }
      return false
    }
  }

  /// The underlying graph.
  fileprivate let storage: Storage

  /// The index into `self` associated with the first valid edge.
  public var startIndex: Index {
    for i in 0..<storage.count {
      if storage[i].edges.count != 0 {
        return Index(sourceIndex: VertexId(i), destinationIndex: 0)
      }
    }
    return endIndex
  }

  /// A index identifying "one-past-the-end" of `self`.
  public var endIndex: Index { Index(sourceIndex: RawId(storage.count), destinationIndex: 0) }

  /// Returns the edge identifier corresponding to the provided index.
  public subscript(index: Index) -> EdgeId {
    EdgeId(source: index.sourceIndex, offset: index.destinationIndex)
  }

  /// Returns the position immediately after the given index.
  public func index(after: Index) -> Index {
    var next = after
    next.destinationIndex += 1
    while next.sourceIndex < storage.count
      && next.destinationIndex >= storage[Int(next.sourceIndex)].edges.count {
      next.sourceIndex += 1
      next.destinationIndex = 0
    }
    return next
  }
}

/// Adjacency lists whose edges are directed.
// This is a marker trait upon which we hang a bunch of implementation, but does not itself signify
// anything in particular at this time. (Potential use case for a private conformance?)
public protocol DirectedAdjacencyListProtocol: AdjacencyListProtocol, ParallelGraph
where
  VertexEdgeCollection == _AdjacencyList_VertexEdgeCollection<_EdgeData>,
  ParallelProjection == _DirectedAdjacencyList_ParallelProjection<_VertexData> {}

// MARK: - DirectedAdjacencyListProtocol: IncidenceGraph

extension DirectedAdjacencyListProtocol {
  // TODO: Consider a design for where these might be subscripts...

  /// All edges originating from `vertex`.
  public func edges(from vertex: VertexId) -> VertexEdgeCollection {
    VertexEdgeCollection(edges: _storage[Int(vertex)].edges, source: vertex)
  }

  /// The number of edges originating from `vertex`.
  public func outDegree(of vertex: VertexId) -> Int {
    edges(from: vertex).count
  }
}

// TODO: Make this a random access collection...
/// All edges from a single vertex in an AdjacencyList graph.
public struct _AdjacencyList_VertexEdgeCollection<EdgeData: _AdjacencyListPerEdge>: Collection {
  /// An identifier for a vertex.
  public typealias VertexId = EdgeData.VertexId
  /// An identifier for an edge.
  public typealias EdgeId = _AdjacencyList_EdgeId<VertexId>

  /// Collection of edge information.
  fileprivate let edges: [EdgeData]
  /// The source vertex.
  fileprivate let source: VertexId

  /// The position of the first element in a nonempty collection.
  public var startIndex: Int { 0 }

  /// The collection's "past the end" position.
  public var endIndex: Int { edges.count }
  /// Returns the position immediately after the given index.
  public func index(after index: Int) -> Int { index + 1 }
  /// Accesses the EdgeId at `index`.
  public subscript(index: Int) -> EdgeId {
    EdgeId(source: source, offset: VertexId(index))
  }
}

// MARK: - AdjacencyListProtocol: PropertyGraph

extension DirectedAdjacencyListProtocol {
  // TODO: Move this vertex subscript onto `AdjacencyListProtocol`.
  /// Accesses the arbitrary data associated with `vertex`.
  public subscript(vertex vertex: VertexId) -> Vertex {
    get { _storage[Int(vertex)].data }
    set { _storage[Int(vertex)].data = newValue }  // TODO: ensure this doesn't cause perf regressions vs _modify!
  }

  /// Accesses the arbitrary data associated with `edge`.
  public subscript(edge edge: EdgeId) -> Edge {
    get { _storage[edge.srcIdx].edges[edge.edgeIdx].data }
    set { _storage[edge.srcIdx].edges[edge.edgeIdx].data = newValue }
  }
}

// MARK: - DirectedAdjacencyListProtocol: Parallel graph operations

extension DirectedAdjacencyListProtocol {

  public mutating func step<
    Mailboxes: MailboxesProtocol,
    GlobalState: MergeableMessage & DefaultInitializable
  >(
    mailboxes: inout Mailboxes,
    globalState: GlobalState,
    _ fn: VertexParallelFunction<Mailboxes.Mailbox, GlobalState>
  ) rethrows -> GlobalState where Mailboxes.Mailbox.Graph == ParallelProjection {
    return try sequentialStep(mailboxes: &mailboxes, globalState: globalState, fn)
//    return try parallelStep(mailboxes: &mailboxes, globalState: globalState, fn)
  }

  /// Executes `fn` in parallel across all vertices, using `mailboxes` and `globalState`; returns
  /// the computed new `GlobalState`.
  public mutating func parallelStep<
    Mailboxes: MailboxesProtocol,
    GlobalState: MergeableMessage & DefaultInitializable
  >(
    mailboxes: inout Mailboxes,
    globalState: GlobalState,
    _ fn: VertexParallelFunction<Mailboxes.Mailbox, GlobalState>
  ) rethrows -> GlobalState where Mailboxes.Mailbox.Graph == ParallelProjection {
    let threadPool = ComputeThreadPools.local

    // TODO: Separate them out to be on different cache lines to avoid false sharing!
    // A per-thread array of global states, where each thread index gets its own.
    var globalStates: [GlobalState?] = Array(repeating: nil, count: threadPool.maxParallelism + 1)
    try globalStates.withUnsafeMutableBufferPointer { globalStates in

      try _storage.withUnsafeMutableBufferPointer { vertices in
        let parallelProjection = ParallelProjection(storage: vertices)
        try threadPool.parallelFor(n: vertices.count) { (i, _) in
          let vertexId = VertexId(VertexId(i))
          try mailboxes.withMailbox(for: vertexId) { mb in
            var ctx = ParallelGraphAlgorithmContext(
              vertex: vertexId,
              globalState: globalState,
              graph: parallelProjection,
              mailbox: &mb)
            if let mergeGlobalState = try fn(&ctx, &vertices[i].data) {
              if let threadId = threadPool.currentThreadIndex {
                if globalStates[threadId] == nil {
                  globalStates[threadId] = mergeGlobalState
                } else {
                  globalStates[threadId]!.merge(mergeGlobalState)
                }
              } else {
                // Unregistered donated thread.
                // TODO: should lock!
                if globalStates[globalStates.count - 1] == nil {
                  globalStates[globalStates.count - 1] = mergeGlobalState
                } else {
                  globalStates[globalStates.count - 1]!.merge(mergeGlobalState)
                }
              }
            }
          }
        }
      }
    }
    var newGlobalState = GlobalState()
    for state in globalStates {
      if let state = state {
        newGlobalState.merge(state)
      }
    }
    return newGlobalState
  }

  /// Executes `fn` across all vertices using only a single thread, using `mailboxes` and
  /// `globalState`; returns the new `GlobalState`.
  ///
  /// - SeeAlso: `parallelStep`
  public mutating func sequentialStep<
    Mailboxes: MailboxesProtocol,
    GlobalState: MergeableMessage & DefaultInitializable
  >(
    mailboxes: inout Mailboxes,
    globalState: GlobalState,
    _ fn: VertexParallelFunction<Mailboxes.Mailbox, GlobalState>
  ) rethrows -> GlobalState where Mailboxes.Mailbox.Graph == ParallelProjection {
    var newGlobalState = GlobalState()
    try _storage.withUnsafeMutableBufferPointer { storage in
      for i in 0..<storage.count {
        let vertexId = VertexId(VertexId(i))
        try mailboxes.withMailbox(for: vertexId) { mb in
          var ctx = ParallelGraphAlgorithmContext(
            vertex: vertexId,
            globalState: globalState,
            graph: ParallelProjection(storage: storage),
            mailbox: &mb)
          if let mergeGlobalState = try fn(&ctx, &storage[i].data) {
            newGlobalState.merge(mergeGlobalState)
          }
        }
      }
    }
    return newGlobalState
  }

  /// Executes `fn` across all vertices using only a single thread using `mailboxes`.
  public mutating func sequentialStep<Mailboxes: MailboxesProtocol>(
    mailboxes: inout Mailboxes,
    _ fn: NoGlobalVertexParallelFunction<Mailboxes.Mailbox>
  ) rethrows where Mailboxes.Mailbox.Graph == ParallelProjection {
    _ = try sequentialStep(mailboxes: &mailboxes, globalState: Empty()) {
      (ctx, v) in
      try fn(&ctx, &v)
      return nil
    }
  }
}

// TODO: Generalize AdjacencyListProtocol so that this type can also conform!
public struct _DirectedAdjacencyList_ParallelProjection<PerVertex: _AdjacencyListPerVertex>:
  GraphProtocol,
  IncidenceGraph,
  PropertyGraph
{
  public typealias Storage = UnsafeMutableBufferPointer<PerVertex>
  public typealias VertexId = PerVertex.EdgeData.VertexId
  public typealias EdgeId = _AdjacencyList_EdgeId<VertexId>
  public typealias Edge = PerVertex.EdgeData.Edge
  public typealias Vertex = PerVertex.Vertex
  public typealias VertexEdgeCollection = _AdjacencyList_VertexEdgeCollection<PerVertex.EdgeData>

  fileprivate var storage: Storage

  public func edges(from vertex: VertexId) -> VertexEdgeCollection {
    VertexEdgeCollection(edges: storage[Int(vertex)].edges, source: vertex)
  }

  /// Returns the number of edges whose source is `vertex`.
  public func outDegree(of vertex: VertexId) -> Int {
    storage[Int(vertex)].edges.count
  }

  public func source(of edge: EdgeId) -> VertexId {
    edge.source
  }

  public func destination(of edge: EdgeId) -> VertexId {
    storage[edge.srcIdx].edges[edge.edgeIdx].destination
  }

  /// Access information associated with `vertex`.
  public subscript(vertex vertex: VertexId) -> Vertex {
    get { storage[Int(vertex)].data }
    _modify { yield &storage[Int(vertex)].data }
  }

  /// Access information associated `edge`.
  public subscript(edge edge: EdgeId) -> Edge {
    get { storage[edge.srcIdx].edges[edge.edgeIdx].data }
    _modify { yield &storage[edge.srcIdx].edges[edge.edgeIdx].data }
  }
}

// MARK: - DirectedAdjacencyList

/// A general purpose directed [adjacency list](https://en.wikipedia.org/wiki/Adjacency_list) graph.
///
/// AdjacencyList implements a directed graph.
///
/// AdjacencyList supports parallel edges.
///
/// AdjacencyList also allows storing arbitrary additional data with each vertex and edge. If you
/// select a zero-sized type (such as `Empty`), all overhead is optimized away by the Swift
/// compiler.
///
/// > Note: because tuples cannot yet conform to protocols, we have to use a separate type instead
/// > of `Void`.
///
/// Operations that do not modify the graph structure occur in O(1) time. Additional operations that
/// run in O(1) (amortized) time include: adding a new edge, and adding a new vertex. Operations that
/// remove either vertices or edges invalidate existing `VertexId`s and `EdgeId`s. Adding new
/// vertices or edges do not invalidate previously retrived ids.
///
/// AdjacencyList is parameterized by the `RawId` which can be carefully tuned to save memory.
/// A good default is `Int32`, unless you are trying to represent more than 2^32 vertices.
public struct DirectedAdjacencyList<
  Vertex: DefaultInitializable,
  Edge: DefaultInitializable,
  RawId: BinaryInteger
>: DirectedAdjacencyListProtocol where RawId.Stride: SignedInteger {
  public typealias VertexId = RawId
  public typealias EdgeId = _AdjacencyList_EdgeId<RawId>
  public typealias VertexCollection = Range<RawId>
  public typealias _EdgeData = _AdjacencyList_DirectedPerEdge<VertexId, Edge>
  public typealias _VertexData = _AdjacencyList_DirectedPerVertex<Vertex, _EdgeData>
  public typealias VertexEdgeCollection = _AdjacencyList_VertexEdgeCollection<_EdgeData>
  public typealias ParallelProjection = _DirectedAdjacencyList_ParallelProjection<_VertexData>

  // Storage must be public because Swift doesn't support private conformances.
  public var _storage: _Storage


  /// Initialize an empty AdjacencyList.
  public init() {
    _storage = _Storage()
  }

  public var vertices: Range<RawId> { 0..<RawId(vertexCount) }

  // MARK: - Mutable graph operations

  // Note: addEdge(from:to:) and addVertex() supplied based on MutablePropertyGraph conformance.

  /// Removes all edges from `u` to `v`.
  ///
  /// If there are parallel edges, it removes all edges.
  ///
  /// - Precondition: `u` and `v` are vertices in `self`.
  /// - Complexity: worst case O(|E|)
  /// - Returns: true if one or more edges were removed; false otherwise.
  @discardableResult
  public mutating func removeEdge(from u: VertexId, to v: VertexId) -> Bool {
    assertValid(u, name: "u")
    assertValid(v, name: "v")

    // We write things in this way in order to avoid accidental quadratic performance in
    // non-optimized builds.
    let previousEdgeCount = _storage[Int(u)].edges.count
    _storage[Int(u)].edges.removeAll { $0.destination == v }
    return previousEdgeCount != _storage[Int(u)].edges.count
  }

  /// Removes `edge`.
  ///
  /// - Precondition: `edge` is a valid `EdgeId` from `self`.
  public mutating func remove(_ edge: EdgeId) {
    assertValid(edge)
    _storage[edge.srcIdx].edges.remove(at: edge.edgeIdx)
  }

  /// Removes all edges that `shouldBeRemoved`.
  public mutating func removeEdges(where shouldBeRemoved: (EdgeId) -> Bool) {
    for srcIdx in 0..<_storage.count {
      let src = VertexId(srcIdx)
      removeEdges(from: src, where: shouldBeRemoved)
    }
  }

  /// Remove all out edges of `vertex` that satisfy the given predicate.
  ///
  /// - Complexity: O(|E|)
  public mutating func removeEdges(
    from vertex: VertexId,
    where shouldBeRemoved: (EdgeId) -> Bool
  ) {
    // Note: this implementation assumes array calls the predicate in order across the array;
    // see SwiftLanguageTests.testArrayRemoveAllOrdering for the test to verify this property.
    var i = 0
    _storage[Int(vertex)].edges.removeAll { elem in
      let edge = EdgeId(source: vertex, offset: RawId(i))
      let tbr = shouldBeRemoved(edge)
      i += 1
      return tbr
    }
  }

  /// Removes all edges from `vertex`.
  ///
  /// - Complexity: O(|E|)
  public mutating func clear(vertex: VertexId) {
    _storage[Int(vertex)].edges.removeAll()
  }

  /// Removes `vertex` from the graph.
  ///
  /// - Precondition: `vertex` is a valid `VertexId` for `self`.
  /// - Complexity: O(|E| + |V|)
  public mutating func remove(_ vertex: VertexId) {
    fatalError("Unimplemented!")
  }

  // MARK: - MutablePropertyGraph

  /// Adds a new vertex with associated `vertexProperty`, returning its identifier.
  ///
  /// - Complexity: O(1) (amortized)
  public mutating func addVertex(storing vertexProperty: Vertex) -> VertexId {
    let cnt = _storage.count
    _storage.append(_AdjacencyList_DirectedPerVertex(data: vertexProperty))
    return VertexId(cnt)
  }

  /// Adds a new edge from `source` to `destination` and associated `edgeProperty`, returning its
  /// identifier.
  ///
  /// - Complexity: O(1) (amortized)
  public mutating func addEdge(
    from source: VertexId, to destination: VertexId, storing edgeProperty: Edge
  ) -> EdgeId {
    let edgeCount = _storage[Int(source)].edges.count
    _storage[Int(source)].edges.append(
      _AdjacencyList_DirectedPerEdge(destination: destination, data: edgeProperty))
    return EdgeId(source: source, offset: RawId(edgeCount))
  }
}

public struct _AdjacencyList_DirectedPerEdge<VertexId: BinaryInteger, Edge: DefaultInitializable>: _AdjacencyListPerEdge {
  public var destination: VertexId
  public var data: Edge

  public init(destination: VertexId) {
    self.destination = destination
    self.data = Edge()
  }

  public init(destination: VertexId, data: Edge) {
    self.destination = destination
    self.data = data
  }
}

public struct _AdjacencyList_DirectedPerVertex<Vertex: DefaultInitializable, EdgeData: _AdjacencyListPerEdge>: _AdjacencyListPerVertex {
  public var data: Vertex
  public var edges: [EdgeData]

  public init() {
    data = Vertex()
    edges = []
  }

  public init(data: Vertex) {
    self.data = data
    self.edges = []
  }
}

extension _AdjacencyList_EdgeId: CustomStringConvertible {
  /// Pretty representation of an edge identifier.
  public var description: String {
    "\(source) --(\(offset))-->"
  }
}

// MARK: - BidirectionalAdjacencyList
/*
// Key changes:
// - ForwardEdgeData adds `reverseOffset`
// - PerVertexData gets incomingEdges.
// Idea:
//  - Define a protocol for EdgeData. Associated types: VertexId, Edge.
//  - Define 2 (3?) implementations of EdgeData, one with just VId & Edge, and one with also reverseOffset.
//  - Define a protocol for VertexData. Associated types: EdgeData & Vertex.
//  - Define 2 (3?) implementations of VertexData, one with data & edges, and one that adds incomingEdges.
*/

/// A general purpose, bidirectional [adjacency list](https://en.wikipedia.org/wiki/Adjacency_list)
/// graph.
///
/// BidirectionalAdjacencyList implements a bidirectional graph. Additionally, parallel edges are
/// supported.
///
/// BidirectionalAdjacencyList also allows storing arbitrary additional data with each vertex and edge. If you
/// select a zero-sized type (such as `Empty`), all overhead is optimized away by the Swift
/// compiler.
///
/// > Note: because tuples cannot yet conform to protocols, we have to use a separate type instead
/// > of `Void`.
///
/// Operations that do not modify the graph structure occur in O(1) time. Additional operations that
/// run in O(1) (amortized) time include: adding a new edge, and adding a new vertex. Operations that
/// remove either vertices or edges invalidate existing `VertexId`s and `EdgeId`s. Adding new
/// vertices or edges do not invalidate previously retrived ids.
///
/// BidirectionalAdjacencyList is parameterized by the `RawId` which can be carefully tuned to save memory.
/// A good default is `Int32`, unless you are trying to represent more than 2^32 vertices.
public struct BidirectionalAdjacencyList<
  Vertex: DefaultInitializable,
  Edge: DefaultInitializable,
  RawId: BinaryInteger
>: DirectedAdjacencyListProtocol where RawId.Stride: SignedInteger {
  /// The name of a vertex in this graph.
  ///
  /// Note: `VertexId`'s are not stable across some graph mutation operations.
  public typealias VertexId = RawId
  public typealias EdgeId = _AdjacencyList_EdgeId<RawId>
  public typealias VertexCollection = Range<RawId>
  public typealias _EdgeData = _AdjacencyList_BidirectionalPerEdge<VertexId, Edge>
  public typealias _VertexData = _AdjacencyList_BidirectionalPerVertex<Vertex, _EdgeData>
  public typealias VertexEdgeCollection = _AdjacencyList_VertexEdgeCollection<_EdgeData>
  public typealias ParallelProjection = _DirectedAdjacencyList_ParallelProjection<_VertexData>

  // /// Information stored for each edge in the forward direction.
  // fileprivate typealias ForwardEdgeData = (destination: VertexId, reverseOffset: RawId, data: Edge)

  // /// Information associated with each vertex.
  // ///
  // /// - data: This is the user supplied, arbitrary data associated with each vertex.
  // /// - edges: This is the data stored associated with each edge.
  // /// - reverseEdges: Incoming edges to `self`.
  // fileprivate typealias PerVertexData = (data: Vertex, edges: [ForwardEdgeData], incomingEdges: [EdgeId])

  // // Infor
  // /// Nested array-of-arrays data structure representing the graph.
  // private var storage = [PerVertexData]()

  public var _storage: _Storage

  /// Initialize an empty BidirectionalAdjacencyList.
  public init() {
    _storage = _Storage()
  }

  public var vertices: Range<RawId> { 0..<RawId(vertexCount) }

  /// Verifies that `self` is internally consistent with edges entering and departing `vertex`.
  ///
  /// Although this function will halt execution if an inconsistency is discovered, it intentionally
  /// returns `true` otherwise to encourage callers to wrap this in an `assert()` call itself, to
  /// ensure the SIL optimizer completely removes this function call when optimizations are enabled.
  fileprivate func verifyIsInternallyConsistent(verifying vertex: VertexId) -> Bool {
    for (i, edge) in _storage[Int(vertex)].edges.enumerated() {
      let reversedInfo = _storage[Int(edge.destination)].incomingEdges[Int(edge.reverseOffset)]
      assert(reversedInfo.source == vertex, "Inconsistent edge: \(edge).\n\(self)")
      assert(Int(reversedInfo.offset) == i, "Inconsistent edge: \(edge).\n\(self)")
    }
    for (i, reverseEdge) in _storage[Int(vertex)].incomingEdges.enumerated() {
      let forwardInfo = _storage[Int(reverseEdge.source)].edges[Int(reverseEdge.offset)]
      assert(forwardInfo.destination == vertex, "Inconsistent reverse edge: \(reverseEdge).\n\(self)")
      assert(Int(forwardInfo.reverseOffset) == i, "Inconsistent reverse edge: \(reverseEdge).\n\(self)")
    }
    return true
  }

  // MARK: - Mutable graph operations

  // Note: addEdge(from:to:) and addVertex() supplied based on MutablePropertyGraph conformance.

  /// Removes all edges from `u` to `v`.
  ///
  /// If there are parallel edges, it removes all edges.
  ///
  /// - Precondition: `u` and `v` are vertices in `self`.
  /// - Complexity: worst case O(|E|)
  /// - Returns: true if one or more edges were removed; false otherwise.
  @discardableResult
  public mutating func removeEdge(from u: VertexId, to v: VertexId) -> Bool {
    assertValid(u, name: "u")
    assertValid(v, name: "v")
    assert(verifyIsInternallyConsistent(verifying: u))
    assert(verifyIsInternallyConsistent(verifying: v))

    fatalError("Not implemented!")  // TODO!!
  }

  /// Removes `edge`.
  ///
  /// - Precondition: `edge` is a valid `EdgeId` from `self`.
  public mutating func remove(_ edge: EdgeId) {
    fatalError("Not implemented! Sorry.")
  }

  /// Removes all edges that `shouldBeRemoved`.
  public mutating func removeEdges(where shouldBeRemoved: (EdgeId) -> Bool) {
    fatalError("Not implemented. Sorry.")
  }

  /// Remove all out edges of `vertex` that satisfy the given predicate.
  ///
  /// - Complexity: O(|E|)
  public mutating func removeEdges(
    from vertex: VertexId,
    where shouldBeRemoved: (EdgeId) -> Bool
  ) {
    fatalError("Not implemented.")
  }

  /// Removes all edges from `vertex`.
  ///
  /// - Complexity: O(|E|)
  public mutating func clear(vertex: VertexId) {
    fatalError("Not implemented. :-(")
  }

  /// Removes `vertex` from the graph.
  ///
  /// - Precondition: `vertex` is a valid `VertexId` for `self`.
  /// - Complexity: O(|E| + |V|)
  public mutating func remove(_ vertex: VertexId) {
    fatalError("Unimplemented! :'-(")
  }

  // MARK: - MutablePropertyGraph

  /// Adds a new vertex with associated `vertexProperty`, returning its identifier.
  ///
  /// - Complexity: O(1) (amortized)
  public mutating func addVertex(storing vertexProperty: Vertex) -> VertexId {
    let cnt = _storage.count
    _storage.append(_AdjacencyList_BidirectionalPerVertex(data: vertexProperty))
    return VertexId(cnt)
  }

  /// Adds a new edge from `source` to `destination` and associated `edgeProperty`, returning its
  /// identifier.
  ///
  /// - Complexity: O(1) (amortized)
  public mutating func addEdge(
    from source: VertexId, to destination: VertexId, storing edgeProperty: Edge
  ) -> EdgeId {
    let srcEdgeCount = _storage[Int(source)].edges.count
    let dstEdgeCount = _storage[Int(destination)].incomingEdges.count
    _storage[Int(source)].edges.append(
      _AdjacencyList_BidirectionalPerEdge(
        destination: destination,
        reverseOffset: RawId(dstEdgeCount),
        data: edgeProperty))
    let edgeId = EdgeId(source: source, offset: RawId(srcEdgeCount))
    _storage[Int(destination)].incomingEdges.append(edgeId)
    return edgeId
  }
}

extension BidirectionalAdjacencyList: BidirectionalGraph {
  public typealias VertexInEdgeCollection = [EdgeId]

  public func edges(to vertex: VertexId) -> VertexInEdgeCollection {
    _storage[Int(vertex)].incomingEdges
  }

  public func inDegree(of vertex: VertexId) -> Int {
    edges(to: vertex).count
  }

  public func degree(of vertex: VertexId) -> Int {
    inDegree(of: vertex) + outDegree(of: vertex)
  }
}

public struct _AdjacencyList_BidirectionalPerEdge<RawId: BinaryInteger, Edge: DefaultInitializable>: _AdjacencyListPerEdge {
  public typealias VertexId = RawId
  public var destination: VertexId
  public var reverseOffset: RawId
  public var data: Edge

  public init(destination: VertexId, reverseOffset: RawId) {
    self.destination = destination
    self.reverseOffset = reverseOffset
    self.data = Edge()
  }

  public init(destination: VertexId, reverseOffset: RawId, data: Edge) {
    self.destination = destination
    self.reverseOffset = reverseOffset
    self.data = data
  }
}

public struct _AdjacencyList_BidirectionalPerVertex<Vertex: DefaultInitializable, EdgeData: _AdjacencyListPerEdge>: _AdjacencyListPerVertex {
  public typealias RawId = EdgeData.VertexId
  public typealias EdgeId = _AdjacencyList_EdgeId<RawId>
  public var data: Vertex
  public var edges: [EdgeData]
  public var incomingEdges: [EdgeId]

  public init() {
    data = Vertex()
    edges = []
    incomingEdges = []
  }

  public init(data: Vertex) {
    self.data = data
    self.edges = []
    self.incomingEdges = []
  }
}
