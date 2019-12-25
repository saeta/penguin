import XCTest
import PenguinParallel

final class GeneratorPipelineIteratorTests: XCTestCase {

    func testSimpleGenerator() {
        var i = 0
        var itr: GeneratorPipelineIterator<Int> = PipelineIterator.generate {
            if i >= 3 { return nil }
            i += 1
            return i
        }
        XCTAssertEqual(1, try! itr.next())
        XCTAssertEqual(2, try! itr.next())
        XCTAssertEqual(3, try! itr.next())
        XCTAssertEqual(nil, try! itr.next())
    }

    func testThrowingGenerator() throws {
        var i = 0
        var itr: GeneratorPipelineIterator<Int> = PipelineIterator.generate {
            i += 1
            if i == 2 {
                throw TestErrors.silly
            }
            if i > 3 { return nil }
            return i
        }
        XCTAssertEqual(1, try! itr.next())
        do {
            _ = try itr.next()
            XCTFail("Should have thrown.")
        } catch TestErrors.silly {
            // Success
        }
        XCTAssertEqual(3, try! itr.next())
        XCTAssertEqual(nil, try! itr.next())
    }

    static var allTests = [
        ("testSimpleGenerator", testSimpleGenerator),
        ("testThrowingGenerator", testThrowingGenerator),
    ]
}

fileprivate enum TestErrors: Error {
    case silly
}
