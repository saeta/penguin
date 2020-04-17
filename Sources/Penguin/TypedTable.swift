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

/// PTypedTable is a typed equivalent to `PTable`.
///
/// While `PTable` is the bread-and-butter table type, it heavily leverages type erasure to
/// facilitate ad-hoc analysis. If analysis is regularly done over files with similar formats, it
/// can be helpful to define a schema, as this unlocks additional ergonomics and performance.
///
/// TODO: give an example! Or point to the tutorial!
@dynamicMemberLookup
public struct PTypedTable<Schema: PTableSchema> {

    init(_ table: PTable) throws {
        self.columnMapping = table.columnMapping
        self.columnOrder = table.columnOrder
        keyPathToColumn = Schema().keyPathsToMemberNames

        var errors = [SchemaProblem]()
        for (kp, columnName) in keyPathToColumn {
            do {
                guard let column = columnMapping[columnName] else {
                    throw PError.unknownColumn(colName: columnName)
                }
                try column.validateColumnSchema(kp)
            } catch let error as PError {
                errors.append(SchemaProblem(columnName, error))
            }
        }
        if !errors.isEmpty {
            throw PError.schemaValidationFailure(errors: errors)
        }
    }

    public subscript<T: ElementRequirements>(dynamicMember keypath: KeyPath<Schema, T>) -> PTypedColumn<T> {
        get {
            let columnName = keyPathToColumn[keypath]!
            let column = columnMapping[columnName]!
            return try! column.asDType()
        }
        // TODO: add _modify
    }

    /// Convert to the `PTypedTable` into a `PTable` equivalent.
    ///
    /// - Complexity: O(1). This is a guaranteed fast operation.
    public var untyped: PTable {
        PTable(columnOrder, columnMapping)
    }

    var columnMapping: [String: PColumn]
    var columnOrder: [String]
    let keyPathToColumn: [PartialKeyPath<Schema>: String]
}
