use super::*;

pub(in crate::document) fn evaluate_entity_constraint_statuses(
    document: &ProjectDocument,
) -> Vec<EntityConstraintStatus> {
    let constraint_statuses = document.evaluated_constraint_statuses();
    let component_remaining_dof = component_remaining_dof_by_entity(document);
    document
        .entities
        .iter()
        .map(|entity| {
            let touching_indices: Vec<usize> = document
                .constraints
                .iter()
                .enumerate()
                .filter_map(|(index, constraint)| {
                    constraint
                        .targets
                        .iter()
                        .any(|target| constraint_target_entity_id(target) == entity.id)
                        .then_some(index)
                })
                .collect();

            if touching_indices
                .iter()
                .any(|index| constraint_statuses[*index] == ConstraintStatus::Conflicting)
            {
                return EntityConstraintStatus {
                    entity_id: entity.id.clone(),
                    status: ConstraintStatus::Conflicting,
                    remaining_dof: initial_entity_dof(entity),
                };
            }

            let remaining_dof = component_remaining_dof
                .get(&entity.id)
                .copied()
                .unwrap_or_else(|| remaining_entity_dof(document, entity));
            let status = if touching_indices
                .iter()
                .any(|index| constraint_statuses[*index] == ConstraintStatus::OverConstrained)
            {
                ConstraintStatus::OverConstrained
            } else if remaining_dof == 0 {
                ConstraintStatus::FullyConstrained
            } else {
                ConstraintStatus::UnderConstrained
            };

            EntityConstraintStatus {
                entity_id: entity.id.clone(),
                status,
                remaining_dof,
            }
        })
        .collect()
}

impl ProjectDocument {
    /// 現在の一致拘束から、一致点グループを派生状態として返す。
    pub fn coincident_point_groups(&self) -> Vec<CoincidentPointGroup> {
        let mut groups = CoincidentTargetGroups::new();
        for constraint in &self.constraints {
            if !matches!(constraint.kind, ConstraintKind::Coincident) {
                continue;
            }
            if let [first, second] = constraint.targets.as_slice() {
                if point_for_target(&self.entities, first).is_ok()
                    && point_for_target(&self.entities, second).is_ok()
                {
                    groups.insert(first.clone());
                    groups.insert(second.clone());
                    groups.union(first, second);
                }
            }
        }

        groups.into_groups(&self.entities)
    }
}

#[derive(Debug, Default)]
struct CoincidentTargetGroups {
    targets: Vec<ConstraintTarget>,
    parent: Vec<usize>,
}

impl CoincidentTargetGroups {
    fn new() -> Self {
        Self::default()
    }

    fn insert(&mut self, target: ConstraintTarget) {
        if self.targets.iter().any(|existing| existing == &target) {
            return;
        }
        self.targets.push(target);
        self.parent.push(self.parent.len());
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

    fn into_groups(self, entities: &[Entity]) -> Vec<CoincidentPointGroup> {
        let mut grouped = std::collections::BTreeMap::<String, Vec<ConstraintTarget>>::new();
        for (index, target) in self.targets.iter().enumerate() {
            let root = self.root(index);
            grouped
                .entry(Self::key(&self.targets[root]))
                .or_default()
                .push(target.clone());
        }

        grouped
            .into_iter()
            .filter_map(|(key, mut targets)| {
                if targets.len() < 2 {
                    return None;
                }
                targets.sort_by_key(Self::key);
                let representative = targets
                    .iter()
                    .filter_map(|target| point_for_target(entities, target).ok())
                    .next()?;
                Some(CoincidentPointGroup {
                    id: format!("coincident-group:{key}"),
                    representative,
                    targets,
                })
            })
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

pub(in crate::document) fn evaluate_constraint_status(
    document: &ProjectDocument,
    constraint: &Constraint,
) -> ConstraintStatus {
    if constraint_is_satisfied(document, constraint) {
        if matches!(constraint.kind, ConstraintKind::Fixed)
            || constraint_is_effectively_fully_constrained(document, constraint)
            || constraint_component_is_fully_constrained(document, constraint)
        {
            ConstraintStatus::FullyConstrained
        } else {
            ConstraintStatus::UnderConstrained
        }
    } else {
        ConstraintStatus::Conflicting
    }
}

fn component_remaining_dof_by_entity(
    document: &ProjectDocument,
) -> std::collections::BTreeMap<String, usize> {
    let mut groups = EntityGroups::new(document.entities.iter().map(|entity| entity.id.clone()));
    for constraint in &document.constraints {
        for pair in constraint.targets.windows(2) {
            groups.union(
                constraint_target_entity_id(&pair[0]),
                constraint_target_entity_id(&pair[1]),
            );
        }
    }

    let mut dof_by_root = std::collections::BTreeMap::<String, usize>::new();
    for entity in &document.entities {
        let root = groups.group_key(&entity.id);
        *dof_by_root.entry(root).or_default() += initial_entity_dof(entity);
    }

    let mut reduction_by_root = std::collections::BTreeMap::<String, usize>::new();
    for constraint in &document.constraints {
        if constraint.targets.is_empty() || !constraint_is_satisfied(document, constraint) {
            continue;
        }
        let root = groups.group_key(constraint_target_entity_id(&constraint.targets[0]));
        *reduction_by_root.entry(root).or_default() +=
            constraint_dof_reduction(document, constraint);
    }

    let mut remaining_by_entity = std::collections::BTreeMap::new();
    for entity in &document.entities {
        let root = groups.group_key(&entity.id);
        let dof = dof_by_root.get(&root).copied().unwrap_or_default();
        let reduction = reduction_by_root.get(&root).copied().unwrap_or_default();
        remaining_by_entity.insert(entity.id.clone(), dof.saturating_sub(reduction));
    }
    remaining_by_entity
}

fn constraint_dof_reduction(document: &ProjectDocument, constraint: &Constraint) -> usize {
    match constraint.kind {
        ConstraintKind::Fixed => fixed_constraint_dof_reduction(document, constraint),
        ConstraintKind::Coincident => coincident_constraint_dof_reduction(document, constraint),
        ConstraintKind::Horizontal
        | ConstraintKind::Vertical
        | ConstraintKind::Distance
        | ConstraintKind::HorizontalDistance
        | ConstraintKind::VerticalDistance
        | ConstraintKind::PointLineDistance
        | ConstraintKind::LineLineDistance
        | ConstraintKind::PointOnLine
        | ConstraintKind::SegmentLength
        | ConstraintKind::Parallel
        | ConstraintKind::Perpendicular
        | ConstraintKind::Tangent
        | ConstraintKind::Angle
        | ConstraintKind::EqualSegmentLength
        | ConstraintKind::Diameter
        | ConstraintKind::Radius => 1,
        ConstraintKind::Symmetric => 2,
    }
}

fn coincident_constraint_dof_reduction(
    document: &ProjectDocument,
    constraint: &Constraint,
) -> usize {
    let [first, second] = constraint.targets.as_slice() else {
        return 0;
    };
    if point_for_target(&document.entities, first).is_err()
        || point_for_target(&document.entities, second).is_err()
    {
        return 0;
    }
    if target_is_arc_endpoint(document, first) || target_is_arc_endpoint(document, second) {
        1
    } else {
        2
    }
}

fn fixed_constraint_dof_reduction(document: &ProjectDocument, constraint: &Constraint) -> usize {
    let [target] = constraint.targets.as_slice() else {
        return 0;
    };
    if point_for_target(&document.entities, target).is_err() {
        return 0;
    }
    let Some(entity) = document
        .entities
        .iter()
        .find(|entity| entity.id == constraint_target_entity_id(target))
    else {
        return 0;
    };
    match (&entity.kind, target) {
        (
            EntityKind::Arc(_),
            ConstraintTarget::ControlPoint {
                point: ControlPointKind::Start | ControlPointKind::End,
                ..
            },
        ) => 1,
        _ => 2,
    }
}

fn target_is_arc_endpoint(document: &ProjectDocument, target: &ConstraintTarget) -> bool {
    let Some(entity) = document
        .entities
        .iter()
        .find(|entity| entity.id == constraint_target_entity_id(target))
    else {
        return false;
    };
    matches!(
        (&entity.kind, target),
        (
            EntityKind::Arc(_),
            ConstraintTarget::ControlPoint {
                point: ControlPointKind::Start | ControlPointKind::End,
                ..
            }
        )
    )
}

fn constraint_component_is_fully_constrained(
    document: &ProjectDocument,
    constraint: &Constraint,
) -> bool {
    let Some(first_target) = constraint.targets.first() else {
        return false;
    };
    component_remaining_dof_by_entity(document)
        .get(constraint_target_entity_id(first_target))
        .copied()
        == Some(0)
}

struct EntityGroups {
    ids: Vec<String>,
    parent: Vec<usize>,
}

impl EntityGroups {
    fn new(ids: impl Iterator<Item = String>) -> Self {
        let ids = ids.collect::<Vec<_>>();
        let parent = (0..ids.len()).collect();
        Self { ids, parent }
    }

    fn union(&mut self, first: &str, second: &str) {
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

    fn group_key(&self, id: &str) -> String {
        let Some(index) = self.index_of(id) else {
            return id.to_owned();
        };
        self.ids[self.root(index)].clone()
    }

    fn index_of(&self, id: &str) -> Option<usize> {
        self.ids.iter().position(|candidate| candidate == id)
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
}

fn initial_entity_dof(entity: &Entity) -> usize {
    match entity.kind {
        EntityKind::Point(_) => 2,
        EntityKind::LineSegment(_) | EntityKind::CenterLine(_) => 4,
        EntityKind::Circle(_) => 3,
        EntityKind::Arc(_) => 5,
    }
}

fn remaining_entity_dof(document: &ProjectDocument, entity: &Entity) -> usize {
    match entity.kind {
        EntityKind::Point(_) => {
            if point_target_is_fixed_or_coincident_to_fixed(
                document,
                &ConstraintTarget::Entity(entity.id.clone()),
            ) {
                0
            } else {
                2
            }
        }
        EntityKind::LineSegment(_) | EntityKind::CenterLine(_) => {
            let start = ConstraintTarget::ControlPoint {
                entity_id: entity.id.clone(),
                point: ControlPointKind::Start,
            };
            let end = ConstraintTarget::ControlPoint {
                entity_id: entity.id.clone(),
                point: ControlPointKind::End,
            };
            let mut reduction = 0usize;
            if point_target_is_fixed_or_coincident_to_fixed(document, &start) {
                reduction += 2;
            }
            if point_target_is_fixed_or_coincident_to_fixed(document, &end) {
                reduction += 2;
            }
            reduction += scalar_constraints_for_entity(document, &entity.id);
            initial_entity_dof(entity).saturating_sub(reduction)
        }
        EntityKind::Circle(_) => {
            let center = ConstraintTarget::ControlPoint {
                entity_id: entity.id.clone(),
                point: ControlPointKind::Center,
            };
            let mut reduction = 0usize;
            if point_target_is_fixed_or_coincident_to_fixed(document, &center) {
                reduction += 2;
            }
            reduction += radius_constraints_for_entity(document, &entity.id);
            initial_entity_dof(entity).saturating_sub(reduction)
        }
        EntityKind::Arc(_) => {
            let center = ConstraintTarget::ControlPoint {
                entity_id: entity.id.clone(),
                point: ControlPointKind::Center,
            };
            let start = ConstraintTarget::ControlPoint {
                entity_id: entity.id.clone(),
                point: ControlPointKind::Start,
            };
            let end = ConstraintTarget::ControlPoint {
                entity_id: entity.id.clone(),
                point: ControlPointKind::End,
            };
            let mut reduction = 0usize;
            if point_target_is_fixed_or_coincident_to_fixed(document, &center) {
                reduction += 2;
            }
            if point_target_is_fixed_or_coincident_to_fixed(document, &start) {
                reduction += 1;
            }
            if point_target_is_fixed_or_coincident_to_fixed(document, &end) {
                reduction += 1;
            }
            reduction += radius_constraints_for_entity(document, &entity.id);
            initial_entity_dof(entity).saturating_sub(reduction)
        }
    }
}

fn scalar_constraints_for_entity(document: &ProjectDocument, entity_id: &str) -> usize {
    document
        .constraints
        .iter()
        .filter(|constraint| {
            constraint
                .targets
                .iter()
                .any(|target| constraint_target_entity_id(target) == entity_id)
        })
        .map(|constraint| match constraint.kind {
            ConstraintKind::Horizontal
            | ConstraintKind::Vertical
            | ConstraintKind::Distance
            | ConstraintKind::HorizontalDistance
            | ConstraintKind::VerticalDistance
            | ConstraintKind::PointLineDistance
            | ConstraintKind::LineLineDistance
            | ConstraintKind::PointOnLine
            | ConstraintKind::SegmentLength
            | ConstraintKind::Parallel
            | ConstraintKind::Perpendicular
            | ConstraintKind::Tangent
            | ConstraintKind::Angle
            | ConstraintKind::EqualSegmentLength => 1,
            ConstraintKind::Symmetric => 2,
            _ => 0,
        })
        .sum()
}

fn radius_constraints_for_entity(document: &ProjectDocument, entity_id: &str) -> usize {
    document
        .constraints
        .iter()
        .filter(|constraint| {
            constraint
                .targets
                .iter()
                .any(|target| constraint_target_entity_id(target) == entity_id)
        })
        .filter(|constraint| {
            matches!(
                constraint.kind,
                ConstraintKind::Radius | ConstraintKind::Diameter
            )
        })
        .count()
}

fn point_target_is_fixed_or_coincident_to_fixed(
    document: &ProjectDocument,
    target: &ConstraintTarget,
) -> bool {
    point_has_fixed_constraint(document, target)
        || document.constraints.iter().any(|constraint| {
            if !matches!(constraint.kind, ConstraintKind::Coincident)
                || constraint.targets.len() != 2
            {
                return false;
            }
            let first = &constraint.targets[0];
            let second = &constraint.targets[1];
            (first == target && point_has_fixed_constraint(document, second))
                || (second == target && point_has_fixed_constraint(document, first))
        })
}

pub(in crate::document) fn duplicate_constraint_groups(
    constraints: &[Constraint],
) -> Vec<Vec<usize>> {
    let mut groups = std::collections::BTreeMap::<String, Vec<usize>>::new();
    for (index, constraint) in constraints.iter().enumerate() {
        let signature = format!(
            "{:?}|{:?}|{:?}",
            constraint.kind, constraint.targets, constraint.value
        );
        groups.entry(signature).or_default().push(index);
    }
    groups.into_values().collect()
}

pub(in crate::document) fn constraint_is_satisfied(
    document: &ProjectDocument,
    constraint: &Constraint,
) -> bool {
    match constraint.kind {
        ConstraintKind::Coincident => match constraint.targets.as_slice() {
            [first, second] => match (
                point_for_target(&document.entities, first),
                point_for_target(&document.entities, second),
            ) {
                (Ok(a), Ok(b)) => points_close(a, b),
                _ => false,
            },
            _ => false,
        },
        ConstraintKind::Horizontal => match constraint.targets.as_slice() {
            [target] => line_for_entity_target(&document.entities, target)
                .map(|line| approx_eq(line.start.y_mm, line.end.y_mm))
                .unwrap_or(false),
            [first, second] => match (
                point_for_target(&document.entities, first),
                point_for_target(&document.entities, second),
            ) {
                (Ok(a), Ok(b)) => approx_eq(a.y_mm, b.y_mm),
                _ => false,
            },
            _ => false,
        },
        ConstraintKind::Vertical => match constraint.targets.as_slice() {
            [target] => line_for_entity_target(&document.entities, target)
                .map(|line| approx_eq(line.start.x_mm, line.end.x_mm))
                .unwrap_or(false),
            [first, second] => match (
                point_for_target(&document.entities, first),
                point_for_target(&document.entities, second),
            ) {
                (Ok(a), Ok(b)) => approx_eq(a.x_mm, b.x_mm),
                _ => false,
            },
            _ => false,
        },
        ConstraintKind::Parallel => match line_pair_from_targets(document, constraint) {
            Ok((a, b)) => approx_eq(cross_product(direction(a), direction(b)), 0.0),
            Err(_) => false,
        },
        ConstraintKind::Perpendicular => match line_pair_from_targets(document, constraint) {
            Ok((a, b)) => approx_eq(dot_product(direction(a), direction(b)), 0.0),
            Err(_) => false,
        },
        ConstraintKind::Tangent => match tangent_targets_from_document(document, constraint) {
            Ok(tangent) => tangent_arc_direction(tangent.arc, tangent.arc_endpoint)
                .and_then(|arc_tangent| {
                    tangent_line_continuation_direction(
                        tangent.line_direction_to_connection,
                        tangent.arc_endpoint,
                    )
                    .map(|expected| {
                        approx_eq(cross_product(expected, arc_tangent), 0.0)
                            && dot_product(expected, arc_tangent) > 0.0
                    })
                })
                .unwrap_or(false),
            Err(_) => false,
        },
        ConstraintKind::Symmetric => match constraint.targets.as_slice() {
            [first, second, axis] => match (
                point_for_target(&document.entities, first),
                point_for_target(&document.entities, second),
                line_for_entity_target(&document.entities, axis),
            ) {
                (Ok(anchor), Ok(target), Ok(axis_line)) => {
                    points_close(mirror_point_across_line(anchor, axis_line), target)
                }
                _ => false,
            },
            _ => false,
        },
        ConstraintKind::Distance => match point_pair_with_expected_length(document, constraint) {
            Ok((a, b, expected)) => approx_eq(distance_between(a, b), expected),
            Err(_) => false,
        },
        ConstraintKind::HorizontalDistance => {
            match point_pair_with_expected_length(document, constraint) {
                Ok((a, b, expected)) => approx_eq((b.x_mm - a.x_mm).abs(), expected),
                Err(_) => false,
            }
        }
        ConstraintKind::VerticalDistance => {
            match point_pair_with_expected_length(document, constraint) {
                Ok((a, b, expected)) => approx_eq((b.y_mm - a.y_mm).abs(), expected),
                Err(_) => false,
            }
        }
        ConstraintKind::PointLineDistance => {
            match point_line_with_expected_distance(document, constraint) {
                Ok((point, line, expected)) => {
                    approx_eq(point_line_distance(point, line), expected)
                }
                Err(_) => false,
            }
        }
        ConstraintKind::LineLineDistance => match line_pair_from_targets(document, constraint) {
            Ok((a, b)) => resolve_length_value_mm(
                &document.parameters,
                constraint.value.as_ref(),
                "line-line distance value",
            )
            .map(|expected| {
                approx_eq(cross_product(direction(a), direction(b)), 0.0)
                    && approx_eq(point_line_distance(b.start, a), expected)
            })
            .unwrap_or(false),
            Err(_) => false,
        },
        ConstraintKind::PointOnLine => {
            match point_line_targets_from_constraint(document, constraint) {
                Ok((point, line)) => approx_eq(point_line_distance(point, line), 0.0),
                Err(_) => false,
            }
        }
        ConstraintKind::SegmentLength => match line_from_single_target(document, constraint) {
            Some(line) => resolve_length_value_mm(
                &document.parameters,
                constraint.value.as_ref(),
                "segment length value",
            )
            .map(|expected| approx_eq(line.length_mm(), expected))
            .unwrap_or(false),
            None => false,
        },
        ConstraintKind::Diameter => match circle_from_single_target(document, constraint) {
            Some(circle) => resolve_length_value_mm(
                &document.parameters,
                constraint.value.as_ref(),
                "diameter value",
            )
            .map(|expected| approx_eq(circle.radius_mm * 2.0, expected))
            .unwrap_or(false),
            None => false,
        },
        ConstraintKind::Radius => match radius_entity_from_single_target(document, constraint) {
            Some(entity) => resolve_length_value_mm(
                &document.parameters,
                constraint.value.as_ref(),
                "radius value",
            )
            .map(|expected| approx_eq(entity.radius_mm, expected))
            .unwrap_or(false),
            None => false,
        },
        ConstraintKind::Angle => {
            let expected =
                match resolve_degrees_value(constraint.value.as_ref(), "angle constraint value") {
                    Ok(value) => value.to_radians(),
                    Err(_) => return false,
                };
            if let Ok(angle_lines) =
                shared_endpoint_angle_lines_from_constraint(document, constraint)
            {
                let angle = signed_angle(angle_lines.first_direction, angle_lines.second_direction);
                approx_eq(normalize_angle(angle), normalize_angle(expected))
            } else if let Some(arc) = arc_from_single_target(document, constraint) {
                approx_eq(
                    normalize_angle(arc.sweep_angle_rad),
                    normalize_angle(expected),
                )
            } else {
                false
            }
        }
        ConstraintKind::Fixed => match constraint.targets.as_slice() {
            [target] => point_for_target(&document.entities, target).is_ok(),
            _ => false,
        },
        ConstraintKind::EqualSegmentLength => match line_pair_from_targets(document, constraint) {
            Ok((a, b)) => approx_eq(a.length_mm(), b.length_mm()),
            Err(_) => false,
        },
    }
}

pub(in crate::document) fn constraint_is_effectively_fully_constrained(
    document: &ProjectDocument,
    constraint: &Constraint,
) -> bool {
    match constraint.kind {
        ConstraintKind::Coincident => constraint
            .targets
            .iter()
            .any(|target| point_has_fixed_constraint(document, target)),
        _ => false,
    }
}

fn tangent_arc_direction(arc: crate::geometry::Arc, endpoint: ControlPointKind) -> Option<Point2> {
    let sweep_sign = if arc.sweep_angle_rad < 0.0 { -1.0 } else { 1.0 };
    let radius_angle = match endpoint {
        ControlPointKind::Start => arc.start_angle_rad,
        ControlPointKind::End => arc.start_angle_rad + arc.sweep_angle_rad,
        ControlPointKind::Center => return None,
    };
    Some(Point2::new(
        (radius_angle + sweep_sign * std::f64::consts::FRAC_PI_2).cos(),
        (radius_angle + sweep_sign * std::f64::consts::FRAC_PI_2).sin(),
    ))
}

pub(in crate::document) fn constraint_is_semantically_redundant(
    document: &ProjectDocument,
    constraint_index: usize,
) -> bool {
    let Some(constraint) = document.constraints.get(constraint_index) else {
        return false;
    };
    if !constraint_is_satisfied(document, constraint) {
        return false;
    }
    has_equivalent_scalar_constraint(document, constraint_index)
        || has_equivalent_line_relation_constraint(document, constraint_index)
        || (constraint_can_be_redundant_by_dof(constraint)
            && targets_remain_fully_constrained_without_constraint(document, constraint_index))
}

fn constraint_can_be_redundant_by_dof(constraint: &Constraint) -> bool {
    matches!(
        constraint.kind,
        ConstraintKind::Horizontal
            | ConstraintKind::Vertical
            | ConstraintKind::Parallel
            | ConstraintKind::Perpendicular
            | ConstraintKind::Tangent
            | ConstraintKind::Distance
            | ConstraintKind::HorizontalDistance
            | ConstraintKind::VerticalDistance
            | ConstraintKind::PointLineDistance
            | ConstraintKind::LineLineDistance
            | ConstraintKind::PointOnLine
            | ConstraintKind::SegmentLength
            | ConstraintKind::Angle
            | ConstraintKind::Diameter
            | ConstraintKind::Radius
            | ConstraintKind::EqualSegmentLength
    )
}

fn targets_remain_fully_constrained_without_constraint(
    document: &ProjectDocument,
    constraint_index: usize,
) -> bool {
    let Some(constraint) = document.constraints.get(constraint_index) else {
        return false;
    };
    let target_entity_ids = constraint
        .targets
        .iter()
        .map(|target| constraint_target_entity_id(target).to_owned())
        .collect::<std::collections::BTreeSet<_>>();
    if target_entity_ids.is_empty() {
        return false;
    }

    let mut candidate = document.clone();
    candidate.constraints.remove(constraint_index);
    let remaining_by_entity = component_remaining_dof_by_entity(&candidate);
    target_entity_ids.iter().all(|entity_id| {
        candidate
            .entities
            .iter()
            .find(|entity| entity.id == *entity_id)
            .map(|entity| {
                remaining_by_entity
                    .get(entity_id)
                    .copied()
                    .unwrap_or_else(|| remaining_entity_dof(&candidate, entity))
                    == 0
            })
            .unwrap_or(false)
    })
}

fn has_equivalent_scalar_constraint(document: &ProjectDocument, constraint_index: usize) -> bool {
    let Some(constraint) = document.constraints.get(constraint_index) else {
        return false;
    };
    document
        .constraints
        .iter()
        .enumerate()
        .any(|(other_index, other)| {
            other_index != constraint_index
                && scalar_constraint_equivalence_kind(constraint)
                    == scalar_constraint_equivalence_kind(other)
                && targets_equivalent(&constraint.targets, &other.targets)
                && scalar_constraint_value_mm(document, constraint)
                    .zip(scalar_constraint_value_mm(document, other))
                    .map(|(current, existing)| approx_eq(current, existing))
                    .unwrap_or(false)
        })
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum ScalarConstraintEquivalenceKind {
    SegmentLength,
    Distance,
    HorizontalDistance,
    VerticalDistance,
    PointLineDistance,
    LineLineDistance,
    Radius,
}

fn scalar_constraint_equivalence_kind(
    constraint: &Constraint,
) -> Option<ScalarConstraintEquivalenceKind> {
    match constraint.kind {
        ConstraintKind::SegmentLength => Some(ScalarConstraintEquivalenceKind::SegmentLength),
        ConstraintKind::Distance => Some(ScalarConstraintEquivalenceKind::Distance),
        ConstraintKind::HorizontalDistance => {
            Some(ScalarConstraintEquivalenceKind::HorizontalDistance)
        }
        ConstraintKind::VerticalDistance => Some(ScalarConstraintEquivalenceKind::VerticalDistance),
        ConstraintKind::PointLineDistance => {
            Some(ScalarConstraintEquivalenceKind::PointLineDistance)
        }
        ConstraintKind::LineLineDistance => Some(ScalarConstraintEquivalenceKind::LineLineDistance),
        ConstraintKind::Radius | ConstraintKind::Diameter => {
            Some(ScalarConstraintEquivalenceKind::Radius)
        }
        _ => None,
    }
}

fn scalar_constraint_value_mm(document: &ProjectDocument, constraint: &Constraint) -> Option<f64> {
    let value = resolve_length_value_mm(
        &document.parameters,
        constraint.value.as_ref(),
        "constraint value",
    )
    .ok()?;
    match constraint.kind {
        ConstraintKind::SegmentLength
        | ConstraintKind::Distance
        | ConstraintKind::HorizontalDistance
        | ConstraintKind::VerticalDistance
        | ConstraintKind::PointLineDistance
        | ConstraintKind::LineLineDistance
        | ConstraintKind::Radius => Some(value),
        ConstraintKind::Diameter => Some(value / 2.0),
        _ => None,
    }
}

fn has_equivalent_line_relation_constraint(
    document: &ProjectDocument,
    constraint_index: usize,
) -> bool {
    let Some(constraint) = document.constraints.get(constraint_index) else {
        return false;
    };
    let Some(relation) = line_relation_kind(constraint) else {
        return false;
    };
    document
        .constraints
        .iter()
        .enumerate()
        .any(|(other_index, other)| {
            other_index != constraint_index
                && targets_equivalent(&constraint.targets, &other.targets)
                && line_relation_kind(other) == Some(relation)
        })
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum LineRelationKind {
    Parallel,
    Perpendicular,
}

fn line_relation_kind(constraint: &Constraint) -> Option<LineRelationKind> {
    match constraint.kind {
        ConstraintKind::Parallel => Some(LineRelationKind::Parallel),
        ConstraintKind::Perpendicular => Some(LineRelationKind::Perpendicular),
        ConstraintKind::Angle => {
            let angle = resolve_degrees_value(constraint.value.as_ref(), "angle constraint value")
                .ok()?
                .to_radians();
            let normalized = normalize_angle(angle).abs();
            if approx_eq(normalized, 0.0) || approx_eq(normalized, std::f64::consts::PI) {
                Some(LineRelationKind::Parallel)
            } else if approx_eq(normalized, std::f64::consts::FRAC_PI_2) {
                Some(LineRelationKind::Perpendicular)
            } else {
                None
            }
        }
        _ => None,
    }
}

fn targets_equivalent(first: &[ConstraintTarget], second: &[ConstraintTarget]) -> bool {
    first == second
        || (first.len() == 2 && second.len() == 2 && first[0] == second[1] && first[1] == second[0])
}

pub(in crate::document) fn point_has_fixed_constraint(
    document: &ProjectDocument,
    target: &ConstraintTarget,
) -> bool {
    document.constraints.iter().any(|constraint| {
        matches!(constraint.kind, ConstraintKind::Fixed)
            && constraint.targets.len() == 1
            && constraint.targets[0] == *target
    })
}

fn tangent_line_continuation_direction(
    line_direction_to_connection: Point2,
    endpoint: ControlPointKind,
) -> Option<Point2> {
    match endpoint {
        ControlPointKind::Start => Some(line_direction_to_connection),
        ControlPointKind::End => Some(Point2::new(
            -line_direction_to_connection.x_mm,
            -line_direction_to_connection.y_mm,
        )),
        ControlPointKind::Center => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fixed_constraint(id: &str, target: ConstraintTarget) -> Constraint {
        Constraint {
            id: id.to_owned(),
            kind: ConstraintKind::Fixed,
            targets: vec![target],
            value: None,
            status: ConstraintStatus::Unknown,
        }
    }

    fn scalar_constraint(
        id: &str,
        kind: ConstraintKind,
        targets: Vec<ConstraintTarget>,
        value_mm: f64,
    ) -> Constraint {
        Constraint {
            id: id.to_owned(),
            kind,
            targets,
            value: Some(ConstraintValue::FixedMm(value_mm)),
            status: ConstraintStatus::Unknown,
        }
    }

    #[test]
    fn targets_equivalent_accepts_same_or_reversed_pair_only() {
        let first = ConstraintTarget::Entity("entity:first".to_owned());
        let second = ConstraintTarget::Entity("entity:second".to_owned());
        let third = ConstraintTarget::Entity("entity:third".to_owned());

        assert!(targets_equivalent(
            &[first.clone(), second.clone()],
            &[first.clone(), second.clone()]
        ));
        assert!(targets_equivalent(
            &[first.clone(), second.clone()],
            &[second.clone(), first.clone()]
        ));
        assert!(!targets_equivalent(
            &[first.clone(), second.clone()],
            &[first.clone(), third.clone()]
        ));
        assert!(!targets_equivalent(
            &[first.clone(), second.clone(), third.clone()],
            &[third, second, first]
        ));
    }

    #[test]
    fn point_has_fixed_constraint_requires_fixed_kind_single_exact_target() {
        let mut document = ProjectDocument::new("Fixed Target");
        let target = ConstraintTarget::Entity("entity:point".to_owned());
        let other = ConstraintTarget::Entity("entity:other".to_owned());
        document.constraints = vec![
            fixed_constraint("constraint:fixed", target.clone()),
            Constraint {
                id: "constraint:not-fixed".to_owned(),
                kind: ConstraintKind::Coincident,
                targets: vec![target.clone(), other.clone()],
                value: None,
                status: ConstraintStatus::Unknown,
            },
            Constraint {
                id: "constraint:malformed-fixed".to_owned(),
                kind: ConstraintKind::Fixed,
                targets: vec![other.clone(), target.clone()],
                value: None,
                status: ConstraintStatus::Unknown,
            },
        ];

        assert!(point_has_fixed_constraint(&document, &target));
        assert!(!point_has_fixed_constraint(&document, &other));
    }

    #[test]
    fn equivalent_scalar_constraints_require_matching_constraint_kind() {
        let mut document = ProjectDocument::new("Scalar Constraint Kinds");
        let first = ConstraintTarget::Entity("entity:first".to_owned());
        let second = ConstraintTarget::Entity("entity:second".to_owned());
        document.constraints = vec![
            scalar_constraint(
                "constraint:distance",
                ConstraintKind::Distance,
                vec![first.clone(), second.clone()],
                10.0,
            ),
            scalar_constraint(
                "constraint:horizontal-distance",
                ConstraintKind::HorizontalDistance,
                vec![first.clone(), second.clone()],
                10.0,
            ),
            scalar_constraint(
                "constraint:duplicate-horizontal-distance",
                ConstraintKind::HorizontalDistance,
                vec![second, first],
                10.0,
            ),
        ];

        assert!(!has_equivalent_scalar_constraint(&document, 0));
        assert!(has_equivalent_scalar_constraint(&document, 1));
    }
}
