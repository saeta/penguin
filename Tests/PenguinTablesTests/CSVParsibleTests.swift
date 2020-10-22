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

import PenguinCSV
import XCTest

@testable import PenguinTables

final class CSVParsibleTests: XCTestCase {
  func testIntParsing() throws {
    assertParse(" 1", as: 1)
    assertParse("0", as: 0)
    assertParse(" 100 ", as: 100)
    assertParse(" -123", as: -123)
  }

  static var allTests = [
    ("testIntParsing", testIntParsing)
  ]
}

#if swift(>=5.3)
fileprivate func assertParse<T: PCSVParsible & Equatable>(
  _ bytes: String,
  as val: T,
  file: StaticString = #filePath,
  line: UInt = #line
) {
  var s = bytes
  s.withUTF8 { s in
    let parsed = T(CSVCell.raw(s))
    XCTAssertEqual(parsed, val, file: file, line: line)
  }
}
#else
fileprivate func assertParse<T: PCSVParsible & Equatable>(
  _ bytes: String,
  as val: T,
  file: StaticString = #file,
  line: UInt = #line
) {
  var s = bytes
  s.withUTF8 { s in
    let parsed = T(CSVCell.raw(s))
    XCTAssertEqual(parsed, val, file: file, line: line)
  }
}
#endif
