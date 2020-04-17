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

/// Represents a Graph data structure.
///
/// This is modeled off of the Boost Graph Library; see
/// https://www.boost.org/doc/libs/1_72_0/libs/graph/doc/Graph.html.
public protocol GraphProtocol {
  /// A handle to refer to a vertex in the graph.
  associatedtype VertexId: Equatable
  /// A handle to rever to an edge in the graph.
  associatedtype EdgeId: Equatable

  // TODO: Figure out how to model directness!
}

/// A `MutableGraph` can be changed via the addition and removal of edges and vertices.
///
/// In the documentation of complexity guarantees, |V| is the number of nodes, and |E| is the number
/// of edges.
public protocol MutableGraph: GraphProtocol {
  /// Adds an edge from `source` to `destination` into the graph.
  ///
  /// - Throws: If parallel edges are disallowed, and the edge `source` to `destination` already
  ///   exists.
  /// - Complexity: either O(1) (amortized) or O(log(|E|/|V|)) if checking for parallel edges.
  mutating func addEdge(from source: VertexId, to destination: VertexId) throws -> EdgeId

  /// Removes the edge (u, v) from the graph.
  ///
  /// If the graph allows parallel edges, it removes all matching edges.
  ///
  /// - Precondition: `u` and `v` are vertices in `self`.
  /// - Throws: `GraphErrors.edgeNotFound` if there is no edge from `u` to `v`.
  /// - Complexity: worst case O(|E|).
  mutating func removeEdge(from u: VertexId, to v: VertexId) throws

  /// Removes the edge `edge` from the graph.
  ///
  /// - Precondition: `edge` is a valid `EdgeId` from `self`.
  mutating func remove(_ edge: EdgeId)

  /// Removes all edges identified by `shouldBeRemoved`.
  mutating func removeEdges(where shouldBeRemoved: (EdgeId) throws -> Bool) rethrows

  /// Removes all out edges from `vertex` identified by `shouldBeRemoved`.
  ///
  /// - Complexity: O(|E|)
  mutating func removeEdges(from vertex: VertexId, where shouldBeRemoved: (EdgeId) throws -> Bool)
    rethrows

  /// Adds a new vertex, returning its identifier.
  ///
  /// - Complexity: O(1) (amortized)
  mutating func addVertex() -> VertexId

  /// Removes all edges from `vertex`.
  ///
  /// - Complexity: worst case O(|E| + |V|).
  mutating func clear(vertex: VertexId)

  /// Removes `vertex` from the graph.
  ///
  /// - Precondition: `vertex` is a valid `VertexId` for `self`.
  /// - Complexity: O(|E| + |V|)
  mutating func remove(_ vertex: VertexId)
}

extension MutableGraph {
  /// Removes the edge from `u` to `v` if present, and does nothing otherwise.
  public mutating func removedEdgeIfPresent(from u: VertexId, to v: VertexId) {
    _ = try? removeEdge(from: u, to: v)
  }
}

/// A `VertexListGraph` is a graph that can enumerate all the vertices within it.
public protocol VertexListGraph: GraphProtocol {

  /// The collection of all vertices.
  associatedtype VertexCollection: HierarchicalCollection where VertexCollection.Element == VertexId

  /// The total number of vertices in the graph.
  ///
  /// Note: `vertexCount` might have O(V) complexity.
  var vertexCount: Int { get }

  /// All of the graph's vertices.
  func vertices() -> VertexCollection
}

/// An `EdgeListGraph` is a graph that can enumerate all edges within it.
public protocol EdgeListGraph: GraphProtocol {

  /// The collection of all edge identifiers.
  associatedtype EdgeCollection: HierarchicalCollection where EdgeCollection.Element == EdgeId

  /// The total number of edges within the graph.
  ///
  /// Note: `edgeCount` might have O(|V| + |E|) complexity.
  var edgeCount: Int { get }

  /// A collection of edges.
  func edges() -> EdgeCollection

  /// Returns the source vertex of `edge`.
  func source(of edge: EdgeId) -> VertexId

  /// Returns the destination vertex of `edge`.
  func destination(of edge: EdgeId) -> VertexId
}

/// A graph that allows retrieval of edges from a given node.
public protocol IncidenceGraph: GraphProtocol {
  /// The collection of edges originating from a given vertex.
  associatedtype VertexEdgeCollection: Collection where VertexEdgeCollection.Element == EdgeId

  /// Computes the collection of edges from `vertex`.
  func edges(from vertex: VertexId) -> VertexEdgeCollection

  /// Returns the source `VertexId` of `edge`.
  func source(of edge: EdgeId) -> VertexId

  /// Returns the source `VertexId` of `edge`.
  func destination(of edge: EdgeId) -> VertexId

  /// Computes the out-degree of `vertex`.
  func outDegree(of vertex: VertexId) -> Int
}
