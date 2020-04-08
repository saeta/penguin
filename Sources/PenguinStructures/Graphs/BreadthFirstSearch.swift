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


/// A visitor to capture state during a breadth first search of a graph.
///
/// In order to abstract over different search policies (e.g. naive BFS, Dijkstra's, etc.), the
/// visitor is responsible for keeping track of discovered verticies and ensuring they are examined
/// by the algorithm by returning them in subsequent `popVertex` calls. Most commonly, simply:
///   1. return `nil` from `popVertex()`
///   2. Chain (using `BFSVisitorChain`) a search policy onto your custom `BFSVisitor`, such as
///      `BFSQueueVisitor`.
///
/// - SeeAlso: `BFSQueueVisitor`
/// - SeeAlso: `BFSVisitorChain`
public protocol BFSVisitor {
	/// The graph datastructure this `BFSVisitor` will traverse.
	associatedtype Graph: GraphProtocol

	/// Called upon first discovering `vertex` in the graph.
	///
	/// The visitor should keep track of the vertex (and put it in a backlog) so that it can be
	/// returned in the future when `popVertex()` is called.
	mutating func discover(vertex: Graph.VertexId, _ graph: inout Graph)

	/// Retrieves the next vertex to visit.
	mutating func popVertex() -> Graph.VertexId?

	/// Called when `vertex` is at the front of the queue and is examined.
	mutating func examine(vertex: Graph.VertexId, _ graph: inout Graph)

	/// Called for each edge associated with a freshly discovered vertex.
	mutating func examine(edge: Graph.EdgeId, _ graph: inout Graph)

	/// Called for each edge that forms the search tree.
	mutating func treeEdge(_ edge: Graph.EdgeId, _ graph: inout Graph)

	/// Called for each non-tree edge encountered.
	mutating func nonTreeEdge(_ edge: Graph.EdgeId, _ graph: inout Graph)

	/// Called for each edge with a gray destination.
	mutating func grayDestination(_ edge: Graph.EdgeId, _ graph: inout Graph)

	/// Called for each edge with a black destination.
	mutating func blackDestination(_ edge: Graph.EdgeId, _ graph: inout Graph)

	/// Called once for each vertex right after it is colored black.
	mutating func finish(vertex: Graph.VertexId, _ graph: inout Graph)
}

public extension BFSVisitor {
	/// Called upon first discovering `vertex` in the graph.
	///
	/// The visitor should keep track of the vertex (and put it in a backlog) so that it can be
	/// returned in the future when `popVertex()` is called.
	///
	/// Return `true` if search should immediately terminate.
	mutating func discover(vertex: Graph.VertexId, _ graph: inout Graph) {}

	/// Retrieves the next vertex to visit.
	mutating func popVertex() -> Graph.VertexId? { nil }

	/// Called when `vertex` is at the front of the queue and is examined.
	///
	/// Return `true` if search should immediately terminate.
	mutating func examine(vertex: Graph.VertexId, _ graph: inout Graph) {}

	/// Called for each edge associated with a freshly discovered vertex.
	mutating func examine(edge: Graph.EdgeId, _ graph: inout Graph) {}

	/// Called for each edge that forms the search tree.
	mutating func treeEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) {}

	/// Called for each non-tree edge encountered.
	mutating func nonTreeEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) {}

	/// Called for each edge with a gray destination
	mutating func grayDestination(_ edge: Graph.EdgeId, _ graph: inout Graph) {}

	/// Called for each edge with a black destination.
	mutating func blackDestination(_ edge: Graph.EdgeId, _ graph: inout Graph) {}

	/// Called once for each vertex right after it is colored black.
	mutating func finish(vertex: Graph.VertexId, _ graph: inout Graph) {}
}

extension Graphs {

	/// Runs breadth first search on `graph` using `colorMap` to keep track of search progress, and
	/// using `backlog` to keep track of verticies to explore; `visitor` is called at regular
	/// intervals.
	///
	/// - Precondition: `colorMap` must be initialized for every `VertexId` in `Graph` to be
	///   `.white`. (Note: this precondition is not checked.)
	/// - Precondition: `startVerticies` is non-empty.
	public static func breadthFirstSearchNoInit<
		Graph: IncidenceGraph & VertexListGraph,
		Visitor: BFSVisitor,
		ColorMap: MutableGraphVertexPropertyMap,
		StartCollection: Collection
	>(
		_ graph: inout Graph,
		visitor: inout Visitor,
		colorMap: inout ColorMap,
		startAt startVerticies: StartCollection
	)
	where
		Visitor.Graph == Graph,
		ColorMap.Graph == Graph,
		ColorMap.Value == VertexColor,
		StartCollection.Element == Graph.VertexId
	{
		precondition(!startVerticies.isEmpty, "startVerticies was empty.")
		for startVertex in startVerticies {
			colorMap.set(vertex: startVertex, in: &graph, to: .gray)
			visitor.discover(vertex: startVertex, &graph)
		}

		while let vertex = visitor.popVertex() {
			visitor.examine(vertex: vertex, &graph)
			for edge in graph.edges(from: vertex) {
				let v = graph.destination(of: edge)
				visitor.examine(edge: edge, &graph)
				let vColor = colorMap.get(graph, v)
				if vColor == .white {
					visitor.discover(vertex: v, &graph)
					visitor.treeEdge(edge, &graph)
					colorMap.set(vertex: v, in: &graph, to: .gray)
				} else {
					visitor.nonTreeEdge(edge, &graph)
					if vColor == .gray {
						visitor.grayDestination(edge, &graph)
					} else {
						visitor.blackDestination(edge, &graph)
					}
				}
			}  // end edge for-loop.
			colorMap.set(vertex: vertex, in: &graph, to: .black)
			visitor.finish(vertex: vertex, &graph)
		}  // end while loop
	}
}

/// The BFSVisitor that implements breadth first search.
public struct BFSQueueVisitor<Graph: GraphProtocol>: BFSVisitor {
	var queue = Deque<Graph.VertexId>()

	/// Initialize an empty `BFSQueueVisitor`.
	public init() {}

	/// Called upon first discovering `vertex` in the graph.
	///
	/// This visitor keeps track of the vertex (and put it in a backlog) so that it can be
	/// returned in the future when `popVertex()` is called.
	public mutating func discover(vertex: Graph.VertexId, _ graph: inout Graph) {
		queue.pushBack(vertex)
	}

	/// Retrieves the next vertex to visit.
	public mutating func popVertex() -> Graph.VertexId? {
		guard !queue.isEmpty else { return nil }
		return queue.popFront()
	}

}

/// Chains two `BFSVisitor`s together in HList-style.
public struct BFSVisitorChain<Graph, Head: BFSVisitor, Tail: BFSVisitor>: BFSVisitor
where Head.Graph == Graph, Tail.Graph == Graph {
	/// The first visitor in the chain.
	public private(set) var head: Head
	/// The rest of the chain.
	public private(set) var tail: Tail

	/// Initialize a chain.
	public init(_ head: Head, _ tail: Tail) {
		self.head = head
		self.tail = tail
	}

	/// Called upon first discovering `vertex` in the graph.
	///
	/// The visitor should keep track of the vertex (and put it in a backlog) so that it can be
	/// returned in the future when `popVertex()` is called.
	public mutating func discover(vertex: Graph.VertexId, _ graph: inout Graph) {
		head.discover(vertex: vertex, &graph)
		tail.discover(vertex: vertex, &graph)
	}

	/// Retrieves the next vertex to visit.
	public mutating func popVertex() -> Graph.VertexId? {
		if let vertex = head.popVertex() { return vertex }
		else { return tail.popVertex() }
	}

	/// Called when `vertex` is at the front of the queue and is examined.
	public mutating func examine(vertex: Graph.VertexId, _ graph: inout Graph) {
		head.examine(vertex: vertex, &graph)
		tail.examine(vertex: vertex, &graph)
	}

	/// Called for each edge associated with a freshly discovered vertex.
	public mutating func examine(edge: Graph.EdgeId, _ graph: inout Graph) {
		head.examine(edge: edge, &graph)
		tail.examine(edge: edge, &graph)
	}

	/// Called for each edge that forms the search tree.
	public mutating func treeEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) {
		head.treeEdge(edge, &graph)
		tail.treeEdge(edge, &graph)
	}

	/// Called for each non-tree edge encountered.
	public mutating func nonTreeEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) {
		head.nonTreeEdge(edge, &graph)
		tail.nonTreeEdge(edge, &graph)
	}

	/// Called for each edge with a gray destination
	public mutating func grayDestination(_ edge: Graph.EdgeId, _ graph: inout Graph) {
		head.grayDestination(edge, &graph)
		tail.grayDestination(edge, &graph)
	}

	/// Called for each edge with a black destination.
	public mutating func blackDestination(_ edge: Graph.EdgeId, _ graph: inout Graph) {
		head.blackDestination(edge, &graph)
		tail.blackDestination(edge, &graph)
	}

	/// Called once for each vertex right after it is colored black.
	public mutating func finish(vertex: Graph.VertexId, _ graph: inout Graph) {
		head.finish(vertex: vertex, &graph)
		tail.finish(vertex: vertex, &graph)
	}
}
