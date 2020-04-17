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

import Foundation

public protocol PStringParsible {
  init?(parsing: String)
  init(parseOrThrow value: String) throws
}

extension PStringParsible {
  public init?(parsing: String) {
    do {
      self = try Self.init(parseOrThrow: parsing)
    } catch {
      return nil
    }
  }
}

extension String: PStringParsible {
  public init(parseOrThrow value: String) {
    self = value
  }
}

extension Int: PStringParsible {
  public init(parseOrThrow value: String) throws {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let tmp = Int(trimmed) else {
      throw PError.unparseable(value: value, type: "Int")
    }
    self = tmp
  }
}

extension Float: PStringParsible {
  public init(parseOrThrow value: String) throws {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let tmp = Float(trimmed) else {
      throw PError.unparseable(value: value, type: "Float")
    }
    self = tmp
  }
}

extension Double: PStringParsible {
  public init(parseOrThrow value: String) throws {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let tmp = Double(trimmed) else {
      throw PError.unparseable(value: value, type: "Double")
    }
    self = tmp
  }
}

extension Bool: PStringParsible {
  public init(parseOrThrow value: String) throws {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if let tmp = Bool(trimmed) {
      self = tmp
      return
    }
    if trimmed == "t" || trimmed == "true" {
      self = true
      return
    }
    if trimmed == "f" || trimmed == "false" {
      self = false
      return
    }
    if let asInt = Int(trimmed) {
      if asInt == 0 {
        self = false
        return
      }
      if asInt == 1 {
        self = true
        return
      }
      throw PError.unparseable(value: value, type: "Bool")
    }
    throw PError.unparseable(value: value, type: "Bool")
  }
}
