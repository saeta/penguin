import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(ColumnTests.allTests),
        testCase(IndexSetTests.allTests),
        testCase(PenguinTests.allTests),
        testCase(TableTests.allTests),
        testCase(TypedColumnTests.allTests),
    ]
}
#endif
