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

public class Aggregation {
    // Note: Aggregation can't be a protocol because static members cannot be
    // used on protocol metatype.

    init(name: String, isGlobal: Bool = false) {
        self.name = name
        self.isGlobal = isGlobal
    }

    func build(for column: PColumn) -> AggregationEngine? { fatalError("Unimplemented.") }

    let name: String
    let isGlobal: Bool
}

public class NumericAggregation: Aggregation {
    func build<T: Numeric & ElementRequirements>(for column: PTypedColumn<T>) -> AggregationEngine {
        fatalError("Unimplemented.")
    }

    override func build(for column: PColumn) -> AggregationEngine? {
        column.buildNumericGroupByOp(for: self)
    }
}

public class DoubleConvertibleAggregation: Aggregation {
    func build<T: ElementRequirements & DoubleConvertible>(for column: PTypedColumn<T>) -> AggregationEngine {
        fatalError("Unimplemented.")
    }

    override func build(for column: PColumn) -> AggregationEngine? {
        column.buildDoubleConvertibleGroupByOp(for: self)
    }
}

public class ArbitraryTypedAggregation: Aggregation {
    func build<T: ElementRequirements>(for column: PTypedColumn<T>) -> AggregationEngine {
        fatalError("Unimplemented.")
    }

    override func build(for column: PColumn) -> AggregationEngine? {
        column.buildGroupByOp(for: self)
    }
}

class StringAggregation<Op: AggregationOperation>: Aggregation where Op.Input == String {
    init(name: String, factory: @escaping () -> Op) {
        self.factory = factory
        super.init(name: name)
    }

    override func build(for column: PColumn) -> AggregationEngine? {
        if let col: PTypedColumn<String> = try? column.asDType() {
            return AggregationEngine.build(op: Op.self, for: col, with: factory)
        }
        return nil
    }

    var factory: () -> Op
}

public class AggregationEngine {
    fileprivate init() {}

    // TODO: fix this up to work for parallelism!
    func next(is group: Int) {
        fatalError("Must override!")
    }

    // TODO: fix for parallelism!
    func finish() -> PColumn {
        fatalError("Must override!")
    }
}

final class AggregationEngineImpl<Op: AggregationOperation>: AggregationEngine {
    fileprivate init(
        _ column: PTypedColumn<Op.Input>,
        builder: @escaping () -> Op
    ) {
        self.column = column
        self.builder = builder
        // self.iterator = column.makeIterator()
    }

    override func next(is group: Int) {
        assert(group >= 0, "Group: \(group)")
        if group >= groupOps.count {
            for _ in groupOps.count...group {
                groupOps.append(builder())
            }
        }
        groupOps[group].update(with: column[index])
        index += 1
    }

    override func finish() -> PColumn {
        let outputs = groupOps.map { $0.finish() }
        return PColumn(outputs)
    }

    let column: PTypedColumn<Op.Input>
    let builder: () -> Op
//    var iterator: PTypedColumn<Op.Input>.Iterator. // TODO! for efficiency!
    var index = 0
    var groupOps = [Op]()
}

extension AggregationEngine {
    public static func build<T: AggregationOperation>(
        op: T.Type,
        for column: PTypedColumn<T.Input>,
        with builder: @escaping () -> T
    ) -> AggregationEngine {
        return AggregationEngineImpl<T>(column, builder: builder)
    }
}

/// AggregationOperation's represent the per-group operations within a
/// "split-apply-combine" analysis. Types conforming to the
/// `AggregationOperation` protocol can be used as aggregation functions within
/// a "groupBy" operation.
///
/// Because `AggregationOperation`s can be parallelized across multiple cores or
/// hosts, they must support a "merge" operation, which can be used to
/// aggregate the state within the operations themselves.
public protocol AggregationOperation {
    associatedtype Input: ElementRequirements
    associatedtype Output: ElementRequirements

    /// Update the aggregation statistics with a new cell.
    mutating func update(with cell: Input?)

    /// Merge state with another instance of this operation.
    ///
    /// (e.g. the other cell will have been operating on another shard of the
    /// data frame in parallel.)
    mutating func merge(with other: Self)

    /// Compute the output results from this operation. This will be stored in
    /// a dataframe.
    func finish() -> Output?
}

struct SumAggOp<T: Numeric & ElementRequirements>: AggregationOperation {
    init() {}

    mutating func update(with cell: T?) {
        guard let tmp = cell else { return }
        total += tmp
    }

    mutating func merge(with other: Self) {
        total += other.total
    }

    func finish() -> T? {
        total
    }

    var total = T()
}

// Workaround. :-(
class SumAgg: NumericAggregation {
    init() { super.init(name: "sum") }
    override func build<T: Numeric & ElementRequirements>(
        for column: PTypedColumn<T>
    ) -> AggregationEngine {
        AggregationEngine.build(op: SumAggOp.self, for: column) { SumAggOp() }
    }
}

struct MeanAggOp<T: DoubleConvertible & ElementRequirements>: AggregationOperation {
    init() {}

    mutating func update(with cell: T?) {
        guard let tmp = cell else { return }
        count += 1
        total += tmp
    }

    mutating func merge(with other: Self) {
        total += other.total
        count += other.count
    }

    func finish() -> Double? {
        total.asDouble / Double(count)
    }

    var total = T()
    var count = 0
}

class MeanAgg: DoubleConvertibleAggregation {
    init() { super.init(name: "mean") }
    override func build<T: ElementRequirements & DoubleConvertible>(
        for column: PTypedColumn<T>
    ) -> AggregationEngine {
        AggregationEngine.build(op: MeanAggOp.self, for: column) { MeanAggOp() }
    }
}

public extension Aggregation {
    static var sum: Aggregation {
        SumAgg()
    }
    static var mean: Aggregation {
        MeanAgg()
    }
}

struct CountingOp<T: ElementRequirements>: AggregationOperation {
    init() {}
    mutating func update(with elem: T?) {
        counter += 1
    }
    mutating func merge(with other: Self) {
        counter += other.counter
    }
    func finish() -> Int? { counter }

    var counter = 0
}

// Workaround.
class CountingAgg: ArbitraryTypedAggregation {
    init() { super.init(name: "count", isGlobal: true) }
    override func build<T: ElementRequirements>(for column: PTypedColumn<T>) -> AggregationEngine {
        AggregationEngine.build(op: CountingOp.self, for: column) { CountingOp() }
    }
}

public extension Aggregation {
    static var count: Aggregation {
        CountingAgg()
    }
}

struct CountingNils<T: ElementRequirements>:AggregationOperation {
    enum CountMode {
        case nils
        case nonNils
    }

    init(countNils: Bool) {
        self.init(countNils ? .nils : .nonNils)
    }

    init(_ mode: CountMode) {
        self.mode = mode
    }

    mutating func update(with elem: T?) {
        if elem == nil { nilCount += 1 }
        else { nonNilCount += 1 }
    }
    mutating func merge(with other: Self) {
        nilCount += other.nilCount
        nonNilCount += other.nonNilCount
    }
    func finish() -> Int? {
        switch mode {
        case .nils: return nilCount
        case .nonNils: return nonNilCount
        }
    }

    let mode: CountMode
    var nilCount = 0
    var nonNilCount = 0
}

// Workaround.
class CountingNilsAgg: ArbitraryTypedAggregation {
    init(countNils: Bool) {
        self.countNils = countNils
        super.init(name: countNils ? "nils_count" : "non_nils_count" )
    }

    override func build<T: ElementRequirements>(for column: PTypedColumn<T>) -> AggregationEngine {
        AggregationEngine.build(op: CountingNils.self, for: column) {
            CountingNils(countNils: self.countNils)
        }
    }

    let countNils: Bool
}

public extension Aggregation {
    static var countNils: Aggregation {
        CountingNilsAgg(countNils: true)
    }
    static var countNonNils: Aggregation {
        CountingNilsAgg(countNils: false)
    }
}

struct LongestOp: AggregationOperation {
    mutating func update(with elem: String?) {
        guard let elem = elem else { return }
        let cnt = elem.count
        if cnt > longestCount {
            longest = elem
            longestCount = cnt
        }
    }

    mutating func merge(with other: Self) {
        if other.longestCount > longestCount {
            self.longest = other.longest
            self.longestCount = other.longestCount
        }
    }

    func finish() -> String? {
        return longest
    }

    var longest: String? = nil
    var longestCount = -1  // Cache count to avoid recomputing it all the time.
}

public extension Aggregation {
    static var longest: Aggregation {
        StringAggregation<LongestOp>(name: "longest") { LongestOp() }
    }
}
