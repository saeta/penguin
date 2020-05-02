# Penguin Graphs #

Penguin Graphs contains implementations of useful data structures and algorithms for computing information on Graphs.

> Note: there are known compiler bugs in Swift 5.1 that prevent this library from being compiled.
> Please use Swift 5.2, or a S4TF toolchain of 0.8 or later.

Although the Penguin data frames don't directly use Graphs, they are an incredibly important tool in
a data scientist's toolkit, as they can model a variety of problems efficiently. This package
contains protocols to define graphs, as well as a collection of algorithms defined against these
protocols. This makes it very easy to re-use the graph algorithms on your own data structures.
Finally, this package includes a Swiss-army-knife graph implementation that you can use
directly if you do not already have your data in a graph structure.

The protocols defined in this library borrow a lot of ideas from the excellent [Boost Graph
Library](https://www.boost.org/doc/libs/1_72_0/libs/graph/doc/index.html).
