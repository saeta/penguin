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
