import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(ArrayParallelSequenceTests.allTests),
        testCase(RangePipelineIteratorTests.allTests),
        testCase(SequencePipelineIteratorTests.allTests),
    ]
}
#endif
