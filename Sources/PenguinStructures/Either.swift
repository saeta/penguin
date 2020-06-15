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

/// Represents one of two possible choices.
public enum Either<A, B> {
  case a(A)
  case b(B)
}

extension Either: Equatable where A: Equatable, B: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case (.a(let lhs), .a(let rhs)): return lhs == rhs
    case (.b(let lhs), .b(let rhs)): return lhs == rhs
    default: return false
    }
  }
}

extension Either: Comparable where A: Comparable, B: Comparable {
  public static func < (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case (.a(let lhs), .a(let rhs)): return lhs < rhs
    case (.a, _): return true
    case (.b(let lhs), .b(let rhs)): return lhs < rhs
    default: return false
    }
  }
}


extension Either: Hashable where A: Hashable, B: Hashable {
  public func hash(into hasher: inout Hasher) {
    switch self {
    case .a(let a): a.hash(into: &hasher)
    case .b(let b): b.hash(into: &hasher)
    }
  }
}
