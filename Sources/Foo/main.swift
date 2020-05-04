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

import Dispatch
import Foundation
import Penguin
import PenguinCSV
import PenguinParallel

func baz() {
  typealias Pool = NonBlockingThreadPool<PosixConcurrencyPlatform>
  let pool = Pool(name: "baz", threadCount: 18)

  let condition = NSCondition()
  var seenIndices = Array(repeating: false, count: 1003)  // guarded by condition.
  pool.parallelFor(n: seenIndices.count) { (i, _) in
    condition.lock()
    assert(!seenIndices[i], "Error at: \(i)")
    seenIndices[i] = true
    condition.unlock()
  }
  assert(seenIndices.allSatisfy { $0 })
}
baz()
print("OK DONE with baz!")

func bar() {
    typealias Pool = NonBlockingThreadPool<PosixConcurrencyPlatform>
    let threadCount = 7
    let pool = Pool(name: "testThreadIndex", threadCount: threadCount)

    let condition = NSCondition()
    var threadsSeenCount = 0  // guarded by condition.
    var seenWorkItems = Set<Int>()

    for work in 0..<threadCount {
      pool.dispatch {
        condition.lock()
        threadsSeenCount += 1
        seenWorkItems.insert(work)
        if threadsSeenCount == threadCount {
          condition.signal()
        }
        condition.unlock()
      }
    }

    condition.lock()
    while threadsSeenCount != threadCount {
      condition.wait()
    }
    condition.unlock()
    pool.shutDown()
}

for i in 0..<100 {
print("About to run bar \(i)")
bar()
print("ran bar \(i)!")
}
print("DONE! kill me now.")
sleep(100)

@discardableResult
func time<T>(_ name: String, f: () -> T) -> T {
  let start = DispatchTime.now()
  let tmp = f()
  let end = DispatchTime.now()
  let nanoseconds = Double(end.uptimeNanoseconds - start.uptimeNanoseconds)
  let milliseconds = nanoseconds / 1e6
  print("\(name) \(milliseconds) ms")
  return tmp
}

func foo() {
  _ = Array(0..<100).pMap { elem -> Int in
    //            print("Thread.current.name: \(Thread.current.name).")
    return elem * 2
  }
}

let arraySize = 100_000_000

func sum() -> Int {
  let arr = Array(0..<arraySize)
  return arr.pSum()
}

print("Hello world!")
// print(time("psum") { sum() })
// //foo()
// print("Done!")
// time("sequential") {
//   Array(0..<arraySize).reduce(0, +)
// }
// print("Done 2!")

let fileName = "/Users/saeta/tmp/criteo/day_0_short"
let reader = try! CSVReader(file: fileName)
print("Metadata:\n\(reader.metadata!)")
print("\n\n====================================================\n\n")
let table = try! PTable(csv: fileName)
print(table)

let fileName2 = "/Users/saeta/tmp/movielens/ml-25m/genome-scores.csv"
let reader2 = try! CSVReader(file: fileName2)
print("Metadata:\n\(reader2.metadata!)")
print("\n\n====================================================\n\n")

let table2 = time("loading \(fileName2)") {
    try! PTable(csv: fileName2)
}

print(table2)
let grouped = time("grouping") {
    try! table2.group(by: "movieId", applying: .count, .mean)
}
print(grouped)
