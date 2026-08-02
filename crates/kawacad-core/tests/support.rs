#![allow(dead_code, unused_imports)]

use kawacad_core::command::{CommandError, DocumentCommand};
use kawacad_core::constraints::{
    Constraint, ConstraintKind, ConstraintStatus, ConstraintTarget, ConstraintValue,
    ControlPointKind,
};
use kawacad_core::document::ProjectDocument;
use kawacad_core::geometry::{Arc, Circle, Entity, EntityKind, LineSegment, Point2};
use kawacad_core::layers::{Layer, LayerKind};
use kawacad_core::measurement::{MeasurementAnnotation, MeasurementAnnotationKind};
use kawacad_core::parameters::{Parameter, ParameterUnit};
use kawacad_core::print::PrintSettings;
use kawacad_core::snapshot::CanvasViewMode;
use std::time::{SystemTime, UNIX_EPOCH};

pub fn point(x: f64, y: f64) -> Point2 {
    Point2::new(x, y)
}

pub fn line(start: Point2, end: Point2) -> LineSegment {
    LineSegment::new(start, end)
}

pub fn circle(center: Point2, radius_mm: f64) -> Circle {
    Circle { center, radius_mm }
}

pub fn arc(center: Point2, radius_mm: f64, start_angle_rad: f64, sweep_angle_rad: f64) -> Arc {
    Arc {
        center,
        radius_mm,
        start_angle_rad,
        sweep_angle_rad,
    }
}

pub fn point_entity(id: &str, point: Point2) -> Entity {
    Entity::new(id, EntityKind::Point(point))
}

pub fn line_entity(id: &str, start: Point2, end: Point2) -> Entity {
    Entity::new(id, EntityKind::LineSegment(line(start, end)))
}

pub fn center_line_entity(id: &str, start: Point2, end: Point2) -> Entity {
    Entity::new(id, EntityKind::CenterLine(line(start, end)))
}

pub fn circle_entity(id: &str, center: Point2, radius_mm: f64) -> Entity {
    Entity::new(id, EntityKind::Circle(circle(center, radius_mm)))
}

pub fn arc_entity(
    id: &str,
    center: Point2,
    radius_mm: f64,
    start_angle_rad: f64,
    sweep_angle_rad: f64,
) -> Entity {
    Entity::new(
        id,
        EntityKind::Arc(arc(center, radius_mm, start_angle_rad, sweep_angle_rad)),
    )
}

pub fn layer(id: &str, name: &str, kind: LayerKind, printable: bool) -> Layer {
    Layer::new(id, name, kind, printable)
}

pub fn parameter(id: &str, name: &str, value_mm: f64) -> Parameter {
    Parameter {
        id: id.to_owned(),
        name: name.to_owned(),
        value_mm,
        unit: ParameterUnit::Millimeter,
        memo: String::new(),
    }
}

pub fn constraint(
    id: &str,
    kind: ConstraintKind,
    targets: Vec<ConstraintTarget>,
    value: Option<ConstraintValue>,
) -> Constraint {
    Constraint {
        id: id.to_owned(),
        kind,
        targets,
        value,
        status: ConstraintStatus::Unknown,
    }
}

pub fn entity_target(entity_id: &str) -> ConstraintTarget {
    ConstraintTarget::Entity(entity_id.to_owned())
}

pub fn point_target(entity_id: &str, point: ControlPointKind) -> ConstraintTarget {
    ConstraintTarget::ControlPoint {
        entity_id: entity_id.to_owned(),
        point,
    }
}

pub fn measurement_annotation(
    id: &str,
    kind: MeasurementAnnotationKind,
    targets: Vec<ConstraintTarget>,
) -> MeasurementAnnotation {
    MeasurementAnnotation {
        id: id.to_owned(),
        kind,
        targets,
        label_offset_mm: point(0.0, 0.0),
        overall_offset_mm: point(0.0, 0.0),
        visible: true,
    }
}

pub fn document(name: &str) -> ProjectDocument {
    ProjectDocument::new(name)
}

pub fn temp_path(name: &str) -> std::path::PathBuf {
    let stamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("system time should be after unix epoch")
        .as_nanos();
    std::env::temp_dir().join(format!("kawacad-core-{stamp}-{name}"))
}

pub fn round_trip_json(document: &ProjectDocument) -> ProjectDocument {
    let json = document
        .to_json_pretty_string()
        .expect("document should serialize");
    ProjectDocument::from_json_str(&json).expect("document should deserialize")
}

pub fn assert_approx_eq(lhs: f64, rhs: f64) {
    assert!(
        (lhs - rhs).abs() <= kawacad_core::geometry::GEOMETRY_EPSILON_MM,
        "expected {lhs} to equal {rhs}"
    );
}

pub fn assert_arc(entity: &Entity, center: Point2, radius_mm: f64) {
    let EntityKind::Arc(arc) = entity.kind else {
        panic!("expected arc entity, got {:?}", entity.kind);
    };
    assert_approx_eq(arc.center.x_mm, center.x_mm);
    assert_approx_eq(arc.center.y_mm, center.y_mm);
    assert_approx_eq(arc.radius_mm, radius_mm);
}
