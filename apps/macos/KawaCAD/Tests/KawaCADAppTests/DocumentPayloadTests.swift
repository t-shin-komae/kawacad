import Foundation
import Testing

@testable import KawaCADApp

@Test("layer deletion impact decodes the Core camelCase layer id")
func bridge_decodes_layer_deletion_impact() throws {
  let impact = try JSONDecoder().decode(
    LayerDeletionImpact.self,
    from: Data(
      "{\"layerId\":\"layer:construction\",\"entityCount\":1,\"derivedElementCount\":2}".utf8)
  )

  #expect(impact.layerID == "layer:construction")
  #expect(impact.entityCount == 1)
  #expect(impact.derivedElementCount == 2)
  #expect(impact.affectedCount == 3)
}

@Test("CoreConstraintTarget は Core wire shape を型付きで往復する")
func core_constraint_target_round_trips_wire_shape() throws {
  let targets = [
    CoreConstraintTarget.entity("entity:line-a"),
    CoreConstraintTarget.controlPoint(entityID: "entity:line-a", point: .start),
  ]
  let data = try JSONEncoder().encode(targets)
  let json = try #require(String(data: data, encoding: .utf8))

  #expect(json.contains("\"entity\":\"entity:line-a\""))
  #expect(json.contains("\"entity_id\":\"entity:line-a\""))
  #expect(json.contains("\"point\":\"start\""))
  #expect(CoreConstraintTarget.decodeList(from: json) == targets)
}

@Test("CoreJSONValue は Core へ送れない非 JSON 値を拒否する")
func core_json_value_rejects_non_json_value() throws {
  #expect(throws: CoreWireError.self) {
    _ = try CoreJSONValue(any: Date())
  }
}

@Test("CoreJSONValue はJSONSerialization由来の数値1と真偽値trueを区別する")
func core_json_value_distinguishes_nsnumber_from_boolean() throws {
  let object = try #require(
    JSONSerialization.jsonObject(with: Data(#"{"quantity":1,"locked":true}"#.utf8))
      as? [String: Any]
  )

  #expect(try CoreJSONValue(any: object["quantity"] as Any) == .number(1))
  #expect(try CoreJSONValue(any: object["locked"] as Any) == .bool(true))
}

@Test("意味境界 fixture は Swift の計測値 DTO と構造化エラー DTO で decode できる")
func semantic_interface_fixtures_decode_with_swift_types() throws {
  let evaluation = try JSONDecoder().decode(
    MeasurementEvaluation.self,
    from: interfaceFixtureData("measurement-evaluation.json")
  )
  #expect(evaluation.annotationId == "measurement:length-a")
  #expect(evaluation.value == .fixedMm(25.0))
  #expect(evaluation.start == CorePoint(xMm: 0.0, yMm: 0.0))
  #expect(evaluation.end == CorePoint(xMm: 25.0, yMm: 0.0))

  struct ErrorFixture: Decodable { let error: CoreFailure }
  let failure = try JSONDecoder().decode(
    ErrorFixture.self,
    from: interfaceFixtureData("structured-error.json")
  ).error
  #expect(failure.code == "renderInvalidPageSize")
  #expect(failure.details?.objectValue?["target"]?.stringValue == "pdf")
}

@Test("Core bridge はフィレット派生要素をデコードする")
func bridge_decodes_fillet_derived_element() throws {
  let json = """
    {
      "snapshot": {
        "name": "Fillet",
        "statistics": {
          "layerCount": 1,
          "parameterCount": 0,
          "entityCount": 2,
          "derivedElementCount": 1,
          "constraintCount": 0
        },
        "editDisplaySummary": {
          "visibleEntityCount": 5,
          "constraintCount": 0,
          "constraintStatus": "unknown"
        },
        "outputPreviewSummary": {
          "visibleEntityCount": 5,
          "constraintCount": 0,
          "constraintStatus": "unknown"
        }
      },
      "history": {
        "canUndo": true,
        "canRedo": false
      },
      "layers": [
        {
          "id": "layer:cut-line",
          "name": "Cut Line",
          "kind": "cutLine",
          "visible": true,
          "printable": true,
          "style": {
            "stroke": { "red": 0.0, "green": 0.0, "blue": 0.0, "alpha": 1.0 },
            "strokeWidthMm": 0.2,
            "pattern": "solid"
          }
        }
      ],
      "parameters": [],
      "entities": [
        {
          "id": "entity:first",
          "layerId": "layer:cut-line",
          "suppressedByFillet": true,
          "kind": {
            "lineSegment": {
              "start": { "xMm": 0.0, "yMm": 0.0 },
              "end": { "xMm": 10.0, "yMm": 0.0 }
            }
          }
        },
        {
          "id": "entity:second",
          "layerId": "layer:cut-line",
          "suppressedByFillet": true,
          "kind": {
            "lineSegment": {
              "start": { "xMm": 0.0, "yMm": 0.0 },
              "end": { "xMm": 0.0, "yMm": 10.0 }
            }
          }
        }
      ],
      "canvasProjection": {
        "visibleFreeTextIds": ["free-text:note"],
        "stitchStartPoints": [
          {
            "id": "stitch:start",
            "positionMm": { "xMm": 4.0, "yMm": 5.0 },
            "visible": true
          }
        ],
        "measurementAnnotations": [],
        "dimensionConstraints": [
          {
            "id": "constraint:length",
            "visible": true,
            "startMm": { "xMm": 0.0, "yMm": 0.0 },
            "endMm": { "xMm": 10.0, "yMm": 0.0 }
          }
        ],
        "constraintMarkers": [
          {
            "id": "constraint:horizontal",
            "positionMm": { "xMm": 5.0, "yMm": 0.0 },
            "visible": false
          }
        ]
      },
      "derivedElements": [
        {
          "id": "derived:fillet-a",
          "layerId": "layer:cut-line",
          "styleId": "style:stitch",
          "kind": {
            "fillet": {
              "sourceEntityIds": ["entity:first", "entity:second"],
              "radius": { "fixedMm": 2.0 }
            }
          }
        }
      ],
      "warnings": [],
      "entityConstraintStatuses": [],
      "coincidentPointGroups": [],
      "constraints": []
    }
    """

  let state = try LeatherCoreProcessAdapter.decodeDocumentState(json: json)
  let fillet = try #require(state.derivedElements.first)
  #expect(fillet.kind == .fillet)
  #expect(fillet.sourceEntityIDs == ["entity:first", "entity:second"])
  #expect(fillet.styleID == "style:stitch")
  #expect(fillet.radiusMM == 2.0)
  #expect(fillet.radiusParameterID == nil)
  #expect(state.entities.allSatisfy { $0.isSuppressedByFillet })
  #expect(state.canvasProjection.visibleFreeTextIDs == ["free-text:note"])
  #expect(
    state.canvasProjection.stitchStartPoints.first?.positionMM == ModelPoint(xMM: 4.0, yMM: 5.0))
  #expect(
    state.canvasProjection.dimensionConstraints.first?.endMM == ModelPoint(xMM: 10.0, yMM: 0.0))
  #expect(state.canvasProjection.constraintMarkers.first?.visible == false)
}

@Test("Core bridge は丸穴一覧をデコードし、未指定時は空配列にする")
func bridge_decodes_round_holes() throws {
  let json = """
    {
      "snapshot": {
        "name": "Round Hole",
        "statistics": {
          "layerCount": 1,
          "sharedStyleCount": 0,
          "parameterCount": 0,
          "entityCount": 1,
          "derivedElementCount": 0,
          "constraintCount": 0
        },
        "editDisplaySummary": {
          "visibleEntityCount": 1,
          "constraintCount": 0,
          "constraintStatus": "unknown"
        },
        "outputPreviewSummary": {
          "visibleEntityCount": 1,
          "constraintCount": 0,
          "constraintStatus": "unknown"
        }
      },
      "history": {
        "canUndo": false,
        "canRedo": false
      },
      "layers": [
        {
          "id": "layer:cut-line",
          "name": "Cut Line",
          "kind": "cutLine",
          "visible": true,
          "printable": true,
          "style": {
            "stroke": { "red": 0.0, "green": 0.0, "blue": 0.0, "alpha": 1.0 },
            "strokeWidthMm": 0.2,
            "pattern": "solid"
          }
        }
      ],
      "sharedStyles": [],
      "parameters": [],
      "entities": [
        {
          "id": "entity:hole",
          "layerId": "layer:cut-line",
          "styleId": "style:stitch-line",
          "kind": {
            "circle": {
              "center": { "xMm": 12.0, "yMm": 8.0 },
              "radiusMm": 2.5
            }
          }
        }
      ],
      "derivedElements": [],
      "freeTexts": [],
      "roundHoles": [
        {
          "id": "round-hole:hole",
          "entityId": "entity:hole",
          "kind": "snapFastener"
        }
      ],
      "parts": [
        {
          "id": "part:wallet",
          "name": "財布外装",
          "originMm": { "xMm": 12.0, "yMm": 8.0 },
          "outlineEntityIds": ["entity:hole"],
          "holeEntityIdGroups": [],
          "entityIds": ["entity:hole"],
          "derivedElementIds": [],
          "freeTextIds": [],
          "measurementAnnotationIds": []
        }
      ],
      "constraints": [],
      "measurementAnnotations": [],
      "dimensionConstraintAnnotations": [],
      "warnings": [],
      "entityConstraintStatuses": [],
      "coincidentPointGroups": []
    }
    """

  let state = try LeatherCoreProcessAdapter.decodeDocumentState(json: json)

  #expect(
    state.roundHoles == [
      ProjectRoundHole(id: "round-hole:hole", entityID: "entity:hole", kind: .snapFastener)
    ])
  #expect(state.parts.first?.name == "財布外装")
  #expect(state.parts.first?.originMM == ModelPoint(xMM: 12.0, yMM: 8.0))
  #expect(state.entities.first?.styleID == "style:stitch-line")

  let compatibleJSON = json.replacingOccurrences(of: "\"roundHoles\"", with: "\"legacyRoundHoles\"")
  let compatibleState = try LeatherCoreProcessAdapter.decodeDocumentState(json: compatibleJSON)
  #expect(compatibleState.roundHoles.isEmpty)
}

@Test("Core bridge は縫い始め点一覧をデコードし、未指定時は空配列にする")
func bridge_decodes_stitch_start_points() throws {
  let json = """
    {
      "snapshot": {
        "name": "Stitch Start",
        "statistics": {
          "layerCount": 1,
          "sharedStyleCount": 0,
          "parameterCount": 0,
          "entityCount": 1,
          "derivedElementCount": 0,
          "constraintCount": 0
        },
        "editDisplaySummary": {
          "visibleEntityCount": 1,
          "constraintCount": 0,
          "constraintStatus": "unknown"
        },
        "outputPreviewSummary": {
          "visibleEntityCount": 1,
          "constraintCount": 0,
          "constraintStatus": "unknown"
        }
      },
      "history": {
        "canUndo": false,
        "canRedo": false
      },
      "layers": [],
      "sharedStyles": [],
      "parameters": [],
      "entities": [],
      "derivedElements": [],
      "freeTexts": [],
      "roundHoles": [],
      "stitchStartPoints": [
        {
          "id": "stitch-start:line",
          "targetId": "entity:line",
          "positionRatio": 0.25
        },
        {
          "id": "stitch-start:offset",
          "targetId": "derived:offset",
          "resolvedIndex": 1,
          "positionRatio": 0.75
        }
      ],
      "constraints": [],
      "measurementAnnotations": [],
      "dimensionConstraintAnnotations": [],
      "warnings": [],
      "entityConstraintStatuses": [],
      "coincidentPointGroups": []
    }
    """

  let state = try LeatherCoreProcessAdapter.decodeDocumentState(json: json)

  #expect(
    state.stitchStartPoints == [
      ProjectStitchStartPoint(
        id: "stitch-start:line", targetID: "entity:line", resolvedIndex: nil, positionRatio: 0.25),
      ProjectStitchStartPoint(
        id: "stitch-start:offset", targetID: "derived:offset", resolvedIndex: 1, positionRatio: 0.75
      ),
    ])

  let compatibleJSON = json.replacingOccurrences(
    of: "\"stitchStartPoints\"", with: "\"legacyStitchStartPoints\"")
  let compatibleState = try LeatherCoreProcessAdapter.decodeDocumentState(json: compatibleJSON)
  #expect(compatibleState.stitchStartPoints.isEmpty)
}

@Test("Core bridge は自由テキスト一覧をデコードする")
func bridge_decodes_free_texts() throws {
  let json = """
    {
      "snapshot": {
        "name": "Free Text",
        "statistics": {
          "layerCount": 1,
          "parameterCount": 0,
          "entityCount": 0,
          "derivedElementCount": 0,
          "constraintCount": 0
        },
        "editDisplaySummary": {
          "visibleEntityCount": 0,
          "constraintCount": 0,
          "constraintStatus": "unknown"
        },
        "outputPreviewSummary": {
          "visibleEntityCount": 0,
          "constraintCount": 0,
          "constraintStatus": "unknown"
        }
      },
      "history": { "canUndo": true, "canRedo": false },
      "layers": [
        {
          "id": "layer:cut-line",
          "name": "Cut Line",
          "kind": "cutLine",
          "visible": true,
          "printable": true,
          "style": {
            "stroke": { "red": 0.0, "green": 0.0, "blue": 0.0, "alpha": 1.0 },
            "strokeWidthMm": 0.2,
            "pattern": "solid"
          }
        }
      ],
      "parameters": [],
      "entities": [],
      "derivedElements": [],
      "freeTexts": [
        {
          "id": "free-text:note",
          "content": "Skive edge",
          "positionMm": { "xMm": 12.0, "yMm": -8.0 },
          "fontSizeMm": 4.5
        }
      ],
      "constraints": [],
      "warnings": [],
      "entityConstraintStatuses": [],
      "coincidentPointGroups": []
    }
    """

  let state = try LeatherCoreProcessAdapter.decodeDocumentState(json: json)

  #expect(state.freeTexts.count == 1)
  #expect(state.freeTexts[0].id == "free-text:note")
  #expect(state.freeTexts[0].content == "Skive edge")
  #expect(state.freeTexts[0].positionMM == ModelPoint(xMM: 12.0, yMM: -8.0))
  #expect(state.freeTexts[0].fontSizeMM == 4.5)
}

@Test("Core bridge は非表示フィレットの元線分を薄い表示にしない")
func bridge_does_not_suppress_sources_for_hidden_fillet_layer() throws {
  let json = """
    {
      "snapshot": {
        "name": "Hidden Fillet",
        "statistics": {
          "layerCount": 2,
          "parameterCount": 0,
          "entityCount": 2,
          "derivedElementCount": 1,
          "constraintCount": 0
        },
        "editDisplaySummary": {
          "visibleEntityCount": 2,
          "constraintCount": 0,
          "constraintStatus": "unknown"
        },
        "outputPreviewSummary": {
          "visibleEntityCount": 2,
          "constraintCount": 0,
          "constraintStatus": "unknown"
        }
      },
      "history": {
        "canUndo": true,
        "canRedo": false
      },
      "layers": [
        {
          "id": "layer:cut-line",
          "name": "Cut Line",
          "kind": "cutLine",
          "visible": true,
          "printable": true,
          "style": {
            "stroke": { "red": 0.0, "green": 0.0, "blue": 0.0, "alpha": 1.0 },
            "strokeWidthMm": 0.2,
            "pattern": "solid"
          }
        },
        {
          "id": "layer:hidden-fillet",
          "name": "Hidden Fillet",
          "kind": "cutLine",
          "visible": false,
          "printable": true,
          "style": {
            "stroke": { "red": 0.0, "green": 0.0, "blue": 0.0, "alpha": 1.0 },
            "strokeWidthMm": 0.2,
            "pattern": "solid"
          }
        }
      ],
      "parameters": [],
      "entities": [
        {
          "id": "entity:first",
          "layerId": "layer:cut-line",
          "kind": {
            "lineSegment": {
              "start": { "xMm": 0.0, "yMm": 0.0 },
              "end": { "xMm": 10.0, "yMm": 0.0 }
            }
          }
        },
        {
          "id": "entity:second",
          "layerId": "layer:cut-line",
          "kind": {
            "lineSegment": {
              "start": { "xMm": 0.0, "yMm": 0.0 },
              "end": { "xMm": 0.0, "yMm": 10.0 }
            }
          }
        }
      ],
      "derivedElements": [
        {
          "id": "derived:fillet-a",
          "layerId": "layer:hidden-fillet",
          "kind": {
            "fillet": {
              "sourceEntityIds": ["entity:first", "entity:second"],
              "radius": { "fixedMm": 2.0 }
            }
          }
        }
      ],
      "warnings": [],
      "entityConstraintStatuses": [],
      "coincidentPointGroups": [],
      "constraints": []
    }
    """

  let state = try LeatherCoreProcessAdapter.decodeDocumentState(json: json)
  #expect(state.entities.allSatisfy { !$0.isSuppressedByFillet })
}

@Test("UC12 円弧端点は拘束対象として start/end に変換される")
func uc12_arc_endpoints_are_constraint_compatible_targets() {
  #expect(CanvasControlPoint.arcStart.isConstraintCompatible)
  #expect(CanvasControlPoint.arcEnd.isConstraintCompatible)
  #expect((CanvasControlPoint.arcStart.jsonObject as? String) == "start")
  #expect((CanvasControlPoint.arcEnd.jsonObject as? String) == "end")

  let arc = CanvasEntity(
    id: "entity:arc",
    label: "円弧",
    kind: .arc,
    layerID: "layer:cut-line",
    geometry: .arc(
      center: ModelPoint(xMM: 0.0, yMM: 0.0),
      radiusMM: 10.0,
      startAngleRad: 0.0,
      sweepAngleRad: Double.pi / 2.0
    )
  )
  let controlPoints = arc.pointSelectionTargets.map(\.target.controlPoint)

  #expect(controlPoints.contains(.center))
  #expect(controlPoints.contains(.arcStart))
  #expect(controlPoints.contains(.arcEnd))
}

@Test("UC3 Core エラー envelope は code/details から利用者向け文言に変換される")
func uc3_core_error_envelope_uses_code_and_details_for_user_message() {
  let insufficientTargetsJSON = """
    {
      "error": {
        "code": "constraintInsufficientTargets",
        "message": "diagnostic only",
        "details": {
          "commandKind": "addConstraint",
          "constraintKind": "segmentLength",
          "actualTargetCount": 0,
          "requiredTargetCount": 1,
          "expectedTargetKinds": ["line"]
        }
      }
    }
    """
  #expect(
    LeatherCoreProcessAdapter.decodeErrorMessage(json: insufficientTargetsJSON)
      == "線分長拘束には 1 件の対象が必要です。現在 0 件です。次に 線分 を選択してください。"
  )

  let conflictingJSON = """
    {
      "error": {
        "code": "conflictingConstraint",
        "message": "would conflict with existing constraints",
        "details": {
          "commandKind": "addConstraint",
          "constraintKind": "segmentLength",
          "constraintId": "constraint:length-a",
          "targetIds": ["entity:line-a"]
        }
      }
    }
    """
  #expect(
    LeatherCoreProcessAdapter.decodeErrorMessage(json: conflictingJSON)
      == "線分長拘束は既存の拘束と矛盾するため追加できません。"
  )

  let updateConflictingJSON = """
    {
      "error": {
        "code": "conflictingConstraint",
        "message": "would conflict with existing constraints",
        "details": {
          "commandKind": "updateConstraint",
          "constraintKind": "segmentLength",
          "constraintId": "constraint:length-a",
          "targetIds": ["entity:line-a"]
        }
      }
    }
    """
  #expect(
    LeatherCoreProcessAdapter.decodeErrorMessage(json: updateConflictingJSON)
      == "線分長拘束は既存の拘束と矛盾するため更新できません。"
  )

  let outputOutOfGridJSON = """
    {
      "error": {
        "code": "outputOutOfGridBounds",
        "message": "diagnostic only"
      }
    }
    """
  #expect(
    LeatherCoreProcessAdapter.decodeErrorMessage(json: outputOutOfGridJSON)
      == "出力対象がA4 5x5グリッドの範囲外にあります。出力対象を範囲内へ移動してください。"
  )

  let renderMessages = [
    "renderEmptyPages": "出力ページが生成されていません。出力対象の内容を確認してください。",
    "renderInvalidPageSize": "出力ページサイズが不正です。用紙設定または出力モデルを確認してください。",
    "renderPageCountMismatch": "出力ページ数の整合が取れていません。出力モデルを確認してください。",
    "renderUnsupportedRotation": "出力回転角が不正です。0 度または 90 度で指定してください。",
  ]
  for (code, expected) in renderMessages {
    let json = #"{"error":{"code":"\#(code)","message":"diagnostic only"}}"#
    #expect(LeatherCoreProcessAdapter.decodeErrorMessage(json: json) == expected)
  }
}
