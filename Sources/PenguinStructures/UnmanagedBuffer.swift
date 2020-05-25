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

/// A dynamically-sized, contiguous array of `Element`s prefixed by `Header`.
///
/// `UnmanagedBuffer` is similar to the standard library's `ManagedBuffer`, with the key difference
/// in that `UnmanagedBuffer` does not induce reference counting overheads. `UnmanagedBuffer`
/// encapsulates a pointer onto the heap that is allocated during `init`. It is the user's
/// responsibility to call `deallocate` exactly once.
///
/// Although `header` is initialized at `UnmanagedBuffer` initialization, `UnamanagedBuffer` (like
/// `ManagedBuffer` supports partial initialization of the `Element`s array.
public struct UnmanagedBuffer<Header, Element> {
  /// The pointer to the heap memory.
  private let basePointer: UnsafeMutableRawPointer

  /// The offset from the `basePointer` to the start of the contiguous array of `Element`s.
  // Note: a previous implementation dynamically computed the `elementOffsetInBytes`, but in certain
  // workloads, ~25% of the CPU time was spent in `swift_getGenericMetadata`!! Since we can't
  // guarantee full specialization (where this turns into a compile-time constant), we instead
  // materialize it explicitly.
  private let elementOffsetInBytes: UInt32

  /// The count of `Element`s capable of being stored in the trailing dynamically-sized buffer.
  // Note: we limit the capacity of `UnmanagedBuffer` to be < UInt32.max to stuff the
  // UnmanagedBuffer struct itself into 2 words for performance. Future work could consider removing
  // this field, and bit-stuffing `elementOffsetInBytes` into the unused bits of `basePointer`,
  // making `UnmanagedBuffer` take only a single machine word.
  //
  // We set elementCapacity to 0 when deallocated as a sentinal.
  private var elementCapacity: UInt32

  // NOTE FOR REVIEWER: Should this be a static function `.allocate()` instead?
  /// Allocates an `UnmanagedBuffer` to store up to `capacity` `Element`s, initializing
  /// memory with `initializer`.
  public init(capacity: Int, initializer: (UnsafeMutableBufferPointer<Element>) -> Header) {
    precondition(
      capacity < UInt32.max,
      "Cannot allocate an UnmanagedBuffer with capacity: \(capacity).")
    precondition(capacity > 0, "capacity must be > 0!")
    precondition(MemoryLayout<Header>.size < UInt32.max)

    let layout = Self.offsetsAndAlignments(capacity: capacity)

    basePointer = UnsafeMutableRawPointer.allocate(
      byteCount: layout.totalBytes,
      alignment: layout.bufferAlignment)
    elementOffsetInBytes = UInt32(layout.elementsOffset)
    elementCapacity = UInt32(capacity)

    basePointer.bindMemory(to: Header.self, capacity: 1)
    (basePointer + Int(elementOffsetInBytes)).bindMemory(to: Element.self, capacity: capacity)
    // (Partially) initialize memory.
    headerPointer.initialize(to: initializer(elementsPointer))
  }

  // Note: you must deinitialize yourself first if required (using headerPointer,
  // and elementsPointer).
  public mutating func deallocate(deinitalizingElements: (UnsafeMutableBufferPointer<Element>, Header) -> Void) {
    deinitalizingElements(elementsPointer, header)
    headerPointer.deinitialize(count: 1)
    basePointer.deallocate()
    elementCapacity = 0  // Set sentinal.
  }

  /// A pointer to the header.
  public var headerPointer: UnsafeMutablePointer<Header> {
    assert(elementCapacity > 0, "Attempting to access a deallocate'd UnmanagedBuffer.")
    return basePointer.assumingMemoryBound(to: Header.self)
  }

  /// A pointer to the collection of elements that comprise the body.
  public var elementsPointer: UnsafeMutableBufferPointer<Element> {
    assert(elementCapacity > 0, "Attempting to access a deallocate'd UnmanagedBuffer.")
    let start = (basePointer + Int(elementOffsetInBytes)).assumingMemoryBound(to: Element.self)
    return UnsafeMutableBufferPointer(start: start, count: Int(elementCapacity))
  }

  /// The header of the `UnmanagedBuffer`.
  public var header: Header {
    _read { yield headerPointer.pointee }
    nonmutating _modify { yield &headerPointer.pointee }
  }

  /// Access elements in `self`.
  ///
  /// Important note: indexing must only be performed when the buffer's underlying memory has been
  /// initialized!
  public subscript(index: Int) -> Element {
    _read {
      precondition(index < capacity, "Index out of bounds (\(index) >= \(capacity)).")
      yield elementsPointer[index]
    }
    nonmutating _modify {
      precondition(index < capacity, "Index out of bounds (\(index) >= \(capacity)).")
      yield &elementsPointer[index]
    }
  }

  /// The maximum number of `Element`s that can be stored in `self`.
  public var capacity: Int { Int(elementCapacity) }

  internal static func offsetsAndAlignments(capacity: Int) -> (totalBytes: Int, elementsOffset: Int, bufferAlignment: Int) {
    // Compute the next alignment offset after MemoryLayout<Header>.size bytes. (Leverages int
    // division does truncation, and that MemoryLayout<ZERO_SIZED_TYPE>.alignment == 1!)
    let offsetSteps = (MemoryLayout<Header>.size + MemoryLayout<Element>.alignment - 1) / MemoryLayout<Element>.alignment
    let offset = offsetSteps * MemoryLayout<Element>.alignment
    let totalBytes = offset + (capacity * MemoryLayout<Element>.stride)
    let alignment = max(MemoryLayout<Element>.alignment, MemoryLayout<Header>.alignment)
    return (totalBytes, offset, alignment)
  }
}
