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

import XCTest
import PenguinStructures

final class VertexParallelTests: XCTestCase {

	// MARK: - Reachable test types

	/// A reachable vertex.
	struct TestReachableVertex: DefaultInitializable, ReachableVertex {
		var isReachable: Bool = false
	}

	/// A test reachable message.
	struct SimpleMessage: MergeableMessage {
		var isTransitivelyReachable: Bool

		mutating func merge(with other: Self) {
			self.isTransitivelyReachable =
				self.isTransitivelyReachable || other.isTransitivelyReachable
		}
	}
	typealias ReachableGraph = PropertyAdjacencyList<TestReachableVertex, Empty, Int32>

	// MARK: - Distance test types

	struct TestDistanceEdge: DefaultInitializable {
		public init() { distance = 1 }
		public init(_ distance: Int) { self.distance = distance }
		var distance: Int
	}

	struct TestDistanceVertex: DefaultInitializable, DistanceVertex {
		var distance: Int
		var predecessor: PropertyAdjacencyList<TestDistanceVertex, TestDistanceEdge, Int32>.VertexId?

		public init() {
			distance = Int.max
			predecessor = nil
		}
	}

	typealias DistanceGraph = PropertyAdjacencyList<TestDistanceVertex, TestDistanceEdge, Int32>

	// MARK: - tests

	func testSequentialMessagePropagation() {
		var g = makeSimpleReachabilityGraph()
		var mailboxes = SequentialMailboxes(for: g, sending: SimpleMessage.self)
		runReachabilityTest(&g, &mailboxes)
	}

	func testTransitiveClosureSequentialMerging() {
		var g = makeSimpleReachabilityGraph()
		var mailboxes = SequentialMailboxes(for: g, sending: EmptyMergeableMessage.self)
		XCTAssertEqual(3, g.computeTransitiveClosure(using: &mailboxes))
		let vIds = g.verticies().flatten()
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
			sending: DistanceSearchMessage<DistanceGraph.VertexId, Int>.self)
		let vIds = g.verticies().flatten()

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
			sending: DistanceSearchMessage<DistanceGraph.VertexId, Int>.self)
		let vIds = g.verticies().flatten()

		let edgeDistanceMap = InternalEdgePropertyMap(\TestDistanceEdge.distance, on: g)
		XCTAssertEqual(
			6,
			g.computeShortestPaths(startingAt: vIds[0], with: edgeDistanceMap, using: &mailboxes))

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
			sending: DistanceSearchMessage<DistanceGraph.VertexId, Int>.self)
		let vIds = g.verticies().flatten()

		let edgeDistanceMap = InternalEdgePropertyMap(\TestDistanceEdge.distance, on: g)
		XCTAssertEqual(3, g.computeShortestPaths(
			startingAt: vIds[0],
			with: edgeDistanceMap,
			using: &mailboxes,
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
			sending: DistanceSearchMessage<DistanceGraph.VertexId, Int>.self)
		let vIds = g.verticies().flatten()

		let edgeDistanceMap = InternalEdgePropertyMap(\TestDistanceEdge.distance, on: g)
		XCTAssertEqual(4, g.computeShortestPaths(
			startingAt: vIds[0],
			stoppingAt: vIds[3],
			with: edgeDistanceMap,
			using: &mailboxes))

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
	static var allTests = [
		("testSequentialMessagePropagation", testSequentialMessagePropagation),
		("testTransitiveClosureSequentialMerging", testTransitiveClosureSequentialMerging),
		("testParallelBFSSequentialMerging", testParallelBFSSequentialMerging),
		("testParallelShortestPathSequentialMerging", testParallelShortestPathSequentialMerging),
		("testParallelShortestPathSequentialMergingEarlyStop", testParallelShortestPathSequentialMergingEarlyStop),
		("testParallelShortestPathSequentialMergingStopVertex", testParallelShortestPathSequentialMergingStopVertex),
	]
}

extension VertexParallelTests {
	func makeSimpleReachabilityGraph() -> ReachableGraph {
		// v0 -> v1 -> v2    v4 (disconnected)
		//  '--> v3 ---^
		var g = ReachableGraph()

		let v0 = g.addVertex(with: TestReachableVertex(isReachable: true))
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
	) where Mailboxes.Mailbox.Graph == ReachableGraph, Mailboxes.Mailbox.Message == SimpleMessage {
		let vIds = g.verticies().flatten()
		XCTAssert(g[vertex: vIds[0], \.isReachable])
		XCTAssertFalse(g[vertex: vIds[1], \.isReachable])
		XCTAssertFalse(g[vertex: vIds[2], \.isReachable])
		XCTAssertFalse(g[vertex: vIds[3], \.isReachable])
		XCTAssertFalse(g[vertex: vIds[4], \.isReachable])

		runReachabilityStep(&g, &mailboxes)
		XCTAssert(mailboxes.deliver())

		// No changes after first superstep.
		XCTAssert(g[vertex: vIds[0], \.isReachable])
		XCTAssertFalse(g[vertex: vIds[1], \.isReachable])
		XCTAssertFalse(g[vertex: vIds[2], \.isReachable])
		XCTAssertFalse(g[vertex: vIds[3], \.isReachable])
		XCTAssertFalse(g[vertex: vIds[4], \.isReachable])

		runReachabilityStep(&g, &mailboxes)
		XCTAssert(mailboxes.deliver())

		// First wave should be reachable.
		XCTAssert(g[vertex: vIds[0], \.isReachable])
		XCTAssert(g[vertex: vIds[1], \.isReachable])
		XCTAssertFalse(g[vertex: vIds[2], \.isReachable])
		XCTAssert(g[vertex: vIds[3], \.isReachable])
		XCTAssertFalse(g[vertex: vIds[4], \.isReachable])

		runReachabilityStep(&g, &mailboxes)
		XCTAssert(mailboxes.deliver())

		// All should be reachable except disconnected one.
		XCTAssert(g[vertex: vIds[0], \.isReachable])
		XCTAssert(g[vertex: vIds[1], \.isReachable])
		XCTAssert(g[vertex: vIds[2], \.isReachable])
		XCTAssert(g[vertex: vIds[3], \.isReachable])
		XCTAssertFalse(g[vertex: vIds[4], \.isReachable])
	}

	func runReachabilityStep<Mailboxes: MailboxesProtocol>(
		_ g: inout ReachableGraph,
		_ mailboxes: inout Mailboxes
	) where Mailboxes.Mailbox.Graph == ReachableGraph, Mailboxes.Mailbox.Message == SimpleMessage {
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
		_ = g.addEdge(from: v0, to: v3, with: TestDistanceEdge(10))
		_ = g.addEdge(from: v1, to: v2)
		_ = g.addEdge(from: v2, to: v3)
		_ = g.addEdge(from: v3, to: v4, with: TestDistanceEdge(5))
		_ = g.addEdge(from: v3, to: v5)
		_ = g.addEdge(from: v5, to: v0)

		return g
	}
}
