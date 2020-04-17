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

/// Conform Bool to comparible.
///
/// This is required in order to use Bool's inside of Penguin.
extension Bool: Comparable {

    /// Comparis lhs to rhs.
    ///
    /// Returns true if lhs is false, and rhs is true, false otherwise.
    /// This definition was chosen in order to match the behavior of a UInt-equivalent
    /// representation, where false is represented as 0, and true as any other number.
    public static func < (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (false, true): return true
        case (true, false): return false
        case (true, true): return false
        case (false, false): return false
        }
    }
}
