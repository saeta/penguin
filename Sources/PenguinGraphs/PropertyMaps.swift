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

/// Maps a `VertexId` from a Graph to a property of type `Value` associated with that `VertexId`.
///
/// Many graph algorithms require information associated with each vertex. Examples include:
///   - if a vertex is a "goal" vertex in a graph search
///   - if a vertex has been explored yet during a graph search (e.g. color).
///   - the "predecessor" of a vertex (e.g. in a search)
///   - the "discovery time" of a vertex (e.g. in a search)
///   - the rank of a vertex
///
/// `GraphVertexPropertyMap` abstracts over different storage implementations of the associated data
/// for each vertex. Some graph implementations may store the associated information within the
/// Graph data structure itself. Other graph implementations may want to store the information in
/// a separate data structure (e.g. temporary data used within a single graph algorithm).
///
/// - SeeAlso: `MutableGraphVertexPropertyMap`
/// - SeeAlso: `GraphEdgePropertyMap`
/// - SeeAlso: `InternalVertexPropertyMap`
public protocol GraphVertexPropertyMap {
  /// The Graph this PropertyMap operates on.
  associatedtype Graph: GraphProtocol
  /// The data associated with each vertex by this map.
  associatedtype Value

  /// Retrieves the `Value` associated with vertex `vertex` in `graph`.
  func get(_ graph: Graph, _ vertex: Graph.VertexId) -> Value
}

/// Allows modifying the associated vertex data.
///
/// Some graph algorithms modify associated data during their execution. PropertyMaps that conform
/// to this protocol allow the associated data to be modified using `set`.
///
/// Note: in order to support both "internal" and "external" backing data structures for the
/// property map, we take `graph` as `inout`.
public protocol MutableGraphVertexPropertyMap: GraphVertexPropertyMap {

  /// Sets the property on `vertex` to `value`.
  mutating func set(vertex: Graph.VertexId, in graph: inout Graph, to value: Value)
}

/// Maps an `EdgeId` from a Graph to a property of type `Value` associated with that `EdgeId`.
///
/// Many graph algorithms require information associated with each edge. Examples include:
///   - Weight of an edge to determine the cost of traversing it (e.g. during Dijkstra search).
///   - Capacity of an edge to determine the maximum amount of flow that can traverse an edge.
///   - The `EdgeId` of the reverse edge.
///
/// `GraphEdgePropertyMap` abstracts over different storage implementations of the associated data
/// for each edge. Some graph implementations may store the associated data within the graph data
/// structure itself. Other graph implementations may want to store the information in a separate
/// data structure (e.g. temporary data used within a single graph algorithm).
///
/// - SeeAlso: `MutableGraphEdgePropertyMap`
/// - SeeAlso: `GraphVertexPropertyMap`
/// - SeeAlso: `InternalEdgePropertyMap`
public protocol GraphEdgePropertyMap {
  /// The graph this PropertyMap operates on.
  associatedtype Graph: GraphProtocol
  /// The data associated with each edge by this map.
  associatedtype Value

  /// Retrieves the `Value` associated with edge `edge` in `graph`.
  func get(_ graph: Graph, _ edge: Graph.EdgeId) -> Value
}

/// Allows modifying the associated edge data.
///
/// Some graph algorithms modify associated data during their execution. PropertyMaps that conform
/// to this protocol  allow the associated data to be modified using `set`.
///
/// Note: in order to support both "internal" and "external" backing data structures for the
/// property map, we take `graph` as `inout`.
public protocol MutableGraphEdgePropertyMap: GraphEdgePropertyMap {

  /// Sets the property on `edge` to `value`.
  mutating func set(edge: Graph.EdgeId, in graph: inout Graph, to value: Value)
}

/// A `PropertyGraph` stores additional information along with the graph structure.
public protocol PropertyGraph: GraphProtocol {
  /// The extra information associated with each vertex.
  associatedtype Vertex

  /// The extra information associated with each edge.
  associatedtype Edge

  /// Access information associated with a given `VertexId`.
  subscript(vertex vertex: VertexId) -> Vertex { get set /* _modify */ }

  /// Access a property related to a given vertex.
  subscript<T>(vertex vertex: VertexId, keypath: KeyPath<Vertex, T>) -> T { get /* set _modify */ }

  /// Access information associated with a given `EdgeId`.
  subscript(edge edge: EdgeId) -> Edge { get set /* _modify */ }

  /// Access a property for a given edge.
  subscript<T>(edge edge: EdgeId, keypath: KeyPath<Edge, T>) -> T { get /* set _modify */ }
}

/// A `MutablePropertyGraph` keeps track of additional metadata for each vertex and edge.
public protocol MutablePropertyGraph: MutableGraph, PropertyGraph
where Vertex: DefaultInitializable, Edge: DefaultInitializable {

  /// Adds a vertex to the graph.
  mutating func addVertex(_ information: Vertex) -> VertexId

  /// Adds an edge to the graph.
  mutating func addEdge(from source: VertexId, to destination: VertexId, _ information: Edge)
    -> EdgeId
}

extension MutablePropertyGraph {
  /// Adds a new vertex to the graph, with a default initialized `Vertex`.
  public mutating func addVertex() -> VertexId {
    addVertex(Vertex())
  }

  /// Adds an edge from `source` to `destination` with a default initialized `Edge`.
  public mutating func addEdge(from source: VertexId, to destination: VertexId) -> EdgeId {
    addEdge(from: source, to: destination, Edge())
  }
}

/// Defines a `GraphVertexPropertyMap` exposing properties stored in the vertex type of the graph.
///
/// Example: say we had a Vertex type defined as follows:
///
/// ```swift
/// struct City {
///   let name: String
/// }
///
/// extension City {
///   var isGoal: Bool { name == "Rome" }  // Do all roads lead to Rome?
/// }
/// ```
///
/// we could expose the `isGoal` property (e.g. which can be used to terminate a graph traversal)
/// as follows:
///
/// ```swift
/// var g: PropertyGraph = ...
/// var goalMap = InternalVertexPropertyMap(\City.isGoal, on: g)
/// ```
public struct InternalVertexPropertyMap<
  Graph: PropertyGraph,
  Value,
  Path: KeyPath<Graph.Vertex, Value>
>: GraphVertexPropertyMap {

  /// The KeyPath between the `Graph.Vertex` and the `Value` reterned by the property map.
  public let keyPath: Path

  /// Create an `InternalVertexPropertyMap` for a given keyPath `Path`.
  ///
  /// If `Path` is a `WritableKeyPath`, then this also conforms to `MutableGraphVertexPropertyMap`.
  public init(_ keyPath: Path, on graph: __shared Graph) {
    self.keyPath = keyPath
  }

  /// Initialize an `InternalVertexPropertyMap` from the given key path.
  public init(_ keyPath: Path) {
    self.keyPath = keyPath
  }

  /// Retrieves the property value from `graph` for `vertex`.
  public func get(_ graph: Graph, _ vertex: Graph.VertexId) -> Value {
    graph[vertex: vertex][keyPath: keyPath]
  }
}

// extension InternalVertexPropertyMap: MutableGraphVertexPropertyMap where Path: WritableKeyPath<Graph.Vertex, Value> {
//  /// Sets the property value for `vertex` within `graph`.
//     public mutating func set(graph: inout Graph, vertex: Graph.VertexId, value: Value) {
//         graph[vertex: vertex][keyPath: keyPath] = value
//     }
// }

/// Defines a `GraphEdgePropertyMap` exposing properties stored in the edge type of the graph.
///
/// Example: say we had an `Edge` type defined as follows:
///
/// ```swift
/// struct WeightedEdge {
///   var weight: Int
/// }
/// ```
///
/// we could expose the `weight` property (e.g. which can be used to evaluate the cost of traversing
/// the edge) as follows:
///
/// ```swift
/// var g: PropertyGraph = ...
/// var weightMap = InternalEdgePropertyMap(\WeightedEdge.weight, on: g)
/// ```
///
/// If you would like to initialize a map without an instance of a graph, you will need to spell out
/// the types a bit more explicitly:
///
/// ```swift
/// typealias Graph = PropertyAdjacencyList<VertexType, WeightedEdge, Int32>
/// var weightMap = InternalEdgePropertyMap<Graph, Int, KeyPath<WeightedEdge, Int>(\WeightedEdge.weight)
/// ```
public struct InternalEdgePropertyMap<
  Graph: PropertyGraph,
  Value,
  Path: KeyPath<Graph.Edge, Value>
>: GraphEdgePropertyMap {

  /// The KeyPath between `Graph.Edge` and `Value`.
  public let keyPath: Path

  /// Initialize an `InternalEdgePropertyMap` from the given `keyPath`.
  ///
  /// `graph` is taken as an additional argument to facilitate type inference.
  public init(_ keyPath: Path, on graph: __shared Graph) {
    self.keyPath = keyPath
  }

  /// Initialize an `InternalEdgePropertyMap` from the given `keyPath`.
  public init(_ keyPath: Path) {
    self.keyPath = keyPath
  }

  public func get(_ graph: Graph, _ edge: Graph.EdgeId) -> Value {
    graph[edge: edge][keyPath: keyPath]
  }
}

// extension InternalEdgePropertyMap: MutableGraphEdgePropertyMap where Path: WritableKeyPath<Graph.Edge, Value> {
//     public mutating func set(graph: inout Graph, edge: Graph.EdgeId, value: Value) {
//         graph[edge: edge][keyPath: keyPath] = value
//     }
// }

/// A table-based vertex property map.
public struct TableVertexPropertyMap<Graph: GraphProtocol, Value>: GraphVertexPropertyMap,
  MutableGraphVertexPropertyMap
where Graph.VertexId: IdIndexable {
  var values: [Value]

  /// Creates an instance where every vertex has value `initialValue`.
  ///
  /// Note: `count` must exactly equal `Graph.vertexCount`!
  public init(repeating initialValue: Value, count: Int) {
    values = Array(repeating: initialValue, count: count)
  }

  /// Creates an instance with `values`, indexed by the Graph's vertex indicies.
  public init(_ values: [Value]) {
    self.values = values
  }

  /// Retrieves the `Value` associated with vertex `vertex` in `graph`.
  public func get(_ graph: Graph, _ vertex: Graph.VertexId) -> Value {
    values[vertex.index]
  }

  /// Sets the property on `vertex` to `value`.
  public mutating func set(vertex: Graph.VertexId, in graph: inout Graph, to value: Value) {
    values[vertex.index] = value
  }

}

extension TableVertexPropertyMap where Graph: VertexListGraph {
  /// Creates an instance where every vertex has `initialValue` for use with `graph`.
  ///
  /// This initializer helps the type inference algorithm, obviating the need to spell out some of
  /// the types.
  public init(repeating initialValue: Value, for graph: __shared Graph) {
    self.init(repeating: initialValue, count: graph.vertexCount)
  }

  /// Creates an instance where the verticies have values `values`.
  ///
  /// This initializer helps the type inference algorithm, and does some consistency checking.
  public init(_ values: [Value], for graph: __shared Graph) {
    assert(values.count == graph.vertexCount)
    self.init(values)
  }
}

extension TableVertexPropertyMap where Value: DefaultInitializable {
  /// Initializes `self` with the default value for `count` verticies.
  public init(count: Int) {
    self.init(repeating: Value(), count: count)
  }
}

/// An external property map backed by a dictionary.
public struct DictionaryEdgePropertyMap<Graph: GraphProtocol, Value>:
  GraphEdgePropertyMap, MutableGraphEdgePropertyMap
where Graph.EdgeId: Hashable {

  /// The mapping of edges to values.
  var values: [Graph.EdgeId: Value]

  /// Initialize `self` providing `values` for each edge.
  public init(_ values: [Graph.EdgeId: Value]) {
    self.values = values
  }

  /// Retrieves the value for `edge` in `graph`.
  public func get(_ graph: Graph, _ edge: Graph.EdgeId) -> Value {
    values[edge]!
  }

  /// Sets `edge` in `graph` to `value`.
  public mutating func set(edge: Graph.EdgeId, in graph: inout Graph, to value: Value) {
    values[edge] = value
  }
}

extension DictionaryEdgePropertyMap {
  /// Initializes `self` using `values`; `graph` is unused, but helps type inference along nicely.
  public init(_ values: [Graph.EdgeId: Value], for graph: __shared Graph) {
    self.init(values)
  }
}
