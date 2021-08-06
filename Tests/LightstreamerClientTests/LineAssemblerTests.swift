import XCTest
@testable import LightstreamerClient

final class LineAssemblerTests: XCTestCase {
    
    func testLineAssembler() {
        XCTAssertEqual([], LineAssembler().process(""))
        XCTAssertEqual([], LineAssembler().process("\r"))
        XCTAssertEqual([], LineAssembler().process("\n"))
        XCTAssertEqual([], LineAssembler().process("foo"))
        XCTAssertEqual([], LineAssembler().process("foo\r"))
        XCTAssertEqual([], LineAssembler().process("foo\n"))
        XCTAssertEqual([], LineAssembler().process("foo\n\r"))
        XCTAssertEqual([""], LineAssembler().process("\r\n"))
        XCTAssertEqual(["foo"], LineAssembler().process("foo\r\n"))
        XCTAssertEqual(["foo"], LineAssembler().process("foo\r\n\r"))
        XCTAssertEqual(["foo"], LineAssembler().process("foo\r\n\n"))
        XCTAssertEqual(["foo"], LineAssembler().process("foo\r\nbar"))
        XCTAssertEqual(["foo", "bar"], LineAssembler().process("foo\r\nbar\r\n"))
        
        var la = LineAssembler()
        XCTAssertEqual([], la.process(""))
        XCTAssertEqual([], la.process("f"))
        XCTAssertEqual([], la.process("o"))
        XCTAssertEqual([], la.process("o"))
        XCTAssertEqual([], la.process("\r"))
        XCTAssertEqual(["foo"], la.process("\n"))
        XCTAssertEqual([], la.process("bar"))
        XCTAssertEqual(["bar"], la.process("\r\n"))
        XCTAssertEqual(["zap"], la.process("zap\r\n"))
        
        la = LineAssembler()
        XCTAssertEqual([], la.process("\r"))
        XCTAssertEqual(["\r"], la.process("\r\n"))
    
        la = LineAssembler()
        XCTAssertEqual([], la.process("\n"))
        XCTAssertEqual(["\n"], la.process("\r\n"))
        
        la = LineAssembler()
        XCTAssertEqual(["foo", "bar"], la.process("foo\r\nbar\r\nza"))
        XCTAssertEqual(["zap"], la.process("p\r\n1"))
        XCTAssertEqual(["123"], la.process("23\r\n"))
    }
}
