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
    mutating func set(graph: inout Graph, vertex: Graph.VertexId, value: Value)
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
    mutating func set(graph: inout Graph, edge: Graph.EdgeId, value: Value)
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
public protocol MutablePropertyGraph: MutableGraph, PropertyGraph where Vertex: DefaultInitializable, Edge: DefaultInitializable {
    // /// The vertex must be default initializable in order to support other mutable graph operations.
    // associatedtype Vertex: DefaultInitializable
    // /// The edge must be default initializable in order to support other mutable graph operations.
    // associatedtype Edge: DefaultInitializable

    /// Adds a vertex to the graph.
    mutating func addVertex(with information: Vertex) -> VertexId

    /// Adds an edge to the graph.
    mutating func addEdge(from source: VertexId, to destination: VertexId, with information: Edge) -> EdgeId
}

public extension MutablePropertyGraph {
    /// Adds a new vertex to the graph, with a default initialized `Vertex`.
    mutating func addVertex() -> VertexId {
        addVertex(with: Vertex())
    }

    /// Adds an edge from `source` to `destination` with a default initialized `Edge`.
    mutating func addEdge(from source: VertexId, to destination: VertexId) -> EdgeId {
        addEdge(from: source, to: destination, with: Edge())
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

/// A type is `DefaultInitializable` as long as it can be initialized with no parameters.
public protocol DefaultInitializable {
    /// Initialize `self` with default values. `self` must be in a valid (but unspecified) state.
    init()
}
