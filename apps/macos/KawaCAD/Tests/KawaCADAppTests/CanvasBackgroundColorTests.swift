import AppKit
import Testing

@testable import KawaCADApp

struct CanvasBackgroundColorTests {
  @Test
  func canvas_background_stays_light_in_light_and_dark_appearances() throws {
    let lightAppearance = try #require(NSAppearance(named: .aqua))
    let darkAppearance = try #require(NSAppearance(named: .darkAqua))

    let lightColor = try resolvedCanvasBackground(with: lightAppearance)
    let darkColor = try resolvedCanvasBackground(with: darkAppearance)

    #expect(lightColor.redComponent > 0.9)
    #expect(lightColor.greenComponent > 0.9)
    #expect(lightColor.blueComponent > 0.9)
    #expect(darkColor.redComponent > 0.9)
    #expect(darkColor.greenComponent > 0.9)
    #expect(darkColor.blueComponent > 0.9)
  }

  private func resolvedCanvasBackground(with appearance: NSAppearance) throws -> NSColor {
    var resolvedColor: NSColor?
    appearance.performAsCurrentDrawingAppearance {
      resolvedColor = LeatherColors.canvasBackground.usingColorSpace(.sRGB)
    }
    return try #require(resolvedColor)
  }
}
