import Foundation

struct PartLibraryEntry: Identifiable, Codable, Hashable {
  let id: String
  let name: String
  let sourcePart: ProjectPart
  let clipboardJSON: String
  let createdAt: Date
}

protocol PartLibraryAdapting {
  func load() throws -> [PartLibraryEntry]
  func save(_ entries: [PartLibraryEntry]) throws
}

struct PartLibraryAdapter: PartLibraryAdapting {
  let fileURL: URL

  init(fileURL: URL? = nil) {
    if let fileURL {
      self.fileURL = fileURL
    } else {
      let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        .first!
      self.fileURL =
        base
        .appendingPathComponent("KawaCAD", isDirectory: true)
        .appendingPathComponent("part-library.json")
    }
  }

  func load() throws -> [PartLibraryEntry] {
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
    return try JSONDecoder().decode([PartLibraryEntry].self, from: Data(contentsOf: fileURL))
  }

  func save(_ entries: [PartLibraryEntry]) throws {
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(entries).write(to: fileURL, options: .atomic)
  }
}
