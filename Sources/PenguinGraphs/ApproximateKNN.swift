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

extension IncidenceGraph where Self: VertexListGraph & MutableGraph {
  /// Adds edges between `vertex` and its `k` nearest neighbors, as determined by `similarityBetween`.
  ///
  /// - Returns: A collection of the `k` nearest neighbors of `vertex` and their computed
  ///   similarities.
  /// - Complexity: O(|V| * O(similarityBetween)), where |V| is the number of vertices in `self`.
  @discardableResult
  public mutating func addKNearestNeighborEdges<Similarity: Comparable>(
    vertex: VertexId,
    k: Int,
    similarityBetween: (VertexId, VertexId, inout Self) -> Similarity)
  -> [(EdgeId, Similarity)] {
    var workList = MaxPriorityQueue<VertexId, Similarity>()  // TODO: do truncation to `k`!
    for u in vertices {
      if u == vertex { continue }
      let Similarity = similarityBetween(vertex, u, &self)
      workList.push(u, at: Similarity)
    }
    var output = [(EdgeId, Similarity)]()
    output.reserveCapacity(k)
    var i = 0
    while i < k {
      i += 1
      let vertexWithSimilarity = workList.pop()!
      let edgeId = addEdge(from: vertex, to: vertexWithSimilarity.payload)
      output.append((edgeId, vertexWithSimilarity.priority))
    }
    return output
  }

  /// Adds edges between all vertices and their `k` nearest neighbors, as determined by
  /// `similarityBetween`.
  ///
  /// - Complexity: O(|V|^2 * O(similarityBetween))
  public mutating func addKNearestNeighborEdges<Similarity: Comparable>(
    k: Int,
    similarityBetween: (VertexId, VertexId, inout Self) -> Similarity
  ) {
    for v in vertices {
      addKNearestNeighborEdges(vertex: v, k: k, similarityBetween: similarityBetween)
    }
  }
}

// MARK: - Enhanced Hill Climbing Search

extension BidirectionalGraph {

  // TODO: Is this just "inverse" Dijkstra's search on an undirected graph, with a fancy truncating
  // priority queue?
  // TODO: Switch to sorted array? Or sorted Deques?

  /// Returns the `k` approximate nearest neighbors of `query` in `self`.
  ///
  /// This algorithm is Algorithm 1 from [k-NN Graph Construction:
  /// a Generic Online Approach](https://arxiv.org/pdf/1804.03032.pdf), by Wan-Lei Zhao
  public mutating func kNNEnhancedHillClimbingSearch<
    Similarity: Comparable,
    Seeds: Collection,
    VertexVisitationState: PropertyMap,
    Heap,
    HeapIndexer
  >(
    query: VertexId,
    k: Int,
    seeds: Seeds,
    vertexVisitationState: inout VertexVisitationState,
    workList: GenericMaxPriorityQueue<Similarity, VertexId, Heap, HeapIndexer>,  // TODO: Do truncation!
    similarityBetween: (VertexId, VertexId, inout Self) -> Similarity
  ) -> [(VertexId, Similarity)]
  where
    Seeds.Element == VertexId,
    VertexVisitationState.Graph == Self,
    VertexVisitationState.Key == VertexId,
    VertexVisitationState.Value == VertexColor
  {
    var workList = workList  // Make mutable.
    for seed in seeds {
      vertexVisitationState.set(seed, in: &self, to: .gray)
      workList.push(seed, at: similarityBetween(query, seed, &self))
    }
    var closestK = [(VertexId, Similarity)]()
    while closestK.count < k {
      guard let nearest = workList.top else { fatalError("No items in work list.") }
      if vertexVisitationState.get(nearest, in: self) == .gray {
        for e in edges(from: nearest) {
          let neighbor = destination(of: e)
          if neighbor == query || vertexVisitationState.get(neighbor, in: self) != .white {
            continue
          }
          vertexVisitationState.set(neighbor, in: &self, to: .gray)
          let similarity = similarityBetween(query, neighbor, &self)
          workList.push(neighbor, at: similarity)
        }
        for e in edges(to: nearest) {
          let neighbor = source(of: e)
          if neighbor == query || vertexVisitationState.get(neighbor, in: self) != .white {
            continue
          }
          vertexVisitationState.set(neighbor, in: &self, to: .gray)
          let similarity = similarityBetween(query, neighbor, &self)
          workList.push(neighbor, at: similarity)
        }
        vertexVisitationState.set(nearest, in: &self, to: .black)
      } else {
        assert(vertexVisitationState.get(nearest, in: self) == .black)
        // We've seen the same nearest vertex, so pop it off.
        let nearest = workList.pop()!
        closestK.append((nearest.payload, nearest.priority))
      }
    }
    return closestK
  }
}

extension BidirectionalGraph where Self: VertexListGraph, VertexId: IdIndexable {
  /// Returns the `k` approximate nearest neighbors of `query` in `self`.
  ///
  /// This algorithm is Algorithm 1 from [k-NN Graph Construction:
  /// a Generic Online Approach](https://arxiv.org/pdf/1804.03032.pdf), by Wan-Lei Zhao
  public mutating func kNNEnhancedHillClimbingSearch<Similarity: Comparable, Seeds: Collection>(
    query: VertexId,
    k: Int,
    seeds: Seeds,
    similarityBetween: (VertexId, VertexId, inout Self) -> Similarity
  ) -> [(VertexId, Similarity)]
  where Seeds.Element == VertexId
  {
    var vertexState = TablePropertyMap(repeating: VertexColor.white, forVerticesIn: self)
    let workList = MaxPriorityQueue<VertexId, Similarity>()
    return kNNEnhancedHillClimbingSearch(
      query: query,
      k: k,
      seeds: seeds,
      vertexVisitationState: &vertexState,
      workList: workList,
      similarityBetween: similarityBetween)
  }
}

// MARK: - Online Approximate k-NN Graph Construction

extension BidirectionalGraph where Self: MutableGraph & VertexListGraph, VertexId: IdIndexable {
  // TODO: Lift requirement of VertexID: IdIndexable

  /// Adds `k` edges to `vertex` corresponding to approximately the `k` nearest neighbors in `self`
  /// according to the similarity function `similarityBetween`; the similarities corresponding to
  /// the `k` edges are stored in `similarities`.
  ///
  /// This algorithm is Algorithm 2 from [k-NN Graph Construction:
  /// a Generic Online Approach](https://arxiv.org/pdf/1804.03032.pdf), by Wan-Lei Zhao
  ///
  /// - Parameter rng: The random number generator to use to select seeds.
  public mutating func kNNInsertApproximateKNearestNeighborEdges<
    Similarity: Comparable,
    RNG: RandomNumberGenerator,
    VertexSimilarities: PropertyMap
  >(
    for vertex: VertexId,
    k: Int,
    rng: inout RNG,
    similarities: inout VertexSimilarities,
    similarityBetween: (VertexId, VertexId, inout Self) -> Similarity
  ) -> [(VertexId, Similarity)]
  where
    VertexSimilarities.Graph == Self,
    VertexSimilarities.Key == EdgeId,
    VertexSimilarities.Value == Similarity
  {
    let seeds = vertices.randomSelectionWithoutReplacement(k: k, using: &rng)
    let neighbors = kNNEnhancedHillClimbingSearch(
      query: vertex,
      k: k,
      seeds: seeds,
      similarityBetween: similarityBetween)
    for (neighbor, similarity) in neighbors {
      let edge = addEdge(from: vertex, to: neighbor)
      similarities.set(edge, in: &self, to: similarity)
    }
    return neighbors
  }

  /// Adds `k` edges to `vertex` corresponding to approximately the `k` nearest neighbors in `self`
  /// according to the similarity function `similarityBetween`; the similarities corresponding to
  /// the `k` edges are stored in `similarities`.
  ///
  /// This algorithm is Algorithm 2 from [k-NN Graph Construction:
  /// a Generic Online Approach](https://arxiv.org/pdf/1804.03032.pdf), by Wan-Lei Zhao
  ///
  /// - Parameter rng: The random number generator to use to select seeds.
  public mutating func kNNInsertApproximateKNearestNeighborEdges<
    Similarity: Comparable,
    VertexSimilarities: PropertyMap
  >(
    for vertex: VertexId,
    k: Int,
    similarities: inout VertexSimilarities,
    similarityBetween: (VertexId, VertexId, inout Self) -> Similarity
  ) -> [(VertexId, Similarity)]
  where
    VertexSimilarities.Graph == Self,
    VertexSimilarities.Key == EdgeId,
    VertexSimilarities.Value == Similarity
  {
    var g = SystemRandomNumberGenerator()
    return kNNInsertApproximateKNearestNeighborEdges(
      for: vertex,
      k: k,
      rng: &g,
      similarities: &similarities,
      similarityBetween: similarityBetween)
  }
}
