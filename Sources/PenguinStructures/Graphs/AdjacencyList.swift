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

/// The vertex/edge structure of an arbitrary [adjacency
/// list](https://en.wikipedia.org/wiki/Adjacency_list) graph.
///
/// AdjacencyList implements a directed graph. If you would like an undirected graph, simply add
/// two edges, representing each direction. Additionally, AdjacencyList supports parallel edges.
/// It is up to the user to ensure no parallel edges are added if parallel edges are undesired.
///
/// Operations that do not modify the graph structure occur in O(1) time. Additional operations that
/// run in O(1) time include: adding a new edge, adding a new vertex. Operations that remove either
/// vertices or edges invalidate existing `VertexId`s and `EdgeId`s. Adding new vertices or edges
/// do not invalidate previously computed ids.
///
/// AdjacencyList is parameterized by the `RawVertexId` which can be carefully tuned to save memory.
/// A good default is `Int32`, unless you are trying to represent more than 2^32 vertices.
///
/// - SeeAlso: `PropertyAdjacencyList`
public struct AdjacencyList<RawVertexId: BinaryInteger>: GraphProtocol {
	// The edges within the graph.
	private var edgesArray: [[RawVertexId]]

	/// Creates an empty adjacency list.
	public init() {
		edgesArray = []
	}

	// TODO: consider just making it an `RawVertexId` or an `Int`.
	/// The name of a vertex in this graph.
	///
	/// Note: `VertexId`'s are not stable across some graph mutation operations.
	public struct VertexId: Equatable, IdIndexable, Hashable {
		let id: RawVertexId
		init(_ id: RawVertexId) {
			self.id = id
		}

		/// A contiguous, dense, zero-indexed integer representation of the vertex.
		///
		/// Note: `index` is not stable across mutations to the graph structure.
		public var index: Int { Int(id) }
	}

	/// The name of an edge in this graph.
	///
	/// Note: `EdgeId`'s are not stable across some graph mutation operations.
	public struct EdgeId: Equatable, Hashable {
		let source: VertexId
		let destination: VertexId
		let offset: Int
	}

	/// Ensures `id` is a valid vertex in `self`, halting execution otherwise.
	func assertValid(_ id: VertexId, name: StaticString? = nil) {
		func makeName() -> String {
			if let name = name { return " (\(name))" }
			return ""
		}
		assert(id.id < edgesArray.count, "Vertex \(id)\(makeName()) is not valid.")
	}

	/// Ensures `id` is a valid edge in `self`, halting execution otherwise.
	func assertValid(_ id: EdgeId) {
		assertValid(id.source, name: "source")
		assertValid(id.destination, name: "destination")
		assert(id.offset < edgesArray[id.source.index].count)
	}
}

extension AdjacencyList: MutableGraph {
    /// Adds an edge from `source` to `destination`.
	public mutating func addEdge(from source: VertexId, to destination: VertexId) -> EdgeId {
		assertValid(source, name: "source")
		assertValid(destination, name: "destination")
		let offset = edgesArray[source.index].count
		edgesArray[source.index].append(destination.id)
		return EdgeId(source: source, destination: destination, offset: offset)
	}

    /// Removes all edges from `u` to `v`.
    ///
    /// If there are parallel edges, it removes all edges.
    ///
    /// - Precondition: `u` and `v` are vertices in `self`.
    /// - Throws: `GraphErrors.edgeNotFound` if there is no edge from `u` to `v`.
    /// - Complexity: worst case O(|E|)
	public mutating func removeEdge(from u: VertexId, to v: VertexId) throws {
		assertValid(u, name: "u")
		assertValid(v, name: "v")
		let previousEdgeCount = edgesArray[u.index].count
		edgesArray[u.index].removeAll { $0 == v.id }
		if previousEdgeCount == edgesArray[u.index].count {
			throw GraphErrors.edgeNotFound
		}
	}

    /// Removes `edge`.
    ///
    /// - Precondition: `edge` is a valid `EdgeId` from `self`.
	public mutating func remove(edge: EdgeId) {
		assertValid(edge)
		assert(edgesArray[edge.source.index][edge.offset] == edge.destination.id,
			"""
			Attempting to remove an edge with inconsistent index & destination. \
			Are you holding onto an EdgeId during graph struture mutation?
			""")
		edgesArray[edge.source.index].remove(at: edge.offset)
	}

    /// Removes all edges that satisfy `predicate`.
	public mutating func removeEdges(where shouldBeRemoved: (EdgeId) throws -> Bool) rethrows {
		for sourceId in 0..<edgesArray.count {
			try removeEdges(from: VertexId(RawVertexId(sourceId)), where: shouldBeRemoved)
		}
	}

    /// Remove all out edges of `vertex` that satisfy the given predicate.
    ///
    /// - Complexity: O(|E|)
	public mutating func removeEdges(
		from vertex: VertexId,
		where shouldBeRemoved: (EdgeId) throws -> Bool
	) rethrows {
		var shouldRemove = Set<RawVertexId>()
		let vertexEdges = edgesArray[vertex.index]
		for (i, dest) in vertexEdges.enumerated() {
			let edgeId = EdgeId(source: vertex, destination: VertexId(dest), offset: i)
			if try shouldBeRemoved(edgeId) {
				shouldRemove.insert(dest)
			}
		}
		edgesArray[vertex.index].removeAll { shouldRemove.contains($0) }
	}

    /// Adds a new vertex, returning its identifier.
    ///
    /// - Complexity: amortized O(1)
	public mutating func addVertex() -> VertexId {
		let c = edgesArray.count
		edgesArray.append([])
		return VertexId(RawVertexId(c))
	}

    /// Removes all edges from `vertex`.
    ///
    /// - Complexity: O(|E|)
	public mutating func clear(vertex: VertexId) {
		edgesArray[vertex.index].removeAll()
	}

    /// Removes `vertex` from the graph.
    ///
    /// - Precondition: `vertex` is a valid `VertexId` for `self`.
    /// - Complexity: O(|E| + |V|)
	public mutating func remove(vertex: VertexId) {
		fatalError("Unimplemented!")
	}
}

extension AdjacencyList: VertexListGraph {
    /// The number of vertices in the graph.
	public var vertexCount: Int { edgesArray.count }

	/// A collection of this graph's vertex identifiers.
	public struct VertexCollection: HierarchicalCollection {
		let vertexCount: Int

		@discardableResult
		public func forEachWhile(startingAt start: Int?, _ fn: (VertexId) throws -> Bool) rethrows -> Int? {
			let begin: Int
			if let start = start {
				begin = start
			} else {
				begin = 0
			}

			for i in begin..<vertexCount {
				if try !fn(VertexId(RawVertexId(i))) {
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

extension AdjacencyList: EdgeListGraph {
    /// The number of edges.
    ///
    /// - Complexity: O(|V|)
	public var edgeCount: Int { edgesArray.reduce(0) { $0 + $1.count } }

	/// A collection of all edge identifiers.
	public struct EdgeCollection: HierarchicalCollection {
		let edgesArray: [[RawVertexId]]

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
		public func forEachWhile(startingAt start: Cursor?, _ fn: (EdgeId) throws -> Bool) rethrows -> Cursor? {
			let begin: Cursor
			if let start = start {
				begin = start
			} else {
				begin = Cursor(sourceIndex: 0, destinationIndex: 0)
			}
			// First loop doesn't always start at 0.
			for inner in begin.destinationIndex..<edgesArray[begin.sourceIndex].count {
				let edgeId = EdgeId(
					source: VertexId(RawVertexId(begin.sourceIndex)),
					destination: VertexId(edgesArray[begin.sourceIndex][inner]),
					offset: inner)
				if try !fn(edgeId) {
					return Cursor(sourceIndex: begin.sourceIndex, destinationIndex: inner)
				}
			}
			for outer in (begin.sourceIndex+1)..<edgesArray.count {
				for inner in 0..<edgesArray[outer].count {
					let edgeId = EdgeId(
						source: VertexId(RawVertexId(outer)),
						destination: VertexId(edgesArray[outer][inner]),
						offset: inner)
					if try !fn(edgeId) {
						return Cursor(sourceIndex: outer, destinationIndex: inner)
					}
				}
			}
			return nil
		}

		public var count: Int { edgesArray.reduce(0) { $0 + $1.count } }
	}

	/// Returns a collection of all edges.
	public func edges() -> EdgeCollection { EdgeCollection(edgesArray: edgesArray) }

	/// Returns the source vertex identifier of `edge`.
	public func source(of edge: EdgeId) -> VertexId {
		edge.source
	}

    /// Returns the destination vertex identifier of `edge`.
	public func destination(of edge: EdgeId) -> VertexId {
		edge.destination
	}
}

extension AdjacencyList: IncidenceGraph {

	/// `VertexEdgeCollection` represents a collection of vertices from a single source vertex.
	public struct VertexEdgeCollection: Collection {
		let edges: [RawVertexId]
		let source: VertexId

		public var startIndex: Int { 0 }
		public var endIndex: Int { edges.count }
		public func index(after index: Int) -> Int { index + 1 }

		public subscript(index: Int) -> EdgeId {
			EdgeId(source: source, destination: VertexId(edges[index]), offset: index)
		}
	}

	/// Returns the collection of edges from `vertex`.
	public func edges(from vertex: VertexId) -> VertexEdgeCollection {
		VertexEdgeCollection(edges: edgesArray[vertex.index], source: vertex)
	}

	/// Returns the number of edges whose source is `vertex`.
	public func outDegree(of vertex: VertexId) -> Int {
		edgesArray[vertex.index].count
	}
}


extension AdjacencyList.EdgeId: CustomStringConvertible {
	/// Pretty representation of an edge identifier.
	public var description: String {
		"\(source.id) --(\(offset))--> \(destination.id)"
	}
}

extension AdjacencyList.VertexId: CustomStringConvertible {
	/// Pretty representation of a vertex identifier.
	public var description: String {
		"VertexId(\(index))"
	}
}
