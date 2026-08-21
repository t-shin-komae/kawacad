import AppKit
import Testing

@testable import KawaCADApp

@Test("UC205 角度表示は1本目から2本目への符号付き方向を導出する")
@MainActor
func uc205_angle_overlay_uses_target_order_for_signed_direction() {
  let first = lineEntity(
    id: "entity:first",
    start: .zero,
    end: ModelPoint(xMM: 20.0, yMM: 0.0)
  )
  let second = lineEntity(
    id: "entity:second",
    start: .zero,
    end: ModelPoint(xMM: 0.0, yMM: 20.0)
  )
  let inputs = CanvasTestInputBuilder()
  let view = inputs.makeView(frame: CGRect(x: 0, y: 0, width: 520, height: 736))
  inputs.entities = [first, second]
  inputs.layers = defaultLayers()
  inputs.canvasProjection = canvasProjection(dimensionConstraints: [
    resolvedCanvasGeometry(
      id: "constraint:angle",
      arc: false,
      center: .zero,
      start: ModelPoint(xMM: 20.0, yMM: 0.0),
      end: ModelPoint(xMM: 0.0, yMM: 20.0)
    )
  ])

  let overlay = view.angleConstraintOverlay(
    for: projectAngleConstraint(
      id: "constraint:angle",
      targetsJSON: #"[{"entity":"entity:first"},{"entity":"entity:second"}]"#,
      valueDegrees: 90.0
    ))

  #expect(overlay?.kind == .linePair)
  #expect(overlay?.center == .zero)
  #expect(overlay?.start == ModelPoint(xMM: 20.0, yMM: 0.0))
  #expect(overlay?.end == ModelPoint(xMM: 0.0, yMM: 20.0))
  #expect(overlay?.signedDegrees == 90.0)
  #expect(overlay?.label == "90°")
}

@Test("UC205 角度表示は選択順の入れ替えで基準線と符号が入れ替わる")
@MainActor
func uc205_angle_overlay_reflects_reversed_target_order() {
  let first = lineEntity(
    id: "entity:first",
    start: .zero,
    end: ModelPoint(xMM: 20.0, yMM: 0.0)
  )
  let second = lineEntity(
    id: "entity:second",
    start: .zero,
    end: ModelPoint(xMM: 0.0, yMM: 20.0)
  )
  let inputs = CanvasTestInputBuilder()
  let view = inputs.makeView(frame: CGRect(x: 0, y: 0, width: 520, height: 736))
  inputs.entities = [first, second]
  inputs.layers = defaultLayers()
  inputs.canvasProjection = canvasProjection(dimensionConstraints: [
    resolvedCanvasGeometry(
      id: "constraint:angle",
      arc: false,
      center: .zero,
      start: ModelPoint(xMM: 0.0, yMM: 20.0),
      end: ModelPoint(xMM: 20.0, yMM: 0.0)
    )
  ])

  let overlay = view.angleConstraintOverlay(
    for: projectAngleConstraint(
      id: "constraint:angle",
      targetsJSON: #"[{"entity":"entity:second"},{"entity":"entity:first"}]"#,
      valueDegrees: -90.0
    ))

  #expect(overlay?.kind == .linePair)
  #expect(overlay?.center == .zero)
  #expect(overlay?.start == ModelPoint(xMM: 0.0, yMM: 20.0))
  #expect(overlay?.end == ModelPoint(xMM: 20.0, yMM: 0.0))
  #expect(overlay?.signedDegrees == -90.0)
  #expect(overlay?.label == "-90°")
}

@Test("UC205 0度の角度表示は基準線と0度ラベル用の情報を保持する")
@MainActor
func uc205_angle_overlay_keeps_zero_degree_label_and_baseline() {
  let first = lineEntity(
    id: "entity:first",
    start: .zero,
    end: ModelPoint(xMM: 20.0, yMM: 0.0)
  )
  let second = lineEntity(
    id: "entity:second",
    start: .zero,
    end: ModelPoint(xMM: 30.0, yMM: 0.0)
  )
  let inputs = CanvasTestInputBuilder()
  let view = inputs.makeView(frame: CGRect(x: 0, y: 0, width: 520, height: 736))
  inputs.entities = [first, second]
  inputs.layers = defaultLayers()
  inputs.canvasProjection = canvasProjection(dimensionConstraints: [
    resolvedCanvasGeometry(
      id: "constraint:zero-angle",
      arc: false,
      center: .zero,
      start: ModelPoint(xMM: 20.0, yMM: 0.0),
      end: ModelPoint(xMM: 30.0, yMM: 0.0)
    )
  ])

  let overlay = view.angleConstraintOverlay(
    for: projectAngleConstraint(
      id: "constraint:zero-angle",
      targetsJSON: #"[{"entity":"entity:first"},{"entity":"entity:second"}]"#,
      valueDegrees: 0.0
    ))

  #expect(overlay?.kind == .linePair)
  #expect(overlay?.center == .zero)
  #expect(overlay?.start == ModelPoint(xMM: 20.0, yMM: 0.0))
  #expect(overlay?.end == ModelPoint(xMM: 30.0, yMM: 0.0))
  #expect(overlay?.signedDegrees == 0.0)
  #expect(overlay?.label == "0°")
}

@Test("UC205 円弧の角度表示は掃引角の符号付きラベルを使う")
@MainActor
func uc205_angle_overlay_supports_arc_sweep_angle() {
  let arc = arcEntity(
    id: "entity:arc",
    center: .zero,
    radiusMM: 10.0,
    startAngleRad: 0.0,
    sweepAngleRad: -.pi / 2.0
  )
  let inputs = CanvasTestInputBuilder()
  let view = inputs.makeView(frame: CGRect(x: 0, y: 0, width: 520, height: 736))
  inputs.entities = [arc]
  inputs.layers = defaultLayers()
  inputs.canvasProjection = canvasProjection(dimensionConstraints: [
    resolvedCanvasGeometry(
      id: "constraint:arc-angle",
      arc: true,
      center: .zero,
      start: ModelPoint(xMM: 10.0, yMM: 0.0),
      end: ModelPoint(xMM: 0.0, yMM: -10.0)
    )
  ])

  let overlay = view.angleConstraintOverlay(
    for: projectAngleConstraint(
      id: "constraint:arc-angle",
      targetsJSON: #"[{"entity":"entity:arc"}]"#,
      valueDegrees: -90.0
    ))

  #expect(overlay?.kind == .arc)
  #expect(overlay?.center == .zero)
  #expect(overlay?.start == ModelPoint(xMM: 10.0, yMM: 0.0))
  #expect(abs((overlay?.end.xMM ?? .nan) - 0.0) < 0.0001)
  #expect(abs((overlay?.end.yMM ?? .nan) - -10.0) < 0.0001)
  #expect(overlay?.label == "-90°")
}

private func projectAngleConstraint(
  id: String,
  targetsJSON: String,
  valueDegrees: Double
) -> ProjectConstraint {
  ProjectConstraint(
    id: id,
    rawKind: "angle",
    kind: "angle",
    targets: [],
    targetsJSON: targetsJSON,
    valueMM: nil,
    valueDegrees: valueDegrees,
    valueParameterID: nil,
    status: .underConstrained
  )
}
