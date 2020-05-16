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

extension IncidenceGraph where Self: VertexListGraph, VertexId: IdIndexable {

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
    Components: MutableGraphVertexPropertyMap,
    DiscoverTime: MutableGraphVertexPropertyMap,
    Roots: MutableGraphVertexPropertyMap
  >(
    components: inout Components,
    discoverTime: inout DiscoverTime,
    roots: inout Roots
  ) -> ComponentType
  where
    Components.Graph == Self,
    Components.Value == ComponentType,
    DiscoverTime.Graph == Self,
    DiscoverTime.Value == TimeType,
    Roots.Graph == Self,
    Roots.Value == Self.VertexId
  {
    // Tarjan's algorithm.
    var dfsTime: TimeType = 0
    var componentCounter: ComponentType = 0
    var stack = [VertexId]()
    depthFirstTraversal { event, graph in
      if case .discover(let v) = event {
        // Initialize counter state when we first encounter a vertex.
        components.set(vertex: v, in: &graph, to: ComponentType.max)
        discoverTime.set(vertex: v, in: &graph, to: dfsTime)
        roots.set(vertex: v, in: &graph, to: v)
        dfsTime += 1
        stack.append(v)
      } else if case .finish(let v) = event {
        func earlierDiscoveredVertex(_ u: VertexId, _ v: VertexId) -> VertexId {
          return discoverTime.get(graph, u) < discoverTime.get(graph, v) ? u : v
        }

        for edge in graph.edges(from: v) {
          let w = graph.destination(of: edge)
          if components.get(graph, w) == ComponentType.max {
            roots.set(
              vertex: v,
              in: &graph,
              to: earlierDiscoveredVertex(roots.get(graph, v), roots.get(graph, w)))
          }
        }

        if roots.get(graph, v) == v {
          // Pop off the stack and set the component!
          while true {
            let w = stack.popLast()!
            components.set(vertex: w, in: &graph, to: componentCounter)
            roots.set(vertex: w, in: &graph, to: v)
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
  public mutating func strongComponents<Components: MutableGraphVertexPropertyMap>(
    components: inout Components
  ) -> Components.Value where Components.Graph == Self, Components.Value: FixedWidthInteger {
    if vertexCount == 0 { return 0 }  // No strong components.
    var discoverTime = TableVertexPropertyMap(repeating: 0, for: self)
    var roots = TableVertexPropertyMap(repeating: vertices.first!, for: self) // Init w/dummy value.
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
  public mutating func strongComponents() -> (components: TableVertexPropertyMap<Self, Int>, componentCount: Int) {
    var components = TableVertexPropertyMap(repeating: -1, for: self)
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
    var components = TableVertexPropertyMap(repeating: -1, for: self)
    return strongComponents(components: &components)
  }

}
