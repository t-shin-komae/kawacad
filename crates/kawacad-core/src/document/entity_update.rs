use super::*;

pub(in crate::document) fn set_line_end_for_entity_target(
    entities: &mut [Entity],
    target: &ConstraintTarget,
    end: Point2,
) -> CommandResult {
    set_line_endpoint_for_entity_target(entities, target, ControlPointKind::End, end)
}

pub(in crate::document) fn set_line_endpoint_for_entity_target(
    entities: &mut [Entity],
    target: &ConstraintTarget,
    endpoint: ControlPointKind,
    point: Point2,
) -> CommandResult {
    let entity_id = constraint_target_entity_id(target);
    let entity = find_entity_mut(entities, entity_id)
        .ok_or_else(|| CommandError::broken_reference("constraint", "entity", entity_id))?;
    match target {
        ConstraintTarget::Entity(_) => match &mut entity.kind {
            EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => {
                match endpoint {
                    ControlPointKind::Start => line.start = point,
                    ControlPointKind::End => line.end = point,
                    ControlPointKind::Center => {
                        return Err(CommandError::InvalidValue {
                            field: "constraint targets",
                            reason: "line constraints require start or end endpoints",
                        });
                    }
                }
                entity.validate().map_err(CommandError::InvalidEntity)
            }
            _ => Err(CommandError::InvalidValue {
                field: "constraint targets",
                reason: "entity target must resolve to a line-compatible entity",
            }),
        },
        ConstraintTarget::ControlPoint { .. } => Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "line constraints require entity targets",
        }),
    }
}

pub(in crate::document) fn set_line_length_for_target(
    entities: &mut [Entity],
    target: &ConstraintTarget,
    length_mm: f64,
) -> CommandResult {
    let entity_id = constraint_target_entity_id(target);
    let entity = find_entity_mut(entities, entity_id)
        .ok_or_else(|| CommandError::broken_reference("constraint", "entity", entity_id))?;
    match target {
        ConstraintTarget::Entity(_) => match &mut entity.kind {
            EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => {
                let direction = normalized_direction(line.start, line.end);
                line.end = Point2::new(
                    line.start.x_mm + direction.x_mm * length_mm,
                    line.start.y_mm + direction.y_mm * length_mm,
                );
                entity.validate().map_err(CommandError::InvalidEntity)
            }
            _ => Err(CommandError::InvalidValue {
                field: "constraint targets",
                reason: "entity target must resolve to a line-compatible entity",
            }),
        },
        ConstraintTarget::ControlPoint { .. } => Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "line constraints require line targets",
        }),
    }
}

pub(in crate::document) fn set_circle_diameter_for_target(
    entities: &mut [Entity],
    target: &ConstraintTarget,
    diameter_mm: f64,
) -> CommandResult {
    let entity_id = constraint_target_entity_id(target);
    let entity = find_entity_mut(entities, entity_id)
        .ok_or_else(|| CommandError::broken_reference("constraint", "entity", entity_id))?;
    match target {
        ConstraintTarget::Entity(_) => match &mut entity.kind {
            EntityKind::Circle(circle) => {
                circle.radius_mm = diameter_mm / 2.0;
                entity.validate().map_err(CommandError::InvalidEntity)
            }
            _ => Err(CommandError::InvalidValue {
                field: "constraint targets",
                reason: "entity target must resolve to a circle-compatible entity",
            }),
        },
        ConstraintTarget::ControlPoint { .. } => Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "diameter constraints require entity targets",
        }),
    }
}

pub(in crate::document) fn set_radius_for_target(
    entities: &mut [Entity],
    target: &ConstraintTarget,
    radius_mm: f64,
) -> CommandResult {
    let entity_id = constraint_target_entity_id(target);
    let entity = find_entity_mut(entities, entity_id)
        .ok_or_else(|| CommandError::broken_reference("constraint", "entity", entity_id))?;
    match target {
        ConstraintTarget::Entity(_) => match &mut entity.kind {
            EntityKind::Circle(circle) => {
                circle.radius_mm = radius_mm;
                entity.validate().map_err(CommandError::InvalidEntity)
            }
            EntityKind::Arc(arc) => {
                arc.radius_mm = radius_mm;
                entity.validate().map_err(CommandError::InvalidEntity)
            }
            _ => Err(CommandError::InvalidValue {
                field: "constraint targets",
                reason: "entity target must resolve to a radius-compatible entity",
            }),
        },
        ConstraintTarget::ControlPoint { .. } => Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "radius constraints require entity targets",
        }),
    }
}

pub(in crate::document) fn set_point_for_target(
    entities: &mut [Entity],
    target: &ConstraintTarget,
    point: Point2,
) -> CommandResult {
    let entity_id = constraint_target_entity_id(target);
    let entity = find_entity_mut(entities, entity_id)
        .ok_or_else(|| CommandError::broken_reference("constraint", "entity", entity_id))?;
    match target {
        ConstraintTarget::Entity(_) => match &mut entity.kind {
            EntityKind::Point(entity_point) => {
                *entity_point = point;
                entity.validate().map_err(CommandError::InvalidEntity)
            }
            _ => Err(CommandError::InvalidValue {
                field: "constraint targets",
                reason: "entity target must resolve to a point-compatible entity",
            }),
        },
        ConstraintTarget::ControlPoint {
            point: control_point,
            ..
        } => {
            match (&mut entity.kind, *control_point) {
                (
                    EntityKind::LineSegment(line) | EntityKind::CenterLine(line),
                    ControlPointKind::Start,
                ) => {
                    line.start = point;
                }
                (
                    EntityKind::LineSegment(line) | EntityKind::CenterLine(line),
                    ControlPointKind::End,
                ) => {
                    line.end = point;
                }
                (EntityKind::Circle(circle), ControlPointKind::Center) => {
                    circle.center = point;
                }
                (EntityKind::Arc(arc), ControlPointKind::Center) => {
                    arc.center = point;
                }
                (EntityKind::Arc(arc), ControlPointKind::Start) => {
                    *arc = arc_with_moved_endpoint_preserving_opposite(
                        *arc,
                        ControlPointKind::Start,
                        point,
                    )?;
                }
                (EntityKind::Arc(arc), ControlPointKind::End) => {
                    *arc = arc_with_moved_endpoint_preserving_opposite(
                        *arc,
                        ControlPointKind::End,
                        point,
                    )?;
                }
                _ => {
                    return Err(CommandError::InvalidValue {
                        field: "constraint targets",
                        reason: "control point target is incompatible with the referenced entity",
                    });
                }
            }
            entity.validate().map_err(CommandError::InvalidEntity)
        }
    }
}

fn arc_with_moved_endpoint_preserving_opposite(
    arc: crate::geometry::Arc,
    endpoint: ControlPointKind,
    point: Point2,
) -> Result<crate::geometry::Arc, CommandError> {
    let previous_sweep = arc.sweep_angle_rad;
    let previous_start = point_on_arc(&arc, arc.start_angle_rad);
    let previous_end = point_on_arc(&arc, arc.start_angle_rad + arc.sweep_angle_rad);
    let (start, end) = match endpoint {
        ControlPointKind::Start => (point, previous_end),
        ControlPointKind::End => (previous_start, point),
        ControlPointKind::Center => {
            return Err(CommandError::InvalidValue {
                field: "constraint targets",
                reason: "arc endpoint must be start or end",
            });
        }
    };
    let chord = Point2::new(end.x_mm - start.x_mm, end.y_mm - start.y_mm);
    let chord_length_squared = chord.x_mm * chord.x_mm + chord.y_mm * chord.y_mm;
    if chord_length_squared <= GEOMETRY_EPSILON_MM * GEOMETRY_EPSILON_MM {
        return Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "arc endpoints must not coincide",
        });
    }
    let midpoint = Point2::new((start.x_mm + end.x_mm) / 2.0, (start.y_mm + end.y_mm) / 2.0);
    let center_offset = Point2::new(
        arc.center.x_mm - midpoint.x_mm,
        arc.center.y_mm - midpoint.y_mm,
    );
    let projection = dot_product(center_offset, chord) / chord_length_squared;
    let center = Point2::new(
        arc.center.x_mm - chord.x_mm * projection,
        arc.center.y_mm - chord.y_mm * projection,
    );
    let radius_mm = distance_between(center, start);
    if radius_mm <= GEOMETRY_EPSILON_MM || !radius_mm.is_finite() {
        return Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "arc endpoint must not coincide with the arc center",
        });
    }
    let start_angle_rad = (start.y_mm - center.y_mm).atan2(start.x_mm - center.x_mm);
    let end_angle_rad = (end.y_mm - center.y_mm).atan2(end.x_mm - center.x_mm);
    let raw_sweep = if previous_sweep < 0.0 {
        -normalize_positive_angle(start_angle_rad - end_angle_rad)
    } else {
        normalize_positive_angle(end_angle_rad - start_angle_rad)
    };
    let sweep_angle_rad = equivalent_sweep_closest_to(raw_sweep, previous_sweep);
    Ok(crate::geometry::Arc {
        center,
        radius_mm,
        start_angle_rad,
        sweep_angle_rad,
    })
}

fn normalize_positive_angle(angle_rad: f64) -> f64 {
    angle_rad.rem_euclid(std::f64::consts::TAU)
}

fn equivalent_sweep_closest_to(raw_sweep: f64, reference_sweep: f64) -> f64 {
    let tau = std::f64::consts::TAU;
    let mut best = raw_sweep;
    let mut best_distance = (best - reference_sweep).abs();
    for offset in [-2.0 * tau, -tau, tau, 2.0 * tau] {
        let candidate = raw_sweep + offset;
        let distance = (candidate - reference_sweep).abs();
        if distance < best_distance {
            best = candidate;
            best_distance = distance;
        }
    }
    best
}

pub(in crate::document) fn moved_point_targets_between(
    previous_entities: &[Entity],
    updated_entities: &[Entity],
) -> Vec<ConstraintTarget> {
    previous_entities
        .iter()
        .filter_map(|previous| {
            let updated = updated_entities
                .iter()
                .find(|candidate| candidate.id == previous.id)?;
            Some((previous, updated))
        })
        .flat_map(|(previous, updated)| {
            point_targets_for_entity(previous)
                .into_iter()
                .filter_map(|target| {
                    let previous_point =
                        point_for_target(std::slice::from_ref(previous), &target).ok()?;
                    let updated_point =
                        point_for_target(std::slice::from_ref(updated), &target).ok()?;
                    (!points_approximately_equal(previous_point, updated_point)).then_some(target)
                })
        })
        .collect()
}

pub(in crate::document) fn project_entity_update_to_axis_constraints(
    previous: &Entity,
    updated: &mut Entity,
    constraints: &[Constraint],
) {
    let horizontal = constraints.iter().any(|constraint| {
        matches!(constraint.kind, ConstraintKind::Horizontal)
            && constraint.targets == [ConstraintTarget::Entity(previous.id.clone())]
    });
    let vertical = constraints.iter().any(|constraint| {
        matches!(constraint.kind, ConstraintKind::Vertical)
            && constraint.targets == [ConstraintTarget::Entity(previous.id.clone())]
    });

    let (EntityKind::LineSegment(previous_line), EntityKind::LineSegment(updated_line)) =
        (&previous.kind, &mut updated.kind)
    else {
        return;
    };

    if horizontal && (updated_line.start.y_mm - updated_line.end.y_mm).abs() > GEOMETRY_EPSILON_MM {
        let start_moved = !points_approximately_equal(previous_line.start, updated_line.start);
        let end_moved = !points_approximately_equal(previous_line.end, updated_line.end);
        let y_mm = match (start_moved, end_moved) {
            (true, false) => updated_line.end.y_mm,
            (false, true) => updated_line.start.y_mm,
            (true, true) => {
                let start_delta = updated_line.start.y_mm - previous_line.start.y_mm;
                let end_delta = updated_line.end.y_mm - previous_line.end.y_mm;
                previous_line.start.y_mm + ((start_delta + end_delta) / 2.0)
            }
            (false, false) => updated_line.start.y_mm,
        };
        updated_line.start.y_mm = y_mm;
        updated_line.end.y_mm = y_mm;
    }

    if vertical && (updated_line.start.x_mm - updated_line.end.x_mm).abs() > GEOMETRY_EPSILON_MM {
        let start_moved = !points_approximately_equal(previous_line.start, updated_line.start);
        let end_moved = !points_approximately_equal(previous_line.end, updated_line.end);
        let x_mm = match (start_moved, end_moved) {
            (true, false) => updated_line.end.x_mm,
            (false, true) => updated_line.start.x_mm,
            (true, true) => {
                let start_delta = updated_line.start.x_mm - previous_line.start.x_mm;
                let end_delta = updated_line.end.x_mm - previous_line.end.x_mm;
                previous_line.start.x_mm + ((start_delta + end_delta) / 2.0)
            }
            (false, false) => updated_line.start.x_mm,
        };
        updated_line.start.x_mm = x_mm;
        updated_line.end.x_mm = x_mm;
    }
}

pub(in crate::document) fn project_entity_update_to_connected_axis_constraints(
    previous_entities: &[Entity],
    updated_entities: &mut [Entity],
    updated_index: usize,
    constraints: &[Constraint],
) -> CommandResult {
    let previous = &previous_entities[updated_index];
    for target in point_targets_for_entity(previous) {
        let previous_point = point_for_target(previous_entities, &target)?;
        let mut projected_point = point_for_target(updated_entities, &target)?;
        let mut projected = false;
        for constraint in constraints {
            if !matches!(constraint.kind, ConstraintKind::Coincident) {
                continue;
            }
            let Some(other_target) = coincident_counterpart(&target, constraint) else {
                continue;
            };
            let other_entity_id = constraint_target_entity_id(other_target);
            if entity_has_axis_constraint(other_entity_id, ConstraintKind::Vertical, constraints) {
                projected_point.x_mm = previous_point.x_mm;
                projected = true;
            }
            if entity_has_axis_constraint(other_entity_id, ConstraintKind::Horizontal, constraints)
            {
                projected_point.y_mm = previous_point.y_mm;
                projected = true;
            }
        }
        if projected {
            set_point_for_target(updated_entities, &target, projected_point)?;
        }
    }
    Ok(())
}

pub(in crate::document) fn point_targets_for_entity(entity: &Entity) -> Vec<ConstraintTarget> {
    match &entity.kind {
        EntityKind::Point(_) => vec![ConstraintTarget::Entity(entity.id.clone())],
        EntityKind::LineSegment(_) | EntityKind::CenterLine(_) => vec![
            ConstraintTarget::ControlPoint {
                entity_id: entity.id.clone(),
                point: ControlPointKind::Start,
            },
            ConstraintTarget::ControlPoint {
                entity_id: entity.id.clone(),
                point: ControlPointKind::End,
            },
        ],
        EntityKind::Circle(_) => vec![ConstraintTarget::ControlPoint {
            entity_id: entity.id.clone(),
            point: ControlPointKind::Center,
        }],
        EntityKind::Arc(_) => vec![
            ConstraintTarget::ControlPoint {
                entity_id: entity.id.clone(),
                point: ControlPointKind::Center,
            },
            ConstraintTarget::ControlPoint {
                entity_id: entity.id.clone(),
                point: ControlPointKind::Start,
            },
            ConstraintTarget::ControlPoint {
                entity_id: entity.id.clone(),
                point: ControlPointKind::End,
            },
        ],
    }
}

fn coincident_counterpart<'a>(
    target: &ConstraintTarget,
    constraint: &'a Constraint,
) -> Option<&'a ConstraintTarget> {
    let [first, second] = constraint.targets.as_slice() else {
        return None;
    };
    if first == target {
        Some(second)
    } else if second == target {
        Some(first)
    } else {
        None
    }
}

fn entity_has_axis_constraint(
    entity_id: &str,
    kind: ConstraintKind,
    constraints: &[Constraint],
) -> bool {
    constraints.iter().any(|constraint| {
        constraint.kind == kind
            && constraint.targets == [ConstraintTarget::Entity(entity_id.to_owned())]
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::geometry::{Arc, Circle, Entity, EntityKind, LineSegment};

    #[test]
    fn set_point_for_target_updates_each_supported_control_point() {
        let mut entities = vec![
            Entity::new("entity:point", EntityKind::Point(Point2::new(0.0, 0.0))),
            Entity::new(
                "entity:line",
                EntityKind::LineSegment(LineSegment::new(
                    Point2::new(0.0, 0.0),
                    Point2::new(10.0, 0.0),
                )),
            ),
            Entity::new(
                "entity:circle",
                EntityKind::Circle(Circle {
                    center: Point2::new(5.0, 5.0),
                    radius_mm: 2.0,
                }),
            ),
            Entity::new(
                "entity:arc",
                EntityKind::Arc(Arc {
                    center: Point2::new(10.0, 10.0),
                    radius_mm: 5.0,
                    start_angle_rad: 0.0,
                    sweep_angle_rad: std::f64::consts::FRAC_PI_2,
                }),
            ),
        ];

        set_point_for_target(
            &mut entities,
            &ConstraintTarget::Entity("entity:point".to_owned()),
            Point2::new(1.0, 2.0),
        )
        .unwrap();
        set_point_for_target(
            &mut entities,
            &ConstraintTarget::ControlPoint {
                entity_id: "entity:line".to_owned(),
                point: ControlPointKind::Start,
            },
            Point2::new(3.0, 4.0),
        )
        .unwrap();
        set_point_for_target(
            &mut entities,
            &ConstraintTarget::ControlPoint {
                entity_id: "entity:line".to_owned(),
                point: ControlPointKind::End,
            },
            Point2::new(13.0, 14.0),
        )
        .unwrap();
        set_point_for_target(
            &mut entities,
            &ConstraintTarget::ControlPoint {
                entity_id: "entity:circle".to_owned(),
                point: ControlPointKind::Center,
            },
            Point2::new(6.0, 7.0),
        )
        .unwrap();
        set_point_for_target(
            &mut entities,
            &ConstraintTarget::ControlPoint {
                entity_id: "entity:arc".to_owned(),
                point: ControlPointKind::Start,
            },
            Point2::new(20.0, 10.0),
        )
        .unwrap();
        set_point_for_target(
            &mut entities,
            &ConstraintTarget::ControlPoint {
                entity_id: "entity:arc".to_owned(),
                point: ControlPointKind::End,
            },
            Point2::new(10.0, 20.0),
        )
        .unwrap();

        assert_eq!(
            point_for_target(
                &entities,
                &ConstraintTarget::Entity("entity:point".to_owned())
            )
            .unwrap(),
            Point2::new(1.0, 2.0)
        );
        assert_eq!(
            point_for_target(
                &entities,
                &ConstraintTarget::ControlPoint {
                    entity_id: "entity:line".to_owned(),
                    point: ControlPointKind::Start
                }
            )
            .unwrap(),
            Point2::new(3.0, 4.0)
        );
        assert_eq!(
            point_for_target(
                &entities,
                &ConstraintTarget::ControlPoint {
                    entity_id: "entity:line".to_owned(),
                    point: ControlPointKind::End
                }
            )
            .unwrap(),
            Point2::new(13.0, 14.0)
        );
        assert_eq!(
            point_for_target(
                &entities,
                &ConstraintTarget::ControlPoint {
                    entity_id: "entity:circle".to_owned(),
                    point: ControlPointKind::Center
                }
            )
            .unwrap(),
            Point2::new(6.0, 7.0)
        );
        let arc = find_entity(&entities, "entity:arc").unwrap();
        if let EntityKind::Arc(arc) = &arc.kind {
            assert!(approx_eq(point_on_arc(arc, arc.start_angle_rad).x_mm, 20.0));
            assert!(approx_eq(point_on_arc(arc, arc.start_angle_rad).y_mm, 10.0));
            assert!(approx_eq(
                point_on_arc(arc, arc.start_angle_rad + arc.sweep_angle_rad).x_mm,
                10.0
            ));
            assert!(approx_eq(
                point_on_arc(arc, arc.start_angle_rad + arc.sweep_angle_rad).y_mm,
                20.0
            ));
        } else {
            panic!("expected arc");
        }
    }
}
