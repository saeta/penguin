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

import Foundation
import PenguinParallel
import PenguinStructures

extension NonBlockingThreadPool {
  /// Initialize `self` using the same number threads as active processors.
  public convenience init(name: String, environment: Environment) {
    self.init(
      name: name,
      threadCount: ProcessInfo.processInfo.activeProcessorCount,
      environment: environment
    )
  }
}

extension NonBlockingThreadPool where Environment: DefaultInitializable {
  /// Initialize `self` using a default initialized environment and the same number of threads as
  /// active processors.
  public convenience init(name: String) {
    self.init(
      name: name,
      environment: Environment()
    )
  }
}

/// A Foundation-based general purpose compute-oriented thread pool.
///
/// - SeeAlso: NonBlockingThreadPool
/// - SeeAlso: PosixConcurrencyPlatform
public typealias PosixNonBlockingThreadPool = NonBlockingThreadPool<PosixConcurrencyPlatform>
