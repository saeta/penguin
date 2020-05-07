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

final class ParallelExpanderTests: XCTestCase {

  typealias LabelBundle = SIMDLabelBundle<SIMD3<Float>>
  typealias Graph = AdjacencyList<TestLabeledVertex, Empty, Int32>
  typealias EdgeWeights = DictionaryEdgePropertyMap<Graph, Float>

  func testSimple() {
    var g = Graph()
    let v1 = g.addVertex(with: TestLabeledVertex(seedLabels: [1, 0, 0]))
    let v2 = g.addVertex()
    let v3 = g.addVertex(with: TestLabeledVertex(seedLabels: [0, 1, 0]))

    let e1 = g.addEdge(from: v1, to: v2)
    let e2 = g.addEdge(from: v3, to: v2)
    let e3 = g.addEdge(from: v2, to: v1)
    let e4 = g.addEdge(from: v2, to: v3)

    let propertyMap = EdgeWeights([e1: 0.5, e2: 0.5, e3: 0.1, e4: 0.1])

    var mb1 = PerThreadMailboxes(for: g, sending: IncomingEdgeWeightSumMessage.self)
    g.computeIncomingEdgeWeightSum(using: &mb1, with: propertyMap)

    var mb2 = PerThreadMailboxes(for: g, sending: LabelBundle.self)
    g.propagateLabels(m1: 1.0, m2: 0.01, m3: 0.01, using: &mb2, with: propertyMap, maxStepCount: 10)

    XCTAssertEqual(0.5, g[vertex: v2].computedLabels[0])
    XCTAssertEqual(0.5, g[vertex: v2].computedLabels[1])
  }
  static var allTests = [
    ("testSimple", testSimple),
  ]
}

extension ParallelExpanderTests {
  struct TestLabeledVertex: DefaultInitializable, LabeledVertex {
    var seedLabels: LabelBundle
    var computedLabels = LabelBundle()
    var prior: Float = 0.5
    var totalIncomingEdgeWeight: Float = Float.nan


    public init(seedLabels: [Float]) {
      self.seedLabels = LabelBundle(weights: SIMD3(seedLabels), validWeightsMask: ~.zero)
    }

    public init() {
      self.seedLabels = .init()
    }
  }
}
