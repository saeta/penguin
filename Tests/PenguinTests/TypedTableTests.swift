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

final class TypedTableTests: XCTestCase {
    struct TestSchema1: PTableSchema {
        var c1: Int = 0
        var c2: String = ""
        var c3: Double = 0.0

#if !canImport(TensorFlow)
        var allKeyPaths: [PartialKeyPath<Self>] {
            [\Self.c1, \Self.c2, \Self.c3]
        }

        var keyPathsToMemberNames: [PartialKeyPath<Self>: String] {
            [\Self.c1: "c1", \Self.c2: "c2", \Self.c3: "c3"]
        }
#endif
    }

    func testBasicTypedTableConstruction() {
        let c1 = PTypedColumn([1, 2, 3])
        let c2 = PTypedColumn(["a", "b", "c"])
        let c3 = PTypedColumn([1.0, 2.0, 3.0])
        let table = try! PTypedTable<TestSchema1>(PTable([
            "c1": PColumn(c1),
            "c2": PColumn(c2),
            "c3": PColumn(c3)
        ]))

        XCTAssertEqual(c1, table.c1)
        XCTAssertEqual(c2, table.c2)
        XCTAssertEqual(c3, table.c3)
    }


    func testInvalidSchemaWrongDType() {
        let c1 = PTypedColumn([1, 2, 3])
        let c2 = PTypedColumn(["a", "b", "c"])
        let c3 = PTypedColumn([1, 2, 3])  // Ints not double's
        do {
            _ = try PTypedTable<TestSchema1>(PTable([
                "c1": PColumn(c1),
                "c2": PColumn(c2),
                "c3": PColumn(c3)
            ]))
            XCTFail("Expected an error of type mis-match to be thrown!")
        } catch {
            // Expected
        }
    }

    static var allTests = [
        ("testBasicTypedTableConstruction", testBasicTypedTableConstruction),
        ("testInvalidSchemaWrongDType", testInvalidSchemaWrongDType),
    ]
}