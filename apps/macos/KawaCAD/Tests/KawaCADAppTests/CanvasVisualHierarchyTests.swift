import Testing

@testable import KawaCADApp

@Test("#164 キャンバス補助表示の優先順位を線幅と破線で維持する")
func canvas_visual_hierarchy_keeps_primary_geometry_prominent() {
  #expect(CanvasVisualHierarchy.gridLineWidth < CanvasVisualHierarchy.a4SecondaryLineWidth)
  #expect(CanvasVisualHierarchy.a4SecondaryLineWidth < CanvasVisualHierarchy.a4PrimaryLineWidth)
  #expect(CanvasVisualHierarchy.a4PrimaryLineWidth < CanvasVisualHierarchy.coordinateLineWidth)
  #expect(CanvasVisualHierarchy.coordinateLineWidth < CanvasVisualHierarchy.selectionLineWidth)
  #expect(CanvasVisualHierarchy.selectionDash == [5, 3])
}
