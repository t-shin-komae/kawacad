use super::*;

#[derive(Debug, Clone)]
pub(in crate::document) struct PropagationGraph<'a> {
    constraints: &'a [Constraint],
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub(in crate::document) struct PropagationResult {
    pub seed_count: usize,
    pub visited_target_count: usize,
    pub iterations: usize,
}

impl<'a> PropagationGraph<'a> {
    pub(in crate::document) fn new(constraints: &'a [Constraint]) -> Self {
        Self { constraints }
    }

    pub(in crate::document) fn propagate_connected_endpoint_changes(
        &self,
        parameters: &[Parameter],
        entities: &mut [Entity],
        seeds: Vec<ConstraintTarget>,
    ) -> CommandResult<PropagationResult> {
        let seed_count = seeds.len();
        let mut queue = std::collections::VecDeque::from(seeds);
        let max_iterations = self
            .constraints
            .len()
            .saturating_mul(entities.len())
            .saturating_mul(16)
            + 64;
        let mut iterations = 0usize;
        let mut visited_target_count = 0usize;

        while let Some(seed) = queue.pop_front() {
            iterations += 1;
            if iterations > max_iterations {
                return Err(CommandError::InvalidValue {
                    field: "constraint",
                    reason: "constraint propagation did not converge",
                });
            }

            let point = point_for_target(entities, &seed)?;
            for target in self.coincident_group_targets(&seed) {
                visited_target_count += 1;
                if target != seed {
                    set_point_for_target(entities, &target, point)?;
                }
                if let Some(opposite) = preserve_line_shape_from_endpoint_target(
                    parameters,
                    entities,
                    self.constraints,
                    &target,
                )? {
                    queue.push_back(opposite);
                }
            }
        }

        Ok(PropagationResult {
            seed_count,
            visited_target_count,
            iterations,
        })
    }

    pub(in crate::document) fn coincident_group_targets(
        &self,
        target: &ConstraintTarget,
    ) -> Vec<ConstraintTarget> {
        let mut group = vec![target.clone()];
        let mut changed = true;
        while changed {
            changed = false;
            for constraint in self.constraints {
                if !matches!(constraint.kind, ConstraintKind::Coincident) {
                    continue;
                }
                let [first, second] = constraint.targets.as_slice() else {
                    continue;
                };
                let first_in_group = group.iter().any(|candidate| candidate == first);
                let second_in_group = group.iter().any(|candidate| candidate == second);
                if first_in_group && !second_in_group {
                    group.push(second.clone());
                    changed = true;
                }
                if second_in_group && !first_in_group {
                    group.push(first.clone());
                    changed = true;
                }
            }
        }
        group
    }
}

pub(in crate::document) fn solve_constraint_system(
    parameters: &[Parameter],
    entities: &[Entity],
    constraints: &[Constraint],
) -> CommandResult<Vec<Entity>> {
    let mut updated_entities = entities.to_vec();
    for constraint in constraints
        .iter()
        .filter(|constraint| !matches!(constraint.kind, ConstraintKind::Tangent))
    {
        apply_constraint_effect_to_entities(parameters, &mut updated_entities, constraint)?;
    }
    solve_axis_distance_pairs(parameters, &mut updated_entities, constraints)?;
    for constraint in constraints
        .iter()
        .filter(|constraint| matches!(constraint.kind, ConstraintKind::Tangent))
    {
        apply_constraint_effect_to_entities(parameters, &mut updated_entities, constraint)?;
    }
    preserve_line_endpoint_shapes_after_coincident(parameters, &mut updated_entities, constraints)?;
    solve_axis_aligned_line_rectangles(parameters, &mut updated_entities, constraints)?;
    Ok(updated_entities)
}

pub(in crate::document) fn apply_constraint_effect_to_entities(
    parameters: &[Parameter],
    entities: &mut [Entity],
    constraint: &Constraint,
) -> CommandResult {
    match constraint.kind {
        ConstraintKind::Horizontal => apply_horizontal_constraint(entities, constraint),
        ConstraintKind::Vertical => apply_vertical_constraint(entities, constraint),
        ConstraintKind::Fixed => Ok(()),
        ConstraintKind::Coincident => apply_coincident_constraint(entities, constraint),
        ConstraintKind::SegmentLength => {
            apply_segment_length_constraint(parameters, entities, constraint)
        }
        ConstraintKind::Diameter => apply_diameter_constraint(parameters, entities, constraint),
        ConstraintKind::Radius => apply_radius_constraint(parameters, entities, constraint),
        ConstraintKind::Distance => apply_distance_constraint(parameters, entities, constraint),
        ConstraintKind::HorizontalDistance => {
            apply_axis_distance_constraint(parameters, entities, constraint, Axis::Horizontal)
        }
        ConstraintKind::VerticalDistance => {
            apply_axis_distance_constraint(parameters, entities, constraint, Axis::Vertical)
        }
        ConstraintKind::PointLineDistance => {
            apply_point_line_distance_constraint(parameters, entities, constraint)
        }
        ConstraintKind::LineLineDistance => {
            apply_line_line_distance_constraint(parameters, entities, constraint)
        }
        ConstraintKind::PointOnLine => apply_point_on_line_constraint(entities, constraint),
        ConstraintKind::Parallel => apply_parallel_constraint(entities, constraint),
        ConstraintKind::Perpendicular => apply_perpendicular_constraint(entities, constraint),
        ConstraintKind::Tangent => apply_tangent_constraint(entities, constraint),
        ConstraintKind::Angle => apply_angle_constraint(entities, constraint),
        ConstraintKind::EqualSegmentLength => {
            apply_equal_segment_length_constraint(entities, constraint)
        }
        ConstraintKind::Symmetric => apply_symmetric_constraint(entities, constraint),
    }
}

pub(in crate::document) fn apply_coincident_constraint(
    entities: &mut [Entity],
    constraint: &Constraint,
) -> CommandResult {
    match constraint.targets.as_slice() {
        [first, second] => {
            let anchor = point_for_target(entities, first)?;
            set_point_for_target(entities, second, anchor)
        }
        _ => Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "coincident constraints require exactly two point targets",
        }),
    }
}

pub(in crate::document) fn apply_horizontal_constraint(
    entities: &mut [Entity],
    constraint: &Constraint,
) -> CommandResult {
    match constraint.targets.as_slice() {
        [ConstraintTarget::Entity(entity_id)] => {
            let entity = find_entity_mut(entities, entity_id)
                .ok_or_else(|| CommandError::broken_reference("constraint", "entity", entity_id))?;
            match &mut entity.kind {
                EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => {
                    let current_length = line.length_mm();
                    let direction_sign = horizontal_direction_sign(line.start, line.end);
                    line.end.x_mm = line.start.x_mm + current_length * direction_sign;
                    line.end.y_mm = line.start.y_mm;
                    entity.validate().map_err(CommandError::InvalidEntity)
                }
                _ => Err(CommandError::InvalidValue {
                    field: "constraint targets",
                    reason: "horizontal constraints require a line target",
                }),
            }
        }
        [first, second] => {
            let anchor = point_for_target(entities, first)?;
            let mut moved = point_for_target(entities, second)?;
            moved.y_mm = anchor.y_mm;
            set_point_for_target(entities, second, moved)
        }
        _ => Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "horizontal constraints require one line target or two point targets",
        }),
    }
}

pub(in crate::document) fn apply_vertical_constraint(
    entities: &mut [Entity],
    constraint: &Constraint,
) -> CommandResult {
    match constraint.targets.as_slice() {
        [ConstraintTarget::Entity(entity_id)] => {
            let entity = find_entity_mut(entities, entity_id)
                .ok_or_else(|| CommandError::broken_reference("constraint", "entity", entity_id))?;
            match &mut entity.kind {
                EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => {
                    let current_length = line.length_mm();
                    let direction_sign = vertical_direction_sign(line.start, line.end);
                    line.end.x_mm = line.start.x_mm;
                    line.end.y_mm = line.start.y_mm + current_length * direction_sign;
                    entity.validate().map_err(CommandError::InvalidEntity)
                }
                _ => Err(CommandError::InvalidValue {
                    field: "constraint targets",
                    reason: "vertical constraints require a line target",
                }),
            }
        }
        [first, second] => {
            let anchor = point_for_target(entities, first)?;
            let mut moved = point_for_target(entities, second)?;
            moved.x_mm = anchor.x_mm;
            set_point_for_target(entities, second, moved)
        }
        _ => Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "vertical constraints require one line target or two point targets",
        }),
    }
}

pub(in crate::document) fn apply_segment_length_constraint(
    parameters: &[Parameter],
    entities: &mut [Entity],
    constraint: &Constraint,
) -> CommandResult {
    let length_mm = resolve_length_value_mm(
        parameters,
        constraint.value.as_ref(),
        "segment length value",
    )?;
    if length_mm <= GEOMETRY_EPSILON_MM {
        return Err(CommandError::InvalidValue {
            field: "segment length value",
            reason: "must be greater than zero",
        });
    }
    match constraint.targets.as_slice() {
        [target] => set_line_length_for_target(entities, target, length_mm),
        _ => Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "segment length constraints require exactly one line target",
        }),
    }
}

pub(in crate::document) fn apply_diameter_constraint(
    parameters: &[Parameter],
    entities: &mut [Entity],
    constraint: &Constraint,
) -> CommandResult {
    let diameter_mm =
        resolve_length_value_mm(parameters, constraint.value.as_ref(), "diameter value")?;
    if diameter_mm <= GEOMETRY_EPSILON_MM {
        return Err(CommandError::InvalidValue {
            field: "diameter value",
            reason: "must be greater than zero",
        });
    }
    match constraint.targets.as_slice() {
        [target] => set_circle_diameter_for_target(entities, target, diameter_mm),
        _ => Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "diameter constraints require exactly one circle target",
        }),
    }
}

pub(in crate::document) fn apply_radius_constraint(
    parameters: &[Parameter],
    entities: &mut [Entity],
    constraint: &Constraint,
) -> CommandResult {
    let radius_mm = resolve_length_value_mm(parameters, constraint.value.as_ref(), "radius value")?;
    if radius_mm <= GEOMETRY_EPSILON_MM {
        return Err(CommandError::InvalidValue {
            field: "radius value",
            reason: "must be greater than zero",
        });
    }
    match constraint.targets.as_slice() {
        [target] => set_radius_for_target(entities, target, radius_mm),
        _ => Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "radius constraints require exactly one arc or circle target",
        }),
    }
}

pub(in crate::document) fn apply_distance_constraint(
    parameters: &[Parameter],
    entities: &mut [Entity],
    constraint: &Constraint,
) -> CommandResult {
    let distance_mm = resolve_length_value_mm(
        parameters,
        constraint.value.as_ref(),
        "distance constraint value",
    )?;
    match constraint.targets.as_slice() {
        [first, second] => {
            let anchor = point_for_target(entities, first)?;
            let current = point_for_target(entities, second)?;
            let direction = normalized_direction(anchor, current);
            let moved = Point2::new(
                anchor.x_mm + direction.x_mm * distance_mm,
                anchor.y_mm + direction.y_mm * distance_mm,
            );
            set_point_for_target(entities, second, moved)
        }
        _ => Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "distance constraints require exactly two point targets",
        }),
    }
}

#[derive(Debug, Clone, Copy)]
pub(in crate::document) enum Axis {
    Horizontal,
    Vertical,
}

pub(in crate::document) fn apply_axis_distance_constraint(
    parameters: &[Parameter],
    entities: &mut [Entity],
    constraint: &Constraint,
    axis: Axis,
) -> CommandResult {
    let value_name = match axis {
        Axis::Horizontal => "horizontal distance value",
        Axis::Vertical => "vertical distance value",
    };
    let distance_mm = resolve_length_value_mm(parameters, constraint.value.as_ref(), value_name)?;
    match constraint.targets.as_slice() {
        [first, second] => {
            let anchor = point_for_target(entities, first)?;
            let current = point_for_target(entities, second)?;
            let moved = match axis {
                Axis::Horizontal => {
                    let sign = sign_or_positive(current.x_mm - anchor.x_mm);
                    Point2::new(anchor.x_mm + distance_mm * sign, current.y_mm)
                }
                Axis::Vertical => {
                    let sign = sign_or_positive(current.y_mm - anchor.y_mm);
                    Point2::new(current.x_mm, anchor.y_mm + distance_mm * sign)
                }
            };
            set_point_for_target(entities, second, moved)
        }
        _ => Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "axis distance constraints require exactly two point targets",
        }),
    }
}

fn solve_axis_distance_pairs(
    parameters: &[Parameter],
    entities: &mut [Entity],
    constraints: &[Constraint],
) -> CommandResult {
    for distance_constraint in constraints
        .iter()
        .filter(|constraint| matches!(constraint.kind, ConstraintKind::Distance))
    {
        for axis_constraint in constraints.iter().filter(|constraint| {
            matches!(
                constraint.kind,
                ConstraintKind::HorizontalDistance | ConstraintKind::VerticalDistance
            ) && same_point_pair(&distance_constraint.targets, &constraint.targets)
        }) {
            let axis = match axis_constraint.kind {
                ConstraintKind::HorizontalDistance => Axis::Horizontal,
                ConstraintKind::VerticalDistance => Axis::Vertical,
                _ => continue,
            };
            solve_axis_distance_pair(
                parameters,
                entities,
                distance_constraint,
                axis_constraint,
                axis,
            )?;
        }
    }
    Ok(())
}

fn solve_axis_distance_pair(
    parameters: &[Parameter],
    entities: &mut [Entity],
    distance_constraint: &Constraint,
    axis_constraint: &Constraint,
    axis: Axis,
) -> CommandResult {
    let distance_mm = resolve_length_value_mm(
        parameters,
        distance_constraint.value.as_ref(),
        "distance constraint value",
    )?;
    let axis_value_name = match axis {
        Axis::Horizontal => "horizontal distance value",
        Axis::Vertical => "vertical distance value",
    };
    let axis_distance_mm =
        resolve_length_value_mm(parameters, axis_constraint.value.as_ref(), axis_value_name)?;
    if axis_distance_mm > distance_mm + GEOMETRY_EPSILON_MM {
        return Ok(());
    }

    let [first, second] = distance_constraint.targets.as_slice() else {
        return Ok(());
    };
    let anchor = point_for_target(entities, first)?;
    let current = point_for_target(entities, second)?;
    let orthogonal_distance = (distance_mm.powi(2) - axis_distance_mm.powi(2))
        .max(0.0)
        .sqrt();
    let moved = match axis {
        Axis::Horizontal => {
            let horizontal_sign = sign_or_positive(current.x_mm - anchor.x_mm);
            let vertical_sign = sign_or_positive(current.y_mm - anchor.y_mm);
            Point2::new(
                anchor.x_mm + axis_distance_mm * horizontal_sign,
                anchor.y_mm + orthogonal_distance * vertical_sign,
            )
        }
        Axis::Vertical => {
            let horizontal_sign = sign_or_positive(current.x_mm - anchor.x_mm);
            let vertical_sign = sign_or_positive(current.y_mm - anchor.y_mm);
            Point2::new(
                anchor.x_mm + orthogonal_distance * horizontal_sign,
                anchor.y_mm + axis_distance_mm * vertical_sign,
            )
        }
    };
    set_point_for_target(entities, second, moved)
}

fn same_point_pair(first: &[ConstraintTarget], second: &[ConstraintTarget]) -> bool {
    first.len() == 2
        && second.len() == 2
        && ((first[0] == second[0] && first[1] == second[1])
            || (first[0] == second[1] && first[1] == second[0]))
}

pub(in crate::document) fn apply_point_line_distance_constraint(
    parameters: &[Parameter],
    entities: &mut [Entity],
    constraint: &Constraint,
) -> CommandResult {
    let distance_mm = resolve_length_value_mm(
        parameters,
        constraint.value.as_ref(),
        "point-line distance value",
    )?;
    let (point_target, current, line) = point_line_targets(entities, &constraint.targets)?;
    let projection = project_point_onto_line(current, line);
    let direction = normalized_direction(line.start, line.end);
    let normal = Point2::new(-direction.y_mm, direction.x_mm);
    let signed_distance = signed_point_line_distance(current, line);
    let side = if signed_distance < 0.0 { -1.0 } else { 1.0 };
    let moved = Point2::new(
        projection.x_mm + normal.x_mm * distance_mm * side,
        projection.y_mm + normal.y_mm * distance_mm * side,
    );
    set_point_for_target(entities, point_target, moved)
}

pub(in crate::document) fn apply_line_line_distance_constraint(
    parameters: &[Parameter],
    entities: &mut [Entity],
    constraint: &Constraint,
) -> CommandResult {
    let distance_mm = resolve_length_value_mm(
        parameters,
        constraint.value.as_ref(),
        "line-line distance value",
    )?;
    let [first, second] = constraint.targets.as_slice() else {
        return Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "line-line distance constraints require exactly two line targets",
        });
    };
    let reference_line = line_for_entity_target(entities, first)?;
    let target_line = line_for_entity_target(entities, second)?;
    let reference_direction = normalized_direction(reference_line.start, reference_line.end);
    let current_direction = normalized_direction(target_line.start, target_line.end);
    let target_length = target_line.length_mm();
    let aligned_direction = align_direction(reference_direction, current_direction);
    let normal = Point2::new(-reference_direction.y_mm, reference_direction.x_mm);
    let signed_distance = signed_point_line_distance(target_line.start, reference_line);
    let side = if signed_distance < 0.0 { -1.0 } else { 1.0 };
    let projection = project_point_onto_line(target_line.start, reference_line);
    let moved_start = Point2::new(
        projection.x_mm + normal.x_mm * distance_mm * side,
        projection.y_mm + normal.y_mm * distance_mm * side,
    );
    let moved_end = Point2::new(
        moved_start.x_mm + aligned_direction.x_mm * target_length,
        moved_start.y_mm + aligned_direction.y_mm * target_length,
    );
    set_line_start_end_for_entity_target(entities, second, moved_start, moved_end)
}

pub(in crate::document) fn apply_point_on_line_constraint(
    entities: &mut [Entity],
    constraint: &Constraint,
) -> CommandResult {
    let (point_target, current, line) = point_line_targets(entities, &constraint.targets)?;
    let projection = project_point_onto_line(current, line);
    set_point_for_target(entities, point_target, projection)
}

fn point_line_targets<'a>(
    entities: &[Entity],
    targets: &'a [ConstraintTarget],
) -> CommandResult<(&'a ConstraintTarget, Point2, crate::geometry::LineSegment)> {
    match targets {
        [first, second] => {
            if let (Ok(point), Ok(line)) = (
                point_for_target(entities, first),
                line_for_entity_target(entities, second),
            ) {
                return Ok((first, point, line));
            }
            if let (Ok(point), Ok(line)) = (
                point_for_target(entities, second),
                line_for_entity_target(entities, first),
            ) {
                return Ok((second, point, line));
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

fn set_line_start_end_for_entity_target(
    entities: &mut [Entity],
    target: &ConstraintTarget,
    start: Point2,
    end: Point2,
) -> CommandResult {
    let ConstraintTarget::Entity(entity_id) = target else {
        return Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "line constraints require entity targets",
        });
    };
    let entity = find_entity_mut(entities, entity_id)
        .ok_or_else(|| CommandError::broken_reference("constraint", "entity", entity_id))?;
    match &mut entity.kind {
        EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => {
            line.start = start;
            line.end = end;
            entity.validate().map_err(CommandError::InvalidEntity)
        }
        _ => Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "line constraints require line targets",
        }),
    }
}

pub(in crate::document) fn apply_equal_segment_length_constraint(
    entities: &mut [Entity],
    constraint: &Constraint,
) -> CommandResult {
    match constraint.targets.as_slice() {
        [first, second] => {
            let reference_line = line_for_entity_target(entities, first)?;
            let target_line = line_for_entity_target(entities, second)?;
            let target_length = reference_line.length_mm();
            let direction = normalized_direction(target_line.start, target_line.end);
            let moved_end = Point2::new(
                target_line.start.x_mm + direction.x_mm * target_length,
                target_line.start.y_mm + direction.y_mm * target_length,
            );
            set_line_end_for_entity_target(entities, second, moved_end)
        }
        _ => Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "equal segment length constraints require exactly two line targets",
        }),
    }
}

pub(in crate::document) fn apply_parallel_constraint(
    entities: &mut [Entity],
    constraint: &Constraint,
) -> CommandResult {
    match constraint.targets.as_slice() {
        [first, second] => {
            let reference_line = line_for_entity_target(entities, first)?;
            let target_line = line_for_entity_target(entities, second)?;
            let reference_direction =
                normalized_direction(reference_line.start, reference_line.end);
            let current_direction = normalized_direction(target_line.start, target_line.end);
            let target_length = target_line.length_mm();
            let aligned_direction = align_direction(reference_direction, current_direction);
            let moved_end = Point2::new(
                target_line.start.x_mm + aligned_direction.x_mm * target_length,
                target_line.start.y_mm + aligned_direction.y_mm * target_length,
            );
            set_line_end_for_entity_target(entities, second, moved_end)
        }
        _ => Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "parallel constraints require exactly two line targets",
        }),
    }
}

pub(in crate::document) fn apply_perpendicular_constraint(
    entities: &mut [Entity],
    constraint: &Constraint,
) -> CommandResult {
    match constraint.targets.as_slice() {
        [first, second] => {
            let reference_line = line_for_entity_target(entities, first)?;
            let target_line = line_for_entity_target(entities, second)?;
            let reference_direction =
                normalized_direction(reference_line.start, reference_line.end);
            let current_direction = normalized_direction(target_line.start, target_line.end);
            let target_length = target_line.length_mm();
            let perpendicular_direction =
                perpendicular_direction_closest_to(reference_direction, current_direction);
            let moved_end = Point2::new(
                target_line.start.x_mm + perpendicular_direction.x_mm * target_length,
                target_line.start.y_mm + perpendicular_direction.y_mm * target_length,
            );
            set_line_end_for_entity_target(entities, second, moved_end)
        }
        _ => Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "perpendicular constraints require exactly two line targets",
        }),
    }
}

pub(in crate::document) fn apply_tangent_constraint(
    entities: &mut [Entity],
    constraint: &Constraint,
) -> CommandResult {
    let tangent = tangent_targets_from_entities(entities, &constraint.targets)?;
    let aligned_tangent = arc_tangent_direction_for_line_continuation(
        tangent.line_direction_to_connection,
        tangent.arc_endpoint,
    )?;
    let sweep_sign = if tangent.arc.sweep_angle_rad < 0.0 {
        -1.0
    } else {
        1.0
    };
    let endpoint_radius_angle =
        aligned_tangent.y_mm.atan2(aligned_tangent.x_mm) - sweep_sign * std::f64::consts::FRAC_PI_2;
    let adjusted_arc =
        tangent_arc_preserving_opposite_endpoint(&tangent, endpoint_radius_angle, sweep_sign)
            .unwrap_or_else(|| {
                tangent_arc_preserving_radius_and_sweep(&tangent, endpoint_radius_angle)
            });

    let arc_entity_id = constraint_target_entity_id(&tangent.arc_target).to_owned();
    let entity = find_entity_mut(entities, &arc_entity_id)
        .ok_or_else(|| CommandError::broken_reference("constraint", "entity", &arc_entity_id))?;
    match &mut entity.kind {
        EntityKind::Arc(arc) => {
            *arc = adjusted_arc;
            entity.validate().map_err(CommandError::InvalidEntity)
        }
        _ => Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "tangent constraints require an arc target",
        }),
    }
}

fn tangent_arc_preserving_opposite_endpoint(
    tangent: &TangentTargets,
    endpoint_radius_angle: f64,
    sweep_sign: f64,
) -> Option<crate::geometry::Arc> {
    let endpoint_radius = Point2::new(endpoint_radius_angle.cos(), endpoint_radius_angle.sin());
    let opposite = match tangent.arc_endpoint {
        ControlPointKind::Start => point_on_arc(
            &tangent.arc,
            tangent.arc.start_angle_rad + tangent.arc.sweep_angle_rad,
        ),
        ControlPointKind::End => point_on_arc(&tangent.arc, tangent.arc.start_angle_rad),
        ControlPointKind::Center => return None,
    };
    let delta = Point2::new(
        opposite.x_mm - tangent.connection_point.x_mm,
        opposite.y_mm - tangent.connection_point.y_mm,
    );
    let denominator = 2.0 * dot_product(delta, endpoint_radius);
    if denominator.abs() <= GEOMETRY_EPSILON_MM {
        return None;
    }
    let radius_mm = -(delta.x_mm * delta.x_mm + delta.y_mm * delta.y_mm) / denominator;
    if radius_mm <= GEOMETRY_EPSILON_MM || !radius_mm.is_finite() {
        return None;
    }
    let center = Point2::new(
        tangent.connection_point.x_mm - radius_mm * endpoint_radius.x_mm,
        tangent.connection_point.y_mm - radius_mm * endpoint_radius.y_mm,
    );
    let opposite_angle = (opposite.y_mm - center.y_mm).atan2(opposite.x_mm - center.x_mm);
    let sweep_angle_rad = match tangent.arc_endpoint {
        ControlPointKind::Start => signed_sweep(endpoint_radius_angle, opposite_angle, sweep_sign),
        ControlPointKind::End => signed_sweep(opposite_angle, endpoint_radius_angle, sweep_sign),
        ControlPointKind::Center => return None,
    };
    if sweep_angle_rad.abs() <= GEOMETRY_EPSILON_MM {
        return None;
    }
    let start_angle_rad = match tangent.arc_endpoint {
        ControlPointKind::Start => endpoint_radius_angle,
        ControlPointKind::End => opposite_angle,
        ControlPointKind::Center => return None,
    };
    Some(crate::geometry::Arc {
        center,
        radius_mm,
        start_angle_rad,
        sweep_angle_rad,
    })
}

fn tangent_arc_preserving_radius_and_sweep(
    tangent: &TangentTargets,
    endpoint_radius_angle: f64,
) -> crate::geometry::Arc {
    let center = Point2::new(
        tangent.connection_point.x_mm - tangent.arc.radius_mm * endpoint_radius_angle.cos(),
        tangent.connection_point.y_mm - tangent.arc.radius_mm * endpoint_radius_angle.sin(),
    );
    let start_angle_rad = match tangent.arc_endpoint {
        ControlPointKind::Start => endpoint_radius_angle,
        ControlPointKind::End => endpoint_radius_angle - tangent.arc.sweep_angle_rad,
        ControlPointKind::Center => tangent.arc.start_angle_rad,
    };
    crate::geometry::Arc {
        center,
        radius_mm: tangent.arc.radius_mm,
        start_angle_rad,
        sweep_angle_rad: tangent.arc.sweep_angle_rad,
    }
}

fn signed_sweep(start_angle_rad: f64, end_angle_rad: f64, sweep_sign: f64) -> f64 {
    if sweep_sign < 0.0 {
        -normalize_positive_angle(start_angle_rad - end_angle_rad)
    } else {
        normalize_positive_angle(end_angle_rad - start_angle_rad)
    }
}

fn arc_tangent_direction_for_line_continuation(
    line_direction_to_connection: Point2,
    endpoint: ControlPointKind,
) -> CommandResult<Point2> {
    match endpoint {
        ControlPointKind::Start => Ok(line_direction_to_connection),
        ControlPointKind::End => Ok(Point2::new(
            -line_direction_to_connection.x_mm,
            -line_direction_to_connection.y_mm,
        )),
        ControlPointKind::Center => Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "tangent constraints require arc start or end endpoints",
        }),
    }
}

pub(in crate::document) fn apply_angle_constraint(
    entities: &mut [Entity],
    constraint: &Constraint,
) -> CommandResult {
    let angle_rad =
        resolve_degrees_value(constraint.value.as_ref(), "angle constraint value")?.to_radians();
    match constraint.targets.as_slice() {
        [_, second] => {
            let angle_lines =
                shared_endpoint_angle_lines_from_targets(entities, &constraint.targets)?;
            let rotated_direction = rotate_direction(angle_lines.first_direction, angle_rad);
            let moved_opposite = Point2::new(
                angle_lines.shared_point.x_mm
                    + rotated_direction.x_mm * angle_lines.second_length_mm,
                angle_lines.shared_point.y_mm
                    + rotated_direction.y_mm * angle_lines.second_length_mm,
            );
            let update_endpoint = match angle_lines.second_shared_endpoint {
                ControlPointKind::Start => ControlPointKind::End,
                ControlPointKind::End => ControlPointKind::Start,
                ControlPointKind::Center => {
                    return Err(CommandError::InvalidValue {
                        field: "constraint targets",
                        reason: "angle constraints require line start or end endpoints",
                    });
                }
            };
            set_line_endpoint_for_entity_target(entities, second, update_endpoint, moved_opposite)
        }
        [ConstraintTarget::Entity(entity_id)] => {
            let entity = find_entity_mut(entities, entity_id)
                .ok_or_else(|| CommandError::broken_reference("constraint", "entity", entity_id))?;
            match &mut entity.kind {
                EntityKind::Arc(arc) => {
                    arc.sweep_angle_rad = angle_rad;
                    entity.validate().map_err(CommandError::InvalidEntity)
                }
                _ => Err(CommandError::InvalidValue {
                    field: "constraint targets",
                    reason: "angle constraints require an arc target",
                }),
            }
        }
        _ => Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "angle constraints require exactly two line targets or one arc target",
        }),
    }
}

pub(in crate::document) fn apply_symmetric_constraint(
    entities: &mut [Entity],
    constraint: &Constraint,
) -> CommandResult {
    match constraint.targets.as_slice() {
        [first, second, axis] => {
            let anchor = point_for_target(entities, first)?;
            let axis_line = line_for_entity_target(entities, axis)?;
            let mirrored = mirror_point_across_line(anchor, axis_line);
            set_point_for_target(entities, second, mirrored)
        }
        _ => Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "symmetric constraints require two point targets and one line axis",
        }),
    }
}

fn preserve_line_endpoint_shapes_after_coincident(
    parameters: &[Parameter],
    entities: &mut [Entity],
    constraints: &[Constraint],
) -> CommandResult {
    for constraint in constraints {
        if !matches!(constraint.kind, ConstraintKind::Coincident) {
            continue;
        }
        for target in &constraint.targets {
            if let ConstraintTarget::ControlPoint { entity_id, point } = target {
                if matches!(point, ControlPointKind::Start | ControlPointKind::End) {
                    preserve_line_shape_from_endpoint(
                        parameters,
                        entities,
                        constraints,
                        entity_id,
                        *point,
                    )?;
                }
            }
        }
    }
    Ok(())
}

fn preserve_line_shape_from_endpoint_target(
    parameters: &[Parameter],
    entities: &mut [Entity],
    constraints: &[Constraint],
    target: &ConstraintTarget,
) -> CommandResult<Option<ConstraintTarget>> {
    let ConstraintTarget::ControlPoint { entity_id, point } = target else {
        return Ok(None);
    };
    if !matches!(point, ControlPointKind::Start | ControlPointKind::End) {
        return Ok(None);
    }

    let opposite = opposite_line_endpoint_target(entity_id, *point);
    let before = point_for_target(entities, &opposite).ok();
    preserve_line_shape_from_endpoint(parameters, entities, constraints, entity_id, *point)?;
    let after = point_for_target(entities, &opposite).ok();
    if matches!((before, after), (Some(before), Some(after)) if !points_approximately_equal(before, after))
    {
        Ok(Some(opposite))
    } else {
        Ok(None)
    }
}

fn opposite_line_endpoint_target(entity_id: &str, point: ControlPointKind) -> ConstraintTarget {
    ConstraintTarget::ControlPoint {
        entity_id: entity_id.to_owned(),
        point: match point {
            ControlPointKind::Start => ControlPointKind::End,
            ControlPointKind::End => ControlPointKind::Start,
            ControlPointKind::Center => ControlPointKind::Center,
        },
    }
}

#[derive(Debug, Default)]
struct LineShapeProfile {
    horizontal: bool,
    vertical: bool,
    length_mm: Option<f64>,
}

fn preserve_line_shape_from_endpoint(
    parameters: &[Parameter],
    entities: &mut [Entity],
    constraints: &[Constraint],
    entity_id: &str,
    anchor_point: ControlPointKind,
) -> CommandResult {
    let profile = line_shape_profile(parameters, constraints, entity_id)?;
    if !profile.horizontal && !profile.vertical && profile.length_mm.is_none() {
        return Ok(());
    }

    let entity = find_entity_mut(entities, entity_id)
        .ok_or_else(|| CommandError::broken_reference("constraint", "entity", entity_id))?;
    let line = match &mut entity.kind {
        EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => line,
        _ => return Ok(()),
    };

    let (anchor, opposite) = match anchor_point {
        ControlPointKind::Start => (line.start, line.end),
        ControlPointKind::End => (line.end, line.start),
        _ => return Ok(()),
    };
    let next_opposite = constrained_opposite_point(anchor, opposite, &profile);
    match anchor_point {
        ControlPointKind::Start => line.end = next_opposite,
        ControlPointKind::End => line.start = next_opposite,
        _ => {}
    }
    entity.validate().map_err(CommandError::InvalidEntity)
}

fn line_shape_profile(
    parameters: &[Parameter],
    constraints: &[Constraint],
    entity_id: &str,
) -> CommandResult<LineShapeProfile> {
    let mut profile = LineShapeProfile::default();
    for constraint in constraints {
        if !matches!(
            constraint.targets.as_slice(),
            [ConstraintTarget::Entity(target_entity_id)] if target_entity_id == entity_id
        ) {
            continue;
        }
        match constraint.kind {
            ConstraintKind::Horizontal => profile.horizontal = true,
            ConstraintKind::Vertical => profile.vertical = true,
            ConstraintKind::Distance | ConstraintKind::SegmentLength => {
                profile.length_mm = Some(resolve_length_value_mm(
                    parameters,
                    constraint.value.as_ref(),
                    "line dimension value",
                )?);
            }
            _ => {}
        }
    }
    Ok(profile)
}

fn constrained_opposite_point(
    anchor: Point2,
    opposite: Point2,
    profile: &LineShapeProfile,
) -> Point2 {
    let fallback_length = distance_between(anchor, opposite);
    let length_mm = profile.length_mm.unwrap_or(fallback_length);
    if profile.horizontal {
        if profile.length_mm.is_none() {
            return Point2::new(opposite.x_mm, anchor.y_mm);
        }
        let direction_sign = horizontal_direction_sign(anchor, opposite);
        return Point2::new(anchor.x_mm + length_mm * direction_sign, anchor.y_mm);
    }
    if profile.vertical {
        if profile.length_mm.is_none() {
            return Point2::new(anchor.x_mm, opposite.y_mm);
        }
        let direction_sign = vertical_direction_sign(anchor, opposite);
        return Point2::new(anchor.x_mm, anchor.y_mm + length_mm * direction_sign);
    }
    if profile.length_mm.is_some() {
        let direction = normalized_direction(anchor, opposite);
        return Point2::new(
            anchor.x_mm + direction.x_mm * length_mm,
            anchor.y_mm + direction.y_mm * length_mm,
        );
    }
    opposite
}

fn solve_axis_aligned_line_rectangles(
    parameters: &[Parameter],
    entities: &mut [Entity],
    constraints: &[Constraint],
) -> CommandResult {
    let line_ids: Vec<String> = entities
        .iter()
        .filter(|entity| matches!(entity.kind, EntityKind::LineSegment(_)))
        .map(|entity| entity.id.clone())
        .collect();
    if line_ids.len() < 4 {
        return Ok(());
    }

    let point_targets = line_ids
        .iter()
        .flat_map(|entity_id| {
            [
                ConstraintTarget::ControlPoint {
                    entity_id: entity_id.clone(),
                    point: ControlPointKind::Start,
                },
                ConstraintTarget::ControlPoint {
                    entity_id: entity_id.clone(),
                    point: ControlPointKind::End,
                },
            ]
        })
        .collect::<Vec<_>>();

    let mut groups = PointTargetGroups::new(entities, point_targets.clone());
    for constraint in constraints {
        if matches!(constraint.kind, ConstraintKind::Coincident) {
            if let [first, second] = constraint.targets.as_slice() {
                groups.union(first, second);
            }
        }
    }

    let horizontal_ids = constraints
        .iter()
        .filter(|constraint| matches!(constraint.kind, ConstraintKind::Horizontal))
        .filter_map(single_entity_line_target_id)
        .collect::<std::collections::BTreeSet<_>>();
    let vertical_ids = constraints
        .iter()
        .filter(|constraint| matches!(constraint.kind, ConstraintKind::Vertical))
        .filter_map(single_entity_line_target_id)
        .collect::<std::collections::BTreeSet<_>>();

    let fixed_targets = constraints
        .iter()
        .filter(|constraint| matches!(constraint.kind, ConstraintKind::Fixed))
        .filter_map(|constraint| match constraint.targets.as_slice() {
            [target] => Some(target.clone()),
            _ => None,
        })
        .collect::<Vec<_>>();
    let anchor_candidates = if fixed_targets.is_empty() {
        point_targets
    } else {
        fixed_targets
    };

    let mut solved_anchor_groups = std::collections::BTreeSet::new();
    for anchor_target in anchor_candidates {
        let Some(anchor_group) = groups.group_key(&anchor_target) else {
            continue;
        };
        if !solved_anchor_groups.insert(anchor_group.clone()) {
            continue;
        }
        let Some(anchor) = point_for_target(entities, &anchor_target).ok() else {
            continue;
        };
        let Some(horizontal_anchor) =
            connected_line_from_group(&groups, &horizontal_ids, &anchor_group)
        else {
            continue;
        };
        let Some(vertical_anchor) =
            connected_line_from_group(&groups, &vertical_ids, &anchor_group)
        else {
            continue;
        };
        let width_sign = sign_or_positive(horizontal_anchor.other_point.x_mm - anchor.x_mm);
        let height_sign = sign_or_positive(vertical_anchor.other_point.y_mm - anchor.y_mm);
        let width_group = horizontal_anchor.other_group;
        let height_group = vertical_anchor.other_group;

        let Some(opposite_group) = rectangle_diagonal_corner_group(
            &groups,
            &horizontal_ids,
            &vertical_ids,
            &width_group,
            &height_group,
        ) else {
            continue;
        };
        let Some(width_mm) = dimension_between_parallel_groups(
            parameters,
            constraints,
            &groups,
            &horizontal_ids,
            [
                (anchor_group.as_str(), width_group.as_str()),
                (height_group.as_str(), opposite_group.as_str()),
            ],
        )?
        else {
            continue;
        };
        let Some(height_mm) = dimension_between_parallel_groups(
            parameters,
            constraints,
            &groups,
            &vertical_ids,
            [
                (anchor_group.as_str(), height_group.as_str()),
                (width_group.as_str(), opposite_group.as_str()),
            ],
        )?
        else {
            continue;
        };

        let width_group_point = Point2::new(anchor.x_mm + width_sign * width_mm, anchor.y_mm);
        let height_group_point = Point2::new(anchor.x_mm, anchor.y_mm + height_sign * height_mm);
        let opposite_group_point = Point2::new(width_group_point.x_mm, height_group_point.y_mm);

        set_group_point(entities, &groups, &anchor_group, anchor)?;
        set_group_point(entities, &groups, &width_group, width_group_point)?;
        set_group_point(entities, &groups, &height_group, height_group_point)?;
        set_group_point(entities, &groups, &opposite_group, opposite_group_point)?;
    }

    Ok(())
}

fn single_entity_line_target_id(constraint: &Constraint) -> Option<String> {
    match constraint.targets.as_slice() {
        [ConstraintTarget::Entity(entity_id)] => Some(entity_id.clone()),
        _ => None,
    }
}

fn dimension_for_line(
    parameters: &[Parameter],
    constraints: &[Constraint],
    line_id: &str,
) -> CommandResult<Option<f64>> {
    for constraint in constraints {
        if !matches!(
            constraint.kind,
            ConstraintKind::Distance | ConstraintKind::SegmentLength
        ) {
            continue;
        }
        if !matches!(
            constraint.targets.as_slice(),
            [ConstraintTarget::Entity(entity_id)] if entity_id == line_id
        ) {
            continue;
        }
        return resolve_length_value_mm(
            parameters,
            constraint.value.as_ref(),
            "line dimension value",
        )
        .map(Some);
    }
    Ok(None)
}

fn dimension_between_parallel_groups<'a>(
    parameters: &[Parameter],
    constraints: &[Constraint],
    groups: &PointTargetGroups,
    line_ids: &std::collections::BTreeSet<String>,
    group_pairs: impl IntoIterator<Item = (&'a str, &'a str)>,
) -> CommandResult<Option<f64>> {
    for (first_group, second_group) in group_pairs {
        for entity_id in line_ids {
            if !line_connects_groups(groups, entity_id, first_group, second_group) {
                continue;
            }
            if let Some(value_mm) = dimension_for_line(parameters, constraints, entity_id)? {
                return Ok(Some(value_mm));
            }
        }
    }
    Ok(None)
}

fn line_connects_groups(
    groups: &PointTargetGroups,
    entity_id: &str,
    first_group: &str,
    second_group: &str,
) -> bool {
    let start = ConstraintTarget::ControlPoint {
        entity_id: entity_id.to_owned(),
        point: ControlPointKind::Start,
    };
    let end = ConstraintTarget::ControlPoint {
        entity_id: entity_id.to_owned(),
        point: ControlPointKind::End,
    };
    matches!(
        (groups.group_key(&start), groups.group_key(&end)),
        (Some(start_group), Some(end_group))
            if (start_group == first_group && end_group == second_group)
                || (start_group == second_group && end_group == first_group)
    )
}

#[derive(Debug)]
struct ConnectedLine {
    other_group: String,
    other_point: Point2,
}

fn connected_line_from_group(
    groups: &PointTargetGroups,
    line_ids: &std::collections::BTreeSet<String>,
    group: &str,
) -> Option<ConnectedLine> {
    for entity_id in line_ids {
        let start = ConstraintTarget::ControlPoint {
            entity_id: entity_id.clone(),
            point: ControlPointKind::Start,
        };
        let end = ConstraintTarget::ControlPoint {
            entity_id: entity_id.clone(),
            point: ControlPointKind::End,
        };
        let start_group = groups.group_key(&start)?;
        let end_group = groups.group_key(&end)?;
        if start_group == group && end_group != group {
            return Some(ConnectedLine {
                other_group: end_group,
                other_point: groups.point_for_group(&end)?,
            });
        }
        if end_group == group && start_group != group {
            return Some(ConnectedLine {
                other_group: start_group,
                other_point: groups.point_for_group(&start)?,
            });
        }
    }
    None
}

fn rectangle_diagonal_corner_group(
    groups: &PointTargetGroups,
    horizontal_ids: &std::collections::BTreeSet<String>,
    vertical_ids: &std::collections::BTreeSet<String>,
    width_group: &str,
    height_group: &str,
) -> Option<String> {
    let from_width = connected_neighbor_groups(groups, vertical_ids, width_group);
    let from_height = connected_neighbor_groups(groups, horizontal_ids, height_group);
    from_width
        .into_iter()
        .find(|candidate| from_height.contains(candidate))
}

fn connected_neighbor_groups(
    groups: &PointTargetGroups,
    line_ids: &std::collections::BTreeSet<String>,
    group: &str,
) -> Vec<String> {
    line_ids
        .iter()
        .filter_map(|entity_id| {
            let start = ConstraintTarget::ControlPoint {
                entity_id: entity_id.clone(),
                point: ControlPointKind::Start,
            };
            let end = ConstraintTarget::ControlPoint {
                entity_id: entity_id.clone(),
                point: ControlPointKind::End,
            };
            let start_group = groups.group_key(&start)?;
            let end_group = groups.group_key(&end)?;
            if start_group == group && end_group != group {
                Some(end_group)
            } else if end_group == group && start_group != group {
                Some(start_group)
            } else {
                None
            }
        })
        .collect()
}

fn set_group_point(
    entities: &mut [Entity],
    groups: &PointTargetGroups,
    group: &str,
    point: Point2,
) -> CommandResult {
    for target in groups.targets_in_group(group) {
        set_point_for_target(entities, &target, point)?;
    }
    Ok(())
}

fn sign_or_positive(value: f64) -> f64 {
    if value < 0.0 {
        -1.0
    } else {
        1.0
    }
}

#[derive(Debug)]
struct PointTargetGroups {
    targets: Vec<ConstraintTarget>,
    parent: Vec<usize>,
    points: std::collections::BTreeMap<String, Point2>,
}

impl PointTargetGroups {
    fn new(entities: &[Entity], targets: Vec<ConstraintTarget>) -> Self {
        let points = targets
            .iter()
            .filter_map(|target| {
                point_for_target(entities, target)
                    .ok()
                    .map(|point| (Self::key(target), point))
            })
            .collect();
        let parent = (0..targets.len()).collect();
        Self {
            targets,
            parent,
            points,
        }
    }

    fn union(&mut self, first: &ConstraintTarget, second: &ConstraintTarget) {
        let Some(first_index) = self.index_of(first) else {
            return;
        };
        let Some(second_index) = self.index_of(second) else {
            return;
        };
        let first_root = self.find(first_index);
        let second_root = self.find(second_index);
        if first_root != second_root {
            self.parent[second_root] = first_root;
        }
    }

    fn group_key(&self, target: &ConstraintTarget) -> Option<String> {
        let index = self.index_of(target)?;
        let root = self.root(index);
        Some(Self::key(&self.targets[root]))
    }

    fn point_for_group(&self, target: &ConstraintTarget) -> Option<Point2> {
        self.points.get(&Self::key(target)).copied()
    }

    fn targets_in_group(&self, group: &str) -> Vec<ConstraintTarget> {
        self.targets
            .iter()
            .filter(|target| self.group_key(target).as_deref() == Some(group))
            .cloned()
            .collect()
    }

    fn index_of(&self, target: &ConstraintTarget) -> Option<usize> {
        self.targets
            .iter()
            .position(|candidate| candidate == target)
    }

    fn root(&self, mut index: usize) -> usize {
        while self.parent[index] != index {
            index = self.parent[index];
        }
        index
    }

    fn find(&mut self, index: usize) -> usize {
        let root = self.root(index);
        self.parent[index] = root;
        root
    }

    fn key(target: &ConstraintTarget) -> String {
        match target {
            ConstraintTarget::Entity(entity_id) => format!("{entity_id}#entity"),
            ConstraintTarget::ControlPoint { entity_id, point } => {
                format!("{entity_id}#{point:?}")
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::geometry::Arc;

    fn point(x_mm: f64, y_mm: f64) -> Point2 {
        Point2::new(x_mm, y_mm)
    }

    fn entity(id: &str, kind: EntityKind) -> Entity {
        Entity::new(id, kind)
    }

    fn line(start: Point2, end: Point2) -> LineSegment {
        LineSegment::new(start, end)
    }

    fn target(entity_id: &str) -> ConstraintTarget {
        ConstraintTarget::Entity(entity_id.to_owned())
    }

    fn point_target(entity_id: &str, point: ControlPointKind) -> ConstraintTarget {
        ConstraintTarget::ControlPoint {
            entity_id: entity_id.to_owned(),
            point,
        }
    }

    fn assert_line_close(actual: LineSegment, expected: LineSegment) {
        assert!((actual.start.x_mm - expected.start.x_mm).abs() <= GEOMETRY_EPSILON_MM);
        assert!((actual.start.y_mm - expected.start.y_mm).abs() <= GEOMETRY_EPSILON_MM);
        assert!((actual.end.x_mm - expected.end.x_mm).abs() <= GEOMETRY_EPSILON_MM);
        assert!((actual.end.y_mm - expected.end.y_mm).abs() <= GEOMETRY_EPSILON_MM);
    }

    fn constraint(
        kind: ConstraintKind,
        targets: Vec<ConstraintTarget>,
        value: Option<ConstraintValue>,
    ) -> Constraint {
        Constraint {
            id: "constraint:test".to_owned(),
            kind,
            targets,
            value,
            status: ConstraintStatus::Unknown,
        }
    }

    fn entities_for_apply_tests() -> Vec<Entity> {
        vec![
            entity("point:a", EntityKind::Point(point(0.0, 0.0))),
            entity("point:b", EntityKind::Point(point(4.0, 3.0))),
            entity(
                "line:a",
                EntityKind::LineSegment(line(point(0.0, 0.0), point(10.0, 0.0))),
            ),
            entity(
                "line:b",
                EntityKind::LineSegment(line(point(0.0, 0.0), point(5.0, 7.0))),
            ),
            entity(
                "axis",
                EntityKind::CenterLine(line(point(0.0, -10.0), point(0.0, 10.0))),
            ),
            entity(
                "circle",
                EntityKind::Circle(Circle {
                    center: point(2.0, 2.0),
                    radius_mm: 3.0,
                }),
            ),
            entity(
                "arc",
                EntityKind::Arc(Arc {
                    center: point(20.0, 20.0),
                    radius_mm: 5.0,
                    start_angle_rad: 0.0,
                    sweep_angle_rad: std::f64::consts::FRAC_PI_2,
                }),
            ),
        ]
    }

    fn parameter() -> Parameter {
        Parameter {
            id: "parameter:length".to_owned(),
            name: "length".to_owned(),
            value_mm: 12.0,
            unit: crate::parameters::ParameterUnit::Millimeter,
            memo: String::new(),
        }
    }

    #[test]
    fn applies_each_constraint_kind_through_dispatch() {
        let parameters = vec![parameter()];
        let mut entities = entities_for_apply_tests();

        for constraint in [
            constraint(ConstraintKind::Horizontal, vec![target("line:b")], None),
            constraint(ConstraintKind::Vertical, vec![target("line:b")], None),
            constraint(ConstraintKind::Fixed, vec![target("point:a")], None),
            constraint(
                ConstraintKind::Coincident,
                vec![target("point:a"), target("point:b")],
                None,
            ),
            constraint(
                ConstraintKind::SegmentLength,
                vec![target("line:a")],
                Some(ConstraintValue::Parameter("parameter:length".to_owned())),
            ),
            constraint(
                ConstraintKind::Diameter,
                vec![target("circle")],
                Some(ConstraintValue::FixedMm(10.0)),
            ),
            constraint(
                ConstraintKind::Radius,
                vec![target("arc")],
                Some(ConstraintValue::FixedMm(7.0)),
            ),
            constraint(
                ConstraintKind::Distance,
                vec![target("point:a"), target("point:b")],
                Some(ConstraintValue::FixedMm(5.0)),
            ),
            constraint(
                ConstraintKind::HorizontalDistance,
                vec![target("point:a"), target("point:b")],
                Some(ConstraintValue::FixedMm(6.0)),
            ),
            constraint(
                ConstraintKind::VerticalDistance,
                vec![target("point:a"), target("point:b")],
                Some(ConstraintValue::FixedMm(4.0)),
            ),
            constraint(
                ConstraintKind::Parallel,
                vec![target("line:a"), target("line:b")],
                None,
            ),
            constraint(
                ConstraintKind::Perpendicular,
                vec![target("line:a"), target("line:b")],
                None,
            ),
            constraint(
                ConstraintKind::Angle,
                vec![target("line:a"), target("line:b")],
                Some(ConstraintValue::FixedDegrees(90.0)),
            ),
            constraint(
                ConstraintKind::EqualSegmentLength,
                vec![target("line:a"), target("line:b")],
                None,
            ),
            constraint(
                ConstraintKind::Symmetric,
                vec![target("point:a"), target("point:b"), target("axis")],
                None,
            ),
        ] {
            apply_constraint_effect_to_entities(&parameters, &mut entities, &constraint)
                .expect("constraint should apply");
        }
    }

    #[test]
    fn applies_point_constraint_shapes() {
        let mut entities = entities_for_apply_tests();

        apply_horizontal_constraint(
            &mut entities,
            &constraint(
                ConstraintKind::Horizontal,
                vec![target("point:a"), target("point:b")],
                None,
            ),
        )
        .expect("two point horizontal should apply");
        apply_vertical_constraint(
            &mut entities,
            &constraint(
                ConstraintKind::Vertical,
                vec![target("point:a"), target("point:b")],
                None,
            ),
        )
        .expect("two point vertical should apply");
    }

    #[test]
    fn horizontal_and_vertical_line_constraints_preserve_length_and_direction_sign() {
        let mut entities = vec![
            entity(
                "line:horizontal",
                EntityKind::LineSegment(line(point(2.0, 3.0), point(-1.0, 7.0))),
            ),
            entity(
                "line:vertical",
                EntityKind::LineSegment(line(point(2.0, 3.0), point(-2.0, -1.0))),
            ),
        ];

        apply_horizontal_constraint(
            &mut entities,
            &constraint(
                ConstraintKind::Horizontal,
                vec![target("line:horizontal")],
                None,
            ),
        )
        .expect("horizontal line constraint should apply");
        apply_vertical_constraint(
            &mut entities,
            &constraint(
                ConstraintKind::Vertical,
                vec![target("line:vertical")],
                None,
            ),
        )
        .expect("vertical line constraint should apply");

        assert_eq!(
            line_for_entity_target(&entities, &target("line:horizontal")).unwrap(),
            line(point(2.0, 3.0), point(-3.0, 3.0))
        );
        let vertical = line_for_entity_target(&entities, &target("line:vertical")).unwrap();
        assert_eq!(vertical.start, point(2.0, 3.0));
        assert!((vertical.end.x_mm - 2.0).abs() <= GEOMETRY_EPSILON_MM);
        assert!((vertical.end.y_mm - (3.0 - 32.0_f64.sqrt())).abs() <= GEOMETRY_EPSILON_MM);
    }

    #[test]
    fn propagation_allows_exact_iteration_budget_without_constraints() {
        let parameters = Vec::new();
        let mut entities = vec![entity("point", EntityKind::Point(point(1.0, 2.0)))];
        let constraints = Vec::new();
        let seeds = std::iter::repeat_n(target("point"), 64).collect::<Vec<_>>();

        let result = PropagationGraph::new(&constraints)
            .propagate_connected_endpoint_changes(&parameters, &mut entities, seeds)
            .expect("exact iteration budget should be allowed");

        assert_eq!(
            result,
            PropagationResult {
                seed_count: 64,
                visited_target_count: 64,
                iterations: 64,
            }
        );
    }

    #[test]
    fn sign_or_positive_keeps_zero_width_and_height_rectangles_positive() {
        assert_eq!(sign_or_positive(-GEOMETRY_EPSILON_MM), -1.0);
        assert_eq!(sign_or_positive(0.0), 1.0);
        assert_eq!(sign_or_positive(GEOMETRY_EPSILON_MM), 1.0);
    }

    #[test]
    fn point_and_line_distance_constraints_keep_signed_side_on_skew_lines() {
        let parameters = Vec::new();
        let mut entities = vec![
            entity("point", EntityKind::Point(point(7.0, 1.0))),
            entity(
                "reference",
                EntityKind::LineSegment(line(point(1.0, 2.0), point(5.0, 5.0))),
            ),
            entity(
                "target",
                EntityKind::LineSegment(line(point(6.0, 0.0), point(9.0, 4.0))),
            ),
        ];
        let reference = line(point(1.0, 2.0), point(5.0, 5.0));
        let initial_line_side = signed_point_line_distance(point(6.0, 0.0), reference).signum();

        apply_point_line_distance_constraint(
            &parameters,
            &mut entities,
            &constraint(
                ConstraintKind::PointLineDistance,
                vec![target("point"), target("reference")],
                Some(ConstraintValue::FixedMm(5.0)),
            ),
        )
        .expect("point-line distance should apply");
        apply_line_line_distance_constraint(
            &parameters,
            &mut entities,
            &constraint(
                ConstraintKind::LineLineDistance,
                vec![target("reference"), target("target")],
                Some(ConstraintValue::FixedMm(3.0)),
            ),
        )
        .expect("line-line distance should apply");

        let moved_point = point_for_target(&entities, &target("point")).unwrap();
        assert!(
            (signed_point_line_distance(moved_point, reference).abs() - 5.0).abs()
                <= GEOMETRY_EPSILON_MM
        );

        let moved_target = line_for_entity_target(&entities, &target("target")).unwrap();
        assert!(
            (signed_point_line_distance(moved_target.start, reference).abs() - 3.0).abs()
                <= GEOMETRY_EPSILON_MM
        );
        assert_eq!(
            signed_point_line_distance(moved_target.start, reference).signum(),
            initial_line_side
        );
        assert!((moved_target.length_mm() - 5.0).abs() <= GEOMETRY_EPSILON_MM);
    }

    #[test]
    fn axis_distance_constraints_move_only_the_target_axis() {
        let parameters = Vec::new();
        let mut horizontal_entities = vec![
            entity("anchor", EntityKind::Point(point(2.0, 3.0))),
            entity("target", EntityKind::Point(point(9.0, 11.0))),
        ];
        apply_axis_distance_constraint(
            &parameters,
            &mut horizontal_entities,
            &constraint(
                ConstraintKind::HorizontalDistance,
                vec![target("anchor"), target("target")],
                Some(ConstraintValue::FixedMm(20.0)),
            ),
            Axis::Horizontal,
        )
        .expect("horizontal distance should apply");
        let moved = point_for_target(&horizontal_entities, &target("target")).unwrap();
        assert!(((moved.x_mm - 2.0).abs() - 20.0).abs() <= GEOMETRY_EPSILON_MM);
        assert!((moved.y_mm - 11.0).abs() <= GEOMETRY_EPSILON_MM);

        let mut vertical_entities = vec![
            entity("anchor", EntityKind::Point(point(2.0, 3.0))),
            entity("target", EntityKind::Point(point(9.0, -11.0))),
        ];
        apply_axis_distance_constraint(
            &parameters,
            &mut vertical_entities,
            &constraint(
                ConstraintKind::VerticalDistance,
                vec![target("anchor"), target("target")],
                Some(ConstraintValue::FixedMm(15.0)),
            ),
            Axis::Vertical,
        )
        .expect("vertical distance should apply");
        let moved = point_for_target(&vertical_entities, &target("target")).unwrap();
        assert!((moved.x_mm - 9.0).abs() <= GEOMETRY_EPSILON_MM);
        assert!(((moved.y_mm - 3.0).abs() - 15.0).abs() <= GEOMETRY_EPSILON_MM);
    }

    #[test]
    fn solve_constraint_system_combines_axis_and_euclidean_distance_constraints() {
        let parameters = Vec::new();
        let entities = vec![
            entity("anchor", EntityKind::Point(point(0.0, 0.0))),
            entity("target", EntityKind::Point(point(6.0, 4.0))),
        ];
        let constraints = vec![
            constraint(
                ConstraintKind::HorizontalDistance,
                vec![target("anchor"), target("target")],
                Some(ConstraintValue::FixedMm(6.0)),
            ),
            constraint(
                ConstraintKind::Distance,
                vec![target("anchor"), target("target")],
                Some(ConstraintValue::FixedMm(10.0)),
            ),
        ];

        let solved = solve_constraint_system(&parameters, &entities, &constraints)
            .expect("mixed distance constraints should solve");
        let moved = point_for_target(&solved, &target("target")).unwrap();

        assert!((moved.x_mm - 6.0).abs() <= GEOMETRY_EPSILON_MM);
        assert!((moved.y_mm - 8.0).abs() <= GEOMETRY_EPSILON_MM);
        assert!((distance_between(point(0.0, 0.0), moved) - 10.0).abs() <= GEOMETRY_EPSILON_MM);
    }

    #[test]
    fn perpendicular_constraint_uses_closest_perpendicular_direction_and_preserves_length() {
        let mut entities = vec![
            entity(
                "reference",
                EntityKind::LineSegment(line(point(0.0, 0.0), point(3.0, 4.0))),
            ),
            entity(
                "target",
                EntityKind::LineSegment(line(point(10.0, 10.0), point(14.0, 13.0))),
            ),
        ];

        apply_perpendicular_constraint(
            &mut entities,
            &constraint(
                ConstraintKind::Perpendicular,
                vec![target("reference"), target("target")],
                None,
            ),
        )
        .expect("perpendicular constraint should apply");

        assert_eq!(
            line_for_entity_target(&entities, &target("target")).unwrap(),
            line(point(10.0, 10.0), point(14.0, 7.0))
        );
    }

    #[test]
    fn preserving_line_shape_from_end_endpoint_keeps_vertical_length_constraint() {
        let parameters = Vec::new();
        let mut entities = vec![entity(
            "line",
            EntityKind::LineSegment(line(point(0.0, 0.0), point(3.0, 4.0))),
        )];
        let constraints = vec![
            constraint(ConstraintKind::Vertical, vec![target("line")], None),
            constraint(
                ConstraintKind::SegmentLength,
                vec![target("line")],
                Some(ConstraintValue::FixedMm(10.0)),
            ),
        ];

        preserve_line_shape_from_endpoint(
            &parameters,
            &mut entities,
            &constraints,
            "line",
            ControlPointKind::End,
        )
        .expect("line shape should be preserved from end");

        assert_eq!(
            line_for_entity_target(&entities, &target("line")).unwrap(),
            line(point(3.0, -6.0), point(3.0, 4.0))
        );
    }

    #[test]
    fn point_target_groups_only_match_requested_rectangle_edges() {
        let entities = vec![
            entity(
                "bottom",
                EntityKind::LineSegment(line(point(0.0, 0.0), point(20.0, 0.0))),
            ),
            entity(
                "right",
                EntityKind::LineSegment(line(point(20.0, 0.0), point(20.0, 10.0))),
            ),
            entity(
                "top",
                EntityKind::LineSegment(line(point(20.0, 10.0), point(0.0, 10.0))),
            ),
            entity(
                "left",
                EntityKind::LineSegment(line(point(0.0, 10.0), point(0.0, 0.0))),
            ),
        ];
        let targets = ["bottom", "right", "top", "left"]
            .iter()
            .flat_map(|entity_id| {
                [
                    point_target(entity_id, ControlPointKind::Start),
                    point_target(entity_id, ControlPointKind::End),
                ]
            })
            .collect::<Vec<_>>();
        let mut groups = PointTargetGroups::new(&entities, targets);
        groups.union(
            &point_target("bottom", ControlPointKind::Start),
            &point_target("left", ControlPointKind::End),
        );
        groups.union(
            &point_target("bottom", ControlPointKind::End),
            &point_target("right", ControlPointKind::Start),
        );

        let bottom_start = groups
            .group_key(&point_target("bottom", ControlPointKind::Start))
            .unwrap();
        let bottom_end = groups
            .group_key(&point_target("bottom", ControlPointKind::End))
            .unwrap();
        let top_start = groups
            .group_key(&point_target("top", ControlPointKind::Start))
            .unwrap();
        let line_ids = std::collections::BTreeSet::from([
            "bottom".to_owned(),
            "right".to_owned(),
            "top".to_owned(),
        ]);

        assert!(line_connects_groups(
            &groups,
            "bottom",
            &bottom_start,
            &bottom_end
        ));
        assert!(!line_connects_groups(
            &groups,
            "top",
            &bottom_start,
            &bottom_end
        ));
        assert_eq!(
            connected_neighbor_groups(&groups, &line_ids, &bottom_end),
            vec![
                bottom_start.clone(),
                groups
                    .group_key(&point_target("right", ControlPointKind::End))
                    .unwrap()
            ]
        );
        assert!(!connected_neighbor_groups(&groups, &line_ids, &top_start).contains(&bottom_start));
    }

    #[test]
    fn rectangle_solver_resizes_from_bottom_right_anchor_with_negative_width_sign() {
        let parameters = Vec::new();
        let mut entities = vec![
            entity(
                "bottom",
                EntityKind::LineSegment(line(point(40.0, 50.0), point(50.0, 50.0))),
            ),
            entity(
                "right",
                EntityKind::LineSegment(line(point(50.0, 50.0), point(50.0, 55.0))),
            ),
            entity(
                "top",
                EntityKind::LineSegment(line(point(50.0, 55.0), point(40.0, 55.0))),
            ),
            entity(
                "left",
                EntityKind::LineSegment(line(point(40.0, 55.0), point(40.0, 50.0))),
            ),
        ];
        let constraints = vec![
            constraint(ConstraintKind::Horizontal, vec![target("bottom")], None),
            constraint(ConstraintKind::Vertical, vec![target("right")], None),
            constraint(ConstraintKind::Horizontal, vec![target("top")], None),
            constraint(ConstraintKind::Vertical, vec![target("left")], None),
            constraint(
                ConstraintKind::Coincident,
                vec![
                    point_target("bottom", ControlPointKind::End),
                    point_target("right", ControlPointKind::Start),
                ],
                None,
            ),
            constraint(
                ConstraintKind::Coincident,
                vec![
                    point_target("right", ControlPointKind::End),
                    point_target("top", ControlPointKind::Start),
                ],
                None,
            ),
            constraint(
                ConstraintKind::Coincident,
                vec![
                    point_target("top", ControlPointKind::End),
                    point_target("left", ControlPointKind::Start),
                ],
                None,
            ),
            constraint(
                ConstraintKind::Coincident,
                vec![
                    point_target("left", ControlPointKind::End),
                    point_target("bottom", ControlPointKind::Start),
                ],
                None,
            ),
            constraint(
                ConstraintKind::Fixed,
                vec![point_target("bottom", ControlPointKind::End)],
                None,
            ),
            constraint(
                ConstraintKind::SegmentLength,
                vec![target("bottom")],
                Some(ConstraintValue::FixedMm(20.0)),
            ),
            constraint(
                ConstraintKind::SegmentLength,
                vec![target("right")],
                Some(ConstraintValue::FixedMm(10.0)),
            ),
        ];

        solve_axis_aligned_line_rectangles(&parameters, &mut entities, &constraints)
            .expect("rectangle solver should resize");

        assert_line_close(
            line_for_entity_target(&entities, &target("bottom")).unwrap(),
            line(point(30.0, 50.0), point(50.0, 50.0)),
        );
        assert_line_close(
            line_for_entity_target(&entities, &target("right")).unwrap(),
            line(point(50.0, 50.0), point(50.0, 60.0)),
        );
        assert_line_close(
            line_for_entity_target(&entities, &target("top")).unwrap(),
            line(point(50.0, 60.0), point(30.0, 60.0)),
        );
        assert_line_close(
            line_for_entity_target(&entities, &target("left")).unwrap(),
            line(point(30.0, 60.0), point(30.0, 50.0)),
        );
    }

    #[test]
    fn propagation_graph_expands_coincident_group_and_reports_result() {
        let parameters = Vec::new();
        let mut entities = vec![
            entity("point:a", EntityKind::Point(point(5.0, 6.0))),
            entity("point:b", EntityKind::Point(point(0.0, 0.0))),
            entity("point:c", EntityKind::Point(point(1.0, 1.0))),
        ];
        let constraints = vec![
            Constraint {
                id: "constraint:a-b".to_owned(),
                kind: ConstraintKind::Coincident,
                targets: vec![target("point:a"), target("point:b")],
                value: None,
                status: ConstraintStatus::Unknown,
            },
            Constraint {
                id: "constraint:b-c".to_owned(),
                kind: ConstraintKind::Coincident,
                targets: vec![target("point:b"), target("point:c")],
                value: None,
                status: ConstraintStatus::Unknown,
            },
        ];
        let graph = PropagationGraph::new(&constraints);

        assert_eq!(
            graph.coincident_group_targets(&target("point:a")),
            vec![target("point:a"), target("point:b"), target("point:c")]
        );

        let result = graph
            .propagate_connected_endpoint_changes(
                &parameters,
                &mut entities,
                vec![target("point:a")],
            )
            .expect("propagation should succeed");

        assert_eq!(
            result,
            PropagationResult {
                seed_count: 1,
                visited_target_count: 3,
                iterations: 1,
            }
        );
        assert_eq!(
            point_for_target(&entities, &target("point:b")).unwrap(),
            point(5.0, 6.0)
        );
        assert_eq!(
            point_for_target(&entities, &target("point:c")).unwrap(),
            point(5.0, 6.0)
        );
    }

    #[test]
    fn rejects_apply_level_invalid_shapes_and_arities() {
        let parameters = vec![parameter()];
        let mut entities = entities_for_apply_tests();

        for result in [
            apply_coincident_constraint(
                &mut entities,
                &constraint(ConstraintKind::Coincident, vec![target("point:a")], None),
            ),
            apply_horizontal_constraint(
                &mut entities,
                &constraint(ConstraintKind::Horizontal, vec![target("circle")], None),
            ),
            apply_horizontal_constraint(
                &mut entities,
                &constraint(
                    ConstraintKind::Horizontal,
                    vec![target("point:a"), target("point:b"), target("line:a")],
                    None,
                ),
            ),
            apply_vertical_constraint(
                &mut entities,
                &constraint(ConstraintKind::Vertical, vec![target("circle")], None),
            ),
            apply_vertical_constraint(
                &mut entities,
                &constraint(
                    ConstraintKind::Vertical,
                    vec![target("point:a"), target("point:b"), target("line:a")],
                    None,
                ),
            ),
            apply_segment_length_constraint(
                &parameters,
                &mut entities,
                &constraint(
                    ConstraintKind::SegmentLength,
                    vec![target("line:a")],
                    Some(ConstraintValue::FixedMm(0.0)),
                ),
            ),
            apply_segment_length_constraint(
                &parameters,
                &mut entities,
                &constraint(
                    ConstraintKind::SegmentLength,
                    vec![target("line:a"), target("line:b")],
                    Some(ConstraintValue::FixedMm(10.0)),
                ),
            ),
            apply_diameter_constraint(
                &parameters,
                &mut entities,
                &constraint(
                    ConstraintKind::Diameter,
                    vec![target("circle")],
                    Some(ConstraintValue::FixedMm(0.0)),
                ),
            ),
            apply_diameter_constraint(
                &parameters,
                &mut entities,
                &constraint(
                    ConstraintKind::Diameter,
                    vec![target("circle"), target("line:a")],
                    Some(ConstraintValue::FixedMm(10.0)),
                ),
            ),
            apply_radius_constraint(
                &parameters,
                &mut entities,
                &constraint(
                    ConstraintKind::Radius,
                    vec![target("arc")],
                    Some(ConstraintValue::FixedMm(0.0)),
                ),
            ),
            apply_radius_constraint(
                &parameters,
                &mut entities,
                &constraint(
                    ConstraintKind::Radius,
                    vec![target("arc"), target("circle")],
                    Some(ConstraintValue::FixedMm(10.0)),
                ),
            ),
            apply_distance_constraint(
                &parameters,
                &mut entities,
                &constraint(
                    ConstraintKind::Distance,
                    vec![target("point:a"), target("point:b"), target("line:a")],
                    Some(ConstraintValue::FixedMm(10.0)),
                ),
            ),
            apply_equal_segment_length_constraint(
                &mut entities,
                &constraint(
                    ConstraintKind::EqualSegmentLength,
                    vec![target("line:a")],
                    None,
                ),
            ),
            apply_parallel_constraint(
                &mut entities,
                &constraint(ConstraintKind::Parallel, vec![target("line:a")], None),
            ),
            apply_perpendicular_constraint(
                &mut entities,
                &constraint(ConstraintKind::Perpendicular, vec![target("line:a")], None),
            ),
            apply_angle_constraint(
                &mut entities,
                &constraint(
                    ConstraintKind::Angle,
                    vec![target("line:a")],
                    Some(ConstraintValue::FixedDegrees(0.0)),
                ),
            ),
            apply_symmetric_constraint(
                &mut entities,
                &constraint(
                    ConstraintKind::Symmetric,
                    vec![target("point:a"), target("point:b")],
                    None,
                ),
            ),
            set_line_length_for_target(
                &mut entities,
                &point_target("line:a", ControlPointKind::Start),
                10.0,
            ),
            set_line_end_for_entity_target(
                &mut entities,
                &point_target("line:a", ControlPointKind::Start),
                point(1.0, 1.0),
            ),
            set_circle_diameter_for_target(
                &mut entities,
                &point_target("circle", ControlPointKind::Center),
                10.0,
            ),
            set_radius_for_target(
                &mut entities,
                &point_target("arc", ControlPointKind::Center),
                10.0,
            ),
            set_point_for_target(&mut entities, &target("line:a"), point(1.0, 1.0)),
        ] {
            assert!(result.is_err());
        }
    }
}
