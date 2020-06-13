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
  /// - Precondition: if parallel edges are disallowed, there must not exist an edge from `source`
  ///   to `destination` already present in `self`.
  /// - Complexity: either O(1) (amortized) or O(log(|E|/|V|)) if checking for parallel edges.
  mutating func addEdge(from source: VertexId, to destination: VertexId) -> EdgeId

  /// Removes the edge (u, v) if present in `self`.
  ///
  /// If the graph allows parallel edges, it removes all matching edges.
  ///
  /// - Precondition: `u` and `v` are vertices in `self`.
  /// - Complexity: worst case O(|E|).
  /// - Returns: true if one or more edges were removed; false otherwise.
  @discardableResult
  mutating func removeEdge(from u: VertexId, to v: VertexId) -> Bool

  /// Removes the edge `edge` from the graph.
  ///
  /// - Precondition: `edge` is a valid `EdgeId` from `self`.
  mutating func remove(_ edge: EdgeId)

  /// Removes all edges identified by `shouldBeRemoved`.
  mutating func removeEdges(where shouldBeRemoved: (EdgeId, Self) -> Bool)

  /// Removes all out edges from `vertex` identified by `shouldBeRemoved`.
  ///
  /// - Complexity: O(|E|)
  mutating func removeEdges(from vertex: VertexId, where shouldBeRemoved: (EdgeId, Self) -> Bool)

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

// TODO: should this be `VertexCollectionGraph`?
/// A `VertexListGraph` is a graph that can enumerate all the vertices within it.
public protocol VertexListGraph: GraphProtocol {

  /// The collection of all vertices.
  associatedtype VertexCollection: Collection where VertexCollection.Element == VertexId

  /// The total number of vertices in the graph.
  ///
  /// Note: `vertexCount` might have O(V) complexity.
  var vertexCount: Int { get }

  /// All of the graph's vertices.
  var vertices: VertexCollection { get }
}

extension VertexListGraph {
  /// The total number of vertices in the graph.
  ///
  /// Note: `vertexCount` might have O(V) complexity.
  public var vertexCount: Int { vertices.count }
}

// TODO: should this be `EdgeCollectionGraph`?
/// An `EdgeListGraph` is a graph that can enumerate all edges within it.
public protocol EdgeListGraph: GraphProtocol {

  /// The collection of all edge identifiers.
  associatedtype EdgeCollection: Collection where EdgeCollection.Element == EdgeId

  /// The total number of edges within the graph.
  ///
  /// Note: `edgeCount` might have O(|V| + |E|) complexity.
  var edgeCount: Int { get }

  /// A collection of edges.
  var edges: EdgeCollection { get }

  /// Returns the source vertex of `edge`.
  func source(of edge: EdgeId) -> VertexId

  /// Returns the destination vertex of `edge`.
  func destination(of edge: EdgeId) -> VertexId
}

/// A graph that allows retrieval of edges from each vertex.
public protocol IncidenceGraph: GraphProtocol {
  /// The collection of edges originating from a given vertex.
  associatedtype VertexEdgeCollection: Collection where VertexEdgeCollection.Element == EdgeId

  /// Returns the collection of edges whose source is `vertex`.
  func edges(from vertex: VertexId) -> VertexEdgeCollection

  /// Returns the source `VertexId` of `edge`.
  func source(of edge: EdgeId) -> VertexId

  /// Returns the source `VertexId` of `edge`.
  func destination(of edge: EdgeId) -> VertexId

  /// Returns the number of edges whose source is `vertex`.
  func outDegree(of vertex: VertexId) -> Int
}

extension IncidenceGraph {
  /// Returns the number of edges whose source is `vertex`.
  public func outDegree(of vertex: VertexId) -> Int {
    edges(from: vertex).count
  }
}

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

/// A graph that provides defaults for graph searching algorithms.
///
/// Implementations of Graph algorithms often demand a variety of associated data structures.
/// A graph that conforms to `SearchDefaultsGraph` provides default types that make using these
/// graph data structures more convenient.
///
/// To conform an `IncidenceGraph` to `SearchDefaultsGraph`, simpliy implement the required methods.
/// Reasonable choices for IdIndexable VertexId's often use `TablePropertyMap`s. For graphs with
/// hashable VertexId's, the `DictionaryPropertyMap` is often a good choice.
public protocol SearchDefaultsGraph: IncidenceGraph {
  /// A reasonable choice for a data structure to use when keeping track of visitation state during
  /// graph searches and traversals.
  associatedtype DefaultColorMap: PropertyMap
    where DefaultColorMap.Graph == Self, DefaultColorMap.Key == VertexId, DefaultColorMap.Value == VertexColor

  /// Creates an instance of the default color map where every vertex is set to `color`.
  func makeDefaultColorMap(repeating color: VertexColor) -> DefaultColorMap
}

/// A graph that allows retrieval of edges incoming to each vertex (the "in-edges").
public protocol BidirectionalGraph: IncidenceGraph {
  /// The collection of edges whose destinations are a given vertex (the "in-edges").
  associatedtype VertexInEdgeCollection: Collection where VertexInEdgeCollection.Element == EdgeId

  /// Returns the collection of edges whose destination is `vertex`.
  func edges(to vertex: VertexId) -> VertexInEdgeCollection

  /// Returns the number of "in-edges" of `vertex`.
  func inDegree(of vertex: VertexId) -> Int

  /// Returns the number of "in-edges" plus "out-edges" of `vertex` in `self`.
  func degree(of vertex: VertexId) -> Int
}

extension BidirectionalGraph {
  /// Returns the number of "in-edges" of `vertex`.
  public func inDegree(of vertex: VertexId) -> Int {
    edges(to: vertex).count
  }

  /// Returns the number of "in-edges" plus "out-edges" of `vertex` in `self`.
  public func degree(of vertex: VertexId) -> Int {
    inDegree(of: vertex) + outDegree(of: vertex)
  }
}
