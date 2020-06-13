# Penguin Graphs #

> PenguinGraphs enables efficient processing, analysis, and machine learning with graphs.

[Graphs](https://en.wikipedia.org/wiki/Graph_(discrete_mathematics)) enable efficient representation
and analysis of myriad relations. It is rare to encounter datasets that contain zero inherent
structure. PenguinGraphs is a library to empower data scientists and machine learning engineers to
efficiently harness this additional structure to derive insights, and to complement other machine
learning algorithms.

> Note: although PenguinGraphs endeavors to be efficient at execution time, it prioritizes user
> ergonomics more; PenguinGraphs is optimized for time-to-insight most of all.

## Overview ##

Components of this library can be divided into 3 key areas:

 1. **Graph algorithms.** PenguinGraphs follows the principles of [generic
    programming](https://en.wikipedia.org/wiki/Generic_programming), where algorithms are written
    independent of concrete data structures. In Swift, that means algorithms are written to
    [protocols](https://docs.swift.org/swift-book/LanguageGuide/Protocols.html). The most important
    protocol is the `IncidenceGraph` protocol, and is thus a good place to start when searching for
    interesting algorithms.

    > Note: you can re-use these algorithms on your own graph data structures if you would like!
    > Simply add the requisite conformances to your graph data structure, and call the algorithms.

 2. **Graph data structures**. PenguinGraph comes with a few graph implementations. A good general-
    purpose graph implementation is the adjacency list family, including `DirectedAdjacencyList`
    (which models a directed graph), `BidirectionalAdjacencyList` (which models a directed graph,
    and allows efficiently discovering the edges into a vertex), and `UndirectedAdjacencyList`
    (which models an undirected graph).

    PenguinGraphs also comes with more specialized graph implementations, such as an infinite grid,
    which can be used to analyize navigation on a [2 dimensional
    plane](https://en.wikipedia.org/wiki/Plane_(geometry)).

 3. **Supporting types.** Graph algorithms often leverage additional information, data structures or
    types during execution. The most important group of types are `PropertyMap`s. The following are
    examples of additional data consumed and produced during select graph algorithms:

  - **Vertex Visitation**: When performing depth-first or breadth-first search, the algorithm
    must keep track of which vertices have been visited or not.
  - **Edge Distances**: Dijkstra's search needs to know how "long" an edge is when searching for
    shortest paths in a graph.
  - **Components**: When computing the strong components of a graph, property maps are used to
    record the discover time of each vertex, as well as which component each vertex belongs to.

    Some graph implementations may record this information within its data data structure. (e.g. An
    adjacency list representation might store the cost of traversing an edge within the adjacency
    list itself.) Other times, the data structure does not support recording extra information
    within it. In order to ensure the graph algorithms can be flexibly applied irrespective of the
    underlying graph implementation, the algorithms use `PropertyMap`s which abstract over the
    physical storage of the data.

    Other supporting types include `VertexColor` which is used to in a variety of graph algorithms
    to determine which vertices have been analyzied, a family of predecessor recorders, which can be
    used to determine shortest paths, and events (such as `BFSEvent`) which represent events during
    an algorithm's execution (e.g. a breadth-first search).

## Tips ##

Below are some helpful tips for 

 1. **Use the auto-generated documentation**. PenguinGraphs is a relatively large library with many
    algorithms and types. The easiest way to understand what's available is to check out the
    [auto-generated documentation](https://saeta.github.io/penguin/graphs/).

 2. **Closures**. Some algorithms in PenguinGraphs take a non-escaping closure as a parameter which
    can customize its execution. Be sure to check out the examples and/or tests.

<!-- TODO: Add examples! -->

## Parallelism ##

PenguinGraphs supports executing some algorithms in parallel.

<!-- TODO: document more here! -->

## Acknowledgements ##

The protocols defined in this library borrow a lot of ideas from the excellent [Boost Graph
Library](https://www.boost.org/doc/libs/1_72_0/libs/graph/doc/index.html). Additionally, algorithms
inspired or based off of academic papers cite the corresponding publications in their documentation.
