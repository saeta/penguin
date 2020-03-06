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

import PenguinParallel
import PenguinCSV
import Penguin
import Dispatch
import Foundation

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
print(time("psum") { sum() })
//foo()
print("Done!")
time("sequential") {
    Array(0..<arraySize).reduce(0, +)
}
print("Done 2!")


let fileName = "/Users/saeta/tmp/criteo/day_0_short"
let reader = try! CSVReader(file: fileName)
print("Metadata:\n\(reader.metadata!)")
let table = try! PTable(csv: fileName)
print(table)
