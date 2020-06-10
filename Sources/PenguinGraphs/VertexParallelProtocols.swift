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

import PenguinParallel
import PenguinStructures

// MARK: - Mailboxes

/// Represents the ability to consolidate two messages into a single message.
///
/// After merging with another message, only `self` will be delivered. (`other` will be discarded.)
public protocol MergeableMessage {
  /// Merges `other` into `self`.
  mutating func merge(_ other: Self)
}

extension Empty: MergeableMessage {
  /// Logically merges `self` with `other`; this operation is a no-op.
  public mutating func merge(_ other: Self) {}  // Do nothing!
}

/// Represents the per-vertex communication abstraction for vertex-parallel algorithms.
///
/// Vertex-parallel algorithms execute as a series of super-steps, where in each step, a vertex can
/// (1) perform vertex-local computation, (2) receive messages from the previous step, and (3) send
/// messages to any other vertex (that will be received in the next step).
///
/// As a simplification and performance optimization, we require that all messages can be merged,
/// such verticies receive at most one message per step. Messages are merged in parallel, which
/// reduces memory and bandwidth pressures. This does not cause a loss in generality of the
/// algorithms that can be expressed, as it is trivial to write an "envelope" type that is an array
/// of the underlying messages.
///
/// This abstraction is inspired by:
///
/// Pregel: A System for Large-Scale Graph Processing (2010)
/// Grzegorz Malewicz, Matthew H. Austern, Aart J. C. Bik, James C. Dehnert, Ilan Horn, Naty Leiser,
/// and Grzegorz Czajkowski
///
public protocol MailboxProtocol {
  /// The type of messages being exchanged.
  associatedtype Message: MergeableMessage
  /// The graph data structure being operated upon.
  associatedtype Graph: GraphProtocol

  /// The consolidated message
  var inbox: Message? { get }

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
  mutating func withMailbox(for vertex: Graph.VertexId, _ fn: (inout Mailbox) throws -> Void)
    rethrows
}

extension MailboxesProtocol {
  /// The graph associated with the mailboxes.
  public typealias Graph = Mailbox.Graph
  /// The type of messages that can be sent using this mailbox.
  public typealias Message = Mailbox.Message
}

/// A non-concurrent table-based mailbox implementation.
public struct SequentialMailboxes<
  Message: MergeableMessage,
  Graph: GraphProtocol
>: MailboxesProtocol where Graph.VertexId: IdIndexable {
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
    /// The incoming message.
    public let inbox: Message?
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
        outboxes[vertex.index]!.merge(message)
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
  public mutating func withMailbox(for vertex: Graph.VertexId, _ fn: (inout Mailbox) throws -> Void)
    rethrows
  {
    // TODO: Ensure we avoid copying outbox or else we're accidentally quadratic!
    var box = Mailbox(inbox: self.inbox[vertex.index], outboxes: self.outbox)
    defer {
      self.outbox = box.outboxes
      self.hasOutgoingMessages = self.hasOutgoingMessages || box.didSendMessage
    }
    try fn(&box)
  }

  /// Initialize mailboxes for `graph` for `messageType` messages.
  ///
  /// This initializer helps the type inference algorithm along.
  public init<SequentialGraph: ParallelGraph & VertexListGraph>(for graph: __shared SequentialGraph, sending messageType: Message.Type) where SequentialGraph.ParallelProjection == Graph {
    self.init(vertexCount: graph.vertexCount)
  }
}

/// Mailboxes that allow communication without synchronization.
///
/// Note: messages are delivered only once.
public class PerThreadMailboxes<
  Message: MergeableMessage,
  Graph: GraphProtocol
>: MailboxesProtocol where Graph.VertexId: IdIndexable {
  // TODO: Add locks to guard against multiple donated threads.

  struct BufferHeader {
    let count: Int
    var hasMessages: Bool = false
  }

  /// The header is `true` when there is a message contained within it, false
  /// otherwise.
  class Buffer: ManagedBuffer<BufferHeader, Message?> {
    var count: Int { header.count }

    func send(_ message: Message, to vertex: Graph.VertexId) {
      header.hasMessages = true
      withUnsafeMutablePointerToElements { buff in
        let ptr = buff.advanced(by: vertex.index)
        if ptr.pointee == nil {
          ptr.pointee = message
        } else {
          ptr.pointee!.merge(message)
        }
      }
    }

    func receive(for vertex: Graph.VertexId) -> Message? {
      withUnsafeMutablePointerToElements { buff in
        let ptr = buff.advanced(by: vertex.index)
        let msg = ptr.move()
        ptr.initialize(to: nil)
        return msg
      }
    }
  }

  private static func makeEmptyBuffer(vertexCount: Int) -> Buffer {
    let buff = Buffer.create(minimumCapacity: vertexCount) { buff in
      buff.withUnsafeMutablePointerToElements {
        $0.initialize(repeating: nil, count: vertexCount)
      }
      return BufferHeader(count: vertexCount)
    }
    return buff as! Buffer
  }

  /// An array of Buffer's (one per compute thread to avoid synchronization).
  private var outbox: [Buffer]

  /// Messages being received this super-step.
  private var inbox: Buffer

  /// Initializes `self` for a given graph size.
  public init(vertexCount: Int, threadCount: Int) {
    assert(threadCount > 0)
    var outbox = [Buffer]()
    outbox.reserveCapacity(threadCount + 1)
    for _ in 0..<(threadCount + 1) {
      outbox.append(Self.makeEmptyBuffer(vertexCount: vertexCount))
    }
    self.outbox = outbox
    inbox = Self.makeEmptyBuffer(vertexCount: vertexCount)
  }

  /// A mailbox that merges messages together.
  public struct Mailbox: MailboxProtocol {
    /// The incoming message.
    public let inbox: Message?
    /// The outgoing messages.
    unowned var outboxes: Buffer
    /// Sends `message` to `vertex` next step.
    public mutating func send(_ message: Message, to vertex: Graph.VertexId) {
      outboxes.send(message, to: vertex)
    }
  }

  /// Transfers messages that were previously sent into the inboxes of the verticies.
  public func deliver() -> Bool {
    var hasMessages = false
    var firstNonemptyOutboxIndex = 0
    // Find the first mailbox that has messages & set that to the outbox.
    for i in 0..<outbox.count {
      if outbox[i].header.hasMessages {
        swap(&inbox, &outbox[i])
        outbox[i].header.hasMessages = false
        hasMessages = true
        firstNonemptyOutboxIndex = i
        break
      }
    }
    if hasMessages {
      // Merge in all related messages.
      for i in firstNonemptyOutboxIndex..<outbox.count {
        if outbox[i].header.hasMessages {
          assert(inbox.count == outbox[i].count)
          outbox[i].withUnsafeMutablePointerToElements { outboxP in
            inbox.withUnsafeMutablePointerToElements { inboxP in
              var i = inboxP
              var o = outboxP
              for _ in 0..<inbox.count {
                if i.pointee == nil {
                  i.moveInitialize(from: o, count: 1)
                } else {
                  if let elem = o.move() {
                    i.pointee!.merge(elem)
                  }
                }
                o.initialize(to: nil)
                i = i.advanced(by: 1)
                o = o.advanced(by: 1)
              }
            }
          }
          outbox[i].header.hasMessages = false  // Clear the hasMessages flag.
        }
      }
      return true
    } else {
      return false
    }
  }

  /// Executes `fn` passing in the `Mailbox` for `vertex`.
  public func withMailbox(for vertex: Graph.VertexId, _ fn: (inout Mailbox) throws -> Void) rethrows
  {
    let threadIndex = ComputeThreadPools.currentThreadIndex ?? (outbox.count - 1)
    var box = Mailbox(
      inbox: self.inbox.receive(for: vertex),
      outboxes: outbox[threadIndex])
    try fn(&box)
  }

  /// Initialize mailboxes for `graph` for `messageType` messages.
  ///
  /// This initializer helps the type inference algorithm along.
  public convenience init<SequentialGraph: VertexListGraph & ParallelGraph>(for graph: __shared SequentialGraph, sending messageType: Message.Type) where SequentialGraph.ParallelProjection == Graph {
    self.init(vertexCount: graph.vertexCount, threadCount: ComputeThreadPools.maxParallelism)
  }
}

// MARK: - Parallel Graph Algorithms

/// Context provided to the function that is invoked on a per-vertex basis.
///
/// We use a context object to (1) simplify the parallel graph API, and (2) make it easy to extend
/// the parallel graph implementation if new bits of context need to be added over time.
///
/// `ParallelGraphAlgorithmContext` also helps enforce the inability to access Vertex property maps
/// during the course of execution, as that could result in violations of the Law of Exclusivity.
///
/// - SeeAlso: `ParalleGraph`
public struct ParallelGraphAlgorithmContext<
  Graph,  // : GraphProtocol,  // Redundant conformance.
  Message,
  GlobalState: MergeableMessage,
  Mailbox: MailboxProtocol
> where Mailbox.Message == Message, Mailbox.Graph == Graph {
  // Note: this is a struct and not a protocol because Swift doesn't support higher-kinded types,
  // as well as conditional requirements on protocols based on associated types.

  // TODO: Add support for (conditionally) recording / applying graph structure mutations.

  /// The identifier of the vertex this function execution is operating upon.
  public let vertex: Graph.VertexId

  /// The global state provided to each vertex.
  ///
  /// This global state is often computed as a result of merging the computed global state from
  /// each vertex in the previous super-step, although it is provided by the user-program for the
  /// first step.
  public let globalState: GlobalState

  // // TODO: consider making nextGlobalState an optional and/or a pointer if that can avoid extra
  // // ref-counting / improve performance and/or providing a send-like API instead.
  // /// Global state that will be aggregated across all verticies in this step and propagated as
  // /// read-only for the next step.
  // public var nextGlobalState: GlobalState

  /// A copy of the graph to be used for graph-structure queries.
  private let graph: Graph

  /// The mailbox for this vertex.
  private var mailbox: UnsafeMutablePointer<Mailbox>

  /// Initializes `self` with the given properties.
  public init(
    vertex: Graph.VertexId,
    globalState: GlobalState,
    graph: Graph,
    mailbox: UnsafeMutablePointer<Mailbox>
  ) {
    self.vertex = vertex
    self.globalState = globalState
    self.graph = graph
    self.mailbox = mailbox
  }

  /// The merged message resulting from merging all the messages sent in the last parallel step.
  public var inbox: Message? { mailbox.pointee.inbox }

  /// Sends `message` to `vertex`, which will be received at the next step.
  public mutating func send(_ message: Message, to vertex: Graph.VertexId) {
    mailbox.pointee.send(message, to: vertex)
  }

  /// Retrieve edge propreties.
  public func getEdgeProperty<Map: ParallelCapablePropertyMap>(
    for edge: Graph.EdgeId,
    in map: Map
  ) -> Map.Value where Map.Graph.ParallelProjection == Graph, Map.Key == Graph.EdgeId {
    map.get(edge, in: graph)
  }
}

extension ParallelGraphAlgorithmContext where Graph: IncidenceGraph {
  /// The number of edges that source from the current vertex.
  public var outDegree: Int { graph.outDegree(of: vertex) }

  /// The edges that source from the current vertex.
  public var edges: Graph.VertexEdgeCollection { graph.edges(from: vertex) }

  /// Returns the destination of `edge`.
  public func destination(of edge: Graph.EdgeId) -> Graph.VertexId { graph.destination(of: edge) }
}

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

  /// The parallel representation of `Self`.
  ///
  /// Most graphs have value semantics. This is at odds with data-parallel processing (where
  /// non-overlapping mutations occur across multiple threads). In order to support value semantics
  /// and parallel processing, we define an associated type `ParallelProjection`, which is a
  /// representation of `self` with mutation semantics compatible with data-parallel operations.
  associatedtype ParallelProjection: GraphProtocol where
    ParallelProjection.VertexId == VertexId,
    ParallelProjection.EdgeId == EdgeId

  /// The context that is passed to the vertex-parallel functions during execution.
  typealias Context<Mailbox: MailboxProtocol, GlobalState: MergeableMessage> =
    ParallelGraphAlgorithmContext<ParallelProjection, Mailbox.Message, GlobalState, Mailbox>
  where Mailbox.Graph == ParallelProjection

  /// The type of functions that can be executed in vertex-parallel fashion across the graph.
  typealias VertexParallelFunction<Mailbox: MailboxProtocol, GlobalState: MergeableMessage> =
    (inout Context<Mailbox, GlobalState>, inout Vertex) throws -> GlobalState?
  where Mailbox.Graph == ParallelProjection

  // TODO: remove default init requirement & make return type optional!
  /// Runs `fn` across each vertex delivering messages in `mailboxes`, making `globalState`
  /// available to each vertex; returns the merged outputs from each vertex.
  ///
  /// While read-only edge property maps can be used as part of the computation, all use of vertex
  /// property maps are prohibited, as use could cause race conditions and violations of Swift's
  /// law of exlusivity.
  mutating func step<
    Mailboxes: MailboxesProtocol,
    GlobalState: MergeableMessage & DefaultInitializable
  >(
    mailboxes: inout Mailboxes,
    globalState: GlobalState,
    _ fn: VertexParallelFunction<Mailboxes.Mailbox, GlobalState>
  ) rethrows -> GlobalState where Mailboxes.Mailbox.Graph == ParallelProjection
}

// extension ParallelGraph {
//   /// By default, the parallel projection is self.
//   typealias ParallelProjection = Self
// }

extension ParallelGraph {
  /// A per-vertex function that doesn't use global state.
  public typealias NoGlobalVertexParallelFunction<Mailbox: MailboxProtocol> =
    (inout Context<Mailbox, Empty>, inout Vertex) throws -> Void
  where Mailbox.Graph == ParallelProjection

  /// Applies `fn` across all vertices in `self` in parallel using `mailboxes` for transport.
  public mutating func step<
    Mailboxes: MailboxesProtocol
  >(
    mailboxes: inout Mailboxes,
    _ fn: NoGlobalVertexParallelFunction<Mailboxes.Mailbox>
  ) rethrows where Mailboxes.Mailbox.Graph == ParallelProjection {
    _ = try step(mailboxes: &mailboxes, globalState: Empty()) { (ctx, vertex) in
      try fn(&ctx, &vertex)
      return nil
    }
  }
}

/// A protocol for whether a vertex is reachable.
public protocol ReachableVertex {
  /// True if `self` is reachable from the starting point.
  var isReachable: Bool { get set }
}

extension ParallelGraph where Vertex: ReachableVertex, Self: IncidenceGraph {

  // TODO: convert to some form of parallelizable property maps?

  /// Computes the transitive closure in parallel.
  ///
  /// - Precondition: `isReachable` is set on the start vertex (verticies).
  /// - Returns: the number of steps taken to compute the closure (aka longest path length).
  public mutating func parallelTransitiveClosure<Mailboxes: MailboxesProtocol>(
    using mailboxes: inout Mailboxes,
    maxStepCount: Int = Int.max
  ) -> Int
  where Mailboxes.Mailbox.Graph == ParallelProjection, Mailboxes.Mailbox.Message == Empty, ParallelProjection: IncidenceGraph {
    // Super-step 0 starts everything going and does a slightly different operation.
    step(mailboxes: &mailboxes) { (context, vertex) in
      assert(context.inbox == nil, "Mailbox was not empty on the first step.")
      if vertex.isReachable {
        for edge in context.edges {
          context.send(Empty(), to: context.destination(of: edge))
        }
      }
    }
    var stepCount = 1
    // While we're still sending messages...
    while mailboxes.deliver() {
      stepCount += 1
      step(mailboxes: &mailboxes) { (context, vertex) in
        let startedReachable = vertex.isReachable
        if !startedReachable && context.inbox != nil {
          vertex.isReachable = true
          for edge in context.edges {
            context.send(Empty(), to: context.destination(of: edge))
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
  associatedtype Distance: Comparable & AdditiveArithmetic

  /// The distance from the start vertex (verticies).
  var distance: Distance { get set }

  /// The predecessor vertex.
  ///
  /// - Note: `get` is not used in most graph search algorithms, only `set`!
  var predecessor: VertexId? { get set }
}

// Note: this must be made public due to Swift's lack of higher-kinded types.
/// Messages used during parallel BFS and parallel shortest paths.
public struct DistanceSearchMessage<VertexId, Distance: Comparable & AdditiveArithmetic>: MergeableMessage {
  var predecessor: VertexId
  var distance: Distance

  /// Merges `self` with `other`.
  public mutating func merge(_ other: Self) {
    if distance > other.distance {
      self.distance = other.distance
      self.predecessor = other.predecessor
    }
  }
}

extension ParallelGraph
where
  Self: IncidenceGraph,
  Vertex: DistanceVertex,
  Vertex.VertexId == VertexId
{

  /// Executes breadth first search in parallel.
  ///
  /// Note: distances are not kept track of during BFS; at the conclusion of this algorithm,
  /// the `vertex.distance` will be `.zero` if it's reachable, and `effectivelyInfinite` otherwise.
  ///
  /// - Parameter startVertex: The verticies to begin search at.
  /// - Returns: the number of steps taken to compute the closure (aka longest path length).
  public mutating func computeBFS<
    Distance: FloatingPoint,
    Mailboxes: MailboxesProtocol
  >(
    startingAt startVertex: VertexId,
    using mailboxes: inout Mailboxes
  ) -> Int
  where
    Mailboxes.Mailbox.Graph == ParallelProjection,
    ParallelProjection: IncidenceGraph,
    Vertex.Distance == Distance,
    Mailboxes.Mailbox.Message == DistanceSearchMessage<VertexId, Distance>
  {
    computeBFS(startingAt: [startVertex], effectivelyInfinite: Distance.infinity, using: &mailboxes)
  }

  /// Executes breadth first search in parallel.
  ///
  /// Note: distances are not kept track of during BFS; at the conclusion of this algorithm,
  /// the `vertex.distance` will be `.zero` if it's reachable, and `effectivelyInfinite` otherwise.
  ///
  /// - Parameter startVertex: The verticies to begin search at.
  /// - Returns: the number of steps taken to compute the closure (aka longest path length).
  public mutating func computeBFS<
    Distance: FixedWidthInteger,
    Mailboxes: MailboxesProtocol
  >(
    startingAt startVertex: VertexId,
    using mailboxes: inout Mailboxes
  ) -> Int
  where
    Mailboxes.Mailbox.Graph == ParallelProjection,
    ParallelProjection: IncidenceGraph,
    Vertex.Distance == Distance,
    Mailboxes.Mailbox.Message == DistanceSearchMessage<VertexId, Distance>
  {
    computeBFS(startingAt: [startVertex], effectivelyInfinite: Distance.max, using: &mailboxes)
  }

  /// Executes breadth first search in parallel.
  ///
  /// Note: distances are not kept track of during BFS; at the conclusion of this algorithm,
  /// the `vertex.distance` will be `.zero` if it's reachable, and `effectivelyInfinite` otherwise.
  ///
  /// - Parameter startVerticies: The verticies to begin search at.
  /// - Returns: the number of steps taken to compute the transitive closure.
  public mutating func computeBFS<
    StartCollection: Collection,
    Distance: AdditiveArithmetic & Comparable,
    Mailboxes: MailboxesProtocol
  >(
    startingAt startVerticies: StartCollection,
    effectivelyInfinite: Distance,
    using mailboxes: inout Mailboxes
  ) -> Int
  where
    Mailboxes.Mailbox.Graph == ParallelProjection,
    ParallelProjection: IncidenceGraph,
    Vertex.Distance == Distance,
    Mailboxes.Mailbox.Message == DistanceSearchMessage<VertexId, Distance>,
    StartCollection.Element == VertexId
  {
    // Super-step 0 starts by initializing everything & gets things going.
    step(mailboxes: &mailboxes) { (context, vertex) in
      assert(context.inbox == nil, "Mailbox was not empty on the first step.")
      if startVerticies.contains(context.vertex) {
        vertex.predecessor = context.vertex
        vertex.distance = .zero
        for edge in context.edges {
          context.send(
            DistanceSearchMessage(predecessor: context.vertex, distance: .zero),
            to: context.destination(of: edge))
        }
      } else {
        vertex.distance = effectivelyInfinite
      }
    }
    var stepCount = 1
    // While we're still sending messages...
    while mailboxes.deliver() {
      stepCount += 1
      step(mailboxes: &mailboxes) { (context, vertex) in
        if let message = context.inbox {
          if vertex.distance == .zero { return }
          // Transitioning from `effectivelyInfinite` to `.zero`; broadcast to neighbors.
          vertex.distance = .zero
          vertex.predecessor = message.predecessor
          for edge in context.edges {
            context.send(
              DistanceSearchMessage(predecessor: context.vertex, distance: .zero),
              to: context.destination(of: edge))
          }
        }
      }
    }
    return stepCount
  }
}

/// Global state used inside `computeShortestPaths`.
fileprivate struct EarlyStopGlobalState<Distance>: MergeableMessage, DefaultInitializable {
  /// The distance to the end vertex.
  var endVertexDistance: Distance? = nil

  /// Whether verticies are still being discovered in the graph that could yield a shorter path.
  var stillBelowEndVertexDistance: Bool = false

  /// merges `self` with `other`.
  mutating func merge(_ other: Self) {
    if endVertexDistance == nil {
      endVertexDistance = other.endVertexDistance
    }
    stillBelowEndVertexDistance = stillBelowEndVertexDistance || other.stillBelowEndVertexDistance
  }
}

extension ParallelGraph
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
  public mutating func computeShortestPaths<
    Distance: Comparable & AdditiveArithmetic,
    Mailboxes: MailboxesProtocol,
    DistanceMap: ParallelCapablePropertyMap
  >(
    startingAt startVertex: VertexId,
    stoppingAt stopVertex: VertexId? = nil,
    distances: DistanceMap,
    effectivelyInfinite: Distance,
    mailboxes: inout Mailboxes,
    maximumSteps: Int? = nil
  ) -> Int
  where
    Mailboxes.Mailbox.Graph == ParallelProjection,
    ParallelProjection: IncidenceGraph,
    Mailboxes.Mailbox.Message == DistanceSearchMessage<VertexId, Distance>,
    DistanceMap.Graph == Self,
    DistanceMap.Key == EdgeId,
    DistanceMap.Value == Distance,
    Vertex.Distance == Distance
  {
    assert(startVertex != stopVertex, "startVertex was also the stopVertex!")
    // Super-step 0 starts by initializing everything & gets things going.
    step(mailboxes: &mailboxes) { (context, vertex) in
      assert(context.inbox == nil, "Mailbox was not empty on the first step.")
      if context.vertex == startVertex {
        vertex.predecessor = context.vertex
        vertex.distance = .zero
        for edge in context.edges {
          let edgeDistance = context.getEdgeProperty(for: edge, in: distances)
          context.send(
            DistanceSearchMessage(predecessor: context.vertex, distance: edgeDistance),
            to: context.destination(of: edge))
        }
      } else {
        vertex.distance = effectivelyInfinite
      }
    }
    var globalState = EarlyStopGlobalState<Distance>()
    var stepCount = 1
    var seenEndVertexDistance = false
    // While we're still sending messages...
    while mailboxes.deliver() {
      stepCount += 1
      globalState = step(mailboxes: &mailboxes, globalState: globalState) {
        (context, vertex) in
        if let message = context.inbox {
          if vertex.distance <= message.distance { return nil }  // Already discovered path

          // New shortest path; update self.
          vertex.distance = message.distance
          vertex.predecessor = message.predecessor

          var nextGlobalState = EarlyStopGlobalState<Distance>()
          if context.vertex == stopVertex {
            // Update global state.
            nextGlobalState.endVertexDistance = vertex.distance
          }
          if let endDistance = globalState.endVertexDistance {
            if message.distance > endDistance {
              // Don't bother to send out messages, as this is guaranteed to not be
              // shorter. (Note: assumes positive weights!)
              return nextGlobalState
            }
            // Inform the world that we're still exploring the graph in a potentially
            // productive way.
            nextGlobalState.stillBelowEndVertexDistance = true
          }
          // Broadcast updated shortest distances.
          for edge in context.edges {
            let edgeDistance = context.getEdgeProperty(for: edge, in: distances)
            context.send(
              DistanceSearchMessage(
                predecessor: context.vertex,
                distance: message.distance + edgeDistance),
              to: context.destination(of: edge))
          }
          return nextGlobalState
        }
        return nil
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
