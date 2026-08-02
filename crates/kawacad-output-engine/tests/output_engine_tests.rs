use kawacad_core::command::DocumentCommand;
use kawacad_core::constraints::{
    Constraint, ConstraintKind, ConstraintStatus, ConstraintTarget, ConstraintValue,
};
use kawacad_core::document::ProjectDocument;
use kawacad_core::geometry::{Arc, Circle, Entity, EntityKind, LineSegment, Point2};
use kawacad_core::layers::{LayerStyle, LinePattern, Rgba};
use kawacad_core::output::{
    BuildOutputDocumentModelOptions, OutputDocumentModel, OutputGraphic, OutputGraphicGeometry,
    OutputGraphicKind, OutputPage, OutputPaperSize, OutputScale, OutputText, OutputTextKind,
    PrintableAreaMm,
};
use kawacad_core::print::PrintOrientation;
use kawacad_output_engine::{
    render_pdf, render_print, PrintRenderCommand, RenderError, StrokeKind,
};

fn point(x_mm: f64, y_mm: f64) -> Point2 {
    Point2::new(x_mm, y_mm)
}

fn line_entity(id: &str, start: Point2, end: Point2) -> Entity {
    Entity::new(id, EntityKind::LineSegment(LineSegment::new(start, end)))
}

fn center_line_entity(id: &str, start: Point2, end: Point2) -> Entity {
    Entity::new(id, EntityKind::CenterLine(LineSegment::new(start, end)))
}

fn circle_entity(id: &str, center: Point2, radius_mm: f64) -> Entity {
    Entity::new(id, EntityKind::Circle(Circle { center, radius_mm }))
}

fn arc_entity(
    id: &str,
    center: Point2,
    radius_mm: f64,
    start_angle_rad: f64,
    sweep_angle_rad: f64,
) -> Entity {
    Entity::new(
        id,
        EntityKind::Arc(Arc {
            center,
            radius_mm,
            start_angle_rad,
            sweep_angle_rad,
        }),
    )
}

fn printable_area() -> PrintableAreaMm {
    PrintableAreaMm {
        left_mm: -100.0,
        right_mm: 100.0,
        top_mm: 143.5,
        bottom_mm: -143.5,
    }
}

fn segment_length_constraint(id: &str, entity_id: &str, length_mm: f64) -> Constraint {
    Constraint {
        id: id.to_owned(),
        kind: ConstraintKind::SegmentLength,
        targets: vec![ConstraintTarget::Entity(entity_id.to_owned())],
        value: Some(ConstraintValue::FixedMm(length_mm)),
        status: ConstraintStatus::Unknown,
    }
}

fn sample_output_model(
    include_dimension_labels: bool,
    include_scale_guide: bool,
) -> kawacad_core::output::OutputDocumentModel {
    let mut doc = ProjectDocument::new("output-engine");
    doc.apply_command(DocumentCommand::AddEntity(line_entity(
        "entity:line-a",
        point(0.0, 0.0),
        point(50.0, 0.0),
    )))
    .expect("line should be added");
    doc.apply_command(DocumentCommand::AddEntity(center_line_entity(
        "entity:center-line",
        point(0.0, -20.0),
        point(0.0, 20.0),
    )))
    .expect("center line should be added");
    doc.apply_command(DocumentCommand::AddEntity(circle_entity(
        "entity:circle-a",
        point(15.0, 15.0),
        5.0,
    )))
    .expect("circle should be added");
    doc.apply_command(DocumentCommand::AddEntity(arc_entity(
        "entity:arc-a",
        point(-15.0, 10.0),
        4.0,
        0.0,
        std::f64::consts::FRAC_PI_2,
    )))
    .expect("arc should be added");
    doc.apply_command(DocumentCommand::AddConstraint(segment_length_constraint(
        "constraint:length-a",
        "entity:line-a",
        50.0,
    )))
    .expect("dimension constraint should be added");

    doc.build_output_document_model(BuildOutputDocumentModelOptions {
        orientation: PrintOrientation::Portrait,
        include_dimension_labels,
        include_scale_guide,
        rotation_deg: 0,
        printable_area_mm: printable_area(),
    })
    .expect("output document model should build")
    .output_document_model
}

fn rotated_output_model() -> kawacad_core::output::OutputDocumentModel {
    let mut doc = ProjectDocument::new("output-engine-rotated");
    doc.apply_command(DocumentCommand::AddEntity(line_entity(
        "entity:rotation-line",
        point(0.0, 0.0),
        point(50.0, 0.0),
    )))
    .expect("rotation line should be added");

    doc.build_output_document_model(BuildOutputDocumentModelOptions {
        orientation: PrintOrientation::Portrait,
        include_dimension_labels: false,
        include_scale_guide: false,
        rotation_deg: 90,
        printable_area_mm: printable_area(),
    })
    .expect("output document model should build")
    .output_document_model
}

fn rotated_arc_output_model(rotation_deg: u16) -> kawacad_core::output::OutputDocumentModel {
    let mut doc = ProjectDocument::new("output-engine-rotated-arc");
    doc.apply_command(DocumentCommand::AddEntity(arc_entity(
        "entity:arc-rotated",
        point(10.0, 20.0),
        8.0,
        0.0,
        std::f64::consts::FRAC_PI_2,
    )))
    .expect("arc should be added");

    doc.build_output_document_model(BuildOutputDocumentModelOptions {
        orientation: PrintOrientation::Portrait,
        include_dimension_labels: false,
        include_scale_guide: false,
        rotation_deg,
        printable_area_mm: printable_area(),
    })
    .expect("output document model should build")
    .output_document_model
}

fn style(
    red: f32,
    green: f32,
    blue: f32,
    stroke_width_mm: f64,
    pattern: LinePattern,
) -> LayerStyle {
    LayerStyle {
        stroke: Rgba {
            red,
            green,
            blue,
            alpha: 1.0,
        },
        stroke_width_mm,
        pattern,
    }
}

fn manual_pdf_output_model() -> OutputDocumentModel {
    OutputDocumentModel {
        paper_size: OutputPaperSize::A4,
        orientation: PrintOrientation::Portrait,
        scale: OutputScale::ActualSize,
        page_count: 1,
        pages: vec![OutputPage {
            width_mm: 210.0,
            height_mm: 297.0,
            grid_column: 0,
            grid_row: 0,
            rotation_deg: 0,
            printable_area_mm: printable_area(),
            graphics: vec![
                OutputGraphic {
                    entity_id: "entity:line".to_string(),
                    kind: OutputGraphicKind::LineSegment,
                    geometry: OutputGraphicGeometry::LineSegment {
                        start_mm: point(0.0, 0.0),
                        end_mm: point(50.0, 0.0),
                    },
                    style: style(1.0, 0.0, 0.0, 0.5, LinePattern::Dashed),
                },
                OutputGraphic {
                    entity_id: "entity:circle".to_string(),
                    kind: OutputGraphicKind::Circle,
                    geometry: OutputGraphicGeometry::Circle {
                        center_mm: point(0.0, 0.0),
                        radius_mm: 10.0,
                    },
                    style: style(0.0, 0.0, 1.0, 0.3, LinePattern::Dotted),
                },
                OutputGraphic {
                    entity_id: "entity:arc".to_string(),
                    kind: OutputGraphicKind::Arc,
                    geometry: OutputGraphicGeometry::Arc {
                        center_mm: point(-20.0, 5.0),
                        radius_mm: 8.0,
                        start_angle_rad: 0.0,
                        sweep_angle_rad: std::f64::consts::FRAC_PI_2,
                    },
                    style: style(0.0, 0.5, 0.0, 0.2, LinePattern::Construction),
                },
            ],
            texts: vec![OutputText {
                kind: OutputTextKind::DimensionLabel,
                content: r#"dim(10)\ref"#.to_string(),
                position_mm: point(10.0, 20.0),
                font_size_mm: 25.4 * 10.0 / 72.0,
            }],
            guide: None,
        }],
    }
}

fn multi_segment_arc_output_model() -> OutputDocumentModel {
    OutputDocumentModel {
        paper_size: OutputPaperSize::A4,
        orientation: PrintOrientation::Portrait,
        scale: OutputScale::ActualSize,
        page_count: 1,
        pages: vec![OutputPage {
            width_mm: 210.0,
            height_mm: 297.0,
            grid_column: 0,
            grid_row: 0,
            rotation_deg: 0,
            printable_area_mm: printable_area(),
            graphics: vec![OutputGraphic {
                entity_id: "entity:half-arc".to_string(),
                kind: OutputGraphicKind::Arc,
                geometry: OutputGraphicGeometry::Arc {
                    center_mm: point(0.0, 0.0),
                    radius_mm: 10.0,
                    start_angle_rad: 0.0,
                    sweep_angle_rad: std::f64::consts::PI,
                },
                style: style(0.0, 0.0, 0.0, 0.2, LinePattern::Solid),
            }],
            texts: Vec::new(),
            guide: None,
        }],
    }
}

fn multi_page_output_model() -> OutputDocumentModel {
    OutputDocumentModel {
        paper_size: OutputPaperSize::A4,
        orientation: PrintOrientation::Portrait,
        scale: OutputScale::ActualSize,
        page_count: 2,
        pages: vec![
            OutputPage {
                width_mm: 210.0,
                height_mm: 297.0,
                grid_column: 0,
                grid_row: 0,
                rotation_deg: 0,
                printable_area_mm: printable_area(),
                graphics: vec![OutputGraphic {
                    entity_id: "entity:page-1-crossing-line".to_string(),
                    kind: OutputGraphicKind::LineSegment,
                    geometry: OutputGraphicGeometry::LineSegment {
                        start_mm: point(80.0, 0.0),
                        end_mm: point(220.0, 0.0),
                    },
                    style: style(0.0, 0.0, 0.0, 0.2, LinePattern::Solid),
                }],
                texts: Vec::new(),
                guide: None,
            },
            OutputPage {
                width_mm: 210.0,
                height_mm: 297.0,
                grid_column: 1,
                grid_row: 0,
                rotation_deg: 0,
                printable_area_mm: printable_area(),
                graphics: vec![OutputGraphic {
                    entity_id: "entity:page-2-crossing-line".to_string(),
                    kind: OutputGraphicKind::LineSegment,
                    geometry: OutputGraphicGeometry::LineSegment {
                        start_mm: point(-220.0, 0.0),
                        end_mm: point(-80.0, 0.0),
                    },
                    style: style(0.0, 0.0, 0.0, 0.2, LinePattern::Solid),
                }],
                texts: Vec::new(),
                guide: None,
            },
        ],
    }
}

fn extract_first_pdf_stream(pdf_bytes: &[u8]) -> String {
    let pdf_text = String::from_utf8_lossy(pdf_bytes);
    let start = pdf_text
        .find("stream\n")
        .expect("pdf content stream must exist")
        + "stream\n".len();
    let end = pdf_text[start..]
        .find("\nendstream")
        .map(|offset| start + offset)
        .expect("pdf endstream marker must exist");
    pdf_text[start..end].to_string()
}

fn extract_pdf_streams(pdf_bytes: &[u8]) -> Vec<String> {
    let pdf_text = String::from_utf8_lossy(pdf_bytes);
    let mut streams = Vec::new();
    let mut offset = 0;
    while let Some(start_offset) = pdf_text[offset..].find("stream\n") {
        let start = offset + start_offset + "stream\n".len();
        let end = pdf_text[start..]
            .find("\nendstream")
            .map(|stream_end| start + stream_end)
            .expect("pdf endstream marker must exist");
        streams.push(pdf_text[start..end].to_string());
        offset = end + "\nendstream".len();
    }
    streams
}

#[test]
fn render_pdf_returns_pdf_bytes_for_valid_output_model() {
    let model = sample_output_model(true, true);

    let pdf = render_pdf(&model).expect("pdf should render");

    let text = String::from_utf8_lossy(&pdf.bytes);
    assert!(text.starts_with("%PDF-1.4"));
    assert!(text.contains("/Type /Page"));
    assert!(text.contains("/BaseFont /Helvetica"));
}

#[test]
fn render_pdf_returns_error_for_invalid_output_model() {
    let mut model = sample_output_model(false, false);
    model.page_count = 2;

    let error = render_pdf(&model).expect_err("invalid model must fail");

    assert_eq!(
        error,
        RenderError::PageCountMismatch {
            declared: 2,
            actual: 1,
        }
    );
}

#[test]
fn render_pdf_is_deterministic_for_same_input() {
    let model = sample_output_model(true, true);

    let first = render_pdf(&model).expect("first render should succeed");
    let second = render_pdf(&model).expect("second render should succeed");

    assert_eq!(first, second);
}

#[test]
fn render_pdf_contains_expected_a4_structure_object_ids_and_media_box() {
    let model = manual_pdf_output_model();

    let pdf = render_pdf(&model).expect("pdf should render");
    let text = String::from_utf8_lossy(&pdf.bytes);

    assert!(text.contains("<< /Type /Pages /Kids [3 0 R] /Count 1 >>"));
    assert!(text.contains("/MediaBox [0 0 595.276 841.890]"));
    assert!(text.contains("/Font << /F1 5 0 R >>"));
    assert!(text.contains("/Contents 4 0 R"));
    assert!(text.contains("xref\n0 6\n"));
    assert!(text.contains("trailer\n<< /Size 6 /Root 1 0 R >>"));
}

#[test]
fn render_pdf_contains_multiple_a4_pages_for_multi_page_model() {
    let model = multi_page_output_model();

    let pdf = render_pdf(&model).expect("multi page pdf should render");
    let text = String::from_utf8_lossy(&pdf.bytes);

    assert!(text.contains("<< /Type /Pages /Kids [3 0 R 5 0 R] /Count 2 >>"));
    assert_eq!(text.matches("/MediaBox [0 0 595.276 841.890]").count(), 2);
    assert!(text.contains("/Font << /F1 7 0 R >>"));
    assert!(text.contains("/Contents 4 0 R"));
    assert!(text.contains("/Contents 6 0 R"));
    assert!(text.contains("xref\n0 8\n"));
    assert!(text.contains("trailer\n<< /Size 8 /Root 1 0 R >>"));
}

#[test]
fn render_pdf_stream_contains_expected_styles_coordinates_and_escaped_text() {
    let model = manual_pdf_output_model();

    let pdf = render_pdf(&model).expect("pdf should render");
    let stream = extract_first_pdf_stream(&pdf.bytes);

    assert!(stream.contains("1.417 w 1.000 0.000 0.000 RG [6 3] 0 d"));
    assert!(stream.contains("297.638 420.945 m 439.370 420.945 l S"));
    assert!(stream.contains("0.850 w 0.000 0.000 1.000 RG [1 2] 0 d"));
    assert!(stream.contains("0.567 w 0.000 0.500 0.000 RG [3 2] 0 d"));
    assert!(stream.contains(r#"BT /F1 10.000 Tf 325.984 477.638 Td (dim\(10\)\\ref) Tj ET"#));
}

#[test]
fn render_pdf_streams_are_clipped_to_page_bounds() {
    let model = multi_page_output_model();

    let pdf = render_pdf(&model).expect("multi page pdf should render");
    let streams = extract_pdf_streams(&pdf.bytes);

    assert_eq!(streams.len(), 2);
    for stream in streams {
        assert!(
            stream.starts_with("q\n0.000 0.000 595.276 841.890 re W n"),
            "stream was:\n{stream}"
        );
        assert!(stream.ends_with("\nQ"), "stream was:\n{stream}");
    }
}

#[test]
fn render_pdf_contains_paste_up_guide_labels_for_multi_page_output() {
    let model = multi_page_output_model();

    let pdf = render_pdf(&model).expect("multi page pdf should render");
    let text = String::from_utf8_lossy(&pdf.bytes);

    assert!(text.contains("(PAGE 1/2)"));
    assert!(text.contains("(PAGE 2/2)"));
    assert!(text.contains("(JOIN TOP)"));
    assert!(text.contains("(JOIN RIGHT)"));
    assert!(text.contains("(JOIN BOTTOM)"));
    assert!(text.contains("(JOIN LEFT)"));
}

#[test]
fn render_pdf_stream_contains_expected_circle_and_arc_bezier_curves() {
    let model = manual_pdf_output_model();

    let pdf = render_pdf(&model).expect("pdf should render");
    let stream = extract_first_pdf_stream(&pdf.bytes);

    assert!(
        stream.contains("325.984 420.945 m"),
        "stream was:\n{stream}"
    );
    assert!(
        stream.contains("325.984 436.600 281.982 449.291 297.638 449.291 c"),
        "stream was:\n{stream}"
    );
    assert!(
        stream.contains("281.982 449.291 269.291 405.290 269.291 420.945 c"),
        "stream was:\n{stream}"
    );
    assert!(
        stream.contains("269.291 405.290 313.293 392.598 297.638 392.598 c"),
        "stream was:\n{stream}"
    );
    assert!(
        stream.contains("313.293 392.598 325.984 436.600 325.984 420.945 c"),
        "stream was:\n{stream}"
    );
    assert!(
        stream.contains("263.622 435.118 m"),
        "stream was:\n{stream}"
    );
    assert!(
        stream.contains("263.622 447.642 228.421 457.795 240.945 457.795 c"),
        "stream was:\n{stream}"
    );
    assert_eq!(stream.matches(" c").count(), 5);
}

#[test]
fn render_pdf_stream_preserves_second_arc_segment_for_multi_segment_sweeps() {
    let model = multi_segment_arc_output_model();

    let pdf = render_pdf(&model).expect("pdf should render");
    let stream = extract_first_pdf_stream(&pdf.bytes);

    assert!(
        stream.contains("325.984 420.945 m"),
        "stream was:\n{stream}"
    );
    assert!(
        stream.contains("325.984 436.600 281.982 449.291 297.638 449.291 c"),
        "stream was:\n{stream}"
    );
    assert!(
        stream.contains("281.982 449.291 269.291 405.290 269.291 420.945 c"),
        "stream was:\n{stream}"
    );
    assert_eq!(stream.matches(" c").count(), 2);
}

#[test]
fn render_print_returns_commands_for_output_model() {
    let model = sample_output_model(true, true);

    let print_data = render_print(&model).expect("print render should succeed");

    assert_eq!(print_data.pages.len(), 1);
    let commands = &print_data.pages[0].commands;
    assert!(commands.iter().any(|command| matches!(
        command,
        PrintRenderCommand::StrokeLine {
            kind: StrokeKind::Guide,
            ..
        }
    )));
    assert!(commands.iter().any(|command| matches!(
        command,
        PrintRenderCommand::DrawText {
            kind: OutputTextKind::DimensionLabel,
            ..
        }
    )));
    assert!(commands
        .iter()
        .any(|command| matches!(command, PrintRenderCommand::StrokeCircle { .. })));
    assert!(commands
        .iter()
        .any(|command| matches!(command, PrintRenderCommand::StrokeArc { .. })));
}

#[test]
fn render_print_includes_page_clip_and_preserves_unsplit_geometry() {
    let model = multi_page_output_model();

    let print_data = render_print(&model).expect("multi page print render should succeed");

    assert_eq!(print_data.pages.len(), 2);
    assert_eq!(
        print_data.pages[0].clip_area_mm,
        PrintableAreaMm {
            left_mm: -105.0,
            right_mm: 105.0,
            top_mm: 148.5,
            bottom_mm: -148.5,
        }
    );

    let crossing_line = print_data.pages[0]
        .commands
        .iter()
        .find_map(|command| match command {
            PrintRenderCommand::StrokeLine {
                end_mm,
                kind: StrokeKind::Graphic,
                ..
            } => Some(*end_mm),
            _ => None,
        })
        .expect("page crossing line command should exist");
    assert_eq!(crossing_line, point(220.0, 0.0));
}

#[test]
fn render_print_adds_paste_up_guides_for_multi_page_output() {
    let model = multi_page_output_model();

    let print_data = render_print(&model).expect("multi page print render should succeed");

    for (index, page) in print_data.pages.iter().enumerate() {
        let guide_line_count = page
            .commands
            .iter()
            .filter(|command| {
                matches!(
                    command,
                    PrintRenderCommand::StrokeLine {
                        kind: StrokeKind::Guide,
                        ..
                    }
                )
            })
            .count();
        assert!(guide_line_count >= 4);
        assert!(page.commands.iter().any(|command| matches!(
            command,
            PrintRenderCommand::DrawText {
                content,
                kind: OutputTextKind::GuideLabel,
                ..
            } if content == &format!("PAGE {}/2", index + 1)
        )));
        assert!(page.commands.iter().any(|command| matches!(
            command,
            PrintRenderCommand::DrawText {
                content,
                kind: OutputTextKind::GuideLabel,
                ..
            } if content == "JOIN TOP"
        )));
    }
}

#[test]
fn render_print_is_deterministic_for_same_input() {
    let model = sample_output_model(true, true);

    let first = render_print(&model).expect("first render should succeed");
    let second = render_print(&model).expect("second render should succeed");

    assert_eq!(first, second);
}

#[test]
fn render_print_keeps_arc_angle_for_unrotated_pages_and_offsets_it_for_rotated_pages() {
    let unrotated = rotated_arc_output_model(0);
    let rotated = rotated_arc_output_model(90);

    let unrotated_render = render_print(&unrotated).expect("unrotated print render should succeed");
    let rotated_render = render_print(&rotated).expect("rotated print render should succeed");

    let unrotated_arc = unrotated_render.pages[0]
        .commands
        .iter()
        .find_map(|command| match command {
            PrintRenderCommand::StrokeArc {
                center_mm,
                start_angle_rad,
                ..
            } => Some((*center_mm, *start_angle_rad)),
            _ => None,
        })
        .expect("unrotated arc command should exist");
    let rotated_arc = rotated_render.pages[0]
        .commands
        .iter()
        .find_map(|command| match command {
            PrintRenderCommand::StrokeArc {
                center_mm,
                start_angle_rad,
                ..
            } => Some((*center_mm, *start_angle_rad)),
            _ => None,
        })
        .expect("rotated arc command should exist");

    assert_eq!(unrotated_arc.0, point(10.0, 20.0));
    assert_eq!(rotated_arc.0, point(-20.0, 10.0));
    assert!((unrotated_arc.1 - 0.0).abs() < 1e-9);
    assert!((rotated_arc.1 - std::f64::consts::FRAC_PI_2).abs() < 1e-9);
}

#[test]
fn render_pdf_result_does_not_depend_on_previous_input() {
    let first_model = sample_output_model(true, false);
    let second_model = rotated_output_model();

    let baseline = render_pdf(&second_model).expect("baseline pdf should render");
    let _ = render_pdf(&first_model).expect("first pdf should render");
    let after_other_input = render_pdf(&second_model).expect("second pdf should render");

    assert_eq!(baseline, after_other_input);
}

#[test]
fn render_order_does_not_change_pdf_or_print_results() {
    let model = sample_output_model(true, true);

    let pdf_first = render_pdf(&model).expect("pdf render should succeed");
    let print_after_pdf = render_print(&model).expect("print after pdf should succeed");

    let print_first = render_print(&model).expect("print render should succeed");
    let pdf_after_print = render_pdf(&model).expect("pdf after print should succeed");

    assert_eq!(pdf_first, pdf_after_print);
    assert_eq!(print_after_pdf, print_first);
}

#[test]
fn render_pdf_rejects_zero_width_page_even_if_height_is_positive() {
    let mut model = sample_output_model(false, false);
    model.pages[0].width_mm = 0.0;
    model.pages[0].height_mm = 297.0;

    let error = render_pdf(&model).expect_err("zero width page must fail");

    assert_eq!(error, RenderError::InvalidPageSize);
}

#[test]
fn render_print_rejects_zero_height_page_even_if_width_is_positive() {
    let mut model = sample_output_model(false, false);
    model.pages[0].width_mm = 210.0;
    model.pages[0].height_mm = 0.0;

    let error = render_print(&model).expect_err("zero height page must fail");

    assert_eq!(error, RenderError::InvalidPageSize);
}

#[test]
fn same_output_document_model_can_be_reused_for_pdf_and_print() {
    let model = sample_output_model(true, true);
    let snapshot = model.clone();

    let pdf = render_pdf(&model).expect("pdf render should succeed");
    let print_data = render_print(&model).expect("print render should succeed");

    assert!(!pdf.bytes.is_empty());
    assert!(!print_data.pages.is_empty());
    assert_eq!(model, snapshot);
}
