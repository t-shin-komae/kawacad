#[path = "support.rs"]
mod support;

use kawacad_core::geometry::{Entity, EntityKind, GeometryValidationError};
use support::*;

#[test]
fn entity_validation_accepts_supported_geometry_and_rejects_invalid_shapes() {
    let valid_entities = vec![
        point_entity("entity:point", point(1.0, 2.0)),
        line_entity("entity:line", point(0.0, 0.0), point(10.0, 0.0)),
        circle_entity("entity:circle", point(5.0, 5.0), 3.0),
        arc_entity(
            "entity:arc",
            point(5.0, 5.0),
            4.0,
            0.0,
            std::f64::consts::FRAC_PI_2,
        ),
        center_line_entity("entity:center-line", point(0.0, 0.0), point(0.0, 10.0)),
    ];

    for entity in valid_entities {
        assert!(entity.validate().is_ok(), "{entity:?}");
    }

    let invalid_entities = vec![
        EntityKind::Point(point(f64::NAN, 0.0)),
        EntityKind::LineSegment(kawacad_core::geometry::LineSegment::new(
            point(0.0, 0.0),
            point(0.0, 0.0),
        )),
        EntityKind::Circle(circle(point(0.0, 0.0), 0.0)),
        EntityKind::Arc(arc(point(0.0, 0.0), 1.0, 0.0, 0.0)),
    ];

    for kind in invalid_entities {
        assert!(kind.validate().is_err(), "{kind:?}");
    }
}

#[test]
fn entity_validation_rejects_empty_ids() {
    assert!(matches!(
        Entity::new("", EntityKind::Point(point(1.0, 2.0))).validate(),
        Err(GeometryValidationError::EmptyEntityId)
    ));
}

#[test]
fn entity_layer_assignment_and_validation_are_round_trippable() {
    let entity = point_entity("entity:point", point(2.0, 3.0)).on_layer("layer:cut-line");
    assert_eq!(entity.layer_id.as_deref(), Some("layer:cut-line"));
    assert!(entity.validate().is_ok());
}
