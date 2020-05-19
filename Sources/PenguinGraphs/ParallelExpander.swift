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

import PenguinParallel

/// Represents a set of labels and their corresponding weights for use in the expander label
/// propagation algorithm.
///
/// For example, we may have categories {A, B, C}. Vertex 1 is seeded with label A, and vertex 3 is
/// seeded with label C. Because vertex 1 is connected to vertex 2, it will propagate its label A
/// along. Vertex 3 is also connected to vertex 2, and sends its label C along. Vertex 2 thus should
/// have a computed label of (assuming equal weight to edges 1->2 and 3->2) 50% A, and 50% C.
///
/// Note: a LabelBundle must encode the sparsity associated with the presence or absence of labels.
///
/// - SeeAlso: `ParallelGraph.propagateLabels`
public protocol LabelBundle: MergeableMessage {
  /// Initializes where every label has `value`.
  init(repeating value: Float)
  /// Scales the weights of the labels in this LabelBundle by `scalar`.
  mutating func scale(by scalar: Float)

  /// Returns scaled weights for the labels in `self` by `scalar`.
  func scaled(by scalar: Float) -> Self

  /// Adds `scalar` to every label.
  mutating func conditionalAdd(_ scalar: Float, where hasValue: Self)

  /// Update `self`'s value for every label not contained in `self` and contained in `other`.
  mutating func fillMissingFrom(_ other: Self)

  /// Add `rhs` to the value of every label in `self`'s label set.
  static func += (lhs: inout Self, rhs: Float)

  /// Add the weights for all labels in `rhs` to the corresponding labels in `lhs`.
  static func += (lhs: inout Self, rhs: Self)

  /// Divides lhs by rhs.
  static func / (lhs: Self, rhs: Self) -> Self
}

extension LabelBundle {
  public func scaled(by scalar: Float) -> Self {
    var tmp = self
    tmp.scale(by: scalar)
    return tmp
  }
}

/// A label bundle backed by SIMD-based types.
///
/// - SeeAlso: `LabelBundle`
public struct SIMDLabelBundle<SIMDType> where SIMDType: SIMD, SIMDType.Scalar == Float {
  /// The weights corresponding to each label.
  private var weights: SIMDType
  /// A mask to determine whether the weight is valid; -1 if true, 0 otherwise.
  private var validWeightsMask: SIMDType.MaskStorage

  /// Constructs a `SIMDLabelBundle` with uninitialized weights for all labels in the bundle.
  public init() {
    weights = .zero
    validWeightsMask = .zero
  }

  /// Constructs a `SIMDLabelBundle` with provided `weights` and `validWeightsMask`.
  ///
  /// - Parameter weights: a vector of weights to be assigned to each label.
  /// - Parameter validWeightsMask: a vector where each element is 0 if the label is not assigned a
  ///   valid weight, or -1 (all bits set to 1 in 2's complement) if the corresponding weight is
  ///   valid.
  public init(weights: SIMDType, validWeightsMask: SIMDType.MaskStorage) {
    self.weights = weights
    self.validWeightsMask = validWeightsMask
  }

  /// Constructs a `SIMDLabelBundle` with provided `weights`.
  ///
  /// Note: all label weights are assumed valid. If you have some labels that are invalid, use
  /// `init(weights:validWeightsMask:)` to specify which weights are invalid.
  ///
  /// - Parameter weights: a vector of weights to be assigned to each label.
  public init(weights: SIMDType) {
    self.weights = weights
    self.validWeightsMask = ~.zero  // All valid.
  }

  /// Accesses the weight associated with the given index.
  public subscript(index: Int) -> Float? {
    get {
      guard validWeightsMask[index] != 0 else {
        return nil
      }
      return weights[index]
    }
    set {
      if let newValue = newValue {
        weights[index] = newValue
        validWeightsMask[index] = -1
      } else {
        weights[index] = 0
        validWeightsMask[index] = 0
      }
    }
  }
}

extension SIMDLabelBundle: LabelBundle {
  /// Creates a `SIMDLabelBundle` with `value` set for each label's weight.
  ///
  /// All labels are determined to have valid values.
  public init(repeating value: Float) {
    weights = .init(repeating: value)
    validWeightsMask = ~.zero
  }

  /// Scales the weights of `self` by `scalar`.
  public mutating func scale(by scalar: Float) {
    weights *= scalar
    assertConsistent()
  }

  /// Adds `scalar` to every weight of `self` where `hasValue` has valid weight labels.
  public mutating func conditionalAdd(_ scalar: Float, where hasValue: Self) {
    let newWeights = weights + scalar
    weights.replace(with: newWeights, where: SIMDMask(hasValue.validWeightsMask))
    // TODO: update validWeightsMask for self!
    assertConsistent()
  }

  /// Sets weights for every label to `other`'s where the label is not defined in `self`, and is
  /// defined in `other`.
  public mutating func fillMissingFrom(_ other: Self) {
    let mask = (~validWeightsMask) & other.validWeightsMask
    weights.replace(with: other.weights, where: SIMDMask(mask))
    validWeightsMask |= mask
    assertConsistent()
  }

  /// Merges `other` into `self` by summing weights.
  public mutating func merge(_ other: Self) {
    self += other
    assertConsistent()
  }

  /// Adds `rhs` to every defined label's corresponding weight in `lhs`.
  public static func += (lhs: inout Self, rhs: Float) {
    lhs.weights += rhs
    lhs.weights.replace(with: 0, where: .!SIMDMask(lhs.validWeightsMask))  // Reset to 0
    lhs.assertConsistent()
  }

  /// Adds weights for `rhs` into `lhs`.

  /// If a given label does not have a defined weight in `lhs`, but does in `rhs`, the label's
  /// weight in `lhs` becomes defined with `rhs`'s corresponding weight.
  public static func += (lhs: inout Self, rhs: Self) {
    lhs.assertConsistent()
    rhs.assertConsistent()
    lhs.weights += rhs.weights
    lhs.validWeightsMask |= rhs.validWeightsMask
    lhs.assertConsistent()
  }

  /// Divide weights in `lhs` by the weights for the corresponding labels in `rhs`.
  ///
  /// - Precondition: `rhs` must have defined weights for every label defined in `lhs`.
  public static func / (lhs: Self, rhs: Self) -> Self {
    assert(lhs.validWeightsMask == lhs.validWeightsMask & rhs.validWeightsMask)
    let weights = lhs.weights / rhs.weights
    return Self(weights: weights, validWeightsMask: lhs.validWeightsMask)
  }

  /// Asserts that internal invariants hold true.
  func assertConsistent(file: StaticString = #file, line: UInt = #line) {
    assert(
      weights.replacing(with: 0, where: SIMDMask(validWeightsMask)) == .zero,
      """
      Not all invalid weights were zero in: \(self):
        - weights: \(weights)
        - mask: \(validWeightsMask)
        - unequal at: \(weights.replacing(with: 0, where: SIMDMask(validWeightsMask)) .!= SIMDType.zero)
      """, file: file, line: line)
  }
}

extension SIMDLabelBundle: CustomStringConvertible {
  /// A string representation of `SIMDLabelBundle`.
  public var description: String {
    var s = "["
    for (weightIndex, maskIndex) in zip(weights.indices, validWeightsMask.indices) {
      if validWeightsMask[maskIndex] != 0 {
        s.append(" \(weights[weightIndex]) ")
      } else {
        s.append(" <n/a> ")
      }
    }
    s.append("]")
    return s
  }
}

/// An optionally labeled vertex that can be used in the Expander algorithm for propagating labels
/// across a partially labeled graph.
///
/// - SeeAlso: `ParallelGraph.propagateLabels`
/// - SeeAlso: `ParallelGraph.computeEdgeWeights`
public protocol LabeledVertex {
  associatedtype Labels: LabelBundle

  /// The sum of weights for all incoming edges.
  var totalIncomingEdgeWeight: Float { get set }

  /// The apriori known label values.
  var seedLabels: Labels { get }

  /// A prior for how strong the belief in seed labels is.
  var prior: Labels { get }

  /// The labels that result from the iterated label propagation computation.
  var computedLabels: Labels { get set }
}

/// A message used in `ParallelGraph` algorithms to compute the sum of weights for all incoming
/// edges to a vertex.
public struct IncomingEdgeWeightSumMessage: MergeableMessage {
  /// The sum of weights.
  var value: Float

  /// Creates an `IncomingEdgeWeightSumMessage` from `value`.
  public init(_ value: Float) {
    self.value = value
  }

  /// Sums weights of `other` with `self`.
  public mutating func merge(_ other: Self) {
    value += other.value
  }
}

extension ParallelGraph where Self: IncidenceGraph, Self.Vertex: LabeledVertex {

  /// Sums the weights of incoming edges into every vertex in parallel.
  ///
  /// Vertices with no incoming edges will be assigned a `totalIncomingEdgeWeight` of 0.
  public mutating func computeIncomingEdgeWeightSum<
    Mailboxes: MailboxesProtocol,
    VertexSimilarities: ExternalPropertyMap
  >(
    using mailboxes: inout Mailboxes,
    _ vertexSimilarities: VertexSimilarities
  )
  where
    Mailboxes.Mailbox.Graph == ParallelProjection,
    ParallelProjection: IncidenceGraph,
    Mailboxes.Mailbox.Message == IncomingEdgeWeightSumMessage,
    VertexSimilarities.Value == Float,
    VertexSimilarities.Key == EdgeId,
    VertexSimilarities.Graph == Self
  {
    // Send
    step(mailboxes: &mailboxes) { (context, vertex) in
      assert(context.inbox == nil, "Unexpected message in inbox \(context.inbox!)")
      for edge in context.edges {
        let edgeWeight = vertexSimilarities[edge]
        context.send(IncomingEdgeWeightSumMessage(edgeWeight), to: context.destination(of: edge))
      }
    }

    if !mailboxes.deliver() {
      fatalError("No messages sent?")
    }

    // Receive
    step(mailboxes: &mailboxes) { (context, vertex) in
      assert(
        context.inbox != nil,
        """
        Missing message for \(context.vertex) (\(vertex)); are there no edges coming into this \
        vertex?
        """)
      vertex.totalIncomingEdgeWeight = context.inbox!.value
    }
  }

  /// Propagates labels from a few seed vertices to all connected vertices in `self`.
  ///
  /// This algorithm is based on the paper: S. Ravi and Q. Diao. Large Scale Distributed
  /// Semi-Supervised Learning Using Streaming Approximation. AISTATS, 2016.
  public mutating func propagateLabels<
    Mailboxes: MailboxesProtocol,
    VertexSimilarities: ExternalPropertyMap
  >(
    m1: Float,
    m2: Float,
    m3: Float,
    using mailboxes: inout Mailboxes,
    _ vertexSimilarities: VertexSimilarities,
    maxStepCount: Int,
    shouldExitEarly: (Int, Self) -> Bool = { (_, _) in false }
  )
  where
    Mailboxes.Mailbox.Graph == ParallelProjection,
    ParallelProjection: IncidenceGraph,
    Mailboxes.Mailbox.Message == Self.Vertex.Labels,
    VertexSimilarities.Value == Float,
    VertexSimilarities.Key == EdgeId,
    VertexSimilarities.Graph == Self
  {
    for stepNumber in 0..<maxStepCount {
      step(mailboxes: &mailboxes) { (context, vertex) in
        // Receive the incoming (merged) message.
        if let neighborContributions = context.inbox {
          // Compute the new computed label bundle for `vertex`.
          var numerator = neighborContributions.scaled(by: m2)
          numerator += vertex.prior.scaled(by: m3)
          numerator += vertex.seedLabels.scaled(by: m1)

          var denominator = Self.Vertex.Labels(repeating: m2 * vertex.totalIncomingEdgeWeight + m3)
          denominator.conditionalAdd(m1, where: vertex.seedLabels)

          var newLabels = numerator / denominator
          newLabels.fillMissingFrom(vertex.seedLabels)
          vertex.computedLabels = newLabels
        }
        // Send along our new computed labels to all our neighbors.
        for edge in context.edges {
          let edgeWeight = vertexSimilarities[edge]
          context.send(
            vertex.computedLabels.scaled(by: edgeWeight),
            to: context.destination(of: edge))
        }
      }
      if !mailboxes.deliver() {
        fatalError("Could not deliver messages at step \(stepNumber).")
      }
      if shouldExitEarly(stepNumber, self) { return }
    }
  }
}
