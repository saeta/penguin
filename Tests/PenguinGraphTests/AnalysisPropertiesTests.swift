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
import XCTest

final class AnalysisPropertiesTests: XCTestCase {

  func testDegreeDistributionLollipop() {
    let g = LollipopGraph(m: 100, n: 50)
    let distribution = g.degreeDistribution
    XCTAssertEqual(4, distribution.count)
    XCTAssertEqual([1, 2, 99, 100], Array(distribution.indices))
    XCTAssertEqual(1, distribution.startIndex)
    XCTAssertEqual(101, distribution.endIndex)
    XCTAssertEqual(0, distribution[0])
    XCTAssertEqual(1, distribution[1])
    XCTAssertEqual(49, distribution[2])
    XCTAssertEqual(99, distribution[99])
    XCTAssertEqual(1, distribution[100])

    let sortedByFrequency = distribution.sortedByFrequency
    // Hand-write out because tuples can't conform to protocols.
    XCTAssertEqual(99, sortedByFrequency[0].degree)
    XCTAssertEqual(99, sortedByFrequency[0].frequency)
    XCTAssertEqual(2, sortedByFrequency[1].degree)
    XCTAssertEqual(49, sortedByFrequency[1].frequency)
    XCTAssertEqual(100, sortedByFrequency[2].degree)
    XCTAssertEqual(1, sortedByFrequency[2].frequency)
    XCTAssertEqual(1, sortedByFrequency[3].degree)
    XCTAssertEqual(1, sortedByFrequency[3].frequency)

    XCTAssertEqual(150, distribution.vertexCount)
    XCTAssertEqual(10000, distribution.directedEdgeCount)
  }

  func testDegreeDistributionCircle1() {
    let g = CircleGraph(n: 50, k: 1)
    let distribution = g.degreeDistribution
    XCTAssertEqual([0, 50], distribution.histogram)
    XCTAssertEqual(1, distribution.startIndex)
    XCTAssertEqual(2, distribution.endIndex)
  }

  func testDegreeDistributionCircle5() {
    let g = CircleGraph(n: 100, k: 5)
    XCTAssertEqual([0, 0, 0, 0, 0, 1], g.degreeDistribution.normalizedHistogram)
  }

  func testDegreeDistributionBoundedGrid() {
    let g = RectangularBoundedGrid(x: 0...3, y: 0...3)
    XCTAssertEqual([0, 0, 0, 0.25, 0, 0.5, 0, 0, 0.25], g.degreeDistribution.normalizedHistogram)
    XCTAssertEqual([0, 0, 0, 0.25, 0, 0.5, 0, 0, 0.25], g.inDegreeDistribution.normalizedHistogram)
  }

  func testUndirectedClusteringCoefficientStar() {
    let g = UndirectedStarGraph(n: 20)
    XCTAssertEqual(0, g.undirectedAverageClusteringCoefficient)
  }

  func testUndirectedClusteringCoefficientCircle4() {
    let g = CircleGraph(n: 10, k: 4)
    XCTAssertEqual(0.5, g.undirectedAverageClusteringCoefficient)
  }

  func testUndirectedClusteringCoefficientComplete() {
    let g = CompleteGraph(n: 10).excludingSelfLoops()
    XCTAssertEqual(1, g.undirectedAverageClusteringCoefficient)
  }

  func testClusteringCoefficientComplete() {
    let g = CompleteGraph(n: 10).excludingSelfLoops()
    XCTAssertEqual(1, g.averageClusteringCoefficient)
  }

  func testClusteringCoefficientBoundedGrid() {
    let g = RectangularBoundedGrid(x: 0...3, y: 0...3)
    XCTAssertEqual(0.657142857142857, g.averageClusteringCoefficient)
  }

  func testClusteringCoefficientStar() {
    XCTAssertEqual(0, DirectedStarGraph(n: 10).excludingSelfLoops().averageClusteringCoefficient)
  }

  func testDistanceMetrics() {
    do {
      var g = DirectedStarGraph(n: 10)
      let metrics = g.distanceMetrics
      XCTAssertEqual(0, metrics.diameter)  // TODO: Is this the right semantics?
      XCTAssertEqual(0, metrics.radius)  // TODO: Is this the right semantics?
      XCTAssertEqual(0, metrics.centralVertex)
      XCTAssertEqual(1, metrics.centralVertexCount)
      XCTAssertEqual(1, metrics.peripheralVertexCount)  // TODO: Is this the right semantics?
    }

    do {
      var g = UndirectedStarGraph(n: 10)
      let metrics = g.distanceMetrics
      XCTAssertEqual(1.8, metrics.averagePathLength)
      XCTAssertEqual(2, metrics.diameter)
      XCTAssertEqual(1, metrics.radius)
      XCTAssertEqual(0, metrics.centralVertex)
      XCTAssertEqual(1, metrics.centralVertexCount)
      XCTAssertEqual(9, metrics.peripheralVertexCount)
    }

    do {
      var g = CompleteGraph(n: 5)
      let metrics = g.distanceMetrics
      XCTAssertEqual(1, metrics.averagePathLength)
      XCTAssertEqual(1, metrics.diameter)
      XCTAssertEqual(1, metrics.radius)
      XCTAssertEqual(5, metrics.centralVertexCount)
      XCTAssertEqual(5, metrics.peripheralVertexCount)
    }

    do {
      var g = LollipopGraph(m: 8, n: 4)
      let metrics = g.distanceMetrics
      XCTAssertEqual(5, metrics.diameter)
      XCTAssertEqual(3, metrics.radius)
      XCTAssertEqual(8, metrics.centralVertex)
      XCTAssertEqual(2, metrics.centralVertexCount)
      XCTAssertEqual(0, metrics.peripheralVertex)
      XCTAssertEqual(8, metrics.peripheralVertexCount)
    }

    do {
      var g = RectangularBoundedGrid(x: 0...3, y: 0...3)
      let metrics = g.distanceMetrics
      XCTAssertEqual(3, metrics.diameter)
      XCTAssertEqual(2, metrics.radius)
      XCTAssertEqual(4, metrics.centralVertexCount)
      XCTAssertEqual(.origin, metrics.peripheralVertex)
      XCTAssertEqual(12, metrics.peripheralVertexCount)
    }

    do {
      var g = CircleGraph(n: 10, k: 3)
      let metrics = g.distanceMetrics
      XCTAssertEqual(2, metrics.averagePathLength)
      XCTAssertEqual(3, metrics.diameter)
      XCTAssertEqual(3, metrics.radius)
    }
  }

  static var allTests = [
    ("testDegreeDistributionLollipop", testDegreeDistributionLollipop),
    ("testDegreeDistributionCircle1", testDegreeDistributionCircle1),
    ("testDegreeDistributionCircle5", testDegreeDistributionCircle5),
    ("testDegreeDistributionBoundedGrid", testDegreeDistributionBoundedGrid),
    ("testUndirectedClusteringCoefficientStar", testUndirectedClusteringCoefficientStar),
    ("testUndirectedClusteringCoefficientCircle4", testUndirectedClusteringCoefficientCircle4),
    ("testUndirectedClusteringCoefficientComplete", testUndirectedClusteringCoefficientComplete),
    ("testClusteringCoefficientComplete", testClusteringCoefficientComplete),
    ("testClusteringCoefficientBoundedGrid", testClusteringCoefficientBoundedGrid),
    ("testClusteringCoefficientStar", testClusteringCoefficientStar),
    ("testDistanceMetrics", testDistanceMetrics),
  ]
}
