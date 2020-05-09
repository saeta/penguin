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

let nonBlockingCondition = BenchmarkSuite(name: "NonBlockingCondition") { suite in

	typealias Cond = NonblockingCondition<PosixConcurrencyPlatform>

	let cond = Cond(threadCount: 12)

	suite.benchmark("notify one, no waiters") {
		cond.notify()
	}

	suite.benchmark("notify all, no waiters") {
		cond.notify(all: true)
	}

	suite.benchmark("preWait, cancelWait") {
		cond.preWait()
		cond.cancelWait()
	}

	suite.benchmark("preWait, notify, cancelWait") {
		cond.preWait()
		cond.notify()
		cond.cancelWait()
	}

	suite.benchmark("preWait, notify, commitWait") {
		cond.preWait()
		cond.notify()
		cond.commitWait(3)
	}
}
