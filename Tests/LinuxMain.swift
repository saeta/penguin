import XCTest

import PenguinTests
import PenguinCSVTests

var tests = [XCTestCaseEntry]()
tests += PenguinTests.allTests()
tests += PenguinCSVTests.allTests()
XCTMain(tests)
