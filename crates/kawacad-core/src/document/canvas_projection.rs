use super::*;

impl ProjectDocument {
    /// 現在形状から Canvas 描画用の意味アンカーと表示可否を解決する。
    pub fn canvas_projection(&self, view_mode: CanvasViewMode) -> CanvasProjection {
        let visible_free_text_ids = self
            .free_texts
            .iter()
            .filter(|text| self.free_text_is_visible(&text.id, view_mode))
            .map(|text| text.id.clone())
            .collect();

        let stitch_start_points = self
            .stitch_start_points
            .iter()
            .filter_map(|stitch| {
                stitch_start_point_position(self, stitch)
                    .ok()
                    .map(|position_mm| ResolvedCanvasPoint {
                        id: stitch.id.clone(),
                        position_mm,
                        visible: self.stitch_is_visible(stitch, view_mode),
                    })
            })
            .collect();

        let measurement_annotations = self
            .measurement_annotations()
            .iter()
            .filter_map(|annotation| {
                self.evaluate_measurement_by_id(&annotation.id)
                    .ok()
                    .map(|evaluation| ResolvedCanvasGeometry {
                        id: annotation.id.clone(),
                        visible: annotation.visible
                            && self.measurement_is_visible(
                                &annotation.id,
                                &annotation.targets,
                                view_mode,
                            ),
                        arc: annotation.kind
                            == crate::measurement::MeasurementAnnotationKind::ArcSweepAngle,
                        center_mm: evaluation.center,
                        start_mm: evaluation.start,
                        end_mm: evaluation.end,
                    })
            })
            .collect();

        let dimension_constraints = self
            .dimension_constraint_annotations()
            .iter()
            .filter_map(|annotation| {
                let constraint = self
                    .constraints
                    .iter()
                    .find(|constraint| constraint.id == annotation.constraint_id)?;
                self.resolve_dimension_geometry(constraint).ok().map(
                    |(center_mm, start_mm, end_mm)| ResolvedCanvasGeometry {
                        id: annotation.constraint_id.clone(),
                        visible: annotation.visible
                            && self.dimension_layer_is_visible(view_mode)
                            && self.targets_are_visible(&constraint.targets, view_mode),
                        arc: constraint.kind == ConstraintKind::Angle
                            && constraint.targets.len() == 1,
                        center_mm,
                        start_mm,
                        end_mm,
                    },
                )
            })
            .collect();

        let constraint_markers = self
            .constraints
            .iter()
            .filter_map(|constraint| {
                self.constraint_marker_anchor(constraint)
                    .map(|position_mm| ResolvedCanvasPoint {
                        id: constraint.id.clone(),
                        position_mm,
                        visible: self.dimension_layer_is_visible(view_mode)
                            && self.targets_are_visible(&constraint.targets, view_mode),
                    })
            })
            .collect();

        CanvasProjection {
            visible_free_text_ids,
            stitch_start_points,
            measurement_annotations,
            dimension_constraints,
            constraint_markers,
        }
    }

    fn free_text_is_visible(&self, id: &str, view_mode: CanvasViewMode) -> bool {
        self.parts
            .iter()
            .find(|part| part.free_text_ids.iter().any(|item| item == id))
            .map(|part| match view_mode {
                CanvasViewMode::EditDisplay => part.visible,
                CanvasViewMode::OutputPreview => part.printable,
            })
            .unwrap_or(true)
    }

    fn measurement_is_visible(
        &self,
        id: &str,
        targets: &[ConstraintTarget],
        view_mode: CanvasViewMode,
    ) -> bool {
        let part_visible = self
            .parts
            .iter()
            .find(|part| {
                part.measurement_annotation_ids
                    .iter()
                    .any(|item| item == id)
            })
            .map(|part| match view_mode {
                CanvasViewMode::EditDisplay => part.visible,
                CanvasViewMode::OutputPreview => part.printable,
            })
            .unwrap_or(true);
        part_visible
            && self.dimension_layer_is_visible(view_mode)
            && self.targets_are_visible(targets, view_mode)
    }

    fn dimension_layer_is_visible(&self, view_mode: CanvasViewMode) -> bool {
        self.layers
            .iter()
            .find(|layer| layer.kind == LayerKind::Dimension || layer.id == "layer:dimension")
            .map(|layer| {
                layer.visible
                    && (!matches!(view_mode, CanvasViewMode::OutputPreview) || layer.printable)
            })
            .unwrap_or(true)
    }

    fn stitch_is_visible(&self, stitch: &StitchStartPoint, view_mode: CanvasViewMode) -> bool {
        if let Some(entity) = self.entity(&stitch.target_id) {
            return self.entity_visible_for_canvas(entity, view_mode);
        }
        let Some(derived) = self.derived_element(&stitch.target_id) else {
            return false;
        };
        self.derived_is_part_visible(
            &derived.id,
            matches!(view_mode, CanvasViewMode::OutputPreview),
        ) && derived
            .layer_id
            .as_deref()
            .and_then(|id| self.layers.iter().find(|layer| layer.id == id))
            .map(|layer| {
                layer.visible
                    && (!matches!(view_mode, CanvasViewMode::OutputPreview) || layer.printable)
            })
            .unwrap_or(true)
    }

    fn targets_are_visible(&self, targets: &[ConstraintTarget], view_mode: CanvasViewMode) -> bool {
        !targets.is_empty()
            && targets.iter().all(|target| {
                self.entity(constraint_target_entity_id(target))
                    .is_some_and(|entity| self.entity_visible_for_canvas(entity, view_mode))
            })
    }

    fn entity_visible_for_canvas(&self, entity: &Entity, view_mode: CanvasViewMode) -> bool {
        let part_visible = match view_mode {
            CanvasViewMode::EditDisplay => self.entity_is_part_visible(&entity.id),
            CanvasViewMode::OutputPreview => self
                .parts
                .iter()
                .find(|part| part.entity_ids.contains(&entity.id))
                .map(|part| part.printable)
                .unwrap_or(true),
        };
        part_visible
            && entity
                .layer_id
                .as_deref()
                .and_then(|id| self.layers.iter().find(|layer| layer.id == id))
                .map(|layer| {
                    layer.visible
                        && (!matches!(view_mode, CanvasViewMode::OutputPreview) || layer.printable)
                })
                .unwrap_or(true)
    }

    fn constraint_marker_anchor(&self, constraint: &Constraint) -> Option<Point2> {
        let points = constraint
            .targets
            .iter()
            .filter_map(|target| self.constraint_target_anchor(target))
            .collect::<Vec<_>>();
        if points.is_empty() {
            return None;
        }
        Some(Point2::new(
            points.iter().map(|point| point.x_mm).sum::<f64>() / points.len() as f64,
            points.iter().map(|point| point.y_mm).sum::<f64>() / points.len() as f64,
        ))
    }

    fn constraint_target_anchor(&self, target: &ConstraintTarget) -> Option<Point2> {
        match target {
            ConstraintTarget::ControlPoint { .. } => point_for_target(&self.entities, target).ok(),
            ConstraintTarget::Entity(_) => point_for_target(&self.entities, target)
                .ok()
                .or_else(|| {
                    line_for_entity_target(&self.entities, target)
                        .ok()
                        .map(|line| {
                            Point2::new(
                                (line.start.x_mm + line.end.x_mm) / 2.0,
                                (line.start.y_mm + line.end.y_mm) / 2.0,
                            )
                        })
                })
                .or_else(|| {
                    circle_for_entity_target(&self.entities, target)
                        .ok()
                        .map(|circle| circle.center)
                })
                .or_else(|| {
                    arc_for_entity_target(&self.entities, target)
                        .ok()
                        .map(|arc| arc.center)
                }),
        }
    }
}
