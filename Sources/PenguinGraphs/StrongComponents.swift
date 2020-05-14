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
    var visitor = StrongComponentsVisitor(components: components, discoverTime: discoverTime, roots: roots)
    try! depthFirstTraversal(visitor: &visitor)
    components = visitor.components
    discoverTime = visitor.discoverTime
    roots = visitor.roots
    return visitor.componentCounter
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

/// Implements Tarjan's algorithm for computing strong components in concert with
/// depthFirstTraversal.
private struct StrongComponentsVisitor<
  Graph: IncidenceGraph,
  ComponentType: FixedWidthInteger,
  TimeType: FixedWidthInteger,
  Components: MutableGraphVertexPropertyMap,
  DiscoverTime: MutableGraphVertexPropertyMap,
  Roots: MutableGraphVertexPropertyMap
>: DFSVisitor
where
  Components.Graph == Graph,
  Components.Value == ComponentType,
  DiscoverTime.Graph == Graph,
  DiscoverTime.Value == TimeType,
  Roots.Graph == Graph,
  Roots.Value == Graph.VertexId
{
  var dfsTime = TimeType()  // Initialized to 0.
  var componentCounter = ComponentType()
  var components: Components
  var discoverTime: DiscoverTime
  var roots: Roots
  var stack = [Graph.VertexId]()  // TODO: consider being generic over the stack?

  mutating func discover(vertex: Graph.VertexId, _ graph: inout Graph) {
    components.set(vertex: vertex, in: &graph, to: ComponentType.max)
    discoverTime.set(vertex: vertex, in: &graph, to: dfsTime)
    roots.set(vertex: vertex, in: &graph, to: vertex)
    dfsTime += 1
    stack.append(vertex)
  }

  mutating func finish(vertex: Graph.VertexId, _ graph: inout Graph) {
    func earlierDiscoveredVertex(_ u: Graph.VertexId, _ v: Graph.VertexId) -> Graph.VertexId {
      return discoverTime.get(graph, u) < discoverTime.get(graph, v) ? u : v
    }

    for edge in graph.edges(from: vertex) {
      let w = graph.destination(of: edge)
      if components.get(graph, w) == ComponentType.max {
        roots.set(
          vertex: vertex,
          in: &graph,
          to: earlierDiscoveredVertex(roots.get(graph, vertex), roots.get(graph, w)))
      }
    }

    if roots.get(graph, vertex) == vertex {
      // Pop off the stack and set the component!
      while true {
        let w = stack.popLast()!
        components.set(vertex: w, in: &graph, to: componentCounter)
        roots.set(vertex: w, in: &graph, to: vertex)
        if vertex == w {
          break
        }
      }
      componentCounter += 1
    }
  }
}
