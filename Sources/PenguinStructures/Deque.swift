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

// MARK: - Queue

// TODO: how should queue relate to collection?
// TODO: how should this be refined w.r.t. priority queues?
/// A first-in-first-out data structure.
public protocol Queue {
  /// The type of data stored in the queue.
  associatedtype Element

  /// Removes and returns the next element.
  mutating func pop() -> Element?

  /// Adds `element` to `self`.
  mutating func push(_ element: Element)
}

// MARK: - Deque

/// A dynamically-sized queue with efficient additions and removals at both the beginning and the end.
///
/// Deque's have stable indices, such that pushing and popping elements do not invalidate indices for
/// unaffected elements.
public struct Deque<Element> {
  private var spine: Spine
}

extension Deque {
  /// The number of bits used to encode the per-page element offset.
  private static var maxPerBlockElementBits: UInt { 13 }
  /// The hard-coded size of a block, in bytes.
  private static var blockSize: UInt { 4096 }
  /// A mask to extract the offset into a block.
  private static var blockOffsetMask: UInt { (1 << maxPerBlockElementBits) - 1 }
  /// A mask to extract the page identifier.
  private static var blockIDMask: UInt { ~blockOffsetMask }
  /// The number of bits used to represent block IDs.
  private static var blockIDBitCount: UInt { UInt(UInt.bitWidth) - maxPerBlockElementBits - 1 }
  /// Maximum block ID, and can also be used as a bitmask for blockIDs. 
  internal static var maxBlockID: UInt { (1 << blockIDBitCount) - 1 }
  /// The number of elements per block.
  private static var elementsPerBlock: UInt { Self.blockSize / UInt(MemoryLayout<Element>.stride) }

  /// Prints out sizes for internal data structures.
  ///
  /// When ensuring Deque works as expected for your platform, this function will print to stdout the sizes of internal
  /// data structures.
  public static func _printDequeStaticInternalConfiguration() {
    print("""
    Deque configuration:
     - maxPerBlockElementBits: \(maxPerBlockElementBits)
     - blockSize: \(blockSize) bytes
     - blockOffsetMask: \(String(blockOffsetMask, radix: 2))
     - blockIDMask: \(String(blockIDMask, radix: 2))
     - blockIDBitCount: \(blockIDBitCount)
     - maxBlockID: \(maxBlockID)
     - elementsPerBlock: \(elementsPerBlock)
    """)
  }

  /// Halts the program if the hard-coded configuration values are inconsistent with each other.
  private func assertConstantInvariants() {
    assert(Self.blockSize == (1 << (Self.maxPerBlockElementBits - 1)), "The block size must be exactly 2^(maxPerBlockElementBits - 1)")
    assert(Self.maxBlockID & (Self.maxBlockID + 1) == 0, "The maximum blockID must be one less than a power of 2 for fast masking.")
  }

  /// A partially- or completely-filled block of elements allocated in page-size increments.
  internal typealias Block = UnsafeMutablePointer<Element>

  // TODO: Make type `Index` exist outside of `Deque` to allow nested collections with intertwined indices (e.g. adjacency lists).
  /// A position into the Deque.
  public struct Index: Equatable, Hashable, Comparable {
    /// Storage for the packed representation of the offset.
    internal var storage: UInt

    /// The offset into a block of elements.
    internal var blockOffset: UInt { storage & Deque.blockOffsetMask }
    /// A stable identifier for a block of storage.
    internal var blockID: UInt { ((storage & Deque.blockIDMask) >> maxPerBlockElementBits) & Deque.maxBlockID }

    /// Returns a Boolean value indicating whether the value of the first argument is less than that of the second argument.
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.storage < rhs.storage }  // TODO: Is this right?
  }

  /// Information on the layout of data within the Deque.
  internal struct Metadata {
    /// The position of the first element (if non-empty).
    var start: Index
    /// The position one greater than the last valid index.
    var end: Index
    /// The offset to use to index into the spine.
    var blockOffset: UInt
  }

  /// An ordered collection of pointers to buffers containing Elements.
  ///
  /// A Deque is composed of a hierarchy of two buffers: the first is the spine, 
  internal final class Spine: ManagedBuffer<Metadata, Block?> {

    /// The number of elements in `self`.
    public var count: Int {
      // Note: this calculation works even if there isn't a full page of elements, and has the benefit
      // of being fully branchless.
      let startBlockElems = Deque.elementsPerBlock - header.start.blockOffset
      let endBlockElems = header.end.blockOffset
      let middleBlocks = (endBlockOffset - startBlockOffset - 1) * Int(bitPattern: Deque.elementsPerBlock)  // Can be negative!
      return Int(bitPattern: startBlockElems + endBlockElems) + middleBlocks
    }

    /// true if `self` contains an element; false otherwise.
    public var isEmpty: Bool { header.start == header.end }

    public func index(after i: Index) -> Index {
      var next = i
      next.storage += 1
      if _slowPath(next.blockOffset == Deque.elementsPerBlock) {
        next = Index(blockOffset: 0, blockID: (next.blockID + 1) & Deque.maxBlockID)
      }
      return next
    }

    public func index(before i: Index) -> Index {
      var next = i
      if _slowPath(i.blockOffset == 0) {
        next = Index(blockOffset: Deque.elementsPerBlock - 1, blockID: (i.blockID - 1) & Deque.maxBlockID)
      } else {
        next.storage -= 1
      }
      return next
    }

    /// The index into `self`'s element pointer for the start block.
    internal var startBlockOffset: Int {
      spineOffsetForIndex(header.start)
    }

    /// The index into `self`'s element pointer for the end block.
    internal var endBlockOffset: Int {
      spineOffsetForIndex(header.end)
    }

    /// Returns the offset into the elements of `self` corresponding to `index`'s `blockID`.
    internal func spineOffsetForIndex(_ index: Index) -> Int {
      let base = index.blockID + header.blockOffset
      return Int(bitPattern: base & Deque.maxBlockID)  // Use bitPattern to avoid extra branches / traps.
    }

    /// Allocates a new empty spine.
    class func createEmpty(blockCount: UInt = 10) -> Spine {
      let buff = Spine.create(minimumCapacity: Int(blockCount)) { buff in
        buff.withUnsafeMutablePointerToElements {
          $0.initialize(repeating: nil, count: buff.capacity)
        }
        return Metadata(start: Index(storage: 0), end: Index(storage: 0), blockOffset: blockCount / 2)
      }
      return buff as! Spine
    }

    func deepClone() -> Spine {
      let oldCapacity = capacity
      let oldMetadata = header
      let oldStartOffset = spineOffsetForIndex(header.start)
      let oldEndOffset = spineOffsetForIndex(header.end)
      let s = Spine.create(minimumCapacity: oldCapacity) { _ in oldMetadata }
      withUnsafeMutablePointerToElements { old in
        s.withUnsafeMutablePointerToElements { new in
          if oldStartOffset > 0 {
            new.initialize(repeating: nil, count: oldStartOffset)
          }
          if oldStartOffset == oldEndOffset {
            // Initialize only the relevant portions of memory.
            if old[oldStartOffset] != nil {
              let newPage = Block.allocate(capacity: Int(bitPattern: Deque.elementsPerBlock))
              let blockOffset = oldMetadata.start.blockOffset
              let blockCount = oldMetadata.end.blockOffset - blockOffset
              (newPage + blockOffset).initialize(from: old[oldStartOffset]! + blockOffset, count: blockCount)
              new[oldStartOffset] = newPage
            } else { new[oldStartOffset] = nil }
          } else {
            // Copy both the first & last page.
            let newStartPage = Block.allocate(capacity: Int(bitPattern: Deque.elementsPerBlock))
            let startBlockOffset = oldMetadata.start.blockOffset
            (newStartPage + startBlockOffset).initialize(
                from: old[oldStartOffset]! + startBlockOffset,
                count: Deque.elementsPerBlock - startBlockOffset)
            new[oldStartOffset] = newStartPage
            if old[oldEndOffset] != nil {
              let newEndPage = Block.allocate(capacity: Int(bitPattern: Deque.elementsPerBlock))
              newEndPage.initialize(from: old[oldEndOffset], count: oldMetadata.end.blockOffset)
              new[oldEndOffset] = newEndPage
            } else { new[oldEndOffset] = nil }
            // Copy all intermediate pages (if any).
            if oldStartOffset + 1 < oldEndOffset - 1 {
              for i in (oldStartOffset + 1)...(oldEndOffset - 1) {
                // Make a copy of the page.
                let newBlock = Block.allocate(capacity: Int(bitPattern: Deque.elementsPerBlock))
                newBlock.initialize(from: old[i]!, count: Int(bitPattern: Deque.elementsPerBlock))
                new[i] = newBlock
              }
            }
          }
          if oldEndOffset + 1 < s.capacity {
            (new + oldEndOffset + 1).initialize(repeating: nil, count: s.capacity - oldEndOffset - 1)
          }
        }
      }
      return s as! Spine
    }
  }
}

extension Deque {
  /// Ensures a particular block is allocated and returns the block pointer.
  internal mutating func ensureAllocatedBlock(at i: Index) -> Block {
    var spineOffset = spine.spineOffsetForIndex(i)
    // First, check to ensure the spineOffset is not out of bounds.
    if _slowPath(spineOffset < 0 || spineOffset >= spine.capacity) {
      // Must modify the spine.
      let startOffset = spine.spineOffsetForIndex(startIndex)
      let endOffset = spine.spineOffsetForIndex(endIndex)
      let occupiedSlots = endOffset - startOffset
      if occupiedSlots + 1 < spine.capacity {
        // Re-center and avoid reallocating a larger spine.
        let newStartOffset = (spine.capacity - occupiedSlots) / 2
        let newEndOffset = newStartOffset + occupiedSlots
        assert(newStartOffset > 0)
        assert(newEndOffset < spine.capacity)
        assert(newStartOffset != startOffset)
        spine.withUnsafeMutablePointerToElements { elems in
          let newStart = elems + newStartOffset
          let oldStart = elems + startOffset
          newStart.assign(from: UnsafePointer(oldStart), count: occupiedSlots)
          if newStartOffset > startOffset {
            oldStart.assign(repeating: nil, count: newStartOffset - startOffset)
          } else {
            let newEnd = elems + newEndOffset
            newEnd.assign(repeating: nil, count: endOffset - newEndOffset)
          }
        }
        let newOffset = Int(spine.header.blockOffset) + (newStartOffset - startOffset)
        spine.header.blockOffset = UInt(newOffset) & Deque.maxBlockID
      } else {
        // Must allocate a new, larger spine; no need to copy the data blocks.
        let newSpine = Spine.create(minimumCapacity: 2 * spine.capacity) { newSpine in
          // Re-center while we're at it.
          let newStartOffset = (newSpine.capacity - occupiedSlots) / 2
          spine.withUnsafeMutablePointerToElements { oldBuff in
            newSpine.withUnsafeMutablePointerToElements { newBuff in
              newBuff.initialize(repeating: nil, count: newStartOffset)
              let newStart = newBuff + newStartOffset
              newStart.initialize(from: UnsafePointer(oldBuff + startOffset), count: occupiedSlots)
              (newStart + occupiedSlots).initialize(repeating: nil, count: newSpine.capacity - occupiedSlots - newStartOffset)
            }
          }
          let newBlockOffset = Int(startIndex.blockID) + newStartOffset
          return Metadata(start: startIndex, end: endIndex, blockOffset: UInt(bitPattern: newBlockOffset) & Deque.maxBlockID)
        }
        spine = newSpine as! Spine
      }
      spineOffset = spine.spineOffsetForIndex(i)
    }
    // Next check if the block is allocated.
    return spine.withUnsafeMutablePointerToElements { elems in
      if _fastPath(elems[spineOffset] != nil) { return elems[spineOffset]! }
      // Check to see if we have an empty allocated block available to reuse.
      let beforeStart = spine.spineOffsetForIndex(startIndex) - 1
      if beforeStart >= 0 && elems[beforeStart] != nil {
        let reuseBlock = elems[beforeStart]!
        elems[spineOffset] = reuseBlock
        elems[beforeStart] = nil
        return reuseBlock
      }
      let afterEnd = spine.spineOffsetForIndex(endIndex) + 1
      if afterEnd < spine.capacity && elems[afterEnd] != nil {
        let reuseBlock = elems[afterEnd]!
        elems[afterEnd] = nil
        elems[spineOffset] = reuseBlock
        return reuseBlock
      }
      let newBlock = Block.allocate(capacity: Int(bitPattern: Deque.elementsPerBlock))
      elems[spineOffset] = newBlock
      return newBlock
    }
  }

  /// Indicates a given block should be considered empty and optionally deallocated.
  ///
  /// In order to avoid degenerate performance cases of allocating and deallocating a block of memory
  /// (e.g. repeatedly pushing and popping a single element right at the page boundary), a block may be
  /// lazily deallocated. In order to take advantage of this performance optimization, blocks should be
  /// allocated with `ensureAllocatedBlock` and deallocated with `markEmptyBlock`.
  internal mutating func markEmptyBlock(at spineOffset: Int) {
    // TODO: Implement this optimization.
  }

  /// Ensure that `self` holds uniquely-referenced storage, copying its memory if necessary.
  internal mutating func ensureUniqueStorage() {
    if !isKnownUniquelyReferenced(&spine) {
      spine = spine.deepClone()
    }
  }
}

extension Deque: Collection, BidirectionalCollection {
  public var startIndex: Index { spine.header.start }
  public var endIndex: Index { spine.header.end }
  public var count: Int { spine.count }
  public var isEmpty: Bool { spine.isEmpty }
  public func index(after i: Index) -> Index { spine.index(after: i) }
  public func index(before i: Index) -> Index { spine.index(before: i) }

  public subscript(i: Index) -> Element {
    // TODO: Ensure `i` is a valid index!
    let spineOffset = spine.spineOffsetForIndex(i)
    return spine.withUnsafeMutablePointerToElements { $0[spineOffset]![Int(i.blockOffset)] }
  }
}

// TODO: Conform Deque to RandomAccessCollection, MutableCollection, and RangeReplaceableCollection.

extension Deque {

  /// Creates an empty Deque.
  public init() {
    self.spine = Spine.createEmpty()
  }

  /// Creates an instance with the same elements as `contents`.
  public init<Contents: Collection>(_ contents: Contents) where Contents.Element == Element {
    self.init()
    for e in contents {
      pushBack(e)
    }
  }

  /// Add `elem` to the back of `self`.
  public mutating func pushBack(_ elem: Element) {
    ensureUniqueStorage()
    let i = endIndex
    let block = ensureAllocatedBlock(at: i)
    let position = block + Int(bitPattern: i.blockOffset)
    position.initialize(to: elem)
    spine.header.end = spine.index(after: i)
  }

  /// Removes and returns the element at the back, reducing `self`'s count by one.
  ///
  /// - Precondition: !isEmpty
  public mutating func popBack() -> Element {
    ensureUniqueStorage()
    let i = spine.index(before: endIndex)
    let offset = spine.spineOffsetForIndex(i)
    let block = spine.withUnsafeMutablePointerToElements { $0[offset]! }
    let position = block + Int(bitPattern: i.blockOffset)
    let returnValue = position.move()
    spine.header.end = i
    if _slowPath(i.blockOffset == 0) {
      markEmptyBlock(at: offset)
    }
    return returnValue
  }

  /// Adds `elem` to the front of `self`.
  public mutating func pushFront(_ elem: Element) {
    ensureUniqueStorage()
    let i = spine.index(before: startIndex)
    let block = ensureAllocatedBlock(at: i)
    let position = block + Int(bitPattern: i.blockOffset)
    position.initialize(to: elem)
    spine.header.start = i
  }

  /// Removes and returns the element at the front, reducing `self`'s count by one.
  ///
  /// - Precondition: !isEmpty
  public mutating func popFront() -> Element {
    ensureUniqueStorage()
    let offset = spine.spineOffsetForIndex(startIndex)
    let block = spine.withUnsafeMutablePointerToElements { $0[offset]! }
    let position = block + Int(bitPattern: startIndex.blockOffset)
    let returnValue = position.move()
    let newStart = spine.index(after: startIndex)
    if _slowPath(spine.spineOffsetForIndex(newStart) != offset) {
      markEmptyBlock(at: offset)
    }
    spine.header.start = newStart
    return returnValue
  }
}

extension Deque: Queue {
  public mutating func pop() -> Element? {
    if isEmpty {
      return nil
    }
    return popFront()
  }

  public mutating func push(_ element: Element) {
    pushBack(element)
  }
}


extension Deque.Index {
  /// Creates an Index from a given blockOffset and blockID.
  ///
  /// - Precondition: blockOffset is a valid block offset.
  internal init(blockOffset: UInt, blockID: UInt) {
    precondition((blockOffset & Deque.blockOffsetMask) == blockOffset, "blockOffset \(blockOffset) is not a valid block offset")
    storage = (blockID << Deque.maxPerBlockElementBits) | blockOffset
  }
}

extension Deque.Index: CustomStringConvertible {
  public var description: String {
    "Index(blockID: \(blockID), blockOffset: \(blockOffset))"
  }
}

extension Deque.Spine: CustomStringConvertible {
  public var description: String {
    func formatBlock(_ block: Deque.Block?) -> String {
      if let block = block {
        return "\(block)"
      } else {
        return "nil"
      }
    }
    var body = ""
    withUnsafeMutablePointerToElements { buff in
      for i in 0..<capacity {
        body.append(" - \(formatBlock(buff[i]))\n")
      }
    }
    return """
    Spine(capacity: \(capacity), metadata: \(header)) {
    \(body)}
    """
  }
}

extension UnsafeMutablePointer {
  fileprivate static func + (lhs: Self, rhs: UInt) -> Self {
    return lhs + Int(rhs)
  }

  fileprivate func initialize(from: UnsafeMutablePointer<Pointee>?, count: UInt) {
    initialize(from: UnsafePointer(from!), count: Int(bitPattern: count))
  }
}
