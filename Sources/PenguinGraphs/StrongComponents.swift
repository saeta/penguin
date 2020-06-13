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

extension IncidenceGraph where Self: VertexListGraph & SearchDefaultsGraph, VertexId: IdIndexable {

  /// Computes the [strongly connected
  /// components](https://en.wikipedia.org/wiki/Strongly_connected_component) of `self`.
  ///
  /// A strongly connected component is a subset of vertices within a directed graph such that every
  /// vertex is reachable from every other vertex in the subset.
  ///
  /// - Returns: the number of strong components in `self`.
  public mutating func strongComponents<
    ComponentType: FixedWidthInteger,
    TimeType: FixedWidthInteger,
    Components: PropertyMap,
    DiscoverTime: PropertyMap,
    Roots: PropertyMap
  >(
    components: inout Components,
    discoverTime: inout DiscoverTime,
    roots: inout Roots
  ) -> ComponentType
  where
    Components.Graph == Self,
    Components.Key == VertexId,
    Components.Value == ComponentType,
    DiscoverTime.Graph == Self,
    DiscoverTime.Key == VertexId,
    DiscoverTime.Value == TimeType,
    Roots.Graph == Self,
    Roots.Key == VertexId,
    Roots.Value == Self.VertexId
  {
    // Tarjan's algorithm.
    var dfsTime: TimeType = 0
    var componentCounter: ComponentType = 0
    var stack = [VertexId]()
    depthFirstTraversal { event, graph in
      if case .discover(let v) = event {
        // Initialize counter state when we first encounter a vertex.
        components.set(v, in: &graph, to: ComponentType.max)
        discoverTime.set(v, in: &graph, to: dfsTime)
        roots.set(v, in: &graph, to: v)
        dfsTime += 1
        stack.append(v)
      } else if case .finish(let v) = event {
        func earlierDiscoveredVertex(_ u: VertexId, _ v: VertexId) -> VertexId {
          return discoverTime.get(u, in: graph) < discoverTime.get(v, in: graph) ? u : v
        }

        for edge in graph.edges(from: v) {
          let w = graph.destination(of: edge)
          if components.get(w, in: graph) == ComponentType.max {
            roots.set(v, in: &graph,
              to: earlierDiscoveredVertex(roots.get(v, in: graph), roots.get(w, in: graph)))
          }
        }

        if roots.get(v, in: graph) == v {
          // Pop off the stack and set the component!
          while true {
            let w = stack.popLast()!
            components.set(w, in: &graph, to: componentCounter)
            roots.set(w, in: &graph, to: v)
            if v == w {
              break
            }
          }
          componentCounter += 1
        }        
      }
    }
    return componentCounter
  }

  /// Computes the [strongly connected
  /// components](https://en.wikipedia.org/wiki/Strongly_connected_component) of `self`; once done
  /// `components` will classify each vertex into a numbered strong component.
  ///
  /// A strongly connected component is a subset of vertices within a directed graph such that every
  /// vertex is reachable from every other vertex in the subset. The computed numbering of strong
  /// components corresponds to a reverse topological sort of the graph of strong components.
  ///
  /// - Returns: the number of strong components in `self`.
  public mutating func strongComponents<Components: PropertyMap>(
    components: inout Components
  ) -> Components.Value
  where
    Components.Graph == Self,
    Components.Key == VertexId,
    Components.Value: FixedWidthInteger
  {
    if vertexCount == 0 { return 0 }  // No strong components.
    var discoverTime = TablePropertyMap(repeating: 0, forVerticesIn: self)
    var roots = TablePropertyMap(repeating: vertices.first!, forVerticesIn: self) // Init w/dummy value.
    return strongComponents(
      components: &components,
      discoverTime: &discoverTime,
      roots: &roots)
  }

  /// Computes the [strongly connected
  /// components](https://en.wikipedia.org/wiki/Strongly_connected_component) of `self`.
  ///
  /// A strongly connected component is a subset of vertices within a directed graph such that every
  /// vertex is reachable from every other vertex in the subset.
  ///
  /// - Returns: a table mapping each vertex to a number corresponding to a strong component, and
  ///   the number of strong components in `self`.
  public mutating func strongComponents() -> (components: TablePropertyMap<Self, VertexId, Int>, componentCount: Int) {
    var components = TablePropertyMap(repeating: -1, forVerticesIn: self)
    let count = strongComponents(components: &components)
    return (components, count)
  }

  /// Computes the number of [strongly connected
  /// components](https://en.wikipedia.org/wiki/Strongly_connected_component) of `self`.
  ///
  /// A strongly connected component is a subset of vertices within a directed graph such that every
  /// vertex is reachable from every other vertex in the subset.
  ///
  /// - Returns: the number of strong components in `self`.
  public mutating func strongComponentsCount() -> Int {
    var components = TablePropertyMap(repeating: -1, forVerticesIn: self)
    return strongComponents(components: &components)
  }

}
