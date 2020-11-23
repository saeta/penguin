import PenguinGraphs
import PenguinParallelWithFoundation
import PenguinStructures
import Benchmark

let parallelExpander = BenchmarkSuite(name: "ParallelExpander") { suite in
  typealias LabelBundle = SIMDLabelBundle<SIMD3<Float>>
  typealias Graph = DirectedAdjacencyList<TestLabeledVertex, Empty, Int32>
  typealias EdgeWeights = DictionaryPropertyMap<Graph, Graph.EdgeId, Float>

  struct TestLabeledVertex: DefaultInitializable, LabeledVertex {
    var seedLabels: LabelBundle
    var computedLabels = LabelBundle()
    var prior = LabelBundle(weights: .zero)  // Natural prior of zero.
    var totalIncomingEdgeWeight: Float = Float.nan

    public init(seedLabels: [Float]) {
      self.seedLabels = LabelBundle(weights: SIMD3(seedLabels))
    }

    public init() {
      self.seedLabels = .init()
    }
  }

  let pool = PosixNonBlockingThreadPool(name: "benchmark-pool")
  ComputeThreadPools.local = pool

  for size in [10, 100, 1000, 3000] {
    suite.benchmark("parallel expander \(size) nodes (complete)") {
      var g = Graph()
      for i in 0..<size {
        _ = g.addVertex()
      }

      var edgeWeightsDict = [Graph.EdgeId: Float]()
      for i in 0..<size {
        for j in 0..<size {
          if i == j { continue }
          let edgeId = g.addEdge(from: Int32(i), to: Int32(j))
          edgeWeightsDict[edgeId] = 0.5
        }
      }

      let propertyMap = EdgeWeights(edgeWeightsDict)

      var mb1 = PerThreadMailboxes(
        for: g, sending: Type<IncomingEdgeWeightSumMessage>())
      
      g.computeIncomingEdgeWeightSum(using: &mb1, propertyMap)

      var mb2 = PerThreadMailboxes(for: g, sending: Type<LabelBundle>())
      g.propagateLabels(m1: 1.0, m2: 0.01, m3: 0.01, using: &mb2, propertyMap, maxStepCount: 10)
    }
  }

  for size in [10, 100, 1000, 3000] {
    suite.benchmark("parallel expander \(size) nodes (4 edges)") {
      var g = Graph()
      for i in 0..<size {
        _ = g.addVertex()
      }

      var edgeWeightsDict = [Graph.EdgeId: Float]()
      for i in 0..<size {
        for j in 0..<4 {
          var dest = i + j
          if dest >= size { dest -= size }
          let edgeId = g.addEdge(from: Int32(i), to: Int32(dest))
          edgeWeightsDict[edgeId] = 0.5
        }
      }

      let propertyMap = EdgeWeights(edgeWeightsDict)

      var mb1 = PerThreadMailboxes(
        for: g, sending: Type<IncomingEdgeWeightSumMessage>())
      
      g.computeIncomingEdgeWeightSum(using: &mb1, propertyMap)

      var mb2 = PerThreadMailboxes(for: g, sending: Type<LabelBundle>())
      g.propagateLabels(m1: 1.0, m2: 0.01, m3: 0.01, using: &mb2, propertyMap, maxStepCount: 10)
    }
  }
}
