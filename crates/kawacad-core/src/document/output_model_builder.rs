use super::*;
use crate::geometry::{Circle, Entity, LineSegment};
use crate::layers::{LayerStyle, LinePattern, Rgba};
use crate::output::{
    BuildOutputDocumentModelOptions, BuildOutputDocumentModelResult, OutputBuildError,
    OutputDocumentModel, OutputGraphic, OutputGraphicGeometry, OutputGraphicKind, OutputGuide,
    OutputPage, OutputPaperSize, OutputScale, OutputText, OutputTextKind, PrintWarning,
    PrintWarningKind,
};
use std::collections::BTreeSet;

pub(in crate::document) struct OutputModelBuilder;

const DIMENSION_LABEL_FONT_SIZE_MM: f64 = 3.5;
const GUIDE_LABEL_FONT_SIZE_MM: f64 = 3.5;

impl OutputModelBuilder {
    pub(in crate::document) fn build(
        document: &ProjectDocument,
        options: BuildOutputDocumentModelOptions,
    ) -> Result<BuildOutputDocumentModelResult, OutputBuildError> {
        let (width_mm, height_mm) = crate::print::PaperSize::A4.dimensions_mm(options.orientation);

        let page_grid = A4PageGrid::new(width_mm, height_mm);
        let mut graphics = Vec::new();
        let mut page_tiles = BTreeSet::new();
        let mut has_printable_overflow = false;
        let mut has_page_boundary_crossing = false;
        let output_entities = document.output_entities();
        for entity in &output_entities {
            if !document.entity_is_output_visible(entity) {
                continue;
            }
            let entity_bounds = output_bounds_for_entity(entity);
            let entity_tiles = page_grid.tiles_for_bounds(entity_bounds)?;
            if entity_tiles.len() > 1 {
                has_page_boundary_crossing = true;
            }
            page_tiles.extend(entity_tiles.iter().copied());
            if entity_tiles.iter().any(|tile| {
                let center = page_grid.tile_center(*tile);
                entity_bounds
                    .translated_by(-center.x_mm, -center.y_mm)
                    .rotated(options.rotation_deg)
                    .exceeds(options.printable_area_mm)
            }) {
                has_printable_overflow = true;
            }
            graphics.push(OutputGraphicWithBounds {
                graphic: Self::output_graphic_for_entity(document, entity),
                tiles: entity_tiles,
            });
        }
        for marker in Self::output_stitch_start_points(document) {
            let marker_bounds = match marker.geometry {
                OutputGraphicGeometry::Point { position_mm } => {
                    OutputBoundsMm::from_point(position_mm)
                }
                _ => continue,
            };
            let marker_tiles = page_grid.tiles_for_bounds(marker_bounds)?;
            page_tiles.extend(marker_tiles.iter().copied());
            graphics.push(OutputGraphicWithBounds {
                graphic: marker,
                tiles: marker_tiles,
            });
        }

        let mut texts = Self::output_free_texts(document);
        if options.include_dimension_labels {
            texts.extend(Self::output_dimension_texts(document));
        }
        let mut text_items = Vec::new();
        for text in texts.drain(..) {
            let text_bounds = OutputBoundsMm::from_point(text.position_mm);
            let text_tiles = page_grid.tiles_for_bounds(text_bounds)?;
            page_tiles.extend(text_tiles.iter().copied());
            text_items.push(OutputTextWithBounds {
                text,
                tiles: text_tiles,
            });
        }

        let mut warnings = Vec::new();
        if graphics.is_empty() {
            warnings.push(PrintWarning {
                kind: PrintWarningKind::EmptyDocument,
                message: "出力対象がありません。".to_string(),
            });
        } else {
            if has_page_boundary_crossing {
                warnings.push(PrintWarning {
                    kind: PrintWarningKind::PageBoundaryCrossing,
                    message: "A4ページ境界をまたぐ図形があります。".to_string(),
                });
            }
            if has_printable_overflow {
                warnings.push(PrintWarning {
                    kind: PrintWarningKind::OutOfPrintableBounds,
                    message: "印刷可能領域からはみ出しています。".to_string(),
                });
            }
        }

        let ordered_tiles = page_grid.sort_tiles(page_tiles);
        let pages = ordered_tiles
            .iter()
            .map(|tile| {
                let center = page_grid.tile_center(*tile);
                let mut page_texts: Vec<OutputText> = text_items
                    .iter()
                    .filter(|item| item.tiles.contains(tile))
                    .map(|item| Self::local_output_text(&item.text, center))
                    .collect();
                let guide = Self::output_scale_guide(&options);
                if let Some(guide) = &guide {
                    page_texts.push(OutputText {
                        kind: OutputTextKind::GuideLabel,
                        content: guide.label.clone(),
                        position_mm: guide.label_position_mm,
                        font_size_mm: GUIDE_LABEL_FONT_SIZE_MM,
                    });
                }

                OutputPage {
                    width_mm,
                    height_mm,
                    grid_column: tile.column,
                    grid_row: tile.row,
                    rotation_deg: options.rotation_deg,
                    printable_area_mm: options.printable_area_mm,
                    graphics: graphics
                        .iter()
                        .filter(|item| item.tiles.contains(tile))
                        .map(|item| Self::local_output_graphic(&item.graphic, center))
                        .collect(),
                    texts: page_texts,
                    guide,
                }
            })
            .collect::<Vec<_>>();

        Ok(BuildOutputDocumentModelResult {
            output_document_model: OutputDocumentModel {
                paper_size: OutputPaperSize::A4,
                orientation: options.orientation,
                scale: OutputScale::ActualSize,
                page_count: pages.len(),
                pages,
            },
            warnings,
        })
    }

    fn local_output_graphic(graphic: &OutputGraphic, page_center: Point2) -> OutputGraphic {
        OutputGraphic {
            entity_id: graphic.entity_id.clone(),
            kind: graphic.kind,
            geometry: Self::local_output_graphic_geometry(&graphic.geometry, page_center),
            style: graphic.style,
        }
    }

    fn local_output_graphic_geometry(
        geometry: &OutputGraphicGeometry,
        page_center: Point2,
    ) -> OutputGraphicGeometry {
        match geometry {
            OutputGraphicGeometry::Point { position_mm } => OutputGraphicGeometry::Point {
                position_mm: local_point(*position_mm, page_center),
            },
            OutputGraphicGeometry::LineSegment { start_mm, end_mm } => {
                OutputGraphicGeometry::LineSegment {
                    start_mm: local_point(*start_mm, page_center),
                    end_mm: local_point(*end_mm, page_center),
                }
            }
            OutputGraphicGeometry::Circle {
                center_mm,
                radius_mm,
            } => OutputGraphicGeometry::Circle {
                center_mm: local_point(*center_mm, page_center),
                radius_mm: *radius_mm,
            },
            OutputGraphicGeometry::Arc {
                center_mm,
                radius_mm,
                start_angle_rad,
                sweep_angle_rad,
            } => OutputGraphicGeometry::Arc {
                center_mm: local_point(*center_mm, page_center),
                radius_mm: *radius_mm,
                start_angle_rad: *start_angle_rad,
                sweep_angle_rad: *sweep_angle_rad,
            },
            OutputGraphicGeometry::CenterLine { start_mm, end_mm } => {
                OutputGraphicGeometry::CenterLine {
                    start_mm: local_point(*start_mm, page_center),
                    end_mm: local_point(*end_mm, page_center),
                }
            }
        }
    }

    fn local_output_text(text: &OutputText, page_center: Point2) -> OutputText {
        OutputText {
            kind: text.kind,
            content: text.content.clone(),
            position_mm: local_point(text.position_mm, page_center),
            font_size_mm: text.font_size_mm,
        }
    }

    fn output_graphic_for_entity(document: &ProjectDocument, entity: &Entity) -> OutputGraphic {
        OutputGraphic {
            entity_id: entity.id.clone(),
            kind: match entity.kind {
                EntityKind::Point(_) => OutputGraphicKind::Point,
                EntityKind::LineSegment(_) => OutputGraphicKind::LineSegment,
                EntityKind::Circle(_) => OutputGraphicKind::Circle,
                EntityKind::Arc(_) => OutputGraphicKind::Arc,
                EntityKind::CenterLine(_) => OutputGraphicKind::CenterLine,
            },
            geometry: match entity.kind {
                EntityKind::Point(point) => OutputGraphicGeometry::Point { position_mm: point },
                EntityKind::LineSegment(line) => OutputGraphicGeometry::LineSegment {
                    start_mm: line.start,
                    end_mm: line.end,
                },
                EntityKind::Circle(circle) => OutputGraphicGeometry::Circle {
                    center_mm: circle.center,
                    radius_mm: circle.radius_mm,
                },
                EntityKind::Arc(arc) => OutputGraphicGeometry::Arc {
                    center_mm: arc.center,
                    radius_mm: arc.radius_mm,
                    start_angle_rad: arc.start_angle_rad,
                    sweep_angle_rad: arc.sweep_angle_rad,
                },
                EntityKind::CenterLine(line) => OutputGraphicGeometry::CenterLine {
                    start_mm: line.start,
                    end_mm: line.end,
                },
            },
            style: Self::output_style_for_entity(document, entity),
        }
    }

    fn output_dimension_texts(document: &ProjectDocument) -> Vec<OutputText> {
        document
            .constraints
            .iter()
            .filter(|constraint| {
                constraint.targets.iter().all(|target| {
                    let id = match target {
                        ConstraintTarget::Entity(id)
                        | ConstraintTarget::ControlPoint { entity_id: id, .. } => id,
                    };
                    document
                        .parts
                        .iter()
                        .find(|part| {
                            part.entity_ids.contains(id) || part.derived_element_ids.contains(id)
                        })
                        .map(|part| part.printable)
                        .unwrap_or(true)
                })
            })
            .filter_map(|constraint| {
                Self::output_dimension_text_for_constraint(document, constraint)
            })
            .collect()
    }

    fn output_dimension_text_for_constraint(
        document: &ProjectDocument,
        constraint: &Constraint,
    ) -> Option<OutputText> {
        let content = match constraint.kind {
            ConstraintKind::Distance
            | ConstraintKind::HorizontalDistance
            | ConstraintKind::VerticalDistance
            | ConstraintKind::PointLineDistance
            | ConstraintKind::LineLineDistance
            | ConstraintKind::SegmentLength
            | ConstraintKind::Diameter
            | ConstraintKind::Radius => resolve_length_value_mm(
                &document.parameters,
                constraint.value.as_ref(),
                "output dimension label value",
            )
            .ok()
            .map(format_length_label),
            ConstraintKind::Angle => {
                resolve_degrees_value(constraint.value.as_ref(), "output angle label value")
                    .ok()
                    .map(format_angle_label)
            }
            _ => None,
        }?;

        Some(OutputText {
            kind: OutputTextKind::DimensionLabel,
            content,
            position_mm: Self::constraint_label_position(document, constraint)
                .unwrap_or(Point2::new(0.0, 0.0)),
            font_size_mm: DIMENSION_LABEL_FONT_SIZE_MM,
        })
    }

    fn output_free_texts(document: &ProjectDocument) -> Vec<OutputText> {
        document
            .free_texts
            .iter()
            .filter(|free_text| {
                document
                    .parts
                    .iter()
                    .find(|part| part.free_text_ids.contains(&free_text.id))
                    .map(|part| part.printable)
                    .unwrap_or(true)
            })
            .map(|free_text| OutputText {
                kind: OutputTextKind::FreeText,
                content: free_text.content.clone(),
                position_mm: free_text.position_mm,
                font_size_mm: free_text.font_size_mm,
            })
            .collect()
    }

    fn output_stitch_start_points(document: &ProjectDocument) -> Vec<OutputGraphic> {
        document
            .stitch_start_points
            .iter()
            .filter(|stitch| {
                document
                    .parts
                    .iter()
                    .find(|part| {
                        part.entity_ids.contains(&stitch.target_id)
                            || part.derived_element_ids.contains(&stitch.target_id)
                    })
                    .map(|part| part.printable)
                    .unwrap_or(true)
            })
            .filter_map(|stitch_start_point| {
                let position_mm = stitch_start_point_position(document, stitch_start_point).ok()?;
                Some(OutputGraphic {
                    entity_id: stitch_start_point.id.clone(),
                    kind: OutputGraphicKind::Point,
                    geometry: OutputGraphicGeometry::Point { position_mm },
                    style: LayerStyle {
                        stroke: Rgba::BLACK,
                        stroke_width_mm: 0.8,
                        pattern: LinePattern::Solid,
                    },
                })
            })
            .collect()
    }

    fn constraint_label_position(
        document: &ProjectDocument,
        constraint: &Constraint,
    ) -> Option<Point2> {
        let points: Vec<Point2> = constraint
            .targets
            .iter()
            .filter_map(|target| Self::constraint_target_anchor_point(document, target))
            .collect();
        if points.is_empty() {
            return None;
        }

        let (sum_x, sum_y) = points.iter().fold((0.0, 0.0), |(sum_x, sum_y), point| {
            (sum_x + point.x_mm, sum_y + point.y_mm)
        });
        Some(Point2::new(
            sum_x / points.len() as f64,
            sum_y / points.len() as f64,
        ))
    }

    fn constraint_target_anchor_point(
        document: &ProjectDocument,
        target: &ConstraintTarget,
    ) -> Option<Point2> {
        match target {
            ConstraintTarget::ControlPoint { .. } => {
                point_for_target(&document.entities, target).ok()
            }
            ConstraintTarget::Entity(_) => {
                if let Ok(point) = point_for_target(&document.entities, target) {
                    return Some(point);
                }
                if let Ok(line) = line_for_entity_target(&document.entities, target) {
                    return Some(line_midpoint(line));
                }
                if let Ok(circle) = circle_for_entity_target(&document.entities, target) {
                    return Some(circle.center);
                }
                if let Ok(arc) = arc_for_entity_target(&document.entities, target) {
                    return Some(arc.center);
                }
                None
            }
        }
    }

    fn output_scale_guide(options: &BuildOutputDocumentModelOptions) -> Option<OutputGuide> {
        if !options.include_scale_guide {
            return None;
        }

        let start = Point2::new(
            options.printable_area_mm.left_mm + 10.0,
            options.printable_area_mm.bottom_mm + 10.0,
        );
        let end = Point2::new(start.x_mm + 50.0, start.y_mm);
        Some(OutputGuide {
            start_mm: start,
            end_mm: end,
            label: "50mm".to_string(),
            label_position_mm: Point2::new((start.x_mm + end.x_mm) / 2.0, start.y_mm + 5.0),
        })
    }

    fn output_style_for_entity(document: &ProjectDocument, entity: &Entity) -> LayerStyle {
        entity
            .style_id
            .as_deref()
            .and_then(|style_id| {
                document
                    .shared_styles
                    .iter()
                    .find(|style| style.id == style_id)
            })
            .map(|style| style.style)
            .or_else(|| {
                entity
                    .layer_id
                    .as_deref()
                    .and_then(|layer_id| document.layers.iter().find(|layer| layer.id == layer_id))
                    .map(|layer| layer.style)
            })
            .or_else(|| document.layers.first().map(|layer| layer.style))
            .unwrap_or(LayerStyle {
                stroke: crate::layers::Rgba::BLACK,
                stroke_width_mm: 0.2,
                pattern: crate::layers::LinePattern::Solid,
            })
    }
}

#[derive(Debug, Clone)]
struct OutputGraphicWithBounds {
    graphic: OutputGraphic,
    tiles: Vec<A4TileIndex>,
}

#[derive(Debug, Clone)]
struct OutputTextWithBounds {
    text: OutputText,
    tiles: Vec<A4TileIndex>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
struct A4TileIndex {
    column: i32,
    row: i32,
}

struct A4PageGrid {
    page_width_mm: f64,
    page_height_mm: f64,
}

impl A4PageGrid {
    const MIN_INDEX: i32 = -2;
    const MAX_INDEX: i32 = 2;

    fn new(page_width_mm: f64, page_height_mm: f64) -> Self {
        Self {
            page_width_mm,
            page_height_mm,
        }
    }

    fn tiles_for_bounds(
        &self,
        bounds: OutputBoundsMm,
    ) -> Result<Vec<A4TileIndex>, OutputBuildError> {
        if bounds.min_x_mm < -self.page_width_mm * 2.5 - GEOMETRY_EPSILON_MM
            || bounds.max_x_mm > self.page_width_mm * 2.5 + GEOMETRY_EPSILON_MM
            || bounds.min_y_mm < -self.page_height_mm * 2.5 - GEOMETRY_EPSILON_MM
            || bounds.max_y_mm > self.page_height_mm * 2.5 + GEOMETRY_EPSILON_MM
        {
            return Err(OutputBuildError::OutOfGridBounds);
        }

        let min_column = self.tile_index_for_min(bounds.min_x_mm, self.page_width_mm);
        let max_column = self.tile_index_for_max(bounds.max_x_mm, self.page_width_mm);
        let min_row = self.tile_index_for_min(bounds.min_y_mm, self.page_height_mm);
        let max_row = self.tile_index_for_max(bounds.max_y_mm, self.page_height_mm);

        if min_column < Self::MIN_INDEX
            || max_column > Self::MAX_INDEX
            || min_row < Self::MIN_INDEX
            || max_row > Self::MAX_INDEX
        {
            return Err(OutputBuildError::OutOfGridBounds);
        }

        let mut tiles = Vec::new();
        for row in min_row..=max_row {
            for column in min_column..=max_column {
                tiles.push(A4TileIndex { column, row });
            }
        }
        Ok(tiles)
    }

    fn sort_tiles(&self, tiles: BTreeSet<A4TileIndex>) -> Vec<A4TileIndex> {
        let mut ordered = tiles.into_iter().collect::<Vec<_>>();
        ordered.sort_by_key(|tile| (-tile.row, tile.column));
        ordered
    }

    fn tile_center(&self, tile: A4TileIndex) -> Point2 {
        Point2::new(
            f64::from(tile.column) * self.page_width_mm,
            f64::from(tile.row) * self.page_height_mm,
        )
    }

    fn tile_index_for_min(&self, value_mm: f64, page_size_mm: f64) -> i32 {
        ((value_mm + page_size_mm / 2.0 + GEOMETRY_EPSILON_MM) / page_size_mm).floor() as i32
    }

    fn tile_index_for_max(&self, value_mm: f64, page_size_mm: f64) -> i32 {
        ((value_mm + page_size_mm / 2.0 - GEOMETRY_EPSILON_MM) / page_size_mm).floor() as i32
    }
}

#[derive(Debug, Clone, Copy)]
struct OutputBoundsMm {
    min_x_mm: f64,
    max_x_mm: f64,
    min_y_mm: f64,
    max_y_mm: f64,
}

impl OutputBoundsMm {
    fn from_point(point: Point2) -> Self {
        Self {
            min_x_mm: point.x_mm,
            max_x_mm: point.x_mm,
            min_y_mm: point.y_mm,
            max_y_mm: point.y_mm,
        }
    }

    fn include_point(&mut self, point: Point2) {
        self.min_x_mm = self.min_x_mm.min(point.x_mm);
        self.max_x_mm = self.max_x_mm.max(point.x_mm);
        self.min_y_mm = self.min_y_mm.min(point.y_mm);
        self.max_y_mm = self.max_y_mm.max(point.y_mm);
    }

    fn translated_by(self, x_mm: f64, y_mm: f64) -> Self {
        Self {
            min_x_mm: self.min_x_mm + x_mm,
            max_x_mm: self.max_x_mm + x_mm,
            min_y_mm: self.min_y_mm + y_mm,
            max_y_mm: self.max_y_mm + y_mm,
        }
    }

    fn rotated(self, rotation_deg: u16) -> Self {
        let mut bounds = OutputBoundsMm::from_point(rotate_point(
            Point2::new(self.min_x_mm, self.min_y_mm),
            rotation_deg,
        ));
        for point in [
            Point2::new(self.min_x_mm, self.max_y_mm),
            Point2::new(self.max_x_mm, self.min_y_mm),
            Point2::new(self.max_x_mm, self.max_y_mm),
        ] {
            bounds.include_point(rotate_point(point, rotation_deg));
        }
        bounds
    }

    fn exceeds(self, printable_area: crate::output::PrintableAreaMm) -> bool {
        self.min_x_mm < printable_area.left_mm
            || self.max_x_mm > printable_area.right_mm
            || self.min_y_mm < printable_area.bottom_mm
            || self.max_y_mm > printable_area.top_mm
    }
}

fn output_bounds_for_entity(entity: &Entity) -> OutputBoundsMm {
    match &entity.kind {
        EntityKind::Point(point) => OutputBoundsMm::from_point(*point),
        EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => {
            output_bounds_for_line_segment(*line)
        }
        EntityKind::Circle(circle) => output_bounds_for_circle(*circle),
        EntityKind::Arc(arc) => output_bounds_for_arc(arc),
    }
}

fn output_bounds_for_line_segment(line: LineSegment) -> OutputBoundsMm {
    let mut bounds = OutputBoundsMm::from_point(line.start);
    bounds.include_point(line.end);
    bounds
}

fn output_bounds_for_circle(circle: Circle) -> OutputBoundsMm {
    OutputBoundsMm {
        min_x_mm: circle.center.x_mm - circle.radius_mm,
        max_x_mm: circle.center.x_mm + circle.radius_mm,
        min_y_mm: circle.center.y_mm - circle.radius_mm,
        max_y_mm: circle.center.y_mm + circle.radius_mm,
    }
}

fn output_bounds_for_arc(arc: &crate::geometry::Arc) -> OutputBoundsMm {
    let mut bounds = OutputBoundsMm::from_point(point_on_arc(arc, arc.start_angle_rad));
    bounds.include_point(point_on_arc(arc, arc.start_angle_rad + arc.sweep_angle_rad));

    for candidate_angle in [
        0.0,
        std::f64::consts::FRAC_PI_2,
        std::f64::consts::PI,
        std::f64::consts::PI * 1.5,
    ] {
        if arc_contains_angle(arc.start_angle_rad, arc.sweep_angle_rad, candidate_angle) {
            bounds.include_point(point_on_arc(arc, candidate_angle));
        }
    }

    bounds
}

fn rotate_point(point: Point2, rotation_deg: u16) -> Point2 {
    match rotation_deg {
        0 => point,
        90 => Point2::new(-point.y_mm, point.x_mm),
        _ => point,
    }
}

fn local_point(point: Point2, page_center: Point2) -> Point2 {
    Point2::new(point.x_mm - page_center.x_mm, point.y_mm - page_center.y_mm)
}

fn arc_contains_angle(start_angle_rad: f64, sweep_angle_rad: f64, target_angle_rad: f64) -> bool {
    if sweep_angle_rad.abs() >= std::f64::consts::TAU {
        return true;
    }

    let start = normalize_positive_angle(start_angle_rad);
    let target = normalize_positive_angle(target_angle_rad);

    if sweep_angle_rad >= 0.0 {
        let delta = normalize_positive_angle(target - start);
        delta <= sweep_angle_rad + GEOMETRY_EPSILON_MM
    } else {
        let delta = normalize_positive_angle(start - target);
        delta <= (-sweep_angle_rad) + GEOMETRY_EPSILON_MM
    }
}

fn line_midpoint(line: LineSegment) -> Point2 {
    Point2::new(
        (line.start.x_mm + line.end.x_mm) / 2.0,
        (line.start.y_mm + line.end.y_mm) / 2.0,
    )
}

fn format_length_label(value_mm: f64) -> String {
    format!("{}mm", format_numeric_label(value_mm))
}

fn format_angle_label(value_degrees: f64) -> String {
    format!("{}°", format_numeric_label(value_degrees))
}

fn format_numeric_label(value: f64) -> String {
    let rounded_tenths = (value * 10.0).round() / 10.0;
    if (rounded_tenths - rounded_tenths.round()).abs() <= GEOMETRY_EPSILON_MM {
        format!("{rounded_tenths:.0}")
    } else {
        format!("{rounded_tenths:.1}")
    }
}
