import XCTest
@testable import Penguin

final class IndexSetTests: XCTestCase {

    func testUnion() {
        let lhs = PIndexSet([true, false, false, true])
        let rhs = PIndexSet([true, true, false, false])
        let expected = PIndexSet([true, true, false, true])
        XCTAssertEqual(try! lhs.unioned(rhs), expected)
    }

    func testUnionExtension() {
        let lhs = PIndexSet([true, false, true, false])
        let rhs = PIndexSet([true, true])
        let expected = PIndexSet([true, true, true, false])
        XCTAssertEqual(try! lhs.unioned(rhs, extending: true), expected)
        XCTAssertEqual(try! rhs.unioned(lhs, extending: true), expected)
    }

    func testIntersect() {
        let lhs = PIndexSet([true, false, false, true])
        let rhs = PIndexSet([true, true, false, false])
        let expected = PIndexSet([true, false, false, false])
        XCTAssertEqual(try! lhs.intersected(rhs), expected)
    }

    func testIntersectExtension() {
        let lhs = PIndexSet([true, false, true, false])
        let rhs = PIndexSet([true, true])
        let expected = PIndexSet([true, false, false, false])
        XCTAssertEqual(try! lhs.intersected(rhs, extending: true), expected)
        XCTAssertEqual(try! rhs.intersected(lhs, extending: true), expected)
    }

    static var allTests = [
        ("testUnion", testUnion),
        ("testUnionExtension", testUnionExtension),
        ("testIntersect", testIntersect),
        ("testIntersectExtension", testIntersectExtension),
    ]
}
