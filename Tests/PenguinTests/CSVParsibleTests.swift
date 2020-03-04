import XCTest
@testable import Penguin
import PenguinCSV

final class CSVParsibleTests: XCTestCase {
	func testIntParsing() throws {
		print("one")
		assertParse(" 1", as: 1)
		assertParse("0", as: 0)
		print("three")
		assertParse(" 100 ", as: 100)
		print("four")
		assertParse(" -123", as: -123)
		print("five")
	}

	static var allTests = [
		("testIntParsing", testIntParsing),
	]
}

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
