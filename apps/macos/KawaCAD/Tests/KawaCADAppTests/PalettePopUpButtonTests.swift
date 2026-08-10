import AppKit
import SwiftUI
import Testing

@testable import KawaCADApp

@Test("ツールパレットのポップアップボタンは指定幅で描画される")
@MainActor
func palette_popup_button_uses_the_proposed_width() throws {
  var selectedValue = "outer"
  let hostingView = NSHostingView(
    rootView: PalettePopUpButton(
      items: [
        PalettePopUpItem(key: "outer", title: "外形カット線", value: "outer"),
        PalettePopUpItem(key: "fold", title: "折り線", value: "fold"),
      ],
      selection: selectedValue,
      accessibilityLabel: "型紙線種",
      onSelect: { selectedValue = $0 }
    )
    .frame(width: 158)
  )
  hostingView.frame = NSRect(x: 0, y: 0, width: 158, height: 40)
  hostingView.layoutSubtreeIfNeeded()

  let popUpButton = try #require(findSubview(of: NSPopUpButton.self, in: hostingView))
  #expect(popUpButton.frame.width == 158)
  #expect(popUpButton.titleOfSelectedItem == "外形カット線")

  popUpButton.selectItem(at: 1)
  _ = popUpButton.sendAction(popUpButton.action, to: popUpButton.target)
  #expect(selectedValue == "fold")
}

@MainActor
private func findSubview<View: NSView>(of type: View.Type, in root: NSView) -> View? {
  if let match = root as? View {
    return match
  }
  for subview in root.subviews {
    if let match = findSubview(of: type, in: subview) {
      return match
    }
  }
  return nil
}
