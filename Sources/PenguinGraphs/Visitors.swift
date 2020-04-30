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

// MARK: - Visitor Protocols

/// `GraphVisitor`s compute additional information during graph traverals.
///
/// Examples of `GraphVisitor`s include:
///  - Computing the predecessors of all verticies (e.g. that can be used to reconstruct the
///    shortest paths).
///  - Implementing Dijkstra's algorithm (the logic of Dijkstra's algorithm is implemented as a
///    `BFSVisitor`).
///  - Computing distances to verticies (e.g. during Dijkstra's algorithm).
///
/// - SeeAlso: `BFSVisitor`
/// - SeeAlso: `DFSVisitor`
/// - SeeAlso: `DijkstraVisitor`
public protocol GraphVisitor {
  /// The type of Graph this `DFSVisitor` will be traversing.
  associatedtype Graph: GraphProtocol

  /// Called upon first discovering `vertex` in the graph.
  mutating func discover(vertex: Graph.VertexId, _ graph: inout Graph) throws

  /// Called when `vertex` is at the front of the queue and is examined.
  mutating func examine(vertex: Graph.VertexId, _ graph: inout Graph) throws

  /// Called for each edge associated with a freshly discovered vertex.
  mutating func examine(edge: Graph.EdgeId, _ graph: inout Graph) throws

  /// Called once for each vertex right after it is colored black.
  mutating func finish(vertex: Graph.VertexId, _ graph: inout Graph) throws
}

extension GraphVisitor {
  /// Called upon first discovering `vertex` in the graph.
  public mutating func discover(vertex: Graph.VertexId, _ graph: inout Graph) {}

  /// Called when `vertex` is at the front of the queue and is examined.
  public mutating func examine(vertex: Graph.VertexId, _ graph: inout Graph) {}

  /// Called for each edge associated with a freshly discovered vertex.
  public mutating func examine(edge: Graph.EdgeId, _ graph: inout Graph) {}

  /// Called once for each vertex right after it is colored black.
  public mutating func finish(vertex: Graph.VertexId, _ graph: inout Graph) {}
}

/// `TreeSearchVisitor`s are used for graph traversals that reconstruct a tree, such as DFS & BFS.
///
/// - SeeAlso: `BFSVisitor`
/// - SeeAlso: `DFSVisitor`
public protocol TreeSearchVisitor: GraphVisitor {
  /// `start(vertex:_:)` is called once for each start vertex.
  ///
  /// In the case for single-source search, `start(vertex:_:)` will be called exactly once. In
  /// cases where search may begin at multiple verticies (e.g. BreadthFirstSearch), `start` will
  /// be called once for each start vertex.
  mutating func start(vertex: Graph.VertexId, _ graph: inout Graph) throws

  /// Called for each edge that discovers a new vertex.
  ///
  /// These edges form the search tree.
  mutating func treeEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) throws
}

extension TreeSearchVisitor {
  public mutating func start(vertex: Graph.VertexId, _ graph: inout Graph) throws {}
  public mutating func treeEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) throws {}
}

/// DFSVisitor is used to extract information while executing depth first search.
///
/// Depth first search is a commonly-used subroutine to a variety of graph algorithms. In order to
/// reuse the same depth first search implementation across a variety of graph programs which each
/// need to keep track of different state, each caller supplies its own visitor which is specialized
/// to the information the caller needs.
public protocol DFSVisitor: TreeSearchVisitor {
  /// Called for each back edge in the search tree.
  mutating func backEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) throws

  /// Called for edges that are forward or cross edges in the search tree.
  mutating func forwardOrCrossEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) throws
}

/// Provide default implementations for every method that are "no-ops".
///
/// By adding these default no-op implementations, types that conform to the protocol only need to
/// override the methods they care about.
extension DFSVisitor {
  public mutating func backEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) {}
  public mutating func forwardOrCrossEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) {}
}

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
public protocol BFSVisitor: TreeSearchVisitor {
  /// Retrieves the next vertex to visit.
  mutating func popVertex() -> Graph.VertexId?

  /// Called for each non-tree edge encountered.
  mutating func nonTreeEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) throws

  /// Called for each edge with a gray destination.
  mutating func grayDestination(_ edge: Graph.EdgeId, _ graph: inout Graph) throws

  /// Called for each edge with a black destination.
  mutating func blackDestination(_ edge: Graph.EdgeId, _ graph: inout Graph) throws
}

extension BFSVisitor {

  /// Retrieves the next vertex to visit.
  public mutating func popVertex() -> Graph.VertexId? { nil }

  /// Called for each non-tree edge encountered.
  public mutating func nonTreeEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) {}

  /// Called for each edge with a gray destination
  public mutating func grayDestination(_ edge: Graph.EdgeId, _ graph: inout Graph) {}

  /// Called for each edge with a black destination.
  public mutating func blackDestination(_ edge: Graph.EdgeId, _ graph: inout Graph) {}
}

/// A visitor ot capture state during a Dijkstra search of a graph.
public protocol DijkstraVisitor: GraphVisitor {
  /// Called for each edge that results in a shorter path to its destination vertex.
  mutating func edgeRelaxed(_ edge: Graph.EdgeId, _ graph: inout Graph) throws

  /// Called for each edge that does not result in a shorter path to its destination vertex.
  mutating func edgeNotRelaxed(_ edge: Graph.EdgeId, _ graph: inout Graph) throws
}

extension DijkstraVisitor {
  /// Called for each edge that results in a shorter path to its destination vertex.
  public mutating func edgeRelaxed(_ edge: Graph.EdgeId, _ graph: inout Graph) {}

  /// Called for each edge that does not result in a shorter path to its destination vertex.
  public mutating func edgeNotRelaxed(_ edge: Graph.EdgeId, _ graph: inout Graph) {}
}

// MARK: - Chains

/// A chain of two graph visitors of different types.
public struct VisitorChain<Graph, Head: GraphVisitor, Tail: GraphVisitor>: GraphVisitor
where Head.Graph == Graph, Tail.Graph == Graph {
  /// The first visitor in the chain.
  public private(set) var head: Head
  /// The rest of the chain.
  public private(set) var tail: Tail

  /// Builds a chain of `DFSVisitor`s, composed of `Head`, and `Tail`.
  public init(_ head: Head, _ tail: Tail) {
    self.head = head
    self.tail = tail
  }

  /// `discover(vertex:_:)` is called upon first discovering `vertex` in the graph.
  public mutating func discover(vertex: Graph.VertexId, _ graph: inout Graph) throws {
    try head.discover(vertex: vertex, &graph)
    try tail.discover(vertex: vertex, &graph)
  }

  /// Called when `vertex` is at the front of the queue and is examined.
  public mutating func examine(vertex: Graph.VertexId, _ graph: inout Graph) throws {
    try head.examine(vertex: vertex, &graph)
    try tail.examine(vertex: vertex, &graph)
  }

  /// Called for each edge associated with a freshly discovered vertex.
  public mutating func examine(edge: Graph.EdgeId, _ graph: inout Graph) throws {
    try head.examine(edge: edge, &graph)
    try tail.examine(edge: edge, &graph)
  }

  /// Called once for each vertex right after it is colored black.
  public mutating func finish(vertex: Graph.VertexId, _ graph: inout Graph) throws {
    try head.finish(vertex: vertex, &graph)
    try tail.finish(vertex: vertex, &graph)
  }
}

extension VisitorChain: TreeSearchVisitor where Head: TreeSearchVisitor, Tail: TreeSearchVisitor {
  /// `start(vertex:_:)` is called once for each start vertex.
  ///
  /// In the case for single-source search, `start(vertex:_:)` will be called exactly once. In
  /// cases where search may begin at multiple verticies (e.g. BreadthFirstSearch), `start` will
  /// be called once for each start vertex.
  public mutating func start(vertex: Graph.VertexId, _ graph: inout Graph) throws {
    try head.start(vertex: vertex, &graph)
    try tail.start(vertex: vertex, &graph)
  }

  /// Called for each edge that discovers a new vertex.
  ///
  /// These edges form the search tree.
  public mutating func treeEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) throws {
    try head.treeEdge(edge, &graph)
    try tail.treeEdge(edge, &graph)
  }
}

extension VisitorChain: DFSVisitor where Head: DFSVisitor, Tail: DFSVisitor {

  /// Called for each back edge in the search tree.
  public mutating func backEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) throws {
    try head.backEdge(edge, &graph)
    try tail.backEdge(edge, &graph)
  }

  /// Called for edges that are forward or cross edges in the search tree.
  public mutating func forwardOrCrossEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) throws {
    try head.forwardOrCrossEdge(edge, &graph)
    try tail.forwardOrCrossEdge(edge, &graph)
  }
}

/// A chain of DFS visitors.
public typealias DFSVisitorChain<Graph, Head: DFSVisitor, Tail: DFSVisitor> =
  VisitorChain<Graph, Head, Tail>
where Head.Graph == Graph, Tail.Graph == Graph

extension VisitorChain: BFSVisitor where Head: BFSVisitor, Tail: BFSVisitor {
  /// Retrieves the next vertex to visit.
  public mutating func popVertex() -> Graph.VertexId? {
    if let vertex = head.popVertex() { return vertex } else { return tail.popVertex() }
  }

  /// Called for each non-tree edge encountered.
  public mutating func nonTreeEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) throws {
    try head.nonTreeEdge(edge, &graph)
    try tail.nonTreeEdge(edge, &graph)
  }

  /// Called for each edge with a gray destination
  public mutating func grayDestination(_ edge: Graph.EdgeId, _ graph: inout Graph) throws {
    try head.grayDestination(edge, &graph)
    try tail.grayDestination(edge, &graph)
  }

  /// Called for each edge with a black destination.
  public mutating func blackDestination(_ edge: Graph.EdgeId, _ graph: inout Graph) throws {
    try head.blackDestination(edge, &graph)
    try tail.blackDestination(edge, &graph)
  }
}

/// A chain of BFSVisitors.
public typealias BFSVisitorChain<Graph, Head: BFSVisitor, Tail: BFSVisitor> =
  VisitorChain<Graph, Head, Tail>
where Head.Graph == Graph, Tail.Graph == Graph

extension VisitorChain: DijkstraVisitor where Head: DijkstraVisitor, Tail: DijkstraVisitor {
  /// Called for each edge that results in a shorter path to its destination vertex.
  public mutating func edgeRelaxed(_ edge: Graph.EdgeId, _ graph: inout Graph) throws {
    try head.edgeRelaxed(edge, &graph)
    try tail.edgeRelaxed(edge, &graph)
  }

  /// Called for each edge that does not result in a shorter path to its destination vertex.
  public mutating func edgeNotRelaxed(_ edge: Graph.EdgeId, _ graph: inout Graph) throws {
    try head.edgeNotRelaxed(edge, &graph)
    try tail.edgeNotRelaxed(edge, &graph)
  }
}

/// A chain of DijkstraVisitors.
public typealias DijkstraVisitorChain<Graph, Head: DijkstraVisitor, Tail: DijkstraVisitor> =
  VisitorChain<Graph, Head, Tail>
where Head.Graph == Graph, Tail.Graph == Graph

// MARK: - Visitors

/// A graph algorithm visitor that records the parents of every discovered vertex.
///
/// `PredecessorVisitor` allows capturing a representation of the DFS tree, as this is often a
/// useful output of a DFS traversal within other graph algorithms.
public struct TablePredecessorVisitor<Graph: IncidenceGraph> where Graph.VertexId: IdIndexable {
  /// A table of the predecessor for a vertex, organized by `Graph.VertexId.index`.
  public private(set) var predecessors: [Graph.VertexId?]

  /// Creates a PredecessorVisitor for use on graph `Graph` with `vertexCount` verticies.
  public init(vertexCount: Int) {
    predecessors = Array(repeating: nil, count: vertexCount)
  }
}

extension TablePredecessorVisitor where Graph: VertexListGraph {
  /// Creates a `PredecessorVisitor` for use on `graph`.
  ///
  /// Note: use this initializer to avoid spelling out the types, as this initializer helps along
  /// type inference nicely.
  public init(for graph: Graph) {
    self.init(vertexCount: graph.vertexCount)
  }
}

extension TablePredecessorVisitor: TreeSearchVisitor, DFSVisitor, BFSVisitor {
  /// Records the source of `edge` as being the predecessor of the destination of `edge`.
  public mutating func treeEdge(_ edge: Graph.EdgeId, _ graph: inout Graph) {
    predecessors[graph.destination(of: edge).index] = graph.source(of: edge)
  }
}

extension TablePredecessorVisitor: DijkstraVisitor {
  /// Records the source of `edge` as being the predecessor of the destination of `edge`.
  public mutating func edgeRelaxed(_ edge: Graph.EdgeId, _ graph: inout Graph) {
    predecessors[graph.destination(of: edge).index] = graph.source(of: edge)
  }
}
