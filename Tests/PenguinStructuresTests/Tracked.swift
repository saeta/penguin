//******************************************************************************
// Copyright 2019 Google LLC
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

/// A wrapper over an arbitrary type that can be used to count instances and
/// make sure they're being properly disposed of.
final class Tracked<T> {
  /// The wrapped value.
  var value: T

  /// An arbitrary counter of instances.
  ///
  /// This function that is passed 1 for each instance of `self` created, and -1
  /// for each instance destroyed.
  let track: (Int) -> Void

  /// Creates an instance holding `value` and invoking `track` to count
  /// instances.
  ///
  /// - Parameter track: called with 1 for each instance of `self` created, and
  ///   -1 for each instance destroyed.
  init(_ value: T, track: @escaping (Int)->Void) {
    self.value = value
    self.track = track
    track(1)
  }
  
  deinit { track(-1) }
}
