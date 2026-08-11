import Foundation

extension Data {
  init?(hexEncoded string: String) {
    guard string.count.isMultiple(of: 2) else {
      return nil
    }
    var data = Data(capacity: string.count / 2)
    var index = string.startIndex
    while index < string.endIndex {
      let next = string.index(index, offsetBy: 2)
      guard let byte = UInt8(string[index..<next], radix: 16) else {
        return nil
      }
      data.append(byte)
      index = next
    }
    self = data
  }
}
