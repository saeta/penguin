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
@testable import PenguinCSV

final class UTF8IteratorTests: XCTestCase {
    func testAscii() {
        let data = "hello world!".utf8CString.withUnsafeBytes { Data($0) }
        var itr = UTF8Parser(underlying: data.makeIterator())
        XCTAssertEqual(itr.next(), "h")
        XCTAssertEqual(itr.next(), "e")
        XCTAssertEqual(itr.next(), "l")
        XCTAssertEqual(itr.next(), "l")
        XCTAssertEqual(itr.next(), "o")
        XCTAssertEqual(itr.next(), " ")
        XCTAssertEqual(itr.next(), "w")
        XCTAssertEqual(itr.next(), "o")
        XCTAssertEqual(itr.next(), "r")
        XCTAssertEqual(itr.next(), "l")
        XCTAssertEqual(itr.next(), "d")
        XCTAssertEqual(itr.next(), "!")
    }

    func testNonAscii() {
        let data = "être".utf8CString.withUnsafeBytes { Data($0) }
        var itr = UTF8Parser(underlying: data.makeIterator())
        XCTAssertEqual(itr.next(), "ê")
        XCTAssertEqual(itr.next(), "t")
        XCTAssertEqual(itr.next(), "r")
        XCTAssertEqual(itr.next(), "e")
    }

    static var allTests = [
        ("testAscii", testAscii),
        ("testNonAscii", testNonAscii),
    ]
}
