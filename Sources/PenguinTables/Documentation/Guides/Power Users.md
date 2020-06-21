# Penguin for Power Users #

Although Penguin is designed to be easy to pick up and get started, Penguin and Swift combine
together to make powerful analysis concise.

## Extensions on `PTable` ##

Because `PTable` is just a normal Swift type, you can define extensions on it.

> Warning: overusing these power features can make your code harder for others (including your
> "future self") harder to understand later. Use appropriate caution, and happy analyzing!


### Easy typed column access ###

If you often need to access a particular column and it is always the same type, you can provide a
helper to be able to easily access it:

```swift
extension PTable {
	var name: PTypedColumn<String> { self["name"].asDType() }
}
```

**Beware:** this extension affects _all_ `PTable`s, not just ones that have a `"name"` column! It's
best practice to scope these extensions tightly (e.g. `fileprivate` if used in a library, or in a
non-exported cell if using Jupyter). Alternatively, use the (forthcoming) `PTypedTable` type
instead.

## Boolean properties of data types ##

Penguin's `PTypedColumn`s support easy access to boolean properties of the underlying data types to
facilitate slicing and dicing. For example, if we had a table with temperature readings using our
[custom `Temperature` data type](custom-data-types.html), we could filter down to only readings
below freezing by doing the following:

```swift
let datatable = // ...
let freezingReadings = datatable[datatable.temperature.isBelowFreezing]
```
