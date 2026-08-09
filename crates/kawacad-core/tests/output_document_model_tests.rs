#[path = "support.rs"]
mod support;

use kawacad_core::command::DocumentCommand;
use kawacad_core::constraints::{ConstraintKind, ConstraintValue};
use kawacad_core::document::ProjectDocument;
use kawacad_core::output::{
    BuildOutputDocumentModelOptions, BuildOutputDocumentModelResult, OutputBuildError,
    OutputGraphicGeometry, OutputGraphicKind, OutputPaperSize, OutputScale, OutputTextKind,
    PrintWarningKind, PrintableAreaMm,
};
use kawacad_core::print::PrintOrientation;
use serde_json::json;
use support::{
    arc_entity, assert_approx_eq, center_line_entity, circle_entity, constraint, document,
    entity_target, line_entity, point, point_entity,
};

fn printable_area() -> PrintableAreaMm {
    PrintableAreaMm {
        left_mm: -100.0,
        right_mm: 100.0,
        top_mm: 143.5,
        bottom_mm: -143.5,
    }
}

fn build_output_document_model(
    doc: &ProjectDocument,
    options: BuildOutputDocumentModelOptions,
) -> BuildOutputDocumentModelResult {
    doc.build_output_document_model(options)
        .expect("output document model should build")
}

#[test]
fn output_graphic_geometry_serializes_variant_fields_for_the_react_wire_shape() {
    let geometry = OutputGraphicGeometry::LineSegment {
        start_mm: point(1.0, 2.0),
        end_mm: point(3.0, 4.0),
    };

    assert_eq!(
        serde_json::to_value(geometry).expect("output geometry should serialize"),
        json!({
            "kind": "lineSegment",
            "payload": {
                "startMm": { "xMm": 1.0, "yMm": 2.0 },
                "endMm": { "xMm": 3.0, "yMm": 4.0 }
            }
        })
    );
}

#[test]
fn output_document_model_portrait_is_fixed_to_a4_actual_size_single_page() {
    let mut doc = document("output-document");
    doc.apply_command(DocumentCommand::AddEntity(line_entity(
        "entity:line-a",
        point(0.0, 0.0),
        point(20.0, 0.0),
    )))
    .expect("entity should be added");

    let result = build_output_document_model(
        &doc,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: printable_area(),
        },
    );

    assert_eq!(result.output_document_model.paper_size, OutputPaperSize::A4);
    assert_eq!(
        result.output_document_model.orientation,
        PrintOrientation::Portrait
    );
    assert_eq!(result.output_document_model.scale, OutputScale::ActualSize);
    assert_eq!(result.output_document_model.page_count, 1);
    assert_eq!(result.output_document_model.pages.len(), 1);
    assert_approx_eq(result.output_document_model.pages[0].width_mm, 210.0);
    assert_approx_eq(result.output_document_model.pages[0].height_mm, 297.0);
}

#[test]
fn output_document_model_landscape_swaps_a4_dimensions_but_keeps_actual_size() {
    let mut doc = document("output-document");
    doc.apply_command(DocumentCommand::AddEntity(line_entity(
        "entity:line-a",
        point(0.0, 0.0),
        point(20.0, 0.0),
    )))
    .expect("entity should be added");

    let result = build_output_document_model(
        &doc,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Landscape,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: printable_area(),
        },
    );

    assert_eq!(result.output_document_model.paper_size, OutputPaperSize::A4);
    assert_eq!(
        result.output_document_model.orientation,
        PrintOrientation::Landscape
    );
    assert_eq!(result.output_document_model.scale, OutputScale::ActualSize);
    assert_eq!(result.output_document_model.page_count, 1);
    assert_eq!(result.output_document_model.pages.len(), 1);
    assert_approx_eq(result.output_document_model.pages[0].width_mm, 297.0);
    assert_approx_eq(result.output_document_model.pages[0].height_mm, 210.0);
}

#[test]
fn output_document_model_generates_only_intersecting_a4_tiles() {
    let mut doc = document("output-document-a4-tiles");
    doc.apply_command(DocumentCommand::AddEntity(line_entity(
        "entity:two-page-line",
        point(100.0, 0.0),
        point(220.0, 0.0),
    )))
    .expect("two-page line should be added");

    let result = build_output_document_model(
        &doc,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: printable_area(),
        },
    );

    assert_eq!(result.output_document_model.page_count, 2);
    assert_eq!(result.output_document_model.pages.len(), 2);
    assert_eq!(result.output_document_model.pages[0].grid_column, 0);
    assert_eq!(result.output_document_model.pages[0].grid_row, 0);
    assert_eq!(result.output_document_model.pages[1].grid_column, 1);
    assert_eq!(result.output_document_model.pages[1].grid_row, 0);
    let first_page_graphic = &result.output_document_model.pages[0].graphics[0];
    let second_page_graphic = &result.output_document_model.pages[1].graphics[0];
    match &first_page_graphic.geometry {
        OutputGraphicGeometry::LineSegment { start_mm, end_mm } => {
            assert_approx_eq(start_mm.x_mm, 100.0);
            assert_approx_eq(end_mm.x_mm, 220.0);
        }
        _ => panic!("first page graphic should be a line"),
    }
    match &second_page_graphic.geometry {
        OutputGraphicGeometry::LineSegment { start_mm, end_mm } => {
            assert_approx_eq(start_mm.x_mm, -110.0);
            assert_approx_eq(end_mm.x_mm, 10.0);
        }
        _ => panic!("second page graphic should be a line"),
    }
}

#[test]
fn output_document_model_orders_tiles_from_top_left_by_rows_and_omits_empty_pages() {
    let mut doc = document("output-document-a4-tile-order");
    doc.apply_command(DocumentCommand::AddEntity(point_entity(
        "entity:top-left",
        point(-210.0, 297.0),
    )))
    .expect("top-left point should be added");
    doc.apply_command(DocumentCommand::AddEntity(point_entity(
        "entity:bottom-right",
        point(210.0, -297.0),
    )))
    .expect("bottom-right point should be added");

    let result = build_output_document_model(
        &doc,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: printable_area(),
        },
    );

    assert_eq!(result.output_document_model.page_count, 2);
    assert_eq!(
        result.output_document_model.pages[0].graphics[0].entity_id,
        "entity:top-left"
    );
    assert_eq!(result.output_document_model.pages[0].grid_column, -1);
    assert_eq!(result.output_document_model.pages[0].grid_row, 1);
    assert_eq!(
        result.output_document_model.pages[1].graphics[0].entity_id,
        "entity:bottom-right"
    );
    assert_eq!(result.output_document_model.pages[1].grid_column, 1);
    assert_eq!(result.output_document_model.pages[1].grid_row, -1);
}

#[test]
fn output_document_model_uses_output_orientation_for_a4_tile_grid() {
    let mut doc = document("output-document-landscape-grid");
    doc.apply_command(DocumentCommand::AddEntity(point_entity(
        "entity:landscape-upper-page",
        point(0.0, 120.0),
    )))
    .expect("landscape upper point should be added");

    let result = build_output_document_model(
        &doc,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Landscape,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: printable_area(),
        },
    );

    match &result.output_document_model.pages[0].graphics[0].geometry {
        OutputGraphicGeometry::Point { position_mm } => {
            assert_approx_eq(position_mm.x_mm, 0.0);
            assert_approx_eq(position_mm.y_mm, -90.0);
        }
        _ => panic!("graphic should be a point"),
    }
}

#[test]
fn output_document_model_warns_when_graphic_crosses_a4_page_boundary() {
    let mut doc = document("output-document-page-boundary");
    doc.apply_command(DocumentCommand::AddEntity(line_entity(
        "entity:boundary-line",
        point(100.0, 0.0),
        point(110.0, 0.0),
    )))
    .expect("boundary line should be added");

    let result = build_output_document_model(
        &doc,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: printable_area(),
        },
    );

    assert_eq!(result.output_document_model.page_count, 2);
    assert!(result
        .warnings
        .iter()
        .any(|warning| warning.kind == PrintWarningKind::PageBoundaryCrossing));
}

#[test]
fn output_document_model_fails_when_output_target_exceeds_a4_5x5_grid() {
    let mut doc = document("output-document-out-of-grid");
    doc.apply_command(DocumentCommand::AddEntity(point_entity(
        "entity:outside-grid",
        point(526.0, 0.0),
    )))
    .expect("outside-grid point should be added");

    let error = doc
        .build_output_document_model(BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: printable_area(),
        })
        .expect_err("output target outside A4 5x5 should fail");

    assert_eq!(error, OutputBuildError::OutOfGridBounds);
}

#[test]
fn output_document_model_empty_document_returns_empty_document_warning() {
    let doc = document("output-document");

    let result = build_output_document_model(
        &doc,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: printable_area(),
        },
    );

    assert_eq!(result.output_document_model.page_count, 0);
    assert!(result.output_document_model.pages.is_empty());
    assert_eq!(result.warnings.len(), 1);
    assert_eq!(result.warnings[0].kind, PrintWarningKind::EmptyDocument);
    assert_eq!(result.warnings[0].message, "出力対象がありません。");
}

#[test]
fn output_document_model_hidden_entities_only_returns_empty_document_warning() {
    let mut doc = document("output-document");
    doc.apply_command(DocumentCommand::SetLayerVisibility {
        layer_id: "layer:cut-line".to_string(),
        visible: false,
    })
    .expect("default layer should become hidden");
    doc.apply_command(DocumentCommand::AddEntity(
        line_entity("entity:hidden-line", point(0.0, 0.0), point(20.0, 0.0))
            .on_layer("layer:cut-line"),
    ))
    .expect("hidden-layer entity should be added");

    let result = build_output_document_model(
        &doc,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: printable_area(),
        },
    );

    assert_eq!(result.output_document_model.page_count, 0);
    assert!(result.output_document_model.pages.is_empty());
    assert_eq!(result.warnings.len(), 1);
    assert_eq!(result.warnings[0].kind, PrintWarningKind::EmptyDocument);
    assert_eq!(result.warnings[0].message, "出力対象がありません。");
}

#[test]
fn output_document_model_overflowing_geometry_returns_out_of_printable_bounds_warning() {
    let mut doc = document("output-document");
    doc.apply_command(DocumentCommand::AddEntity(line_entity(
        "entity:overflow-line",
        point(0.0, 0.0),
        point(101.0, 0.0),
    )))
    .expect("overflowing entity should be added");

    let result = build_output_document_model(
        &doc,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: printable_area(),
        },
    );

    assert_eq!(result.warnings.len(), 1);
    assert_eq!(
        result.warnings[0].kind,
        PrintWarningKind::OutOfPrintableBounds
    );
    assert_eq!(
        result.warnings[0].message,
        "印刷可能領域からはみ出しています。"
    );
}

#[test]
fn output_document_model_overflow_warning_still_keeps_actual_size_single_page_output() {
    let mut doc = document("output-document");
    doc.apply_command(DocumentCommand::AddEntity(line_entity(
        "entity:overflow-line",
        point(0.0, 0.0),
        point(101.0, 0.0),
    )))
    .expect("overflowing entity should be added");

    let result = build_output_document_model(
        &doc,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: printable_area(),
        },
    );

    assert_eq!(result.output_document_model.scale, OutputScale::ActualSize);
    assert_eq!(result.output_document_model.page_count, 1);
    assert_eq!(result.output_document_model.pages.len(), 1);
    assert_eq!(result.output_document_model.pages[0].graphics.len(), 1);
    assert_eq!(
        result.output_document_model.pages[0].graphics[0].entity_id,
        "entity:overflow-line"
    );
}

#[test]
fn output_document_model_geometry_on_all_printable_edges_does_not_warn() {
    let mut doc = document("output-document");
    doc.apply_command(DocumentCommand::AddEntity(line_entity(
        "entity:horizontal-edge",
        point(-100.0, 0.0),
        point(100.0, 0.0),
    )))
    .expect("horizontal edge should be added");
    doc.apply_command(DocumentCommand::AddEntity(line_entity(
        "entity:vertical-edge",
        point(0.0, -143.5),
        point(0.0, 143.5),
    )))
    .expect("vertical edge should be added");

    let result = build_output_document_model(
        &doc,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: printable_area(),
        },
    );

    assert!(result.warnings.is_empty());
}

#[test]
fn output_document_model_warns_when_any_single_printable_edge_is_exceeded() {
    let left_overflow = {
        let mut doc = document("output-document-left-overflow");
        doc.apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:left-overflow",
            point(-101.0, 0.0),
            point(0.0, 0.0),
        )))
        .expect("left overflow line should be added");
        doc
    };
    let right_overflow = {
        let mut doc = document("output-document-right-overflow");
        doc.apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:right-overflow",
            point(0.0, 0.0),
            point(101.0, 0.0),
        )))
        .expect("right overflow line should be added");
        doc
    };
    let bottom_overflow = {
        let mut doc = document("output-document-bottom-overflow");
        doc.apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:bottom-overflow",
            point(0.0, -144.5),
            point(0.0, 0.0),
        )))
        .expect("bottom overflow line should be added");
        doc
    };
    let top_overflow = {
        let mut doc = document("output-document-top-overflow");
        doc.apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:top-overflow",
            point(0.0, 0.0),
            point(0.0, 144.5),
        )))
        .expect("top overflow line should be added");
        doc
    };

    for doc in [left_overflow, right_overflow, bottom_overflow, top_overflow] {
        let result = build_output_document_model(
            &doc,
            BuildOutputDocumentModelOptions {
                orientation: PrintOrientation::Portrait,
                include_dimension_labels: false,
                include_scale_guide: false,
                rotation_deg: 0,
                printable_area_mm: printable_area(),
            },
        );
        assert_eq!(result.warnings.len(), 1);
        assert_eq!(
            result.warnings[0].kind,
            PrintWarningKind::OutOfPrintableBounds
        );
    }
}

#[test]
fn output_document_model_circle_bounds_drive_printable_area_warning() {
    let mut doc = document("output-document-circle-bounds");
    doc.apply_command(DocumentCommand::AddEntity(circle_entity(
        "entity:circle",
        point(95.0, 0.0),
        6.0,
    )))
    .expect("circle should be added");

    let result = build_output_document_model(
        &doc,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: printable_area(),
        },
    );

    assert_eq!(result.warnings.len(), 1);
    assert_eq!(
        result.warnings[0].kind,
        PrintWarningKind::OutOfPrintableBounds
    );
}

#[test]
fn output_document_model_arc_bounds_include_cardinal_angles_for_positive_and_negative_sweeps() {
    let positive_arc_area = PrintableAreaMm {
        left_mm: -100.0,
        right_mm: 100.0,
        top_mm: 50.0,
        bottom_mm: -100.0,
    };
    let mut positive = document("output-document-positive-arc");
    positive
        .apply_command(DocumentCommand::AddEntity(arc_entity(
            "entity:upper-arc",
            point(0.0, 0.0),
            60.0,
            0.0,
            std::f64::consts::PI,
        )))
        .expect("upper arc should be added");

    let positive_result = build_output_document_model(
        &positive,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: positive_arc_area,
        },
    );
    assert_eq!(positive_result.warnings.len(), 1);
    assert_eq!(
        positive_result.warnings[0].kind,
        PrintWarningKind::OutOfPrintableBounds
    );

    let negative_arc_area = PrintableAreaMm {
        left_mm: -100.0,
        right_mm: 100.0,
        top_mm: 100.0,
        bottom_mm: -50.0,
    };
    let mut negative = document("output-document-negative-arc");
    negative
        .apply_command(DocumentCommand::AddEntity(arc_entity(
            "entity:lower-arc",
            point(0.0, 0.0),
            60.0,
            0.0,
            -std::f64::consts::PI,
        )))
        .expect("lower arc should be added");

    let negative_result = build_output_document_model(
        &negative,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: negative_arc_area,
        },
    );
    assert_eq!(negative_result.warnings.len(), 1);
    assert_eq!(
        negative_result.warnings[0].kind,
        PrintWarningKind::OutOfPrintableBounds
    );
}

#[test]
fn output_document_model_arc_bounds_are_rotated_before_warning_check() {
    let mut doc = document("output-document-rotated-arc");
    doc.apply_command(DocumentCommand::AddEntity(arc_entity(
        "entity:rotated-arc",
        point(0.0, 0.0),
        80.0,
        0.0,
        std::f64::consts::PI,
    )))
    .expect("arc should be added");

    let no_rotation = build_output_document_model(
        &doc,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: PrintableAreaMm {
                left_mm: -100.0,
                right_mm: 100.0,
                top_mm: 100.0,
                bottom_mm: -50.0,
            },
        },
    );
    let rotated = build_output_document_model(
        &doc,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 90,
            printable_area_mm: PrintableAreaMm {
                left_mm: -50.0,
                right_mm: 50.0,
                top_mm: 100.0,
                bottom_mm: -100.0,
            },
        },
    );

    assert!(no_rotation.warnings.is_empty());
    assert_eq!(rotated.warnings.len(), 1);
    assert_eq!(
        rotated.warnings[0].kind,
        PrintWarningKind::OutOfPrintableBounds
    );
}

#[test]
fn output_document_model_rotation_deg_is_reflected_in_output_page() {
    let mut doc = document("output-document");
    doc.apply_command(DocumentCommand::AddEntity(line_entity(
        "entity:rotation-line",
        point(0.0, 0.0),
        point(101.0, 0.0),
    )))
    .expect("rotation-sensitive entity should be added");

    let no_rotation = build_output_document_model(
        &doc,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: printable_area(),
        },
    );
    let rotated = build_output_document_model(
        &doc,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 90,
            printable_area_mm: printable_area(),
        },
    );

    assert_eq!(no_rotation.output_document_model.pages[0].rotation_deg, 0);
    assert_eq!(rotated.output_document_model.pages[0].rotation_deg, 90);
}

#[test]
fn output_document_model_rotation_changes_printable_bounds_judgement_without_auto_rotation() {
    let mut doc = document("output-document");
    doc.apply_command(DocumentCommand::AddEntity(line_entity(
        "entity:rotation-line",
        point(0.0, 0.0),
        point(101.0, 0.0),
    )))
    .expect("rotation-sensitive entity should be added");

    let no_rotation = build_output_document_model(
        &doc,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: printable_area(),
        },
    );
    let rotated = build_output_document_model(
        &doc,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 90,
            printable_area_mm: printable_area(),
        },
    );

    assert_eq!(no_rotation.warnings.len(), 1);
    assert_eq!(
        no_rotation.warnings[0].kind,
        PrintWarningKind::OutOfPrintableBounds
    );
    assert!(rotated.warnings.is_empty());
}

#[test]
fn output_document_model_includes_center_lines_in_output_graphics() {
    let mut doc = document("output-document");
    doc.apply_command(DocumentCommand::AddEntity(center_line_entity(
        "entity:center-line",
        point(0.0, -20.0),
        point(0.0, 20.0),
    )))
    .expect("center line should be added");

    let result = build_output_document_model(
        &doc,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: printable_area(),
        },
    );

    assert_eq!(result.output_document_model.pages[0].graphics.len(), 1);
    assert_eq!(
        result.output_document_model.pages[0].graphics[0].entity_id,
        "entity:center-line"
    );
    assert_eq!(
        result.output_document_model.pages[0].graphics[0].kind,
        OutputGraphicKind::CenterLine
    );
}

#[test]
fn output_document_model_excludes_hidden_layer_entities_and_non_entity_ui_elements() {
    let mut doc = document("output-document");
    doc.apply_command(DocumentCommand::SetLayerVisibility {
        layer_id: "layer:cut-line".to_string(),
        visible: false,
    })
    .expect("default layer should become hidden");
    doc.apply_command(DocumentCommand::AddEntity(
        line_entity("entity:hidden-line", point(-10.0, 0.0), point(10.0, 0.0))
            .on_layer("layer:cut-line"),
    ))
    .expect("hidden entity should be added");
    doc.apply_command(DocumentCommand::AddEntity(line_entity(
        "entity:visible-line",
        point(0.0, 0.0),
        point(20.0, 0.0),
    )))
    .expect("visible entity should be added");
    doc.apply_command(DocumentCommand::AddEntity(center_line_entity(
        "entity:visible-center-line",
        point(0.0, -20.0),
        point(0.0, 20.0),
    )))
    .expect("visible center line should be added");

    let result = build_output_document_model(
        &doc,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: printable_area(),
        },
    );

    let graphics = &result.output_document_model.pages[0].graphics;
    assert_eq!(graphics.len(), 2);
    assert!(graphics.iter().any(|graphic| {
        graphic.entity_id == "entity:visible-line" && graphic.kind == OutputGraphicKind::LineSegment
    }));
    assert!(graphics.iter().any(|graphic| {
        graphic.entity_id == "entity:visible-center-line"
            && graphic.kind == OutputGraphicKind::CenterLine
    }));
    assert!(graphics
        .iter()
        .all(|graphic| graphic.entity_id != "entity:hidden-line"));
}

#[test]
fn output_document_model_omits_dimension_texts_when_dimension_labels_are_disabled() {
    let mut doc = document("output-document");
    doc.apply_command(DocumentCommand::AddEntity(line_entity(
        "entity:dimension-line",
        point(0.0, 0.0),
        point(50.0, 0.0),
    )))
    .expect("line should be added");
    doc.apply_command(DocumentCommand::AddConstraint(constraint(
        "constraint:segment-length",
        ConstraintKind::SegmentLength,
        vec![entity_target("entity:dimension-line")],
        Some(ConstraintValue::FixedMm(50.0)),
    )))
    .expect("dimension constraint should be added");

    let result = build_output_document_model(
        &doc,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: printable_area(),
        },
    );

    assert!(result.output_document_model.pages[0]
        .texts
        .iter()
        .all(|text| text.kind != OutputTextKind::DimensionLabel));
}

#[test]
fn output_document_model_includes_dimension_texts_when_dimension_labels_are_enabled() {
    let mut doc = document("output-document");
    doc.apply_command(DocumentCommand::AddEntity(line_entity(
        "entity:dimension-line",
        point(0.0, 0.0),
        point(50.0, 0.0),
    )))
    .expect("line should be added");
    doc.apply_command(DocumentCommand::AddConstraint(constraint(
        "constraint:segment-length",
        ConstraintKind::SegmentLength,
        vec![entity_target("entity:dimension-line")],
        Some(ConstraintValue::FixedMm(50.0)),
    )))
    .expect("dimension constraint should be added");

    let result = build_output_document_model(
        &doc,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: true,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: printable_area(),
        },
    );

    let texts = &result.output_document_model.pages[0].texts;
    assert_eq!(texts.len(), 1);
    assert_eq!(texts[0].kind, OutputTextKind::DimensionLabel);
    assert_eq!(texts[0].content, "50mm");
    assert_approx_eq(texts[0].position_mm.x_mm, 25.0);
    assert_approx_eq(texts[0].position_mm.y_mm, 0.0);
}

#[test]
fn output_document_model_includes_angle_dimension_text_at_average_target_anchor() {
    let mut doc = document("output-document-angle-label");
    doc.apply_command(DocumentCommand::AddEntity(line_entity(
        "entity:horizontal",
        point(0.0, 0.0),
        point(10.0, 0.0),
    )))
    .expect("horizontal line should be added");
    doc.apply_command(DocumentCommand::AddEntity(line_entity(
        "entity:vertical",
        point(0.0, 0.0),
        point(0.0, 10.0),
    )))
    .expect("vertical line should be added");
    doc.apply_command(DocumentCommand::AddConstraint(constraint(
        "constraint:angle",
        ConstraintKind::Angle,
        vec![
            entity_target("entity:horizontal"),
            entity_target("entity:vertical"),
        ],
        Some(ConstraintValue::FixedDegrees(90.0)),
    )))
    .expect("angle constraint should be added");

    let result = build_output_document_model(
        &doc,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: true,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: printable_area(),
        },
    );

    let angle_label = result.output_document_model.pages[0]
        .texts
        .iter()
        .find(|text| text.kind == OutputTextKind::DimensionLabel)
        .expect("angle label should be present");
    assert_eq!(angle_label.content, "90°");
    assert_approx_eq(angle_label.position_mm.x_mm, 2.5);
    assert_approx_eq(angle_label.position_mm.y_mm, 2.5);
}

#[test]
fn output_document_model_omits_scale_guide_when_option_is_disabled() {
    let mut doc = document("output-document");
    doc.apply_command(DocumentCommand::AddEntity(line_entity(
        "entity:guide-line",
        point(0.0, 0.0),
        point(20.0, 0.0),
    )))
    .expect("guide baseline entity should be added");

    let result = build_output_document_model(
        &doc,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: printable_area(),
        },
    );

    assert!(result.output_document_model.pages[0].guide.is_none());
    assert!(result.output_document_model.pages[0]
        .texts
        .iter()
        .all(|text| text.kind != OutputTextKind::GuideLabel));
}

#[test]
fn output_document_model_includes_50mm_scale_guide_at_fixed_position_with_label() {
    let mut doc = document("output-document");
    doc.apply_command(DocumentCommand::AddEntity(line_entity(
        "entity:guide-line",
        point(0.0, 0.0),
        point(20.0, 0.0),
    )))
    .expect("guide baseline entity should be added");

    let result = build_output_document_model(
        &doc,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: true,
            rotation_deg: 0,
            printable_area_mm: printable_area(),
        },
    );

    let guide = result.output_document_model.pages[0]
        .guide
        .as_ref()
        .expect("scale guide should be present");
    assert_eq!(guide.label, "50mm");
    assert_approx_eq(guide.start_mm.x_mm, -90.0);
    assert_approx_eq(guide.start_mm.y_mm, -133.5);
    assert_approx_eq(guide.end_mm.x_mm, -40.0);
    assert_approx_eq(guide.end_mm.y_mm, -133.5);
    assert_approx_eq(guide.label_position_mm.x_mm, -65.0);
    assert_approx_eq(guide.label_position_mm.y_mm, -128.5);

    let texts = &result.output_document_model.pages[0].texts;
    assert_eq!(texts.len(), 1);
    assert_eq!(texts[0].kind, OutputTextKind::GuideLabel);
    assert_eq!(texts[0].content, "50mm");
    assert_approx_eq(texts[0].position_mm.x_mm, -65.0);
    assert_approx_eq(texts[0].position_mm.y_mm, -128.5);
}

#[test]
fn output_document_model_is_returned_even_when_overflow_warning_is_present() {
    let mut doc = document("output-document");
    doc.apply_command(DocumentCommand::AddEntity(line_entity(
        "entity:overflow-line",
        point(0.0, 0.0),
        point(101.0, 0.0),
    )))
    .expect("overflowing entity should be added");

    let result = build_output_document_model(
        &doc,
        BuildOutputDocumentModelOptions {
            orientation: PrintOrientation::Portrait,
            include_dimension_labels: false,
            include_scale_guide: false,
            rotation_deg: 0,
            printable_area_mm: printable_area(),
        },
    );

    assert_eq!(result.warnings.len(), 1);
    assert_eq!(
        result.warnings[0].kind,
        PrintWarningKind::OutOfPrintableBounds
    );
    assert_eq!(result.output_document_model.page_count, 1);
    assert_eq!(result.output_document_model.pages.len(), 1);
    assert_eq!(result.output_document_model.pages[0].graphics.len(), 1);
    assert_eq!(
        result.output_document_model.pages[0].graphics[0].entity_id,
        "entity:overflow-line"
    );
}
