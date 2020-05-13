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

import Benchmark
import PenguinParallelWithFoundation
import Dispatch

let nonBlockingThreadPool = BenchmarkSuite(name: "NonBlockingThreadPool") { suite in

  typealias Pool = NonBlockingThreadPool<PosixConcurrencyPlatform>

  let pool = Pool(name: "benchmark-pool", threadCount: 4)
  let helpers = Helpers()

  suite.benchmark("join, one level") {
    pool.join({}, {})
  }

  suite.benchmark("join, two levels") {
    pool.join(
      { pool.join({}, {}) },
      { pool.join({}, {}) })
  }

  suite.benchmark("join, three levels") {
    pool.join(
      { pool.join({ pool.join({}, {}) }, { pool.join({}, {}) }) },
      { pool.join({ pool.join({}, {}) }, { pool.join({}, {}) }) })
  }

  suite.benchmark("join, four levels, three on thread pool thread") {
    pool.join(
      {},
      {
        pool.join({ pool.join({ pool.join({}, {}) }, { pool.join({}, {}) }) },
                { pool.join({ pool.join({}, {}) }, { pool.join({}, {}) }) })
      })
  }

  let pool2 = Pool(name: "benchmark-pool2", threadCount: 12)

  suite.benchmark("parallel for, one level") {
    let buffer1 = helpers.buffer1
    pool2.parallelFor(n: buffer1.count) { (i, n) in buffer1[i] = true }
  }

  suite.benchmark("parallel for, two levels") {
    let buffer2 = helpers.buffer2
    pool2.parallelFor(n: buffer2.count) { (i, n) in
      pool2.parallelFor(n: buffer2[i].count) { (j, _) in buffer2[i][j] = true }
    }
  }


  for grainSize in [10, 100, 1000, 2000, 5000] {
    suite.benchmark("parallel for, one level, grain size \(grainSize)") {
      let buffer1 = helpers.buffer1
      pool2.parallelFor(n: buffer1.count, grainSize: grainSize) { (i, n) in buffer1[i] = true }
    }
  }

  suite.benchmark("parallel for, two levels, grain size 10 & 100") {
    let buffer2 = helpers.buffer2
    pool2.parallelFor(n: buffer2.count, grainSize: 10) { (i, n) in
      pool2.parallelFor(n: buffer2[i].count, grainSize: 100) { (j, _) in buffer2[i][j] = true }
    }
  }

  suite.benchmark("dispatch concurrent perform, one level") {
    let buffer1 = helpers.buffer1
    DispatchQueue.concurrentPerform(iterations: buffer1.count) { i in
      buffer1[i] = true
    }
  }

  suite.benchmark("dispatch concurrent perform, two levels") {
    let buffer2 = helpers.buffer2
    DispatchQueue.concurrentPerform(iterations: buffer2.count) { i in
      DispatchQueue.concurrentPerform(iterations: buffer2[i].count) { j in buffer2[i][j] = true }
    }
  }

  suite.benchmark("sequential one level") {
    let buffer1 = helpers.buffer1
    for i in 0..<buffer1.count {
      buffer1[i] = true
    }
  }

  suite.benchmark("sequential two levels") {
    let buffer2 = helpers.buffer2
    for i in 0..<buffer2.count {
      for j in 0..<buffer2[i].count {
        buffer2[i][j] = true
      }
    }
  }
}

fileprivate class Helpers {
  lazy var buffer1 = UnsafeMutableBufferPointer<Bool>.allocate(capacity: 10000)
  lazy var buffer2 = { () -> UnsafeMutableBufferPointer<UnsafeMutableBufferPointer<Bool>> in
    typealias Buffer = UnsafeMutableBufferPointer<Bool>
    typealias Spine = UnsafeMutableBufferPointer<Buffer>
    let spine = Spine.allocate(capacity: 10)
    for i in 0..<spine.count {
      spine[i] = Buffer.allocate(capacity: 1000)
    }
    return spine
  }()
}
