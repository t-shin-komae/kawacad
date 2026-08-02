//! OS 非依存の Output Engine。

use kawacad_core::geometry::Point2;
use kawacad_core::layers::{LayerStyle, LinePattern, Rgba};
use kawacad_core::output::{
    OutputDocumentModel, OutputGraphicGeometry, OutputTextKind, PrintableAreaMm,
};
use kawacad_core::print::PrintOrientation;

const MM_TO_PT: f64 = 72.0 / 25.4;
const GUIDE_STYLE: LayerStyle = LayerStyle {
    stroke: Rgba::BLACK,
    stroke_width_mm: 0.2,
    pattern: LinePattern::Solid,
};
const PASTE_UP_GUIDE_STYLE: LayerStyle = LayerStyle {
    stroke: Rgba::BLACK,
    stroke_width_mm: 0.15,
    pattern: LinePattern::Construction,
};

/// PDF 出力結果。
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct PdfData {
    /// PDF バイト列。
    pub bytes: Vec<u8>,
}

/// 印刷用描画データ。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PrintRenderData {
    /// 用紙向き。
    pub orientation: PrintOrientation,
    /// ページ一覧。
    pub pages: Vec<PrintRenderPage>,
}

/// 印刷用の1ページ分データ。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PrintRenderPage {
    /// ページ幅。
    pub width_mm: f64,
    /// ページ高さ。
    pub height_mm: f64,
    /// ページ内回転。
    pub rotation_deg: u16,
    /// 印刷可能領域。
    pub printable_area_mm: PrintableAreaMm,
    /// 描画クリップ領域。
    pub clip_area_mm: PrintableAreaMm,
    /// 描画コマンド。
    pub commands: Vec<PrintRenderCommand>,
}

/// 印刷用描画コマンド。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase", tag = "kind", content = "payload")]
pub enum PrintRenderCommand {
    StrokeLine {
        start_mm: Point2,
        end_mm: Point2,
        style: LayerStyle,
        kind: StrokeKind,
    },
    StrokeCircle {
        center_mm: Point2,
        radius_mm: f64,
        style: LayerStyle,
    },
    StrokeArc {
        center_mm: Point2,
        radius_mm: f64,
        start_angle_rad: f64,
        sweep_angle_rad: f64,
        style: LayerStyle,
    },
    DrawPoint {
        center_mm: Point2,
        style: LayerStyle,
    },
    DrawText {
        position_mm: Point2,
        content: String,
        kind: OutputTextKind,
        font_size_mm: f64,
    },
}

/// 線分描画の意味種別。
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum StrokeKind {
    Graphic,
    Guide,
}

/// Output Engine の失敗。
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RenderError {
    EmptyPages,
    PageCountMismatch { declared: usize, actual: usize },
    InvalidPageSize,
    UnsupportedRotation(u16),
}

/// 中間表現から PDF data を組み立てる。
pub fn render_pdf(model: &OutputDocumentModel) -> Result<PdfData, RenderError> {
    let print_data = render_print(model)?;
    let bytes = build_pdf(model, &print_data);
    Ok(PdfData { bytes })
}

/// 中間表現から印刷用描画データを組み立てる。
pub fn render_print(model: &OutputDocumentModel) -> Result<PrintRenderData, RenderError> {
    validate_model(model)?;

    let pages = model
        .pages
        .iter()
        .enumerate()
        .map(|(page_index, page)| {
            let mut commands = Vec::new();
            for graphic in &page.graphics {
                match &graphic.geometry {
                    OutputGraphicGeometry::Point { position_mm } => {
                        commands.push(PrintRenderCommand::DrawPoint {
                            center_mm: rotate_point(*position_mm, page.rotation_deg),
                            style: graphic.style,
                        })
                    }
                    OutputGraphicGeometry::LineSegment { start_mm, end_mm }
                    | OutputGraphicGeometry::CenterLine { start_mm, end_mm } => {
                        commands.push(PrintRenderCommand::StrokeLine {
                            start_mm: rotate_point(*start_mm, page.rotation_deg),
                            end_mm: rotate_point(*end_mm, page.rotation_deg),
                            style: graphic.style,
                            kind: StrokeKind::Graphic,
                        });
                    }
                    OutputGraphicGeometry::Circle {
                        center_mm,
                        radius_mm,
                    } => {
                        commands.push(PrintRenderCommand::StrokeCircle {
                            center_mm: rotate_point(*center_mm, page.rotation_deg),
                            radius_mm: *radius_mm,
                            style: graphic.style,
                        });
                    }
                    OutputGraphicGeometry::Arc {
                        center_mm,
                        radius_mm,
                        start_angle_rad,
                        sweep_angle_rad,
                    } => {
                        let angle_offset = if page.rotation_deg == 90 {
                            std::f64::consts::FRAC_PI_2
                        } else {
                            0.0
                        };
                        commands.push(PrintRenderCommand::StrokeArc {
                            center_mm: rotate_point(*center_mm, page.rotation_deg),
                            radius_mm: *radius_mm,
                            start_angle_rad: *start_angle_rad + angle_offset,
                            sweep_angle_rad: *sweep_angle_rad,
                            style: graphic.style,
                        });
                    }
                }
            }

            for text in &page.texts {
                commands.push(PrintRenderCommand::DrawText {
                    position_mm: rotate_point(text.position_mm, page.rotation_deg),
                    content: text.content.clone(),
                    kind: text.kind,
                    font_size_mm: text.font_size_mm,
                });
            }

            if let Some(guide) = &page.guide {
                commands.push(PrintRenderCommand::StrokeLine {
                    start_mm: rotate_point(guide.start_mm, page.rotation_deg),
                    end_mm: rotate_point(guide.end_mm, page.rotation_deg),
                    style: GUIDE_STYLE,
                    kind: StrokeKind::Guide,
                });
            }

            if model.pages.len() > 1 {
                append_paste_up_guides(
                    &mut commands,
                    page.width_mm,
                    page.height_mm,
                    page_index,
                    model.pages.len(),
                );
            }

            Ok(PrintRenderPage {
                width_mm: page.width_mm,
                height_mm: page.height_mm,
                rotation_deg: page.rotation_deg,
                printable_area_mm: page.printable_area_mm,
                clip_area_mm: page_clip_area(page.width_mm, page.height_mm),
                commands,
            })
        })
        .collect::<Result<Vec<_>, RenderError>>()?;

    Ok(PrintRenderData {
        orientation: model.orientation,
        pages,
    })
}

fn validate_model(model: &OutputDocumentModel) -> Result<(), RenderError> {
    if model.pages.is_empty() {
        return Err(RenderError::EmptyPages);
    }
    if model.page_count != model.pages.len() {
        return Err(RenderError::PageCountMismatch {
            declared: model.page_count,
            actual: model.pages.len(),
        });
    }
    for page in &model.pages {
        if page.width_mm <= 0.0 || page.height_mm <= 0.0 {
            return Err(RenderError::InvalidPageSize);
        }
        if !matches!(page.rotation_deg, 0 | 90) {
            return Err(RenderError::UnsupportedRotation(page.rotation_deg));
        }
    }
    Ok(())
}

fn build_pdf(model: &OutputDocumentModel, print_data: &PrintRenderData) -> Vec<u8> {
    let mut objects = Vec::new();
    let page_count = print_data.pages.len();
    let font_object_id = 3 + page_count * 2;

    objects.push(b"<< /Type /Catalog /Pages 2 0 R >>".to_vec());

    let kids = (0..page_count)
        .map(|index| format!("{} 0 R", 3 + index * 2))
        .collect::<Vec<_>>()
        .join(" ");
    objects.push(format!("<< /Type /Pages /Kids [{kids}] /Count {page_count} >>").into_bytes());

    for (index, page) in print_data.pages.iter().enumerate() {
        let media_box = format!(
            "[0 0 {:.3} {:.3}]",
            mm_to_pt(page.width_mm),
            mm_to_pt(page.height_mm)
        );
        objects.push(
            format!(
                "<< /Type /Page /Parent 2 0 R /MediaBox {media_box} /Resources << /Font << /F1 {font_object_id} 0 R >> >> /Contents {} 0 R >>",
                4 + index * 2
            )
            .into_bytes(),
        );

        let content = pdf_content_stream(page, model.orientation);
        objects.push(
            format!(
                "<< /Length {} >>\nstream\n{content}\nendstream",
                content.len()
            )
            .into_bytes(),
        );
    }

    objects.push(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>".to_vec());

    let mut pdf = Vec::new();
    pdf.extend_from_slice(b"%PDF-1.4\n%\xFF\xFF\xFF\xFF\n");
    let mut offsets = Vec::with_capacity(objects.len());
    for (index, object) in objects.iter().enumerate() {
        offsets.push(pdf.len());
        pdf.extend_from_slice(format!("{} 0 obj\n", index + 1).as_bytes());
        pdf.extend_from_slice(object);
        pdf.extend_from_slice(b"\nendobj\n");
    }

    let xref_offset = pdf.len();
    pdf.extend_from_slice(format!("xref\n0 {}\n", objects.len() + 1).as_bytes());
    pdf.extend_from_slice(b"0000000000 65535 f \n");
    for offset in offsets {
        pdf.extend_from_slice(format!("{offset:010} 00000 n \n").as_bytes());
    }
    pdf.extend_from_slice(
        format!(
            "trailer\n<< /Size {} /Root 1 0 R >>\nstartxref\n{xref_offset}\n%%EOF\n",
            objects.len() + 1
        )
        .as_bytes(),
    );
    pdf
}

fn pdf_content_stream(page: &PrintRenderPage, _orientation: PrintOrientation) -> String {
    let mut lines = vec!["q".to_string(), pdf_clip_rectangle(page)];
    for command in &page.commands {
        match command {
            PrintRenderCommand::StrokeLine {
                start_mm,
                end_mm,
                style,
                ..
            } => {
                lines.push(pdf_stroke_style(*style));
                let start = page_to_pdf_space(page, *start_mm);
                let end = page_to_pdf_space(page, *end_mm);
                lines.push(format!(
                    "{:.3} {:.3} m {:.3} {:.3} l S",
                    start.x_mm, start.y_mm, end.x_mm, end.y_mm
                ));
            }
            PrintRenderCommand::StrokeCircle {
                center_mm,
                radius_mm,
                style,
            } => {
                lines.push(pdf_stroke_style(*style));
                lines.extend(pdf_circle_commands(page, *center_mm, *radius_mm));
            }
            PrintRenderCommand::StrokeArc {
                center_mm,
                radius_mm,
                start_angle_rad,
                sweep_angle_rad,
                style,
            } => {
                lines.push(pdf_stroke_style(*style));
                lines.extend(pdf_arc_commands(
                    page,
                    *center_mm,
                    *radius_mm,
                    *start_angle_rad,
                    *sweep_angle_rad,
                ));
            }
            PrintRenderCommand::DrawPoint { center_mm, style } => {
                lines.push(pdf_stroke_style(*style));
                lines.extend(pdf_circle_commands(page, *center_mm, 0.5));
            }
            PrintRenderCommand::DrawText {
                position_mm,
                content,
                font_size_mm,
                ..
            } => {
                let position = page_to_pdf_space(page, *position_mm);
                lines.push(format!(
                    "BT /F1 {:.3} Tf {:.3} {:.3} Td ({}) Tj ET",
                    mm_to_pt(*font_size_mm),
                    position.x_mm,
                    position.y_mm,
                    escape_pdf_text(content)
                ));
            }
        }
    }
    lines.push("Q".to_string());
    lines.join("\n")
}

fn pdf_clip_rectangle(page: &PrintRenderPage) -> String {
    let lower_left = page_to_pdf_space(
        page,
        Point2::new(page.clip_area_mm.left_mm, page.clip_area_mm.bottom_mm),
    );
    let width = mm_to_pt(page.clip_area_mm.right_mm - page.clip_area_mm.left_mm);
    let height = mm_to_pt(page.clip_area_mm.top_mm - page.clip_area_mm.bottom_mm);
    format!(
        "{:.3} {:.3} {:.3} {:.3} re W n",
        lower_left.x_mm, lower_left.y_mm, width, height
    )
}

fn pdf_stroke_style(style: LayerStyle) -> String {
    let dash = match style.pattern {
        LinePattern::Solid => "[] 0 d".to_string(),
        LinePattern::Dashed => "[6 3] 0 d".to_string(),
        LinePattern::Dotted => "[1 2] 0 d".to_string(),
        LinePattern::Construction => "[3 2] 0 d".to_string(),
    };
    format!(
        "{:.3} w {:.3} {:.3} {:.3} RG {dash}",
        mm_to_pt(style.stroke_width_mm),
        style.stroke.red,
        style.stroke.green,
        style.stroke.blue
    )
}

fn pdf_circle_commands(page: &PrintRenderPage, center_mm: Point2, radius_mm: f64) -> Vec<String> {
    pdf_arc_commands(page, center_mm, radius_mm, 0.0, std::f64::consts::TAU)
}

fn pdf_arc_commands(
    page: &PrintRenderPage,
    center_mm: Point2,
    radius_mm: f64,
    start_angle_rad: f64,
    sweep_angle_rad: f64,
) -> Vec<String> {
    let segments = arc_segments(center_mm, radius_mm, start_angle_rad, sweep_angle_rad);
    let mut commands = Vec::new();
    if let Some((start, control1, control2, end)) = segments.first() {
        let start = page_to_pdf_space(page, *start);
        commands.push(format!("{:.3} {:.3} m", start.x_mm, start.y_mm));
        let first = page_to_pdf_space(page, *control1);
        let second = page_to_pdf_space(page, *control2);
        let end = page_to_pdf_space(page, *end);
        commands.push(format!(
            "{:.3} {:.3} {:.3} {:.3} {:.3} {:.3} c",
            first.x_mm, first.y_mm, second.x_mm, second.y_mm, end.x_mm, end.y_mm
        ));
        for (start, control1, control2, end) in segments.iter().skip(1) {
            let _ = start;
            let first = page_to_pdf_space(page, *control1);
            let second = page_to_pdf_space(page, *control2);
            let end = page_to_pdf_space(page, *end);
            commands.push(format!(
                "{:.3} {:.3} {:.3} {:.3} {:.3} {:.3} c",
                first.x_mm, first.y_mm, second.x_mm, second.y_mm, end.x_mm, end.y_mm
            ));
        }
        commands.push("S".to_string());
    }
    commands
}

fn arc_segments(
    center_mm: Point2,
    radius_mm: f64,
    start_angle_rad: f64,
    sweep_angle_rad: f64,
) -> Vec<(Point2, Point2, Point2, Point2)> {
    let segment_count = (sweep_angle_rad.abs() / std::f64::consts::FRAC_PI_2)
        .ceil()
        .max(1.0) as usize;
    let step = sweep_angle_rad / segment_count as f64;
    let mut segments = Vec::with_capacity(segment_count);
    for index in 0..segment_count {
        let start = start_angle_rad + step * index as f64;
        let end = start + step;
        let alpha = (4.0 / 3.0) * ((end - start) / 4.0).tan();
        let p0 = polar_point(center_mm, radius_mm, start);
        let p3 = polar_point(center_mm, radius_mm, end);
        let p1 = Point2::new(
            p0.x_mm - alpha * radius_mm * start.sin(),
            p0.y_mm + alpha * radius_mm * start.cos(),
        );
        let p2 = Point2::new(
            p3.x_mm + alpha * radius_mm * -end.sin(),
            p3.y_mm + alpha * radius_mm * end.cos(),
        );
        segments.push((p0, p1, p2, p3));
    }
    segments
}

fn page_to_pdf_space(page: &PrintRenderPage, point_mm: Point2) -> Point2 {
    Point2::new(
        mm_to_pt(page.width_mm / 2.0 + point_mm.x_mm),
        mm_to_pt(page.height_mm / 2.0 + point_mm.y_mm),
    )
}

fn mm_to_pt(value_mm: f64) -> f64 {
    value_mm * MM_TO_PT
}

fn page_clip_area(width_mm: f64, height_mm: f64) -> PrintableAreaMm {
    PrintableAreaMm {
        left_mm: -width_mm / 2.0,
        right_mm: width_mm / 2.0,
        top_mm: height_mm / 2.0,
        bottom_mm: -height_mm / 2.0,
    }
}

fn append_paste_up_guides(
    commands: &mut Vec<PrintRenderCommand>,
    width_mm: f64,
    height_mm: f64,
    page_index: usize,
    page_count: usize,
) {
    let half_width = width_mm / 2.0;
    let half_height = height_mm / 2.0;
    let line_inset = 5.0;
    let line_margin = 14.0;

    commands.extend([
        PrintRenderCommand::StrokeLine {
            start_mm: Point2::new(-half_width + line_inset, -half_height + line_margin),
            end_mm: Point2::new(-half_width + line_inset, half_height - line_margin),
            style: PASTE_UP_GUIDE_STYLE,
            kind: StrokeKind::Guide,
        },
        PrintRenderCommand::StrokeLine {
            start_mm: Point2::new(half_width - line_inset, -half_height + line_margin),
            end_mm: Point2::new(half_width - line_inset, half_height - line_margin),
            style: PASTE_UP_GUIDE_STYLE,
            kind: StrokeKind::Guide,
        },
        PrintRenderCommand::StrokeLine {
            start_mm: Point2::new(-half_width + line_margin, half_height - line_inset),
            end_mm: Point2::new(half_width - line_margin, half_height - line_inset),
            style: PASTE_UP_GUIDE_STYLE,
            kind: StrokeKind::Guide,
        },
        PrintRenderCommand::StrokeLine {
            start_mm: Point2::new(-half_width + line_margin, -half_height + line_inset),
            end_mm: Point2::new(half_width - line_margin, -half_height + line_inset),
            style: PASTE_UP_GUIDE_STYLE,
            kind: StrokeKind::Guide,
        },
    ]);

    commands.extend([
        PrintRenderCommand::DrawText {
            position_mm: Point2::new(-half_width + 10.0, half_height - 10.0),
            content: format!("PAGE {}/{}", page_index + 1, page_count),
            kind: OutputTextKind::GuideLabel,
            font_size_mm: 3.5,
        },
        PrintRenderCommand::DrawText {
            position_mm: Point2::new(-18.0, half_height - 10.0),
            content: "JOIN TOP".to_string(),
            kind: OutputTextKind::GuideLabel,
            font_size_mm: 3.5,
        },
        PrintRenderCommand::DrawText {
            position_mm: Point2::new(half_width - 34.0, -2.0),
            content: "JOIN RIGHT".to_string(),
            kind: OutputTextKind::GuideLabel,
            font_size_mm: 3.5,
        },
        PrintRenderCommand::DrawText {
            position_mm: Point2::new(-24.0, -half_height + 10.0),
            content: "JOIN BOTTOM".to_string(),
            kind: OutputTextKind::GuideLabel,
            font_size_mm: 3.5,
        },
        PrintRenderCommand::DrawText {
            position_mm: Point2::new(-half_width + 10.0, -2.0),
            content: "JOIN LEFT".to_string(),
            kind: OutputTextKind::GuideLabel,
            font_size_mm: 3.5,
        },
    ]);
}

fn rotate_point(point: Point2, rotation_deg: u16) -> Point2 {
    if rotation_deg == 90 {
        Point2::new(-point.y_mm, point.x_mm)
    } else {
        point
    }
}

fn polar_point(center_mm: Point2, radius_mm: f64, angle_rad: f64) -> Point2 {
    Point2::new(
        center_mm.x_mm + radius_mm * angle_rad.cos(),
        center_mm.y_mm + radius_mm * angle_rad.sin(),
    )
}

fn escape_pdf_text(text: &str) -> String {
    text.replace('\\', "\\\\")
        .replace('(', "\\(")
        .replace(')', "\\)")
}
