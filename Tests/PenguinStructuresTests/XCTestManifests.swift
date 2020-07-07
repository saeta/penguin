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
      // Please maintain this list in alphabetical order.
      testCase(AnyArrayBufferTests.allTests),
      testCase(ArrayBufferTests.allTests),
      testCase(ArrayStorageExtensionTests.allTests),
      testCase(ArrayStorageTests.allTests),
      testCase(CollectionAlgorithmTests.allTests),
      testCase(DequeTests.allTests),
      testCase(DoubleEndedBufferTests.allTests),
      testCase(FactoryInitializableTests.allTests),
      testCase(FixedSizeArrayTests.allTests),
      testCase(HeapTests.allTests),
      testCase(HierarchicalCollectionTests.allTests),
      testCase(NominalElementDictionaryTests.allTests),
      testCase(PCGRandomNumberGeneratorTests.allTests),
      testCase(RandomTests.allTests),
      testCase(TupleTests.allTests),
      testCase(UnsignedInteger_ReducedTests.allTests),
    ]
  }
#endif
