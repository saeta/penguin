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
import PenguinStructures
import XCTest

final class StrongComponentsTests: XCTestCase {
  typealias Graph = SimpleAdjacencyList

  func testSimple() throws {
    // v0 -> v1 -> v2 -,
    //        ^-- v3 <-'
    var g = Graph()
    let v0 = g.addVertex()
    let v1 = g.addVertex()
    let v2 = g.addVertex()
    let v3 = g.addVertex()
    _ = g.addEdge(from: v0, to: v1)
    _ = g.addEdge(from: v1, to: v2)
    _ = g.addEdge(from: v2, to: v3)
    _ = g.addEdge(from: v3, to: v1)

    let (components, componentCount) = g.strongComponents()

    XCTAssertEqual(2, componentCount)
    XCTAssertEqual([1, 0, 0, 0], components.values)
  }

  func testManyComponents() {
    // Graph based on https://en.wikipedia.org/wiki/File:Tarjan%27s_Algorithm_Animation.gif
    var g = Graph()
    for _ in 0..<8 {
      _ = g.addVertex()
    }

    // Add 14 edges
    _ = g.addEdge(from: 0, to: 1)
    _ = g.addEdge(from: 1, to: 2)
    _ = g.addEdge(from: 2, to: 0)

    _ = g.addEdge(from: 3, to: 1)
    _ = g.addEdge(from: 3, to: 2)
    _ = g.addEdge(from: 3, to: 4)
    _ = g.addEdge(from: 4, to: 3)
    _ = g.addEdge(from: 4, to: 5)

    _ = g.addEdge(from: 5, to: 2)
    _ = g.addEdge(from: 5, to: 6)
    _ = g.addEdge(from: 6, to: 5)

    _ = g.addEdge(from: 7, to: 4)
    _ = g.addEdge(from: 7, to: 6)
    _ = g.addEdge(from: 7, to: 7)

    XCTAssertEqual(14, g.edges.count)

    let (components, componentCount) = g.strongComponents()

    XCTAssertEqual(4, componentCount)
    XCTAssertEqual([0, 0, 0, 2, 2, 1, 1, 3], components.values)
  }

  func testDisconnected() {
    var g = Graph()
    for _ in 0..<4 {
      _ = g.addVertex()
    }

    let (components, componentCount) = g.strongComponents()

    XCTAssertEqual(4, componentCount)
    XCTAssertEqual(Array(0..<4), components.values)
  }

  func testPatternedGraphs() {
    do {
      var g = DirectedStarGraph(n: 5)
      XCTAssertEqual(5, g.strongComponentsCount())
      XCTAssertFalse(g.isStronglyConnected)
    }
    do {
      var g = UndirectedStarGraph(n: 7)
      XCTAssertEqual(1, g.strongComponentsCount())
      XCTAssert(g.isStronglyConnected)
    }
    do {
      var g = CompleteGraph(n: 10)
      XCTAssertEqual(1, g.strongComponentsCount())
      XCTAssert(g.isStronglyConnected)
    }
  }

  static var allTests = [
    ("testSimple", testSimple),
    ("testManyComponents", testManyComponents),
    ("testDisconnected", testDisconnected),
    ("testPatternedGraphs", testPatternedGraphs),
  ]
}
