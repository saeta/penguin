import Foundation

public struct PColumnSummary {
    public var rowCount: Int = 0
    public var missingCount: Int = 0
    public var details: PDataTypeDetails?
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
}

public struct PBoolDetails {
    public var trueCount: Int
    public var falseCount: Int
}

func computeNumericSummary<T: DoubleConvertible>(_ data: [T], _ nils: PIndexSet) -> PColumnSummary {
    precondition(data.count == nils.count)
    var colSummary = PColumnSummary()

    colSummary.rowCount = data.count
    colSummary.missingCount = nils.setCount

    guard data.count > nils.setCount else {
        // No actual data in this column...
        return colSummary
    }

    let nonNilCount = colSummary.rowCount - colSummary.missingCount
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
