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
@testable import Penguin

final class ColumnTests: XCTestCase {
    func testIntConversion() {
        let c: PColumn = PColumn([1, 2, 3, 4])
        XCTAssertEqual(c.count, 4)
        XCTAssertEqual(c.asInt(), PTypedColumn<Int>([1, 2, 3, 4]))
    }

    func testStringConversion() {
        let c: PColumn = PColumn(["a", "b", "c"])
        XCTAssertEqual(c.count, 3)
        XCTAssertEqual(c.asString(), PTypedColumn<String>(["a", "b", "c"]))

    }

    func testDoubleConversion() {
        let c: PColumn = PColumn([1.0, 2.0, 3.0])
        XCTAssertEqual(c.count, 3)
        XCTAssertEqual(c.asDouble(), PTypedColumn<Double>([1.0, 2.0, 3.0]))
    }

    func testBoolConversion() {
        let c = PColumn([false, true, false, nil])
        XCTAssertEqual(4, c.count)
        XCTAssertEqual(1, c.nils.setCount)
        XCTAssertEqual(c.asBool(), PTypedColumn<Bool>([false, true, false, nil]))
    }

    func testNumericSummary() throws {
        let c = PColumn([nil, 3.14, -2.718281828, nil, 6.28, 1000, nil, 0, -5, 10])
        let summary = c.summarize()
        XCTAssertEqual(10, summary.rowCount)
        XCTAssertEqual(3, summary.missingCount)
        let details = try assertNumericDetails(summary)
        XCTAssertEqual(-5, details.min)
        XCTAssertEqual(1000, details.max)
    }

    func testStringSummary() throws {
        let c = PColumn([nil, "a", "bc", "def", "être", nil])
        let summary = c.summarize()
        XCTAssertEqual(6, summary.rowCount)
        XCTAssertEqual(2, summary.missingCount)
        let details = try assertStringDetails(summary)
        XCTAssertEqual("a", details.min)
        XCTAssertEqual("être", details.max)
        XCTAssertEqual(3, details.asciiOnlyCount)
    }

    static var allTests = [
        ("testIntConversion", testIntConversion),
        ("testStringConversion", testStringConversion),
        ("testDoubleConversion", testDoubleConversion),
        ("testBoolConversion", testBoolConversion),
        ("testNumericSummary", testNumericSummary),
        ("testStringSummary", testStringSummary),
    ]
}
