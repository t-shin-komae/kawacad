use super::*;

pub(in crate::document) struct ConstraintSolver;

#[derive(Debug, Clone)]
pub(in crate::document) struct SolverState {
    entities: Vec<Entity>,
    iteration: usize,
    max_iterations: usize,
}

#[derive(Debug, Clone, PartialEq)]
pub(in crate::document) struct SolverIteration {
    pub index: usize,
    pub input_entity_count: usize,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub(in crate::document) struct ConstraintSatisfaction {
    pub constraint_id: String,
    pub kind: ConstraintKind,
    pub satisfied: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub(in crate::document) struct SatisfactionCheck {
    results: Vec<ConstraintSatisfaction>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub(in crate::document) struct ConstraintConflictReport {
    statuses: Vec<ConstraintStatus>,
    conflicting_constraint_ids: Vec<String>,
}

impl SolverState {
    pub(in crate::document) fn new(base_entities: &[Entity], constraints: &[Constraint]) -> Self {
        Self {
            entities: base_entities.to_vec(),
            iteration: 0,
            max_iterations: constraints
                .len()
                .saturating_mul(base_entities.len())
                .saturating_mul(8)
                + 16,
        }
    }

    pub(in crate::document) fn entities(&self) -> &[Entity] {
        &self.entities
    }

    pub(in crate::document) fn begin_iteration(&mut self) -> CommandResult<SolverIteration> {
        if self.iteration >= self.max_iterations {
            return Err(CommandError::InvalidValue {
                field: "constraint",
                reason: "constraint solving did not converge",
            });
        }
        self.iteration += 1;
        Ok(SolverIteration {
            index: self.iteration,
            input_entity_count: self.entities.len(),
        })
    }

    pub(in crate::document) fn moved_point_targets_to(
        &self,
        solved_entities: &[Entity],
    ) -> Vec<ConstraintTarget> {
        moved_point_targets_between(&self.entities, solved_entities)
    }

    pub(in crate::document) fn has_converged_to(&self, solved_entities: &[Entity]) -> bool {
        entities_approximately_equal(&self.entities, solved_entities)
    }

    pub(in crate::document) fn advance_to(&mut self, solved_entities: Vec<Entity>) {
        self.entities = solved_entities;
    }
}

impl SatisfactionCheck {
    pub(in crate::document) fn evaluate(
        document: &ProjectDocument,
        parameters: &[Parameter],
        entities: &[Entity],
        constraints: &[Constraint],
    ) -> Self {
        let mut candidate = document.clone();
        candidate.parameters = parameters.to_vec();
        candidate.entities = entities.to_vec();
        candidate.constraints = constraints.to_vec();
        let results = candidate
            .constraints
            .iter()
            .map(|constraint| ConstraintSatisfaction {
                constraint_id: constraint.id.clone(),
                kind: constraint.kind,
                satisfied: constraint_is_satisfied(&candidate, constraint),
            })
            .collect();
        Self { results }
    }

    pub(in crate::document) fn has_non_coincident_conflicts(&self) -> bool {
        !self.unsatisfied_non_coincident_constraint_ids().is_empty()
    }

    pub(in crate::document) fn unsatisfied_non_coincident_constraint_ids(&self) -> Vec<String> {
        self.results
            .iter()
            .filter(|result| {
                !matches!(result.kind, ConstraintKind::Coincident) && !result.satisfied
            })
            .map(|result| result.constraint_id.clone())
            .collect()
    }
}

impl ConstraintConflictReport {
    pub(in crate::document) fn evaluate(candidate: &ProjectDocument) -> Self {
        let statuses = ConstraintSolver::evaluated_constraint_statuses(candidate);
        let conflicting_constraint_ids = candidate
            .constraints
            .iter()
            .zip(statuses.iter())
            .filter(|(_, status)| **status == ConstraintStatus::Conflicting)
            .map(|(constraint, _)| constraint.id.clone())
            .collect::<Vec<_>>();
        Self {
            statuses,
            conflicting_constraint_ids,
        }
    }

    pub(in crate::document) fn has_conflicts(&self) -> bool {
        self.statuses().contains(&ConstraintStatus::Conflicting)
    }

    pub(in crate::document) fn statuses(&self) -> &[ConstraintStatus] {
        &self.statuses
    }

    pub(in crate::document) fn conflicting_constraint_ids(&self) -> &[String] {
        &self.conflicting_constraint_ids
    }

    pub(in crate::document) fn representative_constraint<'a>(
        &self,
        constraints: &'a [Constraint],
    ) -> Option<&'a Constraint> {
        constraints
            .iter()
            .zip(self.statuses.iter())
            .find(|(_, status)| **status == ConstraintStatus::Conflicting)
            .map(|(constraint, _)| constraint)
            .or_else(|| constraints.last())
    }
}

impl ConstraintSolver {
    pub(in crate::document) fn solve_constraints_from_entities(
        document: &ProjectDocument,
        parameters: &[Parameter],
        base_entities: &[Entity],
        constraints: &[Constraint],
    ) -> CommandResult<Vec<Entity>> {
        let mut state = SolverState::new(base_entities, constraints);
        let propagation_graph = PropagationGraph::new(constraints);

        loop {
            let _iteration = state.begin_iteration()?;
            let mut solved_entities =
                solve_constraint_system(parameters, state.entities(), constraints)?;
            let satisfaction =
                SatisfactionCheck::evaluate(document, parameters, &solved_entities, constraints);
            if satisfaction.has_non_coincident_conflicts() {
                return Ok(solved_entities);
            }

            let moved_targets = state.moved_point_targets_to(&solved_entities);
            if !moved_targets.is_empty() {
                propagation_graph.propagate_connected_endpoint_changes(
                    parameters,
                    &mut solved_entities,
                    moved_targets,
                )?;
            }

            if state.has_converged_to(&solved_entities) {
                return Ok(solved_entities);
            }
            state.advance_to(solved_entities);
        }
    }

    pub(in crate::document) fn evaluated_constraint_statuses(
        document: &ProjectDocument,
    ) -> Vec<ConstraintStatus> {
        let mut statuses: Vec<_> = document
            .constraints
            .iter()
            .map(|constraint| evaluate_constraint_status(document, constraint))
            .collect();
        for indices in duplicate_constraint_groups(&document.constraints) {
            if indices.len() >= 2 {
                for index in indices {
                    if statuses[index] != ConstraintStatus::Conflicting {
                        statuses[index] = ConstraintStatus::OverConstrained;
                    }
                }
            }
        }
        for (index, status) in statuses.iter_mut().enumerate() {
            if *status != ConstraintStatus::Conflicting
                && constraint_is_semantically_redundant(document, index)
            {
                *status = ConstraintStatus::OverConstrained;
            }
        }
        statuses
    }

    pub(in crate::document) fn refresh_constraint_statuses(document: &mut ProjectDocument) {
        let statuses = Self::evaluated_constraint_statuses(document);
        for (constraint, status) in document.constraints.iter_mut().zip(statuses) {
            constraint.status = status;
        }
    }

    pub(in crate::document) fn ensure_constraints_not_conflicting(
        document: &ProjectDocument,
        entities: Vec<Entity>,
        constraints: Vec<Constraint>,
    ) -> CommandResult {
        let mut candidate = document.clone();
        candidate.entities = entities;
        candidate.constraints = constraints;
        Self::ensure_fixed_targets_preserved(
            document,
            &candidate.entities,
            &candidate.constraints,
        )?;
        let conflict_report = ConstraintConflictReport::evaluate(&candidate);
        if conflict_report.has_conflicts() {
            let representative = conflict_report.representative_constraint(&candidate.constraints);
            return Err(match representative {
                Some(constraint) => CommandError::Constraint(Box::new(ConstraintCommandError {
                    code: ConstraintCommandErrorCode::Conflicting,
                    constraint_kind: constraint.kind,
                    constraint_id: constraint.id.clone(),
                    target_ids: constraint
                        .targets
                        .iter()
                        .map(constraint_target_id)
                        .collect(),
                    actual_target_count: Some(constraint.targets.len()),
                    required_target_count: None,
                    expected_target_kinds: Vec::new(),
                    invalid_target_ids: Vec::new(),
                    existing_constraint_id: None,
                    conflicting_constraint_ids: conflict_report
                        .conflicting_constraint_ids()
                        .to_vec(),
                })),
                None => CommandError::InvalidValue {
                    field: "constraint",
                    reason: "would conflict with existing constraints",
                },
            });
        }
        Ok(())
    }

    pub(in crate::document) fn resolve_current_constraints_or_restore(
        document: &mut ProjectDocument,
        rollback: DocumentRollback,
    ) -> CommandResult {
        let solved_entities = match Self::solve_constraints_from_entities(
            document,
            &document.parameters,
            &rollback.entities,
            &document.constraints,
        ) {
            Ok(entities) => entities,
            Err(error) => {
                document.restore_document_state(rollback);
                return Err(error);
            }
        };
        document.entities = solved_entities;
        if let Err(error) = Self::ensure_constraints_not_conflicting(
            document,
            document.entities.clone(),
            document.constraints.clone(),
        ) {
            document.restore_document_state(rollback);
            return Err(error);
        }
        Ok(())
    }

    fn ensure_fixed_targets_preserved(
        document: &ProjectDocument,
        entities: &[Entity],
        constraints: &[Constraint],
    ) -> CommandResult {
        for constraint in constraints {
            if !matches!(constraint.kind, ConstraintKind::Fixed) {
                continue;
            }
            let [target] = constraint.targets.as_slice() else {
                continue;
            };
            let Ok(previous_point) = point_for_target(&document.entities, target) else {
                continue;
            };
            let Ok(next_point) = point_for_target(entities, target) else {
                continue;
            };
            if !points_approximately_equal(previous_point, next_point) {
                return Err(CommandError::Constraint(Box::new(ConstraintCommandError {
                    code: ConstraintCommandErrorCode::Conflicting,
                    constraint_kind: constraint.kind,
                    constraint_id: constraint.id.clone(),
                    target_ids: constraint
                        .targets
                        .iter()
                        .map(constraint_target_id)
                        .collect(),
                    actual_target_count: Some(constraint.targets.len()),
                    required_target_count: None,
                    expected_target_kinds: Vec::new(),
                    invalid_target_ids: Vec::new(),
                    existing_constraint_id: None,
                    conflicting_constraint_ids: vec![constraint.id.clone()],
                })));
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn point(x_mm: f64, y_mm: f64) -> Point2 {
        Point2::new(x_mm, y_mm)
    }

    fn point_entity(id: &str, point: Point2) -> Entity {
        Entity::new(id, EntityKind::Point(point))
    }

    fn line_entity(id: &str, start: Point2, end: Point2) -> Entity {
        Entity::new(id, EntityKind::LineSegment(LineSegment::new(start, end)))
    }

    fn target(entity_id: &str) -> ConstraintTarget {
        ConstraintTarget::Entity(entity_id.to_owned())
    }

    fn constraint(id: &str, kind: ConstraintKind, targets: Vec<ConstraintTarget>) -> Constraint {
        Constraint {
            id: id.to_owned(),
            kind,
            targets,
            value: None,
            status: ConstraintStatus::Unknown,
        }
    }

    #[test]
    fn solver_state_tracks_iterations_moved_targets_and_convergence() {
        let base_entities = vec![point_entity("point:a", point(0.0, 0.0))];
        let constraints = vec![constraint(
            "constraint:fixed",
            ConstraintKind::Fixed,
            vec![target("point:a")],
        )];
        let mut state = SolverState::new(&base_entities, &constraints);

        let iteration = state.begin_iteration().expect("iteration should start");
        assert_eq!(iteration.index, 1);
        assert_eq!(iteration.input_entity_count, 1);
        assert!(state.has_converged_to(&base_entities));

        let moved_entities = vec![point_entity("point:a", point(2.0, 3.0))];
        assert_eq!(
            state.moved_point_targets_to(&moved_entities),
            vec![target("point:a")]
        );
        state.advance_to(moved_entities.clone());
        assert!(state.has_converged_to(&moved_entities));
    }

    #[test]
    fn satisfaction_check_reports_unsatisfied_non_coincident_constraints() {
        let mut document = ProjectDocument::new("satisfaction");
        document.entities = vec![line_entity("line:a", point(0.0, 0.0), point(10.0, 0.0))];
        let constraints = vec![constraint(
            "constraint:vertical",
            ConstraintKind::Vertical,
            vec![target("line:a")],
        )];

        let check = SatisfactionCheck::evaluate(
            &document,
            &document.parameters,
            &document.entities,
            &constraints,
        );

        assert!(check.has_non_coincident_conflicts());
        assert_eq!(
            check.unsatisfied_non_coincident_constraint_ids(),
            vec!["constraint:vertical".to_owned()]
        );
    }

    #[test]
    fn conflict_report_lists_conflicting_constraint_ids_and_statuses() {
        let mut document = ProjectDocument::new("conflict");
        document.entities = vec![line_entity("line:a", point(0.0, 0.0), point(10.0, 0.0))];
        document.constraints = vec![constraint(
            "constraint:vertical",
            ConstraintKind::Vertical,
            vec![target("line:a")],
        )];

        let report = ConstraintConflictReport::evaluate(&document);

        assert!(report.has_conflicts());
        assert_eq!(
            report.conflicting_constraint_ids(),
            &["constraint:vertical".to_owned()]
        );
        assert_eq!(report.statuses(), &[ConstraintStatus::Conflicting]);
        assert_eq!(
            report
                .representative_constraint(&document.constraints)
                .map(|constraint| constraint.id.as_str()),
            Some("constraint:vertical")
        );
    }
}
