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

extension IncidenceGraph where Self: VertexListGraph {

  /// Computes the [distribution of degrees](https://en.wikipedia.org/wiki/Degree_distribution) of
  /// all vertices in `self`.
  ///
  /// - Complexity: O(|V| + |E|)
  public var degreeDistribution: DegreeDistribution {
    var directedEdgeCount = 0
    var vertexCount = 0
    var smallCounts = [Int](repeating: 0, count: 20)
    var largeCounts = [Int: Int]()

    for v in vertices {
      let degree = outDegree(of: v)
      vertexCount += 1
      directedEdgeCount += degree
      if degree < smallCounts.count {
        smallCounts[degree] += 1
      } else {
        largeCounts[degree, default: 0] += 1
      }
    }

    assert(self.vertexCount == vertexCount)
    return DegreeDistribution(
      directedEdgeCount: directedEdgeCount,
      vertexCount: vertexCount,
      smallCounts: smallCounts,
      largeCounts: largeCounts.sorted { $0.0 < $1.0 })
  }
}

/// A sparse collection of vertex counts, indexed by the integer degree.
public struct DegreeDistribution {
  /// The total number of directed edges in a graph.
  ///
  /// Note: when a DegreeDistribution is computed for an undirected graph, each edge is counted
  /// twice.
  public let directedEdgeCount: Int
  /// The total number of vertices in a graph.
  public let vertexCount: Int

  /// A flat array of small frequency counts.
  internal let smallCounts: [Int]
  /// A sparse representation for outlier vertices.
  internal let largeCounts: [(degree: Int, frequency: Int)]

  internal init(
    directedEdgeCount: Int,
    vertexCount: Int,
    smallCounts: [Int],
    largeCounts: [(Int, Int)]
  ) {
    self.directedEdgeCount = directedEdgeCount
    self.vertexCount = vertexCount
    self.smallCounts = smallCounts
    self.largeCounts = largeCounts
  }
}

extension DegreeDistribution {

  /// An array with values corresponding to the number of vertices with a given degree.
  ///
  /// Beware: This converts from a sparse to a dense representation, which could comsume significant
  /// memory.
  public var histogram: [Int] {
    // TODO: Optimize this implementation!
    var hist = [Int]()
    hist.reserveCapacity(maximumDegree + 1)
    for i in 0..<endIndex {
      hist.append(self[i])
    }
    return hist
  }

  /// An array with values corresponding to the frequency with which a vertex of a given degree
  /// would be selected when vertices are selected at random from the graph.
  ///
  /// Beware: This converts from a sparse to a dense representation, which could comsume significant
  /// memory.
  public var normalizedHistogram: [Double] {
    histogram.map { Double($0) / Double(vertexCount) }
  }

  /// Returns the most frequent degree, and the frequency with which it occurred.
  public var mode: (degree: Int, frequency: Int) {
    var mostFrequent = 0
    var maximumCount = 0
    for i in 0..<smallCounts.count {
      if smallCounts[i] > maximumCount {
        maximumCount = smallCounts[i]
        mostFrequent = i
      }
    }

    for i in 0..<largeCounts.count {
      if largeCounts[i].frequency > maximumCount {
        maximumCount = largeCounts[i].frequency
        mostFrequent = largeCounts[i].degree
      }
    }
    return (mostFrequent, maximumCount)
  }

  /// The maximum degree for any vertex in the graph.
  public var maximumDegree: Int {
    endIndex - 1
  }

  /// Returns the degrees, sorted by their frequency.
  public var sortedByFrequency: [(degree: Int, frequency: Int)] {
    var result = largeCounts
    for i in 0..<smallCounts.count {
      if smallCounts[i] != 0 {
        result.append((i, smallCounts[i]))
      }
    }

    result.sort { $0.1 > $1.1 }
    return result
  }
}

extension DegreeDistribution: Collection {
  /// Accesses the number of vertices encountered with `degree` incident edges.
  public subscript(degree: Int) -> Int {
    if degree < smallCounts.count {
      return smallCounts[degree]
    } else {
      // TODO: use binary search instead of linear search!
      return largeCounts.first { $0.0 == degree }.map { $0.1 } ?? 0
    }
  }

  /// The first valid index in `self`.
  public var startIndex: Int {
    for i in 0..<smallCounts.count {
      if smallCounts[i] != 0 { return i }
    }
    guard let first = largeCounts.first else { return 0 }
    return first.0
  }

  /// Returns one past the last valid index into `self`.
  public var endIndex: Int {
    if largeCounts.isEmpty {
      // One past the end
      return (smallCounts.lastIndex { $0 != 0 } ?? -1) + 1
    } else {
      return largeCounts.last!.0 + 1  // One past the end.
    }
  }

  /// Returns the next valid index after `index`.
  public func index(after index: Int) -> Int {
    if index + 1 < smallCounts.count {
      for i in (index + 1)..<smallCounts.count {
        if smallCounts[i] != 0 { return i }
      }
    }
    // TODO: Consider to binary search?
    for i in 0..<largeCounts.count {
      if largeCounts[i].0 > index {
        return largeCounts[i].0
      }
    }
    return endIndex
  }
}