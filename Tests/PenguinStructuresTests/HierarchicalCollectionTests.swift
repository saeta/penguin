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
import PenguinStructures

struct TestError: Error {}

final class HierarchicalCollectionTests: XCTestCase {

    // We refactor our test in this way to ensure we're operating using only the
    // protocol based information.
    func checkArrayOperations<T: HierarchicalCollection>(
        on collection: T
    ) where T.Element == Int {
        XCTAssertEqual(10, collection.count)
        var i = 0
        collection.forEach {
            XCTAssertEqual(i, $0)
            i += 1
        }

        var seenSet = Set<Int>()
        collection.forEachWhile(startingAt: nil) { element in
            seenSet.insert(element)
            return element < 5
        }
        XCTAssertEqual(Set(0..<6), seenSet)

        let threeCursor = collection.firstIndex { $0 == 3 }!

        var partialSeenSet = Set<Int>()
        collection.forEachWhile(startingAt: threeCursor) { element in
            partialSeenSet.insert(element)
            return element < 5
        }
        XCTAssertEqual(Set(3..<6), partialSeenSet)

        do {
            try collection.forEachWhile(startingAt: nil) { element in
                throw TestError()
            }
            XCTFail("Should have thrown!")
        } catch is TestError {
            // success
        } catch {
            XCTFail("Invalid thing thrown... \(error)")
        }
    }

    func testLeafArray() {
        checkArrayOperations(on: LeafArray(Array(0..<10)))
    }

    func testHierarchicalArray() {
        let hierarchical = HierarchicalArray([
            LeafArray(Array(0..<5)),
            LeafArray(Array(5..<8)),
            LeafArray(Array(8..<10)),
        ])
        checkArrayOperations(on: hierarchical)
    }

    static var allTests = [
        ("testLeafArray", testLeafArray),
        ("testHierarchicalArray", testHierarchicalArray),
    ]
}
