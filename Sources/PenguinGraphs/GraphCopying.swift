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

extension MutableGraph where Self: DefaultInitializable {

  /// Initializes `self` as a copy of the incidences of `Other`.
  ///
  /// - Complexity: O(|V| + |E|)
  public init<
    Other: IncidenceGraph & VertexListGraph,
    VertexMapping: ExternalPropertyMap
  >(_ other: Other, vertexMapping: inout VertexMapping)
  where
    VertexMapping.Graph == Other,
    VertexMapping.Key == Other.VertexId,
    VertexMapping.Value == VertexId
  {
    self.init()
    reserveCapacity(vertexCount: other.vertexCount)

    // Add all vertices.
    for v in other.vertices {
      let selfId = addVertex()
      vertexMapping[v] = selfId
    }

    // Add all edges.
    for v in other.vertices {
      let src = vertexMapping.get(v, in: other)
      for e in other.edges(from: v) {
        let dst = vertexMapping.get(other.destination(of: e), in: other)
        _ = addEdge(from: src, to: dst)
      }
    }
  }

  /// Initializes `self` as a copy of the incidences of `Other`.
  ///
  /// - Complexity: O(|V| + |E|)
  public init<Other: IncidenceGraph & VertexListGraph & SearchDefaultsGraph>(_ other: Other)
  where Other.VertexId == VertexId
  {
    guard other.vertexCount > 0 else {
      self.init()
      return
    }
    var map = other.makeDefaultVertexVertexMap(repeating: other.vertices.first!)
    self.init(other, vertexMapping: &map)
  }
}

extension MutableGraph where Self: DefaultInitializable, VertexId == Int {
  
  /// Initializes `self` as a copy of the incidences of `Other`.
  ///
  /// - Complexity: O(|V| + |E|)
  public init<Other: IncidenceGraph & VertexListGraph & SearchDefaultsGraph>(_ other: inout Other)
  where Other.VertexId == VertexId
  {
    var map = other.makeDefaultVertexIntMap(repeating: -1)
    self.init(other, vertexMapping: &map)
  }

}

extension MutablePropertyGraph where Self: DefaultInitializable {

  /// Initializes `self` as a copy of the incidences of `other` and storing the properties of
  /// `vertexProperties` and `edgeProperties`.
  public init<
    Other: IncidenceGraph & VertexListGraph,
    VertexMapping: ExternalPropertyMap,
    VertexProperties: PropertyMap,
    EdgeProperties: PropertyMap
  >(
    _ other: Other,
    vertexMapping: inout VertexMapping,
    vertexProperties: VertexProperties,
    edgeProperties: EdgeProperties
  ) where
    VertexMapping.Graph == Other,
    VertexMapping.Key == Other.VertexId,
    VertexMapping.Value == VertexId,
    VertexProperties.Graph == Other,
    VertexProperties.Key == Other.VertexId,
    VertexProperties.Value == Vertex,
    EdgeProperties.Graph == Other,
    EdgeProperties.Key == Other.EdgeId,
    EdgeProperties.Value == Edge
  {
    self.init()
    reserveCapacity(vertexCount: other.vertexCount)

    // Add all vertices.
    for v in other.vertices {
      let selfId = addVertex(storing: vertexProperties.get(v, in: other))
      vertexMapping[v] = selfId
    }

    // Add all edges.
    for v in other.vertices {
      let src = vertexMapping.get(v, in: other)
      for e in other.edges(from: v) {
        let dst = vertexMapping.get(other.destination(of: e), in: other)
        _ = addEdge(from: src, to: dst, storing: edgeProperties.get(e, in: other))
      }
    }
  }

  /// Initializes `self` as a copy of the incidences and properties of `other`.
  ///
  /// - Complexity: O(|V| + |E|)
  public init<
    Other: IncidenceGraph & VertexListGraph & PropertyGraph,
    VertexMapping: ExternalPropertyMap
  >(_ other: Other, vertexMapping: inout VertexMapping)
  where
    VertexMapping.Graph == Other,
    VertexMapping.Key == Other.VertexId,
    VertexMapping.Value == VertexId,
    Other.Vertex == Vertex,
    Other.Edge == Edge
  {
    self.init(
      other,
      vertexMapping: &vertexMapping,
      vertexProperties: InternalVertexPropertyMap(for: other),
      edgeProperties: InternalEdgePropertyMap(for: other))
  }

  /// Initializes `self` as a copy of the incidences and properties of `other`.
  ///
  /// - Complexity: O(|V| + |E|)
  public init<
    Other: IncidenceGraph & VertexListGraph & PropertyGraph & SearchDefaultsGraph
  >(_ other: Other)
  where
    Other.VertexId == VertexId,
    Other.Vertex == Vertex,
    Other.Edge == Edge
  {
    guard !other.vertices.isEmpty else {
      self.init()
      return
    }
    var vertexMapping = other.makeDefaultVertexVertexMap(repeating: other.vertices.first!)
    self.init(
      other,
      vertexMapping: &vertexMapping,
      vertexProperties: InternalVertexPropertyMap(for: other),
      edgeProperties: InternalEdgePropertyMap(for: other))
  }
}

extension IncidenceGraph where Self: MutableGraph {
  /// Adds all edges from `other` into `self`, using `vertexMapper` to map vertices, and calling
  /// `edgeCreationListener` with every new EdgeId.
  public mutating func addEdges<Other: IncidenceGraph & VertexListGraph>(
    from other: Other,
    mappingVertices vertexMapper: (Other, Other.VertexId, Self) -> VertexId,
    _ edgeCreationListener: (EdgeId, inout Self) -> Void = { _, _ in }
  ) {
    for vSrc in other.vertices {
      let v = vertexMapper(other, vSrc, self)
      for e in other.edges(from: vSrc) {
        let d = vertexMapper(other, other.destination(of: e), self)
        let edgeId = addEdge(from: v, to: d)
        edgeCreationListener(edgeId, &self)
      }
    }
  }

  /// Adds all edges from `other` into `self`, and calling `edgeCreationListener` with every new
  /// EdgeId.
  ///
  /// - Precondition: (not checked) all of `other`'s VertexId's must be valid VertexId's in `self`.
  public mutating func addEdges<Other: IncidenceGraph & VertexListGraph>(
    from other: Other,
    _ edgeCreationListener: (EdgeId, inout Self) -> Void = { _, _ in }
  ) where Other.VertexId == VertexId {
    addEdges(from: other, mappingVertices: { _, v, _ in v }, edgeCreationListener)
  }
}

extension IncidenceGraph where Self: MutablePropertyGraph & VertexListGraph {
  /// Adds all edges from `other` into `self`, calling `edgeCreationListener` with every new
  /// `EdgeId`.
  ///
  /// - Precondition: all of `other`'s VertexId's must be valid VertexId's in `self`.
  public mutating func addEdges<Other: IncidenceGraph & PropertyGraph & VertexListGraph>(
    from other: Other,
    _ edgeCreationListener: (EdgeId, inout Self) -> Void = { _, _ in }
  ) where Other.VertexId == VertexId, Other.Edge == Edge {
    addEdges(
      from: other,
      storing: InternalEdgePropertyMap(for: other),
      mappingVertices: { _, v, _ in v },
      edgeCreationListener)
  }

  /// Adds all edges from `other` into `self` storing the corresponding edge property from
  /// `edgeProperties`.
  public mutating func addEdges<
    Other: IncidenceGraph & VertexListGraph,
    EdgeProperties: PropertyMap
  >(
    from other: Other,
    storing edgeProperties: EdgeProperties,
    mappingVertices vertexMapper: (Other, Other.VertexId, Self) -> VertexId,
    _ edgeCreationListener: (EdgeId, inout Self) -> Void = { _, _ in }
  ) where
    Other.VertexId == VertexId,
    EdgeProperties.Graph == Other,
    EdgeProperties.Key == Other.EdgeId,
    EdgeProperties.Value == Edge
  {
    for vSrc in other.vertices {
      let v = vertexMapper(other, vSrc, self)
      for e in other.edges(from: vSrc) {
        let d = vertexMapper(other, other.destination(of: e), self)
        let edgeId = addEdge(
          from: v,
          to: d,
          storing: edgeProperties.get(e, in: other))
        edgeCreationListener(edgeId, &self)
      }
    }
  }
}
