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

public struct PColumnSummary {
    public var rowCount: Int = 0
    public var missingCount: Int = 0
    public var details: PDataTypeDetails?

    public var nonNilCount: Int {
        rowCount - missingCount
    }

    public var hasData: Bool {
        rowCount > missingCount
    }
}

public enum PDataTypeDetails {
    case numeric(_ details: PNumericDetails)
    case string(_ details: PStringDetails)
    case bool(_ details: PBoolDetails)
}

public struct PNumericDetails {
    public var min: Double = 0
    public var max: Double = 0
    public var sum: Double = 0
    public var mean: Double = 0
    public var stddev: Double = 0
    public var zeroCount: Int = 0
    public var negativeCount: Int = 0
    public var positiveCount: Int = 0
    public var nanCount: Int = 0
    public var infCount: Int = 0
    // TODO: quartiles!
}

public struct PStringDetails {
    public var min: String
    public var max: String
    public var longest: String
    public var shortest: String
    public var averageLength: Double
    public var asciiOnlyCount: Int

    public init(first: String) {
        self.min = first
        self.max = first
        self.longest = first
        self.shortest = first
        self.averageLength = Double(first.count)
        self.asciiOnlyCount = first.allSatisfy { $0.isASCII } ? 1 : 0
    }

    mutating func update(with value: String) {
        if value < min {
            self.min = value
        } else if value > max {
            self.max = value
        }

        if value.count > longest.count {
            self.longest = value
        } else if value.count < shortest.count {
            self.shortest = value
        }

        self.averageLength += Double(value.count)
        if value.allSatisfy({ $0.isASCII }) {
            self.asciiOnlyCount += 1
        }
    }
}

public struct PBoolDetails {
    public var trueCount: Int
    public var falseCount: Int
}

func computeNumericSummary<T: DoubleConvertible>(_ data: [T], _ nils: PIndexSet) -> PColumnSummary {
    var colSummary = computeBasicSummary(data, nils)

    guard colSummary.hasData else {
        // No actual data in this column...
        return colSummary
    }

    let nonNilCount = colSummary.nonNilCount
    var numericDetail: PNumericDetails? = nil

    for (isNil, val) in zip(nils.impl, data) {
        if isNil { continue }
        let valD = val.asDouble
        if numericDetail == nil {
            numericDetail = PNumericDetails()
            numericDetail!.min = valD
            numericDetail!.max = valD
        }
        numericDetail!.sum += valD
        numericDetail!.min = min(numericDetail!.min, valD)
        numericDetail!.max = max(numericDetail!.max, valD)
        if valD == 0 {
            numericDetail!.zeroCount &+= 1
        } else if valD < 0 {
            numericDetail!.negativeCount &+= 1
        } else if valD > 0 {
            numericDetail!.positiveCount &+= 1
        } else if valD.isNaN {
            numericDetail!.nanCount &+= 1
        } else if valD.isInfinite {
            numericDetail!.infCount &+= 1
        }
    }
    let mean = numericDetail!.sum / Double(nonNilCount)
    numericDetail!.mean = mean

    var variance = 0.0
    for (isNil, val) in zip(nils.impl, data) {
        if isNil { continue }
        let difference = val.asDouble - mean
        variance += difference * difference
    }
    numericDetail!.stddev = sqrt(variance)

    colSummary.details = .numeric(numericDetail!)
    return colSummary
}

func computeStringSummary(_ data: [String], _ nils: PIndexSet) -> PColumnSummary {
    var colSummary = computeBasicSummary(data, nils)

    guard data.count > nils.setCount else {
        // No actual data in this column...
        return colSummary
    }

    var stringDetail: PStringDetails? = nil
    for (isNil, val) in zip(nils.impl, data) {
        if isNil { continue }
        if stringDetail == nil {
            stringDetail = PStringDetails(first: val)
        } else {
            stringDetail!.update(with: val)
        }
    }
    stringDetail!.averageLength /= Double(colSummary.nonNilCount)
    colSummary.details = .string(stringDetail!)
    return colSummary
}

fileprivate func computeBasicSummary<T>(_ data: [T], _ nils: PIndexSet) -> PColumnSummary {
    precondition(data.count == nils.count)
    var colSummary = PColumnSummary()

    colSummary.rowCount = data.count
    colSummary.missingCount = nils.setCount

    return colSummary
}
