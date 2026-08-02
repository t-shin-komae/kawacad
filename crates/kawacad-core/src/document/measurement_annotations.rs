use super::*;
use crate::measurement::{
    DimensionConstraintAnnotation, MeasurementAnnotation, MeasurementAnnotationKind,
};

fn project_point_to_line(point: Point2, line: (Point2, Point2)) -> Point2 {
    let dx = line.1.x_mm - line.0.x_mm;
    let dy = line.1.y_mm - line.0.y_mm;
    let denominator = dx * dx + dy * dy;
    if denominator <= GEOMETRY_EPSILON_MM * GEOMETRY_EPSILON_MM {
        return line.0;
    }
    let ratio = ((point.x_mm - line.0.x_mm) * dx + (point.y_mm - line.0.y_mm) * dy) / denominator;
    Point2::new(line.0.x_mm + ratio * dx, line.0.y_mm + ratio * dy)
}

impl ProjectDocument {
    pub(crate) fn move_measurement_annotation(
        &mut self,
        id: &str,
        delta: Point2,
        label_only: bool,
    ) -> CommandResult {
        let mut annotation = self
            .measurement_annotations()
            .iter()
            .find(|item| item.id == id)
            .cloned()
            .ok_or_else(|| CommandError::missing("measurement annotation", id))?;
        if label_only {
            annotation.label_offset_mm = Point2::new(
                annotation.label_offset_mm.x_mm + delta.x_mm,
                annotation.label_offset_mm.y_mm + delta.y_mm,
            );
        } else {
            annotation.overall_offset_mm = Point2::new(
                annotation.overall_offset_mm.x_mm + delta.x_mm,
                annotation.overall_offset_mm.y_mm + delta.y_mm,
            );
        }
        self.update_measurement_annotation(annotation)
    }

    pub(crate) fn move_dimension_constraint_annotation(
        &mut self,
        id: &str,
        delta: Point2,
        label_only: bool,
    ) -> CommandResult {
        if !self
            .constraints
            .iter()
            .any(|constraint| constraint.id == id)
        {
            return Err(CommandError::missing("constraint", id));
        }
        let mut annotation = self
            .dimension_constraint_annotations()
            .iter()
            .find(|item| item.constraint_id == id)
            .cloned()
            .unwrap_or(DimensionConstraintAnnotation {
                constraint_id: id.to_owned(),
                label_offset_mm: Point2::new(0.0, 0.0),
                overall_offset_mm: Point2::new(0.0, 0.0),
                visible: true,
            });
        if label_only {
            annotation.label_offset_mm = Point2::new(
                annotation.label_offset_mm.x_mm + delta.x_mm,
                annotation.label_offset_mm.y_mm + delta.y_mm,
            );
        } else {
            annotation.overall_offset_mm = Point2::new(
                annotation.overall_offset_mm.x_mm + delta.x_mm,
                annotation.overall_offset_mm.y_mm + delta.y_mm,
            );
        }
        if self
            .dimension_constraint_annotations()
            .iter()
            .any(|item| item.constraint_id == id)
        {
            self.update_dimension_constraint_annotation(annotation)
        } else {
            self.add_dimension_constraint_annotation(annotation)
        }
    }
    /// 現在形状からすべての計測表示の正規値と意味上の基準点を評価する。
    pub fn measurement_evaluations(&self) -> Vec<MeasurementEvaluation> {
        self.measurement_annotations()
            .iter()
            .filter_map(|annotation| self.evaluate_measurement(annotation).ok())
            .collect()
    }

    /// ID で指定した計測表示を現在形状から評価する。
    pub fn evaluate_measurement_by_id(
        &self,
        annotation_id: &str,
    ) -> CommandResult<MeasurementEvaluation> {
        let annotation = self
            .measurement_annotations()
            .iter()
            .find(|annotation| annotation.id == annotation_id)
            .ok_or_else(|| CommandError::missing("measurement annotation", annotation_id))?;
        self.evaluate_measurement(annotation)
    }

    pub(crate) fn convert_measurement_to_constraint(
        &mut self,
        annotation_id: &str,
        constraint_id: String,
    ) -> CommandResult {
        let annotation = self
            .measurement_annotations()
            .iter()
            .find(|annotation| annotation.id == annotation_id)
            .cloned()
            .ok_or_else(|| CommandError::missing("measurement annotation", annotation_id))?;
        let evaluation = self.evaluate_measurement(&annotation)?;
        let kind = measurement_constraint_kind(annotation.kind);
        self.add_constraint(Constraint {
            id: constraint_id,
            kind,
            targets: annotation.targets,
            value: Some(evaluation.value),
            status: ConstraintStatus::Unknown,
        })?;
        self.view_annotations
            .measurement_annotations
            .retain(|annotation| annotation.id != annotation_id);
        Ok(())
    }

    fn evaluate_measurement(
        &self,
        annotation: &MeasurementAnnotation,
    ) -> CommandResult<MeasurementEvaluation> {
        self.validate_measurement_annotation_targets(annotation)?;
        let (value, center, start, end) = match annotation.kind {
            MeasurementAnnotationKind::Distance => {
                let first = self.resolve_measurement_point(&annotation.targets[0])?;
                let second = self.resolve_measurement_point(&annotation.targets[1])?;
                (
                    ConstraintValue::FixedMm(
                        (second.x_mm - first.x_mm).hypot(second.y_mm - first.y_mm),
                    ),
                    None,
                    Some(first),
                    Some(second),
                )
            }
            MeasurementAnnotationKind::SegmentLength => {
                let line = self.resolve_measurement_line(&annotation.targets[0])?;
                (
                    ConstraintValue::FixedMm(
                        (line.1.x_mm - line.0.x_mm).hypot(line.1.y_mm - line.0.y_mm),
                    ),
                    None,
                    Some(line.0),
                    Some(line.1),
                )
            }
            MeasurementAnnotationKind::Angle => {
                let first = self.resolve_measurement_line(&annotation.targets[0])?;
                let second = self.resolve_measurement_line(&annotation.targets[1])?;
                let shared = shared_endpoint(first, second).ok_or(CommandError::InvalidValue {
                    field: "measurement annotation targets",
                    reason: "angle annotations require a shared endpoint",
                })?;
                let first_opposite = if point_close(first.0, shared) {
                    first.1
                } else {
                    first.0
                };
                let second_opposite = if point_close(second.0, shared) {
                    second.1
                } else {
                    second.0
                };
                let start_angle =
                    (first_opposite.y_mm - shared.y_mm).atan2(first_opposite.x_mm - shared.x_mm);
                let end_angle =
                    (second_opposite.y_mm - shared.y_mm).atan2(second_opposite.x_mm - shared.x_mm);
                let mut sweep = (end_angle - start_angle).rem_euclid(std::f64::consts::TAU);
                if sweep > std::f64::consts::PI {
                    sweep -= std::f64::consts::TAU;
                }
                (
                    ConstraintValue::FixedDegrees(sweep.to_degrees()),
                    Some(shared),
                    Some(first_opposite),
                    Some(second_opposite),
                )
            }
            MeasurementAnnotationKind::Radius | MeasurementAnnotationKind::Diameter => {
                let entity = self
                    .entity(constraint_target_entity_id(&annotation.targets[0]))
                    .ok_or_else(|| {
                        CommandError::broken_reference(
                            "measurement annotation",
                            "entity",
                            constraint_target_entity_id(&annotation.targets[0]),
                        )
                    })?;
                let (center, radius, start) = match entity.kind {
                    EntityKind::Circle(circle) => (
                        circle.center,
                        circle.radius_mm,
                        Point2::new(circle.center.x_mm + circle.radius_mm, circle.center.y_mm),
                    ),
                    EntityKind::Arc(arc) => (
                        arc.center,
                        arc.radius_mm,
                        point_on_arc(arc.center, arc.radius_mm, arc.start_angle_rad),
                    ),
                    _ => {
                        return Err(CommandError::InvalidValue {
                            field: "measurement annotation target",
                            reason: "target is not radial",
                        })
                    }
                };
                let measured = if annotation.kind == MeasurementAnnotationKind::Diameter {
                    radius * 2.0
                } else {
                    radius
                };
                let end = (annotation.kind == MeasurementAnnotationKind::Diameter).then(|| {
                    Point2::new(
                        center.x_mm - (start.x_mm - center.x_mm),
                        center.y_mm - (start.y_mm - center.y_mm),
                    )
                });
                (
                    ConstraintValue::FixedMm(measured),
                    Some(center),
                    Some(start),
                    end,
                )
            }
            MeasurementAnnotationKind::ArcSweepAngle => {
                let entity = self
                    .entity(constraint_target_entity_id(&annotation.targets[0]))
                    .ok_or_else(|| {
                        CommandError::broken_reference(
                            "measurement annotation",
                            "entity",
                            constraint_target_entity_id(&annotation.targets[0]),
                        )
                    })?;
                let EntityKind::Arc(arc) = entity.kind else {
                    return Err(CommandError::InvalidValue {
                        field: "measurement annotation target",
                        reason: "target is not an arc",
                    });
                };
                (
                    ConstraintValue::FixedDegrees(arc.sweep_angle_rad.to_degrees()),
                    Some(arc.center),
                    Some(point_on_arc(arc.center, arc.radius_mm, arc.start_angle_rad)),
                    Some(point_on_arc(
                        arc.center,
                        arc.radius_mm,
                        arc.start_angle_rad + arc.sweep_angle_rad,
                    )),
                )
            }
        };
        Ok(MeasurementEvaluation {
            annotation_id: annotation.id.clone(),
            kind: annotation.kind,
            value,
            center,
            start,
            end,
        })
    }

    pub(crate) fn resolve_dimension_geometry(
        &self,
        constraint: &Constraint,
    ) -> CommandResult<(Option<Point2>, Option<Point2>, Option<Point2>)> {
        let geometry = match constraint.kind {
            ConstraintKind::Distance
            | ConstraintKind::HorizontalDistance
            | ConstraintKind::VerticalDistance => (
                None,
                Some(self.resolve_measurement_point(&constraint.targets[0])?),
                Some(self.resolve_measurement_point(&constraint.targets[1])?),
            ),
            ConstraintKind::SegmentLength => {
                let line = self.resolve_measurement_line(&constraint.targets[0])?;
                (None, Some(line.0), Some(line.1))
            }
            ConstraintKind::PointLineDistance => {
                let point = self.resolve_measurement_point(&constraint.targets[0])?;
                let line = self.resolve_measurement_line(&constraint.targets[1])?;
                (None, Some(point), Some(project_point_to_line(point, line)))
            }
            ConstraintKind::LineLineDistance => {
                let first = self.resolve_measurement_line(&constraint.targets[0])?;
                let second = self.resolve_measurement_line(&constraint.targets[1])?;
                let midpoint = Point2::new(
                    (first.0.x_mm + first.1.x_mm) / 2.0,
                    (first.0.y_mm + first.1.y_mm) / 2.0,
                );
                (
                    None,
                    Some(midpoint),
                    Some(project_point_to_line(midpoint, second)),
                )
            }
            ConstraintKind::Diameter | ConstraintKind::Radius => {
                let entity = self
                    .entity(constraint_target_entity_id(&constraint.targets[0]))
                    .ok_or_else(|| {
                        CommandError::broken_reference(
                            "dimension constraint",
                            "entity",
                            constraint_target_entity_id(&constraint.targets[0]),
                        )
                    })?;
                let (center, radius) = match entity.kind {
                    EntityKind::Circle(circle) => (circle.center, circle.radius_mm),
                    EntityKind::Arc(arc) => (arc.center, arc.radius_mm),
                    _ => {
                        return Err(CommandError::InvalidValue {
                            field: "dimension constraint target",
                            reason: "target is not radial",
                        })
                    }
                };
                let start = Point2::new(center.x_mm + radius, center.y_mm);
                let end = if constraint.kind == ConstraintKind::Diameter {
                    Some(Point2::new(center.x_mm - radius, center.y_mm))
                } else {
                    None
                };
                (Some(center), Some(start), end)
            }
            ConstraintKind::Angle => {
                if constraint.targets.len() == 1 {
                    let entity = self
                        .entity(constraint_target_entity_id(&constraint.targets[0]))
                        .ok_or_else(|| {
                            CommandError::broken_reference(
                                "dimension constraint",
                                "entity",
                                constraint_target_entity_id(&constraint.targets[0]),
                            )
                        })?;
                    let EntityKind::Arc(arc) = entity.kind else {
                        return Err(CommandError::InvalidValue {
                            field: "dimension constraint targets",
                            reason: "single angle target must be an arc",
                        });
                    };
                    return Ok((
                        Some(arc.center),
                        Some(point_on_arc(arc.center, arc.radius_mm, arc.start_angle_rad)),
                        Some(point_on_arc(
                            arc.center,
                            arc.radius_mm,
                            arc.start_angle_rad + arc.sweep_angle_rad,
                        )),
                    ));
                }
                let first = self.resolve_measurement_line(&constraint.targets[0])?;
                let second = self.resolve_measurement_line(&constraint.targets[1])?;
                let shared = shared_endpoint(first, second).ok_or(CommandError::InvalidValue {
                    field: "dimension constraint targets",
                    reason: "angle constraints require a shared endpoint",
                })?;
                let first_opposite = if point_close(first.0, shared) {
                    first.1
                } else {
                    first.0
                };
                let second_opposite = if point_close(second.0, shared) {
                    second.1
                } else {
                    second.0
                };
                (Some(shared), Some(first_opposite), Some(second_opposite))
            }
            _ => {
                return Err(CommandError::InvalidValue {
                    field: "dimension constraint",
                    reason: "constraint kind has no dimension geometry",
                })
            }
        };
        Ok(geometry)
    }

    pub(crate) fn add_dimension_constraint_annotation(
        &mut self,
        annotation: DimensionConstraintAnnotation,
    ) -> CommandResult {
        validate_dimension_constraint_annotation_offsets(&annotation)?;
        ensure_non_empty_id("dimension constraint annotation", &annotation.constraint_id)?;
        ensure_unique_id(
            self.view_annotations
                .dimension_constraint_annotations
                .iter()
                .map(|existing| existing.constraint_id.as_str()),
            "dimension constraint annotation",
            &annotation.constraint_id,
        )?;
        self.validate_dimension_constraint_annotation_target(&annotation)?;
        self.view_annotations
            .dimension_constraint_annotations
            .push(annotation);
        Ok(())
    }

    pub(crate) fn update_dimension_constraint_annotation(
        &mut self,
        annotation: DimensionConstraintAnnotation,
    ) -> CommandResult {
        validate_dimension_constraint_annotation_offsets(&annotation)?;
        ensure_non_empty_id("dimension constraint annotation", &annotation.constraint_id)?;
        self.validate_dimension_constraint_annotation_target(&annotation)?;
        let index = self
            .view_annotations
            .dimension_constraint_annotations
            .iter()
            .position(|existing| existing.constraint_id == annotation.constraint_id)
            .ok_or_else(|| {
                CommandError::missing(
                    "dimension constraint annotation",
                    annotation.constraint_id.clone(),
                )
            })?;
        self.view_annotations.dimension_constraint_annotations[index] = annotation;
        Ok(())
    }

    pub(crate) fn delete_constraint(&mut self, constraint_id: &str) -> CommandResult {
        delete_by_id(
            &mut self.constraints,
            "constraint",
            constraint_id,
            |constraint| &constraint.id,
        )?;
        self.view_annotations
            .dimension_constraint_annotations
            .retain(|annotation| annotation.constraint_id != constraint_id);
        Ok(())
    }

    pub(crate) fn add_measurement_annotation(
        &mut self,
        annotation: MeasurementAnnotation,
    ) -> CommandResult {
        validate_measurement_annotation_offsets(&annotation)?;
        ensure_non_empty_id("measurement annotation", &annotation.id)?;
        ensure_unique_id(
            self.view_annotations
                .measurement_annotations
                .iter()
                .map(|existing| existing.id.as_str()),
            "measurement annotation",
            &annotation.id,
        )?;
        self.validate_measurement_annotation_targets(&annotation)?;
        let annotation_id = annotation.id.clone();
        self.view_annotations
            .measurement_annotations
            .push(annotation);
        self.auto_assign_measurement_to_part(&annotation_id);
        Ok(())
    }

    pub(crate) fn update_measurement_annotation(
        &mut self,
        annotation: MeasurementAnnotation,
    ) -> CommandResult {
        validate_measurement_annotation_offsets(&annotation)?;
        ensure_non_empty_id("measurement annotation", &annotation.id)?;
        self.validate_measurement_annotation_targets(&annotation)?;
        let index = self
            .view_annotations
            .measurement_annotations
            .iter()
            .position(|existing| existing.id == annotation.id)
            .ok_or_else(|| {
                CommandError::missing("measurement annotation", annotation.id.clone())
            })?;
        self.view_annotations.measurement_annotations[index] = annotation;
        Ok(())
    }

    pub(in crate::document) fn remove_measurement_annotations_for_entity(
        &mut self,
        entity_id: &str,
    ) {
        let removed_ids = self
            .view_annotations
            .measurement_annotations
            .iter()
            .filter(|annotation| {
                annotation
                    .targets
                    .iter()
                    .any(|target| constraint_target_entity_id(target) == entity_id)
            })
            .map(|annotation| annotation.id.clone())
            .collect::<BTreeSet<_>>();
        self.remove_measurement_annotations_by_id(removed_ids);
    }

    pub(in crate::document) fn prune_unresolvable_measurement_annotations(&mut self) {
        let removed_ids = self
            .view_annotations
            .measurement_annotations
            .iter()
            .filter(|annotation| {
                self.validate_measurement_annotation_targets(annotation)
                    .is_err()
            })
            .map(|annotation| annotation.id.clone())
            .collect::<BTreeSet<_>>();
        self.remove_measurement_annotations_by_id(removed_ids);
    }

    fn remove_measurement_annotations_by_id(&mut self, removed_ids: BTreeSet<String>) {
        if removed_ids.is_empty() {
            return;
        }
        self.view_annotations
            .measurement_annotations
            .retain(|annotation| !removed_ids.contains(&annotation.id));
        for annotation_id in removed_ids {
            self.document_warnings.push(DocumentWarning {
                kind: DocumentWarningKind::MeasurementAnnotationRemoved,
                derived_element_id: String::new(),
                measurement_annotation_id: annotation_id.clone(),
                part_id: String::new(),
                message: format!("参照対象の変更により、計測表示 {annotation_id} を削除しました。"),
            });
        }
    }

    fn validate_measurement_annotation_targets(
        &self,
        annotation: &MeasurementAnnotation,
    ) -> CommandResult {
        for target in &annotation.targets {
            self.ensure_entity_exists(
                "measurement annotation",
                constraint_target_entity_id(target),
            )?;
            ensure_control_point_is_available(self, target)?;
        }

        match annotation.kind {
            MeasurementAnnotationKind::Distance => {
                ensure_target_count(annotation, 2)?;
                for target in &annotation.targets {
                    self.resolve_measurement_point(target)?;
                }
            }
            MeasurementAnnotationKind::SegmentLength => {
                ensure_target_count(annotation, 1)?;
                self.resolve_measurement_line(&annotation.targets[0])?;
            }
            MeasurementAnnotationKind::Angle => {
                ensure_target_count(annotation, 2)?;
                let first = self.resolve_measurement_line(&annotation.targets[0])?;
                let second = self.resolve_measurement_line(&annotation.targets[1])?;
                if shared_endpoint(first, second).is_none() {
                    return Err(CommandError::InvalidValue {
                        field: "measurement annotation targets",
                        reason: "angle annotations require two lines sharing one endpoint",
                    });
                }
            }
            MeasurementAnnotationKind::Radius | MeasurementAnnotationKind::Diameter => {
                ensure_target_count(annotation, 1)?;
                self.resolve_measurement_radial_entity(&annotation.targets[0])?;
            }
            MeasurementAnnotationKind::ArcSweepAngle => {
                ensure_target_count(annotation, 1)?;
                self.resolve_measurement_arc_entity(&annotation.targets[0])?;
            }
        }
        Ok(())
    }

    fn validate_dimension_constraint_annotation_target(
        &self,
        annotation: &DimensionConstraintAnnotation,
    ) -> CommandResult {
        let constraint = self
            .constraints
            .iter()
            .find(|constraint| constraint.id == annotation.constraint_id)
            .ok_or_else(|| CommandError::missing("constraint", annotation.constraint_id.clone()))?;
        if constraint.value.is_none() {
            return Err(CommandError::InvalidValue {
                field: "dimension constraint annotation",
                reason: "constraint must be a dimension constraint",
            });
        }
        Ok(())
    }

    fn resolve_measurement_point(&self, target: &ConstraintTarget) -> Result<Point2, CommandError> {
        let entity = self
            .entity(constraint_target_entity_id(target))
            .ok_or_else(|| {
                CommandError::broken_reference(
                    "measurement annotation",
                    "entity",
                    constraint_target_entity_id(target),
                )
            })?;
        match (target, &entity.kind) {
            (ConstraintTarget::Entity(_), EntityKind::Point(point)) => Ok(*point),
            (
                ConstraintTarget::ControlPoint {
                    point: ControlPointKind::Start,
                    ..
                },
                EntityKind::LineSegment(line) | EntityKind::CenterLine(line),
            ) => Ok(line.start),
            (
                ConstraintTarget::ControlPoint {
                    point: ControlPointKind::End,
                    ..
                },
                EntityKind::LineSegment(line) | EntityKind::CenterLine(line),
            ) => Ok(line.end),
            (
                ConstraintTarget::ControlPoint {
                    point: ControlPointKind::Center,
                    ..
                },
                EntityKind::Point(point),
            ) => Ok(*point),
            (
                ConstraintTarget::ControlPoint {
                    point: ControlPointKind::Center,
                    ..
                },
                EntityKind::Circle(circle),
            ) => Ok(circle.center),
            (
                ConstraintTarget::ControlPoint {
                    point: ControlPointKind::Center,
                    ..
                },
                EntityKind::Arc(arc),
            ) => Ok(arc.center),
            (
                ConstraintTarget::ControlPoint {
                    point: ControlPointKind::Start,
                    ..
                },
                EntityKind::Arc(arc),
            ) => Ok(point_on_arc(arc.center, arc.radius_mm, arc.start_angle_rad)),
            (
                ConstraintTarget::ControlPoint {
                    point: ControlPointKind::End,
                    ..
                },
                EntityKind::Arc(arc),
            ) => Ok(point_on_arc(
                arc.center,
                arc.radius_mm,
                arc.start_angle_rad + arc.sweep_angle_rad,
            )),
            _ => Err(CommandError::InvalidValue {
                field: "measurement annotation target",
                reason: "target is not a measurable point",
            }),
        }
    }

    fn resolve_measurement_line(
        &self,
        target: &ConstraintTarget,
    ) -> Result<(Point2, Point2), CommandError> {
        if !matches!(target, ConstraintTarget::Entity(_)) {
            return Err(CommandError::InvalidValue {
                field: "measurement annotation target",
                reason: "line measurements require entity targets",
            });
        }
        let entity = self
            .entity(constraint_target_entity_id(target))
            .ok_or_else(|| {
                CommandError::broken_reference(
                    "measurement annotation",
                    "entity",
                    constraint_target_entity_id(target),
                )
            })?;
        match &entity.kind {
            EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => {
                Ok((line.start, line.end))
            }
            _ => Err(CommandError::InvalidValue {
                field: "measurement annotation target",
                reason: "target is not a measurable line",
            }),
        }
    }

    fn resolve_measurement_radial_entity(&self, target: &ConstraintTarget) -> CommandResult {
        if !matches!(target, ConstraintTarget::Entity(_)) {
            return Err(CommandError::InvalidValue {
                field: "measurement annotation target",
                reason: "radius and diameter annotations require entity targets",
            });
        }
        let entity = self
            .entity(constraint_target_entity_id(target))
            .ok_or_else(|| {
                CommandError::broken_reference(
                    "measurement annotation",
                    "entity",
                    constraint_target_entity_id(target),
                )
            })?;
        match entity.kind {
            EntityKind::Circle(_) | EntityKind::Arc(_) => Ok(()),
            _ => Err(CommandError::InvalidValue {
                field: "measurement annotation target",
                reason: "target is not a circle or arc",
            }),
        }
    }

    fn resolve_measurement_arc_entity(&self, target: &ConstraintTarget) -> CommandResult {
        if !matches!(target, ConstraintTarget::Entity(_)) {
            return Err(CommandError::InvalidValue {
                field: "measurement annotation target",
                reason: "arc sweep annotations require entity targets",
            });
        }
        let entity = self
            .entity(constraint_target_entity_id(target))
            .ok_or_else(|| {
                CommandError::broken_reference(
                    "measurement annotation",
                    "entity",
                    constraint_target_entity_id(target),
                )
            })?;
        match entity.kind {
            EntityKind::Arc(_) => Ok(()),
            _ => Err(CommandError::InvalidValue {
                field: "measurement annotation target",
                reason: "target is not an arc",
            }),
        }
    }
}

fn measurement_constraint_kind(kind: MeasurementAnnotationKind) -> ConstraintKind {
    match kind {
        MeasurementAnnotationKind::Distance => ConstraintKind::Distance,
        MeasurementAnnotationKind::SegmentLength => ConstraintKind::SegmentLength,
        MeasurementAnnotationKind::Angle | MeasurementAnnotationKind::ArcSweepAngle => {
            ConstraintKind::Angle
        }
        MeasurementAnnotationKind::Radius => ConstraintKind::Radius,
        MeasurementAnnotationKind::Diameter => ConstraintKind::Diameter,
    }
}

fn validate_dimension_constraint_annotation_offsets(
    annotation: &DimensionConstraintAnnotation,
) -> CommandResult {
    for (field, value) in [
        (
            "dimension constraint label offset x",
            annotation.label_offset_mm.x_mm,
        ),
        (
            "dimension constraint label offset y",
            annotation.label_offset_mm.y_mm,
        ),
        (
            "dimension constraint overall offset x",
            annotation.overall_offset_mm.x_mm,
        ),
        (
            "dimension constraint overall offset y",
            annotation.overall_offset_mm.y_mm,
        ),
    ] {
        if !value.is_finite() {
            return Err(CommandError::InvalidValue {
                field,
                reason: "must be finite",
            });
        }
    }
    Ok(())
}

fn validate_measurement_annotation_offsets(annotation: &MeasurementAnnotation) -> CommandResult {
    for (field, value) in [
        (
            "measurement label offset x",
            annotation.label_offset_mm.x_mm,
        ),
        (
            "measurement label offset y",
            annotation.label_offset_mm.y_mm,
        ),
        (
            "measurement overall offset x",
            annotation.overall_offset_mm.x_mm,
        ),
        (
            "measurement overall offset y",
            annotation.overall_offset_mm.y_mm,
        ),
    ] {
        if !value.is_finite() {
            return Err(CommandError::InvalidValue {
                field,
                reason: "must be finite",
            });
        }
    }
    Ok(())
}

fn ensure_target_count(annotation: &MeasurementAnnotation, expected: usize) -> CommandResult {
    if annotation.targets.len() == expected {
        Ok(())
    } else {
        Err(CommandError::InvalidValue {
            field: "measurement annotation targets",
            reason: "target count does not match measurement kind",
        })
    }
}

fn ensure_control_point_is_available(
    document: &ProjectDocument,
    target: &ConstraintTarget,
) -> CommandResult {
    let ConstraintTarget::ControlPoint { entity_id, point } = target else {
        return Ok(());
    };
    let entity = document.entity(entity_id).ok_or_else(|| {
        CommandError::broken_reference("measurement annotation", "entity", entity_id)
    })?;
    let valid = matches!(
        (&entity.kind, point),
        (EntityKind::Point(_), ControlPointKind::Center)
            | (EntityKind::Circle(_), ControlPointKind::Center)
            | (
                EntityKind::LineSegment(_),
                ControlPointKind::Start | ControlPointKind::End
            )
            | (
                EntityKind::CenterLine(_),
                ControlPointKind::Start | ControlPointKind::End
            )
            | (
                EntityKind::Arc(_),
                ControlPointKind::Start | ControlPointKind::End | ControlPointKind::Center
            )
    );
    if valid {
        Ok(())
    } else {
        Err(CommandError::InvalidValue {
            field: "measurement annotation target",
            reason: "control point is not available on target entity",
        })
    }
}

fn shared_endpoint(first: (Point2, Point2), second: (Point2, Point2)) -> Option<Point2> {
    [first.0, first.1]
        .into_iter()
        .find(|candidate| point_close(*candidate, second.0) || point_close(*candidate, second.1))
}

fn point_close(first: Point2, second: Point2) -> bool {
    (first.x_mm - second.x_mm).abs() <= GEOMETRY_EPSILON_MM
        && (first.y_mm - second.y_mm).abs() <= GEOMETRY_EPSILON_MM
}

fn point_on_arc(center: Point2, radius_mm: f64, angle_rad: f64) -> Point2 {
    Point2::new(
        center.x_mm + radius_mm * angle_rad.cos(),
        center.y_mm + radius_mm * angle_rad.sin(),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn point(x_mm: f64, y_mm: f64) -> Point2 {
        Point2::new(x_mm, y_mm)
    }

    fn target(entity_id: &str) -> ConstraintTarget {
        ConstraintTarget::Entity(entity_id.to_owned())
    }

    fn control_point(entity_id: &str, point: ControlPointKind) -> ConstraintTarget {
        ConstraintTarget::ControlPoint {
            entity_id: entity_id.to_owned(),
            point,
        }
    }

    fn annotation(
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

    fn document_with_measurement_entities() -> ProjectDocument {
        let mut document = ProjectDocument::new("Measurement Coverage");
        document.entities = vec![
            Entity::new("entity:point", EntityKind::Point(point(1.0, 2.0))),
            Entity::new(
                "entity:line-a",
                EntityKind::LineSegment(LineSegment::new(point(0.0, 0.0), point(10.0, 0.0))),
            ),
            Entity::new(
                "entity:line-b",
                EntityKind::CenterLine(LineSegment::new(point(0.0, 0.0), point(0.0, 10.0))),
            ),
            Entity::new(
                "entity:line-c",
                EntityKind::LineSegment(LineSegment::new(point(20.0, 0.0), point(30.0, 0.0))),
            ),
            Entity::new(
                "entity:circle",
                EntityKind::Circle(Circle {
                    center: point(5.0, 5.0),
                    radius_mm: 3.0,
                }),
            ),
            Entity::new(
                "entity:arc",
                EntityKind::Arc(crate::geometry::Arc {
                    center: point(20.0, 20.0),
                    radius_mm: 5.0,
                    start_angle_rad: 0.0,
                    sweep_angle_rad: std::f64::consts::FRAC_PI_2,
                }),
            ),
        ];
        document
    }

    #[test]
    fn accepts_all_measurement_annotation_target_shapes() {
        let mut document = document_with_measurement_entities();
        let annotations = vec![
            annotation(
                "measurement:distance-entities",
                MeasurementAnnotationKind::Distance,
                vec![
                    target("entity:point"),
                    control_point("entity:circle", ControlPointKind::Center),
                ],
            ),
            annotation(
                "measurement:distance-arc",
                MeasurementAnnotationKind::Distance,
                vec![
                    control_point("entity:arc", ControlPointKind::Start),
                    control_point("entity:arc", ControlPointKind::End),
                ],
            ),
            annotation(
                "measurement:length",
                MeasurementAnnotationKind::SegmentLength,
                vec![target("entity:line-a")],
            ),
            annotation(
                "measurement:angle",
                MeasurementAnnotationKind::Angle,
                vec![target("entity:line-a"), target("entity:line-b")],
            ),
            annotation(
                "measurement:radius-circle",
                MeasurementAnnotationKind::Radius,
                vec![target("entity:circle")],
            ),
            annotation(
                "measurement:diameter-arc",
                MeasurementAnnotationKind::Diameter,
                vec![target("entity:arc")],
            ),
            annotation(
                "measurement:sweep",
                MeasurementAnnotationKind::ArcSweepAngle,
                vec![target("entity:arc")],
            ),
        ];

        for annotation in annotations {
            document
                .add_measurement_annotation(annotation)
                .expect("measurement annotation should be accepted");
        }

        assert_eq!(document.measurement_annotations().len(), 7);
    }

    #[test]
    fn rejects_measurement_annotations_with_invalid_targets_or_offsets() {
        let mut document = document_with_measurement_entities();
        let invalid_cases = vec![
            annotation(
                " ",
                MeasurementAnnotationKind::SegmentLength,
                vec![target("entity:line-a")],
            ),
            annotation(
                "measurement:missing",
                MeasurementAnnotationKind::Distance,
                vec![target("entity:point"), target("entity:missing")],
            ),
            annotation(
                "measurement:wrong-count",
                MeasurementAnnotationKind::SegmentLength,
                vec![target("entity:line-a"), target("entity:line-b")],
            ),
            annotation(
                "measurement:bad-point",
                MeasurementAnnotationKind::Distance,
                vec![target("entity:line-a"), target("entity:point")],
            ),
            annotation(
                "measurement:bad-line",
                MeasurementAnnotationKind::SegmentLength,
                vec![control_point("entity:line-a", ControlPointKind::Start)],
            ),
            annotation(
                "measurement:disconnected-angle",
                MeasurementAnnotationKind::Angle,
                vec![target("entity:line-a"), target("entity:line-c")],
            ),
            annotation(
                "measurement:bad-radius",
                MeasurementAnnotationKind::Radius,
                vec![target("entity:line-a")],
            ),
            annotation(
                "measurement:bad-sweep",
                MeasurementAnnotationKind::ArcSweepAngle,
                vec![target("entity:circle")],
            ),
            annotation(
                "measurement:bad-control",
                MeasurementAnnotationKind::Distance,
                vec![
                    control_point("entity:circle", ControlPointKind::Start),
                    target("entity:point"),
                ],
            ),
        ];

        for invalid in invalid_cases {
            assert!(document.add_measurement_annotation(invalid).is_err());
        }

        let mut non_finite = annotation(
            "measurement:non-finite",
            MeasurementAnnotationKind::Distance,
            vec![
                target("entity:point"),
                control_point("entity:arc", ControlPointKind::Center),
            ],
        );
        non_finite.label_offset_mm.x_mm = f64::INFINITY;
        assert!(matches!(
            document.add_measurement_annotation(non_finite),
            Err(CommandError::InvalidValue {
                field: "measurement label offset x",
                ..
            })
        ));
    }

    #[test]
    fn update_and_prune_measurement_annotations_report_removed_warnings() {
        let mut document = document_with_measurement_entities();
        document
            .add_measurement_annotation(annotation(
                "measurement:distance",
                MeasurementAnnotationKind::Distance,
                vec![
                    target("entity:point"),
                    control_point("entity:arc", ControlPointKind::Center),
                ],
            ))
            .expect("measurement annotation should be added");
        document
            .add_measurement_annotation(annotation(
                "measurement:length",
                MeasurementAnnotationKind::SegmentLength,
                vec![target("entity:line-a")],
            ))
            .expect("line measurement should be added");

        let mut updated = annotation(
            "measurement:distance",
            MeasurementAnnotationKind::Distance,
            vec![
                target("entity:point"),
                control_point("entity:circle", ControlPointKind::Center),
            ],
        );
        updated.visible = false;
        document
            .update_measurement_annotation(updated)
            .expect("measurement annotation should update");
        assert!(!document.measurement_annotations()[0].visible);
        assert!(document
            .update_measurement_annotation(annotation(
                "measurement:missing",
                MeasurementAnnotationKind::SegmentLength,
                vec![target("entity:line-a")],
            ))
            .is_err());

        document.remove_measurement_annotations_for_entity("entity:line-a");
        assert_eq!(document.measurement_annotations().len(), 1);
        assert_eq!(document.document_warnings().len(), 1);
        assert_eq!(
            document.document_warnings()[0].measurement_annotation_id,
            "measurement:length"
        );

        document
            .entities
            .retain(|entity| entity.id != "entity:circle");
        document.prune_unresolvable_measurement_annotations();
        assert!(document.measurement_annotations().is_empty());
        assert_eq!(document.document_warnings().len(), 2);
        assert_eq!(
            document.document_warnings()[1].measurement_annotation_id,
            "measurement:distance"
        );
    }

    #[test]
    fn measurement_geometry_helpers_use_endpoint_tolerance_and_arc_points() {
        let first = (point(0.0, 0.0), point(10.0, 0.0));
        let second = (
            point(10.0 + GEOMETRY_EPSILON_MM / 2.0, 0.0),
            point(10.0, 10.0),
        );
        assert_eq!(shared_endpoint(first, second), Some(point(10.0, 0.0)));
        assert!(point_close(
            point(1.0, 1.0),
            point(1.0 + GEOMETRY_EPSILON_MM / 2.0, 1.0)
        ));
        assert!(!point_close(
            point(1.0, 1.0),
            point(1.0 + GEOMETRY_EPSILON_MM * 2.0, 1.0)
        ));

        let arc_point = point_on_arc(point(3.0, 4.0), 2.0, std::f64::consts::FRAC_PI_2);
        assert!((arc_point.x_mm - 3.0).abs() <= GEOMETRY_EPSILON_MM);
        assert!((arc_point.y_mm - 6.0).abs() <= GEOMETRY_EPSILON_MM);
    }
}
