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
}
