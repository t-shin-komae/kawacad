use super::*;

pub(in crate::document) fn validate_constraint_semantics(
    document: &ProjectDocument,
    constraint: &Constraint,
) -> CommandResult {
    match constraint.kind {
        ConstraintKind::Horizontal | ConstraintKind::Vertical => {
            ensure_value_kind(
                &constraint.value,
                AllowedConstraintValue::None,
                "orientation constraint value",
            )?;
            require_one_line_or_two_points(document, constraint)
        }
        ConstraintKind::Fixed => {
            ensure_value_kind(
                &constraint.value,
                AllowedConstraintValue::None,
                "fixed constraint value",
            )?;
            require_single_point(document, constraint)
        }
        ConstraintKind::SegmentLength => {
            ensure_value_kind(
                &constraint.value,
                AllowedConstraintValue::Length,
                "segment length value",
            )?;
            require_single_line(document, constraint)
        }
        ConstraintKind::Distance
        | ConstraintKind::HorizontalDistance
        | ConstraintKind::VerticalDistance => {
            ensure_value_kind(
                &constraint.value,
                AllowedConstraintValue::Length,
                "distance constraint value",
            )?;
            require_two_points(
                document,
                constraint,
                "distance constraints require exactly two point targets",
            )
        }
        ConstraintKind::PointLineDistance => {
            ensure_value_kind(
                &constraint.value,
                AllowedConstraintValue::Length,
                "point-line distance value",
            )?;
            require_one_point_and_one_line(document, constraint)
        }
        ConstraintKind::LineLineDistance => {
            ensure_value_kind(
                &constraint.value,
                AllowedConstraintValue::Length,
                "line-line distance value",
            )?;
            require_two_lines(
                document,
                constraint,
                "line-line distance constraints require exactly two line targets",
            )
        }
        ConstraintKind::PointOnLine => {
            ensure_value_kind(
                &constraint.value,
                AllowedConstraintValue::None,
                "point-on-line constraint value",
            )?;
            require_one_point_and_one_line(document, constraint)
        }
        ConstraintKind::Diameter => {
            ensure_value_kind(
                &constraint.value,
                AllowedConstraintValue::Length,
                "diameter value",
            )?;
            require_single_circle(document, constraint)
        }
        ConstraintKind::Radius => {
            ensure_value_kind(
                &constraint.value,
                AllowedConstraintValue::Length,
                "radius value",
            )?;
            require_single_radius_target(document, constraint)
        }
        ConstraintKind::EqualSegmentLength => {
            ensure_value_kind(
                &constraint.value,
                AllowedConstraintValue::None,
                "equal segment length value",
            )?;
            require_two_lines(
                document,
                constraint,
                "equal segment length constraints require exactly two line targets",
            )
        }
        ConstraintKind::Coincident => {
            ensure_value_kind(
                &constraint.value,
                AllowedConstraintValue::None,
                "coincident constraint value",
            )?;
            require_two_points(
                document,
                constraint,
                "coincident constraints require exactly two point targets",
            )
        }
        ConstraintKind::Parallel | ConstraintKind::Perpendicular => {
            ensure_value_kind(
                &constraint.value,
                AllowedConstraintValue::None,
                "line relation constraint value",
            )?;
            require_two_lines(
                document,
                constraint,
                "parallel and perpendicular constraints require exactly two line targets",
            )
        }
        ConstraintKind::Tangent => {
            ensure_value_kind(
                &constraint.value,
                AllowedConstraintValue::None,
                "tangent constraint value",
            )?;
            require_one_line_endpoint_and_one_arc_endpoint(document, constraint)
        }
        ConstraintKind::Angle => {
            ensure_value_kind(
                &constraint.value,
                AllowedConstraintValue::Degrees,
                "angle constraint value",
            )?;
            require_two_lines_or_one_arc(document, constraint)
        }
        ConstraintKind::Symmetric => {
            ensure_value_kind(
                &constraint.value,
                AllowedConstraintValue::None,
                "symmetric constraint value",
            )?;
            require_two_points_and_center_line(document, constraint)
        }
    }
}

pub(in crate::document) fn constraints_are_equivalent(
    document: &ProjectDocument,
    existing: &Constraint,
    candidate: &Constraint,
) -> bool {
    existing.kind == candidate.kind
        && constraint_targets_are_equivalent(document, existing, candidate)
        && constraint_values_are_equivalent(document, existing, candidate)
}

fn constraint_targets_are_equivalent(
    document: &ProjectDocument,
    first: &Constraint,
    second: &Constraint,
) -> bool {
    match first.kind {
        ConstraintKind::Fixed
        | ConstraintKind::SegmentLength
        | ConstraintKind::Diameter
        | ConstraintKind::Radius => first.targets == second.targets,
        ConstraintKind::Coincident
        | ConstraintKind::Distance
        | ConstraintKind::HorizontalDistance
        | ConstraintKind::VerticalDistance
        | ConstraintKind::Parallel
        | ConstraintKind::Perpendicular
        | ConstraintKind::LineLineDistance
        | ConstraintKind::EqualSegmentLength => {
            unordered_pair_targets_match(&first.targets, &second.targets)
        }
        ConstraintKind::Horizontal | ConstraintKind::Vertical => {
            match (first.targets.as_slice(), second.targets.as_slice()) {
                ([first_target], [second_target]) => first_target == second_target,
                ([_, _], [_, _]) => unordered_pair_targets_match(&first.targets, &second.targets),
                _ => false,
            }
        }
        ConstraintKind::PointLineDistance => {
            point_line_targets_match(document, &first.targets, &second.targets)
        }
        ConstraintKind::PointOnLine => {
            point_line_targets_match(document, &first.targets, &second.targets)
        }
        ConstraintKind::Tangent => tangent_targets_match(document, &first.targets, &second.targets),
        ConstraintKind::Angle => angle_targets_match(document, &first.targets, &second.targets),
        ConstraintKind::Symmetric => symmetric_targets_match(&first.targets, &second.targets),
    }
}

fn constraint_values_are_equivalent(
    document: &ProjectDocument,
    first: &Constraint,
    second: &Constraint,
) -> bool {
    match first.kind {
        ConstraintKind::Horizontal
        | ConstraintKind::Vertical
        | ConstraintKind::Fixed
        | ConstraintKind::Coincident
        | ConstraintKind::Parallel
        | ConstraintKind::Perpendicular
        | ConstraintKind::Tangent
        | ConstraintKind::EqualSegmentLength
        | ConstraintKind::Symmetric
        | ConstraintKind::PointOnLine => true,
        ConstraintKind::SegmentLength
        | ConstraintKind::Distance
        | ConstraintKind::HorizontalDistance
        | ConstraintKind::VerticalDistance
        | ConstraintKind::PointLineDistance
        | ConstraintKind::LineLineDistance
        | ConstraintKind::Diameter
        | ConstraintKind::Radius => resolve_length_value_mm(
            &document.parameters,
            first.value.as_ref(),
            "constraint value",
        )
        .ok()
        .zip(
            resolve_length_value_mm(
                &document.parameters,
                second.value.as_ref(),
                "constraint value",
            )
            .ok(),
        )
        .map(|(lhs, rhs)| approx_eq(lhs, rhs))
        .unwrap_or(false),
        ConstraintKind::Angle => {
            resolve_degrees_value(first.value.as_ref(), "angle constraint value")
                .ok()
                .zip(resolve_degrees_value(second.value.as_ref(), "angle constraint value").ok())
                .map(|(lhs, rhs)| {
                    approx_eq(
                        normalize_angle(lhs.to_radians()),
                        normalize_angle(rhs.to_radians()),
                    )
                })
                .unwrap_or(false)
        }
    }
}

fn unordered_pair_targets_match(first: &[ConstraintTarget], second: &[ConstraintTarget]) -> bool {
    first.len() == 2
        && second.len() == 2
        && ((first[0] == second[0] && first[1] == second[1])
            || (first[0] == second[1] && first[1] == second[0]))
}

fn point_line_targets_match(
    document: &ProjectDocument,
    first: &[ConstraintTarget],
    second: &[ConstraintTarget],
) -> bool {
    normalized_point_line_targets(document, first)
        .zip(normalized_point_line_targets(document, second))
        .map(|(lhs, rhs)| lhs == rhs)
        .unwrap_or(false)
}

fn normalized_point_line_targets(
    document: &ProjectDocument,
    targets: &[ConstraintTarget],
) -> Option<(ConstraintTarget, ConstraintTarget)> {
    let [first, second] = targets else {
        return None;
    };
    if point_for_target(&document.entities, first).is_ok()
        && line_for_entity_target(&document.entities, second).is_ok()
    {
        return Some((first.clone(), second.clone()));
    }
    if point_for_target(&document.entities, second).is_ok()
        && line_for_entity_target(&document.entities, first).is_ok()
    {
        return Some((second.clone(), first.clone()));
    }
    None
}

fn angle_targets_match(
    document: &ProjectDocument,
    first: &[ConstraintTarget],
    second: &[ConstraintTarget],
) -> bool {
    match (first, second) {
        ([first_target], [second_target]) => {
            arc_for_entity_target(&document.entities, first_target).is_ok()
                && arc_for_entity_target(&document.entities, second_target).is_ok()
                && first_target == second_target
        }
        ([_, _], [_, _]) => first == second,
        _ => false,
    }
}

fn tangent_targets_match(
    document: &ProjectDocument,
    first: &[ConstraintTarget],
    second: &[ConstraintTarget],
) -> bool {
    let first_constraint = Constraint {
        id: "constraint:tangent:first".to_owned(),
        kind: ConstraintKind::Tangent,
        targets: first.to_vec(),
        value: None,
        status: ConstraintStatus::Unknown,
    };
    let second_constraint = Constraint {
        id: "constraint:tangent:second".to_owned(),
        kind: ConstraintKind::Tangent,
        targets: second.to_vec(),
        value: None,
        status: ConstraintStatus::Unknown,
    };
    tangent_targets_from_document(document, &first_constraint)
        .ok()
        .zip(tangent_targets_from_document(document, &second_constraint).ok())
        .map(|(lhs, rhs)| lhs.line_target == rhs.line_target && lhs.arc_target == rhs.arc_target)
        .unwrap_or(false)
}

fn symmetric_targets_match(first: &[ConstraintTarget], second: &[ConstraintTarget]) -> bool {
    match (first, second) {
        ([first_a, first_b, first_axis], [second_a, second_b, second_axis]) => {
            first_axis == second_axis
                && ((first_a == second_a && first_b == second_b)
                    || (first_a == second_b && first_b == second_a))
        }
        _ => false,
    }
}

fn require_one_line_endpoint_and_one_arc_endpoint(
    document: &ProjectDocument,
    constraint: &Constraint,
) -> CommandResult {
    match tangent_targets_from_document(document, constraint) {
        Ok(_) => Ok(()),
        Err(_) => invalid_constraint_targets_with_reason(
            constraint,
            2,
            &["lineEndpoint", "arcEndpoint"],
            "tangent constraints require connected line and arc endpoints",
        ),
    }
}

fn require_two_lines_or_one_arc(
    document: &ProjectDocument,
    constraint: &Constraint,
) -> CommandResult {
    if shared_endpoint_angle_lines_from_constraint(document, constraint).is_ok() {
        return Ok(());
    }
    if arc_from_single_target(document, constraint).is_some() {
        return Ok(());
    }
    invalid_constraint_targets(constraint, 2, &["line", "arc"])
}

fn require_one_line_or_two_points(
    document: &ProjectDocument,
    constraint: &Constraint,
) -> CommandResult {
    match constraint.targets.as_slice() {
        [target] if is_line_target(document, target) => Ok(()),
        [first, second]
            if is_point_target(document, first)? && is_point_target(document, second)? =>
        {
            Ok(())
        }
        _ if constraint.targets.len() == 1 => invalid_constraint_targets_with_code(
            constraint,
            ConstraintCommandErrorCode::InvalidTarget,
            2,
            &["line", "point"],
        ),
        _ => invalid_constraint_targets(constraint, 2, &["line", "point"]),
    }
}

fn require_one_point_and_one_line(
    document: &ProjectDocument,
    constraint: &Constraint,
) -> CommandResult {
    match constraint.targets.as_slice() {
        [first, second]
            if is_point_target(document, first)? && is_line_target(document, second) =>
        {
            Ok(())
        }
        [first, second]
            if is_line_target(document, first) && is_point_target(document, second)? =>
        {
            Ok(())
        }
        _ => invalid_constraint_targets(constraint, 2, &["point", "line"]),
    }
}

fn require_single_point(document: &ProjectDocument, constraint: &Constraint) -> CommandResult {
    match constraint.targets.as_slice() {
        [target] if is_point_target(document, target)? => Ok(()),
        _ => invalid_constraint_targets(constraint, 1, &["point"]),
    }
}

fn require_two_points(
    document: &ProjectDocument,
    constraint: &Constraint,
    reason: &'static str,
) -> CommandResult {
    match constraint.targets.as_slice() {
        [first, second]
            if is_point_target(document, first)? && is_point_target(document, second)? =>
        {
            Ok(())
        }
        _ => invalid_constraint_targets_with_reason(constraint, 2, &["point"], reason),
    }
}

fn require_single_line(document: &ProjectDocument, constraint: &Constraint) -> CommandResult {
    match constraint.targets.as_slice() {
        [target] if is_line_target(document, target) => Ok(()),
        _ => invalid_constraint_targets(constraint, 1, &["line"]),
    }
}

fn require_two_lines(
    document: &ProjectDocument,
    constraint: &Constraint,
    reason: &'static str,
) -> CommandResult {
    match constraint.targets.as_slice() {
        [first, second] if is_line_target(document, first) && is_line_target(document, second) => {
            Ok(())
        }
        _ => invalid_constraint_targets_with_reason(constraint, 2, &["line"], reason),
    }
}

fn require_single_circle(document: &ProjectDocument, constraint: &Constraint) -> CommandResult {
    match constraint.targets.as_slice() {
        [target] if is_circle_target(document, target) => Ok(()),
        _ => invalid_constraint_targets(constraint, 1, &["circle"]),
    }
}

fn require_single_radius_target(
    document: &ProjectDocument,
    constraint: &Constraint,
) -> CommandResult {
    match constraint.targets.as_slice() {
        [target] if is_radius_target(document, target) => Ok(()),
        _ => invalid_constraint_targets(constraint, 1, &["arc", "circle"]),
    }
}

fn require_two_points_and_center_line(
    document: &ProjectDocument,
    constraint: &Constraint,
) -> CommandResult {
    match constraint.targets.as_slice() {
        [first, second, axis]
            if is_point_target(document, first)?
                && is_point_target(document, second)?
                && is_symmetry_axis_target(document, axis) =>
        {
            Ok(())
        }
        _ => invalid_constraint_targets(constraint, 3, &["point", "line", "centerLine"]),
    }
}

fn invalid_constraint_targets(
    constraint: &Constraint,
    required_target_count: usize,
    expected_target_kinds: &[&'static str],
) -> CommandResult {
    invalid_constraint_targets_with_reason(
        constraint,
        required_target_count,
        expected_target_kinds,
        "invalid constraint targets",
    )
}

fn invalid_constraint_targets_with_code(
    constraint: &Constraint,
    code: ConstraintCommandErrorCode,
    required_target_count: usize,
    expected_target_kinds: &[&'static str],
) -> CommandResult {
    Err(CommandError::Constraint(Box::new(ConstraintCommandError {
        code,
        constraint_kind: constraint.kind,
        constraint_id: constraint.id.clone(),
        target_ids: constraint
            .targets
            .iter()
            .map(constraint_target_id)
            .collect(),
        actual_target_count: Some(constraint.targets.len()),
        required_target_count: Some(required_target_count),
        expected_target_kinds: expected_target_kinds.to_vec(),
        invalid_target_ids: constraint
            .targets
            .iter()
            .map(constraint_target_id)
            .collect(),
        existing_constraint_id: None,
        conflicting_constraint_ids: Vec::new(),
    })))
}

fn invalid_constraint_targets_with_reason(
    constraint: &Constraint,
    required_target_count: usize,
    expected_target_kinds: &[&'static str],
    _reason: &'static str,
) -> CommandResult {
    let actual_target_count = constraint.targets.len();
    let code = if actual_target_count < required_target_count {
        ConstraintCommandErrorCode::InsufficientTargets
    } else {
        ConstraintCommandErrorCode::InvalidTarget
    };
    invalid_constraint_targets_with_code(
        constraint,
        code,
        required_target_count,
        expected_target_kinds,
    )
}

fn is_point_target(
    document: &ProjectDocument,
    target: &ConstraintTarget,
) -> Result<bool, CommandError> {
    let Some(entity) = document.entity(constraint_target_entity_id(target)) else {
        return Ok(false);
    };
    Ok(matches_point_target(entity, target))
}

fn is_line_target(document: &ProjectDocument, target: &ConstraintTarget) -> bool {
    let Some(entity) = document.entity(constraint_target_entity_id(target)) else {
        return false;
    };
    matches_line_target(entity, target)
}

fn is_circle_target(document: &ProjectDocument, target: &ConstraintTarget) -> bool {
    let Some(entity) = document.entity(constraint_target_entity_id(target)) else {
        return false;
    };
    matches!(target, ConstraintTarget::Entity(_)) && matches!(entity.kind, EntityKind::Circle(_))
}

fn is_radius_target(document: &ProjectDocument, target: &ConstraintTarget) -> bool {
    let Some(entity) = document.entity(constraint_target_entity_id(target)) else {
        return false;
    };
    matches!(target, ConstraintTarget::Entity(_))
        && matches!(entity.kind, EntityKind::Circle(_) | EntityKind::Arc(_))
}

fn is_symmetry_axis_target(document: &ProjectDocument, target: &ConstraintTarget) -> bool {
    let Some(entity) = document.entity(constraint_target_entity_id(target)) else {
        return false;
    };
    matches!(target, ConstraintTarget::Entity(_))
        && matches!(
            entity.kind,
            EntityKind::LineSegment(_) | EntityKind::CenterLine(_)
        )
}
