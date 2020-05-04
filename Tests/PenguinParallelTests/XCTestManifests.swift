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

#if !canImport(ObjectiveC)
  public func allTests() -> [XCTestCaseEntry] {
    return [
      testCase(ArrayParallelSequenceTests.allTests),
      testCase(ComputeThreadPoolTests.allTests),
      testCase(FunctionGeneratorPipelineIteratorTests.allTests),
      testCase(InterleavePipelineIteratorTests.allTests),
      testCase(NaiveThreadPoolTests.allTests),
      testCase(NonblockingConditionTests.allTests),
      testCase(NonBlockingThreadPoolTests.allTests),
      testCase(ParallelUtilitiesTests.allTests),
      testCase(PosixConcurrencyPlatformTests.allTests),
      testCase(PrefetchBufferTests.allTests),
      testCase(PrefetchPipelineIteratorTests.allTests),
      testCase(RandomCollectionPipelineIteratorTests.allTests),
      testCase(RandomIndiciesIteratorTests.allTests),
      testCase(RangePipelineIteratorTests.allTests),
      testCase(ReduceWindowIteratorTests.allTests),
      testCase(SequencePipelineIteratorTests.allTests),
      testCase(TakePipelineIteratorTests.allTests),
      testCase(TaskDequeTests.allTests),
      testCase(TransformPipelineIteratorTests.allTests),
      testCase(ZipPipelineIteratorTests.allTests),
    ]
  }
#endif
