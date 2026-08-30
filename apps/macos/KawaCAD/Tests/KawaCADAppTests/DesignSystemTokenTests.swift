import SwiftUI
import Testing

@testable import KawaCADApp

struct DesignSystemTokenTests {
  @Test("共通デザイントークンはTauri側の基準値と対応する")
  func shared_metrics_match_cross_platform_values() {
    #expect(LeatherDesignMetrics.Spacing.panel == 16)
    #expect(LeatherDesignMetrics.Radius.control == 6)
    #expect(LeatherDesignMetrics.Radius.card == 8)
    #expect(LeatherDesignMetrics.Typography.body == 13)
    #expect(LeatherDesignMetrics.Typography.title >= 15)
    #expect(LeatherDesignMetrics.Typography.section >= 12)
    #expect(LeatherDesignMetrics.Typography.label >= 11)
    #expect(LeatherDesignMetrics.Icon.toolbar == 22)
    #expect(LeatherDesignMetrics.Control.height == 28)
    #expect(LeatherDesignMetrics.Control.inspectorTabHeight == 30)
    #expect(LeatherDesignMetrics.Control.paletteToolHeight >= 38)
    #expect(LeatherDesignMetrics.Border.hairline == 1)
  }

  @Test("共有色はmacOSのsemantic colorを使用する")
  func shared_colors_use_semantic_system_colors() {
    #expect(LeatherColors.window == Color(nsColor: .windowBackgroundColor))
    #expect(LeatherColors.panel == Color(nsColor: .controlBackgroundColor))
    #expect(LeatherColors.ink == Color(nsColor: .labelColor))
    #expect(LeatherColors.secondaryInk == Color(nsColor: .secondaryLabelColor))
  }
}
