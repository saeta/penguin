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

@testable import PenguinStructures
import XCTest

final class DequeInternalTests: XCTestCase {
    func testIndexComputedProperties() {
        typealias Index = Deque<Int>.Index

        XCTAssertEqual(0, Index(storage: 0).blockOffset)
        XCTAssertEqual(0, Index(storage: 0).blockID)

        XCTAssertEqual(5, Index(blockOffset: 5, blockID: 23).blockOffset)
        XCTAssertEqual(23, Index(blockOffset: 5, blockID: 23).blockID)

        XCTAssertEqual(
            UInt(bitPattern: Int(-105)) & Deque<Int>.maxBlockID,
            Index(blockOffset: 3096, blockID: UInt(bitPattern: Int(-105))).blockID)
    }

    static var allTests = [
        ("testIndexComputedProperties", testIndexComputedProperties),
    ]
}
