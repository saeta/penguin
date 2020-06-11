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

import PenguinCSVTests
import PenguinGraphTests
import PenguinParallelTests
import PenguinPipelineTests
import PenguinStructuresTests
import PenguinTablesTests
import XCTest

var tests = [XCTestCaseEntry]()
tests += PenguinTablesTests.allTests()
tests += PenguinCSVTests.allTests()
tests += PenguinGraphTests.allTests()
tests += PenguinParallelTests.allTests()
tests += PenguinPipelineTests.allTests()
tests += PenguinStructuresTests.allTests()
XCTMain(tests)
