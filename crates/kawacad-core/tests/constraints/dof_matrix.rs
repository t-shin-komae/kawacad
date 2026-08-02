use crate::support::*;
use kawacad_core::command::{CommandError, ConstraintCommandErrorCode, DocumentCommand};
use kawacad_core::constraints::{
    ConstraintKind, ConstraintStatus, ConstraintValue, ControlPointKind,
};
use kawacad_core::document::ProjectDocument;
use kawacad_core::geometry::{Entity, EntityKind, LineSegment, Point2};
use kawacad_core::snapshot::CanvasViewMode;

#[test]
fn d0_basic_entities_without_constraints_are_under_constrained() {
    // D0-01, D0-03, D0-07, D0-10, D0-12
    let mut document = ProjectDocument::new("D0 basic entities");
    for entity in [
        point_entity("entity:point", point(0.0, 0.0)),
        line_entity("entity:line", point(0.0, 0.0), point(10.0, 0.0)),
        circle_entity("entity:circle", point(5.0, 5.0), 3.0),
        arc_entity(
            "entity:arc",
            point(20.0, 20.0),
            5.0,
            0.0,
            std::f64::consts::FRAC_PI_2,
        ),
        center_line_entity("entity:axis", point(0.0, -10.0), point(0.0, 10.0)),
    ] {
        add_entity(&mut document, entity);
    }

    assert_entity_status(
        &document,
        "entity:point",
        ConstraintStatus::UnderConstrained,
        2,
    );
    assert_entity_status(
        &document,
        "entity:line",
        ConstraintStatus::UnderConstrained,
        4,
    );
    assert_entity_status(
        &document,
        "entity:circle",
        ConstraintStatus::UnderConstrained,
        3,
    );
    assert_entity_status(
        &document,
        "entity:arc",
        ConstraintStatus::UnderConstrained,
        5,
    );
    assert_entity_status(
        &document,
        "entity:axis",
        ConstraintStatus::UnderConstrained,
        4,
    );
}

#[test]
fn d0_d1_d2_fixed_point_is_fully_constrained() {
    // D0-02, D1-01, D2-01
    let mut document = ProjectDocument::new("D0-02 D1-01 D2-01");
    add_entity(&mut document, point_entity("entity:point", point(0.0, 0.0)));
    add_constraint(
        &mut document,
        "constraint:fixed",
        ConstraintKind::Fixed,
        vec![entity_target("entity:point")],
        None,
    );

    assert_entity_status(
        &document,
        "entity:point",
        ConstraintStatus::FullyConstrained,
        0,
    );
    assert_snapshot_status(&document, ConstraintStatus::FullyConstrained);
}

#[test]
fn d0_d1_single_dimension_or_orientation_constraints_keep_entities_under_constrained() {
    // D0-04, D0-05, D0-06, D0-08, D0-09, D0-11, D1-12
    for (name, entity, constraint_kind, value, expected_remaining_dof) in [
        (
            "D0-04 segment length",
            line_entity("entity:target", point(0.0, 0.0), point(10.0, 0.0)),
            ConstraintKind::SegmentLength,
            Some(ConstraintValue::FixedMm(10.0)),
            3,
        ),
        (
            "D0-05 horizontal",
            line_entity("entity:target", point(0.0, 0.0), point(10.0, 3.0)),
            ConstraintKind::Horizontal,
            None,
            3,
        ),
        (
            "D0-06 vertical",
            line_entity("entity:target", point(0.0, 0.0), point(3.0, 10.0)),
            ConstraintKind::Vertical,
            None,
            3,
        ),
        (
            "D0-08 circle radius",
            circle_entity("entity:target", point(5.0, 5.0), 3.0),
            ConstraintKind::Radius,
            Some(ConstraintValue::FixedMm(3.0)),
            2,
        ),
        (
            "D0-09 circle diameter",
            circle_entity("entity:target", point(5.0, 5.0), 3.0),
            ConstraintKind::Diameter,
            Some(ConstraintValue::FixedMm(6.0)),
            2,
        ),
        (
            "D0-11 arc radius",
            arc_entity(
                "entity:target",
                point(5.0, 5.0),
                3.0,
                0.0,
                std::f64::consts::FRAC_PI_2,
            ),
            ConstraintKind::Radius,
            Some(ConstraintValue::FixedMm(3.0)),
            4,
        ),
        (
            "D1-12 circle radius",
            circle_entity("entity:target", point(5.0, 5.0), 4.0),
            ConstraintKind::Radius,
            Some(ConstraintValue::FixedMm(4.0)),
            2,
        ),
    ] {
        let mut document = ProjectDocument::new(name);
        add_entity(&mut document, entity);
        add_constraint(
            &mut document,
            "constraint:single",
            constraint_kind,
            vec![entity_target("entity:target")],
            value,
        );
        assert_entity_status(
            &document,
            "entity:target",
            ConstraintStatus::UnderConstrained,
            expected_remaining_dof,
        );
    }
}

#[test]
fn d1_single_constraints_report_expected_statuses() {
    // D1-02
    let mut document = ProjectDocument::new("D1-02");
    add_entity(
        &mut document,
        point_entity("entity:point-a", point(0.0, 0.0)),
    );
    add_entity(
        &mut document,
        point_entity("entity:point-b", point(3.0, 4.0)),
    );
    add_constraint(
        &mut document,
        "constraint:coincident",
        ConstraintKind::Coincident,
        vec![
            entity_target("entity:point-a"),
            entity_target("entity:point-b"),
        ],
        None,
    );
    assert_entity_status(
        &document,
        "entity:point-a",
        ConstraintStatus::UnderConstrained,
        2,
    );
    assert_entity_status(
        &document,
        "entity:point-b",
        ConstraintStatus::UnderConstrained,
        2,
    );

    // D1-03, D1-04, D1-05
    for (name, kind, value) in [
        ("D1-03", ConstraintKind::Horizontal, None),
        ("D1-04", ConstraintKind::Vertical, None),
        (
            "D1-05",
            ConstraintKind::SegmentLength,
            Some(ConstraintValue::FixedMm(10.0)),
        ),
    ] {
        let mut document = ProjectDocument::new(name);
        add_entity(
            &mut document,
            line_entity("entity:line", point(0.0, 0.0), point(10.0, 3.0)),
        );
        add_constraint(
            &mut document,
            "constraint:single",
            kind,
            vec![entity_target("entity:line")],
            value,
        );
        assert_entity_status(
            &document,
            "entity:line",
            ConstraintStatus::UnderConstrained,
            3,
        );
    }

    // D1-07, D1-08, D1-09, D1-10
    for (name, kind, value) in [
        ("D1-07", ConstraintKind::Parallel, None),
        ("D1-08", ConstraintKind::Perpendicular, None),
        (
            "D1-09",
            ConstraintKind::Angle,
            Some(ConstraintValue::FixedDegrees(45.0)),
        ),
        ("D1-10", ConstraintKind::EqualSegmentLength, None),
        (
            "D1-17",
            ConstraintKind::LineLineDistance,
            Some(ConstraintValue::FixedMm(4.0)),
        ),
    ] {
        let mut document = two_line_document(name);
        add_constraint(
            &mut document,
            "constraint:line-relation",
            kind,
            vec![
                entity_target("entity:line-a"),
                entity_target("entity:line-b"),
            ],
            value,
        );
        assert_entity_status(
            &document,
            "entity:line-a",
            ConstraintStatus::UnderConstrained,
            7,
        );
        assert_entity_status(
            &document,
            "entity:line-b",
            ConstraintStatus::UnderConstrained,
            7,
        );
    }

    // D1-11
    let mut document = ProjectDocument::new("D1-11");
    add_entity(
        &mut document,
        circle_entity("entity:circle", point(0.0, 0.0), 5.0),
    );
    add_constraint(
        &mut document,
        "constraint:diameter",
        ConstraintKind::Diameter,
        vec![entity_target("entity:circle")],
        Some(ConstraintValue::FixedMm(10.0)),
    );
    assert_entity_status(
        &document,
        "entity:circle",
        ConstraintStatus::UnderConstrained,
        2,
    );

    // D1-13
    let mut document = ProjectDocument::new("D1-13");
    add_entity(
        &mut document,
        arc_entity(
            "entity:arc",
            point(0.0, 0.0),
            5.0,
            0.0,
            std::f64::consts::FRAC_PI_2,
        ),
    );
    add_constraint(
        &mut document,
        "constraint:radius",
        ConstraintKind::Radius,
        vec![entity_target("entity:arc")],
        Some(ConstraintValue::FixedMm(5.0)),
    );
    assert_entity_status(
        &document,
        "entity:arc",
        ConstraintStatus::UnderConstrained,
        4,
    );

    // D1-14
    let mut document = ProjectDocument::new("D1-14");
    add_entity(
        &mut document,
        point_entity("entity:point-a", point(0.0, 0.0)),
    );
    add_entity(
        &mut document,
        point_entity("entity:point-b", point(3.0, 4.0)),
    );
    add_constraint(
        &mut document,
        "constraint:distance",
        ConstraintKind::Distance,
        vec![
            entity_target("entity:point-a"),
            entity_target("entity:point-b"),
        ],
        Some(ConstraintValue::FixedMm(5.0)),
    );
    assert_entity_status(
        &document,
        "entity:point-a",
        ConstraintStatus::UnderConstrained,
        3,
    );
    assert_entity_status(
        &document,
        "entity:point-b",
        ConstraintStatus::UnderConstrained,
        3,
    );

    // D1-15
    let mut document = ProjectDocument::new("D1-15");
    add_entity(
        &mut document,
        point_entity("entity:point-a", point(2.0, 3.0)),
    );
    add_entity(
        &mut document,
        point_entity("entity:point-b", point(-2.0, 3.0)),
    );
    add_entity(
        &mut document,
        center_line_entity("entity:axis", point(0.0, -10.0), point(0.0, 10.0)),
    );
    add_constraint(
        &mut document,
        "constraint:symmetric",
        ConstraintKind::Symmetric,
        vec![
            entity_target("entity:point-a"),
            entity_target("entity:point-b"),
            entity_target("entity:axis"),
        ],
        None,
    );
    assert_entity_status(
        &document,
        "entity:point-a",
        ConstraintStatus::UnderConstrained,
        6,
    );

    // D1-16
    let mut document = ProjectDocument::new("D1-16");
    add_entity(&mut document, point_entity("entity:point", point(3.0, 4.0)));
    add_entity(
        &mut document,
        line_entity("entity:line", point(0.0, 0.0), point(10.0, 0.0)),
    );
    add_constraint(
        &mut document,
        "constraint:point-line-distance",
        ConstraintKind::PointLineDistance,
        vec![entity_target("entity:point"), entity_target("entity:line")],
        Some(ConstraintValue::FixedMm(4.0)),
    );
    assert_entity_status(
        &document,
        "entity:point",
        ConstraintStatus::UnderConstrained,
        5,
    );

    // D1-18
    let mut document = ProjectDocument::new("D1-18");
    add_entity(&mut document, point_entity("entity:point", point(3.0, 4.0)));
    add_entity(
        &mut document,
        line_entity("entity:line", point(0.0, 0.0), point(10.0, 0.0)),
    );
    add_constraint(
        &mut document,
        "constraint:point-on-line",
        ConstraintKind::PointOnLine,
        vec![entity_target("entity:point"), entity_target("entity:line")],
        None,
    );
    assert_entity_status(
        &document,
        "entity:point",
        ConstraintStatus::UnderConstrained,
        5,
    );
}

#[test]
fn d2_fully_constrained_representative_combinations_are_fully_constrained() {
    // D2-02
    let mut document = ProjectDocument::new("D2-02");
    add_entity(
        &mut document,
        line_entity("entity:line", point(0.0, 0.0), point(10.0, 0.0)),
    );
    add_constraint(
        &mut document,
        "constraint:start-fixed",
        ConstraintKind::Fixed,
        vec![point_target("entity:line", ControlPointKind::Start)],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:horizontal",
        ConstraintKind::Horizontal,
        vec![entity_target("entity:line")],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:length",
        ConstraintKind::SegmentLength,
        vec![entity_target("entity:line")],
        Some(ConstraintValue::FixedMm(10.0)),
    );
    assert_entity_status(
        &document,
        "entity:line",
        ConstraintStatus::FullyConstrained,
        0,
    );

    // D2-03
    let mut document = ProjectDocument::new("D2-03");
    add_entity(
        &mut document,
        line_entity("entity:line", point(0.0, 0.0), point(0.0, 10.0)),
    );
    add_constraint(
        &mut document,
        "constraint:start-fixed",
        ConstraintKind::Fixed,
        vec![point_target("entity:line", ControlPointKind::Start)],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:vertical",
        ConstraintKind::Vertical,
        vec![entity_target("entity:line")],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:length",
        ConstraintKind::SegmentLength,
        vec![entity_target("entity:line")],
        Some(ConstraintValue::FixedMm(10.0)),
    );
    assert_entity_status(
        &document,
        "entity:line",
        ConstraintStatus::FullyConstrained,
        0,
    );

    // D2-04
    let mut document = ProjectDocument::new("D2-04");
    add_entity(
        &mut document,
        line_entity("entity:line", point(0.0, 0.0), point(10.0, 0.0)),
    );
    add_constraint(
        &mut document,
        "constraint:start-fixed",
        ConstraintKind::Fixed,
        vec![point_target("entity:line", ControlPointKind::Start)],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:end-fixed",
        ConstraintKind::Fixed,
        vec![point_target("entity:line", ControlPointKind::End)],
        None,
    );
    assert_entity_status(
        &document,
        "entity:line",
        ConstraintStatus::FullyConstrained,
        0,
    );

    // D2-05
    let mut document = ProjectDocument::new("D2-05");
    add_entity(
        &mut document,
        point_entity("entity:anchor", point(0.0, 0.0)),
    );
    add_entity(
        &mut document,
        line_entity("entity:line", point(5.0, 5.0), point(15.0, 5.0)),
    );
    add_constraint(
        &mut document,
        "constraint:anchor-fixed",
        ConstraintKind::Fixed,
        vec![entity_target("entity:anchor")],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:start-coincident",
        ConstraintKind::Coincident,
        vec![
            entity_target("entity:anchor"),
            point_target("entity:line", ControlPointKind::Start),
        ],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:horizontal",
        ConstraintKind::Horizontal,
        vec![entity_target("entity:line")],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:distance",
        ConstraintKind::SegmentLength,
        vec![entity_target("entity:line")],
        Some(ConstraintValue::FixedMm(10.0)),
    );
    assert_entity_status(
        &document,
        "entity:line",
        ConstraintStatus::FullyConstrained,
        0,
    );

    // D2-06
    let mut document = ProjectDocument::new("D2-06");
    add_entity(
        &mut document,
        circle_entity("entity:circle", point(0.0, 0.0), 5.0),
    );
    add_constraint(
        &mut document,
        "constraint:center-fixed",
        ConstraintKind::Fixed,
        vec![point_target("entity:circle", ControlPointKind::Center)],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:radius",
        ConstraintKind::Radius,
        vec![entity_target("entity:circle")],
        Some(ConstraintValue::FixedMm(5.0)),
    );
    assert_entity_status(
        &document,
        "entity:circle",
        ConstraintStatus::FullyConstrained,
        0,
    );

    // D2-07
    let mut document = ProjectDocument::new("D2-07");
    add_entity(
        &mut document,
        circle_entity("entity:circle", point(0.0, 0.0), 5.0),
    );
    add_constraint(
        &mut document,
        "constraint:center-fixed",
        ConstraintKind::Fixed,
        vec![point_target("entity:circle", ControlPointKind::Center)],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:diameter",
        ConstraintKind::Diameter,
        vec![entity_target("entity:circle")],
        Some(ConstraintValue::FixedMm(10.0)),
    );
    assert_entity_status(
        &document,
        "entity:circle",
        ConstraintStatus::FullyConstrained,
        0,
    );

    // D2-08
    let mut document = full_arc_document("D2-08", false);
    assert_entity_status(
        &document,
        "entity:arc",
        ConstraintStatus::FullyConstrained,
        0,
    );

    // D2-09
    document = full_arc_document("D2-09", true);
    assert_entity_status(
        &document,
        "entity:arc",
        ConstraintStatus::FullyConstrained,
        0,
    );

    // D2-10
    let mut document = ProjectDocument::new("D2-10");
    add_entity(
        &mut document,
        line_entity("entity:line-a", point(0.0, 0.0), point(10.0, 0.0)),
    );
    add_entity(
        &mut document,
        line_entity("entity:line-b", point(0.0, 0.0), point(8.0, 5.0)),
    );
    add_constraint(
        &mut document,
        "constraint:a-start-fixed",
        ConstraintKind::Fixed,
        vec![point_target("entity:line-a", ControlPointKind::Start)],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:a-horizontal",
        ConstraintKind::Horizontal,
        vec![entity_target("entity:line-a")],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:a-length",
        ConstraintKind::SegmentLength,
        vec![entity_target("entity:line-a")],
        Some(ConstraintValue::FixedMm(10.0)),
    );
    add_constraint(
        &mut document,
        "constraint:b-start-fixed",
        ConstraintKind::Fixed,
        vec![point_target("entity:line-b", ControlPointKind::Start)],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:b-length",
        ConstraintKind::SegmentLength,
        vec![entity_target("entity:line-b")],
        Some(ConstraintValue::FixedMm(12.0)),
    );
    add_constraint(
        &mut document,
        "constraint:parallel",
        ConstraintKind::Parallel,
        vec![
            entity_target("entity:line-a"),
            entity_target("entity:line-b"),
        ],
        None,
    );
    assert_entity_status(
        &document,
        "entity:line-a",
        ConstraintStatus::FullyConstrained,
        0,
    );
    assert_entity_status(
        &document,
        "entity:line-b",
        ConstraintStatus::FullyConstrained,
        0,
    );

    // D2-11
    let mut document = ProjectDocument::new("D2-11");
    add_entity(
        &mut document,
        center_line_entity("entity:axis", point(0.0, -10.0), point(0.0, 10.0)),
    );
    add_entity(
        &mut document,
        point_entity("entity:point-a", point(4.0, 2.0)),
    );
    add_entity(
        &mut document,
        point_entity("entity:point-b", point(-4.0, 2.0)),
    );
    add_constraint(
        &mut document,
        "constraint:axis-start-fixed",
        ConstraintKind::Fixed,
        vec![point_target("entity:axis", ControlPointKind::Start)],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:axis-vertical",
        ConstraintKind::Vertical,
        vec![entity_target("entity:axis")],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:axis-length",
        ConstraintKind::SegmentLength,
        vec![entity_target("entity:axis")],
        Some(ConstraintValue::FixedMm(20.0)),
    );
    add_constraint(
        &mut document,
        "constraint:point-a-fixed",
        ConstraintKind::Fixed,
        vec![entity_target("entity:point-a")],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:symmetric",
        ConstraintKind::Symmetric,
        vec![
            entity_target("entity:point-a"),
            entity_target("entity:point-b"),
            entity_target("entity:axis"),
        ],
        None,
    );
    assert_entity_status(
        &document,
        "entity:axis",
        ConstraintStatus::FullyConstrained,
        0,
    );
    assert_entity_status(
        &document,
        "entity:point-a",
        ConstraintStatus::FullyConstrained,
        0,
    );
    assert_entity_status(
        &document,
        "entity:point-b",
        ConstraintStatus::FullyConstrained,
        0,
    );

    // D2-12
    let document = constrained_line_rectangle_document("D2-12");
    assert_rectangle_statuses(&document, ConstraintStatus::FullyConstrained);

    // D2-13
    let mut document = ProjectDocument::new("D2-13");
    add_entity(
        &mut document,
        line_entity("entity:edge", point(0.0, 0.0), point(20.0, 0.0)),
    );
    add_entity(
        &mut document,
        point_entity("entity:hole-center", point(6.0, 5.0)),
    );
    add_constraint(
        &mut document,
        "constraint:edge-start-fixed",
        ConstraintKind::Fixed,
        vec![point_target("entity:edge", ControlPointKind::Start)],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:edge-horizontal",
        ConstraintKind::Horizontal,
        vec![entity_target("entity:edge")],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:edge-length",
        ConstraintKind::SegmentLength,
        vec![entity_target("entity:edge")],
        Some(ConstraintValue::FixedMm(20.0)),
    );
    add_constraint(
        &mut document,
        "constraint:offset-from-edge",
        ConstraintKind::PointLineDistance,
        vec![
            entity_target("entity:hole-center"),
            entity_target("entity:edge"),
        ],
        Some(ConstraintValue::FixedMm(5.0)),
    );
    add_constraint(
        &mut document,
        "constraint:line-direction-position",
        ConstraintKind::Distance,
        vec![
            point_target("entity:edge", ControlPointKind::Start),
            entity_target("entity:hole-center"),
        ],
        Some(ConstraintValue::FixedMm(
            (6.0_f64.powi(2) + 5.0_f64.powi(2)).sqrt(),
        )),
    );
    assert_entity_status(
        &document,
        "entity:hole-center",
        ConstraintStatus::FullyConstrained,
        0,
    );
}

#[test]
fn d3_under_constrained_representative_combinations_remain_under_constrained() {
    // D3-01, D3-02, D3-03
    for (name, constraints, expected_remaining_dof) in [
        (
            "D3-01",
            vec![
                (
                    ConstraintKind::Horizontal,
                    vec![entity_target("entity:line")],
                    None,
                ),
                (
                    ConstraintKind::SegmentLength,
                    vec![entity_target("entity:line")],
                    Some(ConstraintValue::FixedMm(10.0)),
                ),
            ],
            2,
        ),
        (
            "D3-02",
            vec![
                (
                    ConstraintKind::Fixed,
                    vec![point_target("entity:line", ControlPointKind::Start)],
                    None,
                ),
                (
                    ConstraintKind::SegmentLength,
                    vec![entity_target("entity:line")],
                    Some(ConstraintValue::FixedMm(10.0)),
                ),
            ],
            1,
        ),
        (
            "D3-03",
            vec![
                (
                    ConstraintKind::Fixed,
                    vec![point_target("entity:line", ControlPointKind::Start)],
                    None,
                ),
                (
                    ConstraintKind::Horizontal,
                    vec![entity_target("entity:line")],
                    None,
                ),
            ],
            1,
        ),
    ] {
        let mut document = ProjectDocument::new(name);
        add_entity(
            &mut document,
            line_entity("entity:line", point(0.0, 0.0), point(10.0, 3.0)),
        );
        for (index, (kind, targets, value)) in constraints.into_iter().enumerate() {
            add_constraint(
                &mut document,
                &format!("constraint:{index}"),
                kind,
                targets,
                value,
            );
        }
        assert_entity_status(
            &document,
            "entity:line",
            ConstraintStatus::UnderConstrained,
            expected_remaining_dof,
        );
    }

    // D3-04, D3-05
    for (name, constraint_kind, targets, value, expected_remaining_dof) in [
        (
            "D3-04",
            ConstraintKind::Fixed,
            vec![point_target("entity:circle", ControlPointKind::Center)],
            None,
            1,
        ),
        (
            "D3-05",
            ConstraintKind::Radius,
            vec![entity_target("entity:circle")],
            Some(ConstraintValue::FixedMm(5.0)),
            2,
        ),
    ] {
        let mut document = ProjectDocument::new(name);
        add_entity(
            &mut document,
            circle_entity("entity:circle", point(0.0, 0.0), 5.0),
        );
        add_constraint(
            &mut document,
            "constraint:circle",
            constraint_kind,
            targets,
            value,
        );
        assert_entity_status(
            &document,
            "entity:circle",
            ConstraintStatus::UnderConstrained,
            expected_remaining_dof,
        );
    }

    // D3-06
    let mut document = ProjectDocument::new("D3-06");
    add_entity(
        &mut document,
        arc_entity(
            "entity:arc",
            point(0.0, 0.0),
            5.0,
            0.0,
            std::f64::consts::FRAC_PI_2,
        ),
    );
    add_constraint(
        &mut document,
        "constraint:center-fixed",
        ConstraintKind::Fixed,
        vec![point_target("entity:arc", ControlPointKind::Center)],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:radius",
        ConstraintKind::Radius,
        vec![entity_target("entity:arc")],
        Some(ConstraintValue::FixedMm(5.0)),
    );
    assert_entity_status(
        &document,
        "entity:arc",
        ConstraintStatus::UnderConstrained,
        2,
    );

    // D3-07
    let mut document = ProjectDocument::new("D3-07");
    add_entity(
        &mut document,
        point_entity("entity:point-a", point(0.0, 0.0)),
    );
    add_entity(
        &mut document,
        point_entity("entity:point-b", point(2.0, 2.0)),
    );
    add_constraint(
        &mut document,
        "constraint:coincident",
        ConstraintKind::Coincident,
        vec![
            entity_target("entity:point-a"),
            entity_target("entity:point-b"),
        ],
        None,
    );
    assert_entity_status(
        &document,
        "entity:point-a",
        ConstraintStatus::UnderConstrained,
        2,
    );
    assert_entity_status(
        &document,
        "entity:point-b",
        ConstraintStatus::UnderConstrained,
        2,
    );

    // D3-08, D3-09
    for (name, kind, value) in [
        ("D3-08", ConstraintKind::Parallel, None),
        (
            "D3-09",
            ConstraintKind::Angle,
            Some(ConstraintValue::FixedDegrees(45.0)),
        ),
    ] {
        let mut document = two_line_document(name);
        add_constraint(
            &mut document,
            "constraint:line-relation",
            kind,
            vec![
                entity_target("entity:line-a"),
                entity_target("entity:line-b"),
            ],
            value,
        );
        assert_entity_status(
            &document,
            "entity:line-a",
            ConstraintStatus::UnderConstrained,
            7,
        );
        assert_entity_status(
            &document,
            "entity:line-b",
            ConstraintStatus::UnderConstrained,
            7,
        );
    }

    // D3-10
    let mut document = ProjectDocument::new("D3-10");
    add_entity(
        &mut document,
        point_entity("entity:point-a", point(2.0, 3.0)),
    );
    add_entity(
        &mut document,
        point_entity("entity:point-b", point(-2.0, 3.0)),
    );
    add_entity(
        &mut document,
        center_line_entity("entity:axis", point(0.0, -10.0), point(0.0, 10.0)),
    );
    add_constraint(
        &mut document,
        "constraint:symmetric",
        ConstraintKind::Symmetric,
        vec![
            entity_target("entity:point-a"),
            entity_target("entity:point-b"),
            entity_target("entity:axis"),
        ],
        None,
    );
    assert_entity_status(
        &document,
        "entity:point-a",
        ConstraintStatus::UnderConstrained,
        6,
    );
}

#[test]
fn d4_over_constrained_representative_combinations_are_reported() {
    // D4-01
    let mut document = two_line_document("D4-01");
    add_constraint(
        &mut document,
        "constraint:parallel",
        ConstraintKind::Parallel,
        vec![
            entity_target("entity:line-a"),
            entity_target("entity:line-b"),
        ],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:angle",
        ConstraintKind::Angle,
        vec![
            entity_target("entity:line-a"),
            entity_target("entity:line-b"),
        ],
        Some(ConstraintValue::FixedDegrees(0.0)),
    );
    assert_snapshot_status(&document, ConstraintStatus::OverConstrained);

    // D4-02
    let mut document = line_with_fixed_endpoints_document("D4-02");
    add_constraint(
        &mut document,
        "constraint:length",
        ConstraintKind::SegmentLength,
        vec![entity_target("entity:line")],
        Some(ConstraintValue::FixedMm(10.0)),
    );
    assert_snapshot_status(&document, ConstraintStatus::OverConstrained);

    // D4-03
    let mut document = two_line_document("D4-03");
    add_constraint(
        &mut document,
        "constraint:perpendicular",
        ConstraintKind::Perpendicular,
        vec![
            entity_target("entity:line-a"),
            entity_target("entity:line-b"),
        ],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:angle",
        ConstraintKind::Angle,
        vec![
            entity_target("entity:line-a"),
            entity_target("entity:line-b"),
        ],
        Some(ConstraintValue::FixedDegrees(90.0)),
    );
    assert_snapshot_status(&document, ConstraintStatus::OverConstrained);

    // D4-04
    let mut document = ProjectDocument::new("D4-04");
    add_entity(
        &mut document,
        circle_entity("entity:circle", point(0.0, 0.0), 10.0),
    );
    add_constraint(
        &mut document,
        "constraint:radius",
        ConstraintKind::Radius,
        vec![entity_target("entity:circle")],
        Some(ConstraintValue::FixedMm(10.0)),
    );
    add_constraint(
        &mut document,
        "constraint:diameter",
        ConstraintKind::Diameter,
        vec![entity_target("entity:circle")],
        Some(ConstraintValue::FixedMm(20.0)),
    );
    assert_snapshot_status(&document, ConstraintStatus::OverConstrained);

    // D4-05, D4-06
    for (name, first_kind, first_value, second_kind, second_value) in [
        (
            "D4-05",
            ConstraintKind::Radius,
            ConstraintValue::FixedMm(10.0),
            ConstraintKind::Diameter,
            ConstraintValue::FixedMm(20.0),
        ),
        (
            "D4-06",
            ConstraintKind::Diameter,
            ConstraintValue::FixedMm(20.0),
            ConstraintKind::Radius,
            ConstraintValue::FixedMm(10.0),
        ),
    ] {
        let mut document = ProjectDocument::new(name);
        add_entity(
            &mut document,
            circle_entity("entity:circle", point(0.0, 0.0), 10.0),
        );
        add_constraint(
            &mut document,
            "constraint:first",
            first_kind,
            vec![entity_target("entity:circle")],
            Some(first_value),
        );
        add_constraint(
            &mut document,
            "constraint:second",
            second_kind,
            vec![entity_target("entity:circle")],
            Some(second_value),
        );
        assert_snapshot_status(&document, ConstraintStatus::OverConstrained);
    }

    // D4-07, D4-08
    for (name, first_kind, angle) in [
        ("D4-07", ConstraintKind::Parallel, 0.0),
        ("D4-08", ConstraintKind::Perpendicular, 90.0),
    ] {
        let mut document = two_line_document(name);
        add_constraint(
            &mut document,
            "constraint:relation",
            first_kind,
            vec![
                entity_target("entity:line-a"),
                entity_target("entity:line-b"),
            ],
            None,
        );
        add_constraint(
            &mut document,
            "constraint:angle",
            ConstraintKind::Angle,
            vec![
                entity_target("entity:line-a"),
                entity_target("entity:line-b"),
            ],
            Some(ConstraintValue::FixedDegrees(angle)),
        );
        assert_snapshot_status(&document, ConstraintStatus::OverConstrained);
    }

    // D4-09
    let mut document = ProjectDocument::new("D4-09");
    add_entity(
        &mut document,
        point_entity("entity:point-a", point(0.0, 0.0)),
    );
    add_entity(
        &mut document,
        point_entity("entity:point-b", point(10.0, 0.0)),
    );
    add_constraint(
        &mut document,
        "constraint:fixed-a",
        ConstraintKind::Fixed,
        vec![entity_target("entity:point-a")],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:fixed-b",
        ConstraintKind::Fixed,
        vec![entity_target("entity:point-b")],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:distance",
        ConstraintKind::Distance,
        vec![
            entity_target("entity:point-a"),
            entity_target("entity:point-b"),
        ],
        Some(ConstraintValue::FixedMm(10.0)),
    );
    assert_snapshot_status(&document, ConstraintStatus::OverConstrained);

    // D4-10
    let mut document = ProjectDocument::new("D4-10");
    add_entity(
        &mut document,
        line_entity("entity:edge", point(0.0, 0.0), point(20.0, 0.0)),
    );
    add_entity(
        &mut document,
        point_entity("entity:hole-center", point(6.0, 5.0)),
    );
    for (id, targets) in [
        (
            "constraint:edge-start-fixed",
            vec![point_target("entity:edge", ControlPointKind::Start)],
        ),
        (
            "constraint:hole-fixed",
            vec![entity_target("entity:hole-center")],
        ),
    ] {
        add_constraint(&mut document, id, ConstraintKind::Fixed, targets, None);
    }
    add_constraint(
        &mut document,
        "constraint:edge-horizontal",
        ConstraintKind::Horizontal,
        vec![entity_target("entity:edge")],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:edge-length",
        ConstraintKind::SegmentLength,
        vec![entity_target("entity:edge")],
        Some(ConstraintValue::FixedMm(20.0)),
    );
    add_constraint(
        &mut document,
        "constraint:offset-from-edge",
        ConstraintKind::PointLineDistance,
        vec![
            entity_target("entity:hole-center"),
            entity_target("entity:edge"),
        ],
        Some(ConstraintValue::FixedMm(5.0)),
    );
    assert_snapshot_status(&document, ConstraintStatus::OverConstrained);
}

#[test]
fn d5_conflicting_representative_changes_are_rejected_without_mutating_state() {
    // D5-01
    let mut document = ProjectDocument::new("D5-01");
    add_entity(
        &mut document,
        line_entity("entity:line", point(0.0, 0.0), point(10.0, 0.0)),
    );
    add_constraint(
        &mut document,
        "constraint:horizontal",
        ConstraintKind::Horizontal,
        vec![entity_target("entity:line")],
        None,
    );
    assert_conflicting_add(
        &mut document,
        "constraint:vertical",
        ConstraintKind::Vertical,
        vec![entity_target("entity:line")],
        None,
    );

    // D5-02
    let mut document = line_with_fixed_endpoints_document("D5-02");
    assert_conflicting_add(
        &mut document,
        "constraint:length",
        ConstraintKind::SegmentLength,
        vec![entity_target("entity:line")],
        Some(ConstraintValue::FixedMm(20.0)),
    );

    // D5-03
    let mut document = ProjectDocument::new("D5-03");
    add_entity(
        &mut document,
        line_entity("entity:line", point(0.0, 0.0), point(10.0, 0.0)),
    );
    add_constraint(
        &mut document,
        "constraint:length-a",
        ConstraintKind::SegmentLength,
        vec![entity_target("entity:line")],
        Some(ConstraintValue::FixedMm(10.0)),
    );
    assert_conflicting_add(
        &mut document,
        "constraint:length-b",
        ConstraintKind::SegmentLength,
        vec![entity_target("entity:line")],
        Some(ConstraintValue::FixedMm(20.0)),
    );

    // D5-04
    let mut document = ProjectDocument::new("D5-04");
    add_entity(
        &mut document,
        line_entity("entity:line", point(0.0, 0.0), point(10.0, 0.0)),
    );
    add_constraint(
        &mut document,
        "constraint:distance-a",
        ConstraintKind::SegmentLength,
        vec![entity_target("entity:line")],
        Some(ConstraintValue::FixedMm(10.0)),
    );
    assert_conflicting_add(
        &mut document,
        "constraint:distance-b",
        ConstraintKind::SegmentLength,
        vec![entity_target("entity:line")],
        Some(ConstraintValue::FixedMm(20.0)),
    );

    // D5-05, D5-06
    for (name, first_kind, first_value, second_kind, second_value) in [
        (
            "D5-05",
            ConstraintKind::Radius,
            ConstraintValue::FixedMm(10.0),
            ConstraintKind::Diameter,
            ConstraintValue::FixedMm(30.0),
        ),
        (
            "D5-06",
            ConstraintKind::Diameter,
            ConstraintValue::FixedMm(20.0),
            ConstraintKind::Radius,
            ConstraintValue::FixedMm(15.0),
        ),
    ] {
        let mut document = ProjectDocument::new(name);
        add_entity(
            &mut document,
            circle_entity("entity:circle", point(0.0, 0.0), 10.0),
        );
        add_constraint(
            &mut document,
            "constraint:first",
            first_kind,
            vec![entity_target("entity:circle")],
            Some(first_value),
        );
        assert_conflicting_add(
            &mut document,
            "constraint:second",
            second_kind,
            vec![entity_target("entity:circle")],
            Some(second_value),
        );
    }

    // D5-07
    let mut document = ProjectDocument::new("D5-07");
    add_entity(
        &mut document,
        point_entity("entity:point-a", point(0.0, 0.0)),
    );
    add_entity(
        &mut document,
        point_entity("entity:point-b", point(10.0, 0.0)),
    );
    add_constraint(
        &mut document,
        "constraint:fixed-a",
        ConstraintKind::Fixed,
        vec![entity_target("entity:point-a")],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:fixed-b",
        ConstraintKind::Fixed,
        vec![entity_target("entity:point-b")],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:distance-a",
        ConstraintKind::Distance,
        vec![
            entity_target("entity:point-a"),
            entity_target("entity:point-b"),
        ],
        Some(ConstraintValue::FixedMm(10.0)),
    );
    assert_conflicting_add(
        &mut document,
        "constraint:distance-b",
        ConstraintKind::Distance,
        vec![
            entity_target("entity:point-a"),
            entity_target("entity:point-b"),
        ],
        Some(ConstraintValue::FixedMm(20.0)),
    );

    // D5-08
    let mut document = two_line_document("D5-08");
    add_constraint(
        &mut document,
        "constraint:parallel",
        ConstraintKind::Parallel,
        vec![
            entity_target("entity:line-a"),
            entity_target("entity:line-b"),
        ],
        None,
    );
    assert_conflicting_add(
        &mut document,
        "constraint:perpendicular",
        ConstraintKind::Perpendicular,
        vec![
            entity_target("entity:line-a"),
            entity_target("entity:line-b"),
        ],
        None,
    );

    // D5-09
    let mut document = two_line_document("D5-09");
    add_constraint(
        &mut document,
        "constraint:parallel",
        ConstraintKind::Parallel,
        vec![
            entity_target("entity:line-a"),
            entity_target("entity:line-b"),
        ],
        None,
    );
    assert_conflicting_add(
        &mut document,
        "constraint:angle",
        ConstraintKind::Angle,
        vec![
            entity_target("entity:line-a"),
            entity_target("entity:line-b"),
        ],
        Some(ConstraintValue::FixedDegrees(45.0)),
    );

    // D5-10
    let mut document = ProjectDocument::new("D5-10");
    add_entity(
        &mut document,
        point_entity("entity:point-a", point(2.0, 3.0)),
    );
    add_entity(
        &mut document,
        point_entity("entity:point-b", point(-2.0, 3.0)),
    );
    add_entity(
        &mut document,
        center_line_entity("entity:axis", point(0.0, -10.0), point(0.0, 10.0)),
    );
    add_constraint(
        &mut document,
        "constraint:symmetric",
        ConstraintKind::Symmetric,
        vec![
            entity_target("entity:point-a"),
            entity_target("entity:point-b"),
            entity_target("entity:axis"),
        ],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:point-b-fixed",
        ConstraintKind::Fixed,
        vec![entity_target("entity:point-b")],
        None,
    );
    let baseline = document.clone();
    let result = document.apply_command(DocumentCommand::UpdateEntity(point_entity(
        "entity:point-a",
        point(3.0, 3.0),
    )));
    assert!(matches!(
        result,
        Err(CommandError::Constraint(error))
            if error.code == ConstraintCommandErrorCode::Conflicting
    ));
    assert_eq!(document, baseline);

    // D5-11
    let mut document = ProjectDocument::new("D5-11");
    add_entity(
        &mut document,
        line_entity("entity:edge", point(0.0, 0.0), point(20.0, 0.0)),
    );
    add_entity(
        &mut document,
        point_entity("entity:hole-center", point(6.0, 10.0)),
    );
    for (id, targets) in [
        (
            "constraint:edge-start-fixed",
            vec![point_target("entity:edge", ControlPointKind::Start)],
        ),
        (
            "constraint:hole-fixed",
            vec![entity_target("entity:hole-center")],
        ),
    ] {
        add_constraint(&mut document, id, ConstraintKind::Fixed, targets, None);
    }
    add_constraint(
        &mut document,
        "constraint:edge-horizontal",
        ConstraintKind::Horizontal,
        vec![entity_target("entity:edge")],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:edge-length",
        ConstraintKind::SegmentLength,
        vec![entity_target("entity:edge")],
        Some(ConstraintValue::FixedMm(20.0)),
    );
    add_constraint(
        &mut document,
        "constraint:offset-from-edge-a",
        ConstraintKind::PointLineDistance,
        vec![
            entity_target("entity:hole-center"),
            entity_target("entity:edge"),
        ],
        Some(ConstraintValue::FixedMm(10.0)),
    );
    assert_conflicting_add(
        &mut document,
        "constraint:offset-from-edge-b",
        ConstraintKind::PointLineDistance,
        vec![
            entity_target("entity:hole-center"),
            entity_target("entity:edge"),
        ],
        Some(ConstraintValue::FixedMm(20.0)),
    );
}

#[test]
fn d6_deleting_constraints_recomputes_entity_statuses() {
    // D6-01
    let mut document = ProjectDocument::new("D6-01");
    add_entity(&mut document, point_entity("entity:point", point(0.0, 0.0)));
    add_constraint(
        &mut document,
        "constraint:fixed",
        ConstraintKind::Fixed,
        vec![entity_target("entity:point")],
        None,
    );
    assert_entity_status(
        &document,
        "entity:point",
        ConstraintStatus::FullyConstrained,
        0,
    );
    delete_constraint(&mut document, "constraint:fixed");
    assert_entity_status(
        &document,
        "entity:point",
        ConstraintStatus::UnderConstrained,
        2,
    );

    // D6-02, D6-03
    for (name, deleted_constraint) in [
        ("D6-02", "constraint:length"),
        ("D6-03", "constraint:horizontal"),
    ] {
        let mut document = ProjectDocument::new(name);
        add_entity(
            &mut document,
            line_entity("entity:line", point(0.0, 0.0), point(10.0, 0.0)),
        );
        add_constraint(
            &mut document,
            "constraint:start-fixed",
            ConstraintKind::Fixed,
            vec![point_target("entity:line", ControlPointKind::Start)],
            None,
        );
        add_constraint(
            &mut document,
            "constraint:horizontal",
            ConstraintKind::Horizontal,
            vec![entity_target("entity:line")],
            None,
        );
        add_constraint(
            &mut document,
            "constraint:length",
            ConstraintKind::SegmentLength,
            vec![entity_target("entity:line")],
            Some(ConstraintValue::FixedMm(10.0)),
        );
        assert_entity_status(
            &document,
            "entity:line",
            ConstraintStatus::FullyConstrained,
            0,
        );
        delete_constraint(&mut document, deleted_constraint);
        assert_entity_status(
            &document,
            "entity:line",
            ConstraintStatus::UnderConstrained,
            1,
        );
    }

    // D6-04, D6-05
    for (name, constraint_kind, constraint_id, value) in [
        (
            "D6-04",
            ConstraintKind::Radius,
            "constraint:radius",
            ConstraintValue::FixedMm(5.0),
        ),
        (
            "D6-05",
            ConstraintKind::Diameter,
            "constraint:diameter",
            ConstraintValue::FixedMm(10.0),
        ),
    ] {
        let mut document = ProjectDocument::new(name);
        add_entity(
            &mut document,
            circle_entity("entity:circle", point(0.0, 0.0), 5.0),
        );
        add_constraint(
            &mut document,
            "constraint:center-fixed",
            ConstraintKind::Fixed,
            vec![point_target("entity:circle", ControlPointKind::Center)],
            None,
        );
        add_constraint(
            &mut document,
            constraint_id,
            constraint_kind,
            vec![entity_target("entity:circle")],
            Some(value),
        );
        assert_entity_status(
            &document,
            "entity:circle",
            ConstraintStatus::FullyConstrained,
            0,
        );
        delete_constraint(&mut document, constraint_id);
        assert_entity_status(
            &document,
            "entity:circle",
            ConstraintStatus::UnderConstrained,
            1,
        );
    }

    // D6-06
    let mut document = full_arc_document("D6-06", false);
    assert_entity_status(
        &document,
        "entity:arc",
        ConstraintStatus::FullyConstrained,
        0,
    );
    delete_constraint(&mut document, "constraint:radius");
    assert_entity_status(
        &document,
        "entity:arc",
        ConstraintStatus::UnderConstrained,
        1,
    );

    // D6-07
    let mut document = line_with_fixed_endpoints_document("D6-07");
    add_constraint(
        &mut document,
        "constraint:length",
        ConstraintKind::SegmentLength,
        vec![entity_target("entity:line")],
        Some(ConstraintValue::FixedMm(10.0)),
    );
    assert_snapshot_status(&document, ConstraintStatus::OverConstrained);
    delete_constraint(&mut document, "constraint:length");
    assert_entity_status(
        &document,
        "entity:line",
        ConstraintStatus::FullyConstrained,
        0,
    );

    // D6-08
    let mut document = ProjectDocument::new("D6-08");
    add_entity(
        &mut document,
        line_entity("entity:line", point(0.0, 0.0), point(10.0, 0.0)),
    );
    add_constraint(
        &mut document,
        "constraint:length-a",
        ConstraintKind::SegmentLength,
        vec![entity_target("entity:line")],
        Some(ConstraintValue::FixedMm(10.0)),
    );
    assert_conflicting_add(
        &mut document,
        "constraint:length-b",
        ConstraintKind::SegmentLength,
        vec![entity_target("entity:line")],
        Some(ConstraintValue::FixedMm(20.0)),
    );
    assert_entity_status(
        &document,
        "entity:line",
        ConstraintStatus::UnderConstrained,
        3,
    );
}

#[test]
fn d7_entity_and_aggregate_constraint_statuses_are_visible() {
    // D7-01
    let mut document = ProjectDocument::new("D7-01");
    add_entity(&mut document, point_entity("entity:point", point(0.0, 0.0)));
    assert_entity_status(
        &document,
        "entity:point",
        ConstraintStatus::UnderConstrained,
        2,
    );

    // D7-02
    let mut document = line_with_fixed_endpoints_document("D7-02");
    assert_entity_status(
        &document,
        "entity:line",
        ConstraintStatus::FullyConstrained,
        0,
    );

    // D7-03
    add_constraint(
        &mut document,
        "constraint:length",
        ConstraintKind::SegmentLength,
        vec![entity_target("entity:line")],
        Some(ConstraintValue::FixedMm(10.0)),
    );
    assert_entity_status(
        &document,
        "entity:line",
        ConstraintStatus::OverConstrained,
        0,
    );

    // D7-04
    let mut document = ProjectDocument::new("D7-04");
    add_entity(
        &mut document,
        arc_entity(
            "entity:arc",
            point(0.0, 0.0),
            5.0,
            0.0,
            std::f64::consts::FRAC_PI_2,
        ),
    );
    assert_entity_status(
        &document,
        "entity:arc",
        ConstraintStatus::UnderConstrained,
        5,
    );

    // D7-05
    let mut document = ProjectDocument::new("D7-05");
    add_entity(
        &mut document,
        circle_entity("entity:circle", point(0.0, 0.0), 10.0),
    );
    add_constraint(
        &mut document,
        "constraint:radius",
        ConstraintKind::Radius,
        vec![entity_target("entity:circle")],
        Some(ConstraintValue::FixedMm(10.0)),
    );
    add_constraint(
        &mut document,
        "constraint:diameter",
        ConstraintKind::Diameter,
        vec![entity_target("entity:circle")],
        Some(ConstraintValue::FixedMm(20.0)),
    );
    assert_snapshot_status(&document, ConstraintStatus::OverConstrained);

    // D7-06
    let mut document = ProjectDocument::new("D7-06");
    add_entity(
        &mut document,
        line_entity("entity:line", point(0.0, 0.0), point(10.0, 0.0)),
    );
    add_constraint(
        &mut document,
        "constraint:length",
        ConstraintKind::SegmentLength,
        vec![entity_target("entity:line")],
        Some(ConstraintValue::FixedMm(10.0)),
    );
    assert_snapshot_status(&document, ConstraintStatus::UnderConstrained);

    // D7-07
    let document = constrained_line_rectangle_document("D7-07");
    assert_snapshot_status(&document, ConstraintStatus::FullyConstrained);
}

#[test]
fn d8_coincident_order_dimension_conflict_and_group_recompute_are_covered() {
    // D8-01
    let mut document = ProjectDocument::new("D8-01");
    add_entity(
        &mut document,
        line_entity("entity:line-a", point(0.0, 0.0), point(10.0, 0.0)),
    );
    add_entity(
        &mut document,
        line_entity("entity:line-b", point(10.0, 0.0), point(20.0, 0.0)),
    );
    add_constraint(
        &mut document,
        "constraint:coincident",
        ConstraintKind::Coincident,
        vec![
            point_target("entity:line-a", ControlPointKind::End),
            point_target("entity:line-b", ControlPointKind::Start),
        ],
        None,
    );
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

    // D8-02
    let mut document = ProjectDocument::new("D8-02");
    add_entity(
        &mut document,
        line_entity("entity:free", point(0.0, 0.0), point(5.0, 5.0)),
    );
    add_entity(
        &mut document,
        line_entity("entity:horizontal", point(20.0, 10.0), point(30.0, 10.0)),
    );
    add_constraint(
        &mut document,
        "constraint:horizontal",
        ConstraintKind::Horizontal,
        vec![entity_target("entity:horizontal")],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:coincident",
        ConstraintKind::Coincident,
        vec![
            point_target("entity:free", ControlPointKind::End),
            point_target("entity:horizontal", ControlPointKind::Start),
        ],
        None,
    );
    let free = line_geometry(document.entity("entity:free").expect("free line"));
    let horizontal = line_geometry(
        document
            .entity("entity:horizontal")
            .expect("horizontal line"),
    );
    assert_approx_eq(free.end.x_mm, horizontal.start.x_mm);
    assert_approx_eq(free.end.y_mm, horizontal.start.y_mm);
    assert_approx_eq(horizontal.start.y_mm, horizontal.end.y_mm);

    // D8-03
    let mut document = ProjectDocument::new("D8-03");
    add_entity(
        &mut document,
        line_entity("entity:free", point(0.0, 0.0), point(5.0, 5.0)),
    );
    add_entity(
        &mut document,
        line_entity("entity:horizontal", point(20.0, 10.0), point(30.0, 10.0)),
    );
    add_constraint(
        &mut document,
        "constraint:horizontal",
        ConstraintKind::Horizontal,
        vec![entity_target("entity:horizontal")],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:coincident",
        ConstraintKind::Coincident,
        vec![
            point_target("entity:horizontal", ControlPointKind::Start),
            point_target("entity:free", ControlPointKind::End),
        ],
        None,
    );
    let free = line_geometry(document.entity("entity:free").expect("free line"));
    let horizontal = line_geometry(
        document
            .entity("entity:horizontal")
            .expect("horizontal line"),
    );
    assert_approx_eq(free.end.x_mm, horizontal.start.x_mm);
    assert_approx_eq(free.end.y_mm, horizontal.start.y_mm);
    assert_approx_eq(horizontal.start.y_mm, horizontal.end.y_mm);

    // D8-04
    let mut document = constrained_line_rectangle_document("D8-04");
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

    // D8-05
    let mut document = constrained_line_rectangle_document("D8-05");
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

    // D8-06
    let mut document = fixed_two_corner_rectangle_document("D8-06");
    let baseline = document.clone();
    let result = document.apply_command(DocumentCommand::UpdateConstraint(constraint(
        "constraint:width",
        ConstraintKind::SegmentLength,
        vec![entity_target("entity:bottom")],
        Some(ConstraintValue::FixedMm(60.0)),
    )));
    assert!(matches!(
        result,
        Err(CommandError::Constraint(error))
            if error.code == ConstraintCommandErrorCode::Conflicting
    ));
    assert_eq!(document, baseline);

    // D8-07
    let mut document = ProjectDocument::new("D8-07");
    for id in ["entity:point-a", "entity:point-b", "entity:point-c"] {
        add_entity(&mut document, point_entity(id, point(0.0, 0.0)));
    }
    add_constraint(
        &mut document,
        "constraint:ab",
        ConstraintKind::Coincident,
        vec![
            entity_target("entity:point-a"),
            entity_target("entity:point-b"),
        ],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:bc",
        ConstraintKind::Coincident,
        vec![
            entity_target("entity:point-b"),
            entity_target("entity:point-c"),
        ],
        None,
    );
    let groups = document.coincident_point_groups();
    assert_eq!(groups.len(), 1);
    assert_eq!(groups[0].targets.len(), 3);

    delete_constraint(&mut document, "constraint:bc");
    let groups = document.coincident_point_groups();
    assert_eq!(groups.len(), 1);
    assert_eq!(groups[0].targets.len(), 2);
}

fn add_entity(document: &mut ProjectDocument, entity: Entity) {
    document
        .apply_command(DocumentCommand::AddEntity(entity))
        .expect("entity should be added");
}

fn add_constraint(
    document: &mut ProjectDocument,
    id: &str,
    kind: ConstraintKind,
    targets: Vec<kawacad_core::constraints::ConstraintTarget>,
    value: Option<ConstraintValue>,
) {
    document
        .apply_command(DocumentCommand::AddConstraint(constraint(
            id, kind, targets, value,
        )))
        .expect("constraint should be added");
}

fn delete_constraint(document: &mut ProjectDocument, id: &str) {
    document
        .apply_command(DocumentCommand::DeleteConstraint(id.to_owned()))
        .expect("constraint should be deleted");
}

fn assert_conflicting_add(
    document: &mut ProjectDocument,
    id: &str,
    kind: ConstraintKind,
    targets: Vec<kawacad_core::constraints::ConstraintTarget>,
    value: Option<ConstraintValue>,
) {
    let baseline = document.clone();
    let result = document.apply_command(DocumentCommand::AddConstraint(constraint(
        id, kind, targets, value,
    )));
    assert!(matches!(
        result,
        Err(CommandError::Constraint(error))
            if error.code == ConstraintCommandErrorCode::Conflicting
    ));
    assert_eq!(document, &baseline);
}

fn assert_entity_status(
    document: &ProjectDocument,
    entity_id: &str,
    expected_status: ConstraintStatus,
    expected_remaining_dof: usize,
) {
    let status = document
        .entity_constraint_statuses()
        .into_iter()
        .find(|status| status.entity_id == entity_id)
        .unwrap_or_else(|| panic!("{entity_id} status should exist"));
    assert_eq!(
        status.status,
        expected_status,
        "{entity_id} status; constraints={:?}",
        document.constraints()
    );
    assert_eq!(
        status.remaining_dof, expected_remaining_dof,
        "{entity_id} remaining DoF"
    );
}

fn assert_snapshot_status(document: &ProjectDocument, expected: ConstraintStatus) {
    assert_eq!(
        document
            .drawing_snapshot(CanvasViewMode::EditDisplay)
            .constraint_status,
        expected
    );
}

fn two_line_document(name: &str) -> ProjectDocument {
    let mut document = ProjectDocument::new(name);
    add_entity(
        &mut document,
        line_entity("entity:line-a", point(0.0, 0.0), point(10.0, 0.0)),
    );
    add_entity(
        &mut document,
        line_entity("entity:line-b", point(0.0, 0.0), point(8.0, 5.0)),
    );
    document
}

fn line_with_fixed_endpoints_document(name: &str) -> ProjectDocument {
    let mut document = ProjectDocument::new(name);
    add_entity(
        &mut document,
        line_entity("entity:line", point(0.0, 0.0), point(10.0, 0.0)),
    );
    add_constraint(
        &mut document,
        "constraint:start-fixed",
        ConstraintKind::Fixed,
        vec![point_target("entity:line", ControlPointKind::Start)],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:end-fixed",
        ConstraintKind::Fixed,
        vec![point_target("entity:line", ControlPointKind::End)],
        None,
    );
    document
}

fn full_arc_document(name: &str, use_end_anchor: bool) -> ProjectDocument {
    let mut document = ProjectDocument::new(name);
    add_entity(
        &mut document,
        arc_entity(
            "entity:arc",
            point(0.0, 0.0),
            5.0,
            0.0,
            std::f64::consts::FRAC_PI_2,
        ),
    );
    add_constraint(
        &mut document,
        "constraint:center-fixed",
        ConstraintKind::Fixed,
        vec![point_target("entity:arc", ControlPointKind::Center)],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:radius",
        ConstraintKind::Radius,
        vec![entity_target("entity:arc")],
        Some(ConstraintValue::FixedMm(5.0)),
    );
    add_constraint(
        &mut document,
        "constraint:start-fixed",
        ConstraintKind::Fixed,
        vec![point_target("entity:arc", ControlPointKind::Start)],
        None,
    );
    if use_end_anchor {
        add_entity(
            &mut document,
            point_entity("entity:end-anchor", point(0.0, 5.0)),
        );
        add_constraint(
            &mut document,
            "constraint:end-anchor-fixed",
            ConstraintKind::Fixed,
            vec![entity_target("entity:end-anchor")],
            None,
        );
        add_constraint(
            &mut document,
            "constraint:end-coincident",
            ConstraintKind::Coincident,
            vec![
                point_target("entity:arc", ControlPointKind::End),
                entity_target("entity:end-anchor"),
            ],
            None,
        );
    } else {
        add_constraint(
            &mut document,
            "constraint:end-fixed",
            ConstraintKind::Fixed,
            vec![point_target("entity:arc", ControlPointKind::End)],
            None,
        );
    }
    document
}

fn constrained_line_rectangle_document(name: &str) -> ProjectDocument {
    let mut document = ProjectDocument::new(name);
    for entity in [
        line_entity("entity:bottom", point(0.0, 0.0), point(50.0, 0.0)),
        line_entity("entity:right", point(50.0, 0.0), point(50.0, 20.0)),
        line_entity("entity:top", point(50.0, 20.0), point(0.0, 20.0)),
        line_entity("entity:left", point(0.0, 20.0), point(0.0, 0.0)),
    ] {
        add_entity(&mut document, entity);
    }
    for (id, first, second) in [
        (
            "constraint:bottom-left",
            point_target("entity:bottom", ControlPointKind::Start),
            point_target("entity:left", ControlPointKind::End),
        ),
        (
            "constraint:bottom-right",
            point_target("entity:bottom", ControlPointKind::End),
            point_target("entity:right", ControlPointKind::Start),
        ),
        (
            "constraint:top-right",
            point_target("entity:top", ControlPointKind::Start),
            point_target("entity:right", ControlPointKind::End),
        ),
        (
            "constraint:top-left",
            point_target("entity:top", ControlPointKind::End),
            point_target("entity:left", ControlPointKind::Start),
        ),
    ] {
        add_constraint(
            &mut document,
            id,
            ConstraintKind::Coincident,
            vec![first, second],
            None,
        );
    }
    for (id, kind, entity_id) in [
        (
            "constraint:bottom-horizontal",
            ConstraintKind::Horizontal,
            "entity:bottom",
        ),
        (
            "constraint:top-horizontal",
            ConstraintKind::Horizontal,
            "entity:top",
        ),
        (
            "constraint:left-vertical",
            ConstraintKind::Vertical,
            "entity:left",
        ),
        (
            "constraint:right-vertical",
            ConstraintKind::Vertical,
            "entity:right",
        ),
    ] {
        add_constraint(
            &mut document,
            id,
            kind,
            vec![entity_target(entity_id)],
            None,
        );
    }
    add_constraint(
        &mut document,
        "constraint:anchor",
        ConstraintKind::Fixed,
        vec![point_target("entity:bottom", ControlPointKind::Start)],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:width",
        ConstraintKind::SegmentLength,
        vec![entity_target("entity:bottom")],
        Some(ConstraintValue::FixedMm(50.0)),
    );
    add_constraint(
        &mut document,
        "constraint:height",
        ConstraintKind::SegmentLength,
        vec![entity_target("entity:left")],
        Some(ConstraintValue::FixedMm(20.0)),
    );
    document
}

fn assert_rectangle_statuses(document: &ProjectDocument, expected: ConstraintStatus) {
    for entity_id in ["entity:bottom", "entity:right", "entity:top", "entity:left"] {
        assert_entity_status(document, entity_id, expected, 0);
    }
}

fn fixed_two_corner_rectangle_document(name: &str) -> ProjectDocument {
    let mut document = ProjectDocument::new(name);
    for entity in [
        line_entity("entity:bottom", point(0.0, 0.0), point(50.0, 0.0)),
        line_entity("entity:right", point(50.0, 0.0), point(50.0, 20.0)),
        line_entity("entity:top", point(50.0, 20.0), point(0.0, 20.0)),
        line_entity("entity:left", point(0.0, 20.0), point(0.0, 0.0)),
    ] {
        add_entity(&mut document, entity);
    }
    for (id, first, second) in [
        (
            "constraint:bottom-left",
            point_target("entity:bottom", ControlPointKind::Start),
            point_target("entity:left", ControlPointKind::End),
        ),
        (
            "constraint:bottom-right",
            point_target("entity:bottom", ControlPointKind::End),
            point_target("entity:right", ControlPointKind::Start),
        ),
        (
            "constraint:top-right",
            point_target("entity:top", ControlPointKind::Start),
            point_target("entity:right", ControlPointKind::End),
        ),
        (
            "constraint:top-left",
            point_target("entity:top", ControlPointKind::End),
            point_target("entity:left", ControlPointKind::Start),
        ),
    ] {
        add_constraint(
            &mut document,
            id,
            ConstraintKind::Coincident,
            vec![first, second],
            None,
        );
    }
    for (id, kind, entity_id) in [
        (
            "constraint:bottom-horizontal",
            ConstraintKind::Horizontal,
            "entity:bottom",
        ),
        (
            "constraint:top-horizontal",
            ConstraintKind::Horizontal,
            "entity:top",
        ),
        (
            "constraint:left-vertical",
            ConstraintKind::Vertical,
            "entity:left",
        ),
        (
            "constraint:right-vertical",
            ConstraintKind::Vertical,
            "entity:right",
        ),
    ] {
        add_constraint(
            &mut document,
            id,
            kind,
            vec![entity_target(entity_id)],
            None,
        );
    }
    add_constraint(
        &mut document,
        "constraint:bottom-left-fixed",
        ConstraintKind::Fixed,
        vec![point_target("entity:bottom", ControlPointKind::Start)],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:bottom-right-fixed",
        ConstraintKind::Fixed,
        vec![point_target("entity:bottom", ControlPointKind::End)],
        None,
    );
    add_constraint(
        &mut document,
        "constraint:width",
        ConstraintKind::SegmentLength,
        vec![entity_target("entity:bottom")],
        Some(ConstraintValue::FixedMm(50.0)),
    );
    add_constraint(
        &mut document,
        "constraint:height",
        ConstraintKind::SegmentLength,
        vec![entity_target("entity:left")],
        Some(ConstraintValue::FixedMm(20.0)),
    );
    document
}

fn line_geometry(entity: &Entity) -> LineSegment {
    match &entity.kind {
        EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => *line,
        other => panic!("expected line entity, got {other:?}"),
    }
}

#[allow(dead_code)]
fn point_xy(entity: &Entity) -> Point2 {
    match &entity.kind {
        EntityKind::Point(point) => *point,
        other => panic!("expected point entity, got {other:?}"),
    }
}
