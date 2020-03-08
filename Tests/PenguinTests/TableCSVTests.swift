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
import PenguinCSV

final class TableCSVTests: XCTestCase {

    func testBooleanBuilder() {
        var builder = BooleanColumnBuilder()
        builder.testAppend("t")
        builder.testAppend("T")
        builder.testAppend("f")
        builder.testAppend("F")
        builder.testAppend(" t")
        builder.testAppend("  F")
        builder.testAppend(" TrUe ")
        builder.testAppend(" false ")
        builder.testAppend(" Foo")
        builder.testAppend(" Tralmost!")
        builder.testAppend("tru")
        builder.testAppend(". random")
        builder.testAppend("fals")
        builder.testAppend("")
        builder.testAppend("0")
        builder.testAppend("  1")
        let expected = [
            true,
            true,
            false,
            false,
            true,
            false,
            true,
            false,
            nil,
            nil,
            nil,
            nil,
            nil,
            nil,
            false,
            true,
        ]
        XCTAssertEqual(PColumn(expected), builder.finish())
    }

    func testIntBuilder() {
        var builder = NumericColumnBuilder<Int>()
        builder.testAppend(" 1")
        builder.testAppend(" 100 ")
        builder.testAppend("0")
        builder.testAppend("3")
        builder.testAppend(" 6")
        builder.testAppend(" false")
        builder.testAppend(" -103")

        let expected = [1, 100, 0, 3, 6, nil, -103]
        XCTAssertEqual(PColumn(expected), builder.finish())
    }

    func testBasicStringBuilder() {
        var builder = BasicStringColumnBuilder()
        builder.testAppend("foo")
        builder.testAppend("bar")
        builder.testAppend("foo")
        builder.testAppend("baz")
        builder.testAppend("foo")
        builder.testAppend("quux")
        builder.appendNil()

        let expected = [
            "foo",
            "bar",
            "foo",
            "baz",
            "foo",
            "quux",
            nil,
        ]
        XCTAssertEqual(PColumn(expected), builder.finish())

    }

    func testSimpleParse() throws {
        let table = try PTable(csvContents: """
            a,b,c,d
            asdf,1,f,3.1
            fdsa,4,t,6.2
            """)

        let colA = PColumn(["asdf", "fdsa"])
        let colB = PColumn([1, 4])
        let colC = PColumn([false, true])
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
        ("testBooleanBuilder", testBooleanBuilder),
        ("testIntBuilder", testIntBuilder),
        ("testBasicStringBuilder", testBasicStringBuilder),
        ("testSimpleParse", testSimpleParse),
        ("testTsvParseWithTrailingNewline", testTsvParseWithTrailingNewline)
    ]
}

fileprivate extension BooleanColumnBuilder {
    mutating func testAppend(_ testValue: String) {
        testBuilderRawParsing(&self, cell: testValue)
    }
}

fileprivate extension NumericColumnBuilder {
    mutating func testAppend(_ testValue: String) {
        testBuilderRawParsing(&self, cell: testValue)
    }
}

fileprivate extension BasicStringColumnBuilder {
    mutating func testAppend(_ testValue: String) {
        testBuilderRawParsing(&self, cell: testValue)
    }
}

fileprivate func testBuilderRawParsing<Builder: ColumnBuilder>(
    _ builder: inout Builder,
    cell: String
) {
    var copy = cell
    copy.withUTF8 {
        let cell = CSVCell.raw($0)
        builder.append(cell)
    }
}
