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
@testable import PenguinParallel

final class ParallelUtilitiesTests: XCTestCase {
    func testComputeRecursiveDepth() {
        XCTAssertEqual(6, computeRecursiveDepth(procCount: 64))
        XCTAssertEqual(7, computeRecursiveDepth(procCount: 72))
        XCTAssertEqual(7, computeRecursiveDepth(procCount: 112))
        XCTAssertEqual(4, computeRecursiveDepth(procCount: 12))
    }

    static var allTests = [
        ("testComputeRecursiveDepth", testComputeRecursiveDepth),
    ]
}
