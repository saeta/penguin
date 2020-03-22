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

final class IndexSetTests: XCTestCase {

    func testInitializer() {
        let s = PIndexSet(indices: [1, 4, 8], count: 10)
        XCTAssertEqual(s,
                       PIndexSet([false,
                                  true,
                                  false,
                                  false,
                                  true,
                                  false,
                                  false,
                                  false,
                                  true,
                                  false],
                                 setCount: 3))
    }

    func testUnion() {
        let lhs = PIndexSet([true, false, false, true], setCount: 2)
        let rhs = PIndexSet([true, true, false, false], setCount: 2)
        let expected = PIndexSet([true, true, false, true], setCount: 3)
        XCTAssertEqual(try! lhs.unioned(rhs), expected)
    }

    func testUnionExtension() {
        let lhs = PIndexSet([true, false, true, false], setCount: 2)
        let rhs = PIndexSet([true, true], setCount: 2)
        let expected = PIndexSet([true, true, true, false], setCount: 3)
        XCTAssertEqual(try! lhs.unioned(rhs, extending: true), expected)
        XCTAssertEqual(try! rhs.unioned(lhs, extending: true), expected)
    }

    func testIntersect() {
        let lhs = PIndexSet([true, false, false, true], setCount: 2)
        let rhs = PIndexSet([true, true, false, false], setCount: 2)
        let expected = PIndexSet([true, false, false, false], setCount: 1)
        XCTAssertEqual(try! lhs.intersected(rhs), expected)
    }

    func testIntersectExtension() {
        let lhs = PIndexSet([true, false, true, false], setCount: 2)
        let rhs = PIndexSet([true, true], setCount: 2)
        let expected = PIndexSet([true, false, false, false], setCount: 1)
        XCTAssertEqual(try! lhs.intersected(rhs, extending: true), expected)
        XCTAssertEqual(try! rhs.intersected(lhs, extending: true), expected)
    }

    func testNegate() {
        let s = PIndexSet([true, false, true, false, false], setCount: 2)
        let expected = PIndexSet([false, true, false, true, true], setCount: 3)
        XCTAssertEqual(!s, expected)
    }

    func testIsEmpty() {
        XCTAssertTrue(PIndexSet([false, false, false], setCount: 0).isEmpty)
        XCTAssertFalse(PIndexSet([true, false], setCount: 1).isEmpty)
    }

    func testAllInitializer() {
        XCTAssertEqual(PIndexSet(all: true, count: 2), PIndexSet([true, true], setCount: 2))
        XCTAssertEqual(PIndexSet(all: false, count: 3), PIndexSet([false, false, false], setCount: 0))
    }

    func testSorting() {
        let indices = [2, 3, 1, 0]
        XCTAssertEqual(PIndexSet([true, false, true, false], setCount: 2).gathering(indices),
                       PIndexSet([true, false, false, true], setCount: 2))
    }

    func testEmptyInit() {
        let s = PIndexSet(empty: false)
        XCTAssertEqual(0, s.setCount)
        XCTAssertEqual([], s.impl)
    }

    func testAppend() {
        var s = PIndexSet(empty: false)
        s.append(false)
        s.append(true)
        s.append(false)
        s.append(true)

        let expected = PIndexSet([false, true, false, true], setCount: 2)
        XCTAssertEqual(expected, s)
    }

    func testIndexIterator() {
        let s = PIndexSet([true, false, false, true, false, true, false], setCount: 3)
        var itr = s.makeIndexIterator()
        XCTAssertEqual(0, itr.next())
        XCTAssertEqual(3, itr.next())
        XCTAssertEqual(5, itr.next())
        XCTAssertEqual(nil, itr.next())
    }

    static var allTests = [
        ("testInitializer", testInitializer),
        ("testUnion", testUnion),
        ("testUnionExtension", testUnionExtension),
        ("testIntersect", testIntersect),
        ("testIntersectExtension", testIntersectExtension),
        ("testNegate", testNegate),
        ("testIsEmpty", testIsEmpty),
        ("testAllInitializer", testAllInitializer),
        ("testSorting", testSorting),
        ("testEmptyInit", testEmptyInit),
        ("testAppend", testAppend),
        ("testIndexIterator", testIndexIterator),
    ]
}
