public protocol DoubleConvertible: Numeric {
    var asDouble: Double { get }
}

extension Double: DoubleConvertible {
    public var asDouble: Double { self }
}

extension Float: DoubleConvertible {
    public var asDouble: Double { Double(self) }
}

extension Int: DoubleConvertible {
    public var asDouble: Double { Double(self) }
}

extension Int32: DoubleConvertible {
    public var asDouble: Double { Double(self) }
}

extension Int64: DoubleConvertible {
    public var asDouble: Double { Double(self) }
}
