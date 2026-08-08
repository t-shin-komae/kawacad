import Foundation
import Testing

@testable import KawaCADApp

@Test("プロジェクトダイアログは .kawa だけを候補にする")
func project_dialog_only_accepts_kawa() {
  let extensions = ProjectFileDialogConfiguration.contentTypes.compactMap(
    \.preferredFilenameExtension
  )

  #expect(extensions == ["kawa"])
  #expect(!extensions.contains("json"))
  #expect(!extensions.contains("lcraft"))
  #expect(
    ProjectFileDialogConfiguration.suggestedFilename(documentName: "型紙") == "型紙.kawa"
  )
}

@Test("拡張子なしの保存先は .kawa へ正規化する")
func project_dialog_normalizes_extensionless_save_url() {
  let extensionless = URL(fileURLWithPath: "/tmp/KawaCAD Save Test/型紙")
  let normalized = ProjectFileDialogConfiguration.normalizedSaveURL(extensionless)
  let existing = URL(fileURLWithPath: "/tmp/KawaCAD Save Test/型紙.kawa")

  #expect(normalized.pathExtension == "kawa")
  #expect(ProjectFileDialogConfiguration.normalizedSaveURL(existing) == existing)
}
