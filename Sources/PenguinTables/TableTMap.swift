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

extension PTable {
  public func tmap<
    O: ElementRequirements,
    T1: ElementRequirements
  >(
    _ c1: String,
    fn: (T1) throws -> O
  ) rethrows -> PTypedColumn<O> {
    guard let col1 = columnMapping[c1] else { preconditionFailure("Unknown column \(c1).") }
    let tCol1: PTypedColumn<T1> = try! col1.asDType()

    // TODO: Aggregate into a PTypedColumn instead of an array.
    var output = [O]()
    output.reserveCapacity(count!)
    var nils = [Bool]()
    nils.reserveCapacity(count!)
    var nilCount = 0

    for i in 0..<count! {
      guard let a1 = tCol1[i] else {
        nils.append(true)
        nilCount += 1
        continue
      }
      try output.append(fn(a1))
      nils.append(false)
    }
    return PTypedColumn(output, nils: PIndexSet(nils, setCount: nilCount))
  }

  public func tmap<
    O: ElementRequirements,
    T1: ElementRequirements,
    T2: ElementRequirements
  >(
    _ c1: String,
    _ c2: String,
    fn: (T1, T2) throws -> O
  ) rethrows -> PTypedColumn<O> {
    guard let col1 = columnMapping[c1] else { preconditionFailure("Unknown column \(c1).") }
    let tCol1: PTypedColumn<T1> = try! col1.asDType()
    guard let col2 = columnMapping[c2] else { preconditionFailure("Unknown column \(c2).") }
    let tCol2: PTypedColumn<T2> = try! col2.asDType()

    // TODO: Aggregate into a PTypedColumn instead of an array.
    var output = [O]()
    output.reserveCapacity(count!)
    var nils = [Bool]()
    nils.reserveCapacity(count!)
    var nilCount = 0

    for i in 0..<count! {
      guard let a1 = tCol1[i] else {
        nils.append(true)
        nilCount += 1
        continue
      }
      guard let a2 = tCol2[i] else {
        nils.append(true)
        nilCount += 1
        continue
      }
      try output.append(fn(a1, a2))
      nils.append(false)
    }
    return PTypedColumn(output, nils: PIndexSet(nils, setCount: nilCount))
  }

  public func tmap<
    O: ElementRequirements,
    T1: ElementRequirements,
    T2: ElementRequirements,
    T3: ElementRequirements
  >(
    _ c1: String,
    _ c2: String,
    _ c3: String,
    fn: (T1, T2, T3) throws -> O
  ) rethrows -> PTypedColumn<O> {
    guard let col1 = columnMapping[c1] else { preconditionFailure("Unknown column \(c1).") }
    let tCol1: PTypedColumn<T1> = try! col1.asDType()
    guard let col2 = columnMapping[c2] else { preconditionFailure("Unknown column \(c2).") }
    let tCol2: PTypedColumn<T2> = try! col2.asDType()
    guard let col3 = columnMapping[c3] else { preconditionFailure("Unknown column \(c3).") }
    let tCol3: PTypedColumn<T3> = try! col3.asDType()

    // TODO: Aggregate into a PTypedColumn instead of an array.
    var output = [O]()
    output.reserveCapacity(count!)
    var nils = [Bool]()
    nils.reserveCapacity(count!)
    var nilCount = 0

    for i in 0..<count! {
      guard let a1 = tCol1[i] else {
        nils.append(true)
        nilCount += 1
        continue
      }
      guard let a2 = tCol2[i] else {
        nils.append(true)
        nilCount += 1
        continue
      }
      guard let a3 = tCol3[i] else {
        nils.append(true)
        nilCount += 1
        continue
      }
      try output.append(fn(a1, a2, a3))
      nils.append(false)
    }
    return PTypedColumn(output, nils: PIndexSet(nils, setCount: nilCount))
  }

  public func tmap<
    O: ElementRequirements,
    T1: ElementRequirements,
    T2: ElementRequirements,
    T3: ElementRequirements,
    T4: ElementRequirements
  >(
    _ c1: String,
    _ c2: String,
    _ c3: String,
    _ c4: String,
    fn: (T1, T2, T3, T4) throws -> O
  ) rethrows -> PTypedColumn<O> {
    guard let col1 = columnMapping[c1] else { preconditionFailure("Unknown column \(c1).") }
    let tCol1: PTypedColumn<T1> = try! col1.asDType()
    guard let col2 = columnMapping[c2] else { preconditionFailure("Unknown column \(c2).") }
    let tCol2: PTypedColumn<T2> = try! col2.asDType()
    guard let col3 = columnMapping[c3] else { preconditionFailure("Unknown column \(c3).") }
    let tCol3: PTypedColumn<T3> = try! col3.asDType()
    guard let col4 = columnMapping[c4] else { preconditionFailure("Unknown column \(c4).") }
    let tCol4: PTypedColumn<T4> = try! col4.asDType()

    // TODO: Aggregate into a PTypedColumn instead of an array.
    var output = [O]()
    output.reserveCapacity(count!)
    var nils = [Bool]()
    nils.reserveCapacity(count!)
    var nilCount = 0

    for i in 0..<count! {
      guard let a1 = tCol1[i] else {
        nils.append(true)
        nilCount += 1
        continue
      }
      guard let a2 = tCol2[i] else {
        nils.append(true)
        nilCount += 1
        continue
      }
      guard let a3 = tCol3[i] else {
        nils.append(true)
        nilCount += 1
        continue
      }
      guard let a4 = tCol4[i] else {
        nils.append(true)
        nilCount += 1
        continue
      }
      try output.append(fn(a1, a2, a3, a4))
      nils.append(false)
    }
    return PTypedColumn(output, nils: PIndexSet(nils, setCount: nilCount))
  }

  public func tmap<
    O: ElementRequirements,
    T1: ElementRequirements,
    T2: ElementRequirements,
    T3: ElementRequirements,
    T4: ElementRequirements,
    T5: ElementRequirements
  >(
    _ c1: String,
    _ c2: String,
    _ c3: String,
    _ c4: String,
    _ c5: String,
    fn: (T1, T2, T3, T4, T5) throws -> O
  ) rethrows -> PTypedColumn<O> {
    guard let col1 = columnMapping[c1] else { preconditionFailure("Unknown column \(c1).") }
    let tCol1: PTypedColumn<T1> = try! col1.asDType()
    guard let col2 = columnMapping[c2] else { preconditionFailure("Unknown column \(c2).") }
    let tCol2: PTypedColumn<T2> = try! col2.asDType()
    guard let col3 = columnMapping[c3] else { preconditionFailure("Unknown column \(c3).") }
    let tCol3: PTypedColumn<T3> = try! col3.asDType()
    guard let col4 = columnMapping[c4] else { preconditionFailure("Unknown column \(c4).") }
    let tCol4: PTypedColumn<T4> = try! col4.asDType()
    guard let col5 = columnMapping[c5] else { preconditionFailure("Unknown column \(c5).") }
    let tCol5: PTypedColumn<T5> = try! col5.asDType()

    // TODO: Aggregate into a PTypedColumn instead of an array.
    var output = [O]()
    output.reserveCapacity(count!)
    var nils = [Bool]()
    nils.reserveCapacity(count!)
    var nilCount = 0

    for i in 0..<count! {
      guard let a1 = tCol1[i] else {
        nils.append(true)
        nilCount += 1
        continue
      }
      guard let a2 = tCol2[i] else {
        nils.append(true)
        nilCount += 1
        continue
      }
      guard let a3 = tCol3[i] else {
        nils.append(true)
        nilCount += 1
        continue
      }
      guard let a4 = tCol4[i] else {
        nils.append(true)
        nilCount += 1
        continue
      }
      guard let a5 = tCol5[i] else {
        nils.append(true)
        nilCount += 1
        continue
      }
      try output.append(fn(a1, a2, a3, a4, a5))
      nils.append(false)
    }
    return PTypedColumn(output, nils: PIndexSet(nils, setCount: nilCount))
  }

  public func tmap<
    O: ElementRequirements,
    T1: ElementRequirements,
    T2: ElementRequirements,
    T3: ElementRequirements,
    T4: ElementRequirements,
    T5: ElementRequirements,
    T6: ElementRequirements
  >(
    _ c1: String,
    _ c2: String,
    _ c3: String,
    _ c4: String,
    _ c5: String,
    _ c6: String,
    fn: (T1, T2, T3, T4, T5, T6) throws -> O
  ) rethrows -> PTypedColumn<O> {
    guard let col1 = columnMapping[c1] else { preconditionFailure("Unknown column \(c1).") }
    let tCol1: PTypedColumn<T1> = try! col1.asDType()
    guard let col2 = columnMapping[c2] else { preconditionFailure("Unknown column \(c2).") }
    let tCol2: PTypedColumn<T2> = try! col2.asDType()
    guard let col3 = columnMapping[c3] else { preconditionFailure("Unknown column \(c3).") }
    let tCol3: PTypedColumn<T3> = try! col3.asDType()
    guard let col4 = columnMapping[c4] else { preconditionFailure("Unknown column \(c4).") }
    let tCol4: PTypedColumn<T4> = try! col4.asDType()
    guard let col5 = columnMapping[c5] else { preconditionFailure("Unknown column \(c5).") }
    let tCol5: PTypedColumn<T5> = try! col5.asDType()
    guard let col6 = columnMapping[c6] else { preconditionFailure("Unknown column \(c6).") }
    let tCol6: PTypedColumn<T6> = try! col6.asDType()

    // TODO: Aggregate into a PTypedColumn instead of an array.
    var output = [O]()
    output.reserveCapacity(count!)
    var nils = [Bool]()
    nils.reserveCapacity(count!)
    var nilCount = 0

    for i in 0..<count! {
      guard let a1 = tCol1[i] else {
        nils.append(true)
        nilCount += 1
        continue
      }
      guard let a2 = tCol2[i] else {
        nils.append(true)
        nilCount += 1
        continue
      }
      guard let a3 = tCol3[i] else {
        nils.append(true)
        nilCount += 1
        continue
      }
      guard let a4 = tCol4[i] else {
        nils.append(true)
        nilCount += 1
        continue
      }
      guard let a5 = tCol5[i] else {
        nils.append(true)
        nilCount += 1
        continue
      }
      guard let a6 = tCol6[i] else {
        nils.append(true)
        nilCount += 1
        continue
      }
      try output.append(fn(a1, a2, a3, a4, a5, a6))
      nils.append(false)
    }
    return PTypedColumn(output, nils: PIndexSet(nils, setCount: nilCount))
  }
}
