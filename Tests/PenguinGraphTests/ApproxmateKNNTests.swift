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

final class ApproxmateKNNTests: XCTestCase {

  fileprivate typealias Graph = BidirectionalAdjacencyList<Point2, Empty, UInt32>

  func testSimple() {
    var g = Graph()
    // Create a 10x10 grid with points on every integer multiple of 2.
    for i in 0...5 {
      for j in 0...5 {
        _ = g.addVertex(storing: Point2(Float(i * 2), Float(j * 2)))
      }
    }

    // Fill in all nearest 4 neighbors for every vertex.
    g.addKNearestNeighborEdges(k: 4) { u, v, g in
      -euclideanDistance(g[vertex: u], g[vertex: v])
    }

    // If we pick a vertex in the middle of the graph, it should be connected to its 4 cardinal
    // neighbors.
    do {
      let v = g[vertex: 16]
      let expectedNeighbors = [
        Point2(v.x - 2, v.y),
        Point2(v.x + 2, v.y),
        Point2(v.x, v.y - 2),
        Point2(v.x, v.y + 2),
      ]
      XCTAssertEqual(Set(expectedNeighbors), Set(g.edges(from: 16).map { edge in
        g[vertex: g.destination(of: edge)]
      }))
    }

    let q = g.addVertex(storing: Point2(1, 1))
    // Compute neighbors, starting from 3 farthest corners.
    let neighbors = g.kNNEnhancedHillClimbingSearch(query: q, k: 4, seeds: [35, 5, 30]) { u, v, g in
      -euclideanDistance(g[vertex: u], g[vertex: v])
    }
    XCTAssertEqual(4, neighbors.count)
    let expectedNeighbors = [
      Point2(0, 0),
      Point2(0, 2),
      Point2(2, 0),
      Point2(2, 2),
    ]
    XCTAssertEqual(Set(expectedNeighbors), Set(neighbors.map { g[vertex: $0.0] }))
  }

  func testNoEarlyStopping() {
    var g = Graph()
    // Create a 10x10 grid with points on every integer multiple of 2.
    for i in 0...5 {
      for j in 0...5 {
        _ = g.addVertex(storing: Point2(Float(i * 2), Float(j * 2)))
      }
    }

    // Fill all nearest 4 neighbors for every vertex.
    g.addKNearestNeighborEdges(k: 4) { u, v, g in
      -euclideanDistance(g[vertex: u], g[vertex: v])
    }

    let q = g.addVertex(storing: Point2(11, 11))
    let neighbors = g.kNNEnhancedHillClimbingSearch(query: q, k: 4, seeds: [0, 35, 1]) { u, v, g in
      -euclideanDistance(g[vertex: u], g[vertex: v])
    }
    let expectedNeighbors = [
      Point2(10, 10),
      Point2(10, 8),
      Point2(8, 10),
      Point2(8, 8),
    ]
    XCTAssertEqual(Set(expectedNeighbors), Set(neighbors.map { g[vertex: $0.0] }))
  }

  func testLessThanK() {
    var g = Graph()
    _ = g.addVertex()
    _ = g.addVertex()

    g.addKNearestNeighborEdges(k: 4) { u, v, g in
      2
    }

    let q = g.addVertex()
    let neighbors = g.kNNEnhancedHillClimbingSearch(query: q, k: 4, seeds: [0, 1]) { u, v, g in
      3
    }

    XCTAssertEqual(Set([0, 1]), Set(neighbors.map { $0.0 }))
  }

  static var allTests = [
    ("testSimple", testSimple),
    ("testNoEarlyStopping", testNoEarlyStopping),
    ("testLessThanK", testLessThanK),
  ]
}

fileprivate struct Point2: DefaultInitializable, Hashable, CustomStringConvertible {
  var x, y: Float

  init() {
    x = 0
    y = 0
  }

  init(_ x: Float, _ y: Float) {
    self.x = x
    self.y = y
  }

  public var description: String { "(\(x), \(y))" }
}

fileprivate func euclideanDistance(_ lhs: Point2, _ rhs: Point2) -> Float {
  let a = lhs.x - rhs.x
  let b = lhs.y - rhs.y
  let distance = sqrt(Float(a * a) + Float(b * b))
  return distance
}
