# Custom Data Types #

Penguin is extensible and designed for custom data types. This guide shows how to define a custom
data type, and integrate it into the entire Penguin ecosystem.

> Note: this guide is currenty incomplete. Please help by sending a PR!

## Temperature ##

For our purposes, we will define a custom temperature type and leverage it in some analysis.

```swift
struct Temperature {
	var degreesC: Float
}
```

## Defining Computed Properties ##

We can extend our custom data type with computed properties:

```swift
extension Temperature {
	var isBelowFreezing: Bool { degressC < 0 }
	var isAboveFreezing: Bool { !isBelowFreezing }
}
```

We can then use these to easily compute `PIndexSet`s to slice and dice our `PTypedColumn`s:


```swift
let readings: PTypedColumn<Temperature> = // ...
let frozenReadings = readings[readings.isBelowFreezing]
```

<!-- TODO: Add custom CSV parsing capabilities -->
