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

/// Errors that can be thrown during graph processing.
public enum GraphErrors: Error {
	/// No matching edge was found.
	case edgeNotFound
	/// Visitors can throw this error when they would like search to immediately halt.
	case stopSearch
	/// Thrown when an unexpected cycle is detected.
	case cycleDetected
}
