import XCTest
@testable import SMBClient

final class FolderPublicationTests: XCTestCase {
  func testLocalServerFlushAndReplacingRenameKeepOnlyTheCompleteNewDocument() async throws {
    guard ProcessInfo.processInfo.environment["BIBLIUM_SMB_LOCAL_TEST"] == "1" else {
      throw XCTSkip("Opt-in synthetic loopback SMB server on port 14445")
    }
    let client = SMBClient(host: "127.0.0.1", port: 14445)
    try await client.login(username: "public", password: "public")
    try await client.connectShare("PUBLIC")
    let folder = "E\u{0301}toiles-" + UUID().uuidString
    try await client.createDirectory(path: folder)
    let destination = folder + "/device.json"
    let first = Data(repeating: 42, count: 8_193)
    let replacement = Data("{\"version\":2,\"public\":true}".utf8)
    for data in [first, replacement] {
      let temporary = folder + "/" + UUID().uuidString + ".tmp"
      let writer = client.fileWriter(path: temporary)
      try await writer.upload(data: data)
      try await writer.flush()
      try await writer.close()
      try await client.rename(from: temporary, to: destination, replaceIfExists: true)
    }
    let result = try await client.download(path: destination)
    XCTAssertEqual(result, replacement)
    let names = try await client.listDirectory(path: folder).map(\.name).filter { $0 != "." && $0 != ".." }
    XCTAssertEqual(names, ["device.json"])
    try await client.disconnectShare()
    try await client.logoff()
  }

  func testFlushCarriesTheOpenFileHandleAndSMB2Command() {
    let handle = Data(0..<16)
    let request = Flush.Request(messageId: 7, treeId: 9, sessionId: 11, fileId: handle)
    let bytes = request.encoded()
    XCTAssertEqual(request.header.command, Header.Command.flush.rawValue)
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
