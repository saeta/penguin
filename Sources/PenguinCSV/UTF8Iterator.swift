/// A Naive UTF8Parser based on Swift iterator protocols.
///
/// TODO: Consider vectorizing the implementation to improve performance.
public struct UTF8Parser<T: IteratorProtocol>: Sequence, IteratorProtocol where T.Element == UInt8 {
    var underlying: T

    public mutating func next() -> Character? {
        guard let first = underlying.next() else {
            return nil
        }
        if first & 0b10000000 == 0 {
            // ASCII character
            let scalar = Unicode.Scalar(first)
            return Character(scalar)
        }
        // Non-ascii values
        if first & 0b00100000 == 0 {
            // 2 bytes
            guard let second = underlying.next() else {
                print("Incomplete (2 byte) unicode value found at end of file.")
                return nil
            }
            let char = UInt32(((first & 0b00011111) << 6) | (second & 0b00111111))
            return Character(Unicode.Scalar(char)!)
        }
        if first & 0b00010000 == 0 {
            // 3 bytes
            guard let second = underlying.next() else {
                print("Incomplete (3 byte; 1 byte found) unicode value found at end of file.")
                return nil
            }
            guard let third = underlying.next() else {
                print("Incomplete (3 byte; 2 bytes found) unicode value found at end of file.")
                return nil
            }
            // Workaround for Swift compiler being unable to typecheck the following expression.
            // let char = UInt32((first & 0b00011111) << 12 | (second & 0b00111111) << 6 | (third & 0b00111111))
            let upper = UInt32((first & 0b00011111) << 12 | (second & 0b00111111) << 6)
            let char = upper | UInt32(third & 0b00111111)
            return Character(Unicode.Scalar(char)!)
        }
        if first & 0b00001000 != 0 {
            print("Invalid ascii encountered!")  // TODO: make a more helpful error message (e.g offset.)
            return nil
        }
        guard let second = underlying.next() else {
            print("Incomplete (4 byte; 1 byte found) unicode value found at end of file.")
            return nil
        }
        guard let third = underlying.next() else {
            print("Incomplete (4 byte; 2 bytes found) unicode value found at end of file.")
            return nil
        }
        guard let fourth = underlying.next() else {
            print("Incomplete (4 byte; 3 bytes found) unicode value found at end of file.")
            return nil
        }
        // Workaround for Swift compiler being unable to typecheck an expression.
        let charUpper = UInt32((first & 0b00001111) << 18 | (second & 0b00111111 << 12))
        let charLower = UInt32((third & 0b00111111) << 6 | (fourth & 0b00111111))
        return Character(Unicode.Scalar(charUpper | charLower)!)
    }
}

struct Bits {
    let u: UInt32
    init(_ u: UInt8) {
        self.u = UInt32(u)
    }
    init(_ u: UInt32) {
        self.u = u
    }
}

extension Bits: CustomStringConvertible {
    var description: String {
        var desc = ""
        for i in 0..<32 {
            desc.append("\(UInt32(((u & UInt32(1 << i)) >> (i))))")
        }
        return "0b\(String(desc.reversed()))"
    }
}
