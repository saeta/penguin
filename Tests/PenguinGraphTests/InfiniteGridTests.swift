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

final class InfiniteGridTests: XCTestCase {

  func testPoint2() {
    XCTAssertEqual(5, Point2(x: 2, y: 3).manhattenDistance)
    XCTAssertEqual(0, Point2.origin.magnitude)
  }

  func testManhattenFilter() {
    let f = ManhattenGridFilter()
    XCTAssert(f.isPartOfGrid(.origin))
    XCTAssert(f.isPartOfGrid(Point2(x: 23, y: -100)))

    XCTAssert(f.isPartOfGrid(GridEdge(source: .origin, direction: .north)))
    XCTAssertFalse(f.isPartOfGrid(GridEdge(source: .origin, direction: .northEast)))
    XCTAssert(f.isPartOfGrid(GridEdge(source: Point2(x: 1, y: -3), direction: .south)))
  }

  func testInfiniteGrid() {
    let g = CompleteInfiniteGrid()

    let pointsAroundOrigin = [
      Point2(x: 1, y: 0),
      Point2(x: 1, y: 1),
      Point2(x: 0, y: 1),
      Point2(x: -1, y: 1),
      Point2(x: -1, y: 0),
      Point2(x: -1, y: -1),
      Point2(x: 0, y: -1),
      Point2(x: 1, y: -1),
    ]

    XCTAssertEqual(
      Set(pointsAroundOrigin),
      Set(g.edges(from: .origin).map { g.destination(of: $0) }))
    for e in g.edges(from: .origin) {
      XCTAssertEqual(.origin, g.source(of: e))
    }

    XCTAssertEqual(
      Set(pointsAroundOrigin),
      Set(g.edges(to: .origin).map { g.source(of: $0) }))
    for e in g.edges(to: .origin) {
      XCTAssertEqual(.origin, g.destination(of: e))
    }
    XCTAssertEqual(8, g.outDegree(of: .origin))
    XCTAssertEqual(8, g.inDegree(of: .origin))
    XCTAssertEqual(16, g.degree(of: .origin))

    let altPoint = Point2(x: -6, y: 21)
    let pointsAroundAltPoint = [
      Point2(x: -5, y: 21),
      Point2(x: -5, y: 22),
      Point2(x: -6, y: 22),
      Point2(x: -7, y: 22),
      Point2(x: -7, y: 21),
      Point2(x: -7, y: 20),
      Point2(x: -6, y: 20),
      Point2(x: -5, y: 20),
    ]

    XCTAssertEqual(
      Set(pointsAroundAltPoint),
      Set(g.edges(from: altPoint).map { g.destination(of: $0) }))
    for e in g.edges(from: altPoint) {
      XCTAssertEqual(altPoint, g.source(of: e))
    }

    XCTAssertEqual(
      Set(pointsAroundAltPoint),
      Set(g.edges(to: altPoint).map { g.source(of: $0) }))
    for e in g.edges(to: altPoint) {
      XCTAssertEqual(altPoint, g.destination(of: e))
    }

    XCTAssertEqual(8, g.outDegree(of: altPoint))
  }

  func testManhattenGrid() {
    let g = CompleteManhattenGrid()

    let pointsAroundOrigin = [
      Point2(x: 1, y: 0),
      Point2(x: 0, y: 1),
      Point2(x: -1, y: 0),
      Point2(x: 0, y: -1),
    ]

    XCTAssertEqual(
      Set(pointsAroundOrigin),
      Set(g.edges(from: .origin).map { g.destination(of: $0) }))
    for e in g.edges(from: .origin) {
      XCTAssertEqual(.origin, g.source(of: e))
    }

    XCTAssertEqual(
      Set(pointsAroundOrigin),
      Set(g.edges(to: .origin).map { g.source(of: $0) }))
    for e in g.edges(to: .origin) {
      XCTAssertEqual(.origin, g.destination(of: e))
    }
    XCTAssertEqual(4, g.outDegree(of: .origin))
    XCTAssertEqual(4, g.inDegree(of: .origin))
    XCTAssertEqual(8, g.degree(of: .origin))

    let altPoint = Point2(x: 8, y: -3)
    let pointsAroundAltPoint = [
      Point2(x: 7, y: -3),
      Point2(x: 8, y: -2),
      Point2(x: 9, y: -3),
      Point2(x: 8, y: -4),
    ]

    XCTAssertEqual(
      Set(pointsAroundAltPoint),
      Set(g.edges(from: altPoint).map { g.destination(of: $0) }))
    for e in g.edges(from: altPoint) {
      XCTAssertEqual(altPoint, g.source(of: e))
    }

    XCTAssertEqual(
      Set(pointsAroundAltPoint),
      Set(g.edges(to: altPoint).map { g.source(of: $0) }))
    for e in g.edges(to: altPoint) {
      XCTAssertEqual(altPoint, g.destination(of: e))
    }

    XCTAssertEqual(4, g.outDegree(of: altPoint))
  }

  func testRectangularBoundedGrid_VertexList() {
    let g = RectangularBoundedGrid(x: -5...5, y: -2...2)
    XCTAssertEqual(Point2(x: -5, y: -2), g.vertices.first!)
    XCTAssertEqual(Point2(x: 5, y: 2), g.vertices.last!)
  }

  func testRectangularBoundedGridBFS() {
    var g = RectangularBoundedGrid(x: -10...10, y: -10...10)
    var predecessors = DictionaryPredecessorRecorder(for: g)
    g.breadthFirstSearch(startingAt: .origin) { e, g in
      predecessors.record(e, graph: g)
    }

    XCTAssertEqual(.origin, predecessors[Point2(x: 1, y: 1)])
    XCTAssertEqual(Point2(x: 1, y: 1), predecessors[Point2(x: 2, y: 2)])
  }

  static var allTests = [
    ("testPoint2", testPoint2),
    ("testManhattenFilter", testManhattenFilter),
    ("testInfiniteGrid", testInfiniteGrid),
    ("testManhattenGrid", testManhattenGrid),
    ("testRectangularBoundedGrid_VertexList", testRectangularBoundedGrid_VertexList),
    ("testRectangularBoundedGridBFS", testRectangularBoundedGridBFS),
  ]
}
