use super::*;

pub(in crate::document) fn constraint_target_entity_id(target: &ConstraintTarget) -> &str {
    match target {
        ConstraintTarget::Entity(entity_id) => entity_id,
        ConstraintTarget::ControlPoint { entity_id, .. } => entity_id,
    }
}

pub(in crate::document) fn constraint_target_id(target: &ConstraintTarget) -> String {
    match target {
        ConstraintTarget::Entity(entity_id) => entity_id.clone(),
        ConstraintTarget::ControlPoint { entity_id, point } => {
            format!("{entity_id}#{}", control_point_name(*point))
        }
    }
}

fn control_point_name(point: ControlPointKind) -> &'static str {
    match point {
        ControlPointKind::Start => "start",
        ControlPointKind::End => "end",
        ControlPointKind::Center => "center",
    }
}

pub(in crate::document) fn constraint_targets_entity(
    constraint: &Constraint,
    entity_id: &str,
) -> bool {
    constraint
        .targets
        .iter()
        .any(|target| constraint_target_entity_id(target) == entity_id)
}

pub(in crate::document) fn line_from_single_target(
    document: &ProjectDocument,
    constraint: &Constraint,
) -> Option<crate::geometry::LineSegment> {
    match constraint.targets.as_slice() {
        [target] => line_for_entity_target(&document.entities, target).ok(),
        _ => None,
    }
}

pub(in crate::document) fn circle_from_single_target(
    document: &ProjectDocument,
    constraint: &Constraint,
) -> Option<Circle> {
    match constraint.targets.as_slice() {
        [target] => circle_for_entity_target(&document.entities, target).ok(),
        _ => None,
    }
}

pub(in crate::document) fn radius_entity_from_single_target(
    document: &ProjectDocument,
    constraint: &Constraint,
) -> Option<RadiusEntity> {
    match constraint.targets.as_slice() {
        [target] => radius_entity_for_target(&document.entities, target).ok(),
        _ => None,
    }
}

pub(in crate::document) fn arc_from_single_target(
    document: &ProjectDocument,
    constraint: &Constraint,
) -> Option<crate::geometry::Arc> {
    match constraint.targets.as_slice() {
        [target] => arc_for_entity_target(&document.entities, target).ok(),
        _ => None,
    }
}

pub(in crate::document) fn line_pair_from_targets(
    document: &ProjectDocument,
    constraint: &Constraint,
) -> Result<(crate::geometry::LineSegment, crate::geometry::LineSegment), CommandError> {
    match constraint.targets.as_slice() {
        [first, second] => Ok((
            line_for_entity_target(&document.entities, first)?,
            line_for_entity_target(&document.entities, second)?,
        )),
        _ => Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "line relation constraints require exactly two line targets",
        }),
    }
}

pub(in crate::document) struct SharedEndpointAngleLines {
    pub(in crate::document) shared_point: Point2,
    pub(in crate::document) first_direction: Point2,
    pub(in crate::document) second_direction: Point2,
    pub(in crate::document) second_shared_endpoint: ControlPointKind,
    pub(in crate::document) second_length_mm: f64,
}

pub(in crate::document) struct TangentTargets {
    pub(in crate::document) line_target: ConstraintTarget,
    pub(in crate::document) line_direction_to_connection: Point2,
    pub(in crate::document) arc_target: ConstraintTarget,
    pub(in crate::document) arc_endpoint: ControlPointKind,
    pub(in crate::document) arc: crate::geometry::Arc,
    pub(in crate::document) connection_point: Point2,
}

pub(in crate::document) fn shared_endpoint_angle_lines_from_constraint(
    document: &ProjectDocument,
    constraint: &Constraint,
) -> Result<SharedEndpointAngleLines, CommandError> {
    shared_endpoint_angle_lines_from_targets(&document.entities, &constraint.targets)
}

pub(in crate::document) fn shared_endpoint_angle_lines_from_targets(
    entities: &[Entity],
    targets: &[ConstraintTarget],
) -> Result<SharedEndpointAngleLines, CommandError> {
    let [first_target, second_target] = targets else {
        return Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "angle constraints require exactly two line targets",
        });
    };
    if constraint_target_entity_id(first_target) == constraint_target_entity_id(second_target) {
        return Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "angle constraints require two distinct line targets",
        });
    }

    let first = line_for_entity_target(entities, first_target)?;
    let second = line_for_entity_target(entities, second_target)?;
    let shared = shared_endpoint(first, second).ok_or(CommandError::InvalidValue {
        field: "constraint targets",
        reason: "angle constraints require two lines sharing exactly one endpoint",
    })?;

    Ok(SharedEndpointAngleLines {
        shared_point: shared.point,
        first_direction: normalized_direction(shared.point, shared.first_opposite),
        second_direction: normalized_direction(shared.point, shared.second_opposite),
        second_shared_endpoint: shared.second_endpoint,
        second_length_mm: second.length_mm(),
    })
}

struct SharedLineEndpoint {
    point: Point2,
    first_opposite: Point2,
    second_opposite: Point2,
    second_endpoint: ControlPointKind,
}

fn shared_endpoint(
    first: crate::geometry::LineSegment,
    second: crate::geometry::LineSegment,
) -> Option<SharedLineEndpoint> {
    let candidates = [
        (
            first.start,
            first.end,
            second.start,
            second.end,
            ControlPointKind::Start,
        ),
        (
            first.start,
            first.end,
            second.end,
            second.start,
            ControlPointKind::End,
        ),
        (
            first.end,
            first.start,
            second.start,
            second.end,
            ControlPointKind::Start,
        ),
        (
            first.end,
            first.start,
            second.end,
            second.start,
            ControlPointKind::End,
        ),
    ];

    let mut matches = candidates
        .into_iter()
        .filter(|(first_point, _, second_point, _, _)| {
            points_approx_eq(*first_point, *second_point)
        })
        .map(
            |(point, first_opposite, _, second_opposite, second_endpoint)| SharedLineEndpoint {
                point,
                first_opposite,
                second_opposite,
                second_endpoint,
            },
        );
    let shared = matches.next()?;
    if matches.next().is_some() {
        return None;
    }
    Some(shared)
}

pub(in crate::document) fn tangent_targets_from_document(
    document: &ProjectDocument,
    constraint: &Constraint,
) -> Result<TangentTargets, CommandError> {
    let candidates = tangent_candidates_from_targets(&document.entities, &constraint.targets)?;
    unique_connected_tangent_candidate(
        candidates,
        |line_target, arc_target, line_point, arc_point| {
            points_approx_eq(line_point, arc_point)
                || document_targets_are_coincident(document, line_target, arc_target)
        },
    )
}

pub(in crate::document) fn tangent_targets_from_entities(
    entities: &[Entity],
    targets: &[ConstraintTarget],
) -> Result<TangentTargets, CommandError> {
    let candidates = tangent_candidates_from_targets(entities, targets)?;
    unique_connected_tangent_candidate(candidates, |_, _, line_point, arc_point| {
        points_approx_eq(line_point, arc_point)
    })
}

#[derive(Clone)]
struct TangentCandidate {
    line_target: ConstraintTarget,
    line_point: Point2,
    line_opposite: Point2,
    arc_target: ConstraintTarget,
    arc_endpoint: ControlPointKind,
    arc_point: Point2,
    arc: crate::geometry::Arc,
}

fn tangent_candidates_from_targets(
    entities: &[Entity],
    targets: &[ConstraintTarget],
) -> Result<Vec<TangentCandidate>, CommandError> {
    let [first, second] = targets else {
        return Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "tangent constraints require exactly one line target and one arc target",
        });
    };
    if constraint_target_entity_id(first) == constraint_target_entity_id(second) {
        return Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "tangent constraints require distinct line and arc targets",
        });
    }

    let first_lines = line_endpoint_candidates(entities, first)?;
    let second_lines = line_endpoint_candidates(entities, second)?;
    let first_arcs = arc_endpoint_candidates(entities, first)?;
    let second_arcs = arc_endpoint_candidates(entities, second)?;

    let mut candidates = Vec::new();
    for line in &first_lines {
        for arc in &second_arcs {
            candidates.push(TangentCandidate {
                line_target: line.target.clone(),
                line_point: line.point,
                line_opposite: line.opposite,
                arc_target: arc.target.clone(),
                arc_endpoint: arc.endpoint,
                arc_point: arc.point,
                arc: arc.arc,
            });
        }
    }
    for line in &second_lines {
        for arc in &first_arcs {
            candidates.push(TangentCandidate {
                line_target: line.target.clone(),
                line_point: line.point,
                line_opposite: line.opposite,
                arc_target: arc.target.clone(),
                arc_endpoint: arc.endpoint,
                arc_point: arc.point,
                arc: arc.arc,
            });
        }
    }

    if candidates.is_empty() {
        return Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "tangent constraints require one line target and one arc target",
        });
    }
    Ok(candidates)
}

#[derive(Clone)]
struct LineEndpointCandidate {
    target: ConstraintTarget,
    point: Point2,
    opposite: Point2,
}

fn line_endpoint_candidates(
    entities: &[Entity],
    target: &ConstraintTarget,
) -> Result<Vec<LineEndpointCandidate>, CommandError> {
    let entity = match find_entity(entities, constraint_target_entity_id(target)) {
        Some(entity) => entity,
        None => return Ok(Vec::new()),
    };
    let line = match entity.kind {
        EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => line,
        _ => return Ok(Vec::new()),
    };
    match target {
        ConstraintTarget::Entity(_) => Ok(vec![
            LineEndpointCandidate {
                target: ConstraintTarget::ControlPoint {
                    entity_id: entity.id.clone(),
                    point: ControlPointKind::Start,
                },
                point: line.start,
                opposite: line.end,
            },
            LineEndpointCandidate {
                target: ConstraintTarget::ControlPoint {
                    entity_id: entity.id.clone(),
                    point: ControlPointKind::End,
                },
                point: line.end,
                opposite: line.start,
            },
        ]),
        ConstraintTarget::ControlPoint { point, .. } => match point {
            ControlPointKind::Start => Ok(vec![LineEndpointCandidate {
                target: target.clone(),
                point: line.start,
                opposite: line.end,
            }]),
            ControlPointKind::End => Ok(vec![LineEndpointCandidate {
                target: target.clone(),
                point: line.end,
                opposite: line.start,
            }]),
            ControlPointKind::Center => Ok(Vec::new()),
        },
    }
}

#[derive(Clone)]
struct ArcEndpointCandidate {
    target: ConstraintTarget,
    endpoint: ControlPointKind,
    point: Point2,
    arc: crate::geometry::Arc,
}

fn arc_endpoint_candidates(
    entities: &[Entity],
    target: &ConstraintTarget,
) -> Result<Vec<ArcEndpointCandidate>, CommandError> {
    let entity = match find_entity(entities, constraint_target_entity_id(target)) {
        Some(entity) => entity,
        None => return Ok(Vec::new()),
    };
    let arc = match entity.kind {
        EntityKind::Arc(arc) => arc,
        _ => return Ok(Vec::new()),
    };
    let start = point_from_entity_control_point(entity, ControlPointKind::Start)?;
    let end = point_from_entity_control_point(entity, ControlPointKind::End)?;
    match target {
        ConstraintTarget::Entity(_) => Ok(vec![
            ArcEndpointCandidate {
                target: ConstraintTarget::ControlPoint {
                    entity_id: entity.id.clone(),
                    point: ControlPointKind::Start,
                },
                endpoint: ControlPointKind::Start,
                point: start,
                arc,
            },
            ArcEndpointCandidate {
                target: ConstraintTarget::ControlPoint {
                    entity_id: entity.id.clone(),
                    point: ControlPointKind::End,
                },
                endpoint: ControlPointKind::End,
                point: end,
                arc,
            },
        ]),
        ConstraintTarget::ControlPoint { point, .. } => match point {
            ControlPointKind::Start => Ok(vec![ArcEndpointCandidate {
                target: target.clone(),
                endpoint: ControlPointKind::Start,
                point: start,
                arc,
            }]),
            ControlPointKind::End => Ok(vec![ArcEndpointCandidate {
                target: target.clone(),
                endpoint: ControlPointKind::End,
                point: end,
                arc,
            }]),
            ControlPointKind::Center => Ok(Vec::new()),
        },
    }
}

fn unique_connected_tangent_candidate(
    candidates: Vec<TangentCandidate>,
    connected: impl Fn(&ConstraintTarget, &ConstraintTarget, Point2, Point2) -> bool,
) -> Result<TangentTargets, CommandError> {
    let mut connected_candidates = candidates.into_iter().filter(|candidate| {
        connected(
            &candidate.line_target,
            &candidate.arc_target,
            candidate.line_point,
            candidate.arc_point,
        )
    });
    let Some(candidate) = connected_candidates.next() else {
        return Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "tangent constraints require connected line and arc endpoints",
        });
    };
    if connected_candidates.next().is_some() {
        return Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "tangent constraints require exactly one connected endpoint pair",
        });
    }
    Ok(TangentTargets {
        line_target: candidate.line_target,
        line_direction_to_connection: normalized_direction(
            candidate.line_opposite,
            candidate.line_point,
        ),
        arc_target: candidate.arc_target,
        arc_endpoint: candidate.arc_endpoint,
        arc: candidate.arc,
        connection_point: candidate.line_point,
    })
}

fn document_targets_are_coincident(
    document: &ProjectDocument,
    first: &ConstraintTarget,
    second: &ConstraintTarget,
) -> bool {
    document.coincident_point_groups().iter().any(|group| {
        group.targets.iter().any(|target| target == first)
            && group.targets.iter().any(|target| target == second)
    })
}

fn points_approx_eq(lhs: Point2, rhs: Point2) -> bool {
    (lhs.x_mm - rhs.x_mm).hypot(lhs.y_mm - rhs.y_mm) <= GEOMETRY_EPSILON_MM
}

pub(in crate::document) fn point_pair_with_expected_length(
    document: &ProjectDocument,
    constraint: &Constraint,
) -> Result<(Point2, Point2, f64), CommandError> {
    match constraint.targets.as_slice() {
        [first, second] => Ok((
            point_for_target(&document.entities, first)?,
            point_for_target(&document.entities, second)?,
            resolve_length_value_mm(
                &document.parameters,
                constraint.value.as_ref(),
                "distance constraint value",
            )?,
        )),
        _ => Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "distance constraints require exactly two point targets",
        }),
    }
}

pub(in crate::document) fn point_line_with_expected_distance(
    document: &ProjectDocument,
    constraint: &Constraint,
) -> Result<(Point2, LineSegment, f64), CommandError> {
    match constraint.targets.as_slice() {
        [first, second] => {
            let distance = resolve_length_value_mm(
                &document.parameters,
                constraint.value.as_ref(),
                "point-line distance value",
            )?;
            if let (Ok(point), Ok(line)) = (
                point_for_target(&document.entities, first),
                line_for_entity_target(&document.entities, second),
            ) {
                return Ok((point, line, distance));
            }
            if let (Ok(point), Ok(line)) = (
                point_for_target(&document.entities, second),
                line_for_entity_target(&document.entities, first),
            ) {
                return Ok((point, line, distance));
            }
            Err(CommandError::InvalidValue {
                field: "constraint targets",
                reason:
                    "point-line distance constraints require one point target and one line target",
            })
        }
        _ => Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "point-line distance constraints require one point target and one line target",
        }),
    }
}

pub(in crate::document) fn point_line_targets_from_constraint(
    document: &ProjectDocument,
    constraint: &Constraint,
) -> Result<(Point2, LineSegment), CommandError> {
    match constraint.targets.as_slice() {
        [first, second] => {
            if let (Ok(point), Ok(line)) = (
                point_for_target(&document.entities, first),
                line_for_entity_target(&document.entities, second),
            ) {
                return Ok((point, line));
            }
            if let (Ok(point), Ok(line)) = (
                point_for_target(&document.entities, second),
                line_for_entity_target(&document.entities, first),
            ) {
                return Ok((point, line));
            }
            Err(CommandError::InvalidValue {
                field: "constraint targets",
                reason: "point-on-line constraints require one point target and one line target",
            })
        }
        _ => Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "point-on-line constraints require one point target and one line target",
        }),
    }
}

pub(in crate::document) fn find_entity_mut<'a>(
    entities: &'a mut [Entity],
    entity_id: &str,
) -> Option<&'a mut Entity> {
    entities.iter_mut().find(|entity| entity.id == entity_id)
}

pub(in crate::document) fn find_entity<'a>(
    entities: &'a [Entity],
    entity_id: &str,
) -> Option<&'a Entity> {
    entities.iter().find(|entity| entity.id == entity_id)
}

pub(in crate::document) fn matches_line_entity(kind: &EntityKind) -> bool {
    matches!(kind, EntityKind::LineSegment(_) | EntityKind::CenterLine(_))
}

pub(in crate::document) fn matches_line_target(entity: &Entity, target: &ConstraintTarget) -> bool {
    match target {
        ConstraintTarget::Entity(_) => matches_line_entity(&entity.kind),
        ConstraintTarget::ControlPoint { .. } => false,
    }
}

pub(in crate::document) fn matches_point_target(
    entity: &Entity,
    target: &ConstraintTarget,
) -> bool {
    match target {
        ConstraintTarget::Entity(_) => matches!(entity.kind, EntityKind::Point(_)),
        ConstraintTarget::ControlPoint { point, .. } => {
            matches_control_point_for_entity(&entity.kind, *point)
        }
    }
}

pub(in crate::document) fn matches_control_point_for_entity(
    kind: &EntityKind,
    point: ControlPointKind,
) -> bool {
    matches!(
        (kind, point),
        (
            EntityKind::LineSegment(_) | EntityKind::CenterLine(_),
            ControlPointKind::Start | ControlPointKind::End
        ) | (
            EntityKind::Circle(_) | EntityKind::Arc(_),
            ControlPointKind::Center
        ) | (
            EntityKind::Arc(_),
            ControlPointKind::Start | ControlPointKind::End
        )
    )
}

pub(in crate::document) fn point_for_target(
    entities: &[Entity],
    target: &ConstraintTarget,
) -> Result<Point2, CommandError> {
    let entity = find_entity(entities, constraint_target_entity_id(target)).ok_or_else(|| {
        CommandError::broken_reference("constraint", "entity", constraint_target_entity_id(target))
    })?;
    match target {
        ConstraintTarget::Entity(_) => match entity.kind {
            EntityKind::Point(point) => Ok(point),
            _ => Err(CommandError::InvalidValue {
                field: "constraint targets",
                reason: "entity target must resolve to a point-compatible entity",
            }),
        },
        ConstraintTarget::ControlPoint { point, .. } => {
            point_from_entity_control_point(entity, *point)
        }
    }
}

pub(in crate::document) fn line_for_entity_target(
    entities: &[Entity],
    target: &ConstraintTarget,
) -> Result<crate::geometry::LineSegment, CommandError> {
    let entity = find_entity(entities, constraint_target_entity_id(target)).ok_or_else(|| {
        CommandError::broken_reference("constraint", "entity", constraint_target_entity_id(target))
    })?;
    match target {
        ConstraintTarget::Entity(_) => match entity.kind {
            EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => Ok(line),
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

pub(in crate::document) fn circle_for_entity_target(
    entities: &[Entity],
    target: &ConstraintTarget,
) -> Result<Circle, CommandError> {
    let entity = find_entity(entities, constraint_target_entity_id(target)).ok_or_else(|| {
        CommandError::broken_reference("constraint", "entity", constraint_target_entity_id(target))
    })?;
    match target {
        ConstraintTarget::Entity(_) => match entity.kind {
            EntityKind::Circle(circle) => Ok(circle),
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

pub(in crate::document) fn radius_entity_for_target(
    entities: &[Entity],
    target: &ConstraintTarget,
) -> Result<RadiusEntity, CommandError> {
    let entity = find_entity(entities, constraint_target_entity_id(target)).ok_or_else(|| {
        CommandError::broken_reference("constraint", "entity", constraint_target_entity_id(target))
    })?;
    match target {
        ConstraintTarget::Entity(_) => match entity.kind {
            EntityKind::Circle(circle) => Ok(RadiusEntity {
                radius_mm: circle.radius_mm,
            }),
            EntityKind::Arc(arc) => Ok(RadiusEntity {
                radius_mm: arc.radius_mm,
            }),
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

pub(in crate::document) fn arc_for_entity_target(
    entities: &[Entity],
    target: &ConstraintTarget,
) -> Result<crate::geometry::Arc, CommandError> {
    let entity = find_entity(entities, constraint_target_entity_id(target)).ok_or_else(|| {
        CommandError::broken_reference("constraint", "entity", constraint_target_entity_id(target))
    })?;
    match target {
        ConstraintTarget::Entity(_) => match entity.kind {
            EntityKind::Arc(arc) => Ok(arc),
            _ => Err(CommandError::InvalidValue {
                field: "constraint targets",
                reason: "entity target must resolve to an arc",
            }),
        },
        ConstraintTarget::ControlPoint { .. } => Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "arc angle constraints require entity targets",
        }),
    }
}

pub(in crate::document) fn point_from_entity_control_point(
    entity: &Entity,
    point: ControlPointKind,
) -> Result<Point2, CommandError> {
    match (&entity.kind, point) {
        (EntityKind::LineSegment(line) | EntityKind::CenterLine(line), ControlPointKind::Start) => {
            Ok(line.start)
        }
        (EntityKind::LineSegment(line) | EntityKind::CenterLine(line), ControlPointKind::End) => {
            Ok(line.end)
        }
        (EntityKind::Circle(circle), ControlPointKind::Center) => Ok(circle.center),
        (EntityKind::Arc(arc), ControlPointKind::Center) => Ok(arc.center),
        (EntityKind::Arc(arc), ControlPointKind::Start) => Ok(Point2::new(
            arc.center.x_mm + arc.start_angle_rad.cos() * arc.radius_mm,
            arc.center.y_mm + arc.start_angle_rad.sin() * arc.radius_mm,
        )),
        (EntityKind::Arc(arc), ControlPointKind::End) => {
            let end_angle = arc.start_angle_rad + arc.sweep_angle_rad;
            Ok(Point2::new(
                arc.center.x_mm + end_angle.cos() * arc.radius_mm,
                arc.center.y_mm + end_angle.sin() * arc.radius_mm,
            ))
        }
        _ => Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "control point target is incompatible with the referenced entity",
        }),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::geometry::{Arc, Circle, Entity, EntityKind, LineSegment};

    fn line_entity(id: &str) -> Entity {
        Entity::new(
            id,
            EntityKind::LineSegment(LineSegment::new(
                Point2::new(0.0, 0.0),
                Point2::new(3.0, 4.0),
            )),
        )
    }

    #[test]
    fn target_kind_matchers_distinguish_entity_and_control_point_targets() {
        let line = line_entity("entity:line");
        let point = Entity::new("entity:point", EntityKind::Point(Point2::new(1.0, 2.0)));
        let circle = Entity::new(
            "entity:circle",
            EntityKind::Circle(Circle {
                center: Point2::new(5.0, 6.0),
                radius_mm: 2.0,
            }),
        );

        assert!(matches_line_entity(&line.kind));
        assert!(!matches_line_entity(&point.kind));
        assert!(matches_line_target(
            &line,
            &ConstraintTarget::Entity(line.id.clone())
        ));
        assert!(!matches_line_target(
            &line,
            &ConstraintTarget::ControlPoint {
                entity_id: line.id.clone(),
                point: ControlPointKind::Start
            }
        ));
        assert!(matches_point_target(
            &point,
            &ConstraintTarget::Entity(point.id.clone())
        ));
        assert!(!matches_point_target(
            &line,
            &ConstraintTarget::Entity(line.id.clone())
        ));
        assert!(matches_point_target(
            &circle,
            &ConstraintTarget::ControlPoint {
                entity_id: circle.id.clone(),
                point: ControlPointKind::Center
            }
        ));
        assert!(!matches_point_target(
            &circle,
            &ConstraintTarget::ControlPoint {
                entity_id: circle.id.clone(),
                point: ControlPointKind::Start
            }
        ));
    }

    #[test]
    fn point_from_entity_control_point_resolves_line_circle_and_arc_points() {
        let line = line_entity("entity:line");
        assert_eq!(
            point_from_entity_control_point(&line, ControlPointKind::Start).unwrap(),
            Point2::new(0.0, 0.0)
        );
        assert_eq!(
            point_from_entity_control_point(&line, ControlPointKind::End).unwrap(),
            Point2::new(3.0, 4.0)
        );

        let circle = Entity::new(
            "entity:circle",
            EntityKind::Circle(Circle {
                center: Point2::new(5.0, 6.0),
                radius_mm: 2.0,
            }),
        );
        assert_eq!(
            point_from_entity_control_point(&circle, ControlPointKind::Center).unwrap(),
            Point2::new(5.0, 6.0)
        );
        assert!(point_from_entity_control_point(&circle, ControlPointKind::Start).is_err());

        let arc = Entity::new(
            "entity:arc",
            EntityKind::Arc(Arc {
                center: Point2::new(10.0, 20.0),
                radius_mm: 5.0,
                start_angle_rad: 0.0,
                sweep_angle_rad: std::f64::consts::FRAC_PI_2,
            }),
        );
        let start = point_from_entity_control_point(&arc, ControlPointKind::Start).unwrap();
        let end = point_from_entity_control_point(&arc, ControlPointKind::End).unwrap();
        assert!(approx_eq(start.x_mm, 15.0));
        assert!(approx_eq(start.y_mm, 20.0));
        assert!(approx_eq(end.x_mm, 10.0));
        assert!(approx_eq(end.y_mm, 25.0));
    }

    #[test]
    fn constraint_targets_entity_checks_all_target_forms() {
        let constraint = Constraint {
            id: "constraint:coincident".to_owned(),
            kind: ConstraintKind::Coincident,
            targets: vec![
                ConstraintTarget::ControlPoint {
                    entity_id: "entity:line-a".to_owned(),
                    point: ControlPointKind::End,
                },
                ConstraintTarget::Entity("entity:point-a".to_owned()),
            ],
            value: None,
            status: ConstraintStatus::Unknown,
        };

        assert!(constraint_targets_entity(&constraint, "entity:line-a"));
        assert!(constraint_targets_entity(&constraint, "entity:point-a"));
        assert!(!constraint_targets_entity(&constraint, "entity:line-b"));
    }
}
