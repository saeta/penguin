import XCTest

import PenguinTests
import PenguinCSVTests
import PenguinParallelTests

var tests = [XCTestCaseEntry]()
tests += PenguinTests.allTests()
tests += PenguinCSVTests.allTests()
tests += PenguinParallelTests.allTests()
XCTMain(tests)
