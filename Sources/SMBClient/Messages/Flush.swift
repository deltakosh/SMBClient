import Foundation

/// SMB2 FLUSH (MS-SMB2 2.2.17/18). A successful WRITE alone is not a
/// durability acknowledgement for the device document about to be renamed.
public enum Flush {
  public struct Request: Message.Request {
    public typealias Response = Flush.Response
    public let header: Header
    public let fileId: Data

    public init(headerFlags: Header.Flags = [], messageId: UInt64,
                treeId: UInt32, sessionId: UInt64, fileId: Data) {
      header = Header(creditCharge: 1, command: .flush, creditRequest: 1,
                      flags: headerFlags, messageId: messageId,
                      treeId: treeId, sessionId: sessionId)
      self.fileId = fileId
    }

    public func encoded() -> Data {
      var data = header.encoded()
      data += UInt16(24)
      data += UInt16(0)
      data += UInt32(0)
      data += fileId
      return data
    }
  }

  public struct Response: Message.Response {
    public let header: Header
    public let structureSize: UInt16
    public let reserved: UInt16
    public init(data: Data) {
      let reader = ByteReader(data)
      header = reader.read()
      structureSize = reader.read()
      reserved = reader.read()
    }
  }
}
