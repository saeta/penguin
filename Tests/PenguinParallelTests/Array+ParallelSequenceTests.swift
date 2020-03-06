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

import XCTest
import PenguinParallel

final class ArrayParallelSequenceTests: XCTestCase {

    func testPSum() {
        let arr = Array(0..<100000)
        XCTAssertEqual(arr.pSum(), arr.reduce(0, +))
    }

    func testMap() {
        let arr = Array(200..<10000)
        let parallel = arr.pMap { (($0-500)..<$0).reduce(0, +) }
        let sequential = arr.map { (($0-500)..<$0).reduce(0, +) }
        XCTAssertEqual(parallel, sequential)
    }

    static var allTests = [
        ("testPSum", testPSum),
        ("testMap", testMap),
    ]
}
