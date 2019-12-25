
public struct Zip2PipelineIterator<L: PipelineIteratorProtocol, R: PipelineIteratorProtocol>: PipelineIteratorProtocol {
    public typealias Element = (L.Element, R.Element)

    public init(_ lhs: L, _ rhs: R) {
        self.lhs = lhs
        self.rhs = rhs
    }

    public var isNextReady: Bool {
        lhs.isNextReady && rhs.isNextReady
    }

    public mutating func next() throws -> Element? {
        var errL: Error? = nil
        var errR: Error? = nil
        var lhs: L.Element? = nil
        var rhs: R.Element? = nil
        // Must pump both iterators, even if the first one errors out.
        do {
            lhs = try self.lhs.next()
        } catch {
            errL = error
        }
        do {
            rhs = try self.rhs.next()
        } catch {
            errR = error
        }
        if let err = errL {
            throw err
        }
        if let err = errR {
            throw err
        }
        if let l = lhs, let r = rhs {
            return (l, r)
        }
        return nil
    }

    var lhs: L
    var rhs: R
}

public extension PipelineIterator {
    static func zip<L: PipelineIteratorProtocol, R: PipelineIteratorProtocol>(_ lhs: L, _ rhs: R) -> Zip2PipelineIterator<L, R> {
        Zip2PipelineIterator(lhs, rhs)
    }
}
