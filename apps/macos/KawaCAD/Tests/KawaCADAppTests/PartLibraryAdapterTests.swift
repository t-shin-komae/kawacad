import Foundation
import Testing

@testable import KawaCADApp

@Test("パーツライブラリはローカルJSONへ保存して再読込できる")
func part_library_adapter_round_trips_entries() throws {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent("KawaCAD-PartLibrary-\(UUID().uuidString)", isDirectory: true)
  defer { try? FileManager.default.removeItem(at: directory) }
  let adapter = PartLibraryAdapter(fileURL: directory.appendingPathComponent("library.json"))
  let part = ProjectPart(
    id: "part:a",
    name: "カードポケット",
    originMM: ModelPoint(xMM: 10, yMM: 20),
    outlineEntityIDs: ["entity:a"],
    holeEntityIDGroups: [],
    entityIDs: ["entity:a"],
    derivedElementIDs: [],
    freeTextIDs: [],
    measurementAnnotationIDs: [],
    quantity: 2
  )
  let entries = [
    PartLibraryEntry(
      id: "entry:a",
      name: part.name,
      sourcePart: part,
      clipboardJSON: "{\"selection\":true}",
      createdAt: Date(timeIntervalSince1970: 1_000)
    )
  ]

  try adapter.save(entries)

  #expect(try adapter.load() == entries)
}
