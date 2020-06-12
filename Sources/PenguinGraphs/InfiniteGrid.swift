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

/// Allows selective removing parts of an InfiniteGrid.
///
/// Say a robot is planning movement within a room. There are some furnature items that the robot
/// cannot pass through. An `InfiniteGrid` can be parameterized by a `GridFilter` that excludes the
/// furnature and all vertices beyond the room, yielding a representation of the room that can be
/// searched with graph search algorithms such as A-star search.
///
/// - SeeAlso: `InfiniteGrid`.
public protocol GridFilter {
  /// Returns `true` iff `vertex` should be considered part of the grid.
  func isPartOfGrid(_ vertex: Point2) -> Bool

  /// Returns `true` iff `edge` should be considered part of the grid.
  func isPartOfGrid(_ edge: GridEdge) -> Bool
}

/// Performs no filtering on the complete grid, resulting in an infinite grid with no edges or
/// vertices removed.
public struct CompleteGridFilter: GridFilter, DefaultInitializable {
  /// Creates a CompleteGridFilter
  public init() {}

  /// Returns `true` iff `vertex` should be considered part of the grid.  
  public func isPartOfGrid(_ vertex: Point2) -> Bool { true }
  /// Returns `true` iff `edge` should be considered part of the grid.
  public func isPartOfGrid(_ edge: GridEdge) -> Bool { true }
}

public struct ManhattenGridFilter: GridFilter, DefaultInitializable {
  /// Creates a ManhattenGridFilter
  public init() {}

  /// Returns `true` iff `vertex` should be considered part of the grid.  
  public func isPartOfGrid(_ vertex: Point2) -> Bool { true }
  /// Returns `true` iff `edge` should be considered part of the grid.
  public func isPartOfGrid(_ edge: GridEdge) -> Bool { edge.direction.isCardinal }
}

// TODO: Consider composing filters using `Tuple`'s. (Or building combinators like intersection.)

/// A point in 2 dimensional grid.
public struct Point2: Equatable, Hashable, Comparable {
  /// The x coordinate of the point.
  public var x: Int

  /// The y coordinate of the point.
  public var y: Int

  /// Creates a Point2 at the given location.
  public init(x: Int, y: Int) {
    self.x = x
    self.y = y
  }

  /// The Euclidean distance from the origin to `self`.
  public var magnitude: Double {
    (Double(x * x) + Double(y * y)).squareRoot()
  }

  /// The number of steps on the shortest path that excluding diagonals from the origin to `self`.
  public var manhattenDistance: Int {
    abs(x) + abs(y)
  }

  /// Adds `rhs` into `lhs`.
  public static func += (lhs: inout Self, rhs: Self) {
    lhs.x += rhs.x
    lhs.y += rhs.y
  }

  /// Returns a new coordinate that is the vector sum of `lhs` and `rhs`.
  public static func + (lhs: Self, rhs: Self) -> Self {
    var tmp = lhs
    tmp += rhs
    return tmp
  }

  /// Arbitrary ordering of points.
  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.x == rhs.x ? lhs.y < rhs.y : lhs.x < rhs.x
  }

  /// Returns a point that if added to `rhx` would yield the Point2(x: 0, y: 0).
  public static prefix func - (rhs: Self) -> Self {
    return Point2(x: -rhs.x, y: -rhs.y)
  }

  public static func -= (lhs: inout Self, rhs: Self) {
    lhs.x -= rhs.x
    lhs.y -= rhs.y
  }

  public static func - (lhs: Self, rhs: Self) -> Self {
    var tmp = lhs
    tmp -= rhs
    return tmp
  }

  /// The point corresponding to (0, 0).
  public static var origin: Self { Self(x: 0, y: 0) }
}

/// Available movement directions on the grid.
public enum GridDirection: CaseIterable, Equatable, Hashable, Comparable {
  // MARK: - Cardinal directions

  case north
  case east
  case south
  case west

  // MARK: - Diagonal directions

  case northEast
  case southEast
  case southWest
  case northWest

  /// true if `self` is a cardinal direction; false otherwise.
  public var isCardinal: Bool {
    switch self {
    case .north: return true
    case .east: return true
    case .south: return true
    case .west: return true
    default: return false
    }
  }

  /// true iff `self` is a diagonal direction; false otherwise.
  public var isDiagonal: Bool { !isCardinal }

  /// A vector representing the direction of movement for a given direction.
  public var coordinateDelta: Point2 {
    switch self {
    case .north: return Point2(x: 0, y: 1)
    case .east: return Point2(x: 1, y: 0)
    case .south: return Point2(x: 0, y: -1)
    case .west: return Point2(x: -1, y: 0)
    case .northEast: return Self.north.coordinateDelta + Self.east.coordinateDelta
    case .southEast: return Self.south.coordinateDelta + Self.east.coordinateDelta
    case .southWest: return Self.south.coordinateDelta + Self.west.coordinateDelta
    case .northWest: return Self.north.coordinateDelta + Self.west.coordinateDelta
    }
  }

  /// Returns the opposite direction of `rhs`.
  public static prefix func - (rhs: Self) -> Self {
    switch rhs {
    case .north: return .south
    case .east: return .west
    case .south: return .north
    case .west: return .east
    case .northEast: return .southWest
    case .southEast: return .northWest
    case .southWest: return .northEast
    case .northWest: return .southEast
    }
  }
}


/// The name of an edge in `self`.
public struct GridEdge: Equatable, Hashable, Comparable {
  /// The source of the edge.
  public let source: Point2

  /// The direction of movement from `source` to reach the destination.
  public let direction: GridDirection

  /// The destination of `self`.
  public var destination: Point2 {
    source + direction.coordinateDelta
  }

  /// Arbitrary, stable ordering of `Self`s.
  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.source != rhs.source ? lhs.source < rhs.source : lhs.direction < rhs.direction
  }
}

/// An infinite grid with no missing edges or vertices.
public typealias CompleteInfiniteGrid = InfiniteGrid<CompleteGridFilter>

/// An infinite grid with no missing vertices and only edges in cardinal directions.
public typealias CompleteManhattenGrid = InfiniteGrid<ManhattenGridFilter>

/// A graph of two dimensional coordinates and their local connections.
public struct InfiniteGrid<Filter: GridFilter>: GraphProtocol {
  /// Filters the infinite grid.
  private let filter: Filter

  public init(_ filter: Filter) {
    self.filter = filter
  }

  /// Name of a vertex in `self`.
  public typealias VertexId = Point2

  /// Name of an edge in `self`.
  public typealias EdgeId = GridEdge
}

extension InfiniteGrid: DefaultInitializable where Filter: DefaultInitializable {
  /// Creates an infinite grid with a default initialized filter.
  public init() {
    self.filter = Filter()
  }
}

extension InfiniteGrid: IncidenceGraph {
  /// The collection of edges from a single vertex in an infinite grid.
  public struct VertexEdgeCollection: Collection {
    /// The index into the collection.
    public typealias Index = GridDirection.AllCases.Index
    /// The elements of the collection.
    public typealias Element = GridEdge

    /// A filter of edges & vertices.
    let filter: Filter
    /// The source vertex of all edges.
    let source: Point2

    /// The first valid index in `self`.
    public var startIndex: Index {
      if !filter.isPartOfGrid(source) { return endIndex }
      for i in GridDirection.allCases.indices {
        let direction = GridDirection.allCases[i]
        let e = GridEdge(source: source, direction: direction)
        if filter.isPartOfGrid(e) && filter.isPartOfGrid(e.destination) {
          return i
        }
      }
      return endIndex
    }

    /// One past the last valid index in `self`.
    public var endIndex: Index {
      GridDirection.allCases.endIndex
    }

    /// Computes the next index in `self`.
    public func index(after index: Index) -> Index {
      var i = GridDirection.allCases.index(after: index)
      while i != GridDirection.allCases.endIndex {
        let d = GridDirection.allCases[i]
        let e = GridEdge(source: source, direction: d)
        if filter.isPartOfGrid(e) && filter.isPartOfGrid(e.destination) { return i }
        i = GridDirection.allCases.index(after: i)
      }
      return endIndex
    }

    /// Accesses the grid edge at `index`.
    public subscript(index: Index) -> GridEdge {
      GridEdge(source: source, direction: GridDirection.allCases[index])
    }
  }

  /// Returns the collection of edges whose source is `vertex`.
  public func edges(from vertex: VertexId) -> VertexEdgeCollection {
    VertexEdgeCollection(filter: filter, source: vertex)
  }

  /// Returns the source `VertexId` of `edge`.
  public func source(of edge: EdgeId) -> VertexId {
    edge.source
  }

  /// Returns the destnation `VertexId` of `edge`.
  public func destination(of edge: EdgeId) -> VertexId {
    edge.destination
  }
}

extension InfiniteGrid: BidirectionalGraph {
  /// The collection of all edges whose destination is a single vertex in an infinite grid.
  public struct VertexInEdgeCollection: Collection {
    /// The index into the collection.
    public typealias Index = GridDirection.AllCases.Index
    /// The elements of the collection.
    public typealias Element = GridEdge

    /// A filter of edges & vertices.
    let filter: Filter
    /// The source vertex of all edges.
    let destination: Point2

    /// The first valid index in `self`.
    public var startIndex: Index {
      if !filter.isPartOfGrid(destination) { return endIndex }
      for i in GridDirection.allCases.indices {
        let direction = GridDirection.allCases[i]
        let source = destination + (-direction).coordinateDelta
        let e = GridEdge(source: source, direction: direction)
        if filter.isPartOfGrid(e) && filter.isPartOfGrid(source) { return i }
      }
      return endIndex
    }

    public var endIndex: Index {
      GridDirection.allCases.endIndex
    }

    public func index(after index: Index) -> Index {
      var i = GridDirection.allCases.index(after: index)
      while i != GridDirection.allCases.endIndex {
        let d = GridDirection.allCases[i]
        let s = destination + (-d).coordinateDelta
        let e = GridEdge(source: s, direction: d)
        if filter.isPartOfGrid(e) && filter.isPartOfGrid(s) { return i }
        i = GridDirection.allCases.index(after: i)
      }
      return endIndex
    }

    public subscript(index: Index) -> GridEdge {
      let direction = GridDirection.allCases[index]
      return GridEdge(source: destination + (-direction).coordinateDelta, direction: direction)
    }
  }

  public func edges(to vertex: VertexId) -> VertexInEdgeCollection {
    VertexInEdgeCollection(filter: filter, destination: vertex)
  }
}