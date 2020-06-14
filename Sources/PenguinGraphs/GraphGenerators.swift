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

/// Internal protocol. (Sure which we had scoped conformances...)
///
/// A protocol to hang default implementations of methods off of.
///
/// A `_DenseIntegerVertexIdGraph` is a graph whose vertex id's are 0..<vertexCount.
public protocol _DenseIntegerVertexIdGraph: VertexListGraph, SearchDefaultsGraph where VertexCollection == Range<Int> {}

extension _DenseIntegerVertexIdGraph {

  /// The collection containing the identifiers for every vertex in `self`.
  public var vertices: Range<Int> { 0..<vertexCount }

  /// Makes a default color map where every vertex is set to `color`.
  public func makeDefaultColorMap(repeating color: VertexColor) -> TablePropertyMap<Self, VertexId, VertexColor> {
    TablePropertyMap(repeating: color, forVerticesIn: self)
  }

  /// Makes a default int map for every vertex.
  public func makeDefaultVertexIntMap(repeating value: Int) -> TablePropertyMap<Self, VertexId, Int> {
    TablePropertyMap(repeating: value, forVerticesIn: self)
  }

  /// Makes a default vertex property map mapping vertices.
  public func makeDefaultVertexVertexMap(repeating vertex: VertexId) -> TablePropertyMap<Self, VertexId, VertexId> {
    TablePropertyMap(repeating: vertex, forVerticesIn: self)
  }
}

/// A directed graph with a star topology, where vertex 0 is at the center, and every vertex has an
/// edge to vertex 0 (including the self-loop at vertex 0).
public struct DirectedStarGraph: GraphProtocol, _DenseIntegerVertexIdGraph {
  /// The total number of vertices in `self`.
  public let vertexCount: Int

  /// Creates a `DirectedStarGraph` with `vertexCount` vertices.
  public init(vertexCount: Int) {
    self.vertexCount = vertexCount
  }

  /// Creates a `DirectedStarGraph` with `n` vertices.
  public init(n: Int) {
    self.init(vertexCount: n)
  }

  /// Name of a vertex in `self`.
  public typealias VertexId = Int

  /// Name of an edge in `self`.
  public typealias EdgeId = Int
}

// MARK: - DirectedStarGraph: IncidenceGraph

extension DirectedStarGraph: IncidenceGraph {
  // TODO: If optional were a collection, we could easily remove the self edge at 0... :-/

  public func edges(from vertex: Int) -> CollectionOfOne<Int> {
    CollectionOfOne(vertex)
  }

  public func source(of edge: Int) -> Int {
    edge
  }

  public func destination(of edge: Int) -> Int {
    0
  }
}

// MARK: - DirectedStarGraph: BidirectionalGraph

extension DirectedStarGraph: BidirectionalGraph {
  /// The collection of in edges to a vertex.
  public struct VertexInEdgeCollection: Collection {
    fileprivate let vertexCount: Int
    fileprivate let vertex: Int
    public var startIndex: Int { 0 }
    public var endIndex: Int { vertex == 0 ? vertexCount : 0 }
    public subscript(index: Int) -> Int { index }
    public func index(after index: Int) -> Int { index + 1 }
  }

  public func edges(to vertex: Int) -> VertexInEdgeCollection {
    VertexInEdgeCollection(vertexCount: vertexCount, vertex: vertex)
  }
}

/// An undirected graph with a star topology, and no self-loop.
public struct UndirectedStarGraph: GraphProtocol, _DenseIntegerVertexIdGraph {
  /// The total number of vertices in `self`.
  public let vertexCount: Int

  /// Creates an `UndirectedStarGraph` with `vertexCount` vertices.
  public init(vertexCount: Int) {
    self.vertexCount = vertexCount
  }

  /// Creates an `UndirectedStarGraph` with `n` vertices.
  public init(n: Int) {
    self.init(vertexCount: n)
  }

  /// Name for a vertex.
  public typealias VertexId = Int

  /// Name for an edge.
  public struct EdgeId: Equatable, Comparable, Hashable {
    let vertex: Int
    let outward: Bool

    // Note: we must manually write out the Equatable & Hashable conformances to exclude `outward`.

    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.vertex == rhs.vertex
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
      lhs.vertex < rhs.vertex
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(vertex)
    }
  }
}

// MARK: - UndirectedStarGraph: IncidenceGraph

extension UndirectedStarGraph: IncidenceGraph {
  public struct VertexEdgeCollection: Collection {
    fileprivate let vertexCount: Int
    fileprivate let vertex: Int

    public var startIndex: Int { 0 }
    public var endIndex: Int { vertex == 0 ? vertexCount - 1 : 1 }
    public func index(after index: Int) -> Int { index + 1 }
    public subscript(index: Int) -> EdgeId {
      EdgeId(vertex: vertex == 0 ? index + 1 : vertex, outward: vertex == 0)
    }
  }

  public func edges(from vertex: Int) -> VertexEdgeCollection {
    VertexEdgeCollection(vertexCount: vertexCount, vertex: vertex)
  }

  public func source(of edge: EdgeId) -> Int {
    edge.outward ? 0 : edge.vertex
  }

  public func destination(of edge: EdgeId) -> Int {
    edge.outward ? edge.vertex : 0
  }
}

/// A graph with an edge between every vertex, including the self loop.
public struct CompleteGraph: GraphProtocol, _DenseIntegerVertexIdGraph {
  /// The number of vertices in `self`.
  public let vertexCount: Int

  /// Creates a `CompleteGraph` with `vertexCount` vertices.
  public init(vertexCount: Int) {
    self.vertexCount = vertexCount
  }

  /// Creates a `CompleteGraph` with `n` vertices.
  public init(n: Int) {
    self.init(vertexCount: n)
  }

  /// The name for a vertex in `self`.
  public typealias VertexId = Int

  /// The name for an edge in `self`.
  public typealias EdgeId = Int
}

// MARK: - CompleteGraph: IncidenceGraph

extension CompleteGraph: IncidenceGraph {
  public func edges(from vertex: Int) -> Range<Int> {
    (vertex*vertexCount)..<((vertex+1) * vertexCount)
  }

  public func source(of edge: Int) -> Int {
    edge / vertexCount
  }

  public func destination(of edge: Int) -> Int {
    edge % vertexCount
  }
}

extension CompleteGraph: BidirectionalGraph {
  // Returns the edges in `self` whose destination is `vertex`.
  public func edges(to vertex: Int) -> [Int] {
    Array((0..<vertexCount).lazy.map { $0 * self.vertexCount + vertex })
  }
}

/// A graph where each vertex is connected with the subsequent `k` vertices, modulo `vertexCount`.
public struct CircleGraph: GraphProtocol, _DenseIntegerVertexIdGraph {
  /// The number of vertices in `self`.
  public let vertexCount: Int
  /// The number of edges per vertex.
  public let outDegree: Int

  /// Creates a CircleGraph with `vertexCount` vertices, connected to the next `outDegree` vertices.
  public init(vertexCount: Int, outDegree: Int) {
    self.vertexCount = vertexCount
    self.outDegree = outDegree
  }

  /// Creates a CircleGraph with `n` vertices, connected to the next `k` vertices.
  public init(n: Int, k: Int) {
    self.init(vertexCount: n, outDegree: k)
  }

  /// Name of a vertex.
  public typealias VertexId = Int
  /// Name of an edge.
  public struct EdgeId: Equatable, Hashable {  // Should just be a tuple, but tuples can't conform to protocols. :-(
    let source: VertexId
    let offset: Int
  }
}

extension CircleGraph: IncidenceGraph {
  public func edges(from vertex: Int) -> [EdgeId] {
    (0..<outDegree).map { EdgeId(source: vertex, offset: $0) }
  }

  public func source(of edge: EdgeId) -> VertexId {
    edge.source
  }

  public func destination(of edge: EdgeId) -> VertexId {
    (edge.source + edge.offset + 1) % vertexCount
  }
}

extension CircleGraph: VertexListGraph {
  public var vertices: Range<Int> { 0..<vertexCount }
}

/// An undirected complete subgraph over `cliqueVerticesCount` with a single path to a final
/// distinguished vertex.
///
/// See also: [Lollipop graph on Wikipedia](https://en.wikipedia.org/wiki/Lollipop_graph)
public struct LollipopGraph: GraphProtocol, _DenseIntegerVertexIdGraph {
  /// The number of vertices in the fully connected clique.
  public let cliqueVerticesCount: Int
  /// The number of vertices along the singly connected path.
  public let pathLength: Int

  /// Creates a LollipopGraph.
  public init(cliqueVerticesCount: Int, pathLength: Int) {
    self.cliqueVerticesCount = cliqueVerticesCount
    self.pathLength = pathLength
  }

  public init(m: Int, n: Int) {
    self.init(cliqueVerticesCount: m, pathLength: n)
  }

  /// The total number of vertices in `self`.
  public var vertexCount: Int { cliqueVerticesCount + pathLength }

  /// The name of a vertex in `self`.
  public typealias VertexId = Int
  public struct EdgeId: Equatable, Hashable {
    let source: Int
    let destination: Int
    let reversed: Bool

    public init(source: Int, destination: Int) {
      // Canonicalize the order.
      if source < destination {
        self.source = source
        self.destination = destination
        self.reversed = false
      } else {
        self.source = destination
        self.destination = source
        self.reversed = true
      }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.source == rhs.source && lhs.destination == rhs.destination
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(source)
      hasher.combine(destination)
    }
  }
}

extension LollipopGraph: IncidenceGraph {
  public func edges(from vertex: Int) -> [EdgeId] {
    if vertex < cliqueVerticesCount {
      var edges = Array((0..<cliqueVerticesCount).lazy.filter { $0 != vertex }.map { EdgeId(source: vertex, destination: $0) })
      if vertex + 1 == cliqueVerticesCount {
        edges.append(EdgeId(source: vertex, destination: vertex + 1))  // Start the tail.
      }
      return edges
    }
    var edges = [EdgeId(source: vertex, destination: vertex - 1)]
    if vertex < (vertexCount - 1) {
      edges.append(EdgeId(source: vertex, destination: vertex + 1))
    }
    return edges
  }

  public func source(of edge: EdgeId) -> VertexId {
    return edge.reversed ? edge.destination : edge.source
  }

  public func destination(of edge: EdgeId) -> VertexId {
    return edge.reversed ? edge.source : edge.destination
  }
}

extension LollipopGraph: VertexListGraph {
  public var vertices: Range<Int> { 0..<vertexCount }
}
