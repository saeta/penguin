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

/// PropertyAdjacencyList is a general-purpose graph implementation with attached data to edges and
/// verticies.
///
/// PropertyAdjacencyList implements a directed graph. If you would like an undirected graph, simply
/// add two edges, representing each direction. Additionally, PropertyAdjacencyList supports
/// parallel edges. It is up to the user to ensure no parallel edges are added if parallel edges are
/// undesired.
///
/// In order to support generic algorithms that modify the graph structure, elements within a
/// PropertyAdjacencyList must support an initializer that takes zero arguments.
///
/// Operations that do not modify the graph structure occur in O(1) time. Additional operations that
/// run in O(1) time include: adding a new edge, adding a new vertex. Operations that remove either
/// verticies or edges invalidate existing `VertexId`s and `EdgeId`s. Adding new verticies or edges
/// do not invalidate previously computed ids.
///
/// PropertyAdjacencyList is parameterized by the `IdType` which can be carefully tuned to save
/// memory. A good default is `Int32`, unless you are trying to represent more than 2^32 verticies.
///
/// - SeeAlso: `AdjacencyList`
public struct PropertyAdjacencyList<
    Vertex: DefaultInitializable,
    Edge: DefaultInitializable,
    IdType: BinaryInteger
>: GraphProtocol {
    private var adjacencyList = AdjacencyList<IdType>()
    private var vertexProperties = [Vertex]()
    private var edgeProperties = [[Edge]]()

    /// A handle to refer to a vertex in the graph.
    public typealias VertexId = AdjacencyList<IdType>.VertexId

    /// A handle to refer to an edge in the graph.
    public typealias EdgeId = AdjacencyList<IdType>.EdgeId

    /// Initialize an empty PropertyAdjacencyList.
    public init() {}
}

extension PropertyAdjacencyList: VertexListGraph {
    public var vertexCount: Int { adjacencyList.vertexCount }
    public func verticies() -> AdjacencyList<IdType>.VertexCollection { adjacencyList.verticies() }
}

extension PropertyAdjacencyList: EdgeListGraph {
    public var edgeCount: Int { adjacencyList.edgeCount }
    public func edges() -> AdjacencyList<IdType>.EdgeCollection { adjacencyList.edges() }
    public func source(of edge: EdgeId) -> VertexId { adjacencyList.source(of: edge) }
    public func destination(of edge: EdgeId) -> VertexId { adjacencyList.destination(of: edge) }
}

extension PropertyAdjacencyList: MutableGraph {
    // Note: addEdge(from:to:) and addVertex() supplied based on MutablePropertyGraph conformance.

    public mutating func removeEdge(from u: VertexId, to v: VertexId) {
        // TODO: verify this handles parallel edges properly?
        let edges = adjacencyList.edges(from: u).filter { $0.destination == v }
        let offsets = Set(edges.map { $0.offset })
        adjacencyList.removeEdges(from: u) { offsets.contains($0.offset) }

        // TODO: Ask Crusty for a better idea here... maybe a gather instead?
        for edge in edges.reversed() {
            edgeProperties[u.index].remove(at: edge.offset)
        }
    }

    public mutating func remove(edge: EdgeId) {
        adjacencyList.remove(edge: edge)
        edgeProperties[edge.source.index].remove(at: edge.offset)
    }

    public mutating func removeEdges(_ predicate: (EdgeId) throws -> Bool) rethrows {
        // TODO: Implement this better!!
        var edgesToRemove = [EdgeId]()
        try adjacencyList.removeEdges { edge in
            if try predicate(edge) {
                edgesToRemove.append(edge)
                return true
            }
            return false
        }

        // Crusty!
        for edge in edgesToRemove.reversed() {
            edgeProperties[edge.source.index].remove(at: edge.offset)
        }
    }

    public mutating func removeEdges(from node: VertexId, _ predicate: (EdgeId) throws -> Bool) rethrows {
        var offsetsToRemove = [Int]()

        try adjacencyList.removeEdges(from: node) { edge in
            if try predicate(edge) {
                offsetsToRemove.append(edge.offset)
                return true
            }
            return false
        }

        // Crusty!!
        for offset in offsetsToRemove.reversed() {
            edgeProperties[node.index].remove(at: offset)
        }
    }

    public mutating func clear(vertex: VertexId) {
        adjacencyList.clear(vertex: vertex)
        edgeProperties[vertex.index].removeAll()
    }

    public mutating func remove(vertex: VertexId) {
        fatalError("Unimplemented!")
    }
}

extension PropertyAdjacencyList: PropertyGraph {
    /// Access information associated with a given `VertexId`.
    public subscript(vertex vertex: VertexId) -> Vertex {
        get {
            vertexProperties[vertex.index]
        }
        _modify {
            yield &vertexProperties[vertex.index]
        }
    }

    public subscript<T>(vertex vertex: VertexId, keypath: KeyPath<Vertex, T>) -> T {
        vertexProperties[vertex.index][keyPath: keypath]
    }

    public subscript(edge edge: EdgeId) -> Edge {
        get {
            edgeProperties[edge.source.index][edge.offset]
        }
        _modify {
            yield &edgeProperties[edge.source.index][edge.offset]
        }
    }

    public subscript<T>(edge edge: EdgeId, keypath: KeyPath<Edge, T>) -> T {
        edgeProperties[edge.source.index][edge.offset][keyPath: keypath]
    }
}

extension PropertyAdjacencyList: MutablePropertyGraph {
    public mutating func addVertex(with information: Vertex) -> VertexId {
        vertexProperties.append(information)
        edgeProperties.append([])
        return adjacencyList.addVertex()
    }

    public mutating func addEdge(from source: VertexId, to destination: VertexId, with information: Edge) -> EdgeId {
        let id = adjacencyList.addEdge(from: source, to: destination)
        assert(id.offset == edgeProperties[source.index].count)
        edgeProperties[source.index].append(information)
        return id
    }
}

extension PropertyAdjacencyList: IncidenceGraph {
  public typealias VertexEdgeCollection = AdjacencyList<IdType>.VertexEdgeCollection
  public func edges(from vertex: VertexId) -> VertexEdgeCollection {
    adjacencyList.edges(from: vertex)
  }

  public func outDegree(of vertex: VertexId) -> Int {
    adjacencyList.outDegree(of: vertex)
  }
}
