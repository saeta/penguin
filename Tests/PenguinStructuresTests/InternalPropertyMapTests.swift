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
import XCTest

final class InternalPropertyMapTests: XCTestCase {

  typealias Graph = AdjacencyList<ColoredNode, WeightedEdge, Int32>

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
    let v1 = g.addVertex(with: ColoredNode(.gray))
    let v2 = g.addVertex(with: ColoredNode(.black))
    let v3 = g.addVertex()

    let map = InternalVertexPropertyMap(\ColoredNode.color, on: g)

    XCTAssertEqual(.gray, map.get(g, v1))
    XCTAssertEqual(.white, map.get(g, v3))
    XCTAssertEqual(.black, map.get(g, v2))
  }

  func testSimpleEdgeProperty() {
    var g = Graph()
    let v1 = g.addVertex()
    let v2 = g.addVertex()
    let v3 = g.addVertex()

    let e1 = g.addEdge(from: v1, to: v2, with: WeightedEdge(1))
    let e2 = g.addEdge(from: v2, to: v3, with: WeightedEdge(2))
    let e3 = g.addEdge(from: v3, to: v1, with: WeightedEdge(3))

    let map = InternalEdgePropertyMap(\WeightedEdge.weight, on: g)

    XCTAssertEqual(3, map.get(g, e3))
    XCTAssertEqual(2, map.get(g, e2))
    XCTAssertEqual(1, map.get(g, e1))
  }
  static var allTests = [
    ("testSimpleVertexProperty", testSimpleVertexProperty),
    ("testSimpleEdgeProperty", testSimpleEdgeProperty),
  ]
}
