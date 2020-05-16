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

/// Abstracts over storage location for values associated with graphs.
///
/// Graph algorithms often need to store data during the course of execution, such as vertex color
/// (during search), or the costs of traversing an edge (e.g. Dijkstra's algorithm). While some
/// graph types can store data within the graph structure itself. (e.g. `AdjacencyList` allows
/// associating data with every vertex and edge.) Some graph data structures are not materialized
/// whatsoever (e.g. the possible moves on a knight's tour on a chess board). Additionally, data is
/// often needed only during the course of an algorithm, and is discarded afterwards. As a result,
/// it would be inefficient to pay the cost of requiring every graph implementation to persist this
/// transient state. Fortunately, property maps allow us to leverage "in-graph" storage when it
/// is available, while also allowing data to be stored outside the graph when convenient as well,
/// all behind a single abstraction. In short, thanks to the PropertyMap protocol, we can write an
/// algorithm once using one or more PropertyMap's, and the algorithm can be re-used independent of
/// whether the data is stored within the graph data structure or in a separate data structure.
///
/// - SeeAlso: `ExternalPropertyMap`
public protocol PropertyMap {
  associatedtype Graph: GraphProtocol
  associatedtype Key
  associatedtype Value

  /// Get the `Value` associated with `key` in `graph`.
  func get(_ key: Key, in graph: Graph) -> Value

  // TODO: Consider splitting set out into a refinement protocol?

  /// Sets the `Value` associated with `key` in `graph`.
  mutating func set(_ key: Key, in graph: inout Graph, to newValue: Value)
}

/// External property maps store data outside the graph.
public protocol ExternalPropertyMap: PropertyMap {
  subscript(key: Key) -> Value { get set }
}

extension ExternalPropertyMap {
  public func get(_ key: Key, in graph: Graph) -> Value {
    self[key]
  }

  public mutating func set(_ key: Key, in graph: inout Graph, to newValue: Value) {
    self[key] = newValue
  }
}

/// A `PropertyGraph` stores additional information along with the graph structure.
public protocol PropertyGraph: GraphProtocol {
  /// The extra information associated with each vertex.
  associatedtype Vertex

  /// The extra information associated with each edge.
  associatedtype Edge

  /// Access information associated with a given `VertexId`.
  subscript(vertex vertex: VertexId) -> Vertex { get set /* _modify */ }

  /// Access information associated with a given `EdgeId`.
  subscript(edge edge: EdgeId) -> Edge { get set /* _modify */ }
}

/// A `MutablePropertyGraph` keeps track of additional metadata for each vertex and edge.
public protocol MutablePropertyGraph: MutableGraph, PropertyGraph
where Vertex: DefaultInitializable, Edge: DefaultInitializable {

  /// Adds a vertex to the graph.
  mutating func addVertex(storing vertexProperty: Vertex) -> VertexId

  /// Adds an edge to the graph.
  mutating func addEdge(from source: VertexId, to destination: VertexId, storing edgeProperty: Edge)
    -> EdgeId
}

extension MutablePropertyGraph {
  /// Adds a new vertex to the graph, with a default initialized `Vertex`.
  public mutating func addVertex() -> VertexId {
    addVertex(storing: Vertex())
  }

  /// Adds an edge from `source` to `destination` with a default initialized `Edge`.
  public mutating func addEdge(from source: VertexId, to destination: VertexId) -> EdgeId {
    addEdge(from: source, to: destination, storing: Edge())
  }
}

/// A `PropertyMap` over the vertices of `Graph`.
public struct InternalVertexPropertyMap<Graph: PropertyGraph>: PropertyMap {
  public typealias Key = Graph.VertexId
  public typealias Value = Graph.Vertex

  /// Create an `InternalVertexPropertyMap` for `graph`.
  public init(for graph: __shared Graph) {}

  /// Creates an `InternalVertexPropertyMap`.
  public init() {}

  /// Retrieves the property value from `graph` for `vertex`.
  public func get(_ vertex: Graph.VertexId, in graph: Graph) -> Value {
    graph[vertex: vertex]
  }

  public mutating func set(_ vertex: Graph.VertexId, in graph: inout Graph, to newValue: Value) {
    graph[vertex: vertex] = newValue
  }
}

/// A `PropertyMap` over the edges of `Graph`.
public struct InternalEdgePropertyMap<Graph: PropertyGraph>: PropertyMap {
  public typealias Key = Graph.EdgeId
  public typealias Value = Graph.Edge

  /// Create an `InternalEdgePropertyMap` for `graph`.
  public init(for graph: __shared Graph) {}

  /// Creates an `InternalEdgePropertyMap`.
  public init() {}

  /// Retrieves the property value from `graph` for `edge`.
  public func get(_ edge: Graph.EdgeId, in graph: Graph) -> Value {
    graph[edge: edge]
  }

  public mutating func set(_ edge: Graph.EdgeId, in graph: inout Graph, to newValue: Value) {
    graph[edge: edge] = newValue
  }
}

public struct TransformingPropertyMap<NewValue, Underlying: PropertyMap>: PropertyMap {
  let keyPath: WritableKeyPath<Underlying.Value, NewValue>
  var underlying: Underlying

  public func get(_ key: Underlying.Key, in graph: Underlying.Graph) -> NewValue {
    return underlying.get(key, in: graph)[keyPath: keyPath]
  }

  public mutating func set(_ key: Underlying.Key, in graph: inout Underlying.Graph, to newValue: NewValue) {
    // Future improvement: coroutines would be nice here. :-(
    var tmp = underlying.get(key, in: graph)
    tmp[keyPath: keyPath] = newValue
    underlying.set(key, in: &graph, to: tmp)
  }
}

extension PropertyMap {
  public func transform<NewValue>(_ keyPath: WritableKeyPath<Value, NewValue>) -> TransformingPropertyMap<NewValue, Self> {
    TransformingPropertyMap(keyPath: keyPath, underlying: self)
  }
}

/// A table-based external property map.
public struct TablePropertyMap<Graph: GraphProtocol, Key, Value>: ExternalPropertyMap
where Key: IdIndexable {
  public var values: [Value]

  /// Creates an instance where every key has value `initialValue`.
  public init(repeating initialValue: Value, count: Int) {
    values = Array(repeating: initialValue, count: count)
  }

  /// Creates an instance with `values`, indexed by `\Key.index`.
  public init(_ values: [Value]) {
    self.values = values
  }

  public subscript(key: Key) -> Value {
    get { values[key.index] }
    set { values[key.index] = newValue }
  }
}

extension TablePropertyMap where Graph: VertexListGraph, Graph.VertexId: IdIndexable, Key == Graph.VertexId {

  /// Creates an instance where every vertex has `initialValue` for use with `graph`.
  ///
  /// This initializer helps the type inference algorithm, obviating the need to spell out some of
  /// the types.
  public init(repeating initialValue: Value, forVerticesIn graph: __shared Graph) {
    self.init(repeating: initialValue, count: graph.vertexCount)
  }

  /// Creates an instance where the verticies have values `values`.
  ///
  /// This initializer helps the type inference algorithm, and does some consistency checking.
  public init(_ values: [Value], forVerticesIn graph: __shared Graph) {
    assert(values.count == graph.vertexCount)
    self.init(values)
  }
}

extension TablePropertyMap where Value: DefaultInitializable {
  /// Initializes `self` with the default value for `count` verticies.
  public init(count: Int) {
    self.init(repeating: Value(), count: count)
  }
}

extension TablePropertyMap where Graph: VertexListGraph, Graph.VertexId: IdIndexable, Value: DefaultInitializable {
  public init(forVerticesIn graph: __shared Graph) {
    self.init(repeating: Value(), count: graph.vertexCount)
  }
}

/// An external property map backed by a dictionary.
public struct DictionaryPropertyMap<Graph: GraphProtocol, Key, Value>: ExternalPropertyMap
where Key: Hashable {

  /// The mapping of edges to values.
  var values: [Key: Value]

  /// Initialize `self` providing `values` for each edge.
  public init(_ values: [Key: Value]) {
    self.values = values
  }

  public subscript(key: Key) -> Value {
    get { values[key]! }
    set { values[key] = newValue }
  }
}

extension DictionaryPropertyMap where Graph.EdgeId: Hashable, Key == Graph.EdgeId {
  /// Initializes `self` using `values`; `graph` is unused, but helps type inference along nicely.
  public init(_ values: [Graph.EdgeId: Value], forEdgesIn graph: __shared Graph) {
    self.init(values)
  }
}
