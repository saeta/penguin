public protocol PDefaultInit {
    init()
}

extension Int: PDefaultInit {}
extension Int32: PDefaultInit {}
extension Int64: PDefaultInit {}
extension Float: PDefaultInit {}
extension Double: PDefaultInit {}
extension String: PDefaultInit {}
extension Bool: PDefaultInit {}
