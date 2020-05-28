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

// MARK: - Enhanced Hill Climbing Search

extension BidirectionalGraph {

  // TODO: Is this just "inverse" Dijkstra's search on an undirected graph, with a fancy truncating
  // priority queue?
  // TODO: Switch to sorted array?

  /// Returns the `k` approximate nearest neighbors of `query` in `self`.
  public mutating func enhancedHillClimbingSearch<
    Distance: Comparable,
    Seeds: Collection,
    VertexVisitationState: PropertyMap,
    Heap,
    HeapIndexer
  >(
    query: VertexId,
    k: Int,
    seeds: Seeds,
    vertexVisitationState: inout VertexVisitationState,
    workList: GenericPriorityQueue<Distance, VertexId, Heap, HeapIndexer>,  // TODO: Do truncation!
    distanceBetween: (VertexId, VertexId, inout Self) -> Distance
  ) -> [(VertexId, Distance)]
  where
    Seeds.Element == VertexId,
    VertexVisitationState.Graph == Self,
    VertexVisitationState.Key == VertexId,
    VertexVisitationState.Value == VertexColor
  {
    var workList = workList  // Make mutable.
    for seed in seeds {
      workList.push(seed, at: distanceBetween(query, seed, &self))
    }
    while true {
      guard let nearest = workList.top else { fatalError("No items in work list.") }
      if vertexVisitationState.get(nearest, in: self) == .white {
        for e in edges(from: nearest) {
          let neighbor = destination(of: e)
          let distance = distanceBetween(query, neighbor, &self)
          workList.push(neighbor, at: distance)
        }
        for e in edges(to: nearest) {
          let neighbor = source(of: e)
          let distance = distanceBetween(query, neighbor, &self)
          workList.push(neighbor, at: distance)
        }
        vertexVisitationState.set(nearest, in: &self, to: .black)
      } else {
        // We've seen the same nearest vertex, so we're done here!
        workList.heap.sort()
        return workList.prefix(k).map { ($0.payload, $0.priority) }
      }
    }
  }
}

extension BidirectionalGraph where Self: VertexListGraph, VertexId: IdIndexable {
  public mutating func enhancedHillClimbingSearch<Distance: Comparable, Seeds: Collection>(
    query: VertexId,
    k: Int,
    seeds: Seeds,
    distanceBetween: (VertexId, VertexId, inout Self) -> Distance
  ) -> [(VertexId, Distance)]
  where Seeds.Element == VertexId
  {
    var vertexState = TablePropertyMap(repeating: VertexColor.white, forVerticesIn: self)
    let workList = PriorityQueue<VertexId, Distance>()
    return enhancedHillClimbingSearch(
      query: query,
      k: k,
      seeds: seeds,
      vertexVisitationState: &vertexState,
      workList: workList,
      distanceBetween: distanceBetween)
  }
}

// MARK: - Online Approximate k-NN Graph Construction

extension BidirectionalGraph where Self: MutableGraph & VertexListGraph, VertexId: IdIndexable {
  // TODO: Lift requirement of VertexID: IdIndexable
  // TODO: Allow random seed specification.
  public mutating func addApproximateKNearestNeighbors<
    Distance: Comparable,
    RNG: RandomNumberGenerator,
    VertexSimilarities: PropertyMap
  >(
    for vertex: VertexId,
    k: Int,
    rng: inout RNG,
    similarities: inout VertexSimilarities,
    distanceBetween: (VertexId, VertexId, inout Self) -> Distance
  ) -> [(VertexId, Distance)]
  where VertexSimilarities.Graph == Self, VertexSimilarities.Key == EdgeId, VertexSimilarities.Value == Distance {
    let seeds = vertices.randomSelectionWithoutReplacement(k: k, using: &rng)
    let neighbors = enhancedHillClimbingSearch(
      query: vertex,
      k: k,
      seeds: seeds,
      distanceBetween: distanceBetween)
    for (neighbor, distance) in neighbors {
      let edge = addEdge(from: vertex, to: neighbor)
      similarities.set(edge, in: &self, to: distance)
    }
    return neighbors
  }
}

// TODO: Make sure this is actually correct & move to PenguinStructures.
extension Collection {
  fileprivate func randomSelectionWithoutReplacement<Randomness: RandomNumberGenerator>(
    k: Int,
    using randomness: inout Randomness
  ) -> [Element] {
    guard count > k else { return Array(self) }
    var selected = [Element]()
    selected.reserveCapacity(k)
    for (i, elem) in self.enumerated() {
      let remainingToPick = k - selected.count
      let remainingInSelf = count - i
      if randomness.next(upperBound: UInt(remainingInSelf)) < remainingToPick {
        selected.append(elem)
        if selected.count == k { return selected }
      }
    }
    fatalError("Should not have reached here: \(self), \(selected)")
  }
}
