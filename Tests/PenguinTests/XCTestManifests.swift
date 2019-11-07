import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(PenguinTests.allTests),
        testCase(TypedColumnTests.allTests),
        testCase(ColumnTests.allTests),
    ]
}
#endif
