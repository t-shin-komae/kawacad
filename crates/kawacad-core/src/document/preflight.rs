use super::*;

/// Core-side result for evaluating constraint targets before creating a command.
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ConstraintPreflightResult {
    /// Constraint kind evaluated by preflight.
    pub kind: ConstraintKind,
    /// Optional initial value inferred from core domain semantics.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub value: Option<ConstraintValue>,
    /// Core が拘束へ保存すべき順序と制御点へ正規化した target。
    pub normalized_targets: Vec<ConstraintTarget>,
}

impl ProjectDocument {
    /// Evaluates constraint targets without mutating the document.
    pub fn preflight_constraint(
        &self,
        kind: ConstraintKind,
        targets: Vec<ConstraintTarget>,
    ) -> CommandResult<ConstraintPreflightResult> {
        match kind {
            ConstraintKind::Distance => self.preflight_distance_constraint(targets),
            ConstraintKind::HorizontalDistance => {
                self.preflight_axis_distance_constraint(kind, targets, Axis::Horizontal)
            }
            ConstraintKind::VerticalDistance => {
                self.preflight_axis_distance_constraint(kind, targets, Axis::Vertical)
            }
            ConstraintKind::LineLineDistance => {
                self.preflight_line_line_distance_constraint(targets)
            }
            ConstraintKind::SegmentLength => self.preflight_segment_length_constraint(targets),
            ConstraintKind::Diameter => self.preflight_diameter_constraint(targets),
            ConstraintKind::Radius => self.preflight_radius_constraint(targets),
            ConstraintKind::Angle => self.preflight_angle_constraint(targets),
            ConstraintKind::Tangent => self.preflight_tangent_constraint(targets),
            ConstraintKind::PointOnLine => self.preflight_point_on_line_constraint(targets),
            _ => Ok(self.preflight_result(kind, targets, None)),
        }
    }

    fn preflight_distance_constraint(
        &self,
        targets: Vec<ConstraintTarget>,
    ) -> CommandResult<ConstraintPreflightResult> {
        let [first, second] = targets.as_slice() else {
            return Err(CommandError::InvalidValue {
                field: "constraint targets",
                reason: "distance preflight requires exactly two targets",
            });
        };
        if let (Ok(first_point), Ok(second_point)) = (
            preflight_point_for_target(&self.entities, first),
            preflight_point_for_target(&self.entities, second),
        ) {
            return Ok(self.preflight_result(
                ConstraintKind::Distance,
                targets,
                Some(ConstraintValue::FixedMm(point_distance(
                    first_point,
                    second_point,
                ))),
            ));
        }
        if let (Ok(point), Ok(line)) = (
            preflight_point_for_target(&self.entities, first),
            line_for_entity_target(&self.entities, second),
        ) {
            return Ok(self.preflight_result(
                ConstraintKind::PointLineDistance,
                targets,
                Some(ConstraintValue::FixedMm(point_line_distance(point, line))),
            ));
        }
        if let (Ok(point), Ok(line)) = (
            preflight_point_for_target(&self.entities, second),
            line_for_entity_target(&self.entities, first),
        ) {
            return Ok(self.preflight_result(
                ConstraintKind::PointLineDistance,
                targets,
                Some(ConstraintValue::FixedMm(point_line_distance(point, line))),
            ));
        }
        Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "distance preflight requires two points or one point and one line",
        })
    }

    fn preflight_axis_distance_constraint(
        &self,
        kind: ConstraintKind,
        targets: Vec<ConstraintTarget>,
        axis: Axis,
    ) -> CommandResult<ConstraintPreflightResult> {
        let [first, second] = targets.as_slice() else {
            return Err(CommandError::InvalidValue {
                field: "constraint targets",
                reason: "axis distance preflight requires exactly two point targets",
            });
        };
        let first = preflight_point_for_target(&self.entities, first)?;
        let second = preflight_point_for_target(&self.entities, second)?;
        let value = match axis {
            Axis::Horizontal => (second.x_mm - first.x_mm).abs(),
            Axis::Vertical => (second.y_mm - first.y_mm).abs(),
        };
        Ok(self.preflight_result(kind, targets, Some(ConstraintValue::FixedMm(value))))
    }

    fn preflight_line_line_distance_constraint(
        &self,
        targets: Vec<ConstraintTarget>,
    ) -> CommandResult<ConstraintPreflightResult> {
        let [first, second] = targets.as_slice() else {
            return Err(CommandError::InvalidValue {
                field: "constraint targets",
                reason: "line-line distance preflight requires exactly two line targets",
            });
        };
        let first = line_for_entity_target(&self.entities, first)?;
        let second = line_for_entity_target(&self.entities, second)?;
        Ok(self.preflight_result(
            ConstraintKind::LineLineDistance,
            targets,
            Some(ConstraintValue::FixedMm(point_line_distance(
                second.start,
                first,
            ))),
        ))
    }

    fn preflight_segment_length_constraint(
        &self,
        targets: Vec<ConstraintTarget>,
    ) -> CommandResult<ConstraintPreflightResult> {
        let [target] = targets.as_slice() else {
            return Err(CommandError::InvalidValue {
                field: "constraint targets",
                reason: "segment length preflight requires exactly one line target",
            });
        };
        let line = line_for_entity_target(&self.entities, target)?;
        Ok(self.preflight_result(
            ConstraintKind::SegmentLength,
            targets,
            Some(ConstraintValue::FixedMm(line.length_mm())),
        ))
    }

    fn preflight_diameter_constraint(
        &self,
        targets: Vec<ConstraintTarget>,
    ) -> CommandResult<ConstraintPreflightResult> {
        let [target] = targets.as_slice() else {
            return Err(CommandError::InvalidValue {
                field: "constraint targets",
                reason: "diameter preflight requires exactly one circle target",
            });
        };
        let circle = circle_for_entity_target(&self.entities, target)?;
        Ok(self.preflight_result(
            ConstraintKind::Diameter,
            targets,
            Some(ConstraintValue::FixedMm(circle.radius_mm * 2.0)),
        ))
    }

    fn preflight_radius_constraint(
        &self,
        targets: Vec<ConstraintTarget>,
    ) -> CommandResult<ConstraintPreflightResult> {
        let [target] = targets.as_slice() else {
            return Err(CommandError::InvalidValue {
                field: "constraint targets",
                reason: "radius preflight requires exactly one radius target",
            });
        };
        let radius = radius_entity_for_target(&self.entities, target)?;
        Ok(self.preflight_result(
            ConstraintKind::Radius,
            targets,
            Some(ConstraintValue::FixedMm(radius.radius_mm)),
        ))
    }

    fn preflight_tangent_constraint(
        &self,
        targets: Vec<ConstraintTarget>,
    ) -> CommandResult<ConstraintPreflightResult> {
        let constraint = Constraint {
            id: "constraint:preflight:tangent".to_owned(),
            kind: ConstraintKind::Tangent,
            targets,
            value: None,
            status: ConstraintStatus::Unknown,
        };
        tangent_targets_from_document(self, &constraint)?;
        Ok(self.preflight_result(ConstraintKind::Tangent, constraint.targets, None))
    }

    fn preflight_point_on_line_constraint(
        &self,
        targets: Vec<ConstraintTarget>,
    ) -> CommandResult<ConstraintPreflightResult> {
        let [first, second] = targets.as_slice() else {
            return Err(CommandError::InvalidValue {
                field: "constraint targets",
                reason: "point-on-line preflight requires exactly two targets",
            });
        };
        let is_point_line = preflight_point_for_target(&self.entities, first).is_ok()
            && line_for_entity_target(&self.entities, second).is_ok();
        let is_line_point = line_for_entity_target(&self.entities, first).is_ok()
            && preflight_point_for_target(&self.entities, second).is_ok();
        if !is_point_line && !is_line_point {
            return Err(CommandError::InvalidValue {
                field: "constraint targets",
                reason: "point-on-line preflight requires one point and one line target",
            });
        }
        Ok(self.preflight_result(ConstraintKind::PointOnLine, targets, None))
    }

    fn preflight_angle_constraint(
        &self,
        targets: Vec<ConstraintTarget>,
    ) -> CommandResult<ConstraintPreflightResult> {
        let value = match targets.as_slice() {
            [ConstraintTarget::Entity(entity_id)] => {
                let entity = self.entity(entity_id).ok_or_else(|| {
                    CommandError::broken_reference("constraint", "entity", entity_id)
                })?;
                match &entity.kind {
                    EntityKind::Arc(arc) => {
                        ConstraintValue::FixedDegrees(arc.sweep_angle_rad.to_degrees())
                    }
                    _ => {
                        return Err(CommandError::InvalidValue {
                            field: "constraint targets",
                            reason: "angle constraints require an arc target",
                        });
                    }
                }
            }
            [_, _] => {
                let angle_lines =
                    shared_endpoint_angle_lines_from_targets(&self.entities, &targets)?;
                ConstraintValue::FixedDegrees(
                    signed_angle(angle_lines.first_direction, angle_lines.second_direction)
                        .to_degrees(),
                )
            }
            _ => {
                return Err(CommandError::InvalidValue {
                    field: "constraint targets",
                    reason: "angle constraints require one arc target or two line targets",
                });
            }
        };
        Ok(self.preflight_result(ConstraintKind::Angle, targets, Some(value)))
    }

    fn preflight_result(
        &self,
        kind: ConstraintKind,
        targets: Vec<ConstraintTarget>,
        value: Option<ConstraintValue>,
    ) -> ConstraintPreflightResult {
        ConstraintPreflightResult {
            kind,
            normalized_targets: self.normalized_constraint_targets(kind, targets),
            value,
        }
    }

    fn normalized_constraint_targets(
        &self,
        kind: ConstraintKind,
        targets: Vec<ConstraintTarget>,
    ) -> Vec<ConstraintTarget> {
        let point_oriented = matches!(
            kind,
            ConstraintKind::Distance
                | ConstraintKind::PointLineDistance
                | ConstraintKind::HorizontalDistance
                | ConstraintKind::VerticalDistance
                | ConstraintKind::PointOnLine
                | ConstraintKind::Coincident
                | ConstraintKind::Fixed
                | ConstraintKind::Symmetric
                | ConstraintKind::Tangent
        );
        let mut normalized = targets
            .into_iter()
            .map(|target| {
                if !point_oriented {
                    return target;
                }
                let ConstraintTarget::Entity(entity_id) = &target else {
                    return target;
                };
                match self.entity(entity_id).map(|entity| &entity.kind) {
                    Some(EntityKind::Circle(_)) | Some(EntityKind::Arc(_)) => {
                        ConstraintTarget::ControlPoint {
                            entity_id: entity_id.clone(),
                            point: ControlPointKind::Center,
                        }
                    }
                    _ => target,
                }
            })
            .collect::<Vec<_>>();
        if matches!(
            kind,
            ConstraintKind::PointLineDistance | ConstraintKind::PointOnLine
        ) && normalized.len() == 2
            && preflight_point_for_target(&self.entities, &normalized[1]).is_ok()
            && line_for_entity_target(&self.entities, &normalized[0]).is_ok()
        {
            normalized.swap(0, 1);
        }
        normalized
    }
}

enum Axis {
    Horizontal,
    Vertical,
}

fn preflight_point_for_target(
    entities: &[Entity],
    target: &ConstraintTarget,
) -> CommandResult<Point2> {
    if let Ok(point) = point_for_target(entities, target) {
        return Ok(point);
    }
    let entity = find_entity(entities, constraint_target_entity_id(target)).ok_or_else(|| {
        CommandError::broken_reference("constraint", "entity", constraint_target_entity_id(target))
    })?;
    match (target, &entity.kind) {
        (ConstraintTarget::Entity(_), EntityKind::Circle(circle)) => Ok(circle.center),
        (ConstraintTarget::Entity(_), EntityKind::Arc(arc)) => Ok(arc.center),
        _ => Err(CommandError::InvalidValue {
            field: "constraint targets",
            reason: "target must resolve to a point-compatible entity",
        }),
    }
}

fn point_distance(first: Point2, second: Point2) -> f64 {
    (first.x_mm - second.x_mm).hypot(first.y_mm - second.y_mm)
}

fn point_line_distance(point: Point2, line: LineSegment) -> f64 {
    let dx = line.end.x_mm - line.start.x_mm;
    let dy = line.end.y_mm - line.start.y_mm;
    let length = dx.hypot(dy);
    if length <= GEOMETRY_EPSILON_MM {
        return 0.0;
    }
    let relative_x = point.x_mm - line.start.x_mm;
    let relative_y = point.y_mm - line.start.y_mm;
    (relative_x * (-dy / length) + relative_y * (dx / length)).abs()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn point(x_mm: f64, y_mm: f64) -> Point2 {
        Point2::new(x_mm, y_mm)
    }

    fn line_entity(id: &str, start: Point2, end: Point2) -> Entity {
        Entity::new(id, EntityKind::LineSegment(LineSegment::new(start, end)))
    }

    fn target(entity_id: &str) -> ConstraintTarget {
        ConstraintTarget::Entity(entity_id.to_owned())
    }

    #[test]
    fn angle_preflight_uses_shared_endpoint_direction_from_core() {
        let mut document = ProjectDocument::new("Angle Preflight");
        document.entities = vec![
            line_entity("entity:first", point(0.0, 0.0), point(10.0, 0.0)),
            line_entity("entity:second", point(0.0, 0.0), point(0.0, 10.0)),
        ];

        let result = document
            .preflight_constraint(
                ConstraintKind::Angle,
                vec![target("entity:first"), target("entity:second")],
            )
            .expect("angle preflight should succeed");

        assert_eq!(result.kind, ConstraintKind::Angle);
        assert_eq!(result.value, Some(ConstraintValue::FixedDegrees(90.0)));
    }

    #[test]
    fn angle_preflight_rejects_lines_without_shared_endpoint() {
        let mut document = ProjectDocument::new("Disconnected Angle Preflight");
        document.entities = vec![
            line_entity("entity:first", point(0.0, 0.0), point(10.0, 0.0)),
            line_entity("entity:second", point(20.0, 0.0), point(20.0, 10.0)),
        ];

        let result = document.preflight_constraint(
            ConstraintKind::Angle,
            vec![target("entity:first"), target("entity:second")],
        );

        assert!(matches!(
            result,
            Err(CommandError::InvalidValue {
                field: "constraint targets",
                ..
            })
        ));
    }

    #[test]
    fn dimension_preflight_returns_core_measurement_values() {
        let mut document = ProjectDocument::new("Dimension Preflight");
        document.entities = vec![
            Entity::new("entity:point", EntityKind::Point(point(3.0, 4.0))),
            line_entity("entity:line", point(0.0, 0.0), point(20.0, 0.0)),
            Entity::new(
                "entity:circle",
                EntityKind::Circle(Circle {
                    center: point(12.0, 4.0),
                    radius_mm: 5.0,
                }),
            ),
        ];

        let point_line = document
            .preflight_constraint(
                ConstraintKind::Distance,
                vec![target("entity:point"), target("entity:line")],
            )
            .expect("point-line distance preflight");
        assert_eq!(point_line.kind, ConstraintKind::PointLineDistance);
        assert_eq!(point_line.value, Some(ConstraintValue::FixedMm(4.0)));
        assert_eq!(
            point_line.normalized_targets,
            vec![target("entity:point"), target("entity:line")]
        );

        let horizontal = document
            .preflight_constraint(
                ConstraintKind::HorizontalDistance,
                vec![target("entity:point"), target("entity:circle")],
            )
            .expect("horizontal distance preflight");
        assert_eq!(horizontal.kind, ConstraintKind::HorizontalDistance);
        assert_eq!(horizontal.value, Some(ConstraintValue::FixedMm(9.0)));
        assert_eq!(
            horizontal.normalized_targets,
            vec![
                target("entity:point"),
                ConstraintTarget::ControlPoint {
                    entity_id: "entity:circle".to_owned(),
                    point: ControlPointKind::Center,
                },
            ]
        );

        let segment = document
            .preflight_constraint(ConstraintKind::SegmentLength, vec![target("entity:line")])
            .expect("segment length preflight");
        assert_eq!(segment.value, Some(ConstraintValue::FixedMm(20.0)));

        let diameter = document
            .preflight_constraint(ConstraintKind::Diameter, vec![target("entity:circle")])
            .expect("diameter preflight");
        assert_eq!(diameter.value, Some(ConstraintValue::FixedMm(10.0)));
    }

    #[test]
    fn point_on_line_preflight_normalizes_reversed_circle_center_target() {
        let mut document = ProjectDocument::new("Point on line");
        document.entities = vec![
            line_entity("entity:line", point(0.0, 0.0), point(20.0, 0.0)),
            Entity::new(
                "entity:circle",
                EntityKind::Circle(Circle {
                    center: point(10.0, 5.0),
                    radius_mm: 2.0,
                }),
            ),
        ];

        let result = document
            .preflight_constraint(
                ConstraintKind::PointOnLine,
                vec![target("entity:line"), target("entity:circle")],
            )
            .expect("point-on-line preflight");

        assert_eq!(
            result.normalized_targets,
            vec![
                ConstraintTarget::ControlPoint {
                    entity_id: "entity:circle".to_owned(),
                    point: ControlPointKind::Center,
                },
                target("entity:line"),
            ]
        );
    }
}
