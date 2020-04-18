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

/// A simple AdjacencyList with no data associated with each vertex or edge.
public typealias SimpleAdjacencyList<RawVertexId: BinaryInteger> = AdjacencyList<
  Empty, Empty, RawVertexId
>

/// A general purpose [adjacency list](https://en.wikipedia.org/wiki/Adjacency_list) graph.
///
/// AdjacencyList implements a directed graph. If you would like an undirected graph, simply add
/// two edges, representing each direction. Additionally, AdjacencyList supports parallel edges.
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
public struct AdjacencyList<
  Vertex: DefaultInitializable,
  Edge: DefaultInitializable,
  RawId: BinaryInteger
>: GraphProtocol {
  /// The name of a vertex in this graph.
  ///
  /// Note: `VertexId`'s are not stable across some graph mutation operations.
  public typealias VertexId = RawId

  /// The name of an edge in this graph.
  ///
  /// Note: `EdgeId`'s are not stable across some graph mutation operations.
  public struct EdgeId: Equatable, Hashable {
    /// The source vertex.
    fileprivate let source: VertexId
    /// The offset into the edge array
    fileprivate let offset: RawId

    /// Index into `storage` for the source vertex.
    fileprivate var srcIdx: Int { Int(source) }
    /// Index into `storage[self.srcIdx].edges` to retrieve the edge.
    fileprivate var edgeIdx: Int { Int(offset) }
  }

  /// Information stored for each edge.
  fileprivate typealias EdgeData = (destination: VertexId, data: Edge)
  /// Information associated with each vertex.
  fileprivate typealias PerVertexData = (data: Vertex, edges: [EdgeData])
  /// Nested array-of-arrays data structure representing the graph.
  private var storage = [PerVertexData]()

  /// Initialize an empty PropertyAdjacencyList.
  public init() {}

  /// Ensures `id` is a valid vertex in `self`, halting execution otherwise.
  fileprivate func assertValid(_ id: VertexId, name: StaticString? = nil) {
    func makeName() -> String {
      if let name = name { return " (\(name))" }
      return ""
    }
    assert(Int(id) < storage.count, "Vertex \(id)\(makeName()) is not valid.")
  }

  /// Ensures `id` is a valid edge in `self`, halting execution otherwise.
  fileprivate func assertValid(_ id: EdgeId) {
    assertValid(id.source, name: "source")
    assert(id.edgeIdx < storage[id.srcIdx].edges.count, "EdgeId \(id) is not valid.")
  }
}

// MARK: - Vertex list graph operations

extension AdjacencyList: VertexListGraph {
  /// The number of vertices in the graph.
  public var vertexCount: Int { storage.count }

  /// A collection of this graph's vertex identifiers.
  public struct VertexCollection: HierarchicalCollection {
    fileprivate let vertexCount: Int

    @discardableResult
    public func forEachWhile(startingAt start: Int?, _ fn: (VertexId) throws -> Bool) rethrows
      -> Int?
    {
      let begin: Int
      if let start = start {
        begin = start
      } else {
        begin = 0
      }

      for i in begin..<vertexCount {
        if try !fn(RawId(i)) {
          return i
        }
      }
      return nil
    }

    public var count: Int { vertexCount }
  }

  /// The identifiers of all vertices.
  public func vertices() -> VertexCollection {
    VertexCollection(vertexCount: vertexCount)
  }
}

// MARK: - Edge list graph operations

extension AdjacencyList: EdgeListGraph {
  /// The number of edges.
  ///
  /// - Complexity: O(|V|)
  public var edgeCount: Int { storage.reduce(0) { $0 + $1.edges.count } }

  /// A collection of all edge identifiers.
  public struct EdgeCollection: HierarchicalCollection {
    fileprivate let storage: [PerVertexData]

    public struct Cursor: Equatable, Comparable {
      var sourceIndex: Int
      var destinationIndex: Int

      public static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.sourceIndex < rhs.sourceIndex { return true }
        if lhs.sourceIndex == rhs.sourceIndex {
          return lhs.destinationIndex < rhs.destinationIndex
        }
        return false
      }
    }

    @discardableResult
    public func forEachWhile(startingAt start: Cursor?, _ fn: (EdgeId) throws -> Bool) rethrows
      -> Cursor?
    {
      let begin: Cursor
      if let start = start {
        begin = start
      } else {
        begin = Cursor(sourceIndex: 0, destinationIndex: 0)
      }
      // First loop doesn't always start at 0.
      for inner in begin.destinationIndex..<storage[begin.sourceIndex].edges.count {
        let edgeId = EdgeId(
          source: VertexId(begin.sourceIndex),
          offset: VertexId(inner))
        if try !fn(edgeId) {
          return Cursor(sourceIndex: begin.sourceIndex, destinationIndex: inner)
        }
      }
      for outer in (begin.sourceIndex + 1)..<storage.count {
        for inner in 0..<storage[outer].edges.count {
          let edgeId = EdgeId(
            source: VertexId(outer),
            offset: VertexId(inner))
          if try !fn(edgeId) {
            return Cursor(sourceIndex: outer, destinationIndex: inner)
          }
        }
      }
      return nil
    }

    public var count: Int { storage.reduce(0) { $0 + $1.edges.count } }
  }

  /// Returns a collection of all edges.
  public func edges() -> EdgeCollection { EdgeCollection(storage: storage) }

  /// Returns the source vertex identifier of `edge`.
  public func source(of edge: EdgeId) -> VertexId {
    edge.source
  }

  /// Returns the destination vertex identifier of `edge`.
  public func destination(of edge: EdgeId) -> VertexId {
    storage[edge.srcIdx].edges[edge.edgeIdx].destination
  }
}

// MARK: - Incidence graph operations

extension AdjacencyList: IncidenceGraph {

  /// `VertexEdgeCollection` represents a collection of vertices from a single source vertex.
  public struct VertexEdgeCollection: Collection {
    fileprivate let edges: [EdgeData]
    fileprivate let source: VertexId

    public var startIndex: Int { 0 }
    public var endIndex: Int { edges.count }
    public func index(after index: Int) -> Int { index + 1 }

    public subscript(index: Int) -> EdgeId {
      EdgeId(source: source, offset: RawId(index))
    }
  }

  /// Returns the collection of edges from `vertex`.
  public func edges(from vertex: VertexId) -> VertexEdgeCollection {
    VertexEdgeCollection(edges: storage[Int(vertex)].edges, source: vertex)
  }

  /// Returns the number of edges whose source is `vertex`.
  public func outDegree(of vertex: VertexId) -> Int {
    storage[Int(vertex)].edges.count
  }
}

// MARK: - Mutable graph operations

extension AdjacencyList: MutableGraph {
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
    let previousEdgeCount = storage[Int(u)].edges.count
    storage[Int(u)].edges.removeAll { $0.destination == v }
    return previousEdgeCount != storage[Int(u)].edges.count
  }

  /// Removes `edge`.
  ///
  /// - Precondition: `edge` is a valid `EdgeId` from `self`.
  public mutating func remove(_ edge: EdgeId) {
    assertValid(edge)
    storage[edge.srcIdx].edges.remove(at: edge.edgeIdx)
  }

  /// Removes all edges that `shouldBeRemoved`.
  public mutating func removeEdges(where shouldBeRemoved: (EdgeId) -> Bool) {
    for srcIdx in 0..<storage.count {
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
    storage[Int(vertex)].edges.removeAll { elem in
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
    storage[Int(vertex)].edges.removeAll()
  }

  /// Removes `vertex` from the graph.
  ///
  /// - Precondition: `vertex` is a valid `VertexId` for `self`.
  /// - Complexity: O(|E| + |V|)
  public mutating func remove(_ vertex: VertexId) {
    fatalError("Unimplemented!")
  }
}

// MARK: - Property graph conformances

extension AdjacencyList: PropertyGraph {
  /// Access information associated with `vertex`.
  public subscript(vertex vertex: VertexId) -> Vertex {
    get { storage[Int(vertex)].data }
    _modify { yield &storage[Int(vertex)].data }
  }

  /// Access a property of `vertex`.
  public subscript<T>(vertex vertex: VertexId, keypath: KeyPath<Vertex, T>) -> T {
    self[vertex: vertex][keyPath: keypath]
  }

  /// Access information associated `edge`.
  public subscript(edge edge: EdgeId) -> Edge {
    get { storage[edge.srcIdx].edges[edge.edgeIdx].data }
    _modify { yield &storage[edge.srcIdx].edges[edge.edgeIdx].data }
  }

  /// Retrieves a property of `edge`.
  public subscript<T>(edge edge: EdgeId, keypath: KeyPath<Edge, T>) -> T {
    self[edge: edge][keyPath: keypath]
  }
}

extension AdjacencyList: MutablePropertyGraph {
  /// Adds a new vertex with associated `information`, returning its identifier.
  ///
  /// - Complexity: O(1) (amortized)
  public mutating func addVertex(with information: Vertex) -> VertexId {
    let cnt = storage.count
    storage.append((information, []))
    return VertexId(cnt)
  }

  /// Adds a new edge from `source` to `destination` and associated `information`, returning its
  /// identifier.
  ///
  /// - Complexity: O(1) (amortized)
  public mutating func addEdge(
    from source: VertexId, to destination: VertexId, with information: Edge
  ) -> EdgeId {
    let edgeCount = storage[Int(source)].edges.count
    storage[Int(source)].edges.append((destination, information))
    return EdgeId(source: source, offset: RawId(edgeCount))
  }
}

// MARK: - Parallel graph operations

extension AdjacencyList: ParallelGraph {
  public mutating func step<
    Mailboxes: MailboxesProtocol,
    GlobalState: MergeableMessage & DefaultInitializable
  >(
    mailboxes: inout Mailboxes,
    globalState: GlobalState,
    _ fn: VertexParallelFunction<Mailboxes.Mailbox, GlobalState>
  ) rethrows -> GlobalState where Mailboxes.Mailbox.Graph == Self {
    return try sequentialStep(mailboxes: &mailboxes, globalState: globalState, fn)
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
  ) rethrows -> GlobalState where Mailboxes.Mailbox.Graph == Self {
    let threadPool = ComputeThreadPools.local

    // TODO: Separate them out to be on different cache lines to avoid false sharing!
    // A per-thread array of global states, where each thread index gets its own.
    var globalStates: [GlobalState?] = Array(repeating: nil, count: threadPool.parallelism + 1)
    try globalStates.withUnsafeMutableBufferPointer { globalStates in

      var storage = [PerVertexData]()  // Work around `self` ownership restrictions by using a tmp.
      swap(&self.storage, &storage)  // Note: this breaks internal edge property maps!
      defer { swap(&self.storage, &storage) }  // Always swap back!

      try storage.withUnsafeMutableBufferPointer { vertices in
        try threadPool.parallelFor(n: vertices.count) { (i, _) in
          let vertexId = VertexId(VertexId(i))
          try mailboxes.withMailbox(for: vertexId) { mb in
            var ctx = ParallelGraphAlgorithmContext(
              vertex: vertexId,
              globalState: globalState,
              graph: self,
              mailbox: &mb)
            if let mergeGlobalState = try fn(&ctx, &vertices[i].data) {
              if let threadId = threadPool.currentThreadIndex {
                if globalStates[threadId] == nil {
                  globalStates[threadId] = mergeGlobalState
                } else {
                  globalStates[threadId]!.merge(with: mergeGlobalState)
                }
              } else {
                // The user's donated thread.
                // TODO: should lock!
                if globalStates[globalStates.count] == nil {
                  globalStates[globalStates.count] = mergeGlobalState
                } else {
                  globalStates[globalStates.count]!.merge(with: mergeGlobalState)
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
        newGlobalState.merge(with: state)
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
  ) rethrows -> GlobalState where Mailboxes.Mailbox.Graph == Self {
    var newGlobalState = GlobalState()
    for i in 0..<storage.count {
      let vertexId = VertexId(VertexId(i))
      try mailboxes.withMailbox(for: vertexId) { mb in
        var ctx = ParallelGraphAlgorithmContext(
          vertex: vertexId,
          globalState: globalState,
          graph: self,
          mailbox: &mb)
        if let mergeGlobalState = try fn(&ctx, &storage[i].data) {
          newGlobalState.merge(with: mergeGlobalState)
        }
      }
    }
    return newGlobalState
  }

  /// Executes `fn` across all vertices using only a single thread using `mailboxes`.
  public mutating func sequentialStep<Mailboxes: MailboxesProtocol>(
    mailboxes: inout Mailboxes,
    _ fn: NoGlobalVertexParallelFunction<Mailboxes.Mailbox>
  ) rethrows where Mailboxes.Mailbox.Graph == Self {
    _ = try sequentialStep(mailboxes: &mailboxes, globalState: Empty()) {
      (ctx, v) in
      try fn(&ctx, &v)
      return nil
    }
  }
}

extension AdjacencyList.EdgeId: CustomStringConvertible {
  /// Pretty representation of an edge identifier.
  public var description: String {
    "\(source) --(\(offset))-->"
  }
}
