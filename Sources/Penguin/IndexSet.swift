
struct PIndexSet: Equatable {

    public init(indices: [Int], count: Int?) {
        guard let size = count ?? indices.max() else {
            preconditionFailure("indicies (or count) must be provided and non-empty.")
        }
        self.impl = Array(repeating: false, count: size)
        for index in indices {
            self.impl[index] = true
        }
    }

    init(_ bitset: [Bool]) {
        self.impl = bitset
    }

    public mutating func union(_ rhs: PIndexSet, extending: Bool? = nil) throws {
        if count != rhs.count {
            if extending == nil || extending == false {
                throw PError.indexSetMisMatch(lhs: count, rhs: rhs.count, extendingAvailable: extending == nil)
            }
            self.impl.reserveCapacity(max(count, rhs.count))
        }
        let unionStop = min(count, rhs.count)
        for i in 0..<unionStop {
            self.impl[i] = self.impl[i] || rhs.impl[i]
        }
        if count < rhs.count {
            self.impl.append(contentsOf: rhs.impl[unionStop...])
        }
    }

    public func unioned(_ rhs: PIndexSet, extending: Bool? = nil) throws -> PIndexSet {
        var copy = self
        try copy.union(rhs, extending: extending)
        return copy
    }

    public mutating func intersect(_ rhs: PIndexSet, extending: Bool? = nil) throws {
        if count != rhs.count {
            if extending == nil || extending == false {
                throw PError.indexSetMisMatch(lhs: count, rhs: rhs.count, extendingAvailable: extending == nil)
            }
            self.impl.reserveCapacity(rhs.count)
        }
        let intersectionStop = min(count, rhs.count)
        let newSize = max(count, rhs.count)
        for i in 0..<intersectionStop {
            self.impl[i] = self.impl[i] && rhs.impl[i]
        }
        if count < rhs.count {
            for _ in intersectionStop..<newSize {
                self.impl.append(false)
            }
        } else {
            for i in intersectionStop..<newSize {
                self.impl[i] = false
            }
        }
    }

    public func intersected(_ rhs: PIndexSet, extending: Bool? = nil) throws -> PIndexSet {
        var copy = self
        try copy.intersect(rhs, extending: extending)
        return copy
    }

    public var count: Int {
        impl.count
    }

    var impl: [Bool]  // TODO: support alternate representations.
}
