//******************************************************************************
// Copyright 2020 Penguin Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

/// A collection that can be initialized to contain exactly the elements of a source collection.
public protocol SourceInitializableCollection: Collection {
  /// Creates an instance containing exactly the elements of `source`.
  ///
  /// Requires: Instances can hold `source.count` elements.
  init<Source: Collection>(_ source: Source) where Source.Element == Element
  // Note: we don't have a generalization to `Sequence` because we couldn't
  // find an implementation optimizes nearly as well, and in practice
  // `Sequence`'s that are not `Collection`s are extremely rare.
}

extension Array: SourceInitializableCollection {}
