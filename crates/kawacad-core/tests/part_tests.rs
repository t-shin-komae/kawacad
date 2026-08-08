#[path = "support.rs"]
mod support;

use std::collections::BTreeSet;

use kawacad_core::command::{CommandError, DocumentCommand, SelectionReference};
use kawacad_core::constraints::{ConstraintKind, ConstraintValue};
use kawacad_core::derived::{DerivedElement, OffsetCurve, OffsetDirection};
use kawacad_core::document::ProjectDocument;
use kawacad_core::free_text::FreeText;
use kawacad_core::geometry::EntityKind;
use kawacad_core::measurement::{DimensionConstraintAnnotation, MeasurementAnnotationKind};
use kawacad_core::output::{BuildOutputDocumentModelOptions, PrintableAreaMm};
use kawacad_core::parts::{Part, PartAlignment, PartDistributionAxis};
use kawacad_core::print::PrintOrientation;
use kawacad_core::snapshot::CanvasViewMode;
use kawacad_core::stitch_start_points::StitchStartPoint;
use support::*;

fn add_rectangle(document: &mut ProjectDocument, prefix: &str, x: f64, y: f64) -> Vec<String> {
    let ids = ["bottom", "right", "top", "left"].map(|suffix| format!("entity:{prefix}:{suffix}"));
    let entities = [
        line_entity(&ids[0], point(x, y), point(x + 50.0, y)),
        line_entity(&ids[1], point(x + 50.0, y), point(x + 50.0, y + 30.0)),
        line_entity(&ids[2], point(x + 50.0, y + 30.0), point(x, y + 30.0)),
        line_entity(&ids[3], point(x, y + 30.0), point(x, y)),
    ];
    for entity in entities {
        document
            .apply_command(DocumentCommand::AddEntity(entity))
            .expect("rectangle entity");
    }
    ids.into_iter().collect()
}

#[test]
fn part_default_origin_and_absolute_position_are_resolved_by_core() {
    let mut document = ProjectDocument::new("Part Position");
    let selected = add_rectangle(&mut document, "body", 10.0, 20.0);

    document
        .apply_command(DocumentCommand::CreatePart {
            id: "part:body".to_owned(),
            name: "Body".to_owned(),
            origin_mm: None,
            entity_ids: selected,
        })
        .unwrap();
    assert_eq!(document.parts()[0].origin_mm, point(35.0, 35.0));

    document
        .apply_command(DocumentCommand::SetPartPosition {
            part_id: "part:body".to_owned(),
            position: point(100.0, -20.0),
        })
        .unwrap();
    assert_eq!(document.parts()[0].origin_mm, point(100.0, -20.0));

    let EntityKind::LineSegment(bottom) = document.entity("entity:body:bottom").unwrap().kind
    else {
        panic!("expected bottom line")
    };
    assert_eq!(bottom.start, point(75.0, -35.0));
    assert_eq!(bottom.end, point(125.0, -35.0));
}

#[test]
fn canvas_projection_resolves_semantic_geometry_and_hidden_part_visibility() {
    let mut document = ProjectDocument::new("Canvas Projection");
    let selected = add_rectangle(&mut document, "body", 0.0, 0.0);
    let mut stitch_line = document.entity("entity:body:bottom").unwrap().clone();
    stitch_line.style_id = Some("style:stitch-line".into());
    document
        .apply_command(DocumentCommand::UpdateEntity(stitch_line))
        .unwrap();
    document
        .apply_command(DocumentCommand::AddFreeText(FreeText::new(
            "free-text:inside",
            "note",
            point(25.0, 15.0),
            4.0,
        )))
        .unwrap();
    document
        .apply_command(DocumentCommand::AddStitchStartPoint(StitchStartPoint::new(
            "stitch:bottom",
            "entity:body:bottom",
            None,
            0.25,
        )))
        .unwrap();
    document
        .apply_command(DocumentCommand::AddMeasurementAnnotation(
            measurement_annotation(
                "measurement:bottom",
                MeasurementAnnotationKind::SegmentLength,
                vec![entity_target("entity:body:bottom")],
            ),
        ))
        .unwrap();
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:length",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:body:bottom")],
            Some(ConstraintValue::FixedMm(50.0)),
        )))
        .unwrap();
    document
        .apply_command(DocumentCommand::AddDimensionConstraintAnnotation(
            DimensionConstraintAnnotation {
                constraint_id: "constraint:length".into(),
                label_offset_mm: point(0.0, 0.0),
                overall_offset_mm: point(0.0, 0.0),
                visible: true,
            },
        ))
        .unwrap();
    document
        .apply_command(DocumentCommand::CreatePart {
            id: "part:body".into(),
            name: "Body".into(),
            origin_mm: None,
            entity_ids: selected,
        })
        .unwrap();
    document
        .apply_command(DocumentCommand::UpdatePartSettings {
            part_id: "part:body".into(),
            visible: false,
            printable: false,
            locked: true,
            quantity: 1,
        })
        .unwrap();

    let projection = document.canvas_projection(CanvasViewMode::EditDisplay);
    assert!(projection.visible_free_text_ids.is_empty());

    let stitch = projection
        .stitch_start_points
        .iter()
        .find(|item| item.id == "stitch:bottom")
        .unwrap();
    assert_eq!(stitch.position_mm, point(12.5, 0.0));
    assert!(!stitch.visible);

    let measurement = projection
        .measurement_annotations
        .iter()
        .find(|item| item.id == "measurement:bottom")
        .unwrap();
    assert_eq!(measurement.start_mm, Some(point(0.0, 0.0)));
    assert_eq!(measurement.end_mm, Some(point(50.0, 0.0)));
    assert!(!measurement.visible);

    let dimension = projection
        .dimension_constraints
        .iter()
        .find(|item| item.id == "constraint:length")
        .unwrap();
    assert_eq!(dimension.start_mm, Some(point(0.0, 0.0)));
    assert_eq!(dimension.end_mm, Some(point(50.0, 0.0)));
    assert!(!dimension.visible);

    let marker = projection
        .constraint_markers
        .iter()
        .find(|item| item.id == "constraint:length")
        .unwrap();
    assert_eq!(marker.position_mm, point(25.0, 0.0));
    assert!(!marker.visible);
}

#[test]
fn part_creation_classifies_outline_holes_and_round_trips_with_history() {
    let mut document = ProjectDocument::new("Wallet Parts");
    let mut selected = add_rectangle(&mut document, "body", 0.0, 0.0);
    document
        .apply_command(DocumentCommand::AddEntity(circle_entity(
            "entity:body:hole-a",
            point(10.0, 10.0),
            2.0,
        )))
        .unwrap();
    document
        .apply_command(DocumentCommand::AddEntity(circle_entity(
            "entity:body:hole-b",
            point(40.0, 10.0),
            3.0,
        )))
        .unwrap();
    selected.extend([
        "entity:body:hole-a".to_owned(),
        "entity:body:hole-b".to_owned(),
    ]);

    document
        .apply_command(DocumentCommand::CreatePart {
            id: "part:body".to_owned(),
            name: "札入れ外装".to_owned(),
            origin_mm: Some(point(0.0, 0.0)),
            entity_ids: selected,
        })
        .expect("part should be created");
    let part = &document.parts()[0];
    assert_eq!(part.outline_entity_ids.len(), 4);
    assert_eq!(part.hole_entity_id_groups.len(), 2);
    assert_eq!(part.entity_ids.len(), 6);
    assert!(part.locked);

    let restored = round_trip_json(&document);
    assert_eq!(restored.parts(), document.parts());
    let mut legacy_json: serde_json::Value =
        serde_json::from_str(&document.to_json_pretty_string().unwrap()).unwrap();
    legacy_json["parts"][0]["locked"] = serde_json::json!(false);
    let normalized =
        ProjectDocument::from_json_str(&serde_json::to_string(&legacy_json).unwrap()).unwrap();
    assert!(normalized.parts()[0].locked);

    document.undo().expect("undo part creation");
    assert!(document.parts().is_empty());
    assert_eq!(document.entities().len(), 6);
    document.redo().expect("redo part creation");
    assert_eq!(document.parts().len(), 1);

    document
        .apply_command(DocumentCommand::UpdatePart {
            id: "part:body".to_owned(),
            name: "札入れ外装 改".to_owned(),
            origin_mm: point(0.0, 0.0),
        })
        .unwrap();
    assert_eq!(document.parts()[0].name, "札入れ外装 改");
    document.undo().expect("undo part update");
    assert_eq!(document.parts()[0].name, "札入れ外装");
    document.redo().expect("redo part update");
    assert_eq!(document.parts()[0].origin_mm, point(0.0, 0.0));

    document
        .apply_command(DocumentCommand::DeletePart("part:body".to_owned()))
        .unwrap();
    assert!(document.parts().is_empty());
    assert_eq!(document.entities().len(), 6);
    document.undo().expect("undo part deletion");
    assert_eq!(document.parts().len(), 1);
    document.redo().expect("redo part deletion");
    assert!(document.parts().is_empty());
    assert_eq!(document.entities().len(), 6);
}

#[test]
fn line_arc_outline_is_accepted_but_open_and_separate_contours_are_rejected_atomically() {
    let mut document = ProjectDocument::new("Contour Validation");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:diameter",
            point(-10.0, 0.0),
            point(10.0, 0.0),
        )))
        .unwrap();
    document
        .apply_command(DocumentCommand::AddEntity(arc_entity(
            "entity:arc",
            point(0.0, 0.0),
            10.0,
            0.0,
            std::f64::consts::PI,
        )))
        .unwrap();
    document
        .apply_command(DocumentCommand::CreatePart {
            id: "part:semicircle".to_owned(),
            name: "半円パーツ".to_owned(),
            origin_mm: Some(point(0.0, 0.0)),
            entity_ids: vec!["entity:diameter".to_owned(), "entity:arc".to_owned()],
        })
        .expect("line and arc should close");

    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:open",
            point(20.0, 0.0),
            point(30.0, 0.0),
        )))
        .unwrap();
    let before = document.clone();
    assert!(matches!(
        document.apply_command(DocumentCommand::CreatePart {
            id: "part:invalid".to_owned(),
            name: "開いたパーツ".to_owned(),
            origin_mm: Some(point(20.0, 0.0)),
            entity_ids: vec!["entity:open".to_owned()],
        }),
        Err(CommandError::InvalidValue {
            field: "part entityIds",
            ..
        })
    ));
    assert_eq!(document, before);
}

#[test]
fn loading_rejects_a_hole_that_is_no_longer_inside_its_part_outline() {
    let mut document = ProjectDocument::new("Part File Validation");
    for (id, radius) in [("entity:outline", 20.0), ("entity:hole", 3.0)] {
        document
            .apply_command(DocumentCommand::AddEntity(circle_entity(
                id,
                point(0.0, 0.0),
                radius,
            )))
            .unwrap();
    }
    document
        .apply_command(DocumentCommand::CreatePart {
            id: "part:validated".to_owned(),
            name: "検証パーツ".to_owned(),
            origin_mm: Some(point(0.0, 0.0)),
            entity_ids: vec!["entity:outline".to_owned(), "entity:hole".to_owned()],
        })
        .unwrap();
    let mut json: serde_json::Value =
        serde_json::from_str(&document.to_json_pretty_string().unwrap()).unwrap();
    let hole = json["entities"]
        .as_array_mut()
        .unwrap()
        .iter_mut()
        .find(|entity| entity["id"] == "entity:hole")
        .unwrap();
    hole["kind"]["circle"]["center"]["xMm"] = serde_json::json!(100.0);

    assert!(ProjectDocument::from_json_str(&serde_json::to_string(&json).unwrap()).is_err());
}

#[test]
fn content_created_after_finalization_stays_independent_from_the_part() {
    let mut document = ProjectDocument::new("Fixed Membership");
    let outline = add_rectangle(&mut document, "pocket", 0.0, 0.0);
    document
        .apply_command(DocumentCommand::CreatePart {
            id: "part:pocket".to_owned(),
            name: "カードポケット".to_owned(),
            origin_mm: Some(point(0.0, 0.0)),
            entity_ids: outline,
        })
        .unwrap();
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:pocket:fold",
            point(5.0, 15.0),
            point(45.0, 15.0),
        )))
        .unwrap();
    document
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:pocket:stitch",
                None,
                OffsetCurve {
                    source_entity_ids: vec!["entity:pocket:fold".to_owned()],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::FixedMm(3.0),
                    direction: OffsetDirection::Left,
                },
            ),
        ))
        .unwrap();
    document
        .apply_command(DocumentCommand::AddFreeText(FreeText::new(
            "free-text:pocket",
            "カード段",
            point(20.0, 20.0),
            4.0,
        )))
        .unwrap();
    document
        .apply_command(DocumentCommand::AddMeasurementAnnotation(
            measurement_annotation(
                "measurement:pocket-fold",
                MeasurementAnnotationKind::SegmentLength,
                vec![entity_target("entity:pocket:fold")],
            ),
        ))
        .unwrap();

    let part = &document.parts()[0];
    assert!(!part.entity_ids.contains(&"entity:pocket:fold".to_owned()));
    assert!(part.derived_element_ids.is_empty());
    assert!(part.free_text_ids.is_empty());
    assert!(part.measurement_annotation_ids.is_empty());
}

#[test]
fn moving_a_part_translates_geometry_text_and_origin_as_one_undoable_change() {
    let mut document = ProjectDocument::new("Move Part");
    let mut selected = add_rectangle(&mut document, "movable", 0.0, 0.0);
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:movable:fold",
            point(5.0, 15.0),
            point(45.0, 15.0),
        )))
        .unwrap();
    selected.push("entity:movable:fold".to_owned());
    document
        .apply_command(DocumentCommand::AddFreeText(FreeText::new(
            "free-text:movable",
            "fold",
            point(20.0, 20.0),
            4.0,
        )))
        .unwrap();
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:movable:fold-horizontal",
            ConstraintKind::Horizontal,
            vec![entity_target("entity:movable:fold")],
            None,
        )))
        .unwrap();
    document
        .apply_command(DocumentCommand::CreatePart {
            id: "part:movable".to_owned(),
            name: "移動パーツ".to_owned(),
            origin_mm: Some(point(2.0, 3.0)),
            entity_ids: selected,
        })
        .unwrap();

    document
        .apply_command(DocumentCommand::MovePart {
            part_id: "part:movable".to_owned(),
            delta: point(12.0, -7.0),
        })
        .unwrap();
    let EntityKind::LineSegment(fold) = document.entity("entity:movable:fold").unwrap().kind else {
        panic!("expected moved fold line")
    };
    assert_eq!(fold.start, point(17.0, 8.0));
    assert_eq!(fold.end, point(57.0, 8.0));
    assert_eq!(fold.start.y_mm, fold.end.y_mm);
    assert_eq!(
        document.constraints()[0].id,
        "constraint:movable:fold-horizontal"
    );
    assert_eq!(document.parts()[0].origin_mm, point(14.0, -4.0));
    assert_eq!(document.free_texts()[0].position_mm, point(32.0, 13.0));

    document.undo().unwrap();
    assert_eq!(document.parts()[0].origin_mm, point(2.0, 3.0));
    assert_eq!(document.free_texts()[0].position_mm, point(20.0, 20.0));
    document.redo().unwrap();
    assert_eq!(document.parts()[0].origin_mm, point(14.0, -4.0));
}

#[test]
fn duplicating_a_part_remaps_owned_content_but_keeps_shared_parameter_references() {
    let mut document = ProjectDocument::new("Duplicate Part");
    document
        .apply_command(DocumentCommand::AddParameter(parameter(
            "parameter:shared-width",
            "共通幅",
            50.0,
        )))
        .unwrap();
    let selected = add_rectangle(&mut document, "original", 0.0, 0.0);
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:original:width",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:original:bottom")],
            Some(ConstraintValue::Parameter(
                "parameter:shared-width".to_owned(),
            )),
        )))
        .unwrap();
    document
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:original:stitch",
                None,
                OffsetCurve {
                    source_entity_ids: vec!["entity:original:bottom".to_owned()],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::FixedMm(3.0),
                    direction: OffsetDirection::Left,
                },
            ),
        ))
        .unwrap();
    document
        .apply_command(DocumentCommand::AddFreeText(FreeText::new(
            "free-text:original",
            "note",
            point(20.0, 20.0),
            4.0,
        )))
        .unwrap();
    document
        .apply_command(DocumentCommand::CreatePart {
            id: "part:original".to_owned(),
            name: "カードポケット".to_owned(),
            origin_mm: Some(point(0.0, 0.0)),
            entity_ids: selected,
        })
        .unwrap();

    document
        .apply_command(DocumentCommand::DuplicatePart {
            part_id: "part:original".to_owned(),
            new_part_id: "part:copy".to_owned(),
            new_name: "カードポケット のコピー".to_owned(),
            id_namespace: "part-copy".to_owned(),
            delta: point(70.0, 0.0),
        })
        .unwrap();

    assert_eq!(document.parts().len(), 2);
    let original = document
        .parts()
        .iter()
        .find(|part| part.id == "part:original")
        .unwrap();
    let copy = document
        .parts()
        .iter()
        .find(|part| part.id == "part:copy")
        .unwrap();
    assert_eq!(original.origin_mm, point(0.0, 0.0));
    assert_eq!(copy.origin_mm, point(70.0, 0.0));
    assert!(original.locked);
    assert!(copy.locked);
    assert!(copy
        .entity_ids
        .iter()
        .all(|id| id.starts_with("entity:copy-part-copy:")));
    assert_eq!(
        copy.derived_element_ids,
        ["derived:copy-part-copy:derived:original:stitch"]
    );
    assert_eq!(
        copy.free_text_ids,
        ["free-text:copy-part-copy:free-text:original"]
    );
    assert!(original
        .entity_ids
        .iter()
        .all(|id| !copy.entity_ids.contains(id)));
    let copied_constraint = document
        .constraints()
        .iter()
        .find(|item| item.id == "constraint:copy-part-copy:constraint:original:width")
        .unwrap();
    assert_eq!(
        copied_constraint.value,
        Some(ConstraintValue::Parameter(
            "parameter:shared-width".to_owned()
        ))
    );

    let before_edit = document.clone();
    let copied_bottom = document
        .entity("entity:copy-part-copy:entity:original:bottom")
        .unwrap()
        .clone();
    let EntityKind::LineSegment(line) = copied_bottom.kind else {
        panic!("expected copied line")
    };
    let mut edited = copied_bottom;
    edited.kind = EntityKind::LineSegment(kawacad_core::geometry::LineSegment::new(
        line.start,
        point(line.end.x_mm + 5.0, line.end.y_mm),
    ));
    assert!(document
        .apply_command(DocumentCommand::UpdateEntity(edited))
        .is_err());
    assert_eq!(document, before_edit);

    document.undo().unwrap();
    assert_eq!(document.parts().len(), 1);
    assert!(document
        .entity("entity:copy-part-copy:entity:original:bottom")
        .is_none());
}

#[test]
fn fixed_part_rejects_membership_and_boundary_changes_atomically() {
    let mut document = ProjectDocument::new("Part Membership");
    let outline = add_rectangle(&mut document, "membership", 0.0, 0.0);
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:membership:fold",
            point(5.0, 15.0),
            point(45.0, 15.0),
        )))
        .unwrap();
    document
        .apply_command(DocumentCommand::AddEntity(circle_entity(
            "entity:membership:inner",
            point(25.0, 15.0),
            5.0,
        )))
        .unwrap();
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:membership:outside",
            point(60.0, 0.0),
            point(70.0, 0.0),
        )))
        .unwrap();
    document
        .apply_command(DocumentCommand::CreatePart {
            id: "part:membership".to_owned(),
            name: "所属編集".to_owned(),
            origin_mm: Some(point(0.0, 0.0)),
            entity_ids: outline.clone(),
        })
        .unwrap();

    let before = document.clone();
    for command in [
        DocumentCommand::AddEntitiesToPart {
            part_id: "part:membership".to_owned(),
            entity_ids: vec!["entity:membership:fold".to_owned()],
        },
        DocumentCommand::RemoveEntitiesFromPart {
            part_id: "part:membership".to_owned(),
            entity_ids: vec![outline[0].clone()],
        },
        DocumentCommand::SetPartBoundary {
            part_id: "part:membership".to_owned(),
            entity_ids: vec!["entity:membership:inner".to_owned()],
        },
    ] {
        assert_eq!(
            document.apply_command(command),
            Err(CommandError::InvalidValue {
                field: "part fixed",
                reason:
                    "part shape and membership cannot be changed; ungroup the part before editing"
            })
        );
        assert_eq!(document, before);
    }

    assert!(document
        .apply_command(DocumentCommand::AddEntitiesToPart {
            part_id: "part:membership".to_owned(),
            entity_ids: vec!["entity:membership:outside".to_owned()],
        })
        .is_err());
    assert_eq!(document, before);
}

#[test]
fn editing_requires_explicit_ungroup_and_keeps_the_drawing() {
    let mut document = ProjectDocument::new("Ungroup Broken Part");
    let outline = add_rectangle(&mut document, "gusset", 0.0, 0.0);
    document
        .apply_command(DocumentCommand::CreatePart {
            id: "part:gusset".to_owned(),
            name: "小銭入れマチ".to_owned(),
            origin_mm: Some(point(0.0, 0.0)),
            entity_ids: outline,
        })
        .unwrap();

    let before = document.clone();
    assert!(document
        .apply_command(DocumentCommand::DeleteEntity(
            "entity:gusset:top".to_owned(),
        ))
        .is_err());
    assert_eq!(document, before);
    document
        .apply_command(DocumentCommand::DeletePart("part:gusset".to_owned()))
        .unwrap();
    assert!(document.parts().is_empty());
    assert_eq!(document.entities().len(), 4);
    document
        .apply_command(DocumentCommand::DeleteEntity(
            "entity:gusset:top".to_owned(),
        ))
        .unwrap();
    assert_eq!(document.entities().len(), 3);
}

#[test]
fn shared_named_parameter_cannot_resize_finalized_parts() {
    let mut document = ProjectDocument::new("Wallet Dimension Link");
    document
        .apply_command(DocumentCommand::AddParameter(parameter(
            "parameter:wallet-width",
            "財布幅",
            40.0,
        )))
        .unwrap();
    for (suffix, center_x) in [("outer", 0.0), ("inner", 100.0)] {
        let entity_id = format!("entity:{suffix}");
        let part_id = format!("part:{suffix}");
        document
            .apply_command(DocumentCommand::AddEntity(circle_entity(
                &entity_id,
                point(center_x, 0.0),
                20.0,
            )))
            .unwrap();
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                &format!("constraint:{suffix}:diameter"),
                ConstraintKind::Diameter,
                vec![entity_target(&entity_id)],
                Some(ConstraintValue::Parameter(
                    "parameter:wallet-width".to_owned(),
                )),
            )))
            .unwrap();
        document
            .apply_command(DocumentCommand::CreatePart {
                id: part_id,
                name: format!("財布{suffix}"),
                origin_mm: Some(point(center_x, 0.0)),
                entity_ids: vec![entity_id],
            })
            .unwrap();
    }

    let before = document.clone();
    assert!(document
        .apply_command(DocumentCommand::SetParameterValue {
            parameter_id: "parameter:wallet-width".to_owned(),
            value_mm: 60.0,
        })
        .is_err());
    assert_eq!(document, before);
    assert_eq!(document.parts().len(), 2);
    for entity_id in ["entity:outer", "entity:inner"] {
        let EntityKind::Circle(circle) = document.entity(entity_id).unwrap().kind else {
            panic!("expected circle")
        };
        assert_approx_eq(circle.radius_mm, 20.0);
    }
}

#[test]
fn bifold_wallet_pattern_keeps_all_parts_and_outputs_every_piece() {
    let mut document = ProjectDocument::new("二つ折り財布 型紙");
    document
        .apply_command(DocumentCommand::AddParameter(parameter(
            "parameter:snap-diameter",
            "ホック穴径",
            4.0,
        )))
        .unwrap();
    let pieces = [
        ("outer", "札入れ外装", -80.0, 0.0),
        ("bill", "札入れ内装", -20.0, 0.0),
        ("card", "カードポケット", 40.0, 0.0),
        ("coin", "小銭入れ", -50.0, 40.0),
        ("gusset", "小銭入れマチ", 10.0, 40.0),
        ("fastener", "留め具", -80.0, -40.0),
    ];
    let mut expected_entity_ids = BTreeSet::new();

    for (index, (suffix, name, x, y)) in pieces.into_iter().enumerate() {
        let mut selected = add_rectangle(&mut document, suffix, x, y);
        expected_entity_ids.extend(selected.iter().cloned());
        if index <= 1 {
            let snap_hole_id = format!("entity:{suffix}:snap-hole");
            document
                .apply_command(DocumentCommand::AddEntity(circle_entity(
                    &snap_hole_id,
                    point(x + 25.0, y + 15.0),
                    2.0,
                )))
                .unwrap();
            selected.push(snap_hole_id.clone());
            expected_entity_ids.insert(snap_hole_id.clone());
            document
                .apply_command(DocumentCommand::AddConstraint(constraint(
                    &format!("constraint:{suffix}:snap-diameter"),
                    ConstraintKind::Diameter,
                    vec![entity_target(&snap_hole_id)],
                    Some(ConstraintValue::Parameter(
                        "parameter:snap-diameter".to_owned(),
                    )),
                )))
                .unwrap();
        }
        if index == 0 {
            document
                .apply_command(DocumentCommand::AddDerivedElement(
                    DerivedElement::offset_curve(
                        "derived:outer:stitch",
                        None,
                        OffsetCurve {
                            source_entity_ids: vec!["entity:outer:bottom".to_owned()],
                            source_resolved_entity_ids: Vec::new(),
                            distance: ConstraintValue::FixedMm(3.0),
                            direction: OffsetDirection::Left,
                        },
                    ),
                ))
                .unwrap();
            document
                .apply_command(DocumentCommand::AddFreeText(FreeText::new(
                    "free-text:outer",
                    "床面を漉く",
                    point(x + 25.0, y + 20.0),
                    4.0,
                )))
                .unwrap();
            document
                .apply_command(DocumentCommand::AddMeasurementAnnotation(
                    measurement_annotation(
                        "measurement:outer-width",
                        MeasurementAnnotationKind::SegmentLength,
                        vec![entity_target("entity:outer:bottom")],
                    ),
                ))
                .unwrap();
        }
        document
            .apply_command(DocumentCommand::CreatePart {
                id: format!("part:{suffix}"),
                name: name.to_owned(),
                origin_mm: Some(point(x, y)),
                entity_ids: selected,
            })
            .unwrap();
    }

    assert_eq!(document.parts().len(), 6);
    let outer = document
        .parts()
        .iter()
        .find(|part| part.id == "part:outer")
        .unwrap();
    assert_eq!(outer.hole_entity_id_groups.len(), 1);
    assert_eq!(outer.derived_element_ids, ["derived:outer:stitch"]);
    assert_eq!(outer.free_text_ids, ["free-text:outer"]);
    assert_eq!(
        outer.measurement_annotation_ids,
        ["measurement:outer-width"]
    );

    let before = document.clone();
    assert!(document
        .apply_command(DocumentCommand::SetParameterValue {
            parameter_id: "parameter:snap-diameter".to_owned(),
            value_mm: 6.0,
        })
        .is_err());
    assert_eq!(document, before);
    assert_eq!(document.parts().len(), 6);
    for entity_id in ["entity:outer:snap-hole", "entity:bill:snap-hole"] {
        let EntityKind::Circle(circle) = document.entity(entity_id).unwrap().kind else {
            panic!("expected snap hole circle")
        };
        assert_approx_eq(circle.radius_mm, 2.0);
    }

    let restored = round_trip_json(&document);
    assert_eq!(restored.parts(), document.parts());
    let output = document
        .build_output_document_model(BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: true,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: PrintableAreaMm {
                left_mm: -100.0,
                right_mm: 100.0,
                top_mm: 143.5,
                bottom_mm: -143.5,
            },
        })
        .unwrap();
    let output_entity_ids = output
        .output_document_model
        .pages
        .iter()
        .flat_map(|page| {
            page.graphics
                .iter()
                .map(|graphic| graphic.entity_id.clone())
        })
        .collect::<BTreeSet<_>>();
    assert!(expected_entity_ids.is_subset(&output_entity_ids));
}

#[test]
fn serialized_part_shape_matches_the_kawa_schema_contract() {
    let schema: serde_json::Value =
        serde_json::from_str(include_str!("../../../schemas/kawa/0.1.0.schema.json"))
            .expect("kawa schema should be valid json");
    let schema_properties = schema
        .pointer("/$defs/part/properties")
        .and_then(serde_json::Value::as_object)
        .expect("part schema properties");
    let required = schema
        .pointer("/$defs/part/required")
        .and_then(serde_json::Value::as_array)
        .expect("part schema required fields")
        .iter()
        .map(|item| item.as_str().unwrap())
        .collect::<BTreeSet<_>>();
    let serialized = serde_json::to_value(Part {
        id: "part:schema".to_owned(),
        name: "Schema Part".to_owned(),
        origin_mm: point(0.0, 0.0),
        outline_entity_ids: vec!["entity:outline".to_owned()],
        hole_entity_id_groups: vec![vec!["entity:hole".to_owned()]],
        entity_ids: vec!["entity:outline".to_owned(), "entity:hole".to_owned()],
        derived_element_ids: vec!["derived:stitch".to_owned()],
        free_text_ids: vec!["free-text:note".to_owned()],
        measurement_annotation_ids: vec!["measurement:width".to_owned()],
        visible: true,
        printable: true,
        locked: true,
        quantity: 2,
    })
    .unwrap();
    let serialized_keys = serialized
        .as_object()
        .unwrap()
        .keys()
        .map(String::as_str)
        .collect::<BTreeSet<_>>();

    assert!(required.is_subset(&serialized_keys));
    assert_eq!(
        serialized_keys,
        schema_properties
            .keys()
            .map(String::as_str)
            .collect::<BTreeSet<_>>()
    );
    assert_eq!(
        schema.pointer("/properties/parts/items/$ref"),
        Some(&serde_json::Value::String("#/$defs/part".to_owned()))
    );
}

#[test]
fn part_settings_keep_the_part_fixed_while_position_and_independent_content_remain_editable() {
    let mut document = ProjectDocument::new("Part settings");
    let ids = add_rectangle(&mut document, "settings", 0.0, 0.0);
    document
        .apply_command(DocumentCommand::CreatePart {
            id: "part:settings".to_owned(),
            name: "設定対象".to_owned(),
            origin_mm: Some(point(0.0, 0.0)),
            entity_ids: ids.clone(),
        })
        .unwrap();
    document
        .apply_command(DocumentCommand::UpdatePartSettings {
            part_id: "part:settings".to_owned(),
            visible: false,
            printable: false,
            locked: true,
            quantity: 3,
        })
        .unwrap();
    assert_eq!(document.parts()[0].quantity, 3);
    assert!(document
        .drawing_snapshot(CanvasViewMode::EditDisplay)
        .entities
        .iter()
        .all(|entity| !ids.contains(&entity.id)));

    let output = document
        .build_output_document_model(BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: PrintableAreaMm {
                left_mm: -100.0,
                right_mm: 100.0,
                top_mm: 143.5,
                bottom_mm: -143.5,
            },
        })
        .unwrap();
    assert!(output
        .output_document_model
        .pages
        .iter()
        .flat_map(|page| &page.graphics)
        .all(|graphic| !ids.contains(&graphic.entity_id)));

    let origin_before_partial_updates = document.parts()[0].origin_mm;
    document
        .apply_command(DocumentCommand::RenamePart {
            part_id: "part:settings".to_owned(),
            name: "個別更新後".to_owned(),
        })
        .unwrap();
    document
        .apply_command(DocumentCommand::SetPartVisibility {
            part_id: "part:settings".to_owned(),
            visible: true,
        })
        .unwrap();
    document
        .apply_command(DocumentCommand::SetPartPrintable {
            part_id: "part:settings".to_owned(),
            printable: true,
        })
        .unwrap();
    document
        .apply_command(DocumentCommand::SetPartQuantity {
            part_id: "part:settings".to_owned(),
            quantity: 4,
        })
        .unwrap();
    let partially_updated = &document.parts()[0];
    assert_eq!(partially_updated.name, "個別更新後");
    assert!(partially_updated.visible);
    assert!(partially_updated.printable);
    assert_eq!(partially_updated.quantity, 4);
    assert!(partially_updated.locked);
    assert_eq!(partially_updated.origin_mm, origin_before_partial_updates);

    document
        .apply_command(DocumentCommand::MovePart {
            part_id: "part:settings".to_owned(),
            delta: point(10.0, 0.0),
        })
        .unwrap();
    assert_eq!(document.parts()[0].origin_mm, point(10.0, 0.0));

    let inside = line_entity("entity:inside", point(5.0, 5.0), point(10.0, 5.0));
    document
        .apply_command(DocumentCommand::AddEntity(inside))
        .unwrap();
    assert!(document.entity("entity:inside").is_some());
    assert!(!document.parts()[0]
        .entity_ids
        .contains(&"entity:inside".to_owned()));

    let before_unlock = document.clone();
    assert_eq!(
        document.apply_command(DocumentCommand::UpdatePartSettings {
            part_id: "part:settings".to_owned(),
            visible: true,
            printable: true,
            locked: false,
            quantity: 3,
        }),
        Err(CommandError::InvalidValue {
            field: "part fixed",
            reason: "parts cannot be unlocked"
        })
    );
    assert_eq!(document, before_unlock);
}

#[test]
fn part_arrangement_aligns_and_distributes_outline_bounds_as_single_history_steps() {
    let mut document = ProjectDocument::new("Arrange parts");
    for (name, x) in [("a", 0.0), ("b", 60.0), ("c", 150.0)] {
        let ids = add_rectangle(&mut document, name, x, 0.0);
        document
            .apply_command(DocumentCommand::CreatePart {
                id: format!("part:{name}"),
                name: name.to_owned(),
                origin_mm: Some(point(x, 0.0)),
                entity_ids: ids,
            })
            .unwrap();
    }
    let ids = vec![
        "part:a".to_owned(),
        "part:b".to_owned(),
        "part:c".to_owned(),
    ];
    document
        .apply_command(DocumentCommand::AlignParts {
            part_ids: ids.clone(),
            alignment: PartAlignment::Left,
        })
        .unwrap();
    assert!(document
        .parts()
        .iter()
        .all(|part| part.origin_mm.x_mm == 0.0));
    document.undo().unwrap();
    assert_eq!(document.parts()[1].origin_mm.x_mm, 60.0);
    document.redo().unwrap();
    assert!(document
        .parts()
        .iter()
        .all(|part| part.origin_mm.x_mm == 0.0));

    document.undo().unwrap();
    document
        .apply_command(DocumentCommand::DistributeParts {
            part_ids: ids,
            axis: PartDistributionAxis::Horizontal,
        })
        .unwrap();
    assert_eq!(
        document
            .parts()
            .iter()
            .find(|part| part.id == "part:b")
            .unwrap()
            .origin_mm
            .x_mm,
        75.0
    );
}

#[test]
fn legacy_part_json_uses_safe_management_defaults() {
    let part: Part = serde_json::from_value(serde_json::json!({
        "id": "part:legacy",
        "name": "Legacy",
        "originMm": { "xMm": 0.0, "yMm": 0.0 },
        "outlineEntityIds": ["entity:outline"],
        "holeEntityIdGroups": [],
        "entityIds": ["entity:outline"],
        "derivedElementIds": [],
        "freeTextIds": [],
        "measurementAnnotationIds": []
    }))
    .unwrap();
    assert!(part.visible);
    assert!(part.printable);
    assert!(part.locked);
    assert_eq!(part.quantity, 1);
}

#[test]
fn exported_part_content_can_be_inserted_as_an_independent_part_in_another_project() {
    let mut source = ProjectDocument::new("Library source");
    let ids = add_rectangle(&mut source, "library", 0.0, 0.0);
    source
        .apply_command(DocumentCommand::CreatePart {
            id: "part:source".to_owned(),
            name: "カードポケット".to_owned(),
            origin_mm: Some(point(0.0, 0.0)),
            entity_ids: ids.clone(),
        })
        .unwrap();
    source
        .apply_command(DocumentCommand::UpdatePartSettings {
            part_id: "part:source".to_owned(),
            visible: true,
            printable: true,
            locked: true,
            quantity: 4,
        })
        .unwrap();
    let clipboard = source
        .export_selection(SelectionReference {
            entity_ids: ids.clone(),
            derived_element_ids: vec![],
            constraint_ids: vec![],
            measurement_annotation_ids: vec![],
            stitch_start_point_ids: vec![],
            free_text_ids: vec![],
        })
        .unwrap();
    let namespace = "library-insert";
    let copied_ids = ids
        .iter()
        .map(|id| format!("entity:copy-{namespace}:{id}"))
        .collect::<Vec<_>>();
    let mut target = ProjectDocument::new("Library target");
    target
        .apply_command(DocumentCommand::Compound(vec![
            DocumentCommand::PasteSelection {
                clipboard_json: clipboard.clipboard_json,
                id_namespace: namespace.to_owned(),
                delta: point(80.0, 10.0),
            },
            DocumentCommand::CreatePart {
                id: "part:inserted".to_owned(),
                name: "カードポケット".to_owned(),
                origin_mm: Some(point(80.0, 10.0)),
                entity_ids: copied_ids,
            },
            DocumentCommand::UpdatePartSettings {
                part_id: "part:inserted".to_owned(),
                visible: true,
                printable: true,
                locked: true,
                quantity: 4,
            },
        ]))
        .unwrap();
    assert_eq!(target.parts().len(), 1);
    assert_eq!(target.parts()[0].quantity, 4);
    assert_eq!(target.parts()[0].origin_mm, point(80.0, 10.0));
    target.undo().unwrap();
    assert!(target.parts().is_empty());
    assert!(target.entities().is_empty());
}
