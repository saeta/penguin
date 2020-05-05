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

/// Truncates an underlying iterator to the first `takeCount` elements.
///
/// For more documentation, please see `PipelineIteratorProtocol`'s `take` method.
public struct TakePipelineIterator<U: PipelineIteratorProtocol>: PipelineIteratorProtocol {
  public mutating func next() throws -> U.Element? {
    guard takeCount > 0 else { return nil }
    takeCount -= 1
    return try underlying.next()
  }

  var underlying: U
  var takeCount: Int
}

/// Skips the first `count` elements of an underlying iterator.
///
/// For more documentation, please see `PipelineIteratorProtocol`'s `drop` method.
public struct DropPipelineIterator<U: PipelineIteratorProtocol>: PipelineIteratorProtocol {

  public mutating func next() throws -> U.Element? {
    while count > 0 {
      _ = try? underlying.next()
      count -= 1
    }
    return try underlying.next()
  }

  var underlying: U
  var count: Int
}

extension PipelineIteratorProtocol {
  // TODO: include examples in this documentation.

  /// Drops the first `count` elements of the current iterator.
  ///
  /// - Parameter count: The number of elements to drop.
  public func drop(_ count: Int) -> DropPipelineIterator<Self> {
    DropPipelineIterator(underlying: self, count: count)
  }

  /// Truncates the current iterator to the first `count` elements.
  ///
  /// - Parameter count: The number of elements to keep.
  public func take(_ count: Int) -> TakePipelineIterator<Self> {
    TakePipelineIterator(underlying: self, takeCount: count)
  }
}
