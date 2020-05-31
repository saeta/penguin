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

final class InternalPropertyMapTests: XCTestCase {

  typealias Graph = DirectedAdjacencyList<ColoredNode, WeightedEdge, Int32>

  enum TestColor {
    case white
    case gray
    case black
  }

  struct ColoredNode: DefaultInitializable {
    var color: TestColor
    init() { color = .white }
    init(_ color: TestColor) { self.color = color }
  }

  struct WeightedEdge: DefaultInitializable {
    var weight: Double
    init() { weight = 0 }
    init(_ weight: Double) { self.weight = weight }
  }

  func testSimpleVertexProperty() {
    var g = Graph()
    let v1 = g.addVertex(storing: ColoredNode(.gray))
    let v2 = g.addVertex(storing: ColoredNode(.black))
    let v3 = g.addVertex()

    let map = InternalVertexPropertyMap(for: g).transform(\.color)

    XCTAssertEqual(.gray, map.get(v1, in: g))
    XCTAssertEqual(.white, map.get(v3, in: g))
    XCTAssertEqual(.black, map.get(v2, in: g))
  }

  func testSimpleEdgeProperty() {
    var g = Graph()
    let v1 = g.addVertex()
    let v2 = g.addVertex()
    let v3 = g.addVertex()

    let e1 = g.addEdge(from: v1, to: v2, storing: WeightedEdge(1))
    let e2 = g.addEdge(from: v2, to: v3, storing: WeightedEdge(2))
    let e3 = g.addEdge(from: v3, to: v1, storing: WeightedEdge(3))

    let map = InternalEdgePropertyMap(for: g).transform(\.weight)

    XCTAssertEqual(3, map.get(e3, in: g))
    XCTAssertEqual(2, map.get(e2, in: g))
    XCTAssertEqual(1, map.get(e1, in: g))
  }
  static var allTests = [
    ("testSimpleVertexProperty", testSimpleVertexProperty),
    ("testSimpleEdgeProperty", testSimpleEdgeProperty),
  ]
}
