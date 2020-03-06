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

final class TableCSVTests: XCTestCase {
    func testSimpleParse() throws {
        let table = try PTable(csvContents: """
            a,b,c,d
            asdf,1,2,3.1
            fdsa,4,5,6.2
            """)

        let colA = PColumn(["asdf", "fdsa"])
        let colB = PColumn([1, 4])
        let colC = PColumn([2, 5])
        let colD = PColumn([3.1, 6.2])
        let expected = try! PTable([("a", colA), ("b", colB), ("c", colC), ("d", colD)])
        XCTAssertEqual(expected, table)
    }

    func testTsvParseWithTrailingNewline() throws {
        let table = try PTable(csvContents: """
        a\tb\tc
        Pi\t3.14159\t-100
        e\t2.71828\t200

        """)
        let colA = PColumn(["Pi", "e"])
        let colB = PColumn([3.14159, 2.71828])
        let colC = PColumn([-100, 200])
        let expected = try! PTable([("a", colA), ("b", colB), ("c", colC)])
        XCTAssertEqual(expected, table)
    }

    static var allTests = [
        ("testSimpleParse", testSimpleParse),
        ("testTsvParseWithTrailingNewline", testTsvParseWithTrailingNewline)
    ]
}
