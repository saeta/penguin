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

/// An ID that can also be used as an index into a dense, contiguous array.
public protocol IdIndexable {
  /// The index associated with the ID.
  ///
  /// The returned integer must be between 0 and the total number of elements - 1.
  var index: Int { get }
}

extension BinaryInteger where Self: IdIndexable {
  /// The index of a binary integer is itself.
  public var index: Int { Int(self) }
}
extension Int: IdIndexable {}
extension Int32: IdIndexable {}
extension Int64: IdIndexable {}
extension UInt32: IdIndexable {}
extension UInt64: IdIndexable {}
