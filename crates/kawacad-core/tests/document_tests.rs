#[path = "support.rs"]
mod support;

use kawacad_core::command::{
    CommandError, ConstraintCommandErrorCode, DocumentCommand, EntityMetric,
};
use kawacad_core::constraints::{
    ConstraintKind, ConstraintStatus, ConstraintValue, ControlPointKind,
};
use kawacad_core::derived::{
    DerivedElement, DerivedElementKind, Fillet, OffsetCurve, OffsetDirection,
};
use kawacad_core::document::{
    DocumentIoError, DocumentValidationError, ProjectDocument, FILE_FORMAT_VERSION, SCHEMA_VERSION,
};
use kawacad_core::free_text::FreeText;
use kawacad_core::geometry::EntityKind;
use kawacad_core::layers::{LayerKind, LayerStyle, LinePattern, Rgba};
use kawacad_core::measurement::{DimensionConstraintAnnotation, MeasurementAnnotationKind};
use kawacad_core::output::{
    BuildOutputDocumentModelOptions, OutputGraphicGeometry, OutputGraphicKind, OutputTextKind,
    PrintableAreaMm,
};
use kawacad_core::print::PrintOrientation;
use kawacad_core::round_holes::{RoundHole, RoundHoleKind};
use kawacad_core::shared_styles::SharedStyle;
use kawacad_core::snapshot::CanvasViewMode;
use kawacad_core::stitch_start_points::StitchStartPoint;
use support::*;

#[test]
fn new_document_uses_expected_defaults_and_snapshot() {
    let document = ProjectDocument::new("Leather");

    assert_eq!(FILE_FORMAT_VERSION, "0.1.0");
    assert_eq!(document.file_format_version(), FILE_FORMAT_VERSION);
    assert_eq!(document.schema_version(), SCHEMA_VERSION);
    assert_eq!(document.metadata().name, "Leather");
    assert_eq!(document.layers().len(), 1);
    assert_eq!(document.layers()[0].id, "layer:cut-line");
    assert_eq!(
        document
            .shared_styles()
            .iter()
            .map(|style| (
                style.id.as_str(),
                style.name.as_str(),
                style.style.stroke_width_mm,
                style.style.pattern
            ))
            .collect::<Vec<_>>(),
        vec![
            (
                "style:outer-cut-line",
                "外形カット線",
                0.25,
                LinePattern::Solid
            ),
            ("style:stitch-line", "縫い線", 0.18, LinePattern::Dashed),
            ("style:fold-line", "折り線", 0.18, LinePattern::Dashed),
            ("style:center-line", "中心線", 0.13, LinePattern::Dotted),
            (
                "style:construction-line",
                "補助線",
                0.13,
                LinePattern::Construction
            ),
            ("style:dimension-line", "寸法線", 0.13, LinePattern::Solid),
        ]
    );
    assert_eq!(document.parameters().len(), 0);
    assert_eq!(document.entities().len(), 0);
    assert_eq!(document.constraints().len(), 0);
    assert_eq!(
        document
            .drawing_snapshot(CanvasViewMode::EditDisplay)
            .constraint_status,
        ConstraintStatus::Unknown
    );
}

#[test]
fn print_orientation_is_persisted_as_a_document_setting() {
    let mut document = ProjectDocument::new("Print Settings");
    assert_eq!(document.settings().orientation, PrintOrientation::Portrait);
    document
        .apply_command(DocumentCommand::SetPrintOrientation {
            orientation: PrintOrientation::Landscape,
        })
        .expect("orientation");
    assert_eq!(document.settings().orientation, PrintOrientation::Landscape);

    let reloaded = round_trip_json(&document);
    assert_eq!(reloaded.settings().orientation, PrintOrientation::Landscape);
}

#[test]
fn layer_names_must_be_unique_when_adding_or_renaming() {
    let mut document = ProjectDocument::new("Unique Layer Names");

    let add_error = document
        .apply_command(DocumentCommand::AddLayer(layer(
            "layer:duplicate",
            "Cut Line",
            LayerKind::Dimension,
            true,
        )))
        .expect_err("adding a duplicate layer name should fail");
    assert_eq!(
        add_error,
        CommandError::InvalidValue {
            field: "layer name",
            reason: "must be unique",
        }
    );

    document
        .apply_command(DocumentCommand::AddLayer(layer(
            "layer:pattern",
            "Pattern",
            LayerKind::Dimension,
            true,
        )))
        .expect("distinct layer name should be accepted");
    let rename_error = document
        .apply_command(DocumentCommand::RenameLayer {
            layer_id: "layer:pattern".to_owned(),
            name: "  Cut Line  ".to_owned(),
        })
        .expect_err("renaming to a duplicate layer name should fail");
    assert_eq!(
        rename_error,
        CommandError::InvalidValue {
            field: "layer name",
            reason: "must be unique",
        }
    );
}

#[test]
fn parameter_names_must_be_unique_when_adding_or_updating() {
    let mut document = ProjectDocument::new("Unique Parameter Names");
    document
        .apply_command(DocumentCommand::AddParameter(parameter(
            "parameter:width",
            "width",
            10.0,
        )))
        .expect("initial parameter should be accepted");

    let add_error = document
        .apply_command(DocumentCommand::AddParameter(parameter(
            "parameter:duplicate",
            "width",
            20.0,
        )))
        .expect_err("adding a duplicate parameter name should fail");
    assert_eq!(
        add_error,
        CommandError::InvalidValue {
            field: "parameter name",
            reason: "must be unique",
        }
    );

    document
        .apply_command(DocumentCommand::AddParameter(parameter(
            "parameter:height",
            "height",
            20.0,
        )))
        .expect("distinct parameter name should be accepted");
    let update_error = document
        .apply_command(DocumentCommand::UpdateParameter(parameter(
            "parameter:height",
            " width ",
            20.0,
        )))
        .expect_err("updating to a duplicate parameter name should fail");
    assert_eq!(
        update_error,
        CommandError::InvalidValue {
            field: "parameter name",
            reason: "must be unique",
        }
    );
}

#[test]
fn drawing_snapshot_filters_entities_by_layer_visibility() {
    let mut document = ProjectDocument::new("Snapshot Visibility");
    document
        .apply_command(DocumentCommand::AddLayer(layer(
            "layer:visible",
            "Visible",
            LayerKind::Dimension,
            true,
        )))
        .expect("visible layer");
    document
        .apply_command(DocumentCommand::AddLayer(layer(
            "layer:hidden",
            "Hidden",
            LayerKind::Dimension,
            true,
        )))
        .expect("hidden layer");
    document
        .apply_command(DocumentCommand::SetLayerVisibility {
            layer_id: "layer:hidden".to_owned(),
            visible: false,
        })
        .expect("hide layer");

    document
        .apply_command(DocumentCommand::AddEntity(
            line_entity("entity:visible", point(0.0, 0.0), point(10.0, 0.0))
                .on_layer("layer:visible"),
        ))
        .expect("visible entity");
    document
        .apply_command(DocumentCommand::AddEntity(
            line_entity("entity:hidden", point(0.0, 10.0), point(10.0, 10.0))
                .on_layer("layer:hidden"),
        ))
        .expect("hidden entity");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:no-layer",
            point(0.0, 30.0),
            point(10.0, 30.0),
        )))
        .expect("no-layer entity");

    let mut visible_entity_ids = document
        .drawing_snapshot(CanvasViewMode::EditDisplay)
        .entities
        .into_iter()
        .map(|entity| entity.id)
        .collect::<Vec<_>>();
    visible_entity_ids.sort();

    assert_eq!(visible_entity_ids, ["entity:no-layer", "entity:visible"]);
}

#[test]
fn free_text_commands_add_update_delete_and_preserve_history() {
    let mut document = ProjectDocument::new("Free Text");

    document
        .apply_command(DocumentCommand::AddFreeText(FreeText::new(
            "free-text:a",
            "Fold before stitching",
            point(12.0, -8.0),
            4.0,
        )))
        .expect("free text should be added");
    assert_eq!(document.free_texts().len(), 1);
    assert_eq!(document.free_texts()[0].content, "Fold before stitching");

    document
        .apply_command(DocumentCommand::UpdateFreeText(FreeText::new(
            "free-text:a",
            "Fold after edge paint",
            point(18.0, -4.0),
            5.0,
        )))
        .expect("free text should be updated");
    assert_eq!(document.free_texts()[0].content, "Fold after edge paint");
    assert_eq!(document.free_texts()[0].position_mm, point(18.0, -4.0));
    assert_eq!(document.free_texts()[0].font_size_mm, 5.0);

    document.undo().expect("undo update");
    assert_eq!(document.free_texts()[0].content, "Fold before stitching");

    document.redo().expect("redo update");
    assert_eq!(document.free_texts()[0].content, "Fold after edge paint");

    document
        .apply_command(DocumentCommand::DeleteFreeText("free-text:a".to_owned()))
        .expect("free text should be deleted");
    assert!(document.free_texts().is_empty());

    document.undo().expect("undo delete");
    assert_eq!(document.free_texts().len(), 1);
}

#[test]
fn free_text_rejects_invalid_inputs_without_changing_existing_state() {
    let mut document = ProjectDocument::new("Free Text Validation");
    document
        .apply_command(DocumentCommand::AddFreeText(FreeText::new(
            "free-text:valid",
            "Valid note",
            point(0.0, 0.0),
            3.5,
        )))
        .expect("valid free text");

    let invalid_cases = [
        FreeText::new("free-text:empty-content", "   ", point(1.0, 1.0), 3.5),
        FreeText::new("free-text:nan-x", "NaN x", point(f64::NAN, 1.0), 3.5),
        FreeText::new("free-text:nan-y", "NaN y", point(1.0, f64::NAN), 3.5),
        FreeText::new("free-text:zero-size", "Zero size", point(1.0, 1.0), 0.0),
        FreeText::new(
            "free-text:infinite-size",
            "Infinite size",
            point(1.0, 1.0),
            f64::INFINITY,
        ),
    ];

    for invalid in invalid_cases {
        let before = document.free_texts().to_vec();
        let result = document.apply_command(DocumentCommand::AddFreeText(invalid));
        assert!(matches!(result, Err(CommandError::InvalidValue { .. })));
        assert_eq!(document.free_texts(), before.as_slice());
    }

    let before = document.free_texts().to_vec();
    assert!(document
        .apply_command(DocumentCommand::AddFreeText(FreeText::new(
            "free-text:valid",
            "Duplicate",
            point(1.0, 1.0),
            3.5,
        )))
        .is_err());
    assert_eq!(document.free_texts(), before.as_slice());

    assert!(document
        .apply_command(DocumentCommand::UpdateFreeText(FreeText::new(
            "free-text:missing",
            "Missing",
            point(1.0, 1.0),
            3.5,
        )))
        .is_err());
    assert_eq!(document.free_texts(), before.as_slice());
}

#[test]
fn free_text_round_trip_preserves_content_position_and_size() {
    let mut document = ProjectDocument::new("Free Text Round Trip");
    document
        .apply_command(DocumentCommand::AddFreeText(FreeText::new(
            "free-text:note",
            "Make two mirrored pieces",
            point(-25.5, 34.25),
            4.25,
        )))
        .expect("free text should be added");

    let json = document
        .to_json_pretty_string()
        .expect("document should serialize");
    assert!(json.contains("\"freeTexts\""));

    let loaded = ProjectDocument::from_json_str(&json).expect("document should deserialize");
    assert_eq!(loaded.free_texts().len(), 1);
    assert_eq!(loaded.free_texts()[0].content, "Make two mirrored pieces");
    assert_eq!(loaded.free_texts()[0].position_mm, point(-25.5, 34.25));
    assert_eq!(loaded.free_texts()[0].font_size_mm, 4.25);
}

#[test]
fn round_hole_commands_preserve_kind_geometry_style_and_history() {
    let mut document = ProjectDocument::new("Round Holes");
    document
        .apply_command(DocumentCommand::AddEntity(
            circle_entity("entity:key-ring", point(10.0, 20.0), 3.0)
                .with_style("style:stitch-line"),
        ))
        .expect("circle");

    for (id, kind) in [
        ("round-hole:key-ring", RoundHoleKind::KeyRing),
        ("round-hole:rivet", RoundHoleKind::Rivet),
        ("round-hole:snap", RoundHoleKind::SnapFastener),
        ("round-hole:decorative", RoundHoleKind::Decorative),
    ] {
        let entity_id = format!("entity:{id}");
        document
            .apply_command(DocumentCommand::AddEntity(circle_entity(
                &entity_id,
                point(0.0, 0.0),
                1.0,
            )))
            .expect("circle variant");
        document
            .apply_command(DocumentCommand::AddRoundHole(RoundHole::new(
                id, entity_id, kind,
            )))
            .expect("round hole variant");
    }

    let before_circle = circle_geometry(document.entity("entity:key-ring").unwrap());
    document
        .apply_command(DocumentCommand::AddRoundHole(RoundHole::new(
            "round-hole:editable",
            "entity:key-ring",
            RoundHoleKind::KeyRing,
        )))
        .expect("round hole should be added");
    document
        .apply_command(DocumentCommand::UpdateRoundHole(RoundHole::new(
            "round-hole:editable",
            "entity:key-ring",
            RoundHoleKind::Decorative,
        )))
        .expect("kind should update");

    let after_kind_change = circle_geometry(document.entity("entity:key-ring").unwrap());
    assert_eq!(after_kind_change, before_circle);
    assert_eq!(
        document
            .entity("entity:key-ring")
            .unwrap()
            .style_id
            .as_deref(),
        Some("style:stitch-line")
    );
    assert_eq!(
        document
            .round_holes()
            .iter()
            .find(|round_hole| round_hole.id == "round-hole:editable")
            .unwrap()
            .kind,
        RoundHoleKind::Decorative
    );

    document.undo().expect("undo kind update");
    assert_eq!(
        document
            .round_holes()
            .iter()
            .find(|round_hole| round_hole.id == "round-hole:editable")
            .unwrap()
            .kind,
        RoundHoleKind::KeyRing
    );
}

#[test]
fn round_hole_save_load_and_output_use_referenced_circle_geometry() {
    let mut document = ProjectDocument::new("Round Hole Output");
    document
        .apply_command(DocumentCommand::AddEntity(
            circle_entity("entity:hole", point(35.0, 45.0), 2.5).with_style("style:fold-line"),
        ))
        .expect("circle");
    document
        .apply_command(DocumentCommand::AddRoundHole(RoundHole::new(
            "round-hole:hole",
            "entity:hole",
            RoundHoleKind::SnapFastener,
        )))
        .expect("round hole");

    let reloaded = round_trip_json(&document);
    assert_eq!(reloaded.round_holes(), document.round_holes());
    assert_eq!(
        reloaded.entity("entity:hole").unwrap().style_id.as_deref(),
        Some("style:fold-line")
    );

    let output = reloaded
        .build_output_document_model(BuildOutputDocumentModelOptions {
            orientation: kawacad_core::print::PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: PrintableAreaMm {
                left_mm: 5.0,
                right_mm: 5.0,
                top_mm: 5.0,
                bottom_mm: 5.0,
            },
        })
        .expect("output model");
    let graphic = output.output_document_model.pages[0]
        .graphics
        .iter()
        .find(|graphic| graphic.entity_id == "entity:hole")
        .expect("round hole circle output");
    match &graphic.geometry {
        OutputGraphicGeometry::Circle {
            center_mm,
            radius_mm,
        } => {
            assert_approx_eq(center_mm.x_mm, 35.0);
            assert_approx_eq(center_mm.y_mm, 45.0);
            assert_approx_eq(*radius_mm, 2.5);
        }
        other => panic!("expected circle output, got {other:?}"),
    }
}

#[test]
fn stitch_start_points_support_line_arc_offset_save_load_and_output() {
    for (name, entity, ratio, expected_position) in [
        (
            "line",
            line_entity("entity:line", point(0.0, 0.0), point(100.0, 0.0)),
            0.25,
            point(25.0, 0.0),
        ),
        (
            "arc",
            arc_entity(
                "entity:arc",
                point(0.0, 0.0),
                10.0,
                0.0,
                std::f64::consts::PI,
            ),
            0.5,
            point(0.0, 10.0),
        ),
    ] {
        let mut document = ProjectDocument::new(format!("Stitch Start {name}"));
        document
            .apply_command(DocumentCommand::AddEntity(entity.clone()))
            .expect("stitch target");
        document
            .apply_command(DocumentCommand::AddStitchStartPoint(StitchStartPoint::new(
                format!("stitch-start:{name}"),
                entity.id.clone(),
                None,
                ratio,
            )))
            .expect("stitch start point");

        let reloaded = round_trip_json(&document);
        assert_eq!(
            reloaded.stitch_start_points(),
            document.stitch_start_points()
        );
        assert_output_has_stitch_start_marker(
            &reloaded,
            &format!("stitch-start:{name}"),
            expected_position,
        );
    }

    let mut document = ProjectDocument::new("Stitch Start Offset");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:base",
            point(0.0, 0.0),
            point(100.0, 0.0),
        )))
        .expect("base line");
    document
        .apply_command(DocumentCommand::AddParameter(parameter(
            "parameter:offset",
            "offset",
            5.0,
        )))
        .expect("offset parameter");
    document
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:stitch-offset",
                Some("layer:cut-line".to_owned()),
                OffsetCurve {
                    source_entity_ids: vec!["entity:base".to_owned()],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::Parameter("parameter:offset".to_owned()),
                    direction: OffsetDirection::Left,
                },
            )
            .with_style("style:stitch-line"),
        ))
        .expect("offset stitch line");
    document
        .apply_command(DocumentCommand::AddStitchStartPoint(StitchStartPoint::new(
            "stitch-start:offset",
            "derived:stitch-offset",
            Some(0),
            0.4,
        )))
        .expect("offset stitch start point");
    assert_output_has_stitch_start_marker(&document, "stitch-start:offset", point(40.0, 5.0));

    document
        .apply_command(DocumentCommand::SetParameterValue {
            parameter_id: "parameter:offset".to_owned(),
            value_mm: 8.0,
        })
        .expect("offset parameter update");
    assert_eq!(
        document.stitch_start_points()[0].target_id,
        "derived:stitch-offset"
    );
    assert_output_has_stitch_start_marker(&document, "stitch-start:offset", point(40.0, 8.0));
}

#[test]
fn stitch_start_points_reject_invalid_targets_without_state_change() {
    let mut document = ProjectDocument::new("Invalid Stitch Start");
    document
        .apply_command(DocumentCommand::AddEntity(
            line_entity("entity:stitch", point(0.0, 0.0), point(10.0, 0.0))
                .with_style("style:stitch-line"),
        ))
        .expect("stitch line");
    document
        .apply_command(DocumentCommand::AddEntity(point_entity(
            "entity:cut",
            point(0.0, 10.0),
        )))
        .expect("cut line");
    document
        .apply_command(DocumentCommand::AddEntity(
            circle_entity("entity:circle", point(0.0, 0.0), 4.0).with_style("style:stitch-line"),
        ))
        .expect("circle");
    document
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:offset",
                Some("layer:cut-line".to_owned()),
                OffsetCurve {
                    source_entity_ids: vec!["entity:stitch".to_owned()],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::FixedMm(2.0),
                    direction: OffsetDirection::Left,
                },
            )
            .with_style("style:stitch-line"),
        ))
        .expect("offset");

    for invalid in [
        StitchStartPoint::new("stitch-start:cut", "entity:cut", None, 0.5),
        StitchStartPoint::new("stitch-start:circle", "entity:circle", None, 0.5),
        StitchStartPoint::new("stitch-start:missing", "entity:missing", None, 0.5),
        StitchStartPoint::new("stitch-start:bad-index", "derived:offset", Some(3), 0.5),
        StitchStartPoint::new("stitch-start:ratio-low", "entity:stitch", None, -0.1),
        StitchStartPoint::new("stitch-start:ratio-high", "entity:stitch", None, 1.1),
    ] {
        let before = document.stitch_start_points().to_vec();
        assert!(document
            .apply_command(DocumentCommand::AddStitchStartPoint(invalid))
            .is_err());
        assert_eq!(document.stitch_start_points(), before.as_slice());
    }

    document
        .apply_command(DocumentCommand::AddStitchStartPoint(StitchStartPoint::new(
            "stitch-start:valid",
            "entity:stitch",
            None,
            0.5,
        )))
        .expect("valid stitch start");
    document
        .apply_command(DocumentCommand::UpdateStitchStartPoint(
            StitchStartPoint::new("stitch-start:valid", "entity:stitch", None, 0.75),
        ))
        .expect("valid update");
    assert_eq!(document.stitch_start_points()[0].position_ratio, 0.75);
}

#[test]
fn round_hole_validates_referenced_shape_variations_and_constraints() {
    for (entity, expected_ok) in [
        (point_entity("entity:target", point(0.0, 0.0)), false),
        (
            line_entity("entity:target", point(0.0, 0.0), point(10.0, 0.0)),
            false,
        ),
        (
            arc_entity("entity:target", point(0.0, 0.0), 3.0, 0.0, 1.0),
            false,
        ),
        (circle_entity("entity:target", point(0.0, 0.0), 3.0), true),
    ] {
        let mut document = ProjectDocument::new("Round Hole Validation");
        document
            .apply_command(DocumentCommand::AddEntity(entity))
            .expect("target entity");
        let result = document.apply_command(DocumentCommand::AddRoundHole(RoundHole::new(
            "round-hole:target",
            "entity:target",
            RoundHoleKind::Rivet,
        )));
        assert_eq!(result.is_ok(), expected_ok);
    }

    let mut constrained = ProjectDocument::new("Constrained Round Hole");
    constrained
        .apply_command(DocumentCommand::AddEntity(circle_entity(
            "entity:circle",
            point(0.0, 0.0),
            2.0,
        )))
        .expect("circle");
    constrained
        .apply_command(DocumentCommand::AddParameter(parameter(
            "parameter:diameter",
            "diameter",
            8.0,
        )))
        .expect("parameter");
    constrained
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:diameter",
            ConstraintKind::Diameter,
            vec![entity_target("entity:circle")],
            Some(ConstraintValue::Parameter("parameter:diameter".to_owned())),
        )))
        .expect("diameter constraint");
    constrained
        .apply_command(DocumentCommand::AddRoundHole(RoundHole::new(
            "round-hole:constrained",
            "entity:circle",
            RoundHoleKind::KeyRing,
        )))
        .expect("constrained circle round hole");
    let constrained_circle = circle_geometry(constrained.entity("entity:circle").unwrap());
    assert_approx_eq(constrained_circle.radius_mm, 4.0);

    let before = constrained.round_holes().to_vec();
    let invalid_update = constrained.apply_command(DocumentCommand::UpdateEntity(line_entity(
        "entity:circle",
        point(0.0, 0.0),
        point(1.0, 0.0),
    )));
    assert!(invalid_update.is_err());
    assert_eq!(constrained.round_holes(), before.as_slice());
    assert!(matches!(
        constrained.entity("entity:circle").unwrap().kind,
        EntityKind::Circle(_)
    ));
}

#[test]
fn round_hole_rejects_invalid_references_without_state_change() {
    let mut document = ProjectDocument::new("Round Hole Invalid");
    document
        .apply_command(DocumentCommand::AddEntity(circle_entity(
            "entity:circle",
            point(0.0, 0.0),
            2.0,
        )))
        .expect("circle");
    document
        .apply_command(DocumentCommand::AddRoundHole(RoundHole::new(
            "round-hole:valid",
            "entity:circle",
            RoundHoleKind::Decorative,
        )))
        .expect("valid");

    for command in [
        DocumentCommand::AddRoundHole(RoundHole::new("", "entity:circle", RoundHoleKind::Rivet)),
        DocumentCommand::AddRoundHole(RoundHole::new(
            "round-hole:missing",
            "entity:missing",
            RoundHoleKind::Rivet,
        )),
        DocumentCommand::AddRoundHole(RoundHole::new(
            "round-hole:valid",
            "entity:circle",
            RoundHoleKind::Rivet,
        )),
        DocumentCommand::UpdateRoundHole(RoundHole::new(
            "round-hole:valid",
            "entity:missing",
            RoundHoleKind::Rivet,
        )),
        DocumentCommand::UpdateRoundHole(RoundHole::new(
            "round-hole:missing",
            "entity:circle",
            RoundHoleKind::Rivet,
        )),
    ] {
        let before = document.round_holes().to_vec();
        let result = document.apply_command(command);
        assert!(result.is_err());
        assert_eq!(document.round_holes(), before.as_slice());
    }

    document
        .apply_command(DocumentCommand::DeleteEntity("entity:circle".to_owned()))
        .expect("delete circle");
    assert!(document.round_holes().is_empty());
}

fn shared_style(id: &str, name: &str, width: f64, pattern: LinePattern, red: f32) -> SharedStyle {
    SharedStyle::new(
        id,
        name,
        LayerStyle {
            stroke: Rgba {
                red,
                green: 0.25,
                blue: 0.5,
                alpha: 1.0,
            },
            stroke_width_mm: width,
            pattern,
        },
    )
}

#[test]
fn shared_style_commands_apply_to_entity_variants_and_round_trip() {
    let mut document = ProjectDocument::new("Shared Styles");
    let initial_style_count = document.shared_styles().len();
    document
        .apply_command(DocumentCommand::AddSharedStyle(shared_style(
            "style:stitch",
            "Stitch",
            0.35,
            LinePattern::Dashed,
            0.7,
        )))
        .expect("shared style should be added");

    let entities = [
        line_entity("entity:line", point(0.0, 0.0), point(20.0, 0.0)),
        circle_entity("entity:circle", point(30.0, 0.0), 5.0),
        arc_entity("entity:arc", point(50.0, 0.0), 7.0, 0.0, 1.2),
        center_line_entity("entity:center", point(0.0, 20.0), point(20.0, 20.0)),
    ];
    for entity in entities {
        document
            .apply_command(DocumentCommand::AddEntity(entity))
            .expect("entity should be added");
    }

    for entity_id in [
        "entity:line",
        "entity:circle",
        "entity:arc",
        "entity:center",
    ] {
        document
            .apply_command(DocumentCommand::SetEntitySharedStyle {
                entity_id: entity_id.to_owned(),
                style_id: Some("style:stitch".to_owned()),
            })
            .expect("shared style should apply");
    }

    assert_eq!(document.shared_styles().len(), initial_style_count + 1);
    assert!(document
        .entities()
        .iter()
        .all(|entity| entity.style_id.as_deref() == Some("style:stitch")));

    document
        .apply_command(DocumentCommand::UpdateSharedStyle(shared_style(
            "style:stitch",
            "Stitch Updated",
            0.55,
            LinePattern::Dotted,
            0.2,
        )))
        .expect("shared style should update");

    let output = document
        .build_output_document_model(BuildOutputDocumentModelOptions {
            orientation: kawacad_core::print::PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: PrintableAreaMm {
                left_mm: -100.0,
                right_mm: 100.0,
                top_mm: -140.0,
                bottom_mm: 140.0,
            },
        })
        .expect("output model should build");
    let styles = output.output_document_model.pages[0]
        .graphics
        .iter()
        .map(|graphic| graphic.style)
        .collect::<Vec<_>>();
    assert_eq!(styles.len(), 4);
    assert!(styles
        .iter()
        .all(|style| style.pattern == LinePattern::Dotted));
    assert!(styles.iter().all(|style| style.stroke_width_mm == 0.55));
    assert!(styles.iter().all(|style| style.stroke.red == 0.2));

    let loaded = round_trip_json(&document);
    assert_eq!(
        loaded
            .shared_styles()
            .iter()
            .find(|style| style.id == "style:stitch")
            .map(|style| style.name.as_str()),
        Some("Stitch Updated")
    );
    assert!(loaded
        .entities()
        .iter()
        .all(|entity| entity.style_id.as_deref() == Some("style:stitch")));
}

#[test]
fn shared_style_validation_and_deletion_keep_existing_entities() {
    let mut document = ProjectDocument::new("Shared Style Validation");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line",
            point(0.0, 0.0),
            point(20.0, 0.0),
        )))
        .expect("entity should be added");

    assert!(matches!(
        document.apply_command(DocumentCommand::SetEntitySharedStyle {
            entity_id: "entity:line".to_owned(),
            style_id: Some("style:missing".to_owned()),
        }),
        Err(CommandError::BrokenReference { .. })
    ));
    assert_eq!(document.entities()[0].style_id, None);

    for invalid in [
        shared_style("", "Invalid", 0.2, LinePattern::Solid, 0.0),
        shared_style("style:empty-name", "   ", 0.2, LinePattern::Solid, 0.0),
        shared_style("style:zero-width", "Invalid", 0.0, LinePattern::Solid, 0.0),
    ] {
        assert!(matches!(
            document.apply_command(DocumentCommand::AddSharedStyle(invalid)),
            Err(CommandError::EmptyId(_)) | Err(CommandError::InvalidValue { .. })
        ));
    }

    document
        .apply_command(DocumentCommand::AddSharedStyle(shared_style(
            "style:cut",
            "Cut",
            0.25,
            LinePattern::Solid,
            0.0,
        )))
        .expect("shared style should be added");
    document
        .apply_command(DocumentCommand::SetEntitySharedStyle {
            entity_id: "entity:line".to_owned(),
            style_id: Some("style:cut".to_owned()),
        })
        .expect("style should apply");
    document
        .apply_command(DocumentCommand::DeleteSharedStyle("style:cut".to_owned()))
        .expect("shared style should delete");

    assert!(document
        .shared_styles()
        .iter()
        .all(|style| style.id != "style:cut"));
    assert_eq!(document.entities().len(), 1);
    assert_eq!(document.entities()[0].style_id, None);
}

#[test]
fn shared_style_applies_to_derived_element_variations_and_output() {
    for (name, sources, derived_element) in [
        (
            "line offset",
            vec![line_entity(
                "entity:line",
                point(0.0, 0.0),
                point(20.0, 0.0),
            )],
            DerivedElement::offset_curve(
                "derived:line-offset",
                Some("layer:cut-line".to_owned()),
                OffsetCurve {
                    source_entity_ids: vec!["entity:line".to_owned()],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::FixedMm(3.0),
                    direction: OffsetDirection::Left,
                },
            )
            .with_style("style:stitch"),
        ),
        (
            "arc offset",
            vec![arc_entity(
                "entity:arc",
                point(40.0, 0.0),
                8.0,
                0.0,
                std::f64::consts::FRAC_PI_2,
            )],
            DerivedElement::offset_curve(
                "derived:arc-offset",
                Some("layer:cut-line".to_owned()),
                OffsetCurve {
                    source_entity_ids: vec!["entity:arc".to_owned()],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::FixedMm(2.0),
                    direction: OffsetDirection::Left,
                },
            )
            .with_style("style:stitch"),
        ),
        (
            "closed line and arc offset",
            vec![
                line_entity("entity:bottom", point(0.0, 30.0), point(20.0, 30.0)),
                line_entity("entity:right", point(20.0, 30.0), point(20.0, 50.0)),
                arc_entity(
                    "entity:top-left",
                    point(10.0, 50.0),
                    10.0,
                    0.0,
                    std::f64::consts::PI,
                ),
                line_entity("entity:left", point(0.0, 50.0), point(0.0, 30.0)),
            ],
            DerivedElement::offset_curve(
                "derived:closed-offset",
                Some("layer:cut-line".to_owned()),
                OffsetCurve {
                    source_entity_ids: vec![
                        "entity:bottom".to_owned(),
                        "entity:right".to_owned(),
                        "entity:top-left".to_owned(),
                        "entity:left".to_owned(),
                    ],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::FixedMm(1.5),
                    direction: OffsetDirection::Inward,
                },
            )
            .with_style("style:stitch"),
        ),
        (
            "fillet",
            vec![
                line_entity("entity:fillet-a", point(60.0, 0.0), point(80.0, 0.0)),
                line_entity("entity:fillet-b", point(80.0, 0.0), point(80.0, 20.0)),
            ],
            DerivedElement::fillet(
                "derived:fillet",
                Some("layer:cut-line".to_owned()),
                Fillet {
                    source_entity_ids: vec![
                        "entity:fillet-a".to_owned(),
                        "entity:fillet-b".to_owned(),
                    ],
                    radius: ConstraintValue::FixedMm(3.0),
                    closed: false,
                },
            )
            .with_style("style:stitch"),
        ),
    ] {
        let mut document = ProjectDocument::new(name);
        document
            .apply_command(DocumentCommand::AddSharedStyle(shared_style(
                "style:stitch",
                "Stitch",
                0.35,
                LinePattern::Dashed,
                0.7,
            )))
            .expect("shared style should be added");
        for source in sources {
            document
                .apply_command(DocumentCommand::AddEntity(source))
                .expect("source should be added");
        }
        document
            .apply_command(DocumentCommand::AddDerivedElement(derived_element))
            .expect("derived element should be added");

        assert!(document
            .drawing_snapshot(CanvasViewMode::EditDisplay)
            .entities
            .iter()
            .filter(|entity| entity.id.starts_with("derived:"))
            .all(|entity| entity.style_id.as_deref() == Some("style:stitch")));

        document
            .apply_command(DocumentCommand::UpdateSharedStyle(shared_style(
                "style:stitch",
                "Stitch Updated",
                0.55,
                LinePattern::Dotted,
                0.2,
            )))
            .expect("shared style should update");

        let output = document
            .build_output_document_model(BuildOutputDocumentModelOptions {
                orientation: kawacad_core::print::PrintOrientation::Portrait,
                include_dimension_labels: false,
                include_scale_guide: false,
                rotation_deg: 0,
                printable_area_mm: PrintableAreaMm {
                    left_mm: -100.0,
                    right_mm: 120.0,
                    top_mm: -140.0,
                    bottom_mm: 140.0,
                },
            })
            .expect("output model should build");
        let derived_output_styles = output.output_document_model.pages[0]
            .graphics
            .iter()
            .filter(|graphic| graphic.entity_id.starts_with("derived:"))
            .map(|graphic| graphic.style)
            .collect::<Vec<_>>();
        assert!(
            !derived_output_styles.is_empty(),
            "{name} should output derived graphics"
        );
        assert!(derived_output_styles
            .iter()
            .all(|style| style.pattern == LinePattern::Dotted));
        assert!(derived_output_styles
            .iter()
            .all(|style| style.stroke_width_mm == 0.55));
        assert!(derived_output_styles
            .iter()
            .all(|style| style.stroke.red == 0.2));

        let loaded = round_trip_json(&document);
        assert_eq!(
            loaded.derived_elements()[0].style_id.as_deref(),
            Some("style:stitch")
        );
    }
}

#[test]
fn entity_and_derived_partial_updates_preserve_unrelated_semantics() {
    let mut document = ProjectDocument::new("Partial layer and style updates");
    document
        .apply_command(DocumentCommand::AddLayer(layer(
            "layer:user",
            "User",
            LayerKind::Dimension,
            true,
        )))
        .expect("layer should be added");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:first",
            point(0.0, 0.0),
            point(20.0, 0.0),
        )))
        .expect("first source should be added");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:second",
            point(20.0, 0.0),
            point(20.0, 20.0),
        )))
        .expect("second source should be added");
    document
        .apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
            "derived:fillet",
            Some("layer:cut-line".to_owned()),
            Fillet {
                source_entity_ids: vec!["entity:first".to_owned(), "entity:second".to_owned()],
                radius: ConstraintValue::FixedMm(3.0),
                closed: false,
            },
        )))
        .expect("fillet should be added");

    document
        .apply_command(DocumentCommand::SetEntityLayer {
            entity_id: "entity:first".to_owned(),
            layer_id: Some("layer:user".to_owned()),
        })
        .expect("entity layer should update");
    document
        .apply_command(DocumentCommand::SetDerivedLayer {
            derived_element_id: "derived:fillet".to_owned(),
            layer_id: Some("layer:user".to_owned()),
        })
        .expect("derived layer should update");
    document
        .apply_command(DocumentCommand::SetDerivedSharedStyle {
            derived_element_id: "derived:fillet".to_owned(),
            style_id: Some("style:stitch-line".to_owned()),
        })
        .expect("derived style should update");
    document
        .apply_command(DocumentCommand::SetFilletSources {
            derived_element_id: "derived:fillet".to_owned(),
            source_entity_ids: vec!["entity:first".to_owned(), "entity:second".to_owned()],
            closed: false,
        })
        .expect("fillet sources should update");

    assert_eq!(
        document.entity("entity:first").unwrap().layer_id.as_deref(),
        Some("layer:user")
    );
    let fillet = document.derived_element("derived:fillet").unwrap();
    assert_eq!(fillet.layer_id.as_deref(), Some("layer:user"));
    assert_eq!(fillet.style_id.as_deref(), Some("style:stitch-line"));
    let DerivedElementKind::Fillet(fillet_kind) = &fillet.kind else {
        panic!("expected fillet")
    };
    assert_eq!(fillet_kind.radius, ConstraintValue::FixedMm(3.0));
    assert_eq!(
        fillet_kind.source_entity_ids,
        vec!["entity:first".to_owned(), "entity:second".to_owned()]
    );
    assert!(!fillet_kind.closed);

    assert_eq!(
        document
            .layer_deletion_impact("layer:user")
            .expect("layer impact should resolve"),
        kawacad_core::document::LayerDeletionImpact {
            layer_id: "layer:user".to_owned(),
            entity_count: 1,
            derived_element_count: 1,
        }
    );
}

#[test]
fn deleting_shared_style_clears_derived_element_style_without_deleting_it() {
    let mut document = ProjectDocument::new("Derived Style Deletion");
    document
        .apply_command(DocumentCommand::AddSharedStyle(shared_style(
            "style:stitch",
            "Stitch",
            0.35,
            LinePattern::Dashed,
            0.7,
        )))
        .expect("shared style should be added");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line",
            point(0.0, 0.0),
            point(20.0, 0.0),
        )))
        .expect("source should be added");
    document
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:offset",
                Some("layer:cut-line".to_owned()),
                OffsetCurve {
                    source_entity_ids: vec!["entity:line".to_owned()],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::FixedMm(3.0),
                    direction: OffsetDirection::Left,
                },
            )
            .with_style("style:stitch"),
        ))
        .expect("derived element should be added");

    document
        .apply_command(DocumentCommand::DeleteSharedStyle(
            "style:stitch".to_owned(),
        ))
        .expect("shared style should delete");

    assert_eq!(document.derived_elements().len(), 1);
    assert_eq!(document.derived_elements()[0].style_id, None);
    assert!(document
        .drawing_snapshot(CanvasViewMode::EditDisplay)
        .entities
        .iter()
        .any(|entity| entity.id == "derived:offset:resolved:0"));
}

#[test]
fn output_model_includes_free_text_and_keeps_text_kinds_distinct() {
    let mut document = ProjectDocument::new("Free Text Output");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line",
            point(0.0, 0.0),
            point(40.0, 0.0),
        )))
        .expect("line");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:length",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:line")],
            Some(ConstraintValue::FixedMm(40.0)),
        )))
        .expect("segment length constraint");
    document
        .apply_command(DocumentCommand::AddFreeText(FreeText::new(
            "free-text:note",
            "Grain side up",
            point(10.0, 12.0),
            5.5,
        )))
        .expect("free text");

    let output = document
        .build_output_document_model(BuildOutputDocumentModelOptions {
            orientation: kawacad_core::print::PrintOrientation::Portrait,
            include_dimension_labels: true,
            include_scale_guide: true,
            rotation_deg: 0,
            printable_area_mm: PrintableAreaMm {
                left_mm: -95.0,
                right_mm: 95.0,
                top_mm: 138.5,
                bottom_mm: -138.5,
            },
        })
        .expect("output model");
    let texts = &output.output_document_model.pages[0].texts;

    assert!(texts
        .iter()
        .any(|text| text.kind == OutputTextKind::FreeText
            && text.content == "Grain side up"
            && text.position_mm == point(10.0, 12.0)
            && text.font_size_mm == 5.5));
    assert!(texts
        .iter()
        .any(|text| text.kind == OutputTextKind::DimensionLabel));
    assert!(texts
        .iter()
        .any(|text| text.kind == OutputTextKind::GuideLabel));
}

#[test]
fn free_text_survives_mixed_entity_and_constraint_documents() {
    let scenarios = [
        (
            "point-fixed",
            vec![point_entity("entity:point", point(0.0, 0.0))],
            vec![constraint(
                "constraint:fixed",
                ConstraintKind::Fixed,
                vec![entity_target("entity:point")],
                None,
            )],
        ),
        (
            "line-length",
            vec![line_entity(
                "entity:line",
                point(0.0, 0.0),
                point(30.0, 0.0),
            )],
            vec![constraint(
                "constraint:length",
                ConstraintKind::SegmentLength,
                vec![entity_target("entity:line")],
                Some(ConstraintValue::FixedMm(30.0)),
            )],
        ),
        (
            "circle-radius",
            vec![circle_entity("entity:circle", point(10.0, 10.0), 8.0)],
            vec![constraint(
                "constraint:radius",
                ConstraintKind::Radius,
                vec![entity_target("entity:circle")],
                Some(ConstraintValue::FixedMm(8.0)),
            )],
        ),
        (
            "arc-radius",
            vec![arc_entity(
                "entity:arc",
                point(0.0, 0.0),
                12.0,
                0.0,
                std::f64::consts::FRAC_PI_2,
            )],
            vec![constraint(
                "constraint:arc-radius",
                ConstraintKind::Radius,
                vec![entity_target("entity:arc")],
                Some(ConstraintValue::FixedMm(12.0)),
            )],
        ),
    ];

    for (name, entities, constraints) in scenarios {
        let mut document = ProjectDocument::new(name);
        for entity in entities {
            document
                .apply_command(DocumentCommand::AddEntity(entity))
                .expect("entity");
        }
        for constraint in constraints {
            document
                .apply_command(DocumentCommand::AddConstraint(constraint))
                .expect("constraint");
        }
        document
            .apply_command(DocumentCommand::AddFreeText(FreeText::new(
                format!("free-text:{name}"),
                format!("note for {name}"),
                point(5.0, 6.0),
                3.5,
            )))
            .expect("free text");

        assert_eq!(document.free_texts().len(), 1, "{name}");
        assert!(!document.constraints().is_empty(), "{name}");

        document
            .apply_command(DocumentCommand::UpdateFreeText(FreeText::new(
                format!("free-text:{name}"),
                format!("updated {name}"),
                point(8.0, 9.0),
                4.0,
            )))
            .expect("update free text");

        assert_eq!(document.free_texts()[0].content, format!("updated {name}"));
        assert_eq!(document.constraints().len(), 1, "{name}");
    }
}

#[test]
fn arc_sweep_angles_over_180_degrees_round_trip_without_normalization() {
    let mut document = ProjectDocument::new("Large Arc Sweeps");
    document
        .apply_command(DocumentCommand::AddEntity(arc_entity(
            "entity:ccw-large-arc",
            point(0.0, 0.0),
            10.0,
            0.0,
            200.0_f64.to_radians(),
        )))
        .expect("large counter-clockwise arc");
    document
        .apply_command(DocumentCommand::AddEntity(arc_entity(
            "entity:cw-large-arc",
            point(20.0, 0.0),
            10.0,
            0.0,
            -200.0_f64.to_radians(),
        )))
        .expect("large clockwise arc");

    let round_tripped = round_trip_json(&document);
    let ccw = round_tripped
        .entities()
        .iter()
        .find(|entity| entity.id == "entity:ccw-large-arc")
        .expect("counter-clockwise arc");
    let cw = round_tripped
        .entities()
        .iter()
        .find(|entity| entity.id == "entity:cw-large-arc")
        .expect("clockwise arc");

    let EntityKind::Arc(ccw_arc) = ccw.kind else {
        panic!("expected counter-clockwise arc");
    };
    let EntityKind::Arc(cw_arc) = cw.kind else {
        panic!("expected clockwise arc");
    };
    assert_approx_eq(ccw_arc.sweep_angle_rad, 200.0_f64.to_radians());
    assert_approx_eq(cw_arc.sweep_angle_rad, -200.0_f64.to_radians());
}

#[test]
fn updating_large_arc_sweep_from_rounded_inspector_value_does_not_normalize_to_short_side() {
    let mut document = ProjectDocument::new("Large Arc Sweep Update");
    document
        .apply_command(DocumentCommand::AddEntity(arc_entity(
            "entity:large-arc",
            point(-20.0, 65.0),
            44.72135954999579,
            2.677945044588987,
            5.695182703632019,
        )))
        .expect("large arc");

    document
        .apply_command(DocumentCommand::UpdateEntity(arc_entity(
            "entity:large-arc",
            point(-20.0, 65.0),
            44.72135954999579,
            2.677945044588987,
            326.31_f64.to_radians(),
        )))
        .expect("rounded sweep update");

    let updated = document
        .entities()
        .iter()
        .find(|entity| entity.id == "entity:large-arc")
        .expect("updated arc");
    let EntityKind::Arc(arc) = updated.kind else {
        panic!("expected arc");
    };
    assert_approx_eq(arc.sweep_angle_rad, 326.31_f64.to_radians());
}

#[test]
fn derived_element_shape_validation_rejects_zero_non_finite_and_empty_parameter_values() {
    for distance in [
        ConstraintValue::FixedMm(0.0),
        ConstraintValue::FixedMm(-1.0),
        ConstraintValue::FixedMm(f64::NAN),
        ConstraintValue::FixedMm(f64::INFINITY),
        ConstraintValue::FixedDegrees(10.0),
        ConstraintValue::Parameter(" ".to_owned()),
    ] {
        assert!(OffsetCurve {
            source_entity_ids: vec!["entity:source".to_owned()],
            source_resolved_entity_ids: Vec::new(),
            distance,
            direction: OffsetDirection::Left,
        }
        .validate_shape()
        .is_err());
    }

    for radius in [
        ConstraintValue::FixedMm(0.0),
        ConstraintValue::FixedMm(-1.0),
        ConstraintValue::FixedMm(f64::NAN),
        ConstraintValue::FixedMm(f64::INFINITY),
        ConstraintValue::FixedDegrees(90.0),
        ConstraintValue::Parameter(" ".to_owned()),
    ] {
        assert!(Fillet {
            source_entity_ids: vec!["entity:first".to_owned(), "entity:second".to_owned()],
            radius,
            closed: false,
        }
        .validate_shape()
        .is_err());
    }
}

#[test]
fn offset_curve_derives_line_from_source_and_parameter() {
    let mut document = ProjectDocument::new("Offset");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:base",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("base line");
    document
        .apply_command(DocumentCommand::AddParameter(parameter(
            "parameter:offset",
            "offset",
            3.0,
        )))
        .expect("offset parameter");
    document
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:offset",
                Some("layer:cut-line".to_owned()),
                OffsetCurve {
                    source_entity_ids: vec!["entity:base".to_owned()],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::Parameter("parameter:offset".to_owned()),
                    direction: OffsetDirection::Left,
                },
            ),
        ))
        .expect("offset curve");

    let snapshot = document.drawing_snapshot(CanvasViewMode::EditDisplay);
    let offset = snapshot
        .entities
        .iter()
        .find(|entity| entity.id == "derived:offset:resolved:0")
        .expect("resolved offset line");
    assert_line(offset, point(0.0, 3.0), point(10.0, 3.0));

    document
        .apply_command(DocumentCommand::SetParameterValue {
            parameter_id: "parameter:offset".to_owned(),
            value_mm: 5.0,
        })
        .expect("parameter update");
    let snapshot = document.drawing_snapshot(CanvasViewMode::EditDisplay);
    let offset = snapshot
        .entities
        .iter()
        .find(|entity| entity.id == "derived:offset:resolved:0")
        .expect("updated offset line");
    assert_line(offset, point(0.0, 5.0), point(10.0, 5.0));

    let round_tripped = round_trip_json(&document);
    assert_eq!(round_tripped.derived_elements().len(), 1);
    assert_eq!(
        round_tripped
            .drawing_snapshot(CanvasViewMode::EditDisplay)
            .entities
            .len(),
        2
    );
}

#[test]
fn offset_curve_open_polyline_connector_arc_preserves_center_radius_and_sweep() {
    let mut document = ProjectDocument::new("Open Offset Connector");
    for entity in [
        line_entity("entity:horizontal", point(0.0, 0.0), point(10.0, 0.0)),
        line_entity("entity:vertical", point(10.0, 0.0), point(10.0, 10.0)),
    ] {
        document
            .apply_command(DocumentCommand::AddEntity(entity))
            .expect("source line should be added");
    }

    document
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:offset",
                Some("layer:cut-line".to_owned()),
                OffsetCurve {
                    source_entity_ids: vec![
                        "entity:horizontal".to_owned(),
                        "entity:vertical".to_owned(),
                    ],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::FixedMm(2.0),
                    direction: OffsetDirection::Left,
                },
            ),
        ))
        .expect("offset should be added");

    let snapshot = document.drawing_snapshot(CanvasViewMode::EditDisplay);
    let resolved = snapshot
        .entities
        .iter()
        .filter(|entity| entity.id.starts_with("derived:offset:resolved:"))
        .collect::<Vec<_>>();
    assert_eq!(resolved.len(), 3);
    assert_line(resolved[0], point(0.0, 2.0), point(10.0, 2.0));
    assert_arc_endpoints_and_sweep(
        resolved[1],
        point(10.0, 2.0),
        point(8.0, 0.0),
        90.0_f64.to_radians(),
    );
    let connector = arc_geometry(resolved[1]);
    assert_approx_eq(connector.center.x_mm, 10.0);
    assert_approx_eq(connector.center.y_mm, 0.0);
    assert_approx_eq(connector.radius_mm, 2.0);
    assert_line(resolved[2], point(8.0, 0.0), point(8.0, 10.0));
}

#[test]
fn closed_offset_orientation_controls_inward_and_outward_side() {
    let mut clockwise = ProjectDocument::new("Clockwise Offset");
    for entity in [
        line_entity("entity:bottom", point(0.0, 0.0), point(10.0, 0.0)),
        line_entity("entity:right", point(10.0, 0.0), point(10.0, 10.0)),
        line_entity("entity:top", point(10.0, 10.0), point(0.0, 10.0)),
        line_entity("entity:left", point(0.0, 10.0), point(0.0, 0.0)),
    ] {
        clockwise
            .apply_command(DocumentCommand::AddEntity(entity))
            .expect("clockwise source should be added");
    }
    clockwise
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:inward",
                Some("layer:cut-line".to_owned()),
                OffsetCurve {
                    source_entity_ids: vec![
                        "entity:bottom".to_owned(),
                        "entity:right".to_owned(),
                        "entity:top".to_owned(),
                        "entity:left".to_owned(),
                    ],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::FixedMm(2.0),
                    direction: OffsetDirection::Inward,
                },
            ),
        ))
        .expect("clockwise inward offset should be added");
    let clockwise_lines = clockwise
        .drawing_snapshot(CanvasViewMode::EditDisplay)
        .entities
        .into_iter()
        .filter(|entity| entity.id.starts_with("derived:inward:resolved:"))
        .collect::<Vec<_>>();
    assert_eq!(clockwise_lines.len(), 4);
    assert_line(&clockwise_lines[0], point(2.0, 2.0), point(8.0, 2.0));
    assert_line(&clockwise_lines[1], point(8.0, 2.0), point(8.0, 8.0));

    let mut counter_clockwise = ProjectDocument::new("Counter Clockwise Offset");
    for entity in [
        line_entity("entity:left", point(0.0, 0.0), point(0.0, 10.0)),
        line_entity("entity:top", point(0.0, 10.0), point(10.0, 10.0)),
        line_entity("entity:right", point(10.0, 10.0), point(10.0, 0.0)),
        line_entity("entity:bottom", point(10.0, 0.0), point(0.0, 0.0)),
    ] {
        counter_clockwise
            .apply_command(DocumentCommand::AddEntity(entity))
            .expect("counter-clockwise source should be added");
    }
    counter_clockwise
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:outward",
                Some("layer:cut-line".to_owned()),
                OffsetCurve {
                    source_entity_ids: vec![
                        "entity:left".to_owned(),
                        "entity:top".to_owned(),
                        "entity:right".to_owned(),
                        "entity:bottom".to_owned(),
                    ],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::FixedMm(2.0),
                    direction: OffsetDirection::Outward,
                },
            ),
        ))
        .expect("counter-clockwise outward offset should be added");
    let counter_lines = counter_clockwise
        .drawing_snapshot(CanvasViewMode::EditDisplay)
        .entities
        .into_iter()
        .filter(|entity| entity.id.starts_with("derived:outward:resolved:"))
        .collect::<Vec<_>>();
    assert_eq!(counter_lines.len(), 4);
    assert_line(&counter_lines[0], point(-2.0, -2.0), point(-2.0, 12.0));
    assert_line(&counter_lines[1], point(-2.0, 12.0), point(12.0, 12.0));
}

#[test]
fn closed_line_and_arc_contour_offsets_inward_and_survives_round_trip_output() {
    let mut document = ProjectDocument::new("Line Arc Closed Offset");
    for entity in [
        line_entity("entity:bottom", point(0.0, 0.0), point(20.0, 0.0)),
        arc_entity(
            "entity:right-arc",
            point(20.0, 10.0),
            10.0,
            -90.0_f64.to_radians(),
            180.0_f64.to_radians(),
        ),
        line_entity("entity:top", point(20.0, 20.0), point(0.0, 20.0)),
        line_entity("entity:left", point(0.0, 20.0), point(0.0, 0.0)),
    ] {
        document
            .apply_command(DocumentCommand::AddEntity(entity))
            .expect("source contour entity should be added");
    }
    document
        .apply_command(DocumentCommand::AddParameter(parameter(
            "parameter:offset",
            "offset",
            2.0,
        )))
        .expect("offset parameter");
    document
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:stitch-line",
                Some("layer:cut-line".to_owned()),
                OffsetCurve {
                    source_entity_ids: vec![
                        "entity:bottom".to_owned(),
                        "entity:right-arc".to_owned(),
                        "entity:top".to_owned(),
                        "entity:left".to_owned(),
                    ],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::Parameter("parameter:offset".to_owned()),
                    direction: OffsetDirection::Inward,
                },
            ),
        ))
        .expect("inward offset should be added");

    for distance_mm in [2.0, 1.0, 4.0, 7.5] {
        document
            .apply_command(DocumentCommand::SetParameterValue {
                parameter_id: "parameter:offset".to_owned(),
                value_mm: distance_mm,
            })
            .expect("parameter update should keep offset valid");
        assert_line_arc_closed_offset(&document, "derived:stitch-line", distance_mm);
    }

    let round_tripped = round_trip_json(&document);
    assert_line_arc_closed_offset(&round_tripped, "derived:stitch-line", 7.5);

    let output = round_tripped
        .build_output_document_model(kawacad_core::output::BuildOutputDocumentModelOptions {
            orientation: kawacad_core::print::PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: kawacad_core::output::PrintableAreaMm {
                left_mm: -100.0,
                right_mm: 100.0,
                top_mm: 100.0,
                bottom_mm: -100.0,
            },
        })
        .expect("output document model should build");
    let output_offset_graphics = output.output_document_model.pages[0]
        .graphics
        .iter()
        .filter(|graphic| {
            graphic
                .entity_id
                .starts_with("derived:stitch-line:resolved:")
        })
        .collect::<Vec<_>>();
    assert_eq!(output_offset_graphics.len(), 4);
    assert!(output_offset_graphics
        .iter()
        .any(|graphic| graphic.kind == kawacad_core::output::OutputGraphicKind::Arc));
}

#[test]
fn offset_curve_acceptance_covers_source_variations_with_parameter_sweep() {
    for mut fixture in [
        single_line_offset_fixture(),
        open_line_arc_offset_fixture(),
        closed_line_rectangle_offset_fixture(),
        closed_line_arc_offset_fixture(),
    ] {
        for distance_mm in [1.0, 2.5] {
            fixture
                .document
                .apply_command(DocumentCommand::SetParameterValue {
                    parameter_id: "parameter:offset".to_owned(),
                    value_mm: distance_mm,
                })
                .expect("parameter update should keep offset valid");
            assert_offset_fixture_resolves_and_outputs(&fixture);

            let round_tripped = round_trip_json(&fixture.document);
            fixture.document = round_tripped;
            assert_offset_fixture_resolves_and_outputs(&fixture);
        }
    }
}

#[test]
fn offset_curve_tracks_source_update_and_history() {
    let mut document = ProjectDocument::new("Offset History");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:base",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("base line");
    document
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:offset",
                None,
                OffsetCurve {
                    source_entity_ids: vec!["entity:base".to_owned()],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::FixedMm(2.0),
                    direction: OffsetDirection::Left,
                },
            ),
        ))
        .expect("offset curve");

    document
        .apply_command(DocumentCommand::UpdateEntity(line_entity(
            "entity:base",
            point(0.0, 1.0),
            point(10.0, 1.0),
        )))
        .expect("source update");
    let snapshot = document.drawing_snapshot(CanvasViewMode::EditDisplay);
    let offset = snapshot
        .entities
        .iter()
        .find(|entity| entity.id == "derived:offset:resolved:0")
        .expect("resolved offset line");
    assert_line(offset, point(0.0, 3.0), point(10.0, 3.0));

    document.undo().expect("undo source update");
    let snapshot = document.drawing_snapshot(CanvasViewMode::EditDisplay);
    let offset = snapshot
        .entities
        .iter()
        .find(|entity| entity.id == "derived:offset:resolved:0")
        .expect("resolved offset line after undo");
    assert_line(offset, point(0.0, 2.0), point(10.0, 2.0));

    document.redo().expect("redo source update");
    let snapshot = document.drawing_snapshot(CanvasViewMode::EditDisplay);
    let offset = snapshot
        .entities
        .iter()
        .find(|entity| entity.id == "derived:offset:resolved:0")
        .expect("resolved offset line after redo");
    assert_line(offset, point(0.0, 3.0), point(10.0, 3.0));
}

#[test]
fn deleting_source_removes_dependent_offset_curve() {
    let mut document = ProjectDocument::new("Offset Delete");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:base",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("base line");
    document
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:offset",
                None,
                OffsetCurve {
                    source_entity_ids: vec!["entity:base".to_owned()],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::FixedMm(2.0),
                    direction: OffsetDirection::Left,
                },
            ),
        ))
        .expect("offset curve");

    document
        .apply_command(DocumentCommand::DeleteEntity("entity:base".to_owned()))
        .expect("delete source");

    assert!(document.entities().is_empty());
    assert!(document.derived_elements().is_empty());
    assert_eq!(document.document_warnings().len(), 1);
    assert_eq!(
        document.document_warnings()[0].derived_element_id,
        "derived:offset"
    );
    assert!(document
        .drawing_snapshot(CanvasViewMode::EditDisplay)
        .entities
        .is_empty());
}

#[test]
fn compound_deleting_all_fillet_sources_suppresses_removed_derived_warning() {
    let mut document = ProjectDocument::new("Delete Fillet Sources");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:first",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("first line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:second",
            point(10.0, 0.0),
            point(10.0, 10.0),
        )))
        .expect("second line");
    document
        .apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
            "derived:fillet",
            None,
            Fillet {
                source_entity_ids: vec!["entity:first".to_owned(), "entity:second".to_owned()],
                radius: ConstraintValue::FixedMm(2.0),
                closed: true,
            },
        )))
        .expect("fillet");

    document
        .apply_command(DocumentCommand::Compound(vec![
            DocumentCommand::DeleteEntity("entity:first".to_owned()),
            DocumentCommand::DeleteEntity("entity:second".to_owned()),
        ]))
        .expect("delete all sources");

    assert!(document.entities().is_empty());
    assert!(document.derived_elements().is_empty());
    assert!(document.document_warnings().is_empty());
}

#[test]
fn offset_curve_can_use_another_offset_curve_as_source() {
    let mut document = ProjectDocument::new("Offset Chain");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:base",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("base line");
    document
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:first",
                None,
                OffsetCurve {
                    source_entity_ids: vec!["entity:base".to_owned()],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::FixedMm(2.0),
                    direction: OffsetDirection::Left,
                },
            ),
        ))
        .expect("first offset");
    document
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:second",
                None,
                OffsetCurve {
                    source_entity_ids: vec!["derived:first".to_owned()],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::FixedMm(3.0),
                    direction: OffsetDirection::Left,
                },
            ),
        ))
        .expect("second offset");

    let snapshot = document.drawing_snapshot(CanvasViewMode::EditDisplay);
    let second = snapshot
        .entities
        .iter()
        .find(|entity| entity.id == "derived:second:resolved:0")
        .expect("resolved second offset");
    assert_line(second, point(0.0, 5.0), point(10.0, 5.0));
}

#[test]
fn offset_curve_rejects_cyclic_derived_dependency() {
    let mut document = ProjectDocument::new("Offset Cycle");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:base",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("base line");
    document
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:first",
                None,
                OffsetCurve {
                    source_entity_ids: vec!["entity:base".to_owned()],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::FixedMm(2.0),
                    direction: OffsetDirection::Left,
                },
            ),
        ))
        .expect("first offset");
    document
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:second",
                None,
                OffsetCurve {
                    source_entity_ids: vec!["derived:first".to_owned()],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::FixedMm(3.0),
                    direction: OffsetDirection::Left,
                },
            ),
        ))
        .expect("second offset");

    let result = document.apply_command(DocumentCommand::UpdateDerivedElement(
        DerivedElement::offset_curve(
            "derived:first",
            None,
            OffsetCurve {
                source_entity_ids: vec!["derived:second".to_owned()],
                source_resolved_entity_ids: Vec::new(),
                distance: ConstraintValue::FixedMm(1.0),
                direction: OffsetDirection::Left,
            },
        ),
    ));

    assert!(matches!(result, Err(CommandError::InvalidValue { .. })));
}

#[test]
fn invalidated_offset_curve_is_removed_with_warning_after_source_update() {
    let mut document = ProjectDocument::new("Offset Invalidated");
    document
        .apply_command(DocumentCommand::AddEntity(circle_entity(
            "entity:circle",
            point(0.0, 0.0),
            10.0,
        )))
        .expect("circle");
    document
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:offset",
                None,
                OffsetCurve {
                    source_entity_ids: vec!["entity:circle".to_owned()],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::FixedMm(9.0),
                    direction: OffsetDirection::Inward,
                },
            ),
        ))
        .expect("offset");

    document
        .apply_command(DocumentCommand::UpdateEntity(circle_entity(
            "entity:circle",
            point(0.0, 0.0),
            5.0,
        )))
        .expect("source update");

    assert!(document.derived_elements().is_empty());
    assert_eq!(document.document_warnings().len(), 1);
    assert_eq!(
        document.document_warnings()[0].derived_element_id,
        "derived:offset"
    );
}

#[test]
fn parameter_update_that_invalidates_offset_curve_is_rejected_without_pruning() {
    let mut document = ProjectDocument::new("Offset Parameter Guard");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:base",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("base line");
    document
        .apply_command(DocumentCommand::AddParameter(parameter(
            "parameter:offset",
            "offset",
            2.0,
        )))
        .expect("offset parameter");
    document
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:offset",
                None,
                OffsetCurve {
                    source_entity_ids: vec!["entity:base".to_owned()],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::Parameter("parameter:offset".to_owned()),
                    direction: OffsetDirection::Left,
                },
            ),
        ))
        .expect("offset curve");

    let result = document.apply_command(DocumentCommand::SetParameterValue {
        parameter_id: "parameter:offset".to_owned(),
        value_mm: 0.0,
    });

    assert!(matches!(result, Err(CommandError::InvalidValue { .. })));
    assert_eq!(
        document.parameter("parameter:offset").unwrap().value_mm,
        2.0
    );
    assert_eq!(document.derived_elements().len(), 1);
    assert!(document.document_warnings().is_empty());
}

#[test]
fn offset_curve_visibility_follows_source_layer_visibility() {
    let mut document = ProjectDocument::new("Offset Source Visibility");
    document
        .apply_command(DocumentCommand::AddLayer(layer(
            "layer:source",
            "Source",
            LayerKind::Dimension,
            true,
        )))
        .expect("source layer");
    document
        .apply_command(DocumentCommand::AddEntity(
            line_entity("entity:base", point(0.0, 0.0), point(10.0, 0.0)).on_layer("layer:source"),
        ))
        .expect("base line");
    document
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:offset",
                Some("layer:cut-line".to_owned()),
                OffsetCurve {
                    source_entity_ids: vec!["entity:base".to_owned()],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::FixedMm(2.0),
                    direction: OffsetDirection::Left,
                },
            ),
        ))
        .expect("offset curve");

    assert!(document
        .drawing_snapshot(CanvasViewMode::EditDisplay)
        .entities
        .iter()
        .any(|entity| entity.id == "derived:offset:resolved:0"));

    document
        .apply_command(DocumentCommand::SetLayerVisibility {
            layer_id: "layer:source".to_owned(),
            visible: false,
        })
        .expect("hide source layer");

    assert!(document
        .drawing_snapshot(CanvasViewMode::EditDisplay)
        .entities
        .iter()
        .all(|entity| !entity.id.starts_with("derived:offset:resolved:")));
    let output = document
        .build_output_document_model(kawacad_core::output::BuildOutputDocumentModelOptions {
            orientation: kawacad_core::print::PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: kawacad_core::output::PrintableAreaMm {
                left_mm: -100.0,
                right_mm: 100.0,
                top_mm: 100.0,
                bottom_mm: -100.0,
            },
        })
        .expect("output document model should build");
    assert!(output
        .output_document_model
        .pages
        .iter()
        .flat_map(|page| page.graphics.iter())
        .all(|graphic| !graphic.entity_id.starts_with("derived:offset:resolved:")));
}

#[test]
fn continuous_offset_sources_are_ordered_by_connected_endpoints() {
    let mut document = ProjectDocument::new("Offset Path");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:first",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("first line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:second",
            point(10.0, 0.0),
            point(10.0, 10.0),
        )))
        .expect("second line");
    document
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:path",
                None,
                OffsetCurve {
                    source_entity_ids: vec!["entity:second".to_owned(), "entity:first".to_owned()],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::FixedMm(1.0),
                    direction: OffsetDirection::Left,
                },
            ),
        ))
        .expect("continuous offset");

    let resolved_count = document
        .drawing_snapshot(CanvasViewMode::EditDisplay)
        .entities
        .iter()
        .filter(|entity| entity.id.starts_with("derived:path:resolved:"))
        .count();
    assert_eq!(resolved_count, 3);
}

#[test]
fn closed_offset_sources_create_inward_contour_without_endpoint_extension() {
    let mut document = ProjectDocument::new("Closed Offset");
    for entity in [
        line_entity("entity:bottom", point(0.0, 0.0), point(10.0, 0.0)),
        line_entity("entity:right", point(10.0, 0.0), point(10.0, 10.0)),
        line_entity("entity:top", point(10.0, 10.0), point(0.0, 10.0)),
        line_entity("entity:left", point(0.0, 10.0), point(0.0, 0.0)),
    ] {
        document
            .apply_command(DocumentCommand::AddEntity(entity))
            .expect("source");
    }
    document
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:closed",
                None,
                OffsetCurve {
                    source_entity_ids: vec![
                        "entity:bottom".to_owned(),
                        "entity:right".to_owned(),
                        "entity:top".to_owned(),
                        "entity:left".to_owned(),
                    ],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::FixedMm(1.0),
                    direction: OffsetDirection::Inward,
                },
            ),
        ))
        .expect("closed offset");

    let snapshot = document.drawing_snapshot(CanvasViewMode::EditDisplay);
    let resolved = snapshot
        .entities
        .iter()
        .filter(|entity| entity.id.starts_with("derived:closed:resolved:"))
        .collect::<Vec<_>>();
    assert_eq!(resolved.len(), 4);
    assert_line(resolved[0], point(1.0, 1.0), point(9.0, 1.0));
    assert_line(resolved[1], point(9.0, 1.0), point(9.0, 9.0));
    assert_line(resolved[2], point(9.0, 9.0), point(1.0, 9.0));
    assert_line(resolved[3], point(1.0, 9.0), point(1.0, 1.0));
}

#[test]
fn closed_offset_sources_use_arc_midpoints_for_inward_direction() {
    let mut document = ProjectDocument::new("Closed Arc Offset");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:bottom",
            point(-5.0, 0.0),
            point(5.0, 0.0),
        )))
        .expect("line");
    document
        .apply_command(DocumentCommand::AddEntity(arc_entity(
            "entity:arc",
            point(0.0, 0.0),
            5.0,
            0.0,
            std::f64::consts::PI,
        )))
        .expect("arc");
    document
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:arc-closed",
                None,
                OffsetCurve {
                    source_entity_ids: vec!["entity:bottom".to_owned(), "entity:arc".to_owned()],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::FixedMm(1.0),
                    direction: OffsetDirection::Inward,
                },
            ),
        ))
        .expect("closed arc offset");

    let snapshot = document.drawing_snapshot(CanvasViewMode::EditDisplay);
    let resolved = snapshot
        .entities
        .iter()
        .filter(|entity| entity.id.starts_with("derived:arc-closed:resolved:"))
        .collect::<Vec<_>>();
    assert_eq!(resolved.len(), 4);
    let resolved_line = snapshot
        .entities
        .iter()
        .find(|entity| entity.id == "derived:arc-closed:resolved:0")
        .expect("resolved line");
    let resolved_arc = snapshot
        .entities
        .iter()
        .find(|entity| {
            entity.id.starts_with("derived:arc-closed:resolved:")
                && matches!(entity.kind, EntityKind::Arc(arc) if (arc.radius_mm - 4.0).abs() <= 0.001)
        })
        .expect("resolved arc");
    let connector_count = resolved
        .iter()
        .filter(|entity| matches!(entity.kind, EntityKind::Arc(arc) if (arc.radius_mm - 1.0).abs() <= 0.001))
        .count();
    assert_eq!(connector_count, 2);
    assert_line(resolved_line, point(-5.0, 1.0), point(5.0, 1.0));
    assert_arc(resolved_arc, point(0.0, 0.0), 4.0);
}

#[test]
fn fillet_derives_trimmed_lines_and_arc_from_connected_lines() {
    let mut document = ProjectDocument::new("Fillet");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:first",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("first line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:second",
            point(0.0, 0.0),
            point(0.0, 10.0),
        )))
        .expect("second line");
    document
        .apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
            "derived:fillet",
            Some("layer:cut-line".to_owned()),
            Fillet {
                source_entity_ids: vec!["entity:first".to_owned(), "entity:second".to_owned()],
                radius: ConstraintValue::FixedMm(2.0),
                closed: true,
            },
        )))
        .expect("fillet");

    let snapshot = document.drawing_snapshot(CanvasViewMode::EditDisplay);
    assert_eq!(snapshot.entities.len(), 5);
    let first_trimmed = snapshot
        .entities
        .iter()
        .find(|entity| entity.id == "derived:fillet:resolved:0")
        .expect("first trimmed line");
    let fillet_arc = snapshot
        .entities
        .iter()
        .find(|entity| entity.id == "derived:fillet:resolved:1")
        .expect("fillet arc");
    let second_trimmed = snapshot
        .entities
        .iter()
        .find(|entity| entity.id == "derived:fillet:resolved:2")
        .expect("second trimmed line");

    assert_line(first_trimmed, point(10.0, 0.0), point(2.0, 0.0));
    assert_arc(fillet_arc, point(2.0, 2.0), 2.0);
    assert_arc_endpoints_and_sweep(
        fillet_arc,
        point(2.0, 0.0),
        point(0.0, 2.0),
        -std::f64::consts::FRAC_PI_2,
    );
    assert_line(second_trimmed, point(0.0, 2.0), point(0.0, 10.0));

    let round_tripped = round_trip_json(&document);
    assert_eq!(round_tripped.derived_elements().len(), 1);
}

#[test]
fn fillet_tracks_parameter_and_source_update() {
    let mut document = ProjectDocument::new("Fillet Parameter");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:first",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("first line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:second",
            point(0.0, 0.0),
            point(0.0, 10.0),
        )))
        .expect("second line");
    document
        .apply_command(DocumentCommand::AddParameter(parameter(
            "parameter:radius",
            "radius",
            2.0,
        )))
        .expect("radius parameter");
    document
        .apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
            "derived:fillet",
            None,
            Fillet {
                source_entity_ids: vec!["entity:first".to_owned(), "entity:second".to_owned()],
                radius: ConstraintValue::Parameter("parameter:radius".to_owned()),
                closed: true,
            },
        )))
        .expect("fillet");

    document
        .apply_command(DocumentCommand::SetParameterValue {
            parameter_id: "parameter:radius".to_owned(),
            value_mm: 3.0,
        })
        .expect("radius update");
    let snapshot = document.drawing_snapshot(CanvasViewMode::EditDisplay);
    let first_trimmed = snapshot
        .entities
        .iter()
        .find(|entity| entity.id == "derived:fillet:resolved:0")
        .expect("first trimmed line");
    assert_line(first_trimmed, point(10.0, 0.0), point(3.0, 0.0));

    document
        .apply_command(DocumentCommand::UpdateEntity(line_entity(
            "entity:first",
            point(0.0, 0.0),
            point(20.0, 0.0),
        )))
        .expect("source update");
    let snapshot = document.drawing_snapshot(CanvasViewMode::EditDisplay);
    let first_trimmed = snapshot
        .entities
        .iter()
        .find(|entity| entity.id == "derived:fillet:resolved:0")
        .expect("first trimmed line after source update");
    assert_line(first_trimmed, point(20.0, 0.0), point(3.0, 0.0));
}

#[test]
fn fillet_output_uses_final_shape_without_original_source_lines() {
    let mut document = ProjectDocument::new("Fillet Output");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:first",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("first line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:second",
            point(0.0, 0.0),
            point(0.0, 10.0),
        )))
        .expect("second line");
    document
        .apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
            "derived:fillet",
            None,
            Fillet {
                source_entity_ids: vec!["entity:first".to_owned(), "entity:second".to_owned()],
                radius: ConstraintValue::FixedMm(2.0),
                closed: true,
            },
        )))
        .expect("fillet");

    let output = document
        .build_output_document_model(kawacad_core::output::BuildOutputDocumentModelOptions {
            orientation: kawacad_core::print::PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: kawacad_core::output::PrintableAreaMm {
                left_mm: -100.0,
                right_mm: 100.0,
                top_mm: 100.0,
                bottom_mm: -100.0,
            },
        })
        .expect("output document model should build");
    let graphic_ids = output.output_document_model.pages[0]
        .graphics
        .iter()
        .map(|graphic| graphic.entity_id.as_str())
        .collect::<Vec<_>>();
    assert_eq!(
        graphic_ids,
        [
            "derived:fillet:resolved:0",
            "derived:fillet:resolved:1",
            "derived:fillet:resolved:2"
        ]
    );
}

#[test]
fn output_preview_snapshot_uses_output_shape_without_fillet_source_lines() {
    let mut document = ProjectDocument::new("Fillet Preview");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:first",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("first line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:second",
            point(0.0, 0.0),
            point(0.0, 10.0),
        )))
        .expect("second line");
    document
        .apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
            "derived:fillet",
            None,
            Fillet {
                source_entity_ids: vec!["entity:first".to_owned(), "entity:second".to_owned()],
                radius: ConstraintValue::FixedMm(2.0),
                closed: true,
            },
        )))
        .expect("fillet");

    let edit_display_ids = document
        .drawing_snapshot(CanvasViewMode::EditDisplay)
        .entities
        .into_iter()
        .map(|entity| entity.id)
        .collect::<Vec<_>>();
    assert!(edit_display_ids.iter().any(|id| id == "entity:first"));
    assert!(edit_display_ids.iter().any(|id| id == "entity:second"));
    assert!(edit_display_ids
        .iter()
        .any(|id| id.starts_with("derived:fillet:resolved:")));

    let output_preview_ids = document
        .drawing_snapshot(CanvasViewMode::OutputPreview)
        .entities
        .into_iter()
        .map(|entity| entity.id)
        .collect::<Vec<_>>();
    assert!(!output_preview_ids.iter().any(|id| id == "entity:first"));
    assert!(!output_preview_ids.iter().any(|id| id == "entity:second"));
    assert_eq!(
        output_preview_ids,
        [
            "derived:fillet:resolved:0",
            "derived:fillet:resolved:1",
            "derived:fillet:resolved:2"
        ]
    );
}

#[test]
fn output_preview_and_output_exclude_non_printable_layers() {
    let mut document = ProjectDocument::new("Printable Preview");
    document
        .apply_command(DocumentCommand::AddLayer(layer(
            "layer:guide",
            "Guide",
            LayerKind::Dimension,
            false,
        )))
        .expect("guide layer");
    document
        .apply_command(DocumentCommand::AddEntity(
            line_entity("entity:cut", point(0.0, 0.0), point(10.0, 0.0)).on_layer("layer:cut-line"),
        ))
        .expect("cut line");
    document
        .apply_command(DocumentCommand::AddEntity(
            line_entity("entity:guide", point(0.0, 10.0), point(10.0, 10.0))
                .on_layer("layer:guide"),
        ))
        .expect("guide line");

    let edit_display_ids = document
        .drawing_snapshot(CanvasViewMode::EditDisplay)
        .entities
        .into_iter()
        .map(|entity| entity.id)
        .collect::<Vec<_>>();
    assert!(edit_display_ids.iter().any(|id| id == "entity:guide"));

    let output_preview_ids = document
        .drawing_snapshot(CanvasViewMode::OutputPreview)
        .entities
        .into_iter()
        .map(|entity| entity.id)
        .collect::<Vec<_>>();
    assert_eq!(output_preview_ids, ["entity:cut"]);

    let output = document
        .build_output_document_model(kawacad_core::output::BuildOutputDocumentModelOptions {
            orientation: kawacad_core::print::PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: kawacad_core::output::PrintableAreaMm {
                left_mm: -100.0,
                right_mm: 100.0,
                top_mm: 100.0,
                bottom_mm: -100.0,
            },
        })
        .expect("output document model should build");
    let graphic_ids = output.output_document_model.pages[0]
        .graphics
        .iter()
        .map(|graphic| graphic.entity_id.as_str())
        .collect::<Vec<_>>();
    assert_eq!(graphic_ids, ["entity:cut"]);
}

#[test]
fn fillet_derives_open_polyline_internal_corners() {
    let mut document = ProjectDocument::new("Open Polyline Fillet");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:first",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("first line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:middle",
            point(10.0, 0.0),
            point(10.0, 10.0),
        )))
        .expect("middle line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:last",
            point(10.0, 10.0),
            point(20.0, 10.0),
        )))
        .expect("last line");
    document
        .apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
            "derived:fillet",
            None,
            Fillet {
                source_entity_ids: vec![
                    "entity:first".to_owned(),
                    "entity:middle".to_owned(),
                    "entity:last".to_owned(),
                ],
                radius: ConstraintValue::FixedMm(2.0),
                closed: true,
            },
        )))
        .expect("fillet");

    let snapshot = document.drawing_snapshot(CanvasViewMode::EditDisplay);
    assert_eq!(snapshot.entities.len(), 8);
    assert_line(
        snapshot
            .entities
            .iter()
            .find(|entity| entity.id == "derived:fillet:resolved:0")
            .expect("first trimmed line"),
        point(0.0, 0.0),
        point(8.0, 0.0),
    );
    assert_arc_endpoints_and_sweep(
        snapshot
            .entities
            .iter()
            .find(|entity| entity.id == "derived:fillet:resolved:1")
            .expect("first fillet arc"),
        point(8.0, 0.0),
        point(10.0, 2.0),
        std::f64::consts::FRAC_PI_2,
    );
    assert_line(
        snapshot
            .entities
            .iter()
            .find(|entity| entity.id == "derived:fillet:resolved:2")
            .expect("middle trimmed line"),
        point(10.0, 2.0),
        point(10.0, 8.0),
    );
    assert_arc_endpoints_and_sweep(
        snapshot
            .entities
            .iter()
            .find(|entity| entity.id == "derived:fillet:resolved:3")
            .expect("second fillet arc"),
        point(10.0, 8.0),
        point(12.0, 10.0),
        -std::f64::consts::FRAC_PI_2,
    );
    assert_line(
        snapshot
            .entities
            .iter()
            .find(|entity| entity.id == "derived:fillet:resolved:4")
            .expect("last trimmed line"),
        point(12.0, 10.0),
        point(20.0, 10.0),
    );
}

#[test]
fn fillet_derives_closed_line_contour_all_corners_from_shuffled_sources() {
    let mut document = ProjectDocument::new("Closed Fillet");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:bottom",
            point(0.0, 0.0),
            point(20.0, 0.0),
        )))
        .expect("bottom line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:right",
            point(20.0, 0.0),
            point(20.0, 10.0),
        )))
        .expect("right line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:top",
            point(20.0, 10.0),
            point(0.0, 10.0),
        )))
        .expect("top line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:left",
            point(0.0, 10.0),
            point(0.0, 0.0),
        )))
        .expect("left line");
    document
        .apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
            "derived:fillet",
            None,
            Fillet {
                source_entity_ids: vec![
                    "entity:top".to_owned(),
                    "entity:bottom".to_owned(),
                    "entity:left".to_owned(),
                    "entity:right".to_owned(),
                ],
                radius: ConstraintValue::FixedMm(2.0),
                closed: true,
            },
        )))
        .expect("fillet");

    let snapshot = document.drawing_snapshot(CanvasViewMode::EditDisplay);
    let resolved = snapshot
        .entities
        .iter()
        .filter(|entity| entity.id.starts_with("derived:fillet:resolved:"))
        .collect::<Vec<_>>();
    assert_eq!(resolved.len(), 8);
    assert_eq!(
        resolved
            .iter()
            .filter(|entity| matches!(entity.kind, EntityKind::LineSegment(_)))
            .count(),
        4
    );
    assert_eq!(
        resolved
            .iter()
            .filter(|entity| matches!(entity.kind, EntityKind::Arc(_)))
            .count(),
        4
    );

    let output = document
        .build_output_document_model(kawacad_core::output::BuildOutputDocumentModelOptions {
            orientation: kawacad_core::print::PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: kawacad_core::output::PrintableAreaMm {
                left_mm: -100.0,
                right_mm: 100.0,
                top_mm: 100.0,
                bottom_mm: -100.0,
            },
        })
        .expect("output document model should build");
    let graphic_ids = output.output_document_model.pages[0]
        .graphics
        .iter()
        .map(|graphic| graphic.entity_id.as_str())
        .collect::<Vec<_>>();
    assert_eq!(graphic_ids.len(), 8);
    assert!(graphic_ids
        .iter()
        .all(|id| id.starts_with("derived:fillet:resolved:")));

    let round_tripped = round_trip_json(&document);
    assert_eq!(
        match &round_tripped.derived_elements()[0].kind {
            kawacad_core::derived::DerivedElementKind::Fillet(fillet) => {
                fillet.source_entity_ids.len()
            }
            other => panic!("expected fillet, got {other:?}"),
        },
        4
    );
}

#[test]
fn fillet_can_leave_geometrically_closed_sources_open() {
    let mut document = ProjectDocument::new("Open Fillet With Closed Sources");
    for entity in [
        line_entity("entity:bottom", point(0.0, 0.0), point(20.0, 0.0)),
        line_entity("entity:right", point(20.0, 0.0), point(20.0, 10.0)),
        line_entity("entity:top", point(0.0, 10.0), point(20.0, 10.0)),
        line_entity("entity:left", point(0.0, 0.0), point(0.0, 10.0)),
    ] {
        document
            .apply_command(DocumentCommand::AddEntity(entity))
            .expect("line");
    }

    document
        .apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
            "derived:fillet",
            None,
            Fillet {
                source_entity_ids: vec![
                    "entity:top".to_owned(),
                    "entity:left".to_owned(),
                    "entity:bottom".to_owned(),
                    "entity:right".to_owned(),
                ],
                radius: ConstraintValue::FixedMm(2.0),
                closed: false,
            },
        )))
        .expect("open fillet");

    let snapshot = document.drawing_snapshot(CanvasViewMode::EditDisplay);
    let resolved = snapshot
        .entities
        .iter()
        .filter(|entity| entity.id.starts_with("derived:fillet:resolved:"))
        .collect::<Vec<_>>();
    assert_eq!(resolved.len(), 7);
    assert_eq!(
        resolved
            .iter()
            .filter(|entity| matches!(entity.kind, EntityKind::Arc(_)))
            .count(),
        3
    );
    let arc_centers = resolved
        .iter()
        .filter_map(|entity| match entity.kind {
            EntityKind::Arc(arc) => Some((arc.center.x_mm, arc.center.y_mm)),
            _ => None,
        })
        .collect::<Vec<_>>();
    assert!(arc_centers.contains(&(2.0, 8.0)));
    assert!(arc_centers.contains(&(2.0, 2.0)));
    assert!(arc_centers.contains(&(18.0, 2.0)));
    assert!(!arc_centers.contains(&(18.0, 8.0)));

    let round_tripped = round_trip_json(&document);
    match &round_tripped.derived_elements()[0].kind {
        kawacad_core::derived::DerivedElementKind::Fillet(fillet) => {
            assert!(!fillet.closed);
        }
        other => panic!("expected fillet, got {other:?}"),
    }
}

#[test]
fn offset_curve_can_use_fillet_as_source() {
    let mut document = ProjectDocument::new("Offset Fillet");
    for entity in [
        line_entity("entity:bottom", point(0.0, 0.0), point(20.0, 0.0)),
        line_entity("entity:right", point(20.0, 0.0), point(20.0, 10.0)),
        line_entity("entity:top", point(20.0, 10.0), point(0.0, 10.0)),
        line_entity("entity:left", point(0.0, 10.0), point(0.0, 0.0)),
    ] {
        document
            .apply_command(DocumentCommand::AddEntity(entity))
            .expect("line");
    }
    document
        .apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
            "derived:fillet",
            None,
            Fillet {
                source_entity_ids: vec![
                    "entity:bottom".to_owned(),
                    "entity:right".to_owned(),
                    "entity:top".to_owned(),
                    "entity:left".to_owned(),
                ],
                radius: ConstraintValue::FixedMm(2.0),
                closed: true,
            },
        )))
        .expect("fillet");

    document
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:offset",
                None,
                OffsetCurve {
                    source_entity_ids: vec!["derived:fillet".to_owned()],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::FixedMm(1.0),
                    direction: OffsetDirection::Inward,
                },
            ),
        ))
        .expect("offset fillet");

    let snapshot = document.drawing_snapshot(CanvasViewMode::EditDisplay);
    assert!(snapshot
        .entities
        .iter()
        .any(|entity| entity.id.starts_with("derived:offset:resolved:")));
}

#[test]
fn inward_offset_can_collapse_fillet_arcs_to_mitered_corners() {
    let mut document = ProjectDocument::new("Fillet Offset Fixture");
    for entity in [
        line_entity("entity:left", point(-50.0, 100.0), point(-50.0, 40.0)),
        line_entity("entity:bottom", point(-50.0, 40.0), point(30.0, 40.0)),
        line_entity("entity:right", point(30.0, 40.0), point(30.0, 100.0)),
        line_entity("entity:top", point(30.0, 100.0), point(-50.0, 100.0)),
    ] {
        document
            .apply_command(DocumentCommand::AddEntity(entity))
            .expect("line");
    }
    document
        .apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
            "derived:fillet",
            None,
            Fillet {
                source_entity_ids: vec![
                    "entity:top".to_owned(),
                    "entity:left".to_owned(),
                    "entity:bottom".to_owned(),
                    "entity:right".to_owned(),
                ],
                radius: ConstraintValue::FixedMm(5.0),
                closed: true,
            },
        )))
        .expect("fillet");

    document
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:offset",
                None,
                OffsetCurve {
                    source_entity_ids: vec!["derived:fillet".to_owned()],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::FixedMm(5.0),
                    direction: OffsetDirection::Inward,
                },
            ),
        ))
        .expect("offset fillet inward by radius");

    let offset_entities = document
        .drawing_snapshot(CanvasViewMode::EditDisplay)
        .entities
        .into_iter()
        .filter(|entity| entity.id.starts_with("derived:offset:resolved:"))
        .collect::<Vec<_>>();
    assert_eq!(offset_entities.len(), 4);
    assert!(offset_entities
        .iter()
        .all(|entity| matches!(entity.kind, EntityKind::LineSegment(_))));
}

#[test]
fn rectangle_fillet_can_be_applied_one_corner_at_a_time_then_offset_inward() {
    let mut document = ProjectDocument::new("Incremental Rectangle Fillet");
    for entity in [
        line_entity("entity:top", point(20.0, 10.0), point(0.0, 10.0)),
        line_entity("entity:left", point(0.0, 10.0), point(0.0, 0.0)),
        line_entity("entity:bottom", point(0.0, 0.0), point(20.0, 0.0)),
        line_entity("entity:right", point(20.0, 0.0), point(20.0, 10.0)),
    ] {
        document
            .apply_command(DocumentCommand::AddEntity(entity))
            .expect("line");
    }

    apply_rectangle_fillet(&mut document, &["entity:top", "entity:left"], false);
    assert_fillet_arc_centers(&document, &[(2.0, 8.0)]);

    apply_rectangle_fillet(
        &mut document,
        &["entity:top", "entity:left", "entity:bottom"],
        false,
    );
    assert_fillet_arc_centers(&document, &[(2.0, 8.0), (2.0, 2.0)]);

    apply_rectangle_fillet(
        &mut document,
        &["entity:top", "entity:left", "entity:bottom", "entity:right"],
        false,
    );
    assert_fillet_arc_centers(&document, &[(2.0, 8.0), (2.0, 2.0), (18.0, 2.0)]);

    apply_rectangle_fillet(
        &mut document,
        &["entity:top", "entity:left", "entity:bottom", "entity:right"],
        true,
    );
    assert_fillet_arc_centers(
        &document,
        &[(2.0, 8.0), (2.0, 2.0), (18.0, 2.0), (18.0, 8.0)],
    );

    document
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:offset",
                None,
                OffsetCurve {
                    source_entity_ids: vec!["derived:fillet".to_owned()],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::FixedMm(1.0),
                    direction: OffsetDirection::Inward,
                },
            ),
        ))
        .expect("offset filleted rectangle inward");
    assert!(document
        .drawing_snapshot(CanvasViewMode::EditDisplay)
        .entities
        .iter()
        .any(|entity| entity.id.starts_with("derived:offset:resolved:")));
}

fn apply_rectangle_fillet(document: &mut ProjectDocument, sources: &[&str], closed: bool) {
    let fillet = DerivedElement::fillet(
        "derived:fillet",
        None,
        Fillet {
            source_entity_ids: sources.iter().map(|source| (*source).to_owned()).collect(),
            radius: ConstraintValue::FixedMm(2.0),
            closed,
        },
    );
    let command = if document.derived_elements().is_empty() {
        DocumentCommand::AddDerivedElement(fillet)
    } else {
        DocumentCommand::UpdateDerivedElement(fillet)
    };
    document.apply_command(command).expect("fillet");
}

fn assert_fillet_arc_centers(document: &ProjectDocument, expected: &[(f64, f64)]) {
    let centers = document
        .drawing_snapshot(CanvasViewMode::EditDisplay)
        .entities
        .iter()
        .filter(|entity| entity.id.starts_with("derived:fillet:resolved:"))
        .filter_map(|entity| match entity.kind {
            EntityKind::Arc(arc) => Some((arc.center.x_mm, arc.center.y_mm)),
            _ => None,
        })
        .collect::<Vec<_>>();
    assert_eq!(centers.len(), expected.len());
    for center in expected {
        assert!(
            centers.contains(center),
            "missing fillet center {center:?} in {centers:?}"
        );
    }
}

#[test]
fn fillet_rejects_concave_closed_line_contour_without_changing_document() {
    let mut document = ProjectDocument::new("Concave Fillet");
    for entity in [
        line_entity("entity:bottom", point(0.0, 0.0), point(10.0, 0.0)),
        line_entity("entity:right", point(10.0, 0.0), point(10.0, 10.0)),
        line_entity("entity:notch-right", point(10.0, 10.0), point(5.0, 5.0)),
        line_entity("entity:notch-left", point(5.0, 5.0), point(0.0, 10.0)),
        line_entity("entity:left", point(0.0, 10.0), point(0.0, 0.0)),
    ] {
        document
            .apply_command(DocumentCommand::AddEntity(entity))
            .expect("concave contour line should be added");
    }

    let result =
        document.apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
            "derived:fillet",
            None,
            Fillet {
                source_entity_ids: vec![
                    "entity:bottom".to_owned(),
                    "entity:right".to_owned(),
                    "entity:notch-right".to_owned(),
                    "entity:notch-left".to_owned(),
                    "entity:left".to_owned(),
                ],
                radius: ConstraintValue::FixedMm(1.0),
                closed: true,
            },
        )));

    assert!(
        matches!(result, Err(CommandError::InvalidValue { field, reason }) if field == "fillet source" && reason == "closed fillet contours must be convex")
    );
    assert!(document.derived_elements().is_empty());
}

#[test]
fn fillet_rejects_disconnected_path_without_changing_document() {
    let mut document = ProjectDocument::new("Disconnected Fillet");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:first",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("first line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:second",
            point(10.0, 0.0),
            point(10.0, 10.0),
        )))
        .expect("second line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:disconnected",
            point(20.0, 20.0),
            point(30.0, 20.0),
        )))
        .expect("disconnected line");

    let result =
        document.apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
            "derived:fillet",
            None,
            Fillet {
                source_entity_ids: vec![
                    "entity:first".to_owned(),
                    "entity:second".to_owned(),
                    "entity:disconnected".to_owned(),
                ],
                radius: ConstraintValue::FixedMm(2.0),
                closed: true,
            },
        )));

    assert!(matches!(result, Err(CommandError::InvalidValue { .. })));
    assert!(document.derived_elements().is_empty());
}

#[test]
fn fillet_rejects_overlapping_trims_without_changing_document() {
    let mut document = ProjectDocument::new("Large Fillet");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:first",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("first line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:middle",
            point(10.0, 0.0),
            point(10.0, 3.0),
        )))
        .expect("middle line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:last",
            point(10.0, 3.0),
            point(20.0, 3.0),
        )))
        .expect("last line");

    let result =
        document.apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
            "derived:fillet",
            None,
            Fillet {
                source_entity_ids: vec![
                    "entity:first".to_owned(),
                    "entity:middle".to_owned(),
                    "entity:last".to_owned(),
                ],
                radius: ConstraintValue::FixedMm(2.0),
                closed: true,
            },
        )));

    assert!(
        matches!(result, Err(CommandError::InvalidValue { field, .. }) if field == "fillet radius")
    );
    assert!(document.derived_elements().is_empty());
}

#[test]
fn fillet_rejects_source_shared_by_multiple_fillets() {
    let mut document = ProjectDocument::new("Adjacent Fillets");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:first",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("first line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:middle",
            point(10.0, 0.0),
            point(10.0, 10.0),
        )))
        .expect("middle line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:last",
            point(10.0, 10.0),
            point(20.0, 10.0),
        )))
        .expect("last line");
    document
        .apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
            "derived:first-fillet",
            None,
            Fillet {
                source_entity_ids: vec!["entity:first".to_owned(), "entity:middle".to_owned()],
                radius: ConstraintValue::FixedMm(2.0),
                closed: true,
            },
        )))
        .expect("first fillet");

    let result =
        document.apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
            "derived:second-fillet",
            None,
            Fillet {
                source_entity_ids: vec!["entity:middle".to_owned(), "entity:last".to_owned()],
                radius: ConstraintValue::FixedMm(2.0),
                closed: true,
            },
        )));

    assert!(
        matches!(result, Err(CommandError::InvalidValue { field, .. }) if field == "fillet source")
    );
    assert_eq!(document.derived_elements().len(), 1);
}

#[test]
fn fillet_trims_connected_line_arc_sources_and_rejects_excessive_radius_atomically() {
    let mut document = ProjectDocument::new("Fillet Line Arc");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("line");
    document
        .apply_command(DocumentCommand::AddEntity(arc_entity(
            "entity:arc",
            point(20.0, 0.0),
            10.0,
            std::f64::consts::PI,
            -std::f64::consts::FRAC_PI_2,
        )))
        .expect("arc");

    document
        .apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
            "derived:fillet",
            None,
            Fillet {
                source_entity_ids: vec!["entity:line".to_owned(), "entity:arc".to_owned()],
                radius: ConstraintValue::FixedMm(2.0),
                closed: false,
            },
        )))
        .expect("line-arc fillet");

    let resolved = resolved_entities(&document, "derived:fillet");
    assert_eq!(resolved.len(), 3);
    let EntityKind::LineSegment(trimmed_line) = resolved[0].kind else {
        panic!("expected trimmed line")
    };
    let EntityKind::Arc(fillet_arc) = resolved[1].kind else {
        panic!("expected fillet arc")
    };
    let EntityKind::Arc(trimmed_source_arc) = resolved[2].kind else {
        panic!("expected trimmed source arc")
    };
    assert_approx_eq(fillet_arc.radius_mm, 2.0);
    assert_approx_eq(
        trimmed_line.end.x_mm,
        fillet_arc.center.x_mm + fillet_arc.radius_mm * fillet_arc.start_angle_rad.cos(),
    );
    assert_approx_eq(
        trimmed_line.end.y_mm,
        fillet_arc.center.y_mm + fillet_arc.radius_mm * fillet_arc.start_angle_rad.sin(),
    );
    assert_approx_eq(
        trimmed_source_arc.start_angle_rad.cos() * trimmed_source_arc.radius_mm
            + trimmed_source_arc.center.x_mm,
        fillet_arc.center.x_mm
            + fillet_arc.radius_mm
                * (fillet_arc.start_angle_rad + fillet_arc.sweep_angle_rad).cos(),
    );
    assert_approx_eq(
        trimmed_source_arc.start_angle_rad.sin() * trimmed_source_arc.radius_mm
            + trimmed_source_arc.center.y_mm,
        fillet_arc.center.y_mm
            + fillet_arc.radius_mm
                * (fillet_arc.start_angle_rad + fillet_arc.sweep_angle_rad).sin(),
    );

    document
        .apply_command(DocumentCommand::AddParameter(parameter(
            "parameter:radius",
            "radius",
            2.0,
        )))
        .expect("radius parameter");
    document
        .apply_command(DocumentCommand::SetDerivedRadius {
            derived_element_id: "derived:fillet".to_owned(),
            value: ConstraintValue::Parameter("parameter:radius".to_owned()),
        })
        .expect("parameterize line-arc fillet");
    document
        .apply_command(DocumentCommand::SetParameterValue {
            parameter_id: "parameter:radius".to_owned(),
            value_mm: 1.0,
        })
        .expect("update line-arc fillet radius parameter");
    let resolved = resolved_entities(&document, "derived:fillet");
    let EntityKind::Arc(updated_fillet_arc) = resolved[1].kind else {
        panic!("expected updated fillet arc")
    };
    assert_approx_eq(updated_fillet_arc.radius_mm, 1.0);

    let round_tripped = round_trip_json(&document);
    assert_eq!(round_tripped.derived_elements().len(), 1);
    assert_eq!(resolved_entities(&round_tripped, "derived:fillet").len(), 3);
    let output = round_tripped
        .build_output_document_model(BuildOutputDocumentModelOptions {
            orientation: kawacad_core::print::PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: PrintableAreaMm {
                left_mm: -100.0,
                right_mm: 100.0,
                top_mm: 100.0,
                bottom_mm: -100.0,
            },
        })
        .expect("line-arc fillet output");
    assert_eq!(
        output.output_document_model.pages[0]
            .graphics
            .iter()
            .map(|graphic| graphic.entity_id.as_str())
            .collect::<Vec<_>>(),
        [
            "derived:fillet:resolved:0",
            "derived:fillet:resolved:1",
            "derived:fillet:resolved:2"
        ]
    );

    document.undo().expect("undo radius parameter update");
    let resolved = resolved_entities(&document, "derived:fillet");
    let EntityKind::Arc(undone_fillet_arc) = resolved[1].kind else {
        panic!("expected undone fillet arc")
    };
    assert_approx_eq(undone_fillet_arc.radius_mm, 2.0);
    document.redo().expect("redo radius parameter update");
    let resolved = resolved_entities(&document, "derived:fillet");
    let EntityKind::Arc(redone_fillet_arc) = resolved[1].kind else {
        panic!("expected redone fillet arc")
    };
    assert_approx_eq(redone_fillet_arc.radius_mm, 1.0);

    let before = document.clone();
    let result = document.apply_command(DocumentCommand::SetDerivedRadius {
        derived_element_id: "derived:fillet".to_owned(),
        value: ConstraintValue::FixedMm(20.0),
    });
    assert!(matches!(
        result,
        Err(CommandError::InvalidValue {
            field: "fillet radius",
            ..
        })
    ));
    assert_eq!(document, before);
}

#[test]
fn kawa_schema_constraint_kinds_match_public_constraint_kind_json() {
    let schema: serde_json::Value =
        serde_json::from_str(include_str!("../../../schemas/kawa/0.1.0.schema.json"))
            .expect("schema should be valid json");
    let schema_kinds = schema
        .pointer("/$defs/constraintKind/enum")
        .and_then(serde_json::Value::as_array)
        .expect("constraint kind enum should exist");

    let expected_kinds = [
        ConstraintKind::Coincident,
        ConstraintKind::Horizontal,
        ConstraintKind::Vertical,
        ConstraintKind::Parallel,
        ConstraintKind::Perpendicular,
        ConstraintKind::Tangent,
        ConstraintKind::Symmetric,
        ConstraintKind::Distance,
        ConstraintKind::HorizontalDistance,
        ConstraintKind::VerticalDistance,
        ConstraintKind::PointLineDistance,
        ConstraintKind::LineLineDistance,
        ConstraintKind::PointOnLine,
        ConstraintKind::SegmentLength,
        ConstraintKind::Angle,
        ConstraintKind::Fixed,
        ConstraintKind::Diameter,
        ConstraintKind::Radius,
        ConstraintKind::EqualSegmentLength,
    ]
    .into_iter()
    .map(|kind| serde_json::to_value(kind).expect("constraint kind should serialize"))
    .collect::<Vec<_>>();

    assert_eq!(schema_kinds, &expected_kinds);
}

#[test]
fn document_name_can_be_renamed() {
    let mut document = ProjectDocument::new("Leather");

    document
        .apply_command(DocumentCommand::RenameDocument {
            name: " Pattern A ".to_owned(),
        })
        .expect("document rename should succeed");

    assert_eq!(document.metadata().name, "Pattern A");
    assert!(matches!(
        document.apply_command(DocumentCommand::RenameDocument {
            name: " ".to_owned(),
        }),
        Err(kawacad_core::command::CommandError::InvalidValue {
            field: "document name",
            ..
        })
    ));
    assert_eq!(document.metadata().name, "Pattern A");
}

#[test]
fn arc_metric_partial_update_preserves_unspecified_values() {
    let mut document = ProjectDocument::new("Arc partial update");
    document
        .apply_command(DocumentCommand::AddEntity(arc_entity(
            "entity:arc",
            point(10.0, 20.0),
            8.0,
            0.25,
            1.5,
        )))
        .expect("arc should be added");

    document
        .apply_command(DocumentCommand::SetEntityMetric {
            entity_id: "entity:arc".to_owned(),
            metric: EntityMetric::ArcUpdate {
                radius_mm: None,
                start_angle_rad: Some(0.75),
                sweep_angle_rad: None,
            },
        })
        .expect("partial arc update should succeed");

    let EntityKind::Arc(arc) = &document.entity("entity:arc").expect("arc exists").kind else {
        panic!("expected arc")
    };
    assert_eq!(arc.center, point(10.0, 20.0));
    assert_eq!(arc.radius_mm, 8.0);
    assert_eq!(arc.start_angle_rad, 0.75);
    assert_eq!(arc.sweep_angle_rad, 1.5);

    let before_empty_update = document.clone();
    assert!(matches!(
        document.apply_command(DocumentCommand::SetEntityMetric {
            entity_id: "entity:arc".to_owned(),
            metric: EntityMetric::ArcUpdate {
                radius_mm: None,
                start_angle_rad: None,
                sweep_angle_rad: None,
            },
        }),
        Err(CommandError::InvalidValue {
            field: "arc metric",
            ..
        })
    ));
    assert_eq!(document, before_empty_update);
}

#[test]
fn document_apply_command_covers_crud_and_constraint_reapplication() {
    let mut document = ProjectDocument::new("Leather");

    document
        .apply_command(DocumentCommand::AddLayer(layer(
            "layer:user",
            "User",
            LayerKind::Dimension,
            true,
        )))
        .expect("layer should be added");
    document
        .apply_command(DocumentCommand::AddParameter(parameter(
            "parameter:length",
            "length",
            20.0,
        )))
        .expect("parameter should be added");

    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line-a",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("line should be added");
    document
        .apply_command(DocumentCommand::AddEntity(circle_entity(
            "entity:circle-a",
            point(5.0, 5.0),
            3.0,
        )))
        .expect("circle should be added");
    document
        .apply_command(DocumentCommand::AddEntity(point_entity(
            "entity:point-a",
            point(2.0, 2.0),
        )))
        .expect("point should be added");

    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:length",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:line-a")],
            Some(ConstraintValue::Parameter("parameter:length".to_owned())),
        )))
        .expect("segment length constraint should be added");
    assert_line_length(document.entity("entity:line-a").expect("line exists"), 20.0);
    assert!(matches!(
        document.constraints()[0].status,
        ConstraintStatus::UnderConstrained
    ));

    document
        .apply_command(DocumentCommand::SetParameterValue {
            parameter_id: "parameter:length".to_owned(),
            value_mm: 30.0,
        })
        .expect("parameter value should update");
    assert_line_length(document.entity("entity:line-a").expect("line exists"), 30.0);

    document
        .apply_command(DocumentCommand::UpdateConstraint(constraint(
            "constraint:length",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:line-a")],
            Some(ConstraintValue::FixedMm(35.0)),
        )))
        .expect("constraint should update");
    assert_line_length(document.entity("entity:line-a").expect("line exists"), 35.0);

    document
        .apply_command(DocumentCommand::SetLayerVisibility {
            layer_id: "layer:user".to_owned(),
            visible: false,
        })
        .expect("layer visibility should change");
    assert!(
        !document
            .layers()
            .iter()
            .find(|layer| layer.id == "layer:user")
            .unwrap()
            .visible
    );

    document
        .apply_command(DocumentCommand::SetLayerPrintable {
            layer_id: "layer:user".to_owned(),
            printable: false,
        })
        .expect("layer printable should change");
    assert!(
        !document
            .layers()
            .iter()
            .find(|layer| layer.id == "layer:user")
            .unwrap()
            .printable
    );
    document
        .apply_command(DocumentCommand::RenameLayer {
            layer_id: "layer:user".to_owned(),
            name: "Renamed User".to_owned(),
        })
        .expect("layer should rename");
    assert_eq!(
        document
            .layers()
            .iter()
            .find(|layer| layer.id == "layer:user")
            .unwrap()
            .name,
        "Renamed User"
    );
    document
        .apply_command(DocumentCommand::AddLayer(layer(
            "layer:construction",
            "Construction",
            LayerKind::Construction,
            false,
        )))
        .expect("construction layer should be added");

    assert!(matches!(
        document.apply_command(DocumentCommand::SetLayerPrintable {
            layer_id: "layer:construction".to_owned(),
            printable: true,
        }),
        Err(kawacad_core::command::CommandError::InvalidValue {
            field: "layer printable",
            ..
        })
    ));

    let reassigned = point_entity("entity:reassigned", point(9.0, 9.0)).on_layer("layer:user");
    document
        .apply_command(DocumentCommand::AddEntity(reassigned))
        .expect("reassigned entity should be added");
    document
        .apply_command(DocumentCommand::DeleteLayer("layer:user".to_owned()))
        .expect("user layer should delete");
    assert!(document
        .layers()
        .iter()
        .all(|layer| layer.id != "layer:user"));
    assert_eq!(
        document
            .entity("entity:reassigned")
            .unwrap()
            .layer_id
            .as_deref(),
        Some("layer:cut-line")
    );

    document
        .apply_command(DocumentCommand::DeleteConstraint(
            "constraint:length".to_owned(),
        ))
        .expect("constraint should delete");
    assert!(document.constraints().is_empty());

    let round_tripped = round_trip_json(&document);
    assert_eq!(round_tripped, document);

    let file_path = temp_path("document-round-trip.kawa");
    document
        .write_json_file(&file_path)
        .expect("document should write to file");
    let file_round_trip =
        ProjectDocument::read_json_file(&file_path).expect("document should read from file");
    assert_eq!(file_round_trip, document);
    let _ = std::fs::remove_file(&file_path);

    let snapshot = document.drawing_snapshot(CanvasViewMode::EditDisplay);
    assert_eq!(snapshot.view_mode, CanvasViewMode::EditDisplay);
}

#[test]
fn canvas_view_mode_uses_new_boundary_names_and_rejects_legacy_names() {
    assert_eq!(
        serde_json::to_string(&CanvasViewMode::EditDisplay).expect("serialize edit display"),
        r#""editDisplay""#
    );
    assert_eq!(
        serde_json::to_string(&CanvasViewMode::OutputPreview).expect("serialize output preview"),
        r#""outputPreview""#
    );
    assert!(serde_json::from_str::<CanvasViewMode>(r#""historyEdit""#).is_err());
    assert!(serde_json::from_str::<CanvasViewMode>(r#""finalContour""#).is_err());
}

#[test]
fn measurement_annotations_are_view_metadata_and_round_trip() {
    let mut document = ProjectDocument::new("Measurements");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line-a",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("line should be added");

    document
        .apply_command(DocumentCommand::AddMeasurementAnnotation(
            measurement_annotation(
                "measurement:length-a",
                MeasurementAnnotationKind::SegmentLength,
                vec![entity_target("entity:line-a")],
            ),
        ))
        .expect("measurement annotation should be added");

    assert_eq!(document.measurement_annotations().len(), 1);
    assert_eq!(document.constraints().len(), 0);
    assert_eq!(
        document
            .drawing_snapshot(CanvasViewMode::EditDisplay)
            .constraint_status,
        ConstraintStatus::Unknown
    );

    let mut updated = document.measurement_annotations()[0].clone();
    updated.label_offset_mm = point(4.0, 1.5);
    updated.overall_offset_mm = point(0.0, 8.0);
    document
        .apply_command(DocumentCommand::UpdateMeasurementAnnotation(
            updated.clone(),
        ))
        .expect("measurement annotation should update");
    assert_eq!(document.measurement_annotations()[0], updated);

    document
        .apply_command(DocumentCommand::MoveMeasurementAnnotation {
            annotation_id: "measurement:length-a".to_owned(),
            delta: point(2.0, -1.0),
            label_only: true,
        })
        .expect("measurement label offset should move");
    assert_eq!(
        document.measurement_annotations()[0].label_offset_mm,
        point(6.0, 0.5)
    );
    assert_eq!(
        document.measurement_annotations()[0].overall_offset_mm,
        point(0.0, 8.0)
    );
    let moved = document.measurement_annotations()[0].clone();

    let round_tripped = round_trip_json(&document);
    assert_eq!(round_tripped, document);
    assert_eq!(round_tripped.measurement_annotations()[0], moved);

    document.undo().expect("annotation move should undo");
    assert_eq!(document.measurement_annotations()[0], updated);
    document.redo().expect("annotation move should redo");
    assert_eq!(document.measurement_annotations()[0], moved);
}

#[test]
fn dimension_constraint_annotations_are_view_metadata_and_round_trip() {
    let mut document = ProjectDocument::new("Dimension Display");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line-a",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("line should be added");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:length-a",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:line-a")],
            Some(ConstraintValue::FixedMm(10.0)),
        )))
        .expect("dimension constraint should be added");

    let annotation = DimensionConstraintAnnotation {
        constraint_id: "constraint:length-a".to_owned(),
        label_offset_mm: point(0.0, 0.0),
        overall_offset_mm: point(0.0, 0.0),
        visible: true,
    };
    assert_eq!(
        document.dimension_constraint_annotations(),
        std::slice::from_ref(&annotation)
    );
    assert_eq!(document.constraints().len(), 1);

    document
        .apply_command(DocumentCommand::MoveDimensionConstraintAnnotation {
            constraint_id: "constraint:length-a".to_owned(),
            delta: point(2.0, -1.0),
            label_only: false,
        })
        .expect("dimension overall offset should move");
    assert_eq!(
        document.dimension_constraint_annotations()[0].label_offset_mm,
        point(0.0, 0.0)
    );
    assert_eq!(
        document.dimension_constraint_annotations()[0].overall_offset_mm,
        point(2.0, -1.0)
    );

    let mut updated = document.dimension_constraint_annotations()[0].clone();
    updated.label_offset_mm = point(3.0, 1.0);
    updated.overall_offset_mm = point(-2.0, 4.0);
    document
        .apply_command(DocumentCommand::UpdateDimensionConstraintAnnotation(
            updated.clone(),
        ))
        .expect("dimension constraint annotation should update");
    assert_eq!(
        document.dimension_constraint_annotations(),
        &[updated.clone()]
    );

    let round_tripped = round_trip_json(&document);
    assert_eq!(round_tripped, document);
    assert_eq!(
        round_tripped.dimension_constraint_annotations(),
        &[updated.clone()]
    );

    document.undo().expect("annotation update should undo");
    assert_eq!(
        document.dimension_constraint_annotations(),
        &[DimensionConstraintAnnotation {
            constraint_id: "constraint:length-a".to_owned(),
            label_offset_mm: point(0.0, 0.0),
            overall_offset_mm: point(2.0, -1.0),
            visible: true,
        }]
    );
    document.redo().expect("annotation update should redo");
    assert_eq!(
        document.dimension_constraint_annotations(),
        &[updated.clone()]
    );

    document
        .apply_command(DocumentCommand::DeleteConstraint(
            "constraint:length-a".to_owned(),
        ))
        .expect("constraint should delete");
    assert!(document.dimension_constraint_annotations().is_empty());
}

#[test]
fn moving_dimension_constraint_updates_automatically_created_annotation() {
    let mut document = ProjectDocument::new("Dimension annotation default");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line-a",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("line should be added");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:length-a",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:line-a")],
            Some(ConstraintValue::FixedMm(10.0)),
        )))
        .expect("constraint should be added");

    document
        .apply_command(DocumentCommand::MoveDimensionConstraintAnnotation {
            constraint_id: "constraint:length-a".to_owned(),
            delta: point(2.0, -1.0),
            label_only: true,
        })
        .expect("initial dimension annotation move should succeed");

    assert_eq!(
        document.dimension_constraint_annotations(),
        &[DimensionConstraintAnnotation {
            constraint_id: "constraint:length-a".to_owned(),
            label_offset_mm: point(2.0, -1.0),
            overall_offset_mm: point(0.0, 0.0),
            visible: true,
        }]
    );
}

#[test]
fn adding_existing_dimension_constraint_annotation_updates_automatic_annotation() {
    let mut document = ProjectDocument::new("Dimension annotation upsert");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line-a",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("line should be added");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:length-a",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:line-a")],
            Some(ConstraintValue::FixedMm(10.0)),
        )))
        .expect("constraint should be added");

    let annotation = DimensionConstraintAnnotation {
        constraint_id: "constraint:length-a".to_owned(),
        label_offset_mm: point(3.0, 1.0),
        overall_offset_mm: point(-2.0, 4.0),
        visible: false,
    };
    document
        .apply_command(DocumentCommand::AddDimensionConstraintAnnotation(
            annotation.clone(),
        ))
        .expect("explicit annotation should update the automatic annotation");

    assert_eq!(document.dimension_constraint_annotations(), &[annotation]);
}

#[test]
fn axis_dimension_constraints_are_projected_immediately_after_addition() {
    let mut document = ProjectDocument::new("Axis dimension display");
    document
        .apply_command(DocumentCommand::AddEntity(point_entity(
            "entity:first",
            point(2.0, 3.0),
        )))
        .expect("first point should be added");
    document
        .apply_command(DocumentCommand::AddEntity(point_entity(
            "entity:second",
            point(12.0, 8.0),
        )))
        .expect("second point should be added");

    for (id, kind) in [
        ("constraint:horizontal", ConstraintKind::HorizontalDistance),
        ("constraint:vertical", ConstraintKind::VerticalDistance),
    ] {
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                id,
                kind,
                vec![
                    entity_target("entity:first"),
                    entity_target("entity:second"),
                ],
                Some(ConstraintValue::FixedMm(
                    if kind == ConstraintKind::HorizontalDistance {
                        10.0
                    } else {
                        5.0
                    },
                )),
            )))
            .expect("axis dimension constraint should be added");
    }

    assert_eq!(document.dimension_constraint_annotations().len(), 2);
    let projection = document.canvas_projection(CanvasViewMode::EditDisplay);
    assert_eq!(projection.dimension_constraints.len(), 2);
    assert!(projection
        .dimension_constraints
        .iter()
        .all(|item| item.visible && item.start_mm.is_some() && item.end_mm.is_some()));
}

#[test]
fn measurement_annotations_are_removed_when_referenced_entity_is_deleted() {
    let mut document = ProjectDocument::new("Measurement References");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line-a",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("line should be added");
    document
        .apply_command(DocumentCommand::AddMeasurementAnnotation(
            measurement_annotation(
                "measurement:length-a",
                MeasurementAnnotationKind::SegmentLength,
                vec![entity_target("entity:line-a")],
            ),
        ))
        .expect("measurement annotation should be added");

    document
        .apply_command(DocumentCommand::DeleteEntity("entity:line-a".to_owned()))
        .expect("referenced entity should delete");

    assert!(document.measurement_annotations().is_empty());
    assert_eq!(document.document_warnings().len(), 1);
    assert_eq!(
        document.document_warnings()[0].kind,
        kawacad_core::document::DocumentWarningKind::MeasurementAnnotationRemoved
    );
    assert_eq!(
        document.document_warnings()[0].measurement_annotation_id,
        "measurement:length-a"
    );
}

#[test]
fn measurement_annotation_targets_are_validated_without_solving_constraints() {
    let mut document = ProjectDocument::new("Measurement Validation");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line-a",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("line a should be added");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line-b",
            point(20.0, 0.0),
            point(30.0, 0.0),
        )))
        .expect("line b should be added");

    let result = document.apply_command(DocumentCommand::AddMeasurementAnnotation(
        measurement_annotation(
            "measurement:angle",
            MeasurementAnnotationKind::Angle,
            vec![
                entity_target("entity:line-a"),
                entity_target("entity:line-b"),
            ],
        ),
    ));
    assert!(matches!(result, Err(CommandError::InvalidValue { .. })));
    assert!(document.measurement_annotations().is_empty());

    document
        .apply_command(DocumentCommand::AddMeasurementAnnotation(
            measurement_annotation(
                "measurement:distance",
                MeasurementAnnotationKind::Distance,
                vec![
                    point_target("entity:line-a", ControlPointKind::Start),
                    point_target("entity:line-b", ControlPointKind::End),
                ],
            ),
        ))
        .expect("point distance annotation should be accepted");
    assert_eq!(document.measurement_annotations().len(), 1);
    assert!(document.constraints().is_empty());
}

#[test]
fn coincident_constraints_on_fixed_points_are_fully_constrained() {
    let mut document = ProjectDocument::new("Coincident Fixed Points");
    document
        .apply_command(DocumentCommand::AddEntity(point_entity(
            "entity:point-a",
            point(0.0, 0.0),
        )))
        .expect("point a should be added");
    document
        .apply_command(DocumentCommand::AddEntity(point_entity(
            "entity:point-b",
            point(10.0, 0.0),
        )))
        .expect("point b should be added");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line-a",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("line should be added");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:fixed-a",
            ConstraintKind::Fixed,
            vec![entity_target("entity:point-a")],
            None,
        )))
        .expect("fixed a should be added");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:fixed-b",
            ConstraintKind::Fixed,
            vec![entity_target("entity:point-b")],
            None,
        )))
        .expect("fixed b should be added");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:coincident-a",
            ConstraintKind::Coincident,
            vec![
                point_target("entity:line-a", ControlPointKind::Start),
                entity_target("entity:point-a"),
            ],
            None,
        )))
        .expect("coincident a should be added");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:coincident-b",
            ConstraintKind::Coincident,
            vec![
                point_target("entity:line-a", ControlPointKind::End),
                entity_target("entity:point-b"),
            ],
            None,
        )))
        .expect("coincident b should be added");

    assert!(matches!(
        document
            .constraints()
            .iter()
            .find(|constraint| constraint.id == "constraint:coincident-a")
            .expect("coincident a exists")
            .status,
        ConstraintStatus::FullyConstrained
    ));
    assert!(matches!(
        document
            .constraints()
            .iter()
            .find(|constraint| constraint.id == "constraint:coincident-b")
            .expect("coincident b exists")
            .status,
        ConstraintStatus::FullyConstrained
    ));
}

#[test]
fn entity_constraint_statuses_report_remaining_degrees_of_freedom() {
    let mut document = ProjectDocument::new("Entity DoF");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("line");
    document
        .apply_command(DocumentCommand::AddEntity(circle_entity(
            "entity:circle",
            point(20.0, 20.0),
            5.0,
        )))
        .expect("circle");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:line-start-fixed",
            ConstraintKind::Fixed,
            vec![point_target("entity:line", ControlPointKind::Start)],
            None,
        )))
        .expect("fixed start");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:line-horizontal",
            ConstraintKind::Horizontal,
            vec![entity_target("entity:line")],
            None,
        )))
        .expect("horizontal");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:line-distance",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:line")],
            Some(ConstraintValue::FixedMm(10.0)),
        )))
        .expect("distance");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:circle-center-fixed",
            ConstraintKind::Fixed,
            vec![point_target("entity:circle", ControlPointKind::Center)],
            None,
        )))
        .expect("circle center");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:circle-radius",
            ConstraintKind::Radius,
            vec![entity_target("entity:circle")],
            Some(ConstraintValue::FixedMm(5.0)),
        )))
        .expect("circle radius");

    let statuses = document.entity_constraint_statuses();
    let line = statuses
        .iter()
        .find(|status| status.entity_id == "entity:line")
        .expect("line status");
    assert_eq!(line.status, ConstraintStatus::FullyConstrained);
    assert_eq!(line.remaining_dof, 0);

    let circle = statuses
        .iter()
        .find(|status| status.entity_id == "entity:circle")
        .expect("circle status");
    assert_eq!(circle.status, ConstraintStatus::FullyConstrained);
    assert_eq!(circle.remaining_dof, 0);
}

#[test]
fn entity_constraint_statuses_report_dof_reduction_by_entity_shape() {
    let mut document = ProjectDocument::new("Entity DoF Details");
    document
        .apply_command(DocumentCommand::AddEntity(point_entity(
            "entity:point",
            point(0.0, 0.0),
        )))
        .expect("point");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("line");
    document
        .apply_command(DocumentCommand::AddEntity(circle_entity(
            "entity:circle",
            point(20.0, 20.0),
            5.0,
        )))
        .expect("circle");
    document
        .apply_command(DocumentCommand::AddEntity(arc_entity(
            "entity:arc",
            point(40.0, 40.0),
            8.0,
            0.0,
            std::f64::consts::FRAC_PI_2,
        )))
        .expect("arc");

    assert_entity_remaining_dof(&document, "entity:point", 2);
    assert_entity_remaining_dof(&document, "entity:line", 4);
    assert_entity_remaining_dof(&document, "entity:circle", 3);
    assert_entity_remaining_dof(&document, "entity:arc", 5);

    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:point-fixed",
            ConstraintKind::Fixed,
            vec![entity_target("entity:point")],
            None,
        )))
        .expect("point fixed");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:line-start-fixed",
            ConstraintKind::Fixed,
            vec![point_target("entity:line", ControlPointKind::Start)],
            None,
        )))
        .expect("line start fixed");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:line-horizontal",
            ConstraintKind::Horizontal,
            vec![entity_target("entity:line")],
            None,
        )))
        .expect("line horizontal");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:circle-radius",
            ConstraintKind::Radius,
            vec![entity_target("entity:circle")],
            Some(ConstraintValue::FixedMm(5.0)),
        )))
        .expect("circle radius");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:arc-center-fixed",
            ConstraintKind::Fixed,
            vec![point_target("entity:arc", ControlPointKind::Center)],
            None,
        )))
        .expect("arc center fixed");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:arc-start-fixed",
            ConstraintKind::Fixed,
            vec![point_target("entity:arc", ControlPointKind::Start)],
            None,
        )))
        .expect("arc start fixed");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:arc-radius",
            ConstraintKind::Radius,
            vec![entity_target("entity:arc")],
            Some(ConstraintValue::FixedMm(8.0)),
        )))
        .expect("arc radius");

    assert_entity_remaining_dof(&document, "entity:point", 0);
    assert_entity_remaining_dof(&document, "entity:line", 1);
    assert_entity_remaining_dof(&document, "entity:circle", 2);
    assert_entity_remaining_dof(&document, "entity:arc", 1);
}

#[test]
fn arc_endpoint_control_points_can_be_constrained() {
    let mut document = ProjectDocument::new("Arc endpoints");
    document
        .apply_command(DocumentCommand::AddEntity(point_entity(
            "entity:anchor",
            point(20.0, 0.0),
        )))
        .expect("anchor");
    document
        .apply_command(DocumentCommand::AddEntity(arc_entity(
            "entity:arc",
            point(0.0, 0.0),
            10.0,
            0.0,
            std::f64::consts::FRAC_PI_2,
        )))
        .expect("arc");

    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:arc-start",
            ConstraintKind::Coincident,
            vec![
                entity_target("entity:anchor"),
                point_target("entity:arc", ControlPointKind::Start),
            ],
            None,
        )))
        .expect("arc start coincident");

    let arc = arc_geometry(document.entity("entity:arc").expect("arc exists"));
    assert_approx_eq(arc_start(arc).x_mm, 20.0);
    assert_approx_eq(arc_start(arc).y_mm, 0.0);
}

#[test]
fn arc_endpoint_coincident_constraints_preserve_equivalent_large_sweep_direction() {
    let mut document = ProjectDocument::new("Arc endpoint sweep continuity");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:right-line",
            point(5.0, 65.0),
            point(15.215188501565995, 19.0430377003132),
        )))
        .expect("right line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:left-line",
            point(-15.0, 65.0),
            point(-25.0, 20.0),
        )))
        .expect("left line");
    document
        .apply_command(DocumentCommand::AddEntity(arc_entity(
            "entity:arc",
            point(-5.0, 15.0),
            20.615528128088304,
            0.19739555984988075,
            -3.5839668765665382,
        )))
        .expect("arc");

    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:arc-start",
            ConstraintKind::Coincident,
            vec![
                point_target("entity:right-line", ControlPointKind::End),
                point_target("entity:arc", ControlPointKind::Start),
            ],
            None,
        )))
        .expect("arc start coincident");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:arc-end",
            ConstraintKind::Coincident,
            vec![
                point_target("entity:left-line", ControlPointKind::End),
                point_target("entity:arc", ControlPointKind::End),
            ],
            None,
        )))
        .expect("arc end coincident");

    let arc = arc_geometry(document.entity("entity:arc").expect("arc exists"));
    assert_points_close(arc_start(arc), point(15.215188501565995, 19.0430377003132));
    assert_points_close(arc_end(arc), point(-25.0, 20.0));
    assert_approx_eq(arc.sweep_angle_rad, -3.5839668765665382);
}

#[test]
fn second_arc_endpoint_coincident_after_tangent_is_selection_order_independent() {
    let mut document = ProjectDocument::new("Second Arc Endpoint Coincident");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:left-line",
            point(-25.0, 75.0),
            point(-50.00000000000001, 0.0),
        )))
        .expect("left line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:right-line",
            point(-5.0, 75.0),
            point(15.0, 0.0),
        )))
        .expect("right line");
    document
        .apply_command(DocumentCommand::AddEntity(arc_entity(
            "entity:arc",
            point(-9.195588473793663, -13.601470508735437),
            43.011626335213144,
            -3.4633432079864352,
            4.006820802699478,
        )))
        .expect("arc");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:start-coincident",
            ConstraintKind::Coincident,
            vec![
                point_target("entity:left-line", ControlPointKind::End),
                point_target("entity:arc", ControlPointKind::Start),
            ],
            None,
        )))
        .expect("start coincident");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:left-start-fixed",
            ConstraintKind::Fixed,
            vec![point_target("entity:left-line", ControlPointKind::Start)],
            None,
        )))
        .expect("left start fixed");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:right-start-fixed",
            ConstraintKind::Fixed,
            vec![point_target("entity:right-line", ControlPointKind::Start)],
            None,
        )))
        .expect("right start fixed");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:arc-start-fixed",
            ConstraintKind::Fixed,
            vec![point_target("entity:arc", ControlPointKind::Start)],
            None,
        )))
        .expect("arc start fixed");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:right-end-fixed",
            ConstraintKind::Fixed,
            vec![point_target("entity:right-line", ControlPointKind::End)],
            None,
        )))
        .expect("right end fixed");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:start-tangent",
            ConstraintKind::Tangent,
            vec![
                point_target("entity:arc", ControlPointKind::Start),
                point_target("entity:left-line", ControlPointKind::End),
            ],
            None,
        )))
        .expect("start tangent");

    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:end-coincident",
            ConstraintKind::Coincident,
            vec![
                point_target("entity:arc", ControlPointKind::End),
                point_target("entity:right-line", ControlPointKind::End),
            ],
            None,
        )))
        .expect("end coincident should be accepted regardless of target order");

    let arc = arc_by_id(&document, "entity:arc");
    assert_points_close(arc_end(arc), point(15.0, 0.0));
    assert!(document
        .constraints()
        .iter()
        .any(|constraint| constraint.id == "constraint:end-coincident"));
}

#[test]
fn tangent_connected_line_with_free_opposite_endpoint_can_stretch_along_line() {
    let mut document = ProjectDocument::new("Tangent Stretch");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:left-line",
            point(-25.0, 75.0),
            point(-50.00000000000001, 3.552713678800501e-15),
        )))
        .expect("left line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:right-line",
            point(-10.0, 75.0),
            point(14.999999999999991, 7.105427357601002e-15),
        )))
        .expect("right line");
    document
        .apply_command(DocumentCommand::AddEntity(arc_entity(
            "entity:arc",
            point(-17.500000000000014, -10.833333333333327),
            34.25800798515745,
            2.819842099193151,
            3.7850937623830774,
        )))
        .expect("arc");
    for constraint_def in [
        constraint(
            "constraint:start-coincident",
            ConstraintKind::Coincident,
            vec![
                point_target("entity:left-line", ControlPointKind::End),
                point_target("entity:arc", ControlPointKind::Start),
            ],
            None,
        ),
        constraint(
            "constraint:arc-start-fixed",
            ConstraintKind::Fixed,
            vec![point_target("entity:arc", ControlPointKind::Start)],
            None,
        ),
        constraint(
            "constraint:right-end-fixed",
            ConstraintKind::Fixed,
            vec![point_target("entity:right-line", ControlPointKind::End)],
            None,
        ),
        constraint(
            "constraint:start-tangent",
            ConstraintKind::Tangent,
            vec![
                point_target("entity:arc", ControlPointKind::Start),
                point_target("entity:left-line", ControlPointKind::End),
            ],
            None,
        ),
        constraint(
            "constraint:end-coincident",
            ConstraintKind::Coincident,
            vec![
                point_target("entity:right-line", ControlPointKind::End),
                point_target("entity:arc", ControlPointKind::End),
            ],
            None,
        ),
        constraint(
            "constraint:end-tangent",
            ConstraintKind::Tangent,
            vec![
                point_target("entity:arc", ControlPointKind::End),
                point_target("entity:right-line", ControlPointKind::End),
            ],
            None,
        ),
    ] {
        document
            .apply_command(DocumentCommand::AddConstraint(constraint_def))
            .expect("constraint should be accepted");
    }

    document
        .apply_command(DocumentCommand::UpdateEntity(line_entity(
            "entity:right-line",
            point(-15.0, 90.0),
            point(14.999999999999991, 7.105427357601002e-15),
        )))
        .expect("free line endpoint should stretch along the tangent line");

    let right_line = line_geometry(document.entity("entity:right-line").unwrap());
    assert_points_close(right_line.start, point(-15.0, 90.0));
    assert_points_close(
        right_line.end,
        point(14.999999999999991, 7.105427357601002e-15),
    );
    let arc = arc_by_id(&document, "entity:arc");
    assert_points_close(arc_end(arc), right_line.end);
    assert!(vectors_point_same_direction(
        point(
            right_line.start.x_mm - right_line.end.x_mm,
            right_line.start.y_mm - right_line.end.y_mm
        ),
        arc_tangent_direction(arc, ControlPointKind::End)
    ));

    document
        .apply_command(DocumentCommand::UpdateEntity(line_entity(
            "entity:left-line",
            point(-20.0, 90.0),
            point(-50.00000000000001, 3.552713678800501e-15),
        )))
        .expect("left free line endpoint should stretch along the tangent line");

    let left_line = line_geometry(document.entity("entity:left-line").unwrap());
    assert_points_close(left_line.start, point(-20.0, 90.0));
    assert_points_close(
        left_line.end,
        point(-50.00000000000001, 3.552713678800501e-15),
    );
    let arc = arc_by_id(&document, "entity:arc");
    assert_points_close(arc_start(arc), left_line.end);
    assert!(vectors_point_same_direction(
        point(
            left_line.end.x_mm - left_line.start.x_mm,
            left_line.end.y_mm - left_line.start.y_mm
        ),
        arc_tangent_direction(arc, ControlPointKind::Start)
    ));
}

#[test]
fn horizontal_constraint_can_be_added_after_equal_segment_length() {
    let mut document = ProjectDocument::new("Equal Length Then Horizontal");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line-a",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("line a");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line-b",
            point(20.0, 5.0),
            point(26.0, 13.0),
        )))
        .expect("line b");

    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:equal",
            ConstraintKind::EqualSegmentLength,
            vec![
                entity_target("entity:line-a"),
                entity_target("entity:line-b"),
            ],
            None,
        )))
        .expect("equal segment length");

    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:horizontal",
            ConstraintKind::Horizontal,
            vec![entity_target("entity:line-b")],
            None,
        )))
        .expect("horizontal after equal length");

    let line_a = match &document
        .entity("entity:line-a")
        .expect("line a exists")
        .kind
    {
        EntityKind::LineSegment(line) => line,
        _ => panic!("expected line segment"),
    };
    let line_b = match &document
        .entity("entity:line-b")
        .expect("line b exists")
        .kind
    {
        EntityKind::LineSegment(line) => line,
        _ => panic!("expected line segment"),
    };
    assert_approx_eq(line_a.length_mm(), line_b.length_mm());
    assert_approx_eq(line_b.start.y_mm, line_b.end.y_mm);
}

#[test]
fn horizontal_constraint_preserves_existing_segment_length() {
    let mut document = ProjectDocument::new("Segment Length Then Horizontal");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line-a",
            point(5.0, 5.0),
            point(11.0, 13.0),
        )))
        .expect("line a");

    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:length",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:line-a")],
            Some(ConstraintValue::FixedMm(10.0)),
        )))
        .expect("segment length");

    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:horizontal",
            ConstraintKind::Horizontal,
            vec![entity_target("entity:line-a")],
            None,
        )))
        .expect("horizontal after segment length");

    let line_a = match &document
        .entity("entity:line-a")
        .expect("line a exists")
        .kind
    {
        EntityKind::LineSegment(line) => line,
        _ => panic!("expected line segment"),
    };
    assert_approx_eq(line_a.length_mm(), 10.0);
    assert_approx_eq(line_a.start.y_mm, line_a.end.y_mm);
}

#[test]
fn coincident_constraint_with_horizontal_endpoint_is_selection_order_independent() {
    let mut document = ProjectDocument::new("Coincident Horizontal Endpoint");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:free",
            point(0.0, 0.0),
            point(5.0, 5.0),
        )))
        .expect("free line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:horizontal",
            point(20.0, 10.0),
            point(30.0, 10.0),
        )))
        .expect("horizontal line");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:horizontal",
            ConstraintKind::Horizontal,
            vec![entity_target("entity:horizontal")],
            None,
        )))
        .expect("horizontal constraint");

    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:coincident",
            ConstraintKind::Coincident,
            vec![
                point_target("entity:free", ControlPointKind::End),
                point_target("entity:horizontal", ControlPointKind::Start),
            ],
            None,
        )))
        .expect("coincident should not depend on selection order");

    let free = line_geometry(document.entity("entity:free").expect("free line exists"));
    let horizontal = line_geometry(
        document
            .entity("entity:horizontal")
            .expect("horizontal line exists"),
    );
    let groups = document.coincident_point_groups();
    assert_eq!(groups.len(), 1);
    assert_eq!(groups[0].targets.len(), 2);
    assert_approx_eq(free.end.x_mm, horizontal.start.x_mm);
    assert_approx_eq(free.end.y_mm, horizontal.start.y_mm);
    assert_approx_eq(horizontal.start.y_mm, horizontal.end.y_mm);
}

#[test]
fn coincident_constraint_between_dimensioned_horizontal_and_vertical_endpoints_is_valid() {
    let mut document = ProjectDocument::new("Coincident Dimensioned Orthogonal Lines");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:horizontal",
            point(30.0, 65.0),
            point(80.0, 65.0),
        )))
        .expect("horizontal line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:vertical",
            point(30.0, 85.0),
            point(30.0, 115.0),
        )))
        .expect("vertical line");

    for constraint_def in [
        constraint(
            "constraint:horizontal",
            ConstraintKind::Horizontal,
            vec![entity_target("entity:horizontal")],
            None,
        ),
        constraint(
            "constraint:horizontal-distance",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:horizontal")],
            Some(ConstraintValue::FixedMm(50.0)),
        ),
        constraint(
            "constraint:vertical",
            ConstraintKind::Vertical,
            vec![entity_target("entity:vertical")],
            None,
        ),
        constraint(
            "constraint:vertical-distance",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:vertical")],
            Some(ConstraintValue::FixedMm(30.0)),
        ),
    ] {
        document
            .apply_command(DocumentCommand::AddConstraint(constraint_def))
            .expect("line constraint should be added");
    }

    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:coincident",
            ConstraintKind::Coincident,
            vec![
                point_target("entity:horizontal", ControlPointKind::End),
                point_target("entity:vertical", ControlPointKind::Start),
            ],
            None,
        )))
        .expect("coincident should be valid for dimensioned orthogonal endpoints");

    let horizontal = line_geometry(
        document
            .entity("entity:horizontal")
            .expect("horizontal line exists"),
    );
    let vertical = line_geometry(
        document
            .entity("entity:vertical")
            .expect("vertical line exists"),
    );
    assert_approx_eq(horizontal.end.x_mm, vertical.start.x_mm);
    assert_approx_eq(horizontal.end.y_mm, vertical.start.y_mm);
    assert_approx_eq(horizontal.length_mm(), 50.0);
    assert_approx_eq(vertical.length_mm(), 30.0);
    assert_approx_eq(horizontal.start.y_mm, horizontal.end.y_mm);
    assert_approx_eq(vertical.start.x_mm, vertical.end.x_mm);
}

#[test]
fn moving_one_endpoint_in_a_coincident_group_moves_the_group() {
    let mut document = ProjectDocument::new("Move Coincident Group");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line-a",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("line a");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line-b",
            point(10.0, 0.0),
            point(20.0, 0.0),
        )))
        .expect("line b");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:coincident",
            ConstraintKind::Coincident,
            vec![
                point_target("entity:line-a", ControlPointKind::End),
                point_target("entity:line-b", ControlPointKind::Start),
            ],
            None,
        )))
        .expect("coincident");

    let mut line_a = document.entity("entity:line-a").expect("line a").clone();
    if let EntityKind::LineSegment(line) = &mut line_a.kind {
        line.end = point(12.0, 4.0);
    } else {
        panic!("expected line segment");
    }
    document
        .apply_command(DocumentCommand::UpdateEntity(line_a))
        .expect("coincident endpoint move should update the group");

    let line_a = line_geometry(document.entity("entity:line-a").expect("line a"));
    let line_b = line_geometry(document.entity("entity:line-b").expect("line b"));
    assert_approx_eq(line_a.end.x_mm, 12.0);
    assert_approx_eq(line_a.end.y_mm, 4.0);
    assert_approx_eq(line_b.start.x_mm, 12.0);
    assert_approx_eq(line_b.start.y_mm, 4.0);
}

#[test]
fn axis_constrained_line_update_projects_diagonal_endpoint_edits() {
    let mut document = ProjectDocument::new("Axis Projection");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:horizontal",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("horizontal line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:vertical",
            point(20.0, 0.0),
            point(20.0, 10.0),
        )))
        .expect("vertical line");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:horizontal",
            ConstraintKind::Horizontal,
            vec![entity_target("entity:horizontal")],
            None,
        )))
        .expect("horizontal constraint");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:vertical",
            ConstraintKind::Vertical,
            vec![entity_target("entity:vertical")],
            None,
        )))
        .expect("vertical constraint");

    document
        .apply_command(DocumentCommand::UpdateEntity(line_entity(
            "entity:horizontal",
            point(2.0, 3.0),
            point(10.0, 0.0),
        )))
        .expect("start-only diagonal edit should project to horizontal");
    let horizontal = line_geometry(document.entity("entity:horizontal").expect("horizontal"));
    assert_approx_eq(horizontal.start.x_mm, 2.0);
    assert_approx_eq(horizontal.start.y_mm, 0.0);
    assert_approx_eq(horizontal.end.x_mm, 10.0);
    assert_approx_eq(horizontal.end.y_mm, 0.0);

    document
        .apply_command(DocumentCommand::UpdateEntity(line_entity(
            "entity:horizontal",
            point(4.0, 4.0),
            point(14.0, 6.0),
        )))
        .expect("two-end diagonal edit should project to average horizontal translation");
    let horizontal = line_geometry(document.entity("entity:horizontal").expect("horizontal"));
    assert_approx_eq(horizontal.start.x_mm, 4.0);
    assert_approx_eq(horizontal.start.y_mm, 5.0);
    assert_approx_eq(horizontal.end.x_mm, 14.0);
    assert_approx_eq(horizontal.end.y_mm, 5.0);

    document
        .apply_command(DocumentCommand::UpdateEntity(line_entity(
            "entity:vertical",
            point(24.0, 4.0),
            point(26.0, 14.0),
        )))
        .expect("two-end diagonal edit should project to average vertical translation");
    let vertical = line_geometry(document.entity("entity:vertical").expect("vertical"));
    assert_approx_eq(vertical.start.x_mm, 25.0);
    assert_approx_eq(vertical.start.y_mm, 4.0);
    assert_approx_eq(vertical.end.x_mm, 25.0);
    assert_approx_eq(vertical.end.y_mm, 14.0);
}

#[test]
fn fully_constrained_line_rectangle_can_be_resized_by_driving_dimensions() {
    let mut document = constrained_line_rectangle_document();

    assert_rectangle_statuses(&document, ConstraintStatus::FullyConstrained);

    document
        .apply_command(DocumentCommand::UpdateConstraint(constraint(
            "constraint:width",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:bottom")],
            Some(ConstraintValue::FixedMm(80.0)),
        )))
        .expect("width dimension should drive the rectangle");

    let bottom = line_geometry(document.entity("entity:bottom").expect("bottom exists"));
    let top = line_geometry(document.entity("entity:top").expect("top exists"));
    let right = line_geometry(document.entity("entity:right").expect("right exists"));
    assert_approx_eq(bottom.length_mm(), 80.0);
    assert_approx_eq(top.length_mm(), 80.0);
    assert_approx_eq(right.start.x_mm, 80.0);
    assert_approx_eq(right.end.x_mm, 80.0);
    assert_rectangle_statuses(&document, ConstraintStatus::FullyConstrained);

    document
        .apply_command(DocumentCommand::UpdateConstraint(constraint(
            "constraint:height",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:left")],
            Some(ConstraintValue::FixedMm(30.0)),
        )))
        .expect("height dimension should drive the rectangle");

    let left = line_geometry(document.entity("entity:left").expect("left exists"));
    let right = line_geometry(document.entity("entity:right").expect("right exists"));
    assert_approx_eq(left.length_mm(), 30.0);
    assert_approx_eq(right.length_mm(), 30.0);
    assert_rectangle_statuses(&document, ConstraintStatus::FullyConstrained);
}

#[test]
fn filleted_line_rectangle_can_be_resized_by_driving_dimensions() {
    let mut document = constrained_line_rectangle_document();
    document
        .apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
            "derived:fillet",
            None,
            Fillet {
                source_entity_ids: vec![
                    "entity:bottom".to_owned(),
                    "entity:right".to_owned(),
                    "entity:top".to_owned(),
                    "entity:left".to_owned(),
                ],
                radius: ConstraintValue::FixedMm(2.0),
                closed: true,
            },
        )))
        .expect("rectangle fillet");

    document
        .apply_command(DocumentCommand::UpdateConstraint(constraint(
            "constraint:width",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:bottom")],
            Some(ConstraintValue::FixedMm(80.0)),
        )))
        .expect("width dimension should drive the filleted rectangle");
    document
        .apply_command(DocumentCommand::UpdateConstraint(constraint(
            "constraint:height",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:left")],
            Some(ConstraintValue::FixedMm(30.0)),
        )))
        .expect("height dimension should drive the filleted rectangle");

    let bottom = line_geometry(document.entity("entity:bottom").expect("bottom exists"));
    let left = line_geometry(document.entity("entity:left").expect("left exists"));
    assert_approx_eq(bottom.length_mm(), 80.0);
    assert_approx_eq(left.length_mm(), 30.0);

    let snapshot = document.drawing_snapshot(CanvasViewMode::EditDisplay);
    assert_eq!(
        snapshot
            .entities
            .iter()
            .filter(|entity| entity.id.starts_with("derived:fillet:resolved:"))
            .count(),
        8
    );
}

#[test]
fn dimension_parameter_resize_prunes_invalid_fillet_without_rejecting_resize() {
    let mut document = constrained_line_rectangle_document();
    document
        .apply_command(DocumentCommand::AddParameter(parameter(
            "parameter:width",
            "width",
            50.0,
        )))
        .expect("width parameter");
    document
        .apply_command(DocumentCommand::UpdateConstraint(constraint(
            "constraint:width",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:bottom")],
            Some(ConstraintValue::Parameter("parameter:width".to_owned())),
        )))
        .expect("width parameter constraint");
    document
        .apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
            "derived:fillet",
            None,
            Fillet {
                source_entity_ids: vec![
                    "entity:bottom".to_owned(),
                    "entity:right".to_owned(),
                    "entity:top".to_owned(),
                    "entity:left".to_owned(),
                ],
                radius: ConstraintValue::FixedMm(2.0),
                closed: true,
            },
        )))
        .expect("rectangle fillet");

    document
        .apply_command(DocumentCommand::SetParameterValue {
            parameter_id: "parameter:width".to_owned(),
            value_mm: 3.0,
        })
        .expect("width dimension should resize even when the fillet becomes invalid");

    let bottom = line_geometry(document.entity("entity:bottom").expect("bottom exists"));
    assert_approx_eq(bottom.length_mm(), 3.0);
    assert!(document.derived_elements().is_empty());
    assert_eq!(document.document_warnings().len(), 1);
}

#[test]
fn fillet_radius_parameter_update_still_rejects_invalid_fillet_without_pruning() {
    let mut document = constrained_line_rectangle_document();
    document
        .apply_command(DocumentCommand::AddParameter(parameter(
            "parameter:fillet-radius",
            "fillet radius",
            2.0,
        )))
        .expect("fillet radius parameter");
    document
        .apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
            "derived:fillet",
            None,
            Fillet {
                source_entity_ids: vec![
                    "entity:bottom".to_owned(),
                    "entity:right".to_owned(),
                    "entity:top".to_owned(),
                    "entity:left".to_owned(),
                ],
                radius: ConstraintValue::Parameter("parameter:fillet-radius".to_owned()),
                closed: true,
            },
        )))
        .expect("rectangle fillet");

    let result = document.apply_command(DocumentCommand::SetParameterValue {
        parameter_id: "parameter:fillet-radius".to_owned(),
        value_mm: 20.0,
    });

    assert!(
        matches!(result, Err(CommandError::InvalidValue { field, .. }) if field == "fillet radius")
    );
    assert_eq!(document.derived_elements().len(), 1);
    assert_eq!(
        document
            .parameter("parameter:fillet-radius")
            .expect("parameter")
            .value_mm,
        2.0
    );
}

#[test]
fn fully_constrained_line_rectangle_accepts_dimensions_on_opposite_sides() {
    let mut document =
        constrained_line_rectangle_document_with_dimensions("entity:top", "entity:right");

    assert_rectangle_statuses(&document, ConstraintStatus::FullyConstrained);

    document
        .apply_command(DocumentCommand::UpdateConstraint(constraint(
            "constraint:width",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:top")],
            Some(ConstraintValue::FixedMm(70.0)),
        )))
        .expect("width dimension on opposite side should drive the rectangle");

    let bottom = line_geometry(document.entity("entity:bottom").expect("bottom exists"));
    let top = line_geometry(document.entity("entity:top").expect("top exists"));
    let right = line_geometry(document.entity("entity:right").expect("right exists"));
    assert_approx_eq(bottom.length_mm(), 70.0);
    assert_approx_eq(top.length_mm(), 70.0);
    assert_approx_eq(right.start.x_mm, 70.0);
    assert_approx_eq(right.end.x_mm, 70.0);
    assert_rectangle_statuses(&document, ConstraintStatus::FullyConstrained);

    document
        .apply_command(DocumentCommand::UpdateConstraint(constraint(
            "constraint:height",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:right")],
            Some(ConstraintValue::FixedMm(35.0)),
        )))
        .expect("height dimension on opposite side should drive the rectangle");

    let left = line_geometry(document.entity("entity:left").expect("left exists"));
    let right = line_geometry(document.entity("entity:right").expect("right exists"));
    assert_approx_eq(left.length_mm(), 35.0);
    assert_approx_eq(right.length_mm(), 35.0);
    assert_rectangle_statuses(&document, ConstraintStatus::FullyConstrained);
}

#[test]
fn under_constrained_line_rectangle_can_still_resize_by_dimensions() {
    let mut document =
        constrained_line_rectangle_document_with_options("entity:bottom", "entity:left", false);

    assert_rectangle_statuses(&document, ConstraintStatus::UnderConstrained);

    document
        .apply_command(DocumentCommand::UpdateConstraint(constraint(
            "constraint:width",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:bottom")],
            Some(ConstraintValue::FixedMm(75.0)),
        )))
        .expect("width dimension should resize an unfixed rectangle");

    let bottom = line_geometry(document.entity("entity:bottom").expect("bottom exists"));
    let top = line_geometry(document.entity("entity:top").expect("top exists"));
    assert_approx_eq(bottom.length_mm(), 75.0);
    assert_approx_eq(top.length_mm(), 75.0);
    assert_rectangle_statuses(&document, ConstraintStatus::UnderConstrained);

    document
        .apply_command(DocumentCommand::UpdateConstraint(constraint(
            "constraint:height",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:left")],
            Some(ConstraintValue::FixedMm(35.0)),
        )))
        .expect("height dimension should resize an unfixed rectangle");

    let left = line_geometry(document.entity("entity:left").expect("left exists"));
    let right = line_geometry(document.entity("entity:right").expect("right exists"));
    assert_approx_eq(left.length_mm(), 35.0);
    assert_approx_eq(right.length_mm(), 35.0);
    assert_rectangle_statuses(&document, ConstraintStatus::UnderConstrained);
}

#[test]
fn under_constrained_connected_outline_moves_entity_with_coincident_neighbors() {
    // D8-08: 拘束不足な5線分輪郭の線分移動は、隣接要素へ伝播する。
    let mut document = under_constrained_five_segment_outline_document();

    document
        .apply_command(DocumentCommand::UpdateEntity(line_entity(
            "entity:bottom",
            point(30.0, 75.0),
            point(120.0, 75.0),
        )))
        .expect("under constrained connected outline should allow bottom translation");

    let bottom = line_geometry(document.entity("entity:bottom").expect("bottom exists"));
    let left = line_geometry(document.entity("entity:left").expect("left exists"));
    let right = line_geometry(document.entity("entity:right").expect("right exists"));

    assert_approx_eq(bottom.start.y_mm, 75.0);
    assert_approx_eq(bottom.end.y_mm, 75.0);
    assert_approx_eq(left.start.y_mm, 75.0);
    assert_approx_eq(right.end.y_mm, 75.0);
    assert_outline_constraints_satisfied(&document);
}

#[test]
fn under_constrained_connected_outline_accepts_driving_length_dimension() {
    // D8-09: 拘束不足な5線分輪郭の駆動寸法追加は、連結成分全体へ伝播する。
    let mut document = under_constrained_five_segment_outline_document();

    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:left-length",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:left")],
            Some(ConstraintValue::FixedMm(80.0)),
        )))
        .expect("under constrained connected outline should accept a driving length");

    let left = line_geometry(document.entity("entity:left").expect("left exists"));
    let top = line_geometry(document.entity("entity:top").expect("top exists"));

    assert_approx_eq(left.length_mm(), 80.0);
    assert_approx_eq(left.end.y_mm, 145.0);
    assert_approx_eq(top.start.y_mm, 145.0);
    assert_approx_eq(top.end.y_mm, 145.0);
    assert_outline_constraints_satisfied(&document);
}

#[test]
fn updating_shared_endpoint_angle_constraint_repositions_the_second_line() {
    let mut document = ProjectDocument::new("Shared Endpoint Angle Update");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:first",
            point(10.0, 0.0),
            point(0.0, 0.0),
        )))
        .expect("first line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:second",
            point(0.0, 0.0),
            point(5.0, 0.0),
        )))
        .expect("second line");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:angle",
            ConstraintKind::Angle,
            vec![
                entity_target("entity:first"),
                entity_target("entity:second"),
            ],
            Some(ConstraintValue::FixedDegrees(0.0)),
        )))
        .expect("angle constraint should be added");

    document
        .apply_command(DocumentCommand::UpdateConstraint(constraint(
            "constraint:angle",
            ConstraintKind::Angle,
            vec![
                entity_target("entity:first"),
                entity_target("entity:second"),
            ],
            Some(ConstraintValue::FixedDegrees(60.0)),
        )))
        .expect("angle value should update without conflicting");

    let first = line_geometry(document.entity("entity:first").expect("first exists"));
    let second = line_geometry(document.entity("entity:second").expect("second exists"));
    assert_approx_eq(second.start.x_mm, 0.0);
    assert_approx_eq(second.start.y_mm, 0.0);

    let first_direction = point(
        first.start.x_mm - first.end.x_mm,
        first.start.y_mm - first.end.y_mm,
    );
    let second_direction = point(
        second.end.x_mm - second.start.x_mm,
        second.end.y_mm - second.start.y_mm,
    );
    let updated_angle_deg = normalize_degrees(
        (second_direction.y_mm.atan2(second_direction.x_mm)
            - first_direction.y_mm.atan2(first_direction.x_mm))
        .to_degrees(),
    );
    assert!(
        (updated_angle_deg - 60.0).abs() < 0.001,
        "expected angle to update to 60 degrees, got {updated_angle_deg}"
    );
}

#[test]
fn updating_angle_constraint_keeps_reversed_second_line_shared_endpoint_fixed() {
    let mut document = ProjectDocument::new("Reversed Second Angle Update");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:first",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("first line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:second",
            point(0.0, 5.0),
            point(0.0, 0.0),
        )))
        .expect("second line");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:shared-fixed",
            ConstraintKind::Fixed,
            vec![point_target("entity:second", ControlPointKind::End)],
            None,
        )))
        .expect("shared endpoint should be fixed");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:angle",
            ConstraintKind::Angle,
            vec![
                entity_target("entity:first"),
                entity_target("entity:second"),
            ],
            Some(ConstraintValue::FixedDegrees(90.0)),
        )))
        .expect("angle constraint should be added");

    document
        .apply_command(DocumentCommand::UpdateConstraint(constraint(
            "constraint:angle",
            ConstraintKind::Angle,
            vec![
                entity_target("entity:first"),
                entity_target("entity:second"),
            ],
            Some(ConstraintValue::FixedDegrees(45.0)),
        )))
        .expect("angle update should keep the shared endpoint fixed");

    let first = line_geometry(document.entity("entity:first").expect("first exists"));
    let second = line_geometry(document.entity("entity:second").expect("second exists"));
    assert_approx_eq(first.start.x_mm, 0.0);
    assert_approx_eq(first.start.y_mm, 0.0);
    assert_approx_eq(second.end.x_mm, 0.0);
    assert_approx_eq(second.end.y_mm, 0.0);

    let first_direction = point(
        first.end.x_mm - first.start.x_mm,
        first.end.y_mm - first.start.y_mm,
    );
    let second_direction = point(
        second.start.x_mm - second.end.x_mm,
        second.start.y_mm - second.end.y_mm,
    );
    let updated_angle_deg = normalize_degrees(
        (second_direction.y_mm.atan2(second_direction.x_mm)
            - first_direction.y_mm.atan2(first_direction.x_mm))
        .to_degrees(),
    );
    assert!(
        (updated_angle_deg - 45.0).abs() < 0.001,
        "expected angle to update to 45 degrees, got {updated_angle_deg}"
    );
}

#[test]
fn angle_constraint_requires_lines_to_share_an_endpoint() {
    let mut document = ProjectDocument::new("Disconnected Angle");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:first",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("first line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:second",
            point(20.0, 0.0),
            point(20.0, 10.0),
        )))
        .expect("second line");

    let error = document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:angle",
            ConstraintKind::Angle,
            vec![
                entity_target("entity:first"),
                entity_target("entity:second"),
            ],
            Some(ConstraintValue::FixedDegrees(90.0)),
        )))
        .expect_err("disconnected line angle constraints should be rejected");

    match error {
        CommandError::Constraint(error) => {
            assert_eq!(error.code, ConstraintCommandErrorCode::InvalidTarget);
        }
        other => panic!("expected constraint invalid target error, got {other:?}"),
    }
}

#[test]
fn angle_constraint_uses_shared_endpoint_as_both_line_starts() {
    let mut document = ProjectDocument::new("Shared Endpoint Angle");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:first",
            point(10.0, 0.0),
            point(0.0, 0.0),
        )))
        .expect("first line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:second",
            point(0.0, 0.0),
            point(0.0, 5.0),
        )))
        .expect("second line");

    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:angle",
            ConstraintKind::Angle,
            vec![
                entity_target("entity:first"),
                entity_target("entity:second"),
            ],
            Some(ConstraintValue::FixedDegrees(90.0)),
        )))
        .expect("shared endpoint angle should use the shared point as origin");

    let constraint = document
        .constraints()
        .iter()
        .find(|constraint| constraint.id == "constraint:angle")
        .expect("angle constraint exists");
    assert_eq!(constraint.status, ConstraintStatus::UnderConstrained);
}

#[test]
fn angle_constraint_shared_endpoint_direction_supports_all_endpoint_pairs() {
    for (name, first_start, first_end, second_start, second_end) in [
        (
            "start-start",
            point(0.0, 0.0),
            point(10.0, 0.0),
            point(0.0, 0.0),
            point(0.0, 10.0),
        ),
        (
            "start-end",
            point(0.0, 0.0),
            point(10.0, 0.0),
            point(0.0, 10.0),
            point(0.0, 0.0),
        ),
        (
            "end-start",
            point(10.0, 0.0),
            point(0.0, 0.0),
            point(0.0, 0.0),
            point(0.0, 10.0),
        ),
        (
            "end-end",
            point(10.0, 0.0),
            point(0.0, 0.0),
            point(0.0, 10.0),
            point(0.0, 0.0),
        ),
    ] {
        let mut document = ProjectDocument::new(name);
        document
            .apply_command(DocumentCommand::AddEntity(line_entity(
                "entity:first",
                first_start,
                first_end,
            )))
            .expect("first line");
        document
            .apply_command(DocumentCommand::AddEntity(line_entity(
                "entity:second",
                second_start,
                second_end,
            )))
            .expect("second line");

        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                "constraint:angle",
                ConstraintKind::Angle,
                vec![
                    entity_target("entity:first"),
                    entity_target("entity:second"),
                ],
                Some(ConstraintValue::FixedDegrees(90.0)),
            )))
            .unwrap_or_else(|error| {
                panic!("{name} should accept shared endpoint angle: {error:?}")
            });

        let constraint = document
            .constraints()
            .iter()
            .find(|constraint| constraint.id == "constraint:angle")
            .expect("angle constraint exists");
        assert_eq!(
            constraint.status,
            ConstraintStatus::UnderConstrained,
            "{name} should be satisfied"
        );
    }
}

#[test]
fn document_delete_parameter_replaces_parameter_based_constraints() {
    let mut document = ProjectDocument::new("Delete Parameter");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line-a",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("line should be added");
    document
        .apply_command(DocumentCommand::AddParameter(parameter(
            "parameter:length",
            "length",
            24.0,
        )))
        .expect("parameter should be added");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:length",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:line-a")],
            Some(ConstraintValue::Parameter("parameter:length".to_owned())),
        )))
        .expect("segment length constraint should be added");
    assert_line_length(document.entity("entity:line-a").expect("line exists"), 24.0);

    document
        .apply_command(DocumentCommand::DeleteParameter {
            parameter_id: "parameter:length".to_owned(),
            replacement_value_mm: 40.0,
        })
        .expect("parameter should delete with replacement");
    assert_line_length(document.entity("entity:line-a").expect("line exists"), 40.0);
    assert!(matches!(
        document.constraints()[0].value,
        Some(ConstraintValue::FixedMm(40.0))
    ));
}

#[test]
fn document_delete_parameter_rejects_invalid_replacement_without_mutation() {
    let mut document = ProjectDocument::new("Delete Parameter Rollback");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line-a",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("line should be added");
    document
        .apply_command(DocumentCommand::AddParameter(parameter(
            "parameter:length",
            "length",
            10.0,
        )))
        .expect("parameter should be added");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:parameter-length",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:line-a")],
            Some(ConstraintValue::Parameter("parameter:length".to_owned())),
        )))
        .expect("parameter segment length constraint should be added");

    let before = document.clone();
    let result = document.apply_command(DocumentCommand::DeleteParameter {
        parameter_id: "parameter:length".to_owned(),
        replacement_value_mm: -1.0,
    });

    assert!(matches!(
        result,
        Err(CommandError::InvalidValue {
            field: "replacement value",
            ..
        })
    ));
    assert_eq!(document, before);
}

#[test]
fn point_line_distance_preserves_side_for_negative_and_diagonal_lines() {
    let mut negative_side = ProjectDocument::new("PointLineDistance Negative Side");
    negative_side
        .apply_command(DocumentCommand::AddEntity(point_entity(
            "entity:point",
            point(3.0, -4.0),
        )))
        .expect("point");
    negative_side
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("line");
    negative_side
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:point-line-distance",
            ConstraintKind::PointLineDistance,
            vec![entity_target("entity:point"), entity_target("entity:line")],
            Some(ConstraintValue::FixedMm(6.0)),
        )))
        .expect("point-line distance");
    let moved = negative_side.entity("entity:point").unwrap();
    assert_approx_eq(point_x(moved), 3.0);
    assert_approx_eq(point_y(moved), -6.0);

    let mut diagonal = ProjectDocument::new("PointLineDistance Diagonal");
    diagonal
        .apply_command(DocumentCommand::AddEntity(point_entity(
            "entity:point",
            point(4.0, 2.0),
        )))
        .expect("point");
    diagonal
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line",
            point(0.0, 0.0),
            point(10.0, 10.0),
        )))
        .expect("line");
    diagonal
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:point-line-distance",
            ConstraintKind::PointLineDistance,
            vec![entity_target("entity:point"), entity_target("entity:line")],
            Some(ConstraintValue::FixedMm(2.0_f64.sqrt())),
        )))
        .expect("point-line distance");
    let moved = diagonal.entity("entity:point").unwrap();
    assert_approx_eq(point_x(moved), 4.0);
    assert_approx_eq(point_y(moved), 2.0);
}

#[test]
fn line_line_distance_preserves_negative_side_and_target_length() {
    let mut document = ProjectDocument::new("LineLineDistance Negative Side");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:reference",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("reference line");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:target",
            point(2.0, -3.0),
            point(5.0, -7.0),
        )))
        .expect("target line");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:line-line-distance",
            ConstraintKind::LineLineDistance,
            vec![
                entity_target("entity:reference"),
                entity_target("entity:target"),
            ],
            Some(ConstraintValue::FixedMm(8.0)),
        )))
        .expect("line-line distance");

    assert_line(
        document.entity("entity:target").unwrap(),
        point(2.0, -8.0),
        point(7.0, -8.0),
    );
}

#[test]
fn document_constraint_semantics_accept_the_publicly_supported_target_shapes() {
    {
        let mut document = ProjectDocument::new("Horizontal");
        document
            .apply_command(DocumentCommand::AddEntity(line_entity(
                "entity:line-a",
                point(0.0, 0.0),
                point(8.0, 1.0),
            )))
            .expect("line a");
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                "constraint:horizontal",
                ConstraintKind::Horizontal,
                vec![entity_target("entity:line-a")],
                None,
            )))
            .expect("horizontal line");
        if let EntityKind::LineSegment(line) = &document.entity("entity:line-a").unwrap().kind {
            assert_approx_eq(line.start.y_mm, line.end.y_mm);
        } else {
            panic!("expected a line");
        }
    }

    {
        let mut document = ProjectDocument::new("Vertical");
        document
            .apply_command(DocumentCommand::AddEntity(point_entity(
                "entity:point-a",
                point(0.0, 0.0),
            )))
            .expect("point a");
        document
            .apply_command(DocumentCommand::AddEntity(point_entity(
                "entity:point-b",
                point(5.0, 2.0),
            )))
            .expect("point b");
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                "constraint:vertical",
                ConstraintKind::Vertical,
                vec![
                    entity_target("entity:point-a"),
                    entity_target("entity:point-b"),
                ],
                None,
            )))
            .expect("vertical points");
        assert_eq!(
            point_x(document.entity("entity:point-a").unwrap()),
            point_x(document.entity("entity:point-b").unwrap())
        );
    }

    {
        let mut document = ProjectDocument::new("Coincident");
        document
            .apply_command(DocumentCommand::AddEntity(point_entity(
                "entity:point-a",
                point(0.0, 0.0),
            )))
            .expect("point a");
        document
            .apply_command(DocumentCommand::AddEntity(point_entity(
                "entity:point-b",
                point(5.0, 2.0),
            )))
            .expect("point b");
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                "constraint:coincident",
                ConstraintKind::Coincident,
                vec![
                    entity_target("entity:point-a"),
                    entity_target("entity:point-b"),
                ],
                None,
            )))
            .expect("coincident points");
        assert_eq!(
            document.entity("entity:point-a").unwrap().kind,
            document.entity("entity:point-b").unwrap().kind
        );
    }

    {
        let mut document = ProjectDocument::new("Parallel");
        document
            .apply_command(DocumentCommand::AddEntity(line_entity(
                "entity:line-a",
                point(0.0, 0.0),
                point(8.0, 1.0),
            )))
            .expect("line a");
        document
            .apply_command(DocumentCommand::AddEntity(line_entity(
                "entity:line-b",
                point(0.0, 0.0),
                point(2.0, 6.0),
            )))
            .expect("line b");
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                "constraint:parallel",
                ConstraintKind::Parallel,
                vec![
                    entity_target("entity:line-a"),
                    entity_target("entity:line-b"),
                ],
                None,
            )))
            .expect("parallel lines");
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                "constraint:perpendicular",
                ConstraintKind::Perpendicular,
                vec![
                    entity_target("entity:line-a"),
                    entity_target("entity:line-b"),
                ],
                None,
            )))
            .expect_err("perpendicular should conflict after parallel");
    }

    {
        let mut document = ProjectDocument::new("Angle");
        document
            .apply_command(DocumentCommand::AddEntity(line_entity(
                "entity:line-a",
                point(0.0, 0.0),
                point(8.0, 1.0),
            )))
            .expect("line a");
        document
            .apply_command(DocumentCommand::AddEntity(line_entity(
                "entity:line-b",
                point(0.0, 0.0),
                point(2.0, 6.0),
            )))
            .expect("line b");
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                "constraint:angle",
                ConstraintKind::Angle,
                vec![
                    entity_target("entity:line-a"),
                    entity_target("entity:line-b"),
                ],
                Some(ConstraintValue::FixedDegrees(90.0)),
            )))
            .expect("angle lines");
    }

    {
        let mut document = ProjectDocument::new("Diameter");
        document
            .apply_command(DocumentCommand::AddEntity(circle_entity(
                "entity:circle-a",
                point(3.0, 3.0),
                4.0,
            )))
            .expect("circle");
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                "constraint:diameter",
                ConstraintKind::Diameter,
                vec![entity_target("entity:circle-a")],
                Some(ConstraintValue::FixedMm(10.0)),
            )))
            .expect("diameter circle");
    }

    {
        let mut document = ProjectDocument::new("Radius");
        document
            .apply_command(DocumentCommand::AddEntity(arc_entity(
                "entity:arc-a",
                point(8.0, 8.0),
                3.0,
                0.0,
                std::f64::consts::FRAC_PI_2,
            )))
            .expect("arc");
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                "constraint:radius",
                ConstraintKind::Radius,
                vec![entity_target("entity:arc-a")],
                Some(ConstraintValue::FixedMm(10.0)),
            )))
            .expect("radius arc");
        if let EntityKind::Arc(arc) = &document.entity("entity:arc-a").unwrap().kind {
            assert_approx_eq(arc.radius_mm, 10.0);
        } else {
            panic!("expected an arc");
        }
    }

    {
        let mut document = ProjectDocument::new("Arc angle");
        document
            .apply_command(DocumentCommand::AddEntity(arc_entity(
                "entity:arc-angle",
                point(0.0, 0.0),
                10.0,
                0.0,
                std::f64::consts::FRAC_PI_4,
            )))
            .expect("arc");
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                "constraint:arc-angle",
                ConstraintKind::Angle,
                vec![entity_target("entity:arc-angle")],
                Some(ConstraintValue::FixedDegrees(90.0)),
            )))
            .expect("arc angle");
        if let EntityKind::Arc(arc) = &document.entity("entity:arc-angle").unwrap().kind {
            assert_approx_eq(arc.sweep_angle_rad, std::f64::consts::FRAC_PI_2);
        } else {
            panic!("expected an arc");
        }
    }

    {
        let mut document = ProjectDocument::new("Fixed");
        document
            .apply_command(DocumentCommand::AddEntity(point_entity(
                "entity:point-a",
                point(0.0, 0.0),
            )))
            .expect("point a");
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                "constraint:fixed",
                ConstraintKind::Fixed,
                vec![entity_target("entity:point-a")],
                None,
            )))
            .expect("fixed point");
    }

    {
        let mut document = ProjectDocument::new("Equal");
        document
            .apply_command(DocumentCommand::AddEntity(line_entity(
                "entity:line-a",
                point(0.0, 0.0),
                point(8.0, 1.0),
            )))
            .expect("line a");
        document
            .apply_command(DocumentCommand::AddEntity(line_entity(
                "entity:line-b",
                point(0.0, 0.0),
                point(2.0, 6.0),
            )))
            .expect("line b");
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                "constraint:equal",
                ConstraintKind::EqualSegmentLength,
                vec![
                    entity_target("entity:line-a"),
                    entity_target("entity:line-b"),
                ],
                None,
            )))
            .expect("equal segment length");
    }

    {
        let mut document = ProjectDocument::new("DistancePoints");
        document
            .apply_command(DocumentCommand::AddEntity(point_entity(
                "entity:point-a",
                point(0.0, 0.0),
            )))
            .expect("point a");
        document
            .apply_command(DocumentCommand::AddEntity(point_entity(
                "entity:point-b",
                point(5.0, 0.0),
            )))
            .expect("point b");
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                "constraint:distance",
                ConstraintKind::Distance,
                vec![
                    entity_target("entity:point-a"),
                    entity_target("entity:point-b"),
                ],
                Some(ConstraintValue::FixedMm(4.0)),
            )))
            .expect("distance");
        assert_approx_eq(point_x(document.entity("entity:point-b").unwrap()), 4.0);
    }

    {
        let mut document = ProjectDocument::new("SegmentLength");
        document
            .apply_command(DocumentCommand::AddEntity(line_entity(
                "entity:line",
                point(0.0, 0.0),
                point(3.0, 4.0),
            )))
            .expect("line");
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                "constraint:distance-line",
                ConstraintKind::SegmentLength,
                vec![entity_target("entity:line")],
                Some(ConstraintValue::FixedMm(10.0)),
            )))
            .expect("line distance");
        assert_line_length(document.entity("entity:line").unwrap(), 10.0);
    }

    {
        let mut document = ProjectDocument::new("PointLineDistance");
        document
            .apply_command(DocumentCommand::AddEntity(point_entity(
                "entity:point",
                point(3.0, 4.0),
            )))
            .expect("point");
        document
            .apply_command(DocumentCommand::AddEntity(line_entity(
                "entity:line",
                point(0.0, 0.0),
                point(10.0, 0.0),
            )))
            .expect("line");
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                "constraint:point-line-distance",
                ConstraintKind::PointLineDistance,
                vec![entity_target("entity:point"), entity_target("entity:line")],
                Some(ConstraintValue::FixedMm(6.0)),
            )))
            .expect("point-line distance");
        let moved = document.entity("entity:point").unwrap();
        assert_approx_eq(point_x(moved), 3.0);
        assert_approx_eq(point_y(moved), 6.0);
    }

    {
        let mut document = ProjectDocument::new("LineLineDistance");
        document
            .apply_command(DocumentCommand::AddEntity(line_entity(
                "entity:reference",
                point(0.0, 0.0),
                point(10.0, 0.0),
            )))
            .expect("reference line");
        document
            .apply_command(DocumentCommand::AddEntity(line_entity(
                "entity:target",
                point(2.0, 3.0),
                point(6.0, 9.0),
            )))
            .expect("target line");
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                "constraint:line-line-distance",
                ConstraintKind::LineLineDistance,
                vec![
                    entity_target("entity:reference"),
                    entity_target("entity:target"),
                ],
                Some(ConstraintValue::FixedMm(8.0)),
            )))
            .expect("line-line distance");

        assert_line(
            document.entity("entity:target").unwrap(),
            point(2.0, 8.0),
            point(9.21110255092798, 8.0),
        );
    }

    {
        let mut document = ProjectDocument::new("LineLineDistanceParameter");
        document
            .apply_command(DocumentCommand::AddParameter(parameter(
                "parameter:fold-offset",
                "fold_offset",
                12.0,
            )))
            .expect("parameter");
        document
            .apply_command(DocumentCommand::AddEntity(center_line_entity(
                "entity:reference",
                point(0.0, 0.0),
                point(0.0, 10.0),
            )))
            .expect("reference center line");
        document
            .apply_command(DocumentCommand::AddEntity(center_line_entity(
                "entity:fold",
                point(4.0, 2.0),
                point(9.0, 6.0),
            )))
            .expect("fold center line");
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                "constraint:fold-offset",
                ConstraintKind::LineLineDistance,
                vec![
                    entity_target("entity:reference"),
                    entity_target("entity:fold"),
                ],
                Some(ConstraintValue::Parameter(
                    "parameter:fold-offset".to_owned(),
                )),
            )))
            .expect("line-line distance parameter");

        assert_line(
            document.entity("entity:fold").unwrap(),
            point(12.0, 2.0),
            point(12.0, 8.403124237432849),
        );

        document
            .apply_command(DocumentCommand::UpdateParameter(parameter(
                "parameter:fold-offset",
                "fold_offset",
                16.0,
            )))
            .expect("update parameter");

        assert_line(
            document.entity("entity:fold").unwrap(),
            point(16.0, 2.0),
            point(16.0, 8.403124237432849),
        );
    }

    {
        let mut document = ProjectDocument::new("LineLineDistanceAfterParallel");
        document
            .apply_command(DocumentCommand::AddEntity(line_entity(
                "entity:reference",
                point(0.0, 0.0),
                point(10.0, 0.0),
            )))
            .expect("reference line");
        document
            .apply_command(DocumentCommand::AddEntity(line_entity(
                "entity:target",
                point(0.0, 6.0),
                point(10.0, 6.0),
            )))
            .expect("target line");
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                "constraint:parallel",
                ConstraintKind::Parallel,
                vec![
                    entity_target("entity:reference"),
                    entity_target("entity:target"),
                ],
                None,
            )))
            .expect("parallel");
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                "constraint:line-line-distance",
                ConstraintKind::LineLineDistance,
                vec![
                    entity_target("entity:reference"),
                    entity_target("entity:target"),
                ],
                Some(ConstraintValue::FixedMm(6.0)),
            )))
            .expect("line-line distance");

        let distance_constraint = document
            .constraints()
            .iter()
            .find(|constraint| constraint.id == "constraint:line-line-distance")
            .expect("line-line distance exists");
        assert_ne!(
            distance_constraint.status,
            ConstraintStatus::OverConstrained
        );
    }

    {
        let mut document = ProjectDocument::new("PointOnLine");
        document
            .apply_command(DocumentCommand::AddEntity(point_entity(
                "entity:point",
                point(3.0, 4.0),
            )))
            .expect("point");
        document
            .apply_command(DocumentCommand::AddEntity(center_line_entity(
                "entity:center-line",
                point(0.0, 0.0),
                point(10.0, 0.0),
            )))
            .expect("center line");
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                "constraint:point-on-line",
                ConstraintKind::PointOnLine,
                vec![
                    entity_target("entity:point"),
                    entity_target("entity:center-line"),
                ],
                None,
            )))
            .expect("point-on-line");
        let moved = document.entity("entity:point").unwrap();
        assert_approx_eq(point_x(moved), 3.0);
        assert_approx_eq(point_y(moved), 0.0);
    }

    {
        let mut document = ProjectDocument::new("Symmetric");
        document
            .apply_command(DocumentCommand::AddEntity(point_entity(
                "entity:point-a",
                point(2.0, 3.0),
            )))
            .expect("point a");
        document
            .apply_command(DocumentCommand::AddEntity(point_entity(
                "entity:point-b",
                point(5.0, 6.0),
            )))
            .expect("point b");
        document
            .apply_command(DocumentCommand::AddEntity(center_line_entity(
                "entity:axis",
                point(0.0, -10.0),
                point(0.0, 10.0),
            )))
            .expect("axis");
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                "constraint:symmetric",
                ConstraintKind::Symmetric,
                vec![
                    entity_target("entity:point-a"),
                    entity_target("entity:point-b"),
                    entity_target("entity:axis"),
                ],
                None,
            )))
            .expect("symmetric");
        assert_approx_eq(point_x(document.entity("entity:point-b").unwrap()), -2.0);
        assert_approx_eq(point_y(document.entity("entity:point-b").unwrap()), 3.0);
    }

    {
        let mut document = ProjectDocument::new("Symmetric with normal line axis");
        document
            .apply_command(DocumentCommand::AddEntity(point_entity(
                "entity:point-a",
                point(2.0, 3.0),
            )))
            .expect("point a");
        document
            .apply_command(DocumentCommand::AddEntity(point_entity(
                "entity:point-b",
                point(5.0, 6.0),
            )))
            .expect("point b");
        document
            .apply_command(DocumentCommand::AddEntity(line_entity(
                "entity:axis",
                point(0.0, -10.0),
                point(0.0, 10.0),
            )))
            .expect("axis");
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                "constraint:symmetric",
                ConstraintKind::Symmetric,
                vec![
                    entity_target("entity:point-a"),
                    entity_target("entity:point-b"),
                    entity_target("entity:axis"),
                ],
                None,
            )))
            .expect("symmetric");
        assert_approx_eq(point_x(document.entity("entity:point-b").unwrap()), -2.0);
        assert_approx_eq(point_y(document.entity("entity:point-b").unwrap()), 3.0);
    }

    {
        let mut document = ProjectDocument::new("Segment");
        document
            .apply_command(DocumentCommand::AddEntity(line_entity(
                "entity:line-a",
                point(0.0, 0.0),
                point(8.0, 1.0),
            )))
            .expect("line a");
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                "constraint:segment-length",
                ConstraintKind::SegmentLength,
                vec![entity_target("entity:line-a")],
                Some(ConstraintValue::FixedMm(12.0)),
            )))
            .expect("segment length");
    }

    {
        let mut document = ProjectDocument::new("Control Point Center");
        document
            .apply_command(DocumentCommand::AddEntity(circle_entity(
                "entity:circle-a",
                point(1.0, 1.0),
                4.0,
            )))
            .expect("circle");
        document
            .apply_command(DocumentCommand::AddEntity(arc_entity(
                "entity:arc-a",
                point(8.0, 8.0),
                3.0,
                0.0,
                std::f64::consts::FRAC_PI_2,
            )))
            .expect("arc");
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                "constraint:circle-center",
                ConstraintKind::Fixed,
                vec![point_target("entity:circle-a", ControlPointKind::Center)],
                None,
            )))
            .expect("circle center");
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                "constraint:center-distance",
                ConstraintKind::Coincident,
                vec![
                    point_target("entity:circle-a", ControlPointKind::Center),
                    point_target("entity:arc-a", ControlPointKind::Center),
                ],
                None,
            )))
            .expect("center coincident");
        if let EntityKind::Circle(circle) = &document.entity("entity:circle-a").unwrap().kind {
            assert_approx_eq(circle.center.x_mm, 1.0);
            assert_approx_eq(circle.center.y_mm, 1.0);
        } else {
            panic!("expected a circle");
        }
    }
}

#[test]
fn document_rejects_invalid_constraint_target_shapes() {
    let mut document = ProjectDocument::new("Invalid Constraint Shapes");
    document
        .apply_command(DocumentCommand::AddEntity(point_entity(
            "entity:point-a",
            point(0.0, 0.0),
        )))
        .expect("point a");
    document
        .apply_command(DocumentCommand::AddEntity(point_entity(
            "entity:point-b",
            point(4.0, 1.0),
        )))
        .expect("point b");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line-a",
            point(0.0, 0.0),
            point(6.0, 0.0),
        )))
        .expect("line a");
    document
        .apply_command(DocumentCommand::AddEntity(circle_entity(
            "entity:circle-a",
            point(3.0, 3.0),
            2.0,
        )))
        .expect("circle a");
    document
        .apply_command(DocumentCommand::AddEntity(center_line_entity(
            "entity:axis",
            point(0.0, -5.0),
            point(0.0, 5.0),
        )))
        .expect("axis");

    for (id, kind, targets, value) in [
        (
            "constraint:horizontal",
            ConstraintKind::Horizontal,
            vec![entity_target("entity:circle-a")],
            None,
        ),
        (
            "constraint:horizontal-mixed-targets",
            ConstraintKind::Horizontal,
            vec![
                entity_target("entity:point-a"),
                entity_target("entity:line-a"),
            ],
            None,
        ),
        (
            "constraint:vertical-mixed-targets",
            ConstraintKind::Vertical,
            vec![
                entity_target("entity:line-a"),
                entity_target("entity:point-a"),
            ],
            None,
        ),
        (
            "constraint:fixed",
            ConstraintKind::Fixed,
            vec![entity_target("entity:line-a")],
            None,
        ),
        (
            "constraint:segment",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:point-a")],
            Some(ConstraintValue::FixedMm(6.0)),
        ),
        (
            "constraint:diameter",
            ConstraintKind::Diameter,
            vec![entity_target("entity:line-a")],
            Some(ConstraintValue::FixedMm(4.0)),
        ),
        (
            "constraint:diameter-control-point",
            ConstraintKind::Diameter,
            vec![point_target("entity:circle-a", ControlPointKind::Center)],
            Some(ConstraintValue::FixedMm(4.0)),
        ),
        (
            "constraint:radius",
            ConstraintKind::Radius,
            vec![entity_target("entity:line-a")],
            Some(ConstraintValue::FixedMm(4.0)),
        ),
        (
            "constraint:radius-control-point",
            ConstraintKind::Radius,
            vec![point_target("entity:circle-a", ControlPointKind::Center)],
            Some(ConstraintValue::FixedMm(4.0)),
        ),
        (
            "constraint:equal",
            ConstraintKind::EqualSegmentLength,
            vec![
                entity_target("entity:point-a"),
                entity_target("entity:line-a"),
            ],
            None,
        ),
        (
            "constraint:equal-reversed",
            ConstraintKind::EqualSegmentLength,
            vec![
                entity_target("entity:line-a"),
                entity_target("entity:point-a"),
            ],
            None,
        ),
        (
            "constraint:parallel-mixed-targets",
            ConstraintKind::Parallel,
            vec![
                entity_target("entity:line-a"),
                entity_target("entity:point-a"),
            ],
            None,
        ),
        (
            "constraint:perpendicular-mixed-targets",
            ConstraintKind::Perpendicular,
            vec![
                entity_target("entity:point-a"),
                entity_target("entity:line-a"),
            ],
            None,
        ),
        (
            "constraint:angle-mixed-targets",
            ConstraintKind::Angle,
            vec![
                entity_target("entity:line-a"),
                entity_target("entity:point-a"),
            ],
            Some(ConstraintValue::FixedDegrees(90.0)),
        ),
        (
            "constraint:distance-line-target",
            ConstraintKind::Distance,
            vec![entity_target("entity:line-a")],
            Some(ConstraintValue::FixedMm(6.0)),
        ),
        (
            "constraint:point-line-distance-two-points",
            ConstraintKind::PointLineDistance,
            vec![
                entity_target("entity:point-a"),
                entity_target("entity:point-b"),
            ],
            Some(ConstraintValue::FixedMm(6.0)),
        ),
        (
            "constraint:line-line-distance-point-target",
            ConstraintKind::LineLineDistance,
            vec![
                entity_target("entity:line-a"),
                entity_target("entity:point-a"),
            ],
            Some(ConstraintValue::FixedMm(6.0)),
        ),
        (
            "constraint:point-on-line-two-lines",
            ConstraintKind::PointOnLine,
            vec![entity_target("entity:line-a"), entity_target("entity:axis")],
            None,
        ),
        (
            "constraint:coincident",
            ConstraintKind::Coincident,
            vec![
                entity_target("entity:line-a"),
                entity_target("entity:line-a"),
            ],
            None,
        ),
        (
            "constraint:coincident-mixed-targets",
            ConstraintKind::Coincident,
            vec![
                entity_target("entity:point-a"),
                entity_target("entity:line-a"),
            ],
            None,
        ),
        (
            "constraint:symmetric",
            ConstraintKind::Symmetric,
            vec![
                entity_target("entity:point-a"),
                entity_target("entity:point-b"),
                entity_target("entity:circle-a"),
            ],
            None,
        ),
    ] {
        assert!(matches!(
            document.apply_command(DocumentCommand::AddConstraint(constraint(
                id, kind, targets, value,
            ))),
            Err(CommandError::Constraint(error))
                if matches!(
                    error.code,
                    ConstraintCommandErrorCode::InvalidTarget
                        | ConstraintCommandErrorCode::InsufficientTargets
                )
        ));
    }

    assert!(matches!(
        document.apply_command(DocumentCommand::RenameLayer {
            layer_id: "layer:circle-a".to_owned(),
            name: " ".to_owned(),
        }),
        Err(kawacad_core::command::CommandError::InvalidValue {
            field: "layer name",
            ..
        })
    ));
    assert!(matches!(
        document.apply_command(DocumentCommand::DeleteLayer("layer:missing".to_owned())),
        Err(kawacad_core::command::CommandError::MissingId { kind: "layer", .. })
    ));
    assert!(matches!(
        ProjectDocument::new("Single Layer")
            .apply_command(DocumentCommand::DeleteLayer("layer:cut-line".to_owned())),
        Err(kawacad_core::command::CommandError::InvalidValue { field: "layer", .. })
    ));
}

#[test]
fn document_rejects_invalid_mutations_without_changing_state() {
    let mut document = ProjectDocument::new("Invalid Mutations");
    let baseline = document.clone();

    assert!(matches!(
        document.apply_command(DocumentCommand::AddLayer(layer(
            "layer:cut-line",
            "Duplicate",
            LayerKind::Dimension,
            true
        ))),
        Err(kawacad_core::command::CommandError::DuplicateId { kind: "layer", .. })
    ));
    assert!(matches!(
        document.apply_command(DocumentCommand::SetLayerVisibility {
            layer_id: "layer:missing".to_owned(),
            visible: false,
        }),
        Err(kawacad_core::command::CommandError::MissingId { kind: "layer", .. })
    ));
    assert!(matches!(
        document.apply_command(DocumentCommand::SetLayerPrintable {
            layer_id: "layer:missing".to_owned(),
            printable: false,
        }),
        Err(kawacad_core::command::CommandError::MissingId { kind: "layer", .. })
    ));
    assert!(matches!(
        document.apply_command(DocumentCommand::AddParameter(parameter(
            "parameter:bad",
            "",
            1.0
        ))),
        Err(kawacad_core::command::CommandError::InvalidValue {
            field: "parameter name",
            ..
        })
    ));
    assert!(matches!(
        document.apply_command(DocumentCommand::AddEntity(point_entity(
            "entity:bad",
            point(f64::NAN, 0.0),
        ))),
        Err(kawacad_core::command::CommandError::InvalidEntity(
            kawacad_core::geometry::GeometryValidationError::NonFiniteValue(_)
        ))
    ));
    assert!(matches!(
        document.apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:empty",
            ConstraintKind::Fixed,
            vec![],
            None,
        ))),
        Err(CommandError::Constraint(error))
            if error.code == ConstraintCommandErrorCode::InsufficientTargets
    ));
    assert!(matches!(
        document.apply_command(DocumentCommand::DeleteParameter {
            parameter_id: "parameter:missing".to_owned(),
            replacement_value_mm: -1.0,
        }),
        Err(kawacad_core::command::CommandError::InvalidValue {
            field: "replacement value",
            ..
        })
    ));
    assert!(matches!(
        document.apply_command(DocumentCommand::SetParameterValue {
            parameter_id: "parameter:missing".to_owned(),
            value_mm: -1.0,
        }),
        Err(kawacad_core::command::CommandError::InvalidValue {
            field: "parameter value",
            ..
        })
    ));
    assert!(matches!(
        document.apply_command(DocumentCommand::DeleteEntity("entity:missing".to_owned())),
        Err(kawacad_core::command::CommandError::MissingId { kind: "entity", .. })
    ));
    assert!(matches!(
        document.apply_command(DocumentCommand::DeleteConstraint(
            "constraint:missing".to_owned()
        )),
        Err(kawacad_core::command::CommandError::MissingId {
            kind: "constraint",
            ..
        })
    ));
    assert!(matches!(
        document.apply_command(DocumentCommand::DeleteParameter {
            parameter_id: "parameter:missing".to_owned(),
            replacement_value_mm: 1.0,
        }),
        Err(kawacad_core::command::CommandError::MissingId {
            kind: "parameter",
            ..
        })
    ));
    assert!(matches!(
        document.apply_command(DocumentCommand::SetParameterValue {
            parameter_id: "parameter:missing".to_owned(),
            value_mm: 1.0,
        }),
        Err(kawacad_core::command::CommandError::MissingId {
            kind: "parameter",
            ..
        })
    ));
    assert!(matches!(
        document.apply_command(DocumentCommand::UpdateEntity(point_entity(
            "entity:missing",
            point(1.0, 1.0),
        ))),
        Err(kawacad_core::command::CommandError::MissingId { kind: "entity", .. })
    ));

    let mut with_entity = baseline.clone();
    with_entity
        .apply_command(DocumentCommand::AddEntity(point_entity(
            "entity:point-a",
            point(0.0, 0.0),
        )))
        .expect("setup entity");
    assert!(matches!(
        with_entity.apply_command(DocumentCommand::UpdateConstraint(constraint(
            "constraint:missing",
            ConstraintKind::Fixed,
            vec![entity_target("entity:point-a")],
            None,
        ))),
        Err(kawacad_core::command::CommandError::MissingId {
            kind: "constraint",
            ..
        })
    ));

    let mut with_parameter = baseline.clone();
    with_parameter
        .apply_command(DocumentCommand::AddParameter(parameter(
            "parameter:length",
            "length",
            10.0,
        )))
        .expect("setup parameter");
    assert!(matches!(
        with_parameter.apply_command(DocumentCommand::AddParameter(parameter(
            "parameter:length",
            "length-again",
            12.0,
        ))),
        Err(kawacad_core::command::CommandError::DuplicateId {
            kind: "parameter",
            ..
        })
    ));

    assert_eq!(document, baseline);
}

#[test]
fn document_update_paths_reapply_existing_state() {
    let mut document = ProjectDocument::new("Update Paths");
    document
        .apply_command(DocumentCommand::AddLayer(layer(
            "layer:user",
            "User",
            LayerKind::Dimension,
            true,
        )))
        .expect("layer should be added");

    assert!(matches!(
        document.apply_command(DocumentCommand::AddEntity(
            point_entity("entity:orphan", point(0.0, 0.0)).on_layer("layer:missing")
        )),
        Err(kawacad_core::command::CommandError::BrokenReference {
            target_kind: "layer",
            ..
        })
    ));

    document
        .apply_command(DocumentCommand::AddEntity(
            point_entity("entity:point", point(1.0, 2.0)).on_layer("layer:user"),
        ))
        .expect("point should be added");
    document
        .apply_command(DocumentCommand::UpdateEntity(
            point_entity("entity:point", point(3.0, 4.0)).on_layer("layer:user"),
        ))
        .expect("point should be updated");
    assert_eq!(
        document.entity("entity:point").unwrap().kind,
        EntityKind::Point(point(3.0, 4.0))
    );

    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("line should be added");
    document
        .apply_command(DocumentCommand::AddParameter(parameter(
            "parameter:length",
            "length",
            10.0,
        )))
        .expect("parameter should be added");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:length",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:line")],
            Some(ConstraintValue::Parameter("parameter:length".to_owned())),
        )))
        .expect("constraint should be added");
    assert_line_length(document.entity("entity:line").unwrap(), 10.0);

    document
        .apply_command(DocumentCommand::UpdateParameter(parameter(
            "parameter:length",
            "length-updated",
            16.0,
        )))
        .expect("parameter should be updated");
    assert_line_length(document.entity("entity:line").unwrap(), 16.0);

    assert!(document
        .entities()
        .iter()
        .any(|entity| entity.id == "entity:line"));
}

#[test]
fn document_validation_rejects_invalid_metadata_and_schema_versions() {
    let document = document_with_json_mutation("Validation", |value| {
        value["document"]["id"] = serde_json::Value::String(" ".to_owned());
    });
    assert!(matches!(
        document.validate(),
        Err(DocumentValidationError::EmptyId("document metadata"))
    ));

    let document = document_with_json_mutation("Validation", |value| {
        value["document"]["name"] = serde_json::Value::String(" ".to_owned());
    });
    assert!(matches!(
        document.validate(),
        Err(DocumentValidationError::InvalidValue {
            field: "document name",
            ..
        })
    ));

    let document = document_with_json_mutation("Validation", |value| {
        value["document"]["unit"] = serde_json::Value::String("cm".to_owned());
    });
    assert!(matches!(
        document.validate(),
        Err(DocumentValidationError::InvalidValue {
            field: "document unit",
            ..
        })
    ));

    let document = document_with_json_mutation("Validation", |value| {
        value["schemaVersion"] = serde_json::Value::String("9.9.9".to_owned());
    });
    assert!(matches!(
        document.validate(),
        Err(DocumentValidationError::UnsupportedSchemaVersion { .. })
    ));
}

#[test]
fn document_validation_and_io_reject_broken_documents() {
    let duplicate = document_with_json_mutation("Duplicate", |value| {
        let duplicate_layer = value["layers"][0].clone();
        value["layers"]
            .as_array_mut()
            .expect("layers should be array")
            .push(duplicate_layer);
    });
    assert!(matches!(
        duplicate.validate(),
        Err(DocumentValidationError::DuplicateId { kind: "layer", .. })
    ));

    let bad_version = document_with_json_mutation("Version", |value| {
        value["fileFormatVersion"] = serde_json::Value::String("9.9.9".to_owned());
    });
    assert!(matches!(
        bad_version.validate(),
        Err(DocumentValidationError::UnsupportedFileFormatVersion { .. })
    ));

    let bad_json = serde_json::to_string(&bad_version).expect("serialize bad version");
    assert!(matches!(
        ProjectDocument::from_json_str(&bad_json),
        Err(DocumentIoError::ValidationFailed(
            DocumentValidationError::UnsupportedFileFormatVersion { .. }
        ))
    ));

    let mut invalid_parameter = ProjectDocument::new("Invalid Parameter");
    assert!(matches!(
        invalid_parameter.apply_command(DocumentCommand::AddParameter(parameter(
            "parameter:bad",
            "",
            -1.0,
        ))),
        Err(kawacad_core::command::CommandError::InvalidValue {
            field: "parameter name",
            ..
        })
    ));

    let mut invalid_layer = ProjectDocument::new("Invalid Layer");
    assert!(matches!(
        invalid_layer.apply_command(DocumentCommand::AddLayer(layer(
            "layer:bad",
            "",
            LayerKind::Dimension,
            true,
        ))),
        Err(kawacad_core::command::CommandError::InvalidValue {
            field: "layer name",
            ..
        })
    ));

    let invalid_json = "{\"fileFormatVersion\":\"0.1.0\"}";
    assert!(matches!(
        ProjectDocument::from_json_str(invalid_json),
        Err(DocumentIoError::ValidationFailed(_)) | Err(DocumentIoError::DeserializeFailed(_))
    ));

    let missing_file = temp_path("missing.kawa");
    assert!(matches!(
        ProjectDocument::read_json_file(&missing_file),
        Err(DocumentIoError::ReadFailed(_))
    ));
    assert!(matches!(
        ProjectDocument::new("Write Failure").write_json_file(std::env::temp_dir()),
        Err(DocumentIoError::WriteFailed(_))
    ));
}

#[test]
fn project_document_store_facade_keeps_kawa_top_level_shape() {
    let document = ProjectDocument::new("Shape");
    let json = document
        .to_json_pretty_string()
        .expect("document should serialize");
    let value: serde_json::Value = serde_json::from_str(&json).expect("document JSON should parse");
    let object = value.as_object().expect("document JSON should be object");

    assert!(object.contains_key("fileFormatVersion"));
    assert!(object.contains_key("schemaVersion"));
    assert!(object.contains_key("document"));
    assert!(object.contains_key("settings"));
    assert!(object.contains_key("layers"));
    assert!(object.contains_key("parameters"));
    assert!(object.contains_key("entities"));
    assert!(object.contains_key("derivedElements"));
    assert!(object.contains_key("constraints"));
    assert!(!object.contains_key("store"));
    assert!(!object.contains_key("history"));
    assert!(!object.contains_key("documentWarnings"));

    let round_tripped = ProjectDocument::from_json_str(&json).expect("document should deserialize");
    assert_eq!(round_tripped, document);
}

#[test]
fn command_errors_convert_to_document_validation_errors() {
    assert!(matches!(
        DocumentValidationError::from(CommandError::EmptyId("entity")),
        DocumentValidationError::EmptyId("entity")
    ));
    assert!(matches!(
        DocumentValidationError::from(CommandError::DuplicateId {
            kind: "layer",
            id: "layer:duplicate".to_owned(),
        }),
        DocumentValidationError::DuplicateId {
            kind: "layer",
            id,
        } if id == "layer:duplicate"
    ));
    assert!(matches!(
        DocumentValidationError::from(CommandError::MissingId {
            kind: "parameter",
            id: "parameter:missing".to_owned(),
        }),
        DocumentValidationError::BrokenReference {
            source: "parameter",
            target_kind: "parameter",
            target_id,
        } if target_id == "parameter:missing"
    ));
    assert!(matches!(
        DocumentValidationError::from(CommandError::InvalidEntity(
            kawacad_core::geometry::GeometryValidationError::DegenerateLineSegment,
        )),
        DocumentValidationError::InvalidEntity {
            entity_id,
            error: kawacad_core::geometry::GeometryValidationError::DegenerateLineSegment,
        } if entity_id.is_empty()
    ));
    assert!(matches!(
        DocumentValidationError::from(CommandError::InvalidValue {
            field: "value",
            reason: "bad",
        }),
        DocumentValidationError::InvalidValue {
            field: "value",
            reason: "bad",
        }
    ));
    assert!(matches!(
        DocumentValidationError::from(CommandError::BrokenReference {
            source: "constraint",
            target_kind: "entity",
            target_id: "entity:missing".to_owned(),
        }),
        DocumentValidationError::BrokenReference {
            source: "constraint",
            target_kind: "entity",
            target_id,
        } if target_id == "entity:missing"
    ));
}

#[test]
fn document_rejects_additional_invalid_command_values() {
    let mut document = ProjectDocument::new("Invalid Command Values");

    for mut invalid_layer in [
        {
            let mut layer = layer("layer:bad-width", "Bad Width", LayerKind::Dimension, true);
            layer.style.stroke_width_mm = -0.1;
            layer
        },
        {
            let mut layer = layer("layer:bad-red", "Bad Red", LayerKind::Dimension, true);
            layer.style.stroke.red = 1.5;
            layer
        },
        {
            let mut layer = layer(" ", "Blank Id", LayerKind::Dimension, true);
            layer.style.stroke = kawacad_core::layers::Rgba::BLACK;
            layer
        },
    ] {
        assert!(
            document
                .apply_command(DocumentCommand::AddLayer(invalid_layer.clone()))
                .is_err(),
            "layer should be rejected: {invalid_layer:?}"
        );
        invalid_layer.style.stroke_width_mm = f64::NAN;
        assert!(
            document
                .apply_command(DocumentCommand::AddLayer(invalid_layer))
                .is_err(),
            "non-finite layer stroke width should be rejected"
        );
    }

    for invalid_parameter in [
        parameter("parameter:negative", "negative", -1.0),
        parameter("parameter:non-finite", "non-finite", f64::INFINITY),
        parameter(" ", "blank id", 1.0),
    ] {
        assert!(
            document
                .apply_command(DocumentCommand::AddParameter(invalid_parameter.clone()))
                .is_err(),
            "parameter should be rejected: {invalid_parameter:?}"
        );
    }
}

#[test]
fn constraint_value_validation_rejects_mismatched_or_missing_values() {
    let mut document = ProjectDocument::new("Invalid Constraint Values");
    document
        .apply_command(DocumentCommand::AddEntity(point_entity(
            "entity:point-a",
            point(0.0, 0.0),
        )))
        .expect("point a");
    document
        .apply_command(DocumentCommand::AddEntity(point_entity(
            "entity:point-b",
            point(10.0, 0.0),
        )))
        .expect("point b");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line-a",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("line a");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line-b",
            point(0.0, 0.0),
            point(0.0, 10.0),
        )))
        .expect("line b");

    for (id, kind, targets, value, expected_field) in [
        (
            "constraint:horizontal-value",
            ConstraintKind::Horizontal,
            vec![entity_target("entity:line-a")],
            Some(ConstraintValue::FixedMm(1.0)),
            "orientation constraint value",
        ),
        (
            "constraint:segment-missing",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:line-a")],
            None,
            "segment length value",
        ),
        (
            "constraint:segment-degrees",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:line-a")],
            Some(ConstraintValue::FixedDegrees(1.0)),
            "segment length value",
        ),
        (
            "constraint:distance-negative",
            ConstraintKind::Distance,
            vec![
                entity_target("entity:point-a"),
                entity_target("entity:point-b"),
            ],
            Some(ConstraintValue::FixedMm(-1.0)),
            "distance constraint value",
        ),
        (
            "constraint:angle-millimeters",
            ConstraintKind::Angle,
            vec![
                entity_target("entity:line-a"),
                entity_target("entity:line-b"),
            ],
            Some(ConstraintValue::FixedMm(1.0)),
            "angle constraint value",
        ),
        (
            "constraint:angle-nan",
            ConstraintKind::Angle,
            vec![
                entity_target("entity:line-a"),
                entity_target("entity:line-b"),
            ],
            Some(ConstraintValue::FixedDegrees(f64::NAN)),
            "angle constraint value",
        ),
    ] {
        assert!(matches!(
            document.apply_command(DocumentCommand::AddConstraint(constraint(
                id, kind, targets, value,
            ))),
            Err(CommandError::InvalidValue { field, .. }) if field == expected_field
        ));
    }

    assert!(matches!(
        document.apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:distance-missing-parameter",
            ConstraintKind::Distance,
            vec![
                entity_target("entity:point-a"),
                entity_target("entity:point-b"),
            ],
            Some(ConstraintValue::Parameter("parameter:missing".to_owned())),
        ))),
        Err(CommandError::BrokenReference {
            source: "constraint",
            target_kind: "parameter",
            ..
        })
    ));
}

#[test]
fn duplicate_constraints_are_rejected_without_mutating_state() {
    let mut document = ProjectDocument::new("Duplicate Constraints");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line-a",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("line a");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line-b",
            point(0.0, 4.0),
            point(10.0, 4.0),
        )))
        .expect("line b");

    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:parallel-a",
            ConstraintKind::Parallel,
            vec![
                entity_target("entity:line-a"),
                entity_target("entity:line-b"),
            ],
            None,
        )))
        .expect("initial parallel constraint");

    let before = document.clone();
    assert!(matches!(
        document.apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:parallel-b",
            ConstraintKind::Parallel,
            vec![entity_target("entity:line-b"), entity_target("entity:line-a")],
            None,
        ))),
        Err(CommandError::Constraint(error))
            if error.code == ConstraintCommandErrorCode::Duplicate
                && error.existing_constraint_id.as_deref() == Some("constraint:parallel-a")
    ));
    assert_eq!(document, before);
}

#[test]
fn duplicate_point_line_distance_is_rejected_even_if_target_order_is_reversed() {
    let mut document = ProjectDocument::new("Duplicate Point Line Distance");
    document
        .apply_command(DocumentCommand::AddEntity(point_entity(
            "entity:point-a",
            point(2.0, 5.0),
        )))
        .expect("point a");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line-a",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("line a");

    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:point-line-a",
            ConstraintKind::PointLineDistance,
            vec![
                entity_target("entity:point-a"),
                entity_target("entity:line-a"),
            ],
            Some(ConstraintValue::FixedMm(5.0)),
        )))
        .expect("initial point-line distance");

    let before = document.clone();
    assert!(matches!(
        document.apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:point-line-b",
            ConstraintKind::PointLineDistance,
            vec![entity_target("entity:line-a"), entity_target("entity:point-a")],
            Some(ConstraintValue::FixedMm(5.0)),
        ))),
        Err(CommandError::Constraint(error))
            if error.code == ConstraintCommandErrorCode::Duplicate
                && error.existing_constraint_id.as_deref() == Some("constraint:point-line-a")
    ));
    assert_eq!(document, before);
}

#[test]
fn duplicate_line_line_distance_is_rejected_even_if_target_order_is_reversed() {
    let mut document = ProjectDocument::new("Duplicate Line Line Distance");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line-a",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("line a");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line-b",
            point(0.0, 5.0),
            point(10.0, 5.0),
        )))
        .expect("line b");

    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:line-line-a",
            ConstraintKind::LineLineDistance,
            vec![
                entity_target("entity:line-a"),
                entity_target("entity:line-b"),
            ],
            Some(ConstraintValue::FixedMm(5.0)),
        )))
        .expect("initial line-line distance");

    let before = document.clone();
    assert!(matches!(
        document.apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:line-line-b",
            ConstraintKind::LineLineDistance,
            vec![entity_target("entity:line-b"), entity_target("entity:line-a")],
            Some(ConstraintValue::FixedMm(5.0)),
        ))),
        Err(CommandError::Constraint(error))
            if error.code == ConstraintCommandErrorCode::Duplicate
                && error.existing_constraint_id.as_deref() == Some("constraint:line-line-a")
    ));
    assert_eq!(document, before);
}

#[test]
fn duplicate_point_on_line_is_rejected_even_if_target_order_is_reversed() {
    let mut document = ProjectDocument::new("Duplicate Point On Line");
    document
        .apply_command(DocumentCommand::AddEntity(point_entity(
            "entity:point-a",
            point(2.0, 5.0),
        )))
        .expect("point a");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line-a",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("line a");

    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:point-on-line-a",
            ConstraintKind::PointOnLine,
            vec![
                entity_target("entity:point-a"),
                entity_target("entity:line-a"),
            ],
            None,
        )))
        .expect("initial point-on-line");

    let before = document.clone();
    assert!(matches!(
        document.apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:point-on-line-b",
            ConstraintKind::PointOnLine,
            vec![entity_target("entity:line-a"), entity_target("entity:point-a")],
            None,
        ))),
        Err(CommandError::Constraint(error))
            if error.code == ConstraintCommandErrorCode::Duplicate
                && error.existing_constraint_id.as_deref() == Some("constraint:point-on-line-a")
    ));
    assert_eq!(document, before);
}

#[test]
fn coincident_updates_cover_supported_control_points() {
    let mut document = document_with_json_mutation("Extended Control Points", |value| {
        value["entities"]
            .as_array_mut()
            .expect("entities should be array")
            .extend([
                serde_json::to_value(point_entity("entity:point-a", point(0.0, 0.0))).unwrap(),
                serde_json::to_value(point_entity("entity:point-b", point(0.0, 0.0))).unwrap(),
                serde_json::to_value(point_entity("entity:circle-handle", point(70.0, 70.0)))
                    .unwrap(),
                serde_json::to_value(circle_entity("entity:circle", point(70.0, 70.0), 5.0))
                    .unwrap(),
                serde_json::to_value(point_entity(
                    "entity:arc-center-handle",
                    point(100.0, 100.0),
                ))
                .unwrap(),
                serde_json::to_value(arc_entity(
                    "entity:arc-center",
                    point(100.0, 100.0),
                    10.0,
                    0.0,
                    std::f64::consts::FRAC_PI_2,
                ))
                .unwrap(),
                serde_json::to_value(point_entity("entity:arc-start-handle", point(130.0, 100.0)))
                    .unwrap(),
                serde_json::to_value(arc_entity(
                    "entity:arc-start",
                    point(120.0, 100.0),
                    10.0,
                    0.0,
                    std::f64::consts::FRAC_PI_2,
                ))
                .unwrap(),
                serde_json::to_value(point_entity("entity:arc-end-handle", point(200.0, 210.0)))
                    .unwrap(),
                serde_json::to_value(arc_entity(
                    "entity:arc-end",
                    point(200.0, 200.0),
                    10.0,
                    0.0,
                    std::f64::consts::FRAC_PI_2,
                ))
                .unwrap(),
            ]);
    });
    document
        .validate()
        .expect("extended document should validate");

    for constraint_def in [
        constraint(
            "constraint:point-point",
            ConstraintKind::Coincident,
            vec![
                entity_target("entity:point-a"),
                entity_target("entity:point-b"),
            ],
            None,
        ),
        constraint(
            "constraint:circle-center",
            ConstraintKind::Coincident,
            vec![
                entity_target("entity:circle-handle"),
                point_target("entity:circle", ControlPointKind::Center),
            ],
            None,
        ),
        constraint(
            "constraint:arc-center",
            ConstraintKind::Coincident,
            vec![
                entity_target("entity:arc-center-handle"),
                point_target("entity:arc-center", ControlPointKind::Center),
            ],
            None,
        ),
        constraint(
            "constraint:arc-start",
            ConstraintKind::Coincident,
            vec![
                entity_target("entity:arc-start-handle"),
                point_target("entity:arc-start", ControlPointKind::Start),
            ],
            None,
        ),
        constraint(
            "constraint:arc-end",
            ConstraintKind::Coincident,
            vec![
                entity_target("entity:arc-end-handle"),
                point_target("entity:arc-end", ControlPointKind::End),
            ],
            None,
        ),
    ] {
        document
            .apply_command(DocumentCommand::AddConstraint(constraint_def))
            .expect("coincident constraint should be added");
    }

    update_point_entity(&mut document, "entity:point-a", point(3.0, 4.0));
    assert_eq!(
        document.entity("entity:point-b").unwrap().kind,
        EntityKind::Point(point(3.0, 4.0))
    );

    update_point_entity(&mut document, "entity:circle-handle", point(72.0, 73.0));
    let circle = circle_geometry(document.entity("entity:circle").unwrap());
    assert_approx_eq(circle.center.x_mm, 72.0);
    assert_approx_eq(circle.center.y_mm, 73.0);

    update_point_entity(
        &mut document,
        "entity:arc-center-handle",
        point(101.0, 102.0),
    );
    let arc_center = arc_geometry(document.entity("entity:arc-center").unwrap());
    assert_approx_eq(arc_center.center.x_mm, 101.0);
    assert_approx_eq(arc_center.center.y_mm, 102.0);

    update_point_entity(
        &mut document,
        "entity:arc-start-handle",
        point(140.0, 100.0),
    );
    let moved_start_arc = arc_geometry(document.entity("entity:arc-start").unwrap());
    assert_points_close(arc_start(moved_start_arc), point(140.0, 100.0));
    assert_points_close(arc_end(moved_start_arc), point(120.0, 110.0));

    update_point_entity(&mut document, "entity:arc-end-handle", point(200.0, 220.0));
    let moved_end_arc = arc_geometry(document.entity("entity:arc-end").unwrap());
    assert_points_close(arc_start(moved_end_arc), point(210.0, 200.0));
    assert_points_close(arc_end(moved_end_arc), point(200.0, 220.0));
}

#[test]
fn moving_arc_endpoint_to_the_opposite_endpoint_is_rejected() {
    let mut document = ProjectDocument::new("Invalid Arc Endpoint Move");
    document
        .apply_command(DocumentCommand::AddEntity(point_entity(
            "entity:handle",
            point(10.0, 0.0),
        )))
        .expect("handle");
    document
        .apply_command(DocumentCommand::AddEntity(arc_entity(
            "entity:arc",
            point(0.0, 0.0),
            10.0,
            0.0,
            std::f64::consts::FRAC_PI_2,
        )))
        .expect("arc");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:arc-start",
            ConstraintKind::Coincident,
            vec![
                entity_target("entity:handle"),
                point_target("entity:arc", ControlPointKind::Start),
            ],
            None,
        )))
        .expect("arc start coincident");

    assert!(matches!(
        document.apply_command(DocumentCommand::UpdateEntity(point_entity(
            "entity:handle",
            point(0.0, 10.0),
        ))),
        Err(CommandError::InvalidValue {
            field: "constraint targets",
            ..
        })
    ));
}

#[test]
fn undo_and_redo_reject_empty_history() {
    let mut document = ProjectDocument::new("Undo");
    assert!(!document.can_undo());
    assert!(!document.can_redo());
    assert!(matches!(
        document.undo(),
        Err(kawacad_core::command::CommandError::InvalidValue { field: "undo", .. })
    ));
    assert!(matches!(
        document.redo(),
        Err(kawacad_core::command::CommandError::InvalidValue { field: "redo", .. })
    ));
}

#[test]
fn undo_and_redo_restore_previous_command_states() {
    let mut document = ProjectDocument::new("Undo");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line-a",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )))
        .expect("line should be added");
    document
        .apply_command(DocumentCommand::AddEntity(point_entity(
            "entity:point-a",
            point(1.0, 2.0),
        )))
        .expect("point should be added");

    assert_eq!(document.entities().len(), 2);
    assert!(document.can_undo());
    assert!(!document.can_redo());

    document.undo().expect("undo should succeed");
    assert_eq!(document.entities().len(), 1);
    assert_eq!(document.entities()[0].id, "entity:line-a");
    assert!(document.can_undo());
    assert!(document.can_redo());

    document.undo().expect("second undo should succeed");
    assert!(document.entities().is_empty());
    assert!(!document.can_undo());
    assert!(document.can_redo());

    document.redo().expect("redo should succeed");
    assert_eq!(document.entities().len(), 1);
    assert_eq!(document.entities()[0].id, "entity:line-a");
    assert!(document.can_undo());
    assert!(document.can_redo());

    document.redo().expect("second redo should succeed");
    assert_eq!(document.entities().len(), 2);
    assert_eq!(document.entities()[1].id, "entity:point-a");
    assert!(document.can_undo());
    assert!(!document.can_redo());

    document
        .apply_command(DocumentCommand::AddLayer(layer(
            "layer:user",
            "User",
            LayerKind::Dimension,
            true,
        )))
        .expect("new change should clear redo");
    assert!(matches!(
        document.redo(),
        Err(kawacad_core::command::CommandError::InvalidValue { field: "redo", .. })
    ));
}

#[test]
fn compound_command_is_atomic_and_uses_one_history_entry() {
    let mut document = ProjectDocument::new("Compound");

    let failing = document.apply_command(DocumentCommand::Compound(vec![
        DocumentCommand::AddEntity(line_entity(
            "entity:line-a",
            point(0.0, 0.0),
            point(10.0, 0.0),
        )),
        DocumentCommand::AddConstraint(constraint(
            "constraint:missing-target",
            ConstraintKind::Horizontal,
            vec![entity_target("entity:missing")],
            None,
        )),
    ]));

    assert!(failing.is_err());
    assert!(document.entities().is_empty());
    assert!(document.constraints().is_empty());
    assert!(matches!(
        document.undo(),
        Err(kawacad_core::command::CommandError::InvalidValue { field: "undo", .. })
    ));

    document
        .apply_command(DocumentCommand::Compound(vec![
            DocumentCommand::AddEntity(line_entity(
                "entity:line-a",
                point(0.0, 0.0),
                point(10.0, 0.0),
            )),
            DocumentCommand::AddConstraint(constraint(
                "constraint:line-a-horizontal",
                ConstraintKind::Horizontal,
                vec![entity_target("entity:line-a")],
                None,
            )),
        ]))
        .expect("compound command should succeed");

    assert_eq!(document.entities().len(), 1);
    assert_eq!(document.constraints().len(), 1);

    document.undo().expect("compound should undo as one entry");
    assert!(document.entities().is_empty());
    assert!(document.constraints().is_empty());

    document.redo().expect("compound should redo as one entry");
    assert_eq!(document.entities().len(), 1);
    assert_eq!(document.constraints().len(), 1);
}

fn assert_line_length(entity: &kawacad_core::geometry::Entity, expected_mm: f64) {
    match &entity.kind {
        EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => {
            assert_approx_eq(line.length_mm(), expected_mm);
        }
        other => panic!("expected line entity, got {other:?}"),
    }
}

fn resolved_entities(
    document: &ProjectDocument,
    derived_id: &str,
) -> Vec<kawacad_core::geometry::Entity> {
    let prefix = format!("{derived_id}:resolved:");
    document
        .drawing_snapshot(CanvasViewMode::EditDisplay)
        .entities
        .into_iter()
        .filter(|entity| entity.id.starts_with(&prefix))
        .collect()
}

fn assert_line_arc_closed_offset(document: &ProjectDocument, derived_id: &str, distance_mm: f64) {
    let offset_entities = resolved_entities(document, derived_id);
    assert_eq!(offset_entities.len(), 4);
    assert_line(
        &offset_entities[0],
        point(distance_mm, distance_mm),
        point(20.0, distance_mm),
    );
    assert_arc_endpoints_and_sweep(
        &offset_entities[1],
        point(20.0, distance_mm),
        point(20.0, 20.0 - distance_mm),
        180.0_f64.to_radians(),
    );
    assert_line(
        &offset_entities[2],
        point(20.0, 20.0 - distance_mm),
        point(distance_mm, 20.0 - distance_mm),
    );
    assert_line(
        &offset_entities[3],
        point(distance_mm, 20.0 - distance_mm),
        point(distance_mm, distance_mm),
    );
}

struct OffsetAcceptanceFixture {
    document: ProjectDocument,
    derived_id: &'static str,
    expected_resolved_count: usize,
    expects_arc: bool,
}

fn single_line_offset_fixture() -> OffsetAcceptanceFixture {
    let mut document = ProjectDocument::new("Single Line Offset");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line",
            point(0.0, 0.0),
            point(20.0, 0.0),
        )))
        .expect("line");
    add_parameterized_offset(
        &mut document,
        "derived:offset-single-line",
        vec!["entity:line".to_owned()],
        OffsetDirection::Left,
    );
    OffsetAcceptanceFixture {
        document,
        derived_id: "derived:offset-single-line",
        expected_resolved_count: 1,
        expects_arc: false,
    }
}

fn open_line_arc_offset_fixture() -> OffsetAcceptanceFixture {
    let mut document = ProjectDocument::new("Open Line Arc Offset");
    for entity in [
        line_entity("entity:line", point(0.0, 0.0), point(10.0, 0.0)),
        arc_entity(
            "entity:arc",
            point(10.0, 5.0),
            5.0,
            -90.0_f64.to_radians(),
            90.0_f64.to_radians(),
        ),
    ] {
        document
            .apply_command(DocumentCommand::AddEntity(entity))
            .unwrap();
    }
    add_parameterized_offset(
        &mut document,
        "derived:offset-open-line-arc",
        vec!["entity:line".to_owned(), "entity:arc".to_owned()],
        OffsetDirection::Left,
    );
    OffsetAcceptanceFixture {
        document,
        derived_id: "derived:offset-open-line-arc",
        expected_resolved_count: 2,
        expects_arc: true,
    }
}

fn closed_line_rectangle_offset_fixture() -> OffsetAcceptanceFixture {
    let mut document = ProjectDocument::new("Closed Line Rectangle Offset");
    for entity in [
        line_entity("entity:bottom", point(0.0, 0.0), point(20.0, 0.0)),
        line_entity("entity:right", point(20.0, 0.0), point(20.0, 20.0)),
        line_entity("entity:top", point(20.0, 20.0), point(0.0, 20.0)),
        line_entity("entity:left", point(0.0, 20.0), point(0.0, 0.0)),
    ] {
        document
            .apply_command(DocumentCommand::AddEntity(entity))
            .unwrap();
    }
    add_parameterized_offset(
        &mut document,
        "derived:offset-closed-lines",
        vec![
            "entity:bottom".to_owned(),
            "entity:right".to_owned(),
            "entity:top".to_owned(),
            "entity:left".to_owned(),
        ],
        OffsetDirection::Inward,
    );
    OffsetAcceptanceFixture {
        document,
        derived_id: "derived:offset-closed-lines",
        expected_resolved_count: 4,
        expects_arc: false,
    }
}

fn closed_line_arc_offset_fixture() -> OffsetAcceptanceFixture {
    let mut document = ProjectDocument::new("Closed Line Arc Offset");
    for entity in [
        line_entity("entity:bottom", point(0.0, 0.0), point(20.0, 0.0)),
        arc_entity(
            "entity:right-arc",
            point(20.0, 10.0),
            10.0,
            -90.0_f64.to_radians(),
            180.0_f64.to_radians(),
        ),
        line_entity("entity:top", point(20.0, 20.0), point(0.0, 20.0)),
        line_entity("entity:left", point(0.0, 20.0), point(0.0, 0.0)),
    ] {
        document
            .apply_command(DocumentCommand::AddEntity(entity))
            .unwrap();
    }
    add_parameterized_offset(
        &mut document,
        "derived:offset-closed-line-arc",
        vec![
            "entity:bottom".to_owned(),
            "entity:right-arc".to_owned(),
            "entity:top".to_owned(),
            "entity:left".to_owned(),
        ],
        OffsetDirection::Inward,
    );
    OffsetAcceptanceFixture {
        document,
        derived_id: "derived:offset-closed-line-arc",
        expected_resolved_count: 4,
        expects_arc: true,
    }
}

fn add_parameterized_offset(
    document: &mut ProjectDocument,
    derived_id: &'static str,
    source_entity_ids: Vec<String>,
    direction: OffsetDirection,
) {
    document
        .apply_command(DocumentCommand::AddParameter(parameter(
            "parameter:offset",
            "offset",
            1.0,
        )))
        .expect("offset parameter");
    document
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                derived_id,
                Some("layer:cut-line".to_owned()),
                OffsetCurve {
                    source_entity_ids,
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::Parameter("parameter:offset".to_owned()),
                    direction,
                },
            ),
        ))
        .expect("parameterized offset");
}

fn assert_offset_fixture_resolves_and_outputs(fixture: &OffsetAcceptanceFixture) {
    let resolved = resolved_entities(&fixture.document, fixture.derived_id);
    assert_eq!(resolved.len(), fixture.expected_resolved_count);
    if fixture.expects_arc {
        assert!(resolved
            .iter()
            .any(|entity| matches!(entity.kind, EntityKind::Arc(_))));
    }

    let output = fixture
        .document
        .build_output_document_model(kawacad_core::output::BuildOutputDocumentModelOptions {
            orientation: kawacad_core::print::PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: kawacad_core::output::PrintableAreaMm {
                left_mm: -100.0,
                right_mm: 100.0,
                top_mm: 100.0,
                bottom_mm: -100.0,
            },
        })
        .expect("output document model should build");
    let prefix = format!("{}:resolved:", fixture.derived_id);
    let output_offset_graphics = output.output_document_model.pages[0]
        .graphics
        .iter()
        .filter(|graphic| graphic.entity_id.starts_with(&prefix))
        .collect::<Vec<_>>();
    assert_eq!(
        output_offset_graphics.len(),
        fixture.expected_resolved_count
    );
    if fixture.expects_arc {
        assert!(output_offset_graphics
            .iter()
            .any(|graphic| graphic.kind == kawacad_core::output::OutputGraphicKind::Arc));
    }
}

fn assert_line(
    entity: &kawacad_core::geometry::Entity,
    expected_start: kawacad_core::geometry::Point2,
    expected_end: kawacad_core::geometry::Point2,
) {
    match &entity.kind {
        EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => {
            assert_approx_eq(line.start.x_mm, expected_start.x_mm);
            assert_approx_eq(line.start.y_mm, expected_start.y_mm);
            assert_approx_eq(line.end.x_mm, expected_end.x_mm);
            assert_approx_eq(line.end.y_mm, expected_end.y_mm);
        }
        other => panic!("expected line entity, got {other:?}"),
    }
}

fn assert_arc_endpoints_and_sweep(
    entity: &kawacad_core::geometry::Entity,
    expected_start: kawacad_core::geometry::Point2,
    expected_end: kawacad_core::geometry::Point2,
    expected_sweep_rad: f64,
) {
    let EntityKind::Arc(arc) = entity.kind else {
        panic!("expected arc entity, got {:?}", entity.kind);
    };

    let actual_start = point(
        arc.center.x_mm + arc.radius_mm * arc.start_angle_rad.cos(),
        arc.center.y_mm + arc.radius_mm * arc.start_angle_rad.sin(),
    );
    let end_angle_rad = arc.start_angle_rad + arc.sweep_angle_rad;
    let actual_end = point(
        arc.center.x_mm + arc.radius_mm * end_angle_rad.cos(),
        arc.center.y_mm + arc.radius_mm * end_angle_rad.sin(),
    );

    assert_approx_eq(actual_start.x_mm, expected_start.x_mm);
    assert_approx_eq(actual_start.y_mm, expected_start.y_mm);
    assert_approx_eq(actual_end.x_mm, expected_end.x_mm);
    assert_approx_eq(actual_end.y_mm, expected_end.y_mm);
    assert_approx_eq(arc.sweep_angle_rad, expected_sweep_rad);
}

fn assert_entity_remaining_dof(document: &ProjectDocument, entity_id: &str, expected_dof: usize) {
    let status = document
        .entity_constraint_statuses()
        .into_iter()
        .find(|status| status.entity_id == entity_id)
        .unwrap_or_else(|| panic!("{entity_id} status should exist"));
    assert_eq!(
        status.remaining_dof, expected_dof,
        "{entity_id} remaining DoF; status={:?}",
        status.status
    );
}

fn document_with_json_mutation(
    name: &str,
    mutate: impl FnOnce(&mut serde_json::Value),
) -> ProjectDocument {
    let document = ProjectDocument::new(name);
    let mut value = serde_json::to_value(document).expect("document should serialize");
    mutate(&mut value);
    serde_json::from_value(value).expect("mutated document should deserialize")
}

fn line_geometry(entity: &kawacad_core::geometry::Entity) -> kawacad_core::geometry::LineSegment {
    match &entity.kind {
        EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => *line,
        other => panic!("expected line entity, got {other:?}"),
    }
}

fn circle_geometry(entity: &kawacad_core::geometry::Entity) -> kawacad_core::geometry::Circle {
    match &entity.kind {
        EntityKind::Circle(circle) => *circle,
        other => panic!("expected circle entity, got {other:?}"),
    }
}

fn update_point_entity(
    document: &mut ProjectDocument,
    entity_id: &str,
    point: kawacad_core::geometry::Point2,
) {
    document
        .apply_command(DocumentCommand::UpdateEntity(point_entity(
            entity_id, point,
        )))
        .expect("point entity should update");
}

fn constrained_line_rectangle_document() -> ProjectDocument {
    constrained_line_rectangle_document_with_dimensions("entity:bottom", "entity:left")
}

fn constrained_line_rectangle_document_with_dimensions(
    width_entity_id: &str,
    height_entity_id: &str,
) -> ProjectDocument {
    constrained_line_rectangle_document_with_options(width_entity_id, height_entity_id, true)
}

fn constrained_line_rectangle_document_with_options(
    width_entity_id: &str,
    height_entity_id: &str,
    include_fixed_anchor: bool,
) -> ProjectDocument {
    let mut document = ProjectDocument::new("Line Rectangle");
    for entity in [
        line_entity("entity:bottom", point(0.0, 0.0), point(50.0, 0.0)),
        line_entity("entity:right", point(50.0, 0.0), point(50.0, 20.0)),
        line_entity("entity:top", point(50.0, 20.0), point(0.0, 20.0)),
        line_entity("entity:left", point(0.0, 20.0), point(0.0, 0.0)),
    ] {
        document
            .apply_command(DocumentCommand::AddEntity(entity))
            .expect("rectangle line should be added");
    }

    for constraint_def in [
        constraint(
            "constraint:bottom-left",
            ConstraintKind::Coincident,
            vec![
                point_target("entity:bottom", ControlPointKind::Start),
                point_target("entity:left", ControlPointKind::End),
            ],
            None,
        ),
        constraint(
            "constraint:bottom-right",
            ConstraintKind::Coincident,
            vec![
                point_target("entity:bottom", ControlPointKind::End),
                point_target("entity:right", ControlPointKind::Start),
            ],
            None,
        ),
        constraint(
            "constraint:top-right",
            ConstraintKind::Coincident,
            vec![
                point_target("entity:top", ControlPointKind::Start),
                point_target("entity:right", ControlPointKind::End),
            ],
            None,
        ),
        constraint(
            "constraint:top-left",
            ConstraintKind::Coincident,
            vec![
                point_target("entity:top", ControlPointKind::End),
                point_target("entity:left", ControlPointKind::Start),
            ],
            None,
        ),
        constraint(
            "constraint:bottom-horizontal",
            ConstraintKind::Horizontal,
            vec![entity_target("entity:bottom")],
            None,
        ),
        constraint(
            "constraint:top-horizontal",
            ConstraintKind::Horizontal,
            vec![entity_target("entity:top")],
            None,
        ),
        constraint(
            "constraint:left-vertical",
            ConstraintKind::Vertical,
            vec![entity_target("entity:left")],
            None,
        ),
        constraint(
            "constraint:right-vertical",
            ConstraintKind::Vertical,
            vec![entity_target("entity:right")],
            None,
        ),
    ] {
        document
            .apply_command(DocumentCommand::AddConstraint(constraint_def))
            .expect("rectangle constraint should be added");
    }

    if include_fixed_anchor {
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                "constraint:anchor",
                ConstraintKind::Fixed,
                vec![point_target("entity:bottom", ControlPointKind::Start)],
                None,
            )))
            .expect("rectangle anchor should be added");
    }

    for constraint_def in [
        constraint(
            "constraint:width",
            ConstraintKind::SegmentLength,
            vec![entity_target(width_entity_id)],
            Some(ConstraintValue::FixedMm(50.0)),
        ),
        constraint(
            "constraint:height",
            ConstraintKind::SegmentLength,
            vec![entity_target(height_entity_id)],
            Some(ConstraintValue::FixedMm(20.0)),
        ),
    ] {
        document
            .apply_command(DocumentCommand::AddConstraint(constraint_def))
            .expect("rectangle constraint should be added");
    }

    document
}

fn under_constrained_five_segment_outline_document() -> ProjectDocument {
    let mut document = ProjectDocument::new("Five Segment Outline");
    for entity in [
        line_entity("entity:bottom", point(30.0, 65.0), point(120.0, 65.0)),
        line_entity("entity:left", point(30.0, 65.0), point(30.0, 130.0)),
        line_entity("entity:top", point(30.0, 130.0), point(100.0, 130.0)),
        line_entity("entity:diagonal", point(100.0, 130.0), point(120.0, 105.0)),
        line_entity("entity:right", point(120.0, 105.0), point(120.0, 65.0)),
    ] {
        document
            .apply_command(DocumentCommand::AddEntity(entity))
            .expect("outline line should be added");
    }

    for constraint_def in [
        constraint(
            "constraint:bottom-horizontal",
            ConstraintKind::Horizontal,
            vec![entity_target("entity:bottom")],
            None,
        ),
        constraint(
            "constraint:bottom-left",
            ConstraintKind::Coincident,
            vec![
                point_target("entity:left", ControlPointKind::Start),
                point_target("entity:bottom", ControlPointKind::Start),
            ],
            None,
        ),
        constraint(
            "constraint:left-vertical",
            ConstraintKind::Vertical,
            vec![entity_target("entity:left")],
            None,
        ),
        constraint(
            "constraint:top-left",
            ConstraintKind::Coincident,
            vec![
                point_target("entity:top", ControlPointKind::Start),
                point_target("entity:left", ControlPointKind::End),
            ],
            None,
        ),
        constraint(
            "constraint:top-horizontal",
            ConstraintKind::Horizontal,
            vec![entity_target("entity:top")],
            None,
        ),
        constraint(
            "constraint:top-diagonal",
            ConstraintKind::Coincident,
            vec![
                point_target("entity:diagonal", ControlPointKind::Start),
                point_target("entity:top", ControlPointKind::End),
            ],
            None,
        ),
        constraint(
            "constraint:diagonal-right",
            ConstraintKind::Coincident,
            vec![
                point_target("entity:right", ControlPointKind::Start),
                point_target("entity:diagonal", ControlPointKind::End),
            ],
            None,
        ),
        constraint(
            "constraint:right-bottom",
            ConstraintKind::Coincident,
            vec![
                point_target("entity:right", ControlPointKind::End),
                point_target("entity:bottom", ControlPointKind::End),
            ],
            None,
        ),
        constraint(
            "constraint:right-vertical",
            ConstraintKind::Vertical,
            vec![entity_target("entity:right")],
            None,
        ),
    ] {
        document
            .apply_command(DocumentCommand::AddConstraint(constraint_def))
            .expect("outline constraint should be added");
    }

    document
}

fn assert_outline_constraints_satisfied(document: &ProjectDocument) {
    for status in document
        .constraints()
        .iter()
        .map(|constraint| constraint.status)
    {
        assert_ne!(status, ConstraintStatus::Conflicting);
    }
}

fn normalize_degrees(angle_deg: f64) -> f64 {
    let normalized = angle_deg.rem_euclid(360.0);
    if normalized > 180.0 {
        normalized - 360.0
    } else {
        normalized
    }
}

#[test]
fn tangent_constraint_aligns_connected_line_endpoint_and_arc_start() {
    let mut document = ProjectDocument::new("Tangent");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line",
            point(-10.0, 0.0),
            point(0.0, 0.0),
        )))
        .expect("line should be added");
    document
        .apply_command(DocumentCommand::AddEntity(arc_entity(
            "entity:arc",
            point(10.0, 0.0),
            10.0,
            std::f64::consts::PI,
            std::f64::consts::FRAC_PI_2,
        )))
        .expect("arc should be added");

    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:tangent",
            ConstraintKind::Tangent,
            vec![
                point_target("entity:line", ControlPointKind::End),
                point_target("entity:arc", ControlPointKind::Start),
            ],
            None,
        )))
        .expect("tangent constraint should be added");

    let arc = arc_by_id(&document, "entity:arc");
    assert_points_close(arc_start(arc), point(0.0, 0.0));
    assert!(vectors_point_same_direction(
        point(1.0, 0.0),
        arc_tangent_direction(arc, ControlPointKind::Start)
    ));
    assert_ne!(
        document.constraints()[0].status,
        ConstraintStatus::Conflicting
    );
}

#[test]
fn tangent_constraint_updates_arc_when_connected_line_angle_changes() {
    let mut document = ProjectDocument::new("Tangent Update");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line",
            point(-10.0, 0.0),
            point(0.0, 0.0),
        )))
        .expect("line should be added");
    document
        .apply_command(DocumentCommand::AddEntity(arc_entity(
            "entity:arc",
            point(10.0, 0.0),
            10.0,
            std::f64::consts::PI,
            std::f64::consts::FRAC_PI_2,
        )))
        .expect("arc should be added");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:tangent",
            ConstraintKind::Tangent,
            vec![
                point_target("entity:line", ControlPointKind::End),
                point_target("entity:arc", ControlPointKind::Start),
            ],
            None,
        )))
        .expect("tangent constraint should be added");

    document
        .apply_command(DocumentCommand::UpdateEntity(line_entity(
            "entity:line",
            point(0.0, -10.0),
            point(0.0, 0.0),
        )))
        .expect("line update should keep tangent");

    let arc = arc_by_id(&document, "entity:arc");
    assert_points_close(arc_start(arc), point(0.0, 0.0));
    assert!(vectors_point_same_direction(
        point(0.0, 1.0),
        arc_tangent_direction(arc, ControlPointKind::Start)
    ));
}

#[test]
fn tangent_constraint_rejects_disconnected_line_and_arc_endpoints() {
    let mut document = ProjectDocument::new("Disconnected Tangent");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line",
            point(-10.0, 0.0),
            point(0.0, 0.0),
        )))
        .expect("line should be added");
    document
        .apply_command(DocumentCommand::AddEntity(arc_entity(
            "entity:arc",
            point(30.0, 0.0),
            10.0,
            std::f64::consts::PI,
            std::f64::consts::FRAC_PI_2,
        )))
        .expect("arc should be added");

    let result = document.apply_command(DocumentCommand::AddConstraint(constraint(
        "constraint:tangent",
        ConstraintKind::Tangent,
        vec![
            point_target("entity:line", ControlPointKind::End),
            point_target("entity:arc", ControlPointKind::Start),
        ],
        None,
    )));

    assert!(matches!(result, Err(CommandError::Constraint(_))));
}

#[test]
fn tangent_constraint_accepts_endpoints_connected_by_coincident_constraint() {
    let mut document = ProjectDocument::new("Coincident Tangent");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line",
            point(-10.0, 0.0),
            point(0.0, 0.0),
        )))
        .expect("line should be added");
    document
        .apply_command(DocumentCommand::AddEntity(arc_entity(
            "entity:arc",
            point(30.0, 0.0),
            10.0,
            std::f64::consts::PI,
            std::f64::consts::FRAC_PI_2,
        )))
        .expect("arc should be added");
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:coincident",
            ConstraintKind::Coincident,
            vec![
                point_target("entity:line", ControlPointKind::End),
                point_target("entity:arc", ControlPointKind::Start),
            ],
            None,
        )))
        .expect("coincident constraint should connect endpoints");

    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:tangent",
            ConstraintKind::Tangent,
            vec![
                point_target("entity:line", ControlPointKind::End),
                point_target("entity:arc", ControlPointKind::Start),
            ],
            None,
        )))
        .expect("tangent should accept coincident-connected endpoints");

    assert!(document
        .constraints()
        .iter()
        .any(|constraint| constraint.kind == ConstraintKind::Tangent));
}

fn assert_rectangle_statuses(document: &ProjectDocument, expected: ConstraintStatus) {
    for entity_id in ["entity:bottom", "entity:right", "entity:top", "entity:left"] {
        let status = document
            .entity_constraint_statuses()
            .into_iter()
            .find(|status| status.entity_id == entity_id)
            .unwrap_or_else(|| panic!("{entity_id} status should exist"));
        assert_eq!(
            status.status, expected,
            "{entity_id} should be {expected:?}"
        );
        if expected == ConstraintStatus::FullyConstrained {
            assert_eq!(
                status.remaining_dof, 0,
                "{entity_id} should have no remaining DoF"
            );
        }
    }
}

fn arc_by_id(document: &ProjectDocument, entity_id: &str) -> kawacad_core::geometry::Arc {
    let entity = document
        .entities()
        .iter()
        .find(|entity| entity.id == entity_id)
        .unwrap_or_else(|| panic!("{entity_id} should exist"));
    arc_geometry(entity)
}

fn assert_points_close(
    actual: kawacad_core::geometry::Point2,
    expected: kawacad_core::geometry::Point2,
) {
    assert!(
        (actual.x_mm - expected.x_mm).abs() <= 0.0001
            && (actual.y_mm - expected.y_mm).abs() <= 0.0001,
        "expected {actual:?} to be close to {expected:?}"
    );
}

fn assert_output_has_stitch_start_marker(
    document: &ProjectDocument,
    stitch_start_point_id: &str,
    expected_position: kawacad_core::geometry::Point2,
) {
    let output = document
        .build_output_document_model(BuildOutputDocumentModelOptions {
            orientation: kawacad_core::print::PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: PrintableAreaMm {
                left_mm: -95.0,
                right_mm: 95.0,
                top_mm: 138.5,
                bottom_mm: -138.5,
            },
        })
        .expect("output model");
    let marker = output.output_document_model.pages[0]
        .graphics
        .iter()
        .find(|graphic| graphic.entity_id == stitch_start_point_id)
        .expect("stitch start marker output");
    assert_eq!(marker.kind, OutputGraphicKind::Point);
    match &marker.geometry {
        OutputGraphicGeometry::Point { position_mm } => {
            assert_points_close(*position_mm, expected_position);
        }
        other => panic!("expected point marker, got {other:?}"),
    }
}

fn arc_tangent_direction(
    arc: kawacad_core::geometry::Arc,
    endpoint: ControlPointKind,
) -> kawacad_core::geometry::Point2 {
    let sweep_sign = if arc.sweep_angle_rad < 0.0 { -1.0 } else { 1.0 };
    let radius_angle = match endpoint {
        ControlPointKind::Start => arc.start_angle_rad,
        ControlPointKind::End => arc.start_angle_rad + arc.sweep_angle_rad,
        ControlPointKind::Center => panic!("arc tangent requires start or end"),
    };
    point(
        (radius_angle + sweep_sign * std::f64::consts::FRAC_PI_2).cos(),
        (radius_angle + sweep_sign * std::f64::consts::FRAC_PI_2).sin(),
    )
}

fn vectors_are_parallel(
    first: kawacad_core::geometry::Point2,
    second: kawacad_core::geometry::Point2,
) -> bool {
    (first.x_mm * second.y_mm - first.y_mm * second.x_mm).abs() <= 0.0001
}

fn vectors_point_same_direction(
    first: kawacad_core::geometry::Point2,
    second: kawacad_core::geometry::Point2,
) -> bool {
    vectors_are_parallel(first, second)
        && (first.x_mm * second.x_mm + first.y_mm * second.y_mm) > 0.0
}

fn arc_geometry(entity: &kawacad_core::geometry::Entity) -> kawacad_core::geometry::Arc {
    match &entity.kind {
        EntityKind::Arc(arc) => *arc,
        other => panic!("expected arc entity, got {other:?}"),
    }
}

fn arc_start(arc: kawacad_core::geometry::Arc) -> kawacad_core::geometry::Point2 {
    kawacad_core::geometry::Point2::new(
        arc.center.x_mm + arc.start_angle_rad.cos() * arc.radius_mm,
        arc.center.y_mm + arc.start_angle_rad.sin() * arc.radius_mm,
    )
}

fn arc_end(arc: kawacad_core::geometry::Arc) -> kawacad_core::geometry::Point2 {
    let end_angle = arc.start_angle_rad + arc.sweep_angle_rad;
    kawacad_core::geometry::Point2::new(
        arc.center.x_mm + end_angle.cos() * arc.radius_mm,
        arc.center.y_mm + end_angle.sin() * arc.radius_mm,
    )
}

fn point_y(entity: &kawacad_core::geometry::Entity) -> f64 {
    match &entity.kind {
        EntityKind::Point(point) => point.y_mm,
        other => panic!("expected point entity, got {other:?}"),
    }
}

fn point_x(entity: &kawacad_core::geometry::Entity) -> f64 {
    match &entity.kind {
        EntityKind::Point(point) => point.x_mm,
        other => panic!("expected point entity, got {other:?}"),
    }
}
