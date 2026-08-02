import Testing

@testable import KawaCADApp

@Test("UC14 拘束マークは拘束種別と代表位置を導出する")
func uc14_constraint_markers_are_derived_from_constraints_and_entities() {
  let constraints = [
    projectConstraint(
      id: "constraint:horizontal",
      rawKind: "horizontal",
      targetsJSON: #"[{"entity":"entity:line-a"}]"#
    ),
    projectConstraint(
      id: "constraint:coincident",
      rawKind: "coincident",
      targetsJSON:
        #"[{"controlPoint":{"entity_id":"entity:line-a","point":"start"}},{"entity":"entity:point-a"}]"#
    ),
  ]

  let markers = ConstraintMarkerLayout.markers(
    constraints: constraints,
    anchors: [
      resolvedAnchor("constraint:horizontal", 10.0, 0.0),
      resolvedAnchor("constraint:coincident", 0.0, 0.0),
    ]
  )

  #expect(markers.count == 2)
  #expect(markers[0].constraintID == "constraint:horizontal")
  #expect(markers[0].displayName == "水平")
  #expect(markers[0].tool == .horizontal)
  #expect(markers[0].tool.iconKind == CanvasTool.horizontal.iconKind)
  #expect(markers[0].position == ModelPoint(xMM: 10.0, yMM: 0.0))
  #expect(markers[1].constraintID == "constraint:coincident")
  #expect(markers[1].displayName == "一致")
  #expect(markers[1].tool == .coincident)
  #expect(markers[1].tool.iconKind == CanvasTool.coincident.iconKind)
  #expect(markers[1].position == .zero)
}

@Test("接線拘束マークは線分端点と円弧端点から導出される")
func tangent_constraint_marker_is_derived_from_line_and_arc_endpoints() {
  let constraints = [
    projectConstraint(
      id: "constraint:tangent",
      rawKind: "tangent",
      targetsJSON:
        #"[{"controlPoint":{"entity_id":"entity:line","point":"end"}},{"controlPoint":{"entity_id":"entity:arc","point":"start"}}]"#
    )
  ]

  let markers = ConstraintMarkerLayout.markers(
    constraints: constraints,
    anchors: [resolvedAnchor("constraint:tangent", 0.0, 0.0)]
  )

  #expect(markers.count == 1)
  #expect(markers[0].constraintID == "constraint:tangent")
  #expect(markers[0].displayName == "接線")
  #expect(markers[0].tool == .tangent)
  #expect(abs(markers[0].position.xMM) < 0.0001)
  #expect(abs(markers[0].position.yMM) < 0.0001)
}

@Test("UC14 拘束マークは近接拘束をスタックする")
func uc14_constraint_markers_stack_nearby_constraints() {
  let constraints = [
    projectConstraint(
      id: "constraint:horizontal",
      rawKind: "horizontal",
      targetsJSON: #"[{"entity":"entity:line-a"}]"#
    ),
    projectConstraint(
      id: "constraint:length",
      rawKind: "segmentLength",
      targetsJSON: #"[{"entity":"entity:line-a"}]"#,
      valueMM: 20.0
    ),
    projectConstraint(
      id: "constraint:unsupported",
      rawKind: "unknownKind",
      targetsJSON: #"[{"entity":"entity:line-a"}]"#
    ),
  ]

  let markers = ConstraintMarkerLayout.markers(
    constraints: constraints,
    anchors: [
      resolvedAnchor("constraint:horizontal", 10.0, 0.0),
      resolvedAnchor("constraint:length", 10.0, 0.0),
      resolvedAnchor("constraint:unsupported", 10.0, 0.0),
    ]
  )

  #expect(markers.map(\.constraintID) == ["constraint:horizontal", "constraint:length"])
  #expect(markers.map(\.stackIndex) == [0, 1])
  #expect(markers.map(\.tool) == [.horizontal, .segmentLength])
  #expect(markers.map(\.displayName) == ["水平", "線分長"])
}

@Test("UC14 拘束マークは非表示エンティティを含む拘束を表示しない")
func uc14_constraint_markers_require_all_targets_to_be_visible() {
  let constraints = [
    projectConstraint(
      id: "constraint:hidden-target",
      rawKind: "coincident",
      targetsJSON:
        #"[{"controlPoint":{"entity_id":"entity:line-visible","point":"start"}},{"entity":"entity:point-hidden"}]"#
    ),
    projectConstraint(
      id: "constraint:visible-target",
      rawKind: "horizontal",
      targetsJSON: #"[{"entity":"entity:line-visible"}]"#
    ),
  ]

  let markers = ConstraintMarkerLayout.markers(
    constraints: constraints,
    anchors: [
      resolvedAnchor("constraint:hidden-target", 0.0, 0.0, visible: false),
      resolvedAnchor("constraint:visible-target", 10.0, 0.0),
    ]
  )

  #expect(markers.map(\.constraintID) == ["constraint:visible-target"])
}

@Test("UC14 拘束マークは各拘束種別に記号を持つ")
func uc14_constraint_markers_have_icons_for_supported_kinds() {
  let supportedKinds: [(String, CanvasTool)] = [
    ("coincident", .coincident),
    ("horizontal", .horizontal),
    ("vertical", .vertical),
    ("parallel", .parallel),
    ("perpendicular", .perpendicular),
    ("fixed", .fixed),
    ("symmetric", .symmetric),
    ("distance", .distance),
    ("horizontalDistance", .horizontalDistance),
    ("verticalDistance", .verticalDistance),
    ("pointLineDistance", .distance),
    ("lineLineDistance", .lineLineDistance),
    ("pointOnLine", .pointOnLine),
    ("segmentLength", .segmentLength),
    ("angle", .angle),
    ("diameter", .diameter),
    ("radius", .radius),
    ("equalSegmentLength", .equalLength),
  ]
  let constraints = supportedKinds.map { rawKind, _ in
    projectConstraint(
      id: "constraint:\(rawKind)",
      rawKind: rawKind,
      targetsJSON: #"[{"entity":"entity:line-a"}]"#
    )
  }

  let markers = ConstraintMarkerLayout.markers(
    constraints: constraints,
    anchors: constraints.map { resolvedAnchor($0.id, 10.0, 0.0) }
  )

  #expect(markers.map(\.tool) == supportedKinds.map(\.1))
  #expect(markers.map { $0.tool.iconKind } == supportedKinds.map { $0.1.iconKind })
}

private func resolvedAnchor(
  _ id: String,
  _ xMM: Double,
  _ yMM: Double,
  visible: Bool = true
) -> ResolvedCanvasPoint {
  ResolvedCanvasPoint(
    id: id,
    positionMM: ModelPoint(xMM: xMM, yMM: yMM),
    visible: visible
  )
}

private func projectConstraint(
  id: String,
  rawKind: String,
  targetsJSON: String,
  valueMM: Double? = nil
) -> ProjectConstraint {
  ProjectConstraint(
    id: id,
    rawKind: rawKind,
    kind: rawKind,
    targets: [],
    targetsJSON: targetsJSON,
    valueMM: valueMM,
    valueDegrees: nil,
    valueParameterID: nil,
    status: .underConstrained
  )
}
