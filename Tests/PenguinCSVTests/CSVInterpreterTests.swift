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

final class CSVInterpreterTests: XCTestCase {
  func testTypeCompatibility() {
    assertCompatible("", with: .string)
    assertCompatible(" ", with: .string)
    assertCompatible("asdf", with: .string)
    assertCompatible("1.0", with: .string)
    assertCompatible("  1.0", with: .string)
    assertCompatible("  -2.0  ", with: .string)
    assertCompatible("1", with: .string)
    assertCompatible("-3", with: .string)
    assertCompatible(" 1 ", with: .string)
    assertCompatible("300fdsa", with: .string)
    assertCompatible("NaN", with: .string)
    assertCompatible("-Inf", with: .string)
    assertCompatible("true", with: .string)
    assertCompatible(" True", with: .string)
    assertCompatible("f", with: .string)
    assertCompatible("FaLsE", with: .string)

    assertCompatible("", with: .int)
    assertNotCompatible("asdf", with: .int)
    assertNotCompatible("1.0", with: .int)
    assertNotCompatible("  1.0", with: .int)
    assertNotCompatible("  -2.0  ", with: .int)
    assertCompatible("1", with: .int)
    assertCompatible("-3", with: .int)
    assertCompatible(" 1 ", with: .int)
    assertNotCompatible("300fdsa", with: .int)
    assertNotCompatible("NaN", with: .int)
    assertNotCompatible("-Inf", with: .int)
    assertNotCompatible("true", with: .int)
    assertNotCompatible(" True", with: .int)
    assertNotCompatible("f", with: .int)
    assertNotCompatible("FaLsE", with: .int)

    assertCompatible("", with: .double)
    assertNotCompatible("asdf", with: .double)
    assertCompatible("1.0", with: .double)
    assertCompatible("  1.0", with: .double)
    assertCompatible("  -2.0  ", with: .double)
    assertCompatible("1", with: .double)
    assertCompatible("-3", with: .double)
    assertCompatible(" 1 ", with: .double)
    assertNotCompatible("300fdsa", with: .double)
    assertCompatible("NaN", with: .double)
    assertCompatible("-Inf", with: .double)
    assertNotCompatible("true", with: .double)
    assertNotCompatible(" True", with: .double)
    assertNotCompatible("f", with: .double)
    assertNotCompatible("FaLsE", with: .double)

    assertCompatible("", with: .bool)
    assertNotCompatible("asdf", with: .bool)
    assertNotCompatible("1.0", with: .bool)
    assertNotCompatible("  1.0", with: .bool)
    assertNotCompatible("  -2.0  ", with: .bool)
    assertCompatible("1", with: .bool)
    assertNotCompatible("-3", with: .bool)
    assertCompatible(" 1 ", with: .bool)
    assertNotCompatible("300fdsa", with: .bool)
    assertNotCompatible("NaN", with: .bool)
    assertNotCompatible("-Inf", with: .bool)
    assertCompatible("true", with: .bool)
    assertCompatible(" True", with: .bool)
    assertCompatible("f", with: .bool)
    assertCompatible("FaLsE", with: .bool)
  }

  func testPickSeparator() {
    var heuristics: [SeparatorHeuristics] = [
      .init(",", true, 0, 3, 3, false),
      .init("\t", false, 0, 1, 1, false),
      .init("|", false, 0, 1, 1, false),
    ]
    XCTAssertEqual(",", pickSeparator(heuristics))

    heuristics = [
      .init(",", false, 0, 2, 2, false),
      .init("\t", true, 0, 4, 4, false),
      .init("|", false, 0, 1, 1, false),
    ]
    XCTAssertEqual("\t", pickSeparator(heuristics))

    heuristics = [
      .init(",", true, 0, 3, 3, false),
      .init("\t", true, 0, 4, 4, false),
      .init("|", false, 0, 1, 1, false),
    ]
    XCTAssertEqual(",", pickSeparator(heuristics))

    heuristics = [
      .init(",", true, 1, 3, 3, false),
      .init("\t", true, 0, 5, 5, false),
      .init("|", false, 0, 1, 1, false),
    ]
    XCTAssertEqual("\t", pickSeparator(heuristics))

    heuristics = [
      .init(",", true, 0, 4, 4, false),
      .init("\t", true, 1, 6, 6, false),
      .init("|", false, 0, 2, 2, false),
    ]
    XCTAssertEqual(",", pickSeparator(heuristics))

    heuristics = [
      .init(",", true, 2, 7, 7, false),
      .init("\t", true, 1, 4, 4, false),
      .init("|", true, 0, 3, 3, false),
    ]
    XCTAssertEqual("|", pickSeparator(heuristics))

    heuristics = [
      .init(",", false, 2, 3, 3, false),
      .init("\t", false, 1, 4, 4, false),
      .init("|", false, 1, 5, 5, false),
    ]
    XCTAssertEqual(",", pickSeparator(heuristics))

  }

  func testComputingHeuristics() {
    assertParsedHeuristics(
      """
      a,b,c,d
      0,1,2,3
      4,5,6,7
      """,
      [
        .init(",", true, 0, 4, 4, false),
        .init("\t", false, 0, 1, 1, false),
        .init("|", false, 0, 1, 1, false),
      ])

    assertParsedHeuristics(
      """
      a\tb\tc\td
      0\t1\t2\t3
      4\t5\t6\t7
      """,
      [
        .init(",", false, 0, 1, 1, false),
        .init("\t", true, 0, 4, 4, false),
        .init("|", false, 0, 1, 1, false),
      ])
  }

  func testColumnGuesser() {
    checkColumnGuesser(expected: [.string], best: .string, cells: "asdf")
    checkColumnGuesser(expected: [.string, .double, .int], best: .int, cells: "1", "-2", " 10 ")
    checkColumnGuesser(
      expected: [.string, .double], best: .double, cells: "1.0", "  -2.3  ", "nan", "   NaN")
  }

  func testColumnTypeSniffing() {
    checkColumnSniffing(
      withoutFirstRow: [.string, .int, .double],
      withFirstRow: [.string, .string, .string],
      """
      foo,bar,baz
      abc,1,2.0
      1,-3,-3.14159
      """)

    checkColumnSniffing(
      withoutFirstRow: [.string, .int, .double, .string],
      withFirstRow: [.string, .string, .string, .string],
      """
      foo,bar,baz,quux
      abc,1,2.0,2
      1,-3,-3.14159,abc
      """)

    checkColumnSniffing(
      withoutFirstRow: [.int, .int, .double, .double],
      withFirstRow: [.string, .int, .double, .double],
      """
      abc,1,2.0,4
      1,-3,-3.14159,NaN
      """)
  }

  func testComputeColumnTypes() {
    XCTAssert(
      guessHasHeader(
        withFirstRowGuesses: [.string, .string, .string],
        withoutFirstRowGuesses: [.string, .int, .double]))

    XCTAssertFalse(
      guessHasHeader(
        withFirstRowGuesses: [.string, .int, .double],
        withoutFirstRowGuesses: [.int, .int, .double]))
  }

  func testComputeColumnNames() {
    checkComputeColumnNames(
      expected: ["foo", "bar", "baz"],
      """
      foo,bar,baz
      1,2,3
      4,5,6
      """)

    checkComputeColumnNames(
      expected: ["foo", "bar", "baz", "col_3", "col_4"],
      """
      foo,bar,baz
      1,2,3,10,11
      4,5,6,12,13
      """)
  }

  func testSniffCSVCommas() throws {
    let result = try sniffCSV(
      contents: """
        foo,bar,baz,quux
        abc,1,-2,NaN
        xyz,3.14159, 20 ,100
        partialfinalrow,
        """)
    XCTAssertEqual(",", result.separator)
    XCTAssert(result.hasHeaderRow, "\(result)")
    assertColumnNames(["foo", "bar", "baz", "quux"], result)
    assertColumnTypes([.string, .double, .int, .double], result)
  }

  func testSniffCSVTabs() throws {
    let result = try sniffCSV(
      contents: """
        foo\tbar\tbaz
        1\t2\t3
        4.4\t-5\t6
        partialfinalrow
        """)
    XCTAssertEqual("\t", result.separator)
    XCTAssert(result.hasHeaderRow)
    assertColumnNames(["foo", "bar", "baz"], result)
    assertColumnTypes([.double, .int, .int], result)
  }

  func testSniffCSVPipesDuplicateEmpties() throws {
    let result = try sniffCSV(
      contents: """
        foo|bar|baz|quux|foobar
        t|2|three|4.0|-5
        f|||6
        T|||
        F|200|three hundred|400.4|500

        """)
    XCTAssertEqual("|", result.separator)
    XCTAssert(result.hasHeaderRow)
    assertColumnNames(["foo", "bar", "baz", "quux", "foobar"], result)
    assertColumnTypes([.bool, .int, .string, .double, .int], result)
  }

  // TODO: test empty cells!
  // TODO: test extra columns in lower rows.
  // TODO: test non-partial final rows.
  // TODO: test non-utf8 encodings!

  static var allTests = [
    ("testTypeCompatibility", testTypeCompatibility),
    ("testPickSeparator", testPickSeparator),
    ("testComputingHeuristics", testComputingHeuristics),
    ("testColumnGuesser", testColumnGuesser),
    ("testColumnTypeSniffing", testColumnTypeSniffing),
    ("testComputeColumnTypes", testComputeColumnTypes),
    ("testComputeColumnNames", testComputeColumnNames),
    ("testSniffCSVCommas", testSniffCSVCommas),
    ("testSniffCSVTabs", testSniffCSVTabs),
    ("testSniffCSVPipesDuplicateEmpties", testSniffCSVPipesDuplicateEmpties),
  ]
}

fileprivate func assertCompatible(
  _ cell: String, with type: CSVType, file: StaticString = #file, line: UInt = #line
) {
  XCTAssert(
    type.isCompatibleWith(cell), "\(type) should be compatible with \(cell)", file: file, line: line
  )
}

fileprivate func assertNotCompatible(
  _ cell: String, with type: CSVType, file: StaticString = #file, line: UInt = #line
) {
  XCTAssertFalse(
    type.isCompatibleWith(cell), "\(type) should not be compatible with \(cell)", file: file,
    line: line)
}

fileprivate func assertParsedHeuristics(
  _ text: String, _ heuristics: [SeparatorHeuristics], file: StaticString = #file,
  line: UInt = #line
) {
  var text2 = text  // Make a mutable copy, as withUTF8 might modify the string.
  text2.withUTF8 { body in
    let lines = body.split(separator: UInt8(ascii: "\n"))
    precondition(lines.count > 2)
    let fullLines = lines[0..<lines.count - 1]  // Drop last linee as it could be incomplete.
    let separatorHeuristics = computeSeparatorHeuristics(fullLines)
    assertEqual(heuristics, separatorHeuristics, file: file, line: line)
  }
}

fileprivate func assertEqual(
  _ expected: [SeparatorHeuristics], _ actual: [SeparatorHeuristics], file: StaticString, line: UInt
) {
  for (i, elems) in zip(expected, actual).enumerated() {
    XCTAssert(
      elems.0 == elems.1,
      """
      Heuristics at index \(i) are unequal;
        expected: \(elems.0)
          actual: \(elems.1)
      overall:
        expected: \(expected)
          actual: \(actual)
      """, file: file, line: line)
  }
}

fileprivate func checkColumnGuesser(
  expected: [CSVType], best: CSVType, cells: String..., file: StaticString = #file,
  line: UInt = #line
) {
  var guesser = CSVColumnGuesser()
  for cell in cells {
    guesser.updateCompatibilities(cell: cell)
  }
  XCTAssertEqual(Set(expected), guesser.possibleTypes, "Cells: \(cells)", file: file, line: line)
  XCTAssertEqual(best, guesser.bestGuess, "Cells: \(cells)", file: file, line: line)
}

fileprivate func checkColumnSniffing(
  withoutFirstRow: [CSVType],
  withFirstRow: [CSVType],
  _ contents: String,
  separator: Unicode.Scalar = ",",
  file: StaticString = #file,
  line: UInt = #line
) {
  precondition(
    withoutFirstRow.count == withFirstRow.count,
    "Mismatched counts: \(withoutFirstRow.count) and \(withFirstRow.count)")
  var c = contents  // Must make a mutable copy first. :-(
  c.withUTF8 { contents in
    let lines = contents.split(separator: UInt8(ascii: "\n"))
    let allLines = lines[0..<lines.count]  // Don't drop the last one in tests!
    let result = try! computeColumnTypes(
      allLines, separator: separator, columnCount: withoutFirstRow.count)
    XCTAssertEqual(
      withoutFirstRow, result.withoutFirstRow.map { $0.bestGuess }, "Without first row problems!",
      file: file, line: line)
    XCTAssertEqual(
      withFirstRow, result.withFirstRow.map { $0.bestGuess }, "With first row problems!",
      file: file, line: line)
  }
}

fileprivate func checkComputeColumnNames(
  expected: [String], separator: Unicode.Scalar = ",", _ contents: String,
  file: StaticString = #file, line: UInt = #line
) {
  var c = contents
  c.withUTF8 { contents in
    let lines = contents.split(separator: UInt8(ascii: "\n"))
    let result = try! computeColumnNames(
      headerRow: lines[0], separator: separator, columnCount: expected.count)
    XCTAssertEqual(expected, result, file: file, line: line)
  }
}

fileprivate func assertColumnNames(
  _ expected: [String], _ result: CSVGuess, file: StaticString = #file, line: UInt = #line
) {
  let actual = result.columns.map { $0.name }
  XCTAssertEqual(expected, actual, file: file, line: line)
}

fileprivate func assertColumnTypes(
  _ expected: [CSVType], _ result: CSVGuess, file: StaticString = #file, line: UInt = #line
) {
  let actual = result.columns.map { $0.type }
  XCTAssertEqual(expected, actual, file: file, line: line)
}

extension SeparatorHeuristics {
  fileprivate init(
    _ separator: Unicode.Scalar,
    _ nonEmpty: Bool,
    _ differentCount: Int,
    _ columnCount: Int,
    _ firstRowColumnCount: Int,
    _ incompleteLastColumn: Bool
  ) {
    self.init(
      separator: separator,
      nonEmpty: nonEmpty,
      differentCount: differentCount,
      columnCount: columnCount,
      firstRowColumnCount: firstRowColumnCount,
      incompleteLastColumn: incompleteLastColumn
    )
  }
}
