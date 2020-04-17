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

/// Trie implements a map from string prefixes (as sequences of [UInt8]) to
/// integer values.
///
/// This implementation is hyper-optimized for CSV parsing in Penguin, and
/// assumes a relatively sparse space.
///
/// This trie stores a mapping from `UnsafeBufferPointer<UInt8>`'s to `T`'s.
struct Trie<T> {

    /// NodeId refers to the index in the `nodes` array.
    ///
    /// When set to -1, it signifies that it is "unset".
    typealias NodeId = Int32

    /// The trie is flattened into a flat array of `Node`'s. The "pointers" of
    /// the data structure (the `NodeId`'s) are simply indices into this array.
    var nodes = [Node()]

    init() {}

    subscript(str: String) -> T? {
        get {
            var copy = str
            return copy.withUTF8 {
                self[$0]
            }
        }
        set {
            var copy = str
            copy.withUTF8 {
                self[$0] = newValue
            }
        }
    }

    subscript(buf: UnsafeBufferPointer<UInt8>) -> T? {
        get {
            var nodeIndex = 0
            for char in buf {
                guard let newNodeIndex = nodes[nodeIndex][char],
                      newNodeIndex != -1 else { return nil }
                nodeIndex = Int(newNodeIndex)
            }
            return nodes[nodeIndex].value
        }
        set {
            var nodeIndex = 0
            for char in buf {
                if let newNodeIndex = nodes[nodeIndex][char], newNodeIndex != -1 {
                    nodeIndex = Int(newNodeIndex)
                    continue
                }
                // Add a new node.
                nodes[nodeIndex][char] = Int32(nodes.count)
                nodeIndex = nodes.count
                nodes.append(Node())
            }
            nodes[nodeIndex].value = newValue
        }
    }

    struct Node {
        var value: T?
        var entries: NodeEntry?

        subscript(char: UInt8) -> NodeId? {
            get {
                if let entries = entries {
                    return entries[char]
                }
                return nil
            }
            set {
                precondition(newValue != nil, "Cannot set nil value at \(char); self: \(self)")
                guard entries != nil else {
                    self.entries = NodeEntry(char: char, nodeId: newValue!)
                    return
                }
                self.entries![char] = newValue
            }
        }
    }


    enum NodeEntry {
        case inline(chars: SIMD8<UInt8>, indices: SIMD8<NodeId>)
        case outOfLine(references: [(UInt8, NodeId)])

        init(char: UInt8, nodeId: NodeId) {
            var chars = SIMD8<UInt8>(repeating: 0)
            chars[0] = char
            var indices = SIMD8<Int32>(repeating: -1)
            indices[0] = nodeId
            self = .inline(chars: chars, indices: indices)
        }

        subscript(char: UInt8) -> NodeId? {
            get {
                switch self {
                case let .inline(chars, indices):
                    // Vectorized implementation of a linear search.
                    let bools = chars .!= char
                    if bools != SIMDMask(repeating: true) {
                        assert((~bools._storage).wrappedSum() == -1, "\(self), \(char), \(bools)")
                        // We have a match!
                        // We must fiddle with the types now a bit.
                        let int32MaskStorage: SIMD8<Int32> = SIMD8(truncatingIfNeeded: bools._storage)
                        let mask = SIMDMask(int32MaskStorage)
                        // Futz with the types.
                        return indices.replacing(with: 0, where: mask).wrappedSum()
                    }
                    return nil
                case let .outOfLine(references):
                    // TODO: profile to compare binary search vs linear scan.
                    for i in references {
                        if i.0 == char {
                            return i.1
                        }
                    }
                    return nil
                }
            }
            set {
                // Once a value has been set, it should never change!
                assert(self[char] == nil, "self: \(self), char: \(char)")
                assert(newValue != nil, "Cannot set \(char) to nil; \(self)")
                // Use this silly pattern to avoid being accidentally quadratic.
                if case var .inline(chars, indices) = self {
                    assert(chars.scalarCount == indices.scalarCount)
                    for i in 0..<chars.scalarCount {
                        if chars[i] == 0 && indices[i] == -1 {
                            chars[i] = char
                            indices[i] = newValue!
                            self = .inline(chars: chars, indices: indices)
                            return
                        }
                    }
                    // Convert to out-of-line representation.
                    var outOfLineRepresentation = [(UInt8, NodeId)]()
                    outOfLineRepresentation.reserveCapacity(9)
                    for i in 0..<chars.scalarCount {
                        outOfLineRepresentation.append((chars[i], indices[i]))
                    }
                    outOfLineRepresentation.append((char, newValue!))
                    self = .outOfLine(references: outOfLineRepresentation)
                }
                if case var .outOfLine(references) = self {
                    // Overwrite self!
                    self = .inline(chars: SIMD8(repeating: 0), indices: SIMD8(repeating: 0))
                    // Now append.
                    references.append((char, newValue!))
                    // Reset self.
                    self = .outOfLine(references: references)
                    return
                }
                fatalError("Unimplemented case in set!")
            }
        }

        var isInline: Bool {
            switch self {
            case .inline: return true
            case .outOfLine: return false
            }
        }
    }
}
