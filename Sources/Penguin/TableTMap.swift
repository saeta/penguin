
extension PTable {
    public func tmap<
        O: Comparable & Hashable,
        T1: Comparable & Hashable
    >(
        _ c1: String,
        fn: (T1) throws -> O) rethrows -> PTypedColumn<O> {
        guard let col1 = columnMapping[c1] else { preconditionFailure("Unknown column \(c1).") }
        guard let tCol1 = col1 as? PTypedColumn<T1> else { preconditionFailure("Column type mis-match at column \(c1); requested \(T1.self) but the column is actually \(type(of: col1)).") }

        // TODO: Aggregate into a PTypedColumn instead of an array.
        var output = [O]()
        output.reserveCapacity(count!)

        for i in 0..<count! {
            try output.append(fn(tCol1[i]))
        }
        return PTypedColumn(output)
    }

    public func tmap<
        O: Comparable & Hashable,
        T1: Comparable & Hashable,
        T2: Comparable & Hashable
        >(
        _ c1: String,
        _ c2: String,
        fn: (T1, T2) throws -> O) rethrows -> PTypedColumn<O> {
        guard let col1 = columnMapping[c1] else { preconditionFailure("Unknown column \(c1).") }
        guard let tCol1 = col1 as? PTypedColumn<T1> else { preconditionFailure("Column type mis-match at column \(c1); requested \(T1.self) but the column is actually \(type(of: col1)).") }
        guard let col2 = columnMapping[c2] else { preconditionFailure("Unknown column \(c2).") }
        guard let tCol2 = col2 as? PTypedColumn<T2> else { preconditionFailure("Column type mis-match at column \(c2); requested \(T2.self) but the column is actually \(type(of: col2)).") }

        // TODO: Aggregate into a PTypedColumn instead of an array.
        var output = [O]()
        output.reserveCapacity(count!)

        for i in 0..<count! {
            try output.append(fn(tCol1[i], tCol2[i]))
        }
        return PTypedColumn(output)
    }

    public func tmap<
        O: Comparable & Hashable,
        T1: Comparable & Hashable,
        T2: Comparable & Hashable,
        T3: Comparable & Hashable
        >(
        _ c1: String,
        _ c2: String,
        _ c3: String,
        fn: (T1, T2, T3) throws -> O) rethrows -> PTypedColumn<O> {
        guard let col1 = columnMapping[c1] else { preconditionFailure("Unknown column \(c1).") }
        guard let tCol1 = col1 as? PTypedColumn<T1> else { preconditionFailure("Column type mis-match at column \(c1); requested \(T1.self) but the column is actually \(type(of: col1)).") }
        guard let col2 = columnMapping[c2] else { preconditionFailure("Unknown column \(c2).") }
        guard let tCol2 = col2 as? PTypedColumn<T2> else { preconditionFailure("Column type mis-match at column \(c2); requested \(T2.self) but the column is actually \(type(of: col2)).") }
        guard let col3 = columnMapping[c3] else { preconditionFailure("Unknown column \(c3).") }
        guard let tCol3 = col3 as? PTypedColumn<T3> else { preconditionFailure("Column type mis-match at column \(c3); requested \(T3.self) but the column is actually \(type(of: col3)).") }

        // TODO: Aggregate into a PTypedColumn instead of an array.
        var output = [O]()
        output.reserveCapacity(count!)

        for i in 0..<count! {
            try output.append(fn(tCol1[i], tCol2[i], tCol3[i]))
        }
        return PTypedColumn(output)
    }


    public func tmap<
        O: Comparable & Hashable,
        T1: Comparable & Hashable,
        T2: Comparable & Hashable,
        T3: Comparable & Hashable,
        T4: Comparable & Hashable
        >(
        _ c1: String,
        _ c2: String,
        _ c3: String,
        _ c4: String,
        fn: (T1, T2, T3, T4) throws -> O) rethrows -> PTypedColumn<O> {
        guard let col1 = columnMapping[c1] else { preconditionFailure("Unknown column \(c1).") }
        guard let tCol1 = col1 as? PTypedColumn<T1> else { preconditionFailure("Column type mis-match at column \(c1); requested \(T1.self) but the column is actually \(type(of: col1)).") }
        guard let col2 = columnMapping[c2] else { preconditionFailure("Unknown column \(c2).") }
        guard let tCol2 = col2 as? PTypedColumn<T2> else { preconditionFailure("Column type mis-match at column \(c2); requested \(T2.self) but the column is actually \(type(of: col2)).") }
        guard let col3 = columnMapping[c3] else { preconditionFailure("Unknown column \(c3).") }
        guard let tCol3 = col3 as? PTypedColumn<T3> else { preconditionFailure("Column type mis-match at column \(c3); requested \(T3.self) but the column is actually \(type(of: col3)).") }
        guard let col4 = columnMapping[c4] else { preconditionFailure("Unknown column \(c4).") }
        guard let tCol4 = col4 as? PTypedColumn<T4> else { preconditionFailure("Column type mis-match at column \(c4); requested \(T4.self) but the column is actually \(type(of: col4)).") }

        // TODO: Aggregate into a PTypedColumn instead of an array.
        var output = [O]()
        output.reserveCapacity(count!)

        for i in 0..<count! {
            try output.append(fn(tCol1[i], tCol2[i], tCol3[i], tCol4[i]))
        }
        return PTypedColumn(output)
    }

    public func tmap<
        O: Comparable & Hashable,
        T1: Comparable & Hashable,
        T2: Comparable & Hashable,
        T3: Comparable & Hashable,
        T4: Comparable & Hashable,
        T5: Comparable & Hashable
        >(
        _ c1: String,
        _ c2: String,
        _ c3: String,
        _ c4: String,
        _ c5: String,
        fn: (T1, T2, T3, T4, T5) throws -> O) rethrows -> PTypedColumn<O> {
        guard let col1 = columnMapping[c1] else { preconditionFailure("Unknown column \(c1).") }
        guard let tCol1 = col1 as? PTypedColumn<T1> else { preconditionFailure("Column type mis-match at column \(c1); requested \(T1.self) but the column is actually \(type(of: col1)).") }
        guard let col2 = columnMapping[c2] else { preconditionFailure("Unknown column \(c2).") }
        guard let tCol2 = col2 as? PTypedColumn<T2> else { preconditionFailure("Column type mis-match at column \(c2); requested \(T2.self) but the column is actually \(type(of: col2)).") }
        guard let col3 = columnMapping[c3] else { preconditionFailure("Unknown column \(c3).") }
        guard let tCol3 = col3 as? PTypedColumn<T3> else { preconditionFailure("Column type mis-match at column \(c3); requested \(T3.self) but the column is actually \(type(of: col3)).") }
        guard let col4 = columnMapping[c4] else { preconditionFailure("Unknown column \(c4).") }
        guard let tCol4 = col4 as? PTypedColumn<T4> else { preconditionFailure("Column type mis-match at column \(c4); requested \(T4.self) but the column is actually \(type(of: col4)).") }
        guard let col5 = columnMapping[c5] else { preconditionFailure("Unknown column \(c5).") }
        guard let tCol5 = col5 as? PTypedColumn<T5> else { preconditionFailure("Column type mis-match at column \(c5); requested \(T5.self) but the column is actually \(type(of: col5)).") }

        // TODO: Aggregate into a PTypedColumn instead of an array.
        var output = [O]()
        output.reserveCapacity(count!)

        for i in 0..<count! {
            try output.append(fn(tCol1[i], tCol2[i], tCol3[i], tCol4[i], tCol5[i]))
        }
        return PTypedColumn(output)
    }

    public func tmap<
        O: Comparable & Hashable,
        T1: Comparable & Hashable,
        T2: Comparable & Hashable,
        T3: Comparable & Hashable,
        T4: Comparable & Hashable,
        T5: Comparable & Hashable,
        T6: Comparable & Hashable
        >(
        _ c1: String,
        _ c2: String,
        _ c3: String,
        _ c4: String,
        _ c5: String,
        _ c6: String,
        fn: (T1, T2, T3, T4, T5, T6) throws -> O) rethrows -> PTypedColumn<O> {
        guard let col1 = columnMapping[c1] else { preconditionFailure("Unknown column \(c1).") }
        guard let tCol1 = col1 as? PTypedColumn<T1> else { preconditionFailure("Column type mis-match at column \(c1); requested \(T1.self) but the column is actually \(type(of: col1)).") }
        guard let col2 = columnMapping[c2] else { preconditionFailure("Unknown column \(c2).") }
        guard let tCol2 = col2 as? PTypedColumn<T2> else { preconditionFailure("Column type mis-match at column \(c2); requested \(T2.self) but the column is actually \(type(of: col2)).") }
        guard let col3 = columnMapping[c3] else { preconditionFailure("Unknown column \(c3).") }
        guard let tCol3 = col3 as? PTypedColumn<T3> else { preconditionFailure("Column type mis-match at column \(c3); requested \(T3.self) but the column is actually \(type(of: col3)).") }
        guard let col4 = columnMapping[c4] else { preconditionFailure("Unknown column \(c4).") }
        guard let tCol4 = col4 as? PTypedColumn<T4> else { preconditionFailure("Column type mis-match at column \(c4); requested \(T4.self) but the column is actually \(type(of: col4)).") }
        guard let col5 = columnMapping[c5] else { preconditionFailure("Unknown column \(c5).") }
        guard let tCol5 = col5 as? PTypedColumn<T5> else { preconditionFailure("Column type mis-match at column \(c5); requested \(T5.self) but the column is actually \(type(of: col5)).") }
        guard let col6 = columnMapping[c6] else { preconditionFailure("Unknown column \(c6).") }
        guard let tCol6 = col6 as? PTypedColumn<T6> else { preconditionFailure("Column type mis-match at column \(c6); requested \(T6.self) but the column is actually \(type(of: col6)).") }

        // TODO: Aggregate into a PTypedColumn instead of an array.
        var output = [O]()
        output.reserveCapacity(count!)

        for i in 0..<count! {
            try output.append(fn(tCol1[i], tCol2[i], tCol3[i], tCol4[i], tCol5[i], tCol6[i]))
        }
        return PTypedColumn(output)
    }
}
