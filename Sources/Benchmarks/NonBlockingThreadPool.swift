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

let nonBlockingThreadPool = BenchmarkSuite(name: "NonBlockingThreadPool") { suite in

	typealias Pool = NonBlockingThreadPool<PosixConcurrencyPlatform>

	let pool = Pool(name: "benchmark-pool", threadCount: 4)
	let helpers = Helpers()

	suite.benchmark("join, one level") {
		pool.join({ }, { })
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

	suite.benchmark("parallel for, one level") {
		let buffer1 = helpers.buffer1
		pool.parallelFor(n: buffer1.count) { (i, n) in buffer1[i] = true }
	}

	suite.benchmark("parallel for, two levels") {
		let buffer2 = helpers.buffer2
		pool.parallelFor(n: buffer2.count) { (i, n) in
			pool.parallelFor(n: buffer2[i].count) { (j, _) in buffer2[i][j] = true }
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
