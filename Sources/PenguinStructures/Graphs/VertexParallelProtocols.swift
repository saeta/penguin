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

// MARK: - Mailboxes

/// Represents the per-vertex communication abstraction for vertex-parallel algorithms.
///
/// Vertex-parallel algorithms execute as a series of super-steps, where in each step, a vertex can
/// (1) perform vertex-local computation, (2) receive messages from the previous step, and (3) send
/// messages to any other vertex (that will be received in the next step).
///
/// This abstraction is inspired by:
///
/// Pregel: A System for Large-Scale Graph Processing (2010)
/// Grzegorz Malewicz, Matthew H. Austern, Aart J. C. Bik, James C. Dehnert, Ilan Horn, Naty Leiser,
/// and Grzegorz Czajkowski
///
public protocol MailboxProtocol {
	/// The type of messages being exchanged.
	associatedtype Message
	/// The graph data structure being operated upon.
	associatedtype Graph: GraphProtocol
	/// A representation of the incoming messages.
	associatedtype Inbox: Collection where Inbox.Element == Message

	/// The collection of messages received by this vertex from the previous super-step.
	var messages: Inbox { get }

	/// Sends `message` to `vertex` (that will be received in the next super-step).
	mutating func send(_ message: Message, to vertex: Graph.VertexId)
}

/// Represents the computation-wide communication abstraction for vertex-parallel algorithms.
public protocol MailboxesProtocol {
	/// The per-vertex representation of this communication abstraction.
	associatedtype Mailbox: MailboxProtocol

	/// Transfers messages that were previously sent into the inboxes of the verticies; returns true
	/// iff there are messages to be delivered.
	///
	/// This function is called between every super-step of the vertex-parallel algorithms.
	///
	/// - Returns: true if there are messages waiting in inboxes; false otherwise.
	mutating func deliver() -> Bool

	/// Executes `fn` passing in the `Mailbox` for `vertex`.
	mutating func withMailbox(for vertex: Mailbox.Graph.VertexId, _ fn: (inout Mailbox) throws -> Void) rethrows
}

/// A naive, sequential mailbox implementation that collects messages into buffers.
public struct SequentialAppendingMailboxes<Message, Graph: GraphProtocol>: MailboxesProtocol where Graph.VertexId: IdIndexable {
	private let vertexCount: Int
	private var hasOutgoingMessages: Bool = false
	private var outbox: [[Message]]
	private var inbox: [[Message]]

	public init(vertexCount: Int) {
		self.vertexCount = vertexCount
		self.outbox = Self.makeBoxes(vertexCount: vertexCount)
		self.inbox = Self.makeBoxes(vertexCount: vertexCount)
	}

	public struct Mailbox: MailboxProtocol {
		var outboxes: [[Message]]
		var sentMessage: Bool = false
		public let messages: [Message]
		public mutating func send(_ message: Message, to vertex: Graph.VertexId) {
			outboxes[vertex.index].append(message)
			sentMessage = true
		}
	}

	/// Transfers messages that were previously sent into the inboxes of the verticies.
	public mutating func deliver() -> Bool {
		inbox = outbox
		outbox = makeBoxes()
		let tmp = hasOutgoingMessages
		hasOutgoingMessages = false
		return tmp
	}

	/// Executes `fn` passing in the `Mailbox` for `vertex`.
	public mutating func withMailbox(for vertex: Graph.VertexId, _ fn: (inout Mailbox) throws -> Void) rethrows {
		// TODO: Ensure we avoid copying outbox or else we're accidentally quadratic!
		var box = Mailbox(outboxes: self.outbox, messages: self.inbox[vertex.index])
		defer {
			self.outbox = box.outboxes
			self.hasOutgoingMessages = self.hasOutgoingMessages || box.sentMessage
		}
		try fn(&box)
	}

	/// Create a new set of in/out boxes.
	private func makeBoxes() -> [[Message]] {
		Self.makeBoxes(vertexCount: vertexCount)
	}

	/// Create a new set of in/out boxes.
	private static func makeBoxes(vertexCount: Int) -> [[Message]] {
		Array(repeating: [], count: vertexCount)
	}
}

extension SequentialAppendingMailboxes where Graph: VertexListGraph {
	/// Initialize mailboxes for `graph` for `messageType` messages.
	///
	/// This initializer helps the type inference algorithm along.
	public init(for graph: __shared Graph, sending messageType: Message.Type) {
		self.init(vertexCount: graph.vertexCount)
	}
}

/// Mailbox message types that support merging two messages into one.
public protocol MergeableMessage {
	/// Merges `other` into `self`.
	mutating func merge(with other: Self)
}

public struct SequentialMergingMailboxes<Message: MergeableMessage, Graph: GraphProtocol>: MailboxesProtocol where Graph.VertexId: IdIndexable {
	/// Messages being sent this super-step.
	private var outbox: [Message?]
	/// Messages being received this super-step.
	private var inbox: [Message?]
	/// A flag to determine if there are pending messages in the outbox.
	private var hasOutgoingMessages: Bool = false

	/// Initializes `self` for a given graph size.
	public init(vertexCount: Int) {
		outbox = Array(repeating: nil, count: vertexCount)
		inbox = Array(repeating: nil, count: vertexCount)
	}

	/// A mailbox that merges messages together.
	public struct Mailbox: MailboxProtocol {
		/// A zero-or-one collection that avoids heap allocations.
		public struct Inbox: Collection {
			/// The message type.
			public let message: Message?
			// Collection conformances below.
			public var startIndex: Int { 0 }
			public var endIndex: Int { message == nil ? 0 : 1 }
			public subscript(index: Int) -> Message {
				assert(index == 0)
				return message!
			}
			public func index(after: Int) -> Int { after + 1 }
		}
		/// The incoming message.
		public let messages: Inbox
		/// The outgoing messages.
		var outboxes: [Message?]
		/// Boolean flag to determine if a message was sent.
		var didSendMessage: Bool = false
		/// Sends `message` to `vertex` next step.
		public mutating func send(_ message: Message, to vertex: Graph.VertexId) {
			didSendMessage = true
			if outboxes[vertex.index] == nil {
				outboxes[vertex.index] = message
			} else {
				outboxes[vertex.index]!.merge(with: message)
			}
		}
	}

	/// Transfers messages that were previously sent into the inboxes of the verticies.
	public mutating func deliver() -> Bool {
		if hasOutgoingMessages {
			inbox = outbox
			outbox = Array(repeating: nil, count: inbox.count)  // TODO: Avoid reallocating!
			hasOutgoingMessages = false
			return true
		}
		return false
	}

	/// Executes `fn` passing in the `Mailbox` for `vertex`.
	public mutating func withMailbox(for vertex: Graph.VertexId, _ fn: (inout Mailbox) throws -> Void) rethrows {
		// TODO: Ensure we avoid copying outbox or else we're accidentally quadratic!
		var box = Mailbox(messages: Mailbox.Inbox(message: self.inbox[vertex.index]), outboxes: self.outbox)
		defer {
			self.outbox = box.outboxes
			self.hasOutgoingMessages = self.hasOutgoingMessages || box.didSendMessage
		}
		try fn(&box)
	}
}

extension SequentialMergingMailboxes where Graph: VertexListGraph {
	/// Initialize mailboxes for `graph` for `messageType` messages.
	///
	/// This initializer helps the type inference algorithm along.
	public init(for graph: __shared Graph, sending messageType: Message.Type) {
		self.init(vertexCount: graph.vertexCount)
	}
}


// MARK: - Parallel Graph Algorithms

// TODO: Don't make this inherit from PropertyGraph, but instead have it just be graph,
// and figure out how to support external property maps in a parallelizable fashion.

/// A graph that supports vertex-parallel graph algorithms.
///
/// Graph structures are often parallelizable. One common way to parallelize is to parallelize by
/// vertex. In this "think-like-a-vertex", computation is organized into a series of steps, where
/// each vertex executes executes on "local" information, such as vertex-specific properties, as
/// well as the set of edges leaving the vertex. In order to compute useful properties of the graph,
/// a mailbox abstraction is provided that allows a vertex to receive messages from a previous
/// algorithm step, and to send messages to arbitrary other verticies that will be received in the
/// subsequent step.
///
/// This abstraction is inspired by:
///
/// Pregel: A System for Large-Scale Graph Processing (2010)
/// Grzegorz Malewicz, Matthew H. Austern, Aart J. C. Bik, James C. Dehnert, Ilan Horn, Naty Leiser,
/// and Grzegorz Czajkowski
///
/// - SeeAlso: MailboxesProtocol
/// - SeeAlso: MailboxProtocol
public protocol ParallelGraph: PropertyGraph {
	/// A per-vertex function that does not include any globally-aggregated state.
	typealias NonGlobalPerVertexFunction<Mailbox: MailboxProtocol> =
		(VertexId, inout Vertex, inout Mailbox, Self) throws -> Void

	/// A per-vertex function that updates global state in-place.
	///
	/// The non-modifying `GlobalState` parameter is the global state from last step. The inout
	/// global state is the state that will be used for the next step.
	typealias PerVertexFunction<
		Mailbox: MailboxProtocol,
		GlobalState: MergeableMessage & DefaultInitializable
	> = (VertexId, inout Vertex, inout Mailbox, Self, GlobalState, inout GlobalState) throws -> Void

	// /// A per-vertex function that updates global state functionally.
	// typealias PerVertexFunction<
	// 	Mailbox: MailboxProtocol,
	// 	GlobalState: MergeableMessage
	// > = (VertexId, inout Vertex, inout Mailbox, Self, GlobalState) throws -> GlobalState?

	/// Runs `fn` across each vertex delivering messages in `mailboxes`.
	mutating func step<Mailboxes: MailboxesProtocol>(
		mailboxes: inout Mailboxes,
		_ fn: NonGlobalPerVertexFunction<Mailboxes.Mailbox>
	) rethrows where Mailboxes.Mailbox.Graph == Self

	/// Runs `fn` across each vertex delivering messages in `mailboxes` and making `globalState`
	/// available to each vertex; outputs from each vertex are aggregated into `nextGlobalState`.
	mutating func step<
		Mailboxes: MailboxesProtocol,
		GlobalState: MergeableMessage & DefaultInitializable
	>(
		mailboxes: inout Mailboxes,
		globalState: GlobalState,
		_ fn: PerVertexFunction<Mailboxes.Mailbox, GlobalState>
	) rethrows -> GlobalState where Mailboxes.Mailbox.Graph == Self
}

public extension ParallelGraph {
	/// Runs `fn` across each vertex delivering messages in `mailboxes`.
	mutating func step<Mailboxes: MailboxesProtocol>(
		mailboxes: inout Mailboxes,
		_ fn: NonGlobalPerVertexFunction<Mailboxes.Mailbox>
	) rethrows where Mailboxes.Mailbox.Graph == Self {
		_ = try step(mailboxes: &mailboxes, globalState: EmptyMergeableMessage()) {
			(vertexId, vertex, mailbox, graph, emptyGlobalState, nextGlobalState) in
				try fn(vertexId, &vertex, &mailbox, graph)
		}
	}
}

/// A protocol for whether a vertex is reachable.
public protocol ReachableVertex {
	var isReachable: Bool { get set }
}

/// An empty, mergeable message that can be useful for signaling.
public struct EmptyMergeableMessage: MergeableMessage, DefaultInitializable {
	public init() {}
	public mutating func merge(with other: Self) {
		// Do nothing; message presence indicates it's reachable!
	}
}

public extension ParallelGraph where Vertex: ReachableVertex, Self: IncidenceGraph {

	// TODO: convert to some form of parallelizable property maps?

	/// Computes the transitive closure in parallel.
	///
	/// - Precondition: `isReachable` is set on the start vertex (verticies).
	/// - Returns: the number of steps taken to compute the closure (aka longest path length).
	mutating func computeTransitiveClosure<Mailboxes: MailboxesProtocol>(
		using mailboxes: inout Mailboxes
	) -> Int
	where Mailboxes.Mailbox.Graph == Self, Mailboxes.Mailbox.Message == EmptyMergeableMessage {
		// Super-step 0 starts everything going and does a slightly different operation.
		step(mailboxes: &mailboxes) { (vertexId, vertex, mailbox, graph) in
			assert(mailbox.messages.count == 0, "Mailbox was not empty on the first step.")
			if vertex.isReachable {
				for edge in graph.edges(from: vertexId) {
					mailbox.send(EmptyMergeableMessage(), to: graph.destination(of: edge))
				}
			}
		}
		var stepCount = 1
		// While we're still sending messages...
		while mailboxes.deliver() {
			stepCount += 1
			step(mailboxes: &mailboxes) { (vertexId, vertex, mailbox, graph) in
				let startedReachable = vertex.isReachable
				if !startedReachable && !mailbox.messages.isEmpty {
					vertex.isReachable = true
					for edge in graph.edges(from: vertexId) {
						mailbox.send(EmptyMergeableMessage(), to: graph.destination(of: edge))
					}
				}
			}
		}
		return stepCount
	}
}

/// A vertex that can keep track of its distance from another point in the graph.
public protocol DistanceVertex {
	/// A "pointer" to the parent in the search tree.
	associatedtype VertexId
	/// A measure of the distance within the graph.
	associatedtype Distance: GraphDistanceMeasure

	/// The distance from the start vertex (verticies).
	var distance: Distance { get set }

	/// The predecessor vertex.
	///
	/// - Note: `get` is not used in most graph search algorithms, only `set`!
	var predecessor: VertexId? { get set }
}

/// An edge with associated distance.
public protocol DistanceEdge {
	/// The distance measure for the edge.
	associatedtype Distance: GraphDistanceMeasure

	/// The distance cost for traversing this edge.
	var distance: Distance { get }
}

public struct DistanceSearchMessage<VertexId, Distance: GraphDistanceMeasure>: MergeableMessage {
	var predecessor: VertexId
	var distance: Distance

	public mutating func merge(with other: Self) {
		if distance > other.distance {
			self.distance = other.distance
			self.predecessor = other.predecessor
		}
	}
}

public extension ParallelGraph
where
	Self: IncidenceGraph,
	Vertex: DistanceVertex,
	Vertex.VertexId == VertexId
{

	/// Executes breadth first search in parallel.
	///
	/// Note: distances are not kept track of during BFS; at the conclusion of this algorithm,
	/// the `vertex.distance` will be `.zero` if it's reachable, and `.effectiveInfinity` otherwise.
	///
	/// - Parameter startVerticies: The verticies to begin search at.
	/// - Returns: the number of steps taken to compute the closure (aka longest path length).
	mutating func computeBFS<
		Distance: GraphDistanceMeasure,
		Mailboxes: MailboxesProtocol
	>(
		startingAt startVertex: VertexId,
		using mailboxes: inout Mailboxes
	) -> Int
	where
		Mailboxes.Mailbox.Graph == Self,
		Mailboxes.Mailbox.Message == DistanceSearchMessage<VertexId, Distance>
	{
		computeBFS(startingAt: [startVertex], using: &mailboxes)
	}

	/// Executes breadth first search in parallel.
	///
	/// Note: distances are not kept track of during BFS; at the conclusion of this algorithm,
	/// the `vertex.distance` will be `.zero` if it's reachable, and `.effectiveInfinity` otherwise.
	///
	/// - Parameter startVerticies: The verticies to begin search at.
	/// - Returns: the number of steps taken to compute the closure (aka longest path length).
	mutating func computeBFS<
		StartCollection: Collection,
		Distance: GraphDistanceMeasure,
		Mailboxes: MailboxesProtocol
	>(
		startingAt startVerticies: StartCollection,
		using mailboxes: inout Mailboxes
	) -> Int
	where
		Mailboxes.Mailbox.Graph == Self,
		Mailboxes.Mailbox.Message == DistanceSearchMessage<VertexId, Distance>,
		StartCollection.Element == VertexId
	{
		// Super-step 0 starts by initializing everything & gets things going.
		step(mailboxes: &mailboxes) { (vertexId, vertex, mailbox, graph) in
			assert(mailbox.messages.count == 0, "Mailbox was not empty on the first step.")
			if startVerticies.contains(vertexId) {
				vertex.predecessor = vertexId
				vertex.distance = .zero
				for edge in graph.edges(from: vertexId) {
					mailbox.send(
						DistanceSearchMessage(predecessor: vertexId, distance: .zero),
						to: graph.destination(of: edge))
				}
			} else {
				vertex.distance = .effectiveInfinity
			}
		}
		var stepCount = 1
		// While we're still sending messages...
		while mailboxes.deliver() {
			stepCount += 1
			step(mailboxes: &mailboxes) { (vertexId, vertex, mailbox, graph) in
				if let first = mailbox.messages.first {
					if vertex.distance == .zero { return }
					// Transitioning from `.effectiveInfinity` to `.zero`; broadcast to neighbors.
					vertex.distance = .zero
					vertex.predecessor = first.predecessor
					for edge in graph.edges(from: vertexId) {
						mailbox.send(
							DistanceSearchMessage(predecessor: vertexId, distance: .zero),
							to: graph.destination(of: edge))
					}
				}
			}
		}
		return stepCount
	}
}

/// Global state used inside `computeShortestPaths`.
fileprivate struct EarlyStopGlobalState<Distance>: MergeableMessage, DefaultInitializable {
	// TODO: consider initializing to `effectiveInfinity`?
	/// The distance to the end vertex.
	var endVertexDistance: Distance? = nil

	/// Whether verticies are still being discovered in the graph that could yield a shorter path.
	var stillBelowEndVertexDistance: Bool = false

	/// merge `self` with `other`.
	mutating func merge(with other: Self) {
		if endVertexDistance == nil {
			endVertexDistance = other.endVertexDistance
		}
		stillBelowEndVertexDistance = stillBelowEndVertexDistance ||
			other.stillBelowEndVertexDistance
	}
}

public extension ParallelGraph
where
	Self: IncidenceGraph,
	Vertex: DistanceVertex,
	Vertex.VertexId == VertexId
{
	/// Computes the shortest paths from `startVertex`.
	///
	/// A `stopVertex` can be used to stop the algorithm early once the shortest path has been
	/// computed between `startVertex` and `stopVertex`.
	///
	/// Note: this algorithm correctly handles negative weight edges so long as a `stopVertex` is
	/// not specified. Note that negative cycles imply a non-finite shortest path, and thus result
	/// in unspecified behavior.
	///
	/// - Parameter startVertex: The vertex to begin search at.
	/// - Parameter mailboxes: The communication primitive to use.
	/// - Parameter stopVertex: If supplied, once the shortest path from `startVertex` to
	///   `stopVertex` has been determined, searching will stop.
	/// - Parameter: maximumSteps: The maximum number of super-steps to take.
	/// - Returns: the number of steps taken to compute the closure (aka longest path length).
	mutating func computeShortestPaths<
		Distance: GraphDistanceMeasure,
		Mailboxes: MailboxesProtocol,
		DistanceMap: GraphEdgePropertyMap
	>(
		startingAt startVertex: VertexId,
		stoppingAt stopVertex: VertexId? = nil,
		with distances: DistanceMap,
		using mailboxes: inout Mailboxes,
		maximumSteps: Int? = nil
	) -> Int
	where
		Mailboxes.Mailbox.Graph == Self,
		Mailboxes.Mailbox.Message == DistanceSearchMessage<VertexId, Distance>,
		DistanceMap.Graph == Self,
		DistanceMap.Value == Distance,
		Vertex.Distance == Distance
	{
		assert(startVertex != stopVertex, "startVertex was also the stopVertex!")
		// Super-step 0 starts by initializing everything & gets things going.
		step(mailboxes: &mailboxes) { (vertexId, vertex, mailbox, graph) in
			assert(mailbox.messages.count == 0, "Mailbox was not empty on the first step.")
			if vertexId == startVertex {
				vertex.predecessor = vertexId
				vertex.distance = .zero
				for edge in graph.edges(from: vertexId) {
					let edgeDistance = distances.get(graph, edge)
					mailbox.send(
						DistanceSearchMessage(predecessor: vertexId, distance: edgeDistance),
						to: graph.destination(of: edge))
				}
			} else {
				vertex.distance = .effectiveInfinity
			}
		}
		var globalState = EarlyStopGlobalState<Distance>()
		var stepCount = 1
		var seenEndVertexDistance = false
		// While we're still sending messages...
		while mailboxes.deliver() {
			stepCount += 1
			globalState = step(mailboxes: &mailboxes, globalState: globalState) {
				(vertexId, vertex, mailbox, graph, globalState, nextGlobalState) in

				// Note: assumes merging mailbox!
				if let first = mailbox.messages.first {
					if vertex.distance <= first.distance { return }  // Already discovered path.

					// New shortest path; update self.
					vertex.distance = first.distance
					vertex.predecessor = first.predecessor

					if vertexId == stopVertex {
						// Update global state.
						nextGlobalState.endVertexDistance = vertex.distance
					}
					if let endDistance = globalState.endVertexDistance {
						if first.distance > endDistance {
							// Don't bother to send out messages, as this is guaranteed to not be
							// shorter. (Note: assumes positive weights!)
							return
						}
						// Inform the world that we're still exploring the graph in a potentially
						// productive way.
						nextGlobalState.stillBelowEndVertexDistance = true
					}
					// Broadcast updated shortest distances.
					for edge in graph.edges(from: vertexId) {
						let edgeDistance = distances.get(graph, edge)
						mailbox.send(
							DistanceSearchMessage(
								predecessor: vertexId,
								distance: first.distance + edgeDistance),
							to: graph.destination(of: edge))
					}
				}
			}
			if globalState.endVertexDistance != nil && !globalState.stillBelowEndVertexDistance {
				// Must have at least one step once the end vertex distance has been seen.
				if seenEndVertexDistance {
					return stepCount  // Done!
				} else {
					seenEndVertexDistance = true
				}
			}
			if stepCount == maximumSteps { return stepCount }  // Reached max step count!
		}
		return stepCount
	}

}

// MARK: - Parallel Graph Implementations

extension PropertyAdjacencyList: ParallelGraph {
	/// Runs `fn` across each vertex delivering messages in `mailboxes` and making `globalState`
	/// available to each vertex; outputs from each vertex are aggregated into `nextGlobalState`.
	public mutating func step<
		Mailboxes: MailboxesProtocol,
		GlobalState: MergeableMessage & DefaultInitializable
	>(
		mailboxes: inout Mailboxes,
		globalState: GlobalState,
		_ fn: PerVertexFunction<Mailboxes.Mailbox, GlobalState>
	) rethrows -> GlobalState where Mailboxes.Mailbox.Graph == Self {
		return try sequentialStep(mailboxes: &mailboxes, globalState: globalState, fn)
	}

	/// Runs `fn` across each vertex delivering messages in `mailboxes` and making `globalState`
	/// available to each vertex; outputs from each vertex are aggregated into `nextGlobalState`.
	public mutating func sequentialStep<
		Mailboxes: MailboxesProtocol,
		GlobalState: MergeableMessage & DefaultInitializable
	>(
		mailboxes: inout Mailboxes,
		globalState: GlobalState,
		_ fn: PerVertexFunction<Mailboxes.Mailbox, GlobalState>
	) rethrows -> GlobalState where Mailboxes.Mailbox.Graph == Self {
		var newGlobalState = GlobalState()
		for i in 0..<vertexProperties.count {
			let vertexId = VertexId(IdType(i))
			try mailboxes.withMailbox(for: vertexId) { mb in
				try fn(vertexId, &vertexProperties[i], &mb, self, globalState, &newGlobalState)
			}
		}
		return newGlobalState
	}

	/// Runs `fn` across each vertex delivering messages in `mailboxes`.
	public mutating func step<Mailboxes: MailboxesProtocol>(
		mailboxes: inout Mailboxes,
		_ fn: NonGlobalPerVertexFunction<Mailboxes.Mailbox>
	) rethrows where Mailboxes.Mailbox.Graph == Self {
		try sequentialStep(mailboxes: &mailboxes, fn)
	}

	/// Runs `fn` across each vertex delivering messages in `mailboxes`.
	public mutating func sequentialStep<Mailboxes: MailboxesProtocol>(
		mailboxes: inout Mailboxes,
		_ fn: NonGlobalPerVertexFunction<Mailboxes.Mailbox>
	) rethrows where Mailboxes.Mailbox.Graph == Self {
		for i in 0..<vertexProperties.count {
			let vertexId = VertexId(IdType(i))
			try mailboxes.withMailbox(for: vertexId) { mb in
				try fn(vertexId, &vertexProperties[i], &mb, self)
			}
		}
	}
}
