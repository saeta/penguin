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

import PenguinGraphs
import PenguinParallelWithFoundation
import PenguinStructures
import XCTest

final class VertexParallelTests: XCTestCase {

  // MARK: - Reachable test types

  /// A reachable vertex.
  struct TestReachableVertex: DefaultInitializable, ReachableVertex {
    var isReachable: Bool = false
  }

  /// A test reachable message.
  struct SimpleMessage: MergeableMessage {
    var isTransitivelyReachable: Bool

    mutating func merge(_ other: Self) {
      self.isTransitivelyReachable =
        self.isTransitivelyReachable || other.isTransitivelyReachable
    }
  }
  typealias ReachableGraph = DirectedAdjacencyList<TestReachableVertex, Empty, Int32>

  // MARK: - Distance test types

  struct TestDistanceEdge: DefaultInitializable {
    public init() { distance = 1 }
    public init(_ distance: Int) { self.distance = distance }
    var distance: Int
  }

  struct TestDistanceVertex: DefaultInitializable, DistanceVertex {
    var distance: Int
    var predecessor: DirectedAdjacencyList<TestDistanceVertex, TestDistanceEdge, Int32>.VertexId?

    public init() {
      distance = Int.max
      predecessor = nil
    }
  }

  typealias DistanceGraph = DirectedAdjacencyList<TestDistanceVertex, TestDistanceEdge, Int32>
  typealias TestDistanceSearchMessage = DistanceSearchMessage<DistanceGraph.VertexId, Int>

  // MARK: - tests

  func testSequentialMessagePropagation() {
    var g = makeSimpleReachabilityGraph()
    var mailboxes = SequentialMailboxes(for: g, sending: Type<SimpleMessage>())
    runReachabilityTest(&g, &mailboxes)
  }

  func testTransitiveClosureSequentialMerging() {
    var g = makeSimpleReachabilityGraph()
    var mailboxes = SequentialMailboxes(for: g, sending: Type<Empty>())
    XCTAssertEqual(3, g.parallelTransitiveClosure(using: &mailboxes))
    let vIds = g.vertices
    XCTAssert(g[vertex: vIds[0]].isReachable)
    XCTAssert(g[vertex: vIds[1]].isReachable)
    XCTAssert(g[vertex: vIds[2]].isReachable)
    XCTAssert(g[vertex: vIds[3]].isReachable)
    XCTAssertFalse(g[vertex: vIds[4]].isReachable)
  }

  func testParallelBFSSequentialMerging() {
    var g = makeDistanceGraph()
    var mailboxes = SequentialMailboxes(
      for: g,
      sending: Type<DistanceSearchMessage<DistanceGraph.VertexId, Int>>())
    let vIds = g.vertices

    XCTAssertEqual(4, g.computeBFS(startingAt: vIds[0], using: &mailboxes))

    //  -> v0 -> v1 -> v2    v6 (disconnected)
    // |    '--> v3 <--'
    // '--- v5 <--"--> v4

    XCTAssertEqual(vIds[0], g[vertex: vIds[0]].predecessor)
    XCTAssertEqual(vIds[0], g[vertex: vIds[1]].predecessor)
    XCTAssertEqual(vIds[1], g[vertex: vIds[2]].predecessor)
    XCTAssertEqual(vIds[0], g[vertex: vIds[3]].predecessor)
    XCTAssertEqual(vIds[3], g[vertex: vIds[4]].predecessor)
    XCTAssertEqual(vIds[3], g[vertex: vIds[5]].predecessor)
    XCTAssertEqual(nil, g[vertex: vIds[6]].predecessor)

    XCTAssertEqual(0, g[vertex: vIds[0]].distance)
    XCTAssertEqual(0, g[vertex: vIds[1]].distance)
    XCTAssertEqual(0, g[vertex: vIds[2]].distance)
    XCTAssertEqual(0, g[vertex: vIds[3]].distance)
    XCTAssertEqual(0, g[vertex: vIds[4]].distance)
    XCTAssertEqual(0, g[vertex: vIds[5]].distance)
    XCTAssertEqual(Int.max, g[vertex: vIds[6]].distance)
  }

  func testParallelShortestPathSequentialMerging() {
    var g = makeDistanceGraph()
    var mailboxes = SequentialMailboxes(
      for: g,
      sending: Type<DistanceSearchMessage<DistanceGraph.VertexId, Int>>())
    let vIds = g.vertices

    let edgeDistanceMap = InternalEdgePropertyMap(for: g).transform(\.distance)
    XCTAssertEqual(
      6,
      g.computeShortestPaths(
        startingAt: vIds[0],
        distances: edgeDistanceMap,
        effectivelyInfinite: Int.max,
        mailboxes: &mailboxes)
    )

    //  -> v0 -> v1 -> v2    v6 (disconnected)
    // |    '--> v3 <--'
    // '--- v5 <--"--> v4

    XCTAssertEqual(vIds[0], g[vertex: vIds[0]].predecessor)
    XCTAssertEqual(vIds[0], g[vertex: vIds[1]].predecessor)
    XCTAssertEqual(vIds[1], g[vertex: vIds[2]].predecessor)
    XCTAssertEqual(vIds[2], g[vertex: vIds[3]].predecessor)
    XCTAssertEqual(vIds[3], g[vertex: vIds[4]].predecessor)
    XCTAssertEqual(vIds[3], g[vertex: vIds[5]].predecessor)
    XCTAssertEqual(nil, g[vertex: vIds[6]].predecessor)

    XCTAssertEqual(0, g[vertex: vIds[0]].distance)
    XCTAssertEqual(1, g[vertex: vIds[1]].distance)
    XCTAssertEqual(2, g[vertex: vIds[2]].distance)
    XCTAssertEqual(3, g[vertex: vIds[3]].distance)
    XCTAssertEqual(8, g[vertex: vIds[4]].distance)
    XCTAssertEqual(4, g[vertex: vIds[5]].distance)
    XCTAssertEqual(Int.max, g[vertex: vIds[6]].distance)
  }

  func testParallelShortestPathSequentialMergingEarlyStop() {
    var g = makeDistanceGraph()

    var mailboxes = SequentialMailboxes(
      for: g,
      sending: Type<DistanceSearchMessage<DistanceGraph.VertexId, Int>>())
    let vIds = g.vertices

    let edgeDistanceMap = InternalEdgePropertyMap(for: g).transform(\.distance)
    XCTAssertEqual(
      3,
      g.computeShortestPaths(
        startingAt: vIds[0],
        distances: edgeDistanceMap,
        effectivelyInfinite: Int.max,
        mailboxes: &mailboxes,
        maximumSteps: 3))

    //  -> v0 -> v1 -> v2    v6 (disconnected)
    // |    '--> v3 <--'
    // '--- v5 <--"--> v4

    XCTAssertEqual(vIds[0], g[vertex: vIds[0]].predecessor)
    XCTAssertEqual(vIds[0], g[vertex: vIds[1]].predecessor)
    XCTAssertEqual(vIds[1], g[vertex: vIds[2]].predecessor)
    XCTAssertEqual(vIds[0], g[vertex: vIds[3]].predecessor)
    XCTAssertEqual(vIds[3], g[vertex: vIds[4]].predecessor)
    XCTAssertEqual(vIds[3], g[vertex: vIds[5]].predecessor)
    XCTAssertEqual(nil, g[vertex: vIds[6]].predecessor)

    XCTAssertEqual(0, g[vertex: vIds[0]].distance)
    XCTAssertEqual(1, g[vertex: vIds[1]].distance)
    XCTAssertEqual(2, g[vertex: vIds[2]].distance)
    XCTAssertEqual(10, g[vertex: vIds[3]].distance)
    XCTAssertEqual(15, g[vertex: vIds[4]].distance)
    XCTAssertEqual(11, g[vertex: vIds[5]].distance)
    XCTAssertEqual(Int.max, g[vertex: vIds[6]].distance)
  }

  func testParallelShortestPathSequentialMergingStopVertex() {
    var g = makeDistanceGraph()

    var mailboxes = SequentialMailboxes(
      for: g,
      sending: Type<DistanceSearchMessage<DistanceGraph.VertexId, Int>>())
    let vIds = g.vertices

    let edgeDistanceMap = InternalEdgePropertyMap(for: g).transform(\.distance)
    XCTAssertEqual(
      4,
      g.computeShortestPaths(
        startingAt: vIds[0],
        stoppingAt: vIds[3],
        distances: edgeDistanceMap,
        effectivelyInfinite: Int.max,
        mailboxes: &mailboxes))

    //  -> v0 -> v1 -> v2    v6 (disconnected)
    // |    '--> v3 <--'
    // '--- v5 <--"--> v4

    XCTAssertEqual(vIds[0], g[vertex: vIds[0]].predecessor)
    XCTAssertEqual(vIds[0], g[vertex: vIds[1]].predecessor)
    XCTAssertEqual(vIds[1], g[vertex: vIds[2]].predecessor)
    XCTAssertEqual(vIds[2], g[vertex: vIds[3]].predecessor)
    XCTAssertEqual(vIds[3], g[vertex: vIds[4]].predecessor)  // TODO: avoid sending messages!
    XCTAssertEqual(vIds[3], g[vertex: vIds[5]].predecessor)  // TODO: avoid sending messages!
    XCTAssertEqual(nil, g[vertex: vIds[6]].predecessor)

    XCTAssertEqual(0, g[vertex: vIds[0]].distance)
    XCTAssertEqual(1, g[vertex: vIds[1]].distance)
    XCTAssertEqual(2, g[vertex: vIds[2]].distance)
    XCTAssertEqual(3, g[vertex: vIds[3]].distance)
    XCTAssertEqual(15, g[vertex: vIds[4]].distance)
    XCTAssertEqual(11, g[vertex: vIds[5]].distance)
    XCTAssertEqual(Int.max, g[vertex: vIds[6]].distance)
  }

  func testPerThreadMailboxesShortestPathsUserThread() {
    let testPool = TestSequentialThreadPool(maxParallelism: 10)
    runParallelMailboxesTest(testPool)
  }

  func testPerThreadMailboxesShortestPathsPoolThread() {
    var testPool = TestSequentialThreadPool(maxParallelism: 10)
    testPool.currentThreadIndex = 3
    runParallelMailboxesTest(testPool)
  }

  func testPerThreadMailboxesWonkyMessagePatterns() {
    var testPool = TestSequentialThreadPool(maxParallelism: 10)
    let g = makeDistanceGraph()
    let vIds = g.vertices
    ComputeThreadPools.withPool(testPool) {
      let mailboxes = PerThreadMailboxes(for: g, sending: Type<TestMessage>())

      XCTAssertFalse(mailboxes.deliver())
      XCTAssertFalse(mailboxes.deliver())
      mailboxes.withMailbox(for: vIds[3]) { mailbox in
        XCTAssertNil(mailbox.inbox)
        mailbox.send(TestMessage(), to: vIds[2])
      }
      XCTAssert(mailboxes.deliver())
      mailboxes.withMailbox(for: vIds[2]) { mailbox in
        XCTAssertEqual(TestMessage(), mailbox.inbox)
      }
      XCTAssertFalse(mailboxes.deliver())

      testPool.currentThreadIndex = 3
      ComputeThreadPools.withPool(testPool) {
        mailboxes.withMailbox(for: vIds[2]) { mailbox in
          mailbox.send(TestMessage(sum: 1), to: vIds[3])
        }
        mailboxes.withMailbox(for: vIds[1]) { mailbox in
          mailbox.send(TestMessage(sum: 2), to: vIds[3])
        }
      }
      testPool.currentThreadIndex = 1
      ComputeThreadPools.withPool(testPool) {
        mailboxes.withMailbox(for: vIds[0]) { mailbox in
          mailbox.send(TestMessage(sum: 4), to: vIds[3])
        }
      }
      XCTAssert(mailboxes.deliver())
      mailboxes.withMailbox(for: vIds[3]) { mailbox in
        XCTAssertEqual(mailbox.inbox, TestMessage(sum: 7))
      }
    }
  }

  func testPerThreadMailboxesMultiThreaded() {
    // TODO: Don't create a new thread pool in the test.
    let pool = PosixNonBlockingThreadPool(name: "per-thread-mailboxes-multi-threaded")
    ComputeThreadPools.withPool(pool) {
      XCTAssert(ComputeThreadPools.maxParallelism > 1)
      var g = makeDistanceGraph()
      let vIds = g.vertices
      var mailboxes = PerThreadMailboxes(
        for: g,
        sending: Type<DistanceSearchMessage<DistanceGraph.VertexId, Int>>())

      let edgeDistanceMap = InternalEdgePropertyMap(for: g).transform(\.distance)
      XCTAssertEqual(
        6,
        g.computeShortestPaths(
          startingAt: vIds[0],
          distances: edgeDistanceMap,
          effectivelyInfinite: Int.max,
          mailboxes: &mailboxes))

      //  -> v0 -> v1 -> v2    v6 (disconnected)
      // |    '--> v3 <--'
      // '--- v5 <--"--> v4

      XCTAssertEqual(vIds[0], g[vertex: vIds[0]].predecessor)
      XCTAssertEqual(vIds[0], g[vertex: vIds[1]].predecessor)
      XCTAssertEqual(vIds[1], g[vertex: vIds[2]].predecessor)
      XCTAssertEqual(vIds[2], g[vertex: vIds[3]].predecessor)
      XCTAssertEqual(vIds[3], g[vertex: vIds[4]].predecessor)
      XCTAssertEqual(vIds[3], g[vertex: vIds[5]].predecessor)
      XCTAssertEqual(nil, g[vertex: vIds[6]].predecessor)

      XCTAssertEqual(0, g[vertex: vIds[0]].distance)
      XCTAssertEqual(1, g[vertex: vIds[1]].distance)
      XCTAssertEqual(2, g[vertex: vIds[2]].distance)
      XCTAssertEqual(3, g[vertex: vIds[3]].distance)
      XCTAssertEqual(8, g[vertex: vIds[4]].distance)
      XCTAssertEqual(4, g[vertex: vIds[5]].distance)
      XCTAssertEqual(Int.max, g[vertex: vIds[6]].distance)
    }
  }

  func testPerThreadMailboxesDelivery() {
    var testPool = TestSequentialThreadPool(maxParallelism: 10, currentThreadIndex: 3)
    let mailboxes = PerThreadMailboxes<Empty, ReachableGraph>(vertexCount: 5, threadCount: 10)

    ComputeThreadPools.withPool(testPool) {
      mailboxes.withMailbox(for: 3) { mb in mb.send(Empty(), to: 0) }
    }
    testPool.currentThreadIndex = 0
    ComputeThreadPools.withPool(testPool) {
      mailboxes.withMailbox(for: 1) { mb in mb.send(Empty(), to: 4) }
    }
    XCTAssert(mailboxes.deliver())
    XCTAssertFalse(mailboxes.deliver())
  }

  static var allTests = [
    ("testSequentialMessagePropagation", testSequentialMessagePropagation),
    ("testTransitiveClosureSequentialMerging", testTransitiveClosureSequentialMerging),
    ("testParallelBFSSequentialMerging", testParallelBFSSequentialMerging),
    ("testParallelShortestPathSequentialMerging", testParallelShortestPathSequentialMerging),
    (
      "testParallelShortestPathSequentialMergingEarlyStop",
      testParallelShortestPathSequentialMergingEarlyStop
    ),
    (
      "testParallelShortestPathSequentialMergingStopVertex",
      testParallelShortestPathSequentialMergingStopVertex
    ),
    (
      "testPerThreadMailboxesShortestPathsUserThread", testPerThreadMailboxesShortestPathsUserThread
    ),
    (
      "testPerThreadMailboxesShortestPathsPoolThread", testPerThreadMailboxesShortestPathsPoolThread
    ),
    ("testPerThreadMailboxesWonkyMessagePatterns", testPerThreadMailboxesWonkyMessagePatterns),
    ("testPerThreadMailboxesMultiThreaded", testPerThreadMailboxesMultiThreaded),
    ("testPerThreadMailboxesDelivery", testPerThreadMailboxesDelivery),
  ]
}

extension VertexParallelTests {
  func makeSimpleReachabilityGraph() -> ReachableGraph {
    // v0 -> v1 -> v2    v4 (disconnected)
    //  '--> v3 ---^
    var g = ReachableGraph()

    let v0 = g.addVertex(storing: TestReachableVertex(isReachable: true))
    let v1 = g.addVertex()
    let v2 = g.addVertex()
    let v3 = g.addVertex()
    _ = g.addVertex()  // v4

    _ = g.addEdge(from: v0, to: v1)
    _ = g.addEdge(from: v0, to: v3)
    _ = g.addEdge(from: v1, to: v2)
    _ = g.addEdge(from: v3, to: v2)
    return g
  }

  func runReachabilityTest<Mailboxes: MailboxesProtocol>(
    _ g: inout ReachableGraph,
    _ mailboxes: inout Mailboxes
  ) where Mailboxes.Mailbox.Graph == ReachableGraph.ParallelProjection, Mailboxes.Mailbox.Message == SimpleMessage {
    let vIds = g.vertices
    XCTAssert(g[vertex: vIds[0]].isReachable)
    XCTAssertFalse(g[vertex: vIds[1]].isReachable)
    XCTAssertFalse(g[vertex: vIds[2]].isReachable)
    XCTAssertFalse(g[vertex: vIds[3]].isReachable)
    XCTAssertFalse(g[vertex: vIds[4]].isReachable)

    runReachabilityStep(&g, &mailboxes)
    XCTAssert(mailboxes.deliver())

    // No changes after first superstep.
    XCTAssert(g[vertex: vIds[0]].isReachable)
    XCTAssertFalse(g[vertex: vIds[1]].isReachable)
    XCTAssertFalse(g[vertex: vIds[2]].isReachable)
    XCTAssertFalse(g[vertex: vIds[3]].isReachable)
    XCTAssertFalse(g[vertex: vIds[4]].isReachable)

    runReachabilityStep(&g, &mailboxes)
    XCTAssert(mailboxes.deliver())

    // First wave should be reachable.
    XCTAssert(g[vertex: vIds[0]].isReachable)
    XCTAssert(g[vertex: vIds[1]].isReachable)
    XCTAssertFalse(g[vertex: vIds[2]].isReachable)
    XCTAssert(g[vertex: vIds[3]].isReachable)
    XCTAssertFalse(g[vertex: vIds[4]].isReachable)

    runReachabilityStep(&g, &mailboxes)
    XCTAssert(mailboxes.deliver())

    // All should be reachable except disconnected one.
    XCTAssert(g[vertex: vIds[0]].isReachable)
    XCTAssert(g[vertex: vIds[1]].isReachable)
    XCTAssert(g[vertex: vIds[2]].isReachable)
    XCTAssert(g[vertex: vIds[3]].isReachable)
    XCTAssertFalse(g[vertex: vIds[4]].isReachable)
  }

  func runReachabilityStep<Mailboxes: MailboxesProtocol>(
    _ g: inout ReachableGraph,
    _ mailboxes: inout Mailboxes
  ) where Mailboxes.Mailbox.Graph == ReachableGraph.ParallelProjection, Mailboxes.Mailbox.Message == SimpleMessage {
    g.sequentialStep(mailboxes: &mailboxes) { (context, vertex) in
      if let message = context.inbox {
        vertex.isReachable = vertex.isReachable || message.isTransitivelyReachable
      }

      for edge in context.edges {
        let msg = SimpleMessage(isTransitivelyReachable: vertex.isReachable)
        context.send(msg, to: context.destination(of: edge))
      }
    }
  }
}

extension VertexParallelTests {
  func makeDistanceGraph() -> DistanceGraph {
    //  -> v0 -> v1 -> v2    v6 (disconnected)
    // |    '--> v3 <--'
    // '--- v5 <--"--> v4
    var g = DistanceGraph()

    let v0 = g.addVertex()
    let v1 = g.addVertex()
    let v2 = g.addVertex()
    let v3 = g.addVertex()
    let v4 = g.addVertex()
    let v5 = g.addVertex()
    _ = g.addVertex()  // v6

    _ = g.addEdge(from: v0, to: v1)
    _ = g.addEdge(from: v0, to: v3, storing: TestDistanceEdge(10))
    _ = g.addEdge(from: v1, to: v2)
    _ = g.addEdge(from: v2, to: v3)
    _ = g.addEdge(from: v3, to: v4, storing: TestDistanceEdge(5))
    _ = g.addEdge(from: v3, to: v5)
    _ = g.addEdge(from: v5, to: v0)

    return g
  }
}

extension VertexParallelTests {

  fileprivate func runParallelMailboxesTest(_ testPool: TestSequentialThreadPool) {
    ComputeThreadPools.withPool(testPool) {
      var g = makeDistanceGraph()
      var mailboxes = PerThreadMailboxes(
        for: g,
        sending: Type<DistanceSearchMessage<DistanceGraph.VertexId, Int>>())

      let vIds = g.vertices
      let edgeDistanceMap = InternalEdgePropertyMap(for: g).transform(\.distance)
      XCTAssertEqual(
        6,
        g.computeShortestPaths(
          startingAt: vIds[0],
          distances: edgeDistanceMap,
          effectivelyInfinite: Int.max,
          mailboxes: &mailboxes))

      //  -> v0 -> v1 -> v2    v6 (disconnected)
      // |    '--> v3 <--'
      // '--- v5 <--"--> v4

      XCTAssertEqual(vIds[0], g[vertex: vIds[0]].predecessor)
      XCTAssertEqual(vIds[0], g[vertex: vIds[1]].predecessor)
      XCTAssertEqual(vIds[1], g[vertex: vIds[2]].predecessor)
      XCTAssertEqual(vIds[2], g[vertex: vIds[3]].predecessor)
      XCTAssertEqual(vIds[3], g[vertex: vIds[4]].predecessor)
      XCTAssertEqual(vIds[3], g[vertex: vIds[5]].predecessor)
      XCTAssertEqual(nil, g[vertex: vIds[6]].predecessor)

      XCTAssertEqual(0, g[vertex: vIds[0]].distance)
      XCTAssertEqual(1, g[vertex: vIds[1]].distance)
      XCTAssertEqual(2, g[vertex: vIds[2]].distance)
      XCTAssertEqual(3, g[vertex: vIds[3]].distance)
      XCTAssertEqual(8, g[vertex: vIds[4]].distance)
      XCTAssertEqual(4, g[vertex: vIds[5]].distance)
      XCTAssertEqual(Int.max, g[vertex: vIds[6]].distance)
    }
  }
}

fileprivate struct TestMessage: Equatable, MergeableMessage {
  var sum: Int = 0

  mutating func merge(_ other: Self) {
    sum += other.sum
  }
}

/// A test thread pool that doesn't have parallelism, but makes it easy to pretend as if multiple
/// threads are sequentially performing operations.
fileprivate struct TestSequentialThreadPool: ComputeThreadPool {
  /// The amount of parallelism to simulate in this thread pool.
  public let maxParallelism: Int

  /// Set this to define the thread this simulation should be running on.
  public var currentThreadIndex: Int? = nil

  public func dispatch(_ fn: @escaping () -> Void) {
    fn()
  }

  public func join(_ a: () throws -> Void, _ b: () throws -> Void) throws {
    try a()
    try b()
  }

  public func join(_ a: () -> Void, _ b: () -> Void) {
    a()
    b()
  }

  public func parallelFor(n: Int, _ fn: VectorizedParallelForBody) {
    fn(0, n, n)
  }

  public func parallelFor(n: Int, _ fn: ThrowingVectorizedParallelForBody) throws {
    try fn(0, n, n)
  }
}
