#[path = "support.rs"]
mod support;

use kawacad_core::command::{
    DocumentCommand, EntityGesture, EntityMetric, GestureAxis, GestureSnapConstraint,
    SelectionReference,
};
use kawacad_core::constraints::{
    ConstraintKind, ConstraintTarget, ConstraintValue, ControlPointKind,
};
use kawacad_core::derived::{
    DerivedElement, DerivedElementKind, Fillet, OffsetCurve, OffsetDirection,
};
use kawacad_core::document::{DerivedElementPreflightKind, OffsetSourceScope, ProjectDocument};
use kawacad_core::geometry::EntityKind;
use kawacad_core::measurement::MeasurementAnnotationKind;
use kawacad_core::round_holes::{RoundHole, RoundHoleKind};
use kawacad_core::snapshot::CanvasViewMode;
use support::*;

#[test]
fn gesture_creation_builds_canonical_geometry_and_constraints_atomically() {
    let mut document = ProjectDocument::new("gesture");
    document
        .apply_command(DocumentCommand::AddEntity(point_entity(
            "entity:snap",
            point(12.0, 0.0),
        )))
        .unwrap();

    document
        .apply_command(DocumentCommand::CreateEntityFromGesture {
            id: "entity:line".into(),
            layer_id: None,
            style_id: None,
            gesture: EntityGesture::Line {
                start: point(0.0, 0.0),
                end: point(12.0, 5.0),
                center_line: false,
                axis: Some(GestureAxis::Horizontal),
            },
            start_snap: None,
            end_snap: Some(GestureSnapConstraint {
                constraint_id: "constraint:end-snap".into(),
                target: ConstraintTarget::Entity("entity:snap".into()),
            }),
            axis_constraint_id: Some("constraint:horizontal".into()),
        })
        .unwrap();

    let EntityKind::LineSegment(line) = document.entity("entity:line").unwrap().kind else {
        panic!("expected line")
    };
    assert_eq!(line.start, point(0.0, 0.0));
    assert_eq!(line.end, point(12.0, 0.0));
    assert_eq!(document.constraints().len(), 2);
    assert!(document
        .constraints()
        .iter()
        .any(|constraint| constraint.kind == ConstraintKind::Coincident));
    assert!(document
        .constraints()
        .iter()
        .any(|constraint| constraint.kind == ConstraintKind::Horizontal));

    document
        .undo()
        .expect("gesture should undo as one mutation");
    assert!(document.entity("entity:line").is_none());
    assert!(document.constraints().is_empty());
    assert!(document.entity("entity:snap").is_some());
}

#[test]
fn arc_gesture_resolves_radius_start_angle_and_large_sweep_in_core() {
    let mut document = ProjectDocument::new("arc gesture");
    let reference = 200.0_f64.to_radians();
    let end_angle = reference;
    document
        .apply_command(DocumentCommand::CreateEntityFromGesture {
            id: "entity:arc".into(),
            layer_id: None,
            style_id: None,
            gesture: EntityGesture::Arc {
                center: point(5.0, 5.0),
                start: point(15.0, 5.0),
                end: point(5.0 + 10.0 * end_angle.cos(), 5.0 + 10.0 * end_angle.sin()),
                sweep_reference_rad: Some(reference),
            },
            start_snap: None,
            end_snap: None,
            axis_constraint_id: None,
        })
        .unwrap();

    let EntityKind::Arc(arc) = document.entity("entity:arc").unwrap().kind else {
        panic!("expected arc")
    };
    assert_approx_eq(arc.radius_mm, 10.0);
    assert_approx_eq(arc.start_angle_rad, 0.0);
    assert_approx_eq(arc.sweep_angle_rad, reference);
}

#[test]
fn semantic_property_edits_preserve_owned_object_structure() {
    let mut document = ProjectDocument::new("property edits");
    for entity in [
        line_entity("entity:first", point(0.0, 0.0), point(10.0, 0.0)),
        line_entity("entity:second", point(10.0, 0.0), point(10.0, 10.0)),
        circle_entity("entity:hole", point(30.0, 40.0), 2.0),
    ] {
        document
            .apply_command(DocumentCommand::AddEntity(entity))
            .unwrap();
    }
    document
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:offset",
                None,
                OffsetCurve {
                    source_entity_ids: vec!["entity:first".into()],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::FixedMm(2.0),
                    direction: OffsetDirection::Left,
                },
            ),
        ))
        .unwrap();
    document
        .apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
            "derived:fillet",
            None,
            Fillet {
                source_entity_ids: vec!["entity:first".into(), "entity:second".into()],
                radius: ConstraintValue::FixedMm(1.0),
                closed: false,
            },
        )))
        .unwrap();
    document
        .apply_command(DocumentCommand::AddRoundHole(RoundHole::new(
            "round-hole:a",
            "entity:hole",
            RoundHoleKind::Rivet,
        )))
        .unwrap();

    document
        .apply_command(DocumentCommand::SetDerivedDistance {
            derived_element_id: "derived:offset".into(),
            value: ConstraintValue::FixedMm(4.0),
        })
        .unwrap();
    document
        .apply_command(DocumentCommand::SetDerivedDirection {
            derived_element_id: "derived:offset".into(),
            direction: OffsetDirection::Right,
        })
        .unwrap();
    document
        .apply_command(DocumentCommand::SetDerivedRadius {
            derived_element_id: "derived:fillet".into(),
            value: ConstraintValue::FixedMm(3.0),
        })
        .unwrap();
    document
        .apply_command(DocumentCommand::SetRoundHoleDiameter {
            round_hole_id: "round-hole:a".into(),
            diameter_mm: 12.0,
        })
        .unwrap();

    let offset = document.derived_element("derived:offset").unwrap();
    let kawacad_core::derived::DerivedElementKind::OffsetCurve(offset_kind) = &offset.kind else {
        panic!("expected offset")
    };
    assert_eq!(offset_kind.source_entity_ids, ["entity:first"]);
    assert_eq!(offset_kind.distance, ConstraintValue::FixedMm(4.0));
    assert_eq!(offset_kind.direction, OffsetDirection::Right);

    let fillet = document.derived_element("derived:fillet").unwrap();
    let kawacad_core::derived::DerivedElementKind::Fillet(fillet_kind) = &fillet.kind else {
        panic!("expected fillet")
    };
    assert_eq!(
        fillet_kind.source_entity_ids,
        ["entity:first", "entity:second"]
    );
    assert_eq!(fillet_kind.radius, ConstraintValue::FixedMm(3.0));

    let EntityKind::Circle(hole) = document.entity("entity:hole").unwrap().kind else {
        panic!("expected hole circle")
    };
    assert_eq!(hole.center, point(30.0, 40.0));
    assert_eq!(hole.radius_mm, 6.0);
    assert_eq!(document.round_holes()[0].kind, RoundHoleKind::Rivet);
}

#[test]
fn semantic_round_hole_commands_create_and_edit_owned_geometry_atomically() {
    let mut document = ProjectDocument::new("round hole intent");

    document
        .apply_command(DocumentCommand::CreateRoundHole {
            id: "round-hole:a".into(),
            entity_id: "entity:round-hole:a".into(),
            center: point(30.0, 40.0),
            diameter_mm: 12.0,
            round_hole_kind: RoundHoleKind::Rivet,
            layer_id: None,
            style_id: None,
        })
        .unwrap();

    let EntityKind::Circle(hole) = document.entity("entity:round-hole:a").unwrap().kind else {
        panic!("expected hole circle")
    };
    assert_eq!(hole.center, point(30.0, 40.0));
    assert_eq!(hole.radius_mm, 6.0);
    assert_eq!(document.round_holes()[0].kind, RoundHoleKind::Rivet);

    document
        .apply_command(DocumentCommand::SetRoundHoleKind {
            round_hole_id: "round-hole:a".into(),
            kind: RoundHoleKind::Decorative,
        })
        .unwrap();
    assert_eq!(document.round_holes()[0].kind, RoundHoleKind::Decorative);

    document.undo().unwrap();
    assert_eq!(document.round_holes()[0].kind, RoundHoleKind::Rivet);
    document.undo().unwrap();
    assert!(document.round_holes().is_empty());
    assert!(document.entity("entity:round-hole:a").is_none());
}

#[test]
fn semantic_entity_metrics_update_canonical_geometry() {
    let mut document = ProjectDocument::new("metrics");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line",
            point(1.0, 2.0),
            point(4.0, 6.0),
        )))
        .unwrap();
    document
        .apply_command(DocumentCommand::AddEntity(circle_entity(
            "entity:circle",
            point(5.0, 6.0),
            2.0,
        )))
        .unwrap();
    document
        .apply_command(DocumentCommand::AddEntity(arc_entity(
            "entity:arc",
            point(0.0, 0.0),
            3.0,
            0.0,
            1.0,
        )))
        .unwrap();

    document
        .apply_command(DocumentCommand::SetEntityMetric {
            entity_id: "entity:line".into(),
            metric: EntityMetric::SegmentLength { value_mm: 10.0 },
        })
        .unwrap();
    document
        .apply_command(DocumentCommand::SetEntityMetric {
            entity_id: "entity:circle".into(),
            metric: EntityMetric::CircleRadius { value_mm: 8.0 },
        })
        .unwrap();
    document
        .apply_command(DocumentCommand::SetEntityMetric {
            entity_id: "entity:arc".into(),
            metric: EntityMetric::Arc {
                radius_mm: 7.0,
                start_angle_rad: 0.25,
                sweep_angle_rad: -4.0,
            },
        })
        .unwrap();

    let EntityKind::LineSegment(line) = document.entity("entity:line").unwrap().kind else {
        panic!("expected line")
    };
    assert_approx_eq(
        (line.end.x_mm - line.start.x_mm).hypot(line.end.y_mm - line.start.y_mm),
        10.0,
    );
    let EntityKind::Circle(circle) = document.entity("entity:circle").unwrap().kind else {
        panic!("expected circle")
    };
    assert_eq!(circle.radius_mm, 8.0);
    let EntityKind::Arc(arc) = document.entity("entity:arc").unwrap().kind else {
        panic!("expected arc")
    };
    assert_eq!(
        (arc.radius_mm, arc.start_angle_rad, arc.sweep_angle_rad),
        (7.0, 0.25, -4.0)
    );
}

#[test]
fn move_intent_expands_two_source_fillet_inside_core() {
    let mut document = ProjectDocument::new("move fillet");
    for entity in [
        line_entity("entity:first", point(0.0, 0.0), point(10.0, 0.0)),
        line_entity("entity:second", point(10.0, 0.0), point(10.0, 10.0)),
    ] {
        document
            .apply_command(DocumentCommand::AddEntity(entity))
            .unwrap();
    }
    document
        .apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
            "derived:fillet",
            None,
            Fillet {
                source_entity_ids: vec!["entity:first".into(), "entity:second".into()],
                radius: ConstraintValue::FixedMm(2.0),
                closed: false,
            },
        )))
        .unwrap();

    document
        .apply_command(DocumentCommand::MoveEntities {
            entity_ids: vec!["entity:first".into()],
            delta: point(5.0, 7.0),
            allow_single_line_stretch: true,
        })
        .unwrap();

    let EntityKind::LineSegment(first) = document.entity("entity:first").unwrap().kind else {
        panic!("expected first line")
    };
    let EntityKind::LineSegment(second) = document.entity("entity:second").unwrap().kind else {
        panic!("expected second line")
    };
    assert_eq!(first.start, point(5.0, 7.0));
    assert_eq!(second.start, point(15.0, 7.0));
}

#[test]
fn derived_preflight_returns_offset_scopes_and_rejects_disconnected_sources() {
    let mut document = ProjectDocument::new("preflight");
    for entity in [
        line_entity("entity:bottom", point(0.0, 0.0), point(20.0, 0.0)),
        line_entity("entity:right", point(20.0, 0.0), point(20.0, 10.0)),
        line_entity("entity:top", point(20.0, 10.0), point(0.0, 10.0)),
        line_entity("entity:left", point(0.0, 10.0), point(0.0, 0.0)),
        line_entity("entity:away", point(50.0, 0.0), point(60.0, 0.0)),
    ] {
        document
            .apply_command(DocumentCommand::AddEntity(entity))
            .unwrap();
    }

    let result = document
        .preflight_derived_element(
            DerivedElementPreflightKind::OffsetCurve,
            Some("entity:bottom".into()),
            vec![],
            Some(point(10.0, 5.0)),
        )
        .unwrap();
    assert_eq!(
        result.offset_options[0].scope,
        OffsetSourceScope::ClosedContour
    );
    assert_eq!(result.offset_options[0].direction, OffsetDirection::Inward);
    assert_eq!(result.offset_options[0].source_entity_ids.len(), 4);

    let selected_range = document
        .preflight_derived_element(
            DerivedElementPreflightKind::OffsetCurve,
            Some("entity:bottom".into()),
            vec!["entity:bottom".into(), "entity:right".into()],
            Some(point(10.0, 5.0)),
        )
        .unwrap();
    assert_eq!(
        selected_range.offset_options[0].scope,
        OffsetSourceScope::SelectedRange
    );
    assert_eq!(
        selected_range.offset_options[0].source_entity_ids,
        ["entity:bottom", "entity:right"]
    );

    let reversed_selected_range = document
        .preflight_derived_element(
            DerivedElementPreflightKind::OffsetCurve,
            Some("entity:bottom".into()),
            vec!["entity:right".into(), "entity:bottom".into()],
            Some(point(10.0, 5.0)),
        )
        .unwrap();
    assert_eq!(
        reversed_selected_range.offset_options[0].direction,
        OffsetDirection::Right
    );

    let offset_error = document
        .preflight_derived_element(
            DerivedElementPreflightKind::OffsetCurve,
            Some("entity:bottom".into()),
            vec!["entity:bottom".into(), "entity:away".into()],
            Some(point(10.0, 5.0)),
        )
        .unwrap_err();
    assert!(matches!(
        offset_error,
        kawacad_core::command::CommandError::InvalidValue {
            field: "offset source",
            reason: "multiple offset sources must form one continuous path"
        }
    ));

    let error = document
        .preflight_derived_element(
            DerivedElementPreflightKind::Fillet,
            None,
            vec!["entity:bottom".into(), "entity:away".into()],
            None,
        )
        .unwrap_err();
    assert!(matches!(
        error,
        kawacad_core::command::CommandError::InvalidValue {
            field: "derived element preflight",
            reason: "fillet source entities must form one connected path"
        }
    ));
}

#[test]
fn fillet_preflight_canonicalizes_open_path_ids_before_creation() {
    let mut document = ProjectDocument::new("canonical fillet preflight");
    for entity in [
        line_entity("entity:z", point(0.0, 0.0), point(10.0, 0.0)),
        line_entity("entity:a", point(10.0, 0.0), point(10.0, 10.0)),
        line_entity("entity:m", point(10.0, 10.0), point(20.0, 10.0)),
    ] {
        document
            .apply_command(DocumentCommand::AddEntity(entity))
            .unwrap();
    }

    let first = document
        .preflight_derived_element(
            DerivedElementPreflightKind::Fillet,
            None,
            vec!["entity:z".into(), "entity:m".into(), "entity:a".into()],
            None,
        )
        .unwrap();
    let second = document
        .preflight_derived_element(
            DerivedElementPreflightKind::Fillet,
            None,
            vec!["entity:a".into(), "entity:z".into(), "entity:m".into()],
            None,
        )
        .unwrap();

    assert_eq!(
        first.source_entity_ids,
        ["entity:m", "entity:a", "entity:z"]
    );
    assert_eq!(first.source_entity_ids, second.source_entity_ids);
    assert!(!first.closed);

    document
        .apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
            "derived:canonical-fillet",
            None,
            Fillet {
                source_entity_ids: first.source_entity_ids,
                radius: ConstraintValue::FixedMm(2.0),
                closed: first.closed,
            },
        )))
        .unwrap();
    let DerivedElementKind::Fillet(created) = &document
        .derived_element("derived:canonical-fillet")
        .unwrap()
        .kind
    else {
        panic!("expected fillet");
    };
    assert_eq!(
        created.source_entity_ids,
        ["entity:m", "entity:a", "entity:z"]
    );
}

#[test]
fn fillet_preflight_accepts_connected_line_arc_in_either_selection_order() {
    let mut document = ProjectDocument::new("line arc fillet preflight");
    for entity in [
        line_entity("entity:line", point(0.0, 0.0), point(10.0, 0.0)),
        arc_entity(
            "entity:arc",
            point(20.0, 0.0),
            10.0,
            std::f64::consts::PI,
            -std::f64::consts::FRAC_PI_2,
        ),
    ] {
        document
            .apply_command(DocumentCommand::AddEntity(entity))
            .unwrap();
    }

    let forward = document
        .preflight_derived_element(
            DerivedElementPreflightKind::Fillet,
            None,
            vec!["entity:line".into(), "entity:arc".into()],
            None,
        )
        .unwrap();
    let reverse = document
        .preflight_derived_element(
            DerivedElementPreflightKind::Fillet,
            None,
            vec!["entity:arc".into(), "entity:line".into()],
            None,
        )
        .unwrap();

    assert_eq!(forward.source_entity_ids, reverse.source_entity_ids);
    assert_eq!(forward.source_entity_ids.len(), 2);
    assert!(!forward.closed);

    document
        .apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
            "derived:line-arc",
            None,
            Fillet {
                source_entity_ids: forward.source_entity_ids,
                radius: ConstraintValue::FixedMm(2.0),
                closed: forward.closed,
            },
        )))
        .unwrap();
    let resolved = document
        .drawing_snapshot(CanvasViewMode::EditDisplay)
        .entities
        .into_iter()
        .filter(|entity| entity.id.starts_with("derived:line-arc:resolved:"))
        .collect::<Vec<_>>();
    assert_eq!(resolved.len(), 3);
    assert!(matches!(resolved[0].kind, EntityKind::Arc(_)));
    assert!(matches!(resolved[1].kind, EntityKind::Arc(_)));
    assert!(matches!(resolved[2].kind, EntityKind::LineSegment(_)));
}

#[test]
fn fillet_preflight_canonicalizes_closed_contours_independently_of_selection_order() {
    let mut document = ProjectDocument::new("canonical closed fillet preflight");
    for entity in [
        line_entity("entity:z", point(0.0, 0.0), point(20.0, 0.0)),
        line_entity("entity:a", point(20.0, 0.0), point(20.0, 10.0)),
        line_entity("entity:m", point(20.0, 10.0), point(0.0, 10.0)),
        line_entity("entity:b", point(0.0, 10.0), point(0.0, 0.0)),
    ] {
        document
            .apply_command(DocumentCommand::AddEntity(entity))
            .unwrap();
    }

    let first = document
        .preflight_derived_element(
            DerivedElementPreflightKind::Fillet,
            None,
            vec![
                "entity:z".into(),
                "entity:m".into(),
                "entity:a".into(),
                "entity:b".into(),
            ],
            None,
        )
        .unwrap();
    let second = document
        .preflight_derived_element(
            DerivedElementPreflightKind::Fillet,
            None,
            vec![
                "entity:b".into(),
                "entity:a".into(),
                "entity:z".into(),
                "entity:m".into(),
            ],
            None,
        )
        .unwrap();

    assert!(first.closed);
    assert_eq!(first.source_entity_ids, second.source_entity_ids);
    assert_eq!(
        first.source_entity_ids.first(),
        Some(&"entity:a".to_owned())
    );
}

#[test]
fn fillet_preflight_creates_a_five_mm_keyholder_fillet_from_shuffled_uuid_sources() {
    let ids = [
        "550e8400-e29b-41d4-a716-446655440000",
        "c56a4180-65aa-42ec-a945-5fd21dec0538",
        "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
        "7f3c8b1e-2d65-4eaa-9c91-3d762db5a901",
        "123e4567-e89b-12d3-a456-426614174000",
        "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11",
        "f47ac10b-58cc-4372-a567-0e02b2c3d479",
    ];
    let points = [
        point(0.0, 0.0),
        point(30.0, 0.0),
        point(30.0, 30.0),
        point(60.0, 30.0),
        point(60.0, 60.0),
        point(90.0, 60.0),
        point(90.0, 90.0),
        point(120.0, 90.0),
    ];
    let mut document = ProjectDocument::new("seven line keyholder");
    for index in 0..ids.len() {
        document
            .apply_command(DocumentCommand::AddEntity(line_entity(
                ids[index],
                points[index],
                points[index + 1],
            )))
            .unwrap();
    }

    let preflight = document
        .preflight_derived_element(
            DerivedElementPreflightKind::Fillet,
            None,
            vec![
                ids[4].into(),
                ids[1].into(),
                ids[6].into(),
                ids[0].into(),
                ids[3].into(),
                ids[5].into(),
                ids[2].into(),
            ],
            None,
        )
        .expect("seven connected UUID lines should preflight");
    assert_eq!(preflight.source_entity_ids.len(), 7);
    assert!(!preflight.closed);

    document
        .apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
            "derived:keyholder-fillet",
            None,
            Fillet {
                source_entity_ids: preflight.source_entity_ids.clone(),
                radius: ConstraintValue::FixedMm(5.0),
                closed: preflight.closed,
            },
        )))
        .expect("five millimeter fillet should be created");
    let created_sources = match &document
        .derived_element("derived:keyholder-fillet")
        .expect("created fillet")
        .kind
    {
        DerivedElementKind::Fillet(fillet) => fillet.source_entity_ids.clone(),
        other => panic!("expected fillet, got {other:?}"),
    };
    assert_eq!(created_sources, preflight.source_entity_ids);
    assert_eq!(
        document
            .drawing_snapshot(CanvasViewMode::EditDisplay)
            .entities
            .iter()
            .filter(|entity| entity.id.starts_with("derived:keyholder-fillet:resolved:"))
            .count(),
        13
    );

    document
        .undo()
        .expect("fillet creation should undo atomically");
    assert!(document
        .derived_element("derived:keyholder-fillet")
        .is_none());
    document
        .redo()
        .expect("fillet creation should redo atomically");
    let reloaded = round_trip_json(&document);
    let reloaded_sources = match &reloaded
        .derived_element("derived:keyholder-fillet")
        .expect("round-tripped fillet")
        .kind
    {
        DerivedElementKind::Fillet(fillet) => fillet.source_entity_ids.clone(),
        other => panic!("expected fillet, got {other:?}"),
    };
    assert_eq!(reloaded_sources, created_sources);
}

#[test]
fn offset_preflight_preserves_only_the_selected_range_of_an_open_fillet() {
    let mut document = ProjectDocument::new("partial fillet offset");
    for entity in [
        line_entity("entity:bottom", point(0.0, 0.0), point(20.0, 0.0)),
        line_entity("entity:right", point(20.0, 0.0), point(20.0, 10.0)),
        line_entity("entity:top", point(20.0, 10.0), point(0.0, 10.0)),
        line_entity("entity:left", point(0.0, 10.0), point(0.0, 0.0)),
    ] {
        document
            .apply_command(DocumentCommand::AddEntity(entity))
            .unwrap();
    }
    document
        .apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
            "derived:fillet",
            None,
            Fillet {
                source_entity_ids: vec![
                    "entity:bottom".into(),
                    "entity:right".into(),
                    "entity:top".into(),
                    "entity:left".into(),
                ],
                radius: ConstraintValue::FixedMm(2.0),
                closed: false,
            },
        )))
        .unwrap();

    let selected_range = document
        .preflight_derived_element(
            DerivedElementPreflightKind::OffsetCurve,
            Some("derived:fillet:resolved:0".into()),
            vec![
                "entity:bottom".into(),
                "entity:right".into(),
                "entity:top".into(),
            ],
            Some(point(10.0, 2.0)),
        )
        .unwrap();
    let option = &selected_range.offset_options[0];
    assert_eq!(option.scope, OffsetSourceScope::SelectedRange);
    assert_eq!(option.source_entity_ids, ["derived:fillet"]);
    assert_eq!(
        option.source_resolved_entity_ids,
        [
            "derived:fillet:resolved:0",
            "derived:fillet:resolved:1",
            "derived:fillet:resolved:2",
            "derived:fillet:resolved:3",
            "derived:fillet:resolved:4",
        ]
    );

    let single = document
        .preflight_derived_element(
            DerivedElementPreflightKind::OffsetCurve,
            Some("derived:fillet:resolved:1".into()),
            vec![],
            Some(point(19.0, 1.0)),
        )
        .unwrap();
    assert_eq!(
        single
            .offset_options
            .last()
            .unwrap()
            .source_resolved_entity_ids,
        ["derived:fillet:resolved:1"]
    );

    document
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:offset",
                None,
                OffsetCurve {
                    source_entity_ids: option.source_entity_ids.clone(),
                    source_resolved_entity_ids: option.source_resolved_entity_ids.clone(),
                    distance: ConstraintValue::FixedMm(1.0),
                    direction: option.direction,
                },
            ),
        ))
        .unwrap();
    let offset_entities = document
        .drawing_snapshot(CanvasViewMode::EditDisplay)
        .entities
        .into_iter()
        .filter(|entity| entity.id.starts_with("derived:offset:resolved:"))
        .collect::<Vec<_>>();
    assert_eq!(offset_entities.len(), 5);
    let offset_arcs = offset_entities
        .iter()
        .filter_map(|entity| match entity.kind {
            EntityKind::Arc(arc) => Some(arc),
            _ => None,
        })
        .collect::<Vec<_>>();
    assert_eq!(offset_arcs.len(), 2);
    assert!(offset_arcs
        .iter()
        .all(|arc| (arc.radius_mm - 1.0).abs() <= 0.001));

    let round_tripped = round_trip_json(&document);
    let offset = round_tripped
        .derived_elements()
        .iter()
        .find(|item| item.id == "derived:offset")
        .unwrap();
    let kawacad_core::derived::DerivedElementKind::OffsetCurve(offset) = &offset.kind else {
        panic!("expected offset")
    };
    assert_eq!(
        offset.source_resolved_entity_ids,
        [
            "derived:fillet:resolved:0",
            "derived:fillet:resolved:1",
            "derived:fillet:resolved:2",
            "derived:fillet:resolved:3",
            "derived:fillet:resolved:4",
        ]
    );
}

#[test]
fn measurement_evaluation_and_conversion_use_the_same_core_value() {
    let mut document = ProjectDocument::new("measurement");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line",
            point(0.0, 0.0),
            point(3.0, 4.0),
        )))
        .unwrap();
    document
        .apply_command(DocumentCommand::AddMeasurementAnnotation(
            measurement_annotation(
                "measurement:length",
                MeasurementAnnotationKind::SegmentLength,
                vec![entity_target("entity:line")],
            ),
        ))
        .unwrap();

    let evaluation = document
        .evaluate_measurement_by_id("measurement:length")
        .unwrap();
    assert_eq!(evaluation.value, ConstraintValue::FixedMm(5.0));
    document
        .apply_command(DocumentCommand::ConvertMeasurementToConstraint {
            annotation_id: "measurement:length".into(),
            constraint_id: "constraint:length".into(),
        })
        .unwrap();
    let constraint = document
        .constraints()
        .iter()
        .find(|item| item.id == "constraint:length")
        .unwrap();
    assert_eq!(constraint.kind, ConstraintKind::SegmentLength);
    assert_eq!(constraint.value, Some(evaluation.value));
    assert!(document
        .measurement_annotations()
        .iter()
        .all(|item| item.id != "measurement:length"));
}

#[test]
fn stitch_placement_projects_to_core_selected_stitch_line() {
    let mut document = ProjectDocument::new("stitch");
    let mut line = line_entity("entity:stitch", point(0.0, 0.0), point(100.0, 0.0));
    line.style_id = Some("style:stitch-line".into());
    document
        .apply_command(DocumentCommand::AddEntity(line))
        .unwrap();

    document
        .apply_command(DocumentCommand::PlaceStitchStartPoint {
            id: "stitch:start".into(),
            position: point(40.0, 1.0),
            candidate_target_ids: vec![],
            max_distance_mm: 3.0,
        })
        .unwrap();
    let stitch = &document.stitch_start_points()[0];
    assert_eq!(stitch.target_id, "entity:stitch");
    assert_eq!(stitch.resolved_index, None);
    assert_approx_eq(stitch.position_ratio, 0.4);
}

#[test]
fn stitch_placement_accepts_shape_targets_without_shared_stitch_style() {
    let mut document = ProjectDocument::new("stitch-shapes");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line",
            point(0.0, 0.0),
            point(100.0, 0.0),
        )))
        .unwrap();
    document
        .apply_command(DocumentCommand::AddEntity(center_line_entity(
            "entity:center",
            point(0.0, 20.0),
            point(100.0, 20.0),
        )))
        .unwrap();
    document
        .apply_command(DocumentCommand::AddEntity(arc_entity(
            "entity:arc",
            point(50.0, 50.0),
            10.0,
            0.0,
            std::f64::consts::PI,
        )))
        .unwrap();

    for (id, position, expected_ratio) in [
        ("entity:line", point(25.0, 1.0), 0.25),
        ("entity:center", point(75.0, 21.0), 0.75),
        ("entity:arc", point(50.0, 60.0), 0.5),
    ] {
        document
            .apply_command(DocumentCommand::PlaceStitchStartPoint {
                id: format!("stitch:{id}"),
                position,
                candidate_target_ids: vec![id.to_owned()],
                max_distance_mm: 2.0,
            })
            .unwrap();
        let stitch = document
            .stitch_start_points()
            .iter()
            .find(|item| item.target_id == id)
            .unwrap();
        assert_approx_eq(stitch.position_ratio, expected_ratio);
    }
}

#[test]
fn stitch_placement_filters_unstyled_derived_targets_by_resolved_shape() {
    let mut document = ProjectDocument::new("stitch-derived-shapes");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line",
            point(0.0, 0.0),
            point(100.0, 0.0),
        )))
        .unwrap();
    document
        .apply_command(DocumentCommand::AddEntity(circle_entity(
            "entity:circle",
            point(200.0, 0.0),
            10.0,
        )))
        .unwrap();
    for (id, source) in [
        ("derived:line-offset", "entity:line"),
        ("derived:circle-offset", "entity:circle"),
    ] {
        document
            .apply_command(DocumentCommand::AddDerivedElement(
                DerivedElement::offset_curve(
                    id,
                    None,
                    OffsetCurve {
                        source_entity_ids: vec![source.into()],
                        source_resolved_entity_ids: Vec::new(),
                        distance: ConstraintValue::FixedMm(5.0),
                        direction: OffsetDirection::Left,
                    },
                ),
            ))
            .unwrap();
    }

    document
        .apply_command(DocumentCommand::PlaceStitchStartPoint {
            id: "stitch:derived-line".into(),
            position: point(40.0, 6.0),
            candidate_target_ids: vec!["derived:line-offset".into()],
            max_distance_mm: 2.0,
        })
        .unwrap();
    let stitch = &document.stitch_start_points()[0];
    assert_eq!(stitch.target_id, "derived:line-offset");
    assert_eq!(stitch.resolved_index, Some(0));
    assert_approx_eq(stitch.position_ratio, 0.4);

    let before = document.stitch_start_points().to_vec();
    assert!(document
        .apply_command(DocumentCommand::PlaceStitchStartPoint {
            id: "stitch:derived-circle".into(),
            position: point(215.0, 0.0),
            candidate_target_ids: vec!["derived:circle-offset".into()],
            max_distance_mm: 2.0,
        })
        .is_err());
    assert_eq!(document.stitch_start_points(), before.as_slice());
}

#[test]
fn selection_export_and_paste_keep_derived_measurement_and_constraint_references_internal() {
    let mut document = ProjectDocument::new("clipboard");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line",
            point(0.0, 0.0),
            point(20.0, 0.0),
        )))
        .unwrap();
    document
        .apply_command(DocumentCommand::AddDerivedElement(
            DerivedElement::offset_curve(
                "derived:offset",
                Some("layer:cut-line".into()),
                OffsetCurve {
                    source_entity_ids: vec!["entity:line".into()],
                    source_resolved_entity_ids: Vec::new(),
                    distance: ConstraintValue::FixedMm(3.0),
                    direction: OffsetDirection::Left,
                },
            ),
        ))
        .unwrap();
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            "constraint:length",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:line")],
            Some(ConstraintValue::FixedMm(20.0)),
        )))
        .unwrap();
    document
        .apply_command(DocumentCommand::AddMeasurementAnnotation(
            measurement_annotation(
                "measurement:length",
                MeasurementAnnotationKind::SegmentLength,
                vec![entity_target("entity:line")],
            ),
        ))
        .unwrap();

    let selection = SelectionReference {
        entity_ids: vec!["entity:line".into()],
        ..SelectionReference::default()
    };
    let exported = document.export_selection(selection).unwrap();
    assert_eq!(exported.root_count, 1);
    document
        .apply_command(DocumentCommand::PasteSelection {
            clipboard_json: exported.clipboard_json,
            id_namespace: "test".into(),
            delta: point(5.0, 5.0),
        })
        .unwrap();

    let copied_entity = "entity:copy-test:entity:line";
    let copied_derived = document
        .derived_elements()
        .iter()
        .find(|item| item.id == "derived:copy-test:derived:offset")
        .unwrap();
    assert!(document.entity(copied_entity).is_some());
    let kawacad_core::derived::DerivedElementKind::OffsetCurve(offset) = &copied_derived.kind
    else {
        panic!("expected offset")
    };
    assert_eq!(offset.source_entity_ids, [copied_entity]);
    let copied_constraint = document
        .constraints()
        .iter()
        .find(|item| item.id.starts_with("constraint:copy-test:"))
        .unwrap();
    assert_eq!(copied_constraint.targets, [entity_target(copied_entity)]);
    let copied_measurement = document
        .measurement_annotations()
        .iter()
        .find(|item| item.id.starts_with("measurement:copy-test:"))
        .unwrap();
    assert_eq!(copied_measurement.targets, [entity_target(copied_entity)]);
}

#[test]
fn selection_export_and_paste_keep_line_arc_fillet_sources_internal() {
    let mut document = ProjectDocument::new("line arc fillet clipboard");
    for entity in [
        line_entity("entity:line", point(0.0, 0.0), point(10.0, 0.0)),
        arc_entity(
            "entity:arc",
            point(20.0, 0.0),
            10.0,
            std::f64::consts::PI,
            -std::f64::consts::FRAC_PI_2,
        ),
    ] {
        document
            .apply_command(DocumentCommand::AddEntity(entity))
            .unwrap();
    }
    document
        .apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
            "derived:fillet",
            None,
            Fillet {
                source_entity_ids: vec!["entity:line".into(), "entity:arc".into()],
                radius: ConstraintValue::FixedMm(2.0),
                closed: false,
            },
        )))
        .unwrap();

    let exported = document
        .export_selection(SelectionReference {
            entity_ids: vec!["entity:line".into(), "entity:arc".into()],
            ..SelectionReference::default()
        })
        .unwrap();
    document
        .apply_command(DocumentCommand::PasteSelection {
            clipboard_json: exported.clipboard_json,
            id_namespace: "line-arc".into(),
            delta: point(5.0, 5.0),
        })
        .unwrap();

    let copied = document
        .derived_element("derived:copy-line-arc:derived:fillet")
        .unwrap();
    let DerivedElementKind::Fillet(fillet) = &copied.kind else {
        panic!("expected fillet")
    };
    assert_eq!(
        fillet.source_entity_ids,
        [
            "entity:copy-line-arc:entity:line",
            "entity:copy-line-arc:entity:arc"
        ]
    );
    assert_eq!(
        document
            .drawing_snapshot(CanvasViewMode::EditDisplay)
            .entities
            .iter()
            .filter(|entity| entity
                .id
                .starts_with("derived:copy-line-arc:derived:fillet:resolved:"))
            .count(),
        3
    );
}

#[test]
fn selection_export_reports_bounds_and_uses_its_center_as_paste_anchor() {
    let mut document = ProjectDocument::new("clipboard bounds");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line",
            point(10.0, 20.0),
            point(30.0, 40.0),
        )))
        .unwrap();

    let exported = document
        .export_selection(SelectionReference {
            entity_ids: vec!["entity:line".into()],
            ..SelectionReference::default()
        })
        .unwrap();

    assert_eq!(exported.anchor_point, Some(point(20.0, 30.0)));
    assert_eq!(
        exported.bounds,
        Some(kawacad_core::document::SelectionBounds {
            min_point: point(10.0, 20.0),
            max_point: point(30.0, 40.0),
        })
    );
}

#[test]
fn selection_roots_expand_dependencies_and_reject_missing_root_ids() {
    let mut document = ProjectDocument::new("clipboard roots");
    document
        .apply_command(DocumentCommand::AddEntity(line_entity(
            "entity:line",
            point(0.0, 0.0),
            point(20.0, 0.0),
        )))
        .unwrap();
    document
        .apply_command(DocumentCommand::AddMeasurementAnnotation(
            measurement_annotation(
                "measurement:length",
                MeasurementAnnotationKind::SegmentLength,
                vec![entity_target("entity:line")],
            ),
        ))
        .unwrap();

    let exported = document
        .export_selection(SelectionReference {
            measurement_annotation_ids: vec!["measurement:length".into()],
            ..SelectionReference::default()
        })
        .unwrap();
    assert_eq!(exported.root_count, 1);
    assert!(exported.anchor_point.is_some());
    document
        .apply_command(DocumentCommand::PasteSelection {
            clipboard_json: exported.clipboard_json,
            id_namespace: "root".into(),
            delta: point(5.0, 0.0),
        })
        .unwrap();
    assert!(document.entity("entity:copy-root:entity:line").is_some());
    assert!(document
        .measurement_annotations()
        .iter()
        .any(|item| item.id == "measurement:copy-root:measurement:length"));

    let error = document
        .export_selection(SelectionReference {
            constraint_ids: vec!["constraint:missing".into()],
            ..SelectionReference::default()
        })
        .unwrap_err();
    assert!(matches!(
        error,
        kawacad_core::command::CommandError::MissingId {
            kind: "constraint",
            ..
        }
    ));
}

#[test]
fn smooth_arc_tangencies_is_atomic_and_adds_two_tangent_constraints() {
    let mut document = ProjectDocument::new("smooth");
    for entity in [
        line_entity(
            "entity:right",
            point(5.0, 65.0),
            point(15.215188501565995, 19.0430377003132),
        ),
        line_entity("entity:left", point(-15.0, 65.0), point(-25.0, 20.0)),
        arc_entity(
            "entity:arc",
            point(-5.0, 15.0),
            20.615528128088304,
            0.19739555984988075,
            -3.5839668765665382,
        ),
    ] {
        document
            .apply_command(DocumentCommand::AddEntity(entity))
            .unwrap();
    }
    for (id, line_id, arc_point) in [
        ("constraint:right", "entity:right", ControlPointKind::Start),
        ("constraint:left", "entity:left", ControlPointKind::End),
    ] {
        document
            .apply_command(DocumentCommand::AddConstraint(constraint(
                id,
                ConstraintKind::Coincident,
                vec![
                    point_target(line_id, ControlPointKind::End),
                    point_target("entity:arc", arc_point),
                ],
                None,
            )))
            .unwrap();
    }
    document
        .apply_command(DocumentCommand::SmoothArcTangencies {
            arc_entity_id: "entity:arc".into(),
        })
        .unwrap();
    assert_eq!(
        document
            .constraints()
            .iter()
            .filter(|item| item.kind == ConstraintKind::Tangent)
            .count(),
        2
    );
}
