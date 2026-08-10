import AppKit
import SwiftUI
import Testing

@testable import KawaCADApp

@Test("ツールパレットのポップアップボタンは指定幅で描画される")
@MainActor
func palette_popup_button_uses_the_configured_width() throws {
  var selectedValue = "snapFastener"
  let hostingView = NSHostingView(
    rootView: HStack(spacing: 0) {
      PalettePopUpButton(
        items: [
          PalettePopUpItem(title: "外形カット線", value: "outer"),
          PalettePopUpItem(title: "ジャンパーホック穴", value: "snapFastener"),
        ],
        selection: selectedValue,
        width: 158,
        accessibilityLabel: "型紙線種",
        onSelect: { selectedValue = $0 }
      )
      Spacer(minLength: 0)
    }
  )
  hostingView.frame = NSRect(x: 0, y: 0, width: 220, height: 40)
  hostingView.layoutSubtreeIfNeeded()

  let container = try #require(findSubview(of: PalettePopUpContainer.self, in: hostingView))
  let popUpButton = container.button
  #expect(container.frame.width == 158)
  #expect(popUpButton.frame.width == 158)
  #expect(popUpButton.titleOfSelectedItem == "ジャンパーホック穴")

  popUpButton.selectItem(at: 0)
  _ = popUpButton.sendAction(popUpButton.action, to: popUpButton.target)
  #expect(selectedValue == "outer")
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
