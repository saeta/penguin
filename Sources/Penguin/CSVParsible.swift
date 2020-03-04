import PenguinCSV
#if canImport(Darwin)
	import Darwin
#else
	import Glibc
#endif

public protocol PCSVParsible {
	init?(_ cell: CSVCell)
}

extension PCSVParsible where Self: PStringParsible {
	// A default implementation that delegates to PStringParsible
	public init?(_ cell: CSVCell) {
		switch cell {
		case .empty: return nil
		case let .escaped(s):
			self.init(parsing: s)
		case let .raw(buf):
			guard let s = String(
				bytesNoCopy: UnsafeMutableRawPointer(
					mutating: buf.baseAddress!),
				length: buf.count,
				encoding: .utf8,
				freeWhenDone: false) else {
				return nil
			}
			self.init(parsing: s)
		}
	}
}

// Use the default implementation for these types.

extension String: PCSVParsible {}
extension Bool: PCSVParsible {}

// Custom implementations below that optimize for performance.

extension Int: PCSVParsible {
	public init?(_ cell: CSVCell) {
		switch cell {
		case .empty: return nil
		case let .escaped(s):
			self.init(parsing: s)  // Slow path.
		case let .raw(buf):
			var sign = 1
			var base = 0
			var i = 0

			// Skip leading whitespace.
			while Unicode.Scalar(buf[i]) == " " && i < buf.count {
				i += 1
			}

			if Unicode.Scalar(buf[i]) == "-" {
				sign = -1
				i += 1
			}
			if Unicode.Scalar(buf[i]) == "+" {
				i += 1
			}

			let ascii0 = Character(Unicode.Scalar("0")).asciiValue!

			while i < buf.count {
				let elem = buf[i] &- ascii0
				if elem < 0 || elem > 9 {
					break
				}
				base = base * 10 + Int(elem)
				i += 1
			}
			self = sign * base
		}
	}
}

extension Double: PCSVParsible {
	public init?(_ cell: CSVCell) {
		switch cell {
		case .empty: return nil
		case let .escaped(s):
			self.init(parsing: s)  // Slow path.
		case let .raw(buf):
			let rawPtr = UnsafeRawPointer(buf.baseAddress)
			let tmp = strtod(rawPtr!.assumingMemoryBound(to: Int8.self), nil)  // This might not be right.
			self = tmp
		}
	}
}
