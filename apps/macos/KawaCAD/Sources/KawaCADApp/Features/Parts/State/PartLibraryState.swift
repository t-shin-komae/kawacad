import Combine

/// The persisted part-library entries exposed to the workspace. Storage I/O
/// stays behind `PartLibraryAdapter`, just as the web hook owns its displayed
/// entries while Tauri commands own persistence.
final class PartLibraryState: ObservableObject {
  @Published private(set) var entries: [PartLibraryEntry]
  private let adapter: any PartLibraryAdapting

  init(adapter: any PartLibraryAdapting) {
    self.adapter = adapter
    entries = (try? adapter.load()) ?? []
  }

  func replaceEntries(_ entries: [PartLibraryEntry]) {
    self.entries = entries
  }

  func addOrReplace(_ entry: PartLibraryEntry) throws {
    entries.removeAll { $0.name == entry.name }
    entries.append(entry)
    entries.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    try persist()
  }

  func remove(_ entry: PartLibraryEntry) throws {
    entries.removeAll { $0.id == entry.id }
    try persist()
  }

  func persist() throws {
    try adapter.save(entries)
  }
}
