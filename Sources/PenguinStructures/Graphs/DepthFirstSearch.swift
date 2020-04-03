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

/// `VertexColor` is used to represent which verticies have been seen during graph searches.
///
/// Note: although there are vague interpretations for what each color means, their exact properties
/// are dependent upon the kind of graph search algorithm being executed.
public enum VertexColor {
	/// white is used for unseen verticies in the graph.
	case white
	/// gray is used for verticies that are being processed.
	case gray
	/// black is used for verticies that have finished processing.
	case black
}

/// DFSVisitor is used to extract information while executing depth first search.
///
/// Depth first search is a commonly-used subroutine to a variety of graph algorithms. In order to
/// reuse the same depth first search implementation across a variety of graph programs which each
/// need to keep track of different state, each caller supplies its own visitor which is specialized
/// to the information the caller needs.
public protocol DFSVisitor {
	/// The type of Graph this `DFSVisitor` will be traversing.
	associatedtype Graph: GraphProtocol

	/// `start(vertex:_:)` is called once, passing in the vertex where search will begin.
	mutating func start(vertex: Graph.VertexId, _ graph: inout Graph)

	/// `discover(vertex:_:)` is called upon first discovering `vertex` in the graph.
	///
	/// Return `true` if search should immediately terminate.
	mutating func discover(vertex: Graph.VertexId, _ graph: inout Graph) -> Bool

	/// Called for each edge associated with a freshly discovered vertex.
	mutating func examine(edge: Graph.EdgeId, _ graph: inout Graph)

	/// Called for each edge that discovers a new vertex.
	///
	/// These edges form the search tree.
	mutating func treeEdge(_ edge: Graph.EdgeId, _ graph: inout Graph)

	/// Called for each back edge in the search tree.
	mutating func backEdge(_ edge: Graph.EdgeId, _ graph: inout Graph)

	/// Called for edges that are forward or cross edges in the search tree.
	mutating func forwardOrCrossEdge(_ edge: Graph.EdgeId, _ graph: inout Graph)

	/// Called once for each vertex right after it is colored black.
	mutating func finish(vertex: Graph.VertexId, _ graph: inout Graph)
}

/// Provide default implementations for every method that are "no-ops".
///
/// By adding these default no-op implementations, types that conform to the protocol only need to
/// override the methods they care about.
public extension DFSVisitor {
	mutating func start(vertex: Graph.VertexId, _ graph: inout Graph) {}
	mutating func discover(vertex: Graph.VertexId, _ graph: inout Graph) -> Bool { false }
	mutating func examine(edge: Graph.EdgeId, _ graph: inout Graph) {}
	mutating func treeEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) {}
	mutating func backEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) {}
	mutating func forwardOrCrossEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) {}
	mutating func finish(vertex: Graph.VertexId, _ graph: inout Graph) {}
}

/// Runs depth first search on `graph` starting at `startVertex` using `colorMap` to keep track of
/// visited verticies; `visitor` is called regularly to allow arbitrary state to be computed during
/// search.
///
/// - Note: `graph` is taken `inout` because the `colorMap` or `visitor` may store data within the
///   graph itself.
/// - Precondition: `ColorMap` has been initialized for every vertex to `.white`.
public func depthFirstSearchNoInit<
	Graph: IncidenceGraph & VertexListGraph,
	ColorMap: MutableGraphVertexPropertyMap,
	Visitor: DFSVisitor
>(
	_ graph: inout Graph,
	colorMap: inout ColorMap,
	visitor: inout Visitor,
	start startVertex: Graph.VertexId
)
where
	ColorMap.Graph == Graph,
	ColorMap.Value == VertexColor,
	Visitor.Graph == Graph
{
	visitor.start(vertex: startVertex, &graph)

	// We use an explicit stack to avoid a recursive implementation for performance.
	//
	// The stack contains the vertex we're traversing, as well as the (partially consumed) iterator
	// for the edges.
	//
	// Invariant: colorMap.get(vertex: v, in: graph) should be .gray for all `v` in `stack`.
	var stack = Array<(Graph.VertexId, Graph.VertexEdgeCollection.Iterator)>()
	colorMap.set(vertex: startVertex, in: &graph, to: .gray)
	stack.append((startVertex, graph.edges(from: startVertex).makeIterator()))

	guard !visitor.discover(vertex: startVertex, &graph) else { return }

	while var (v, itr) = stack.popLast() {
		while let edge = itr.next() {
			let destination = graph.destination(of: edge)
			visitor.examine(edge: edge, &graph)
			let destinationColor = colorMap.get(graph, destination)
			if destinationColor == .white {
				// We have a tree edge; push the current iteration state onto the stack and
				// "recurse" into destination.
				visitor.treeEdge(edge, &graph)
				colorMap.set(vertex: destination, in: &graph, to: .gray)
				if visitor.discover(vertex: destination, &graph) { return }
				stack.append((v, itr))
				v = destination
				itr = graph.edges(from: v).makeIterator()
			} else {
				if destinationColor == .gray {
					visitor.backEdge(edge, &graph)
				} else {
					visitor.forwardOrCrossEdge(edge, &graph)
				}
			}
		}
		// Finished iterating over all edges from our vertex.
		colorMap.set(vertex: v, in: &graph, to: .black)
		visitor.finish(vertex: v, &graph)
	}
}

/// Chains two DFSVisitors together in HList-style.
public struct DFSVisitorChain<Graph, Head: DFSVisitor, Tail: DFSVisitor>: DFSVisitor
where
	Head.Graph == Graph,
	Tail.Graph == Graph
{
	/// The first visitor in the chain.
	public private(set) var head: Head
	/// The rest of the chain.
	public private(set) var tail: Tail

	public init(_ head: Head, _ tail: Tail) {
		self.head = head
		self.tail = tail
	}

	/// `start(vertex:_:)` is called once, passing in the vertex where search will begin.
	public mutating func start(vertex: Graph.VertexId, _ graph: inout Graph) {
		head.start(vertex: vertex, &graph)
		tail.start(vertex: vertex, &graph)
	}

	/// `discover(vertex:_:)` is called upon first discovering `vertex` in the graph.
	///
	/// Return `true` if search should immediately terminate.
	public mutating func discover(vertex: Graph.VertexId, _ graph: inout Graph) -> Bool {
		if head.discover(vertex: vertex, &graph) { return true }
		return tail.discover(vertex: vertex, &graph)
	}

	/// Called for each edge associated with a freshly discovered vertex.
	public mutating func examine(edge: Graph.EdgeId, _ graph: inout Graph) {
		head.examine(edge: edge, &graph)
		tail.examine(edge: edge, &graph)
	}

	/// Called for each edge that discovers a new vertex.
	///
	/// These edges form the search tree.
	public mutating func treeEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) {
		head.treeEdge(edge, &graph)
		tail.treeEdge(edge, &graph)
	}

	/// Called for each back edge in the search tree.
	public mutating func backEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) {
		head.backEdge(edge, &graph)
		tail.backEdge(edge, &graph)
	}

	/// Called for edges that are forward or cross edges in the search tree.
	public mutating func forwardOrCrossEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) {
		head.forwardOrCrossEdge(edge, &graph)
		tail.forwardOrCrossEdge(edge, &graph)
	}

	/// Called once for each vertex right after it is colored black.
	public mutating func finish(vertex: Graph.VertexId, _ graph: inout Graph) {
		head.finish(vertex: vertex, &graph)
		tail.finish(vertex: vertex, &graph)
	}
}


/// A DFSVisitor that records the parents of every discovered vertex.
///
/// `PredecessorVisitor` allows capturing a representation of the DFS tree, as this is often a
/// useful output of a DFS traversal within other graph algorithms.
public struct PredecessorVisitor<Graph: IncidenceGraph>: DFSVisitor
where Graph.VertexId: IdIndexable {
	/// A table of the predecessor for a vertex, organized by `Graph.VertexId.index`.
	public private(set) var predecessors: [Graph.VertexId?]

	/// Creates a PredecessorVisitor for use on graph `Graph` with `vertexCount` verticies.
	public init(vertexCount: Int) {
		predecessors = Array(repeating: nil, count: vertexCount)
	}

	/// Records the source of `edge` as being the predecessor of the destination of `edge`.
	public mutating func treeEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) {
		predecessors[graph.destination(of: edge).index] = graph.source(of: edge)
	}
}

public extension PredecessorVisitor where Graph: VertexListGraph {
	/// Creates a `PredecessorVisitor` for use on `graph`.
	///
	/// Note: use this initializer to avoid spelling out the types, as this initializer helps along
	/// type inference nicely.
	init(for graph: Graph) {
		self.init(vertexCount: graph.vertexCount)
	}
}
