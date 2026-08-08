use super::*;
use std::collections::{BTreeMap, BTreeSet};

#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
/// Core が UI のクリップボード保持用に書き出す不透明な選択スナップショット。
pub struct SelectionClipboardExport {
    /// UI が内容を解釈せず、そのまま貼り付けコマンドへ渡すトークン。
    pub clipboard_json: String,
    /// 利用者が明示選択したルート項目数。
    pub root_count: usize,
    /// カーソル位置貼り付けの基準点。
    pub anchor_point: Option<Point2>,
    /// カーソル貼り付けと重なり回避に使う、選択集合の外接矩形。
    pub bounds: Option<SelectionBounds>,
}

/// 選択集合のモデル空間上の外接矩形。単位はミリメートル。
#[derive(Debug, Clone, Copy, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SelectionBounds {
    /// X/Y ともに最小の外接矩形頂点。
    pub min_point: Point2,
    /// X/Y ともに最大の外接矩形頂点。
    pub max_point: Point2,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct SelectionClipboard {
    source_document: ProjectDocument,
    selection: SelectionReference,
}

#[derive(Debug, Clone, Copy)]
struct Vector {
    x: f64,
    y: f64,
}

#[derive(Debug, Clone)]
struct TangencyLineConnection {
    entity: Entity,
    connected_point: ControlPointKind,
    anchor: Point2,
    original_connected_point: Point2,
    direction_from_anchor: Vector,
    center_line: bool,
}

#[derive(Debug, Clone)]
struct SmoothInputs {
    arc: Entity,
    current_center: Point2,
    current_radius_mm: f64,
    current_sweep_angle_rad: f64,
    start_line: TangencyLineConnection,
    end_line: TangencyLineConnection,
}

#[derive(Debug, Clone, Copy)]
struct SmoothCandidate {
    center: Point2,
    start_point: Point2,
    end_point: Point2,
    radius: f64,
    start_angle: f64,
    sweep_angle: f64,
    score: f64,
}

impl ProjectDocument {
    /// 選択と依存閉包を Core 所有の不透明スナップショットとして書き出す。
    pub fn export_selection(
        &self,
        selection: SelectionReference,
    ) -> CommandResult<SelectionClipboardExport> {
        // 複製と同じ検証経路を通し、境界外参照を持つ明示選択をコピー時点で拒否する。
        let mut validation = self.clone();
        validation.duplicate_selection(
            selection.clone(),
            "clipboard-validation",
            Point2::new(0.0, 0.0),
        )?;
        let root_count = selection.entity_ids.len()
            + selection.derived_element_ids.len()
            + selection.constraint_ids.len()
            + selection.measurement_annotation_ids.len()
            + selection.stitch_start_point_ids.len()
            + selection.free_text_ids.len();
        let bounds = selection_bounds(self, &selection);
        let anchor_point = bounds.map(SelectionBounds::center);
        let clipboard_json = serde_json::to_string(&SelectionClipboard {
            source_document: self.clone(),
            selection,
        })
        .map_err(|_| CommandError::InvalidValue {
            field: "selection clipboard",
            reason: "failed to serialize selection snapshot",
        })?;
        Ok(SelectionClipboardExport {
            clipboard_json,
            root_count,
            anchor_point,
            bounds,
        })
    }

    pub(crate) fn paste_selection(
        &mut self,
        clipboard_json: &str,
        id_namespace: &str,
        delta: Point2,
    ) -> CommandResult {
        let clipboard: SelectionClipboard =
            serde_json::from_str(clipboard_json).map_err(|_| CommandError::InvalidValue {
                field: "selection clipboard",
                reason: "clipboard token is invalid",
            })?;
        let mut staging = clipboard.source_document;
        staging.duplicate_selection(clipboard.selection, id_namespace, delta)?;

        let prefix = |kind: &str| format!("{kind}:copy-{id_namespace}:");
        let entities = staging
            .entities
            .iter()
            .filter(|item| item.id.starts_with(&prefix("entity")))
            .cloned()
            .collect::<Vec<_>>();
        let derived = staging
            .derived_elements
            .iter()
            .filter(|item| item.id.starts_with(&prefix("derived")))
            .cloned()
            .collect::<Vec<_>>();
        let free_texts = staging
            .free_texts
            .iter()
            .filter(|item| item.id.starts_with(&prefix("free-text")))
            .cloned()
            .collect::<Vec<_>>();
        let round_holes = staging
            .round_holes
            .iter()
            .filter(|item| item.id.starts_with(&prefix("round-hole")))
            .cloned()
            .collect::<Vec<_>>();
        let constraints = staging
            .constraints
            .iter()
            .filter(|item| item.id.starts_with(&prefix("constraint")))
            .cloned()
            .collect::<Vec<_>>();
        let measurements = staging
            .measurement_annotations()
            .iter()
            .filter(|item| item.id.starts_with(&prefix("measurement")))
            .cloned()
            .collect::<Vec<_>>();
        let dimensions = staging
            .dimension_constraint_annotations()
            .iter()
            .filter(|item| item.constraint_id.starts_with(&prefix("constraint")))
            .cloned()
            .collect::<Vec<_>>();
        let stitches = staging
            .stitch_start_points
            .iter()
            .filter(|item| item.id.starts_with(&prefix("stitch")))
            .cloned()
            .collect::<Vec<_>>();

        let layer_ids = entities
            .iter()
            .filter_map(|item| item.layer_id.clone())
            .chain(derived.iter().filter_map(|item| item.layer_id.clone()))
            .collect::<BTreeSet<_>>();
        let style_ids = entities
            .iter()
            .filter_map(|item| item.style_id.clone())
            .chain(derived.iter().filter_map(|item| item.style_id.clone()))
            .collect::<BTreeSet<_>>();
        let parameter_ids = constraints
            .iter()
            .filter_map(|item| match &item.value {
                Some(ConstraintValue::Parameter(id)) => Some(id.clone()),
                _ => None,
            })
            .chain(derived.iter().filter_map(|item| match &item.kind {
                DerivedElementKind::OffsetCurve(offset) => match &offset.distance {
                    ConstraintValue::Parameter(id) => Some(id.clone()),
                    _ => None,
                },
                DerivedElementKind::Fillet(fillet) => match &fillet.radius {
                    ConstraintValue::Parameter(id) => Some(id.clone()),
                    _ => None,
                },
            }))
            .collect::<BTreeSet<_>>();

        for id in layer_ids {
            let source = staging
                .layers
                .iter()
                .find(|item| item.id == id)
                .cloned()
                .ok_or_else(|| {
                    CommandError::broken_reference("selection clipboard", "layer", id.clone())
                })?;
            match self.layers.iter().find(|item| item.id == id) {
                Some(existing) if existing != &source => {
                    return Err(library_dependency_conflict("layer"))
                }
                Some(_) => {}
                None => self.add_layer(source)?,
            }
        }
        for id in style_ids {
            let source = staging
                .shared_styles
                .iter()
                .find(|item| item.id == id)
                .cloned()
                .ok_or_else(|| {
                    CommandError::broken_reference(
                        "selection clipboard",
                        "shared style",
                        id.clone(),
                    )
                })?;
            match self.shared_styles.iter().find(|item| item.id == id) {
                Some(existing) if existing != &source => {
                    return Err(library_dependency_conflict("shared style"))
                }
                Some(_) => {}
                None => self.add_shared_style(source)?,
            }
        }
        for id in parameter_ids {
            let source = staging
                .parameters
                .iter()
                .find(|item| item.id == id)
                .cloned()
                .ok_or_else(|| {
                    CommandError::broken_reference("selection clipboard", "parameter", id.clone())
                })?;
            match self.parameters.iter().find(|item| item.id == id) {
                Some(existing) if existing != &source => {
                    return Err(library_dependency_conflict("parameter"))
                }
                Some(_) => {}
                None => self.add_parameter(source)?,
            }
        }

        for item in entities {
            self.add_entity(item)?;
        }
        for item in derived {
            self.add_derived_element(item)?;
        }
        for item in round_holes {
            self.add_round_hole(item)?;
        }
        for item in free_texts {
            self.add_free_text(item)?;
        }
        for item in constraints {
            self.add_constraint(item)?;
        }
        for item in measurements {
            self.add_measurement_annotation(item)?;
        }
        for item in dimensions {
            self.add_dimension_constraint_annotation(item)?;
        }
        for item in stitches {
            self.add_stitch_start_point(item)?;
        }
        Ok(())
    }

    pub(crate) fn duplicate_selection(
        &mut self,
        selection: SelectionReference,
        id_namespace: &str,
        delta: Point2,
    ) -> CommandResult {
        if id_namespace.trim().is_empty() {
            return Err(CommandError::EmptyId("duplicate namespace"));
        }
        if !delta.x_mm.is_finite() || !delta.y_mm.is_finite() {
            return Err(CommandError::InvalidValue {
                field: "duplicate delta",
                reason: "must be finite",
            });
        }

        let mut entity_ids = selection.entity_ids.into_iter().collect::<BTreeSet<_>>();
        let mut derived_ids = selection
            .derived_element_ids
            .into_iter()
            .collect::<BTreeSet<_>>();
        for constraint_id in &selection.constraint_ids {
            let constraint = self
                .constraints
                .iter()
                .find(|item| &item.id == constraint_id)
                .ok_or_else(|| CommandError::missing("constraint", constraint_id))?;
            for target in &constraint.targets {
                self.collect_duplicate_target_dependency(
                    constraint_target_entity_id(target),
                    &mut entity_ids,
                    &mut derived_ids,
                )?;
            }
        }
        for annotation_id in &selection.measurement_annotation_ids {
            let annotation = self
                .measurement_annotations()
                .iter()
                .find(|item| &item.id == annotation_id)
                .ok_or_else(|| CommandError::missing("measurement annotation", annotation_id))?;
            for target in &annotation.targets {
                self.collect_duplicate_target_dependency(
                    constraint_target_entity_id(target),
                    &mut entity_ids,
                    &mut derived_ids,
                )?;
            }
        }
        for stitch_id in &selection.stitch_start_point_ids {
            let stitch = self
                .stitch_start_points
                .iter()
                .find(|item| &item.id == stitch_id)
                .ok_or_else(|| CommandError::missing("stitch start point", stitch_id))?;
            self.collect_duplicate_target_dependency(
                &stitch.target_id,
                &mut entity_ids,
                &mut derived_ids,
            )?;
        }
        for text_id in &selection.free_text_ids {
            if !self.free_texts.iter().any(|item| &item.id == text_id) {
                return Err(CommandError::missing("free text", text_id));
            }
        }
        for id in entity_ids.clone() {
            if self.entity(&id).is_none() {
                return Err(CommandError::missing("entity", id));
            }
        }
        for id in derived_ids.clone() {
            self.collect_duplicate_source_closure(&id, &mut entity_ids, &mut derived_ids)?;
        }
        loop {
            let available = entity_ids
                .iter()
                .chain(derived_ids.iter())
                .cloned()
                .collect::<BTreeSet<_>>();
            let additions = self
                .derived_elements
                .iter()
                .filter(|derived| !derived_ids.contains(&derived.id))
                .filter(|derived| {
                    derived_element_source_ids(derived).all(|id| available.contains(id))
                })
                .map(|derived| derived.id.clone())
                .collect::<Vec<_>>();
            if additions.is_empty() {
                break;
            }
            derived_ids.extend(additions);
        }
        let available = entity_ids
            .iter()
            .chain(derived_ids.iter())
            .cloned()
            .collect::<BTreeSet<_>>();
        if available.is_empty()
            && selection.constraint_ids.is_empty()
            && selection.measurement_annotation_ids.is_empty()
            && selection.stitch_start_point_ids.is_empty()
            && selection.free_text_ids.is_empty()
        {
            return Err(CommandError::InvalidValue {
                field: "duplicate selection",
                reason: "selection must not be empty",
            });
        }

        let entity_map = entity_ids
            .iter()
            .map(|id| (id.clone(), duplicate_id("entity", id_namespace, id)))
            .collect::<BTreeMap<_, _>>();
        let derived_map = derived_ids
            .iter()
            .map(|id| (id.clone(), duplicate_id("derived", id_namespace, id)))
            .collect::<BTreeMap<_, _>>();

        for id in &entity_ids {
            let mut entity = self
                .entity(id)
                .cloned()
                .ok_or_else(|| CommandError::missing("entity", id))?;
            entity.id = entity_map[id].clone();
            translate_entity(&mut entity, delta);
            self.add_entity(entity)?;
        }
        for id in &derived_ids {
            let mut derived = self
                .derived_element(id)
                .cloned()
                .ok_or_else(|| CommandError::missing("derived element", id))?;
            derived.id = derived_map[id].clone();
            remap_derived_sources(&mut derived, &entity_map, &derived_map);
            self.add_derived_element(derived)?;
        }

        let explicit_constraints = selection
            .constraint_ids
            .into_iter()
            .collect::<BTreeSet<_>>();
        let constraints = self
            .constraints
            .iter()
            .filter(|constraint| !constraint.id.starts_with("constraint:implicit:"))
            .filter(|constraint| {
                explicit_constraints.contains(&constraint.id)
                    || constraint
                        .targets
                        .iter()
                        .all(|target| available.contains(constraint_target_entity_id(target)))
            })
            .cloned()
            .collect::<Vec<_>>();
        let mut constraint_map = BTreeMap::new();
        for mut constraint in constraints {
            if !constraint
                .targets
                .iter()
                .all(|target| available.contains(constraint_target_entity_id(target)))
            {
                return Err(CommandError::InvalidValue {
                    field: "duplicate selection",
                    reason: "selected constraint has a dependency outside the selection",
                });
            }
            let original_constraint_id = constraint.id.clone();
            constraint.id = duplicate_id("constraint", id_namespace, &constraint.id);
            constraint_map.insert(original_constraint_id, constraint.id.clone());
            constraint.targets = constraint
                .targets
                .into_iter()
                .map(|target| remap_target(target, &entity_map, &derived_map))
                .collect::<CommandResult<Vec<_>>>()?;
            constraint.status = ConstraintStatus::Unknown;
            self.add_constraint(constraint)?;
        }
        let dimension_annotations = self
            .dimension_constraint_annotations()
            .iter()
            .filter(|annotation| constraint_map.contains_key(&annotation.constraint_id))
            .cloned()
            .collect::<Vec<_>>();
        for mut annotation in dimension_annotations {
            annotation.constraint_id = constraint_map[&annotation.constraint_id].clone();
            self.add_dimension_constraint_annotation(annotation)?;
        }

        let explicit_measurements = selection
            .measurement_annotation_ids
            .into_iter()
            .collect::<BTreeSet<_>>();
        let measurements = self
            .measurement_annotations()
            .iter()
            .filter(|annotation| {
                explicit_measurements.contains(&annotation.id)
                    || annotation
                        .targets
                        .iter()
                        .all(|target| available.contains(constraint_target_entity_id(target)))
            })
            .cloned()
            .collect::<Vec<_>>();
        for mut annotation in measurements {
            if !annotation
                .targets
                .iter()
                .all(|target| available.contains(constraint_target_entity_id(target)))
            {
                return Err(CommandError::InvalidValue {
                    field: "duplicate selection",
                    reason: "selected measurement has a dependency outside the selection",
                });
            }
            annotation.id = duplicate_id("measurement", id_namespace, &annotation.id);
            annotation.targets = annotation
                .targets
                .into_iter()
                .map(|target| remap_target(target, &entity_map, &derived_map))
                .collect::<CommandResult<Vec<_>>>()?;
            self.add_measurement_annotation(annotation)?;
        }

        let selected_stitches = selection
            .stitch_start_point_ids
            .into_iter()
            .collect::<BTreeSet<_>>();
        let stitches = self
            .stitch_start_points
            .iter()
            .filter(|stitch| {
                selected_stitches.contains(&stitch.id) || available.contains(&stitch.target_id)
            })
            .cloned()
            .collect::<Vec<_>>();
        for mut stitch in stitches {
            stitch.id = duplicate_id("stitch", id_namespace, &stitch.id);
            stitch.target_id = entity_map
                .get(&stitch.target_id)
                .or_else(|| derived_map.get(&stitch.target_id))
                .cloned()
                .ok_or(CommandError::InvalidValue {
                    field: "duplicate selection",
                    reason: "stitch start point has a dependency outside the selection",
                })?;
            self.add_stitch_start_point(stitch)?;
        }

        let round_holes = self
            .round_holes
            .iter()
            .filter(|hole| entity_ids.contains(&hole.entity_id))
            .cloned()
            .collect::<Vec<_>>();
        for mut hole in round_holes {
            hole.id = duplicate_id("round-hole", id_namespace, &hole.id);
            hole.entity_id = entity_map[&hole.entity_id].clone();
            self.add_round_hole(hole)?;
        }

        let selected_texts = selection.free_text_ids.into_iter().collect::<BTreeSet<_>>();
        let texts = self
            .free_texts
            .iter()
            .filter(|text| selected_texts.contains(&text.id))
            .cloned()
            .collect::<Vec<_>>();
        for mut text in texts {
            text.id = duplicate_id("free-text", id_namespace, &text.id);
            text.position_mm.x_mm += delta.x_mm;
            text.position_mm.y_mm += delta.y_mm;
            self.add_free_text(text)?;
        }
        Ok(())
    }

    fn collect_duplicate_source_closure(
        &self,
        derived_id: &str,
        entity_ids: &mut BTreeSet<String>,
        derived_ids: &mut BTreeSet<String>,
    ) -> CommandResult {
        let derived = self
            .derived_element(derived_id)
            .ok_or_else(|| CommandError::missing("derived element", derived_id))?;
        for source_id in derived_element_source_ids(derived) {
            if self.entity(source_id).is_some() {
                entity_ids.insert(source_id.clone());
            } else if self.derived_element(source_id).is_some()
                && derived_ids.insert(source_id.clone())
            {
                self.collect_duplicate_source_closure(source_id, entity_ids, derived_ids)?;
            } else if self.derived_element(source_id).is_none() {
                return Err(CommandError::broken_reference(
                    "duplicate selection",
                    "source",
                    source_id,
                ));
            }
        }
        Ok(())
    }

    fn collect_duplicate_target_dependency(
        &self,
        target_id: &str,
        entity_ids: &mut BTreeSet<String>,
        derived_ids: &mut BTreeSet<String>,
    ) -> CommandResult {
        if self.entity(target_id).is_some() {
            entity_ids.insert(target_id.to_owned());
            return Ok(());
        }
        if self.derived_element(target_id).is_some() {
            if derived_ids.insert(target_id.to_owned()) {
                self.collect_duplicate_source_closure(target_id, entity_ids, derived_ids)?;
            }
            return Ok(());
        }
        Err(CommandError::broken_reference(
            "duplicate selection",
            "target",
            target_id,
        ))
    }

    pub(crate) fn place_stitch_start_point(
        &mut self,
        id: String,
        position: Point2,
        candidate_target_ids: Vec<String>,
        max_distance_mm: f64,
    ) -> CommandResult {
        if !position.x_mm.is_finite()
            || !position.y_mm.is_finite()
            || !max_distance_mm.is_finite()
            || max_distance_mm <= 0.0
        {
            return Err(CommandError::InvalidValue {
                field: "stitch start point placement",
                reason: "position and maximum distance must be finite",
            });
        }
        let candidates = self.stitch_line_candidates(&candidate_target_ids);
        let best = candidates
            .into_iter()
            .filter_map(|(target_id, resolved_index, entity)| {
                project_to_entity(position, &entity).map(|(position_ratio, distance_mm)| {
                    (target_id, resolved_index, position_ratio, distance_mm)
                })
            })
            .filter(|candidate| candidate.3 <= max_distance_mm)
            .min_by(|first, second| first.3.total_cmp(&second.3))
            .ok_or(CommandError::InvalidValue {
                field: "stitch start point placement",
                reason: "no stitch line is close enough",
            })?;
        self.add_stitch_start_point(StitchStartPoint::new(id, best.0, best.1, best.2))
    }

    fn stitch_line_candidates(
        &self,
        candidate_target_ids: &[String],
    ) -> Vec<(String, Option<usize>, Entity)> {
        let allows = |id: &str| {
            candidate_target_ids.is_empty()
                || candidate_target_ids.iter().any(|candidate| candidate == id)
        };
        let mut result = self
            .entities
            .iter()
            .filter(|entity| super::command_applier::ensure_stitch_target_entity(entity).is_ok())
            .filter(|entity| allows(&entity.id))
            .cloned()
            .map(|entity| (entity.id.clone(), None, entity))
            .collect::<Vec<_>>();
        for derived in &self.derived_elements {
            if !allows(&derived.id) {
                continue;
            }
            if let Ok(entities) = self.resolve_derived_element(derived) {
                result.extend(
                    entities
                        .into_iter()
                        .enumerate()
                        .filter(|(_, entity)| {
                            super::command_applier::ensure_stitch_target_entity(entity).is_ok()
                        })
                        .map(|(index, entity)| (derived.id.clone(), Some(index), entity)),
                );
            }
        }
        result
    }

    pub(crate) fn set_entity_metric(
        &mut self,
        entity_id: &str,
        metric: EntityMetric,
    ) -> CommandResult {
        let mut entity = self
            .entity(entity_id)
            .cloned()
            .ok_or_else(|| CommandError::missing("entity", entity_id.to_owned()))?;
        entity.kind = match (entity.kind, metric) {
            (EntityKind::LineSegment(line), EntityMetric::SegmentLength { value_mm }) => {
                EntityKind::LineSegment(line_with_length(line, value_mm)?)
            }
            (EntityKind::CenterLine(line), EntityMetric::SegmentLength { value_mm }) => {
                EntityKind::CenterLine(line_with_length(line, value_mm)?)
            }
            (EntityKind::Circle(mut circle), EntityMetric::CircleRadius { value_mm }) => {
                ensure_positive_metric(value_mm, "circle radius")?;
                circle.radius_mm = value_mm;
                EntityKind::Circle(circle)
            }
            (
                EntityKind::Arc(mut arc),
                EntityMetric::Arc {
                    radius_mm,
                    start_angle_rad,
                    sweep_angle_rad,
                },
            ) => {
                ensure_positive_metric(radius_mm, "arc radius")?;
                if !start_angle_rad.is_finite()
                    || !sweep_angle_rad.is_finite()
                    || sweep_angle_rad.abs() <= f64::EPSILON
                {
                    return Err(CommandError::InvalidValue {
                        field: "arc metric",
                        reason: "angles must be finite and sweep must not be zero",
                    });
                }
                arc.radius_mm = radius_mm;
                arc.start_angle_rad = start_angle_rad;
                arc.sweep_angle_rad = sweep_angle_rad;
                EntityKind::Arc(arc)
            }
            (
                EntityKind::Arc(mut arc),
                EntityMetric::ArcUpdate {
                    radius_mm,
                    start_angle_rad,
                    sweep_angle_rad,
                },
            ) => {
                if radius_mm.is_none() && start_angle_rad.is_none() && sweep_angle_rad.is_none() {
                    return Err(CommandError::InvalidValue {
                        field: "arc metric",
                        reason: "must update at least one value",
                    });
                }
                if let Some(radius_mm) = radius_mm {
                    ensure_positive_metric(radius_mm, "arc radius")?;
                    arc.radius_mm = radius_mm;
                }
                if let Some(start_angle_rad) = start_angle_rad {
                    if !start_angle_rad.is_finite() {
                        return Err(CommandError::InvalidValue {
                            field: "arc metric",
                            reason: "angles must be finite",
                        });
                    }
                    arc.start_angle_rad = start_angle_rad;
                }
                if let Some(sweep_angle_rad) = sweep_angle_rad {
                    if !sweep_angle_rad.is_finite() || sweep_angle_rad.abs() <= f64::EPSILON {
                        return Err(CommandError::InvalidValue {
                            field: "arc metric",
                            reason: "sweep must be finite and non-zero",
                        });
                    }
                    arc.sweep_angle_rad = sweep_angle_rad;
                }
                EntityKind::Arc(arc)
            }
            _ => {
                return Err(CommandError::InvalidValue {
                    field: "entity metric",
                    reason: "metric is incompatible with entity kind",
                });
            }
        };
        self.update_entity(entity)
    }

    pub(crate) fn smooth_arc_tangencies(&mut self, arc_entity_id: &str) -> CommandResult {
        let inputs = self.smooth_inputs(arc_entity_id)?;
        let solution = smooth_candidates(&inputs)
            .into_iter()
            .max_by(|first, second| first.score.total_cmp(&second.score))
            .ok_or(CommandError::InvalidValue {
                field: "smooth arc tangencies",
                reason: "no valid tangent solution",
            })?;

        let affected_targets = [
            control_target(&inputs.arc.id, ControlPointKind::Start),
            control_target(&inputs.arc.id, ControlPointKind::End),
            control_target(
                &inputs.start_line.entity.id,
                inputs.start_line.connected_point,
            ),
            control_target(&inputs.end_line.entity.id, inputs.end_line.connected_point),
        ];
        self.constraints.retain(|constraint| {
            constraint.kind != ConstraintKind::Fixed
                || !constraint
                    .targets
                    .iter()
                    .any(|target| affected_targets.contains(target))
        });

        let mut updated_arc = inputs.arc.clone();
        updated_arc.kind = EntityKind::Arc(Arc {
            center: solution.center,
            radius_mm: solution.radius,
            start_angle_rad: solution.start_angle,
            sweep_angle_rad: solution.sweep_angle,
        });
        self.update_entity(updated_arc)?;
        self.update_entity(updated_tangency_line(
            &inputs.start_line,
            solution.start_point,
        ))?;
        if inputs.end_line.entity.id != inputs.start_line.entity.id {
            self.update_entity(updated_tangency_line(&inputs.end_line, solution.end_point))?;
        }
        self.add_tangent_if_missing(
            &inputs.start_line.entity.id,
            inputs.start_line.connected_point,
            arc_entity_id,
            ControlPointKind::Start,
            "start",
        )?;
        self.add_tangent_if_missing(
            &inputs.end_line.entity.id,
            inputs.end_line.connected_point,
            arc_entity_id,
            ControlPointKind::End,
            "end",
        )
    }

    fn smooth_inputs(&self, arc_entity_id: &str) -> CommandResult<SmoothInputs> {
        let arc_entity = self
            .entity(arc_entity_id)
            .cloned()
            .ok_or_else(|| CommandError::missing("entity", arc_entity_id.to_owned()))?;
        let EntityKind::Arc(arc) = arc_entity.kind else {
            return Err(CommandError::InvalidValue {
                field: "smooth arc tangencies",
                reason: "selected entity must be an arc",
            });
        };
        let start_line = self.tangency_connection(arc_entity_id, ControlPointKind::Start)?;
        let end_line = self.tangency_connection(arc_entity_id, ControlPointKind::End)?;
        Ok(SmoothInputs {
            arc: arc_entity,
            current_center: arc.center,
            current_radius_mm: arc.radius_mm,
            current_sweep_angle_rad: arc.sweep_angle_rad,
            start_line,
            end_line,
        })
    }

    fn tangency_connection(
        &self,
        arc_entity_id: &str,
        arc_point: ControlPointKind,
    ) -> CommandResult<TangencyLineConnection> {
        let arc_target = control_target(arc_entity_id, arc_point);
        for constraint in &self.constraints {
            if constraint.kind != ConstraintKind::Coincident
                || !constraint.targets.contains(&arc_target)
            {
                continue;
            }
            for target in &constraint.targets {
                let ConstraintTarget::ControlPoint { entity_id, point } = target else {
                    continue;
                };
                if entity_id == arc_entity_id
                    || !matches!(point, ControlPointKind::Start | ControlPointKind::End)
                {
                    continue;
                }
                let entity = self.entity(entity_id).cloned().ok_or_else(|| {
                    CommandError::broken_reference("smooth arc tangencies", "entity", entity_id)
                })?;
                let (line, center_line) = match entity.kind {
                    EntityKind::LineSegment(line) => (line, false),
                    EntityKind::CenterLine(line) => (line, true),
                    _ => continue,
                };
                let (anchor, connected) = match point {
                    ControlPointKind::Start => (line.end, line.start),
                    ControlPointKind::End => (line.start, line.end),
                    ControlPointKind::Center => continue,
                };
                let direction =
                    normalized(connected.x_mm - anchor.x_mm, connected.y_mm - anchor.y_mm).ok_or(
                        CommandError::InvalidValue {
                            field: "smooth arc tangencies",
                            reason: "connected line must have a direction",
                        },
                    )?;
                return Ok(TangencyLineConnection {
                    entity,
                    connected_point: *point,
                    anchor,
                    original_connected_point: connected,
                    direction_from_anchor: direction,
                    center_line,
                });
            }
        }
        Err(CommandError::InvalidValue {
            field: "smooth arc tangencies",
            reason: "arc endpoint must be coincident with a line endpoint",
        })
    }

    fn add_tangent_if_missing(
        &mut self,
        line_id: &str,
        line_point: ControlPointKind,
        arc_id: &str,
        arc_point: ControlPointKind,
        suffix: &str,
    ) -> CommandResult {
        let targets = vec![
            control_target(line_id, line_point),
            control_target(arc_id, arc_point),
        ];
        if self.constraints.iter().any(|constraint| {
            constraint.kind == ConstraintKind::Tangent
                && constraint.targets.len() == targets.len()
                && constraint
                    .targets
                    .iter()
                    .all(|target| targets.contains(target))
        }) {
            return Ok(());
        }
        self.add_constraint(Constraint {
            id: format!("constraint:tangent:{arc_id}:{suffix}"),
            kind: ConstraintKind::Tangent,
            targets,
            value: None,
            status: ConstraintStatus::Unknown,
        })
    }
}

fn library_dependency_conflict(kind: &'static str) -> CommandError {
    CommandError::InvalidValue {
        field: kind,
        reason: "clipboard dependency conflicts with the target project",
    }
}

impl SelectionBounds {
    fn center(self) -> Point2 {
        Point2::new(
            (self.min_point.x_mm + self.max_point.x_mm) * 0.5,
            (self.min_point.y_mm + self.max_point.y_mm) * 0.5,
        )
    }
}

fn selection_bounds(
    document: &ProjectDocument,
    selection: &SelectionReference,
) -> Option<SelectionBounds> {
    let mut entity_ids = selection
        .entity_ids
        .iter()
        .cloned()
        .collect::<BTreeSet<_>>();
    let mut derived_ids = selection
        .derived_element_ids
        .iter()
        .cloned()
        .collect::<BTreeSet<_>>();
    let mut include_target = |target_id: &str| {
        if document.entity(target_id).is_some() {
            entity_ids.insert(target_id.to_owned());
        } else if document.derived_element(target_id).is_some() {
            derived_ids.insert(target_id.to_owned());
        }
    };
    for constraint_id in &selection.constraint_ids {
        if let Some(constraint) = document
            .constraints
            .iter()
            .find(|item| &item.id == constraint_id)
        {
            for target in &constraint.targets {
                include_target(constraint_target_entity_id(target));
            }
        }
    }
    for annotation_id in &selection.measurement_annotation_ids {
        if let Some(annotation) = document
            .measurement_annotations()
            .iter()
            .find(|item| &item.id == annotation_id)
        {
            for target in &annotation.targets {
                include_target(constraint_target_entity_id(target));
            }
        }
    }
    for stitch_id in &selection.stitch_start_point_ids {
        if let Some(stitch) = document
            .stitch_start_points
            .iter()
            .find(|item| &item.id == stitch_id)
        {
            include_target(&stitch.target_id);
        }
    }
    let mut points = entity_ids
        .iter()
        .filter_map(|id| document.entity(id))
        .flat_map(entity_bounds_points)
        .collect::<Vec<_>>();
    for id in &derived_ids {
        let Some(derived) = document.derived_element(id) else {
            continue;
        };
        if let Ok(resolved) = document.resolve_derived_element(derived) {
            points.extend(resolved.iter().flat_map(entity_bounds_points));
        }
    }
    points.extend(
        selection
            .free_text_ids
            .iter()
            .filter_map(|id| document.free_texts.iter().find(|item| &item.id == id))
            .map(|item| item.position_mm),
    );
    let first = points.first().copied()?;
    Some(SelectionBounds {
        min_point: Point2::new(
            points
                .iter()
                .map(|point| point.x_mm)
                .fold(first.x_mm, f64::min),
            points
                .iter()
                .map(|point| point.y_mm)
                .fold(first.y_mm, f64::min),
        ),
        max_point: Point2::new(
            points
                .iter()
                .map(|point| point.x_mm)
                .fold(first.x_mm, f64::max),
            points
                .iter()
                .map(|point| point.y_mm)
                .fold(first.y_mm, f64::max),
        ),
    })
}

fn entity_bounds_points(entity: &Entity) -> Vec<Point2> {
    match entity.kind {
        EntityKind::Point(point) => vec![point],
        EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => vec![line.start, line.end],
        EntityKind::Circle(circle) => vec![
            Point2::new(
                circle.center.x_mm - circle.radius_mm,
                circle.center.y_mm - circle.radius_mm,
            ),
            Point2::new(
                circle.center.x_mm + circle.radius_mm,
                circle.center.y_mm + circle.radius_mm,
            ),
        ],
        EntityKind::Arc(arc) => {
            let mut points = vec![
                point_on_semantic_arc(arc, 0.0),
                point_on_semantic_arc(arc, 1.0),
            ];
            for angle in [
                0.0,
                std::f64::consts::FRAC_PI_2,
                std::f64::consts::PI,
                std::f64::consts::FRAC_PI_2 * 3.0,
            ] {
                if arc_contains_angle(arc.start_angle_rad, arc.sweep_angle_rad, angle) {
                    points.push(Point2::new(
                        arc.center.x_mm + arc.radius_mm * angle.cos(),
                        arc.center.y_mm + arc.radius_mm * angle.sin(),
                    ));
                }
            }
            points
        }
    }
}

fn arc_contains_angle(start_angle_rad: f64, sweep_angle_rad: f64, target_angle_rad: f64) -> bool {
    if sweep_angle_rad.abs() >= std::f64::consts::TAU {
        return true;
    }
    if sweep_angle_rad >= 0.0 {
        (target_angle_rad - start_angle_rad).rem_euclid(std::f64::consts::TAU)
            <= sweep_angle_rad + GEOMETRY_EPSILON_MM
    } else {
        (start_angle_rad - target_angle_rad).rem_euclid(std::f64::consts::TAU)
            <= -sweep_angle_rad + GEOMETRY_EPSILON_MM
    }
}

fn point_on_semantic_arc(arc: Arc, ratio: f64) -> Point2 {
    let angle = arc.start_angle_rad + arc.sweep_angle_rad * ratio;
    Point2::new(
        arc.center.x_mm + arc.radius_mm * angle.cos(),
        arc.center.y_mm + arc.radius_mm * angle.sin(),
    )
}

pub(super) fn duplicate_id(kind: &str, namespace: &str, original: &str) -> String {
    format!("{kind}:copy-{namespace}:{original}")
}

fn translate_entity(entity: &mut Entity, delta: Point2) {
    let translate = |point: &mut Point2| {
        point.x_mm += delta.x_mm;
        point.y_mm += delta.y_mm;
    };
    match &mut entity.kind {
        EntityKind::Point(point) => translate(point),
        EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => {
            translate(&mut line.start);
            translate(&mut line.end);
        }
        EntityKind::Circle(circle) => translate(&mut circle.center),
        EntityKind::Arc(arc) => translate(&mut arc.center),
    }
}

fn remap_derived_sources(
    derived: &mut DerivedElement,
    entity_map: &BTreeMap<String, String>,
    derived_map: &BTreeMap<String, String>,
) {
    if let DerivedElementKind::OffsetCurve(offset) = &mut derived.kind {
        for (old_id, new_id) in derived_map {
            let old_prefix = format!("{old_id}:resolved:");
            let new_prefix = format!("{new_id}:resolved:");
            for resolved_id in &mut offset.source_resolved_entity_ids {
                if let Some(suffix) = resolved_id.strip_prefix(&old_prefix) {
                    *resolved_id = format!("{new_prefix}{suffix}");
                }
            }
        }
    }
    let source_ids = match &mut derived.kind {
        DerivedElementKind::OffsetCurve(offset) => &mut offset.source_entity_ids,
        DerivedElementKind::Fillet(fillet) => &mut fillet.source_entity_ids,
    };
    for source_id in source_ids {
        if let Some(new_id) = entity_map
            .get(source_id)
            .or_else(|| derived_map.get(source_id))
        {
            *source_id = new_id.clone();
        }
    }
}

fn remap_target(
    target: ConstraintTarget,
    entity_map: &BTreeMap<String, String>,
    derived_map: &BTreeMap<String, String>,
) -> CommandResult<ConstraintTarget> {
    match target {
        ConstraintTarget::Entity(id) => entity_map
            .get(&id)
            .or_else(|| derived_map.get(&id))
            .cloned()
            .map(ConstraintTarget::Entity)
            .ok_or(CommandError::InvalidValue {
                field: "duplicate selection",
                reason: "target has a dependency outside the selection",
            }),
        ConstraintTarget::ControlPoint { entity_id, point } => entity_map
            .get(&entity_id)
            .or_else(|| derived_map.get(&entity_id))
            .cloned()
            .map(|entity_id| ConstraintTarget::ControlPoint { entity_id, point })
            .ok_or(CommandError::InvalidValue {
                field: "duplicate selection",
                reason: "control point has a dependency outside the selection",
            }),
    }
}

fn project_to_entity(point: Point2, entity: &Entity) -> Option<(f64, f64)> {
    match entity.kind {
        EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => {
            let dx = line.end.x_mm - line.start.x_mm;
            let dy = line.end.y_mm - line.start.y_mm;
            let length_squared = dx * dx + dy * dy;
            if length_squared <= GEOMETRY_EPSILON_MM * GEOMETRY_EPSILON_MM {
                return None;
            }
            let raw = ((point.x_mm - line.start.x_mm) * dx + (point.y_mm - line.start.y_mm) * dy)
                / length_squared;
            let ratio = raw.clamp(0.0, 1.0);
            let projected = Point2::new(line.start.x_mm + dx * ratio, line.start.y_mm + dy * ratio);
            Some((ratio, distance(point, projected)))
        }
        EntityKind::Arc(arc) => {
            if arc.radius_mm <= GEOMETRY_EPSILON_MM || arc.sweep_angle_rad.abs() <= f64::EPSILON {
                return None;
            }
            let angle = (point.y_mm - arc.center.y_mm).atan2(point.x_mm - arc.center.x_mm);
            let sweep = if arc.sweep_angle_rad > 0.0 {
                (angle - arc.start_angle_rad).rem_euclid(std::f64::consts::TAU)
            } else {
                (arc.start_angle_rad - angle).rem_euclid(std::f64::consts::TAU)
            };
            let ratio =
                (sweep.min(arc.sweep_angle_rad.abs()) / arc.sweep_angle_rad.abs()).clamp(0.0, 1.0);
            let target_angle = arc.start_angle_rad + arc.sweep_angle_rad * ratio;
            let projected = Point2::new(
                arc.center.x_mm + arc.radius_mm * target_angle.cos(),
                arc.center.y_mm + arc.radius_mm * target_angle.sin(),
            );
            Some((ratio, distance(point, projected)))
        }
        _ => None,
    }
}

fn ensure_positive_metric(value: f64, field: &'static str) -> CommandResult {
    if value.is_finite() && value > GEOMETRY_EPSILON_MM {
        Ok(())
    } else {
        Err(CommandError::InvalidValue {
            field,
            reason: "must be a positive finite value",
        })
    }
}

fn line_with_length(line: LineSegment, value_mm: f64) -> CommandResult<LineSegment> {
    ensure_positive_metric(value_mm, "segment length")?;
    let current = line.length_mm();
    if current <= GEOMETRY_EPSILON_MM {
        return Err(CommandError::InvalidValue {
            field: "segment length",
            reason: "cannot resize a degenerate line",
        });
    }
    let scale = value_mm / current;
    Ok(LineSegment::new(
        line.start,
        Point2::new(
            line.start.x_mm + (line.end.x_mm - line.start.x_mm) * scale,
            line.start.y_mm + (line.end.y_mm - line.start.y_mm) * scale,
        ),
    ))
}

fn control_target(entity_id: &str, point: ControlPointKind) -> ConstraintTarget {
    ConstraintTarget::ControlPoint {
        entity_id: entity_id.to_owned(),
        point,
    }
}

fn updated_tangency_line(connection: &TangencyLineConnection, connected: Point2) -> Entity {
    let line = match connection.connected_point {
        ControlPointKind::Start => LineSegment::new(connected, connection.anchor),
        ControlPointKind::End => LineSegment::new(connection.anchor, connected),
        ControlPointKind::Center => return connection.entity.clone(),
    };
    let mut entity = connection.entity.clone();
    entity.kind = if connection.center_line {
        EntityKind::CenterLine(line)
    } else {
        EntityKind::LineSegment(line)
    };
    entity
}

fn smooth_candidates(inputs: &SmoothInputs) -> Vec<SmoothCandidate> {
    let start_normal = left_normal(inputs.start_line.direction_from_anchor);
    let end_normal = left_normal(inputs.end_line.direction_from_anchor);
    [1.0, -1.0]
        .into_iter()
        .flat_map(|end_sign| candidate_centers(inputs, start_normal, end_normal, end_sign))
        .collect()
}

fn candidate_centers(
    inputs: &SmoothInputs,
    start_normal: Vector,
    end_normal: Vector,
    end_sign: f64,
) -> Vec<SmoothCandidate> {
    let equation_normal = subtract(start_normal, multiply(end_normal, end_sign));
    let length_squared = dot_vectors(equation_normal, equation_normal);
    if length_squared <= 1.0e-9 {
        return Vec::new();
    }
    let offset = dot_point(start_normal, inputs.start_line.anchor)
        - end_sign * dot_point(end_normal, inputs.end_line.anchor);
    let delta = (dot_point(equation_normal, inputs.current_center) - offset) / length_squared;
    let center = Point2::new(
        inputs.current_center.x_mm - equation_normal.x * delta,
        inputs.current_center.y_mm - equation_normal.y * delta,
    );
    arc_direction_candidates(inputs, center, start_normal, end_normal)
}

fn arc_direction_candidates(
    inputs: &SmoothInputs,
    center: Point2,
    start_normal: Vector,
    end_normal: Vector,
) -> Vec<SmoothCandidate> {
    let start_distance = signed_distance(center, &inputs.start_line, start_normal);
    let end_distance = signed_distance(center, &inputs.end_line, end_normal);
    let radius = start_distance.abs();
    if radius <= 1.0e-6 || (end_distance.abs() - radius).abs() >= 1.0e-5 {
        return Vec::new();
    }
    let start_point = foot_point(center, start_normal, start_distance);
    let end_point = foot_point(center, end_normal, end_distance);
    if !point_is_ahead(
        start_point,
        inputs.start_line.anchor,
        inputs.start_line.direction_from_anchor,
    ) || !point_is_ahead(
        end_point,
        inputs.end_line.anchor,
        inputs.end_line.direction_from_anchor,
    ) {
        return Vec::new();
    }
    let start_angle = (start_point.y_mm - center.y_mm).atan2(start_point.x_mm - center.x_mm);
    let end_angle = (end_point.y_mm - center.y_mm).atan2(end_point.x_mm - center.x_mm);
    let positive = normalized_positive_angle(end_angle - start_angle);
    let negative = -normalized_positive_angle(start_angle - end_angle);
    [positive, negative]
        .into_iter()
        .filter_map(|sweep| {
            if sweep.abs() <= 1.0e-6 || (sweep.abs() - std::f64::consts::TAU).abs() <= 1.0e-6 {
                return None;
            }
            let score = tangency_score(inputs, center, start_point, end_point, sweep);
            (score > 0.2).then_some(SmoothCandidate {
                center,
                start_point,
                end_point,
                radius,
                start_angle,
                sweep_angle: sweep,
                score,
            })
        })
        .collect()
}

fn tangency_score(
    inputs: &SmoothInputs,
    center: Point2,
    start_point: Point2,
    end_point: Point2,
    sweep: f64,
) -> f64 {
    let Some(start_radius) = normalized(
        start_point.x_mm - center.x_mm,
        start_point.y_mm - center.y_mm,
    ) else {
        return f64::NEG_INFINITY;
    };
    let Some(end_radius) = normalized(end_point.x_mm - center.x_mm, end_point.y_mm - center.y_mm)
    else {
        return f64::NEG_INFINITY;
    };
    let start_tangent = tangent(start_radius, sweep);
    let end_tangent = tangent(end_radius, sweep);
    let alignment = dot_vectors(start_tangent, inputs.start_line.direction_from_anchor)
        + dot_vectors(
            end_tangent,
            multiply(inputs.end_line.direction_from_anchor, -1.0),
        );
    alignment
        - 0.02 * distance(center, inputs.current_center)
        - 0.01
            * (distance(start_point, inputs.start_line.original_connected_point)
                + distance(end_point, inputs.end_line.original_connected_point))
        - 0.005 * (distance(start_point, center) - inputs.current_radius_mm).abs()
        - 0.05 * shortest_angle_difference(sweep, inputs.current_sweep_angle_rad).abs()
}

fn normalized(dx: f64, dy: f64) -> Option<Vector> {
    let length = dx.hypot(dy);
    (length > 1.0e-9 && length.is_finite()).then_some(Vector {
        x: dx / length,
        y: dy / length,
    })
}

fn left_normal(vector: Vector) -> Vector {
    Vector {
        x: -vector.y,
        y: vector.x,
    }
}
fn multiply(vector: Vector, scale: f64) -> Vector {
    Vector {
        x: vector.x * scale,
        y: vector.y * scale,
    }
}
fn subtract(lhs: Vector, rhs: Vector) -> Vector {
    Vector {
        x: lhs.x - rhs.x,
        y: lhs.y - rhs.y,
    }
}
fn dot_point(vector: Vector, point: Point2) -> f64 {
    vector.x * point.x_mm + vector.y * point.y_mm
}
fn dot_vectors(lhs: Vector, rhs: Vector) -> f64 {
    lhs.x * rhs.x + lhs.y * rhs.y
}
fn distance(lhs: Point2, rhs: Point2) -> f64 {
    (lhs.x_mm - rhs.x_mm).hypot(lhs.y_mm - rhs.y_mm)
}
fn signed_distance(point: Point2, line: &TangencyLineConnection, normal: Vector) -> f64 {
    dot_point(normal, point) - dot_point(normal, line.anchor)
}
fn foot_point(point: Point2, normal: Vector, signed_distance: f64) -> Point2 {
    Point2::new(
        point.x_mm - normal.x * signed_distance,
        point.y_mm - normal.y * signed_distance,
    )
}
fn point_is_ahead(point: Point2, anchor: Point2, direction: Vector) -> bool {
    (point.x_mm - anchor.x_mm) * direction.x + (point.y_mm - anchor.y_mm) * direction.y > 1.0e-6
}
fn tangent(radius: Vector, sweep: f64) -> Vector {
    if sweep >= 0.0 {
        Vector {
            x: -radius.y,
            y: radius.x,
        }
    } else {
        Vector {
            x: radius.y,
            y: -radius.x,
        }
    }
}
fn normalized_positive_angle(angle: f64) -> f64 {
    angle.rem_euclid(std::f64::consts::TAU)
}
fn shortest_angle_difference(lhs: f64, rhs: f64) -> f64 {
    let value = (lhs - rhs).rem_euclid(std::f64::consts::TAU);
    if value > std::f64::consts::PI {
        value - std::f64::consts::TAU
    } else {
        value
    }
}
