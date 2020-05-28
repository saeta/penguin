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

  // TODO: consider adding callbacks in some form, and/or unifying with Dijkstra's / BFS.
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
  ) -> [VertexId]
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
        return workList.prefix(k).map { $0.payload }
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
  ) -> [VertexId]
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
