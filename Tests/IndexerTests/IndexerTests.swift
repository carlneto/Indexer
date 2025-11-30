import XCTest
@testable import Indexer

final class IndexerTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Indexer().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
