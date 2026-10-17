import XCTest
@testable import SMBClient

final class FolderPublicationTests: XCTestCase {
  func testFlushCarriesTheOpenFileHandleAndSMB2Command() {
    let handle = Data(0..<16)
    let request = Flush.Request(messageId: 7, treeId: 9, sessionId: 11, fileId: handle)
    let bytes = request.encoded()
    XCTAssertEqual(request.header.command, .flush)
    XCTAssertEqual(bytes.count, 64 + 24)
    XCTAssertEqual(Array(bytes[64..<72]), [24, 0, 0, 0, 0, 0, 0, 0])
    XCTAssertEqual(bytes.suffix(16), handle)
  }

  func testRenameReplacementIsExplicitAndRetainsDecomposedUTF16Name() {
    let name = "Lune\u{0301}/.biblium/devices/public.json"
    let replace = FileRenameInformation(replaceIfExists: true, fileName: name)
    let safeDefault = FileRenameInformation(fileName: name)
    XCTAssertEqual(replace.encoded().first, 1)
    XCTAssertEqual(safeDefault.encoded().first, 0)
    XCTAssertEqual(replace.fileName, name.encoded())
    XCTAssertNotEqual(replace.fileName, name.precomposedStringWithCanonicalMapping.encoded())
  }

  func testSeparatorConversionNeverChangesUnicodeSpelling() {
    let raw = "E\u{0301}toiles/.biblium/device.json"
    let path = Pathname.normalize(raw)
    XCTAssertEqual(Array(path.utf8), Array(raw.replacingOccurrences(of: "/", with: "\\").utf8))
    XCTAssertNotEqual(Array(path.utf8), Array(path.precomposedStringWithCanonicalMapping.utf8))
  }
}
