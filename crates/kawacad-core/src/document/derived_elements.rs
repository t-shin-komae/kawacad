use super::*;
use crate::derived::{
    distance_is_effectively_zero, resolved_entity_id, Fillet, OffsetCurve, OffsetDirection,
};
use crate::geometry::EntityId;
use crate::snapshot::DrawingEntityMetadata;

impl ProjectDocument {
    pub(in crate::document) fn validate_derived_element(
        &self,
        derived_element: &DerivedElement,
    ) -> CommandResult {
        ensure_non_empty_id("derived element", &derived_element.id)?;
        if let Some(layer_id) = &derived_element.layer_id {
            self.ensure_layer_exists("derived element", layer_id)?;
        }
        if let Some(style_id) = &derived_element.style_id {
            self.ensure_shared_style_exists("derived element", style_id)?;
        }
        let source_ids = derived_element_source_ids(derived_element);
        match &derived_element.kind {
            DerivedElementKind::OffsetCurve(offset_curve) => {
                offset_curve
                    .validate_shape()
                    .map_err(|_| CommandError::InvalidValue {
                        field: "derived element",
                        reason: "invalid offset curve",
                    })?;
                if let ConstraintValue::Parameter(parameter_id) = &offset_curve.distance {
                    self.ensure_parameter_exists("derived element", parameter_id)?;
                }
            }
            DerivedElementKind::Fillet(fillet) => {
                fillet
                    .validate_shape()
                    .map_err(|_| CommandError::InvalidValue {
                        field: "derived element",
                        reason: "invalid fillet",
                    })?;
                if let ConstraintValue::Parameter(parameter_id) = &fillet.radius {
                    self.ensure_parameter_exists("derived element", parameter_id)?;
                }
            }
        }
        for source_id in source_ids {
            if source_id == &derived_element.id {
                return Err(CommandError::InvalidValue {
                    field: "derived element",
                    reason: "must not reference itself",
                });
            }
            if self.entity(source_id).is_none() && self.derived_element(source_id).is_none() {
                return Err(CommandError::broken_reference(
                    "derived element",
                    "source",
                    source_id,
                ));
            }
        }
        self.ensure_derived_element_is_acyclic(&derived_element.id)?;
        Ok(())
    }

    pub(crate) fn resolved_entities(&self) -> Vec<Entity> {
        let mut entities = self.entities.clone();
        for derived_element in &self.derived_elements {
            if !derived_element_is_visible(self, derived_element) {
                continue;
            }
            if let Ok(mut resolved) = self.resolve_derived_element(derived_element) {
                entities.append(&mut resolved);
            }
        }
        entities
    }

    pub(crate) fn output_entities(&self) -> Vec<Entity> {
        let suppressed_source_ids = self.output_suppressed_fillet_source_ids();
        let mut entities = self
            .entities
            .iter()
            .filter(|entity| self.entity_is_output_visible(entity))
            .filter(|entity| !suppressed_source_ids.contains(&entity.id))
            .cloned()
            .collect::<Vec<_>>();
        for derived_element in &self.derived_elements {
            if !derived_element_is_output_visible(self, derived_element) {
                continue;
            }
            if let Ok(mut resolved) = self.resolve_derived_element(derived_element) {
                entities.append(&mut resolved);
            }
        }
        entities
    }

    fn output_suppressed_fillet_source_ids(&self) -> BTreeSet<String> {
        self.derived_elements
            .iter()
            .filter(|derived_element| {
                matches!(derived_element.kind, DerivedElementKind::Fillet(_))
                    && derived_element_is_output_visible(self, derived_element)
                    && self.resolve_derived_element(derived_element).is_ok()
            })
            .flat_map(|derived_element| derived_element_source_ids(derived_element).cloned())
            .filter(|source_id| self.entity(source_id).is_some())
            .collect()
    }

    pub(in crate::document) fn prune_unresolvable_derived_elements(&mut self) {
        let mut removed_ids = BTreeSet::new();
        loop {
            let invalid_ids = self
                .derived_elements
                .iter()
                .filter(|derived_element| self.resolve_derived_element(derived_element).is_err())
                .map(|derived_element| derived_element.id.clone())
                .collect::<Vec<_>>();
            if invalid_ids.is_empty() {
                break;
            }
            for id in &invalid_ids {
                removed_ids.insert(id.clone());
                self.collect_dependent_derived_element_ids(id, &mut removed_ids);
            }
            self.derived_elements
                .retain(|derived_element| !removed_ids.contains(&derived_element.id));
        }
        self.push_removed_derived_warnings(removed_ids);
    }

    pub(in crate::document) fn resolve_derived_element(
        &self,
        derived_element: &DerivedElement,
    ) -> CommandResult<Vec<Entity>> {
        self.resolve_derived_element_with_stack(derived_element, &mut Vec::new())
    }

    fn resolve_derived_element_with_stack(
        &self,
        derived_element: &DerivedElement,
        stack: &mut Vec<String>,
    ) -> CommandResult<Vec<Entity>> {
        if stack.iter().any(|id| id == &derived_element.id) {
            return Err(CommandError::InvalidValue {
                field: "derived element",
                reason: "cyclic derived element dependency is not allowed",
            });
        }
        stack.push(derived_element.id.clone());
        let result = match &derived_element.kind {
            DerivedElementKind::OffsetCurve(offset_curve) => {
                self.resolve_offset_curve(derived_element, offset_curve, stack)
            }
            DerivedElementKind::Fillet(fillet) => {
                self.resolve_fillet(derived_element, fillet, stack)
            }
        };
        stack.pop();
        result
    }

    fn resolve_offset_curve(
        &self,
        derived_element: &DerivedElement,
        offset_curve: &OffsetCurve,
        stack: &mut Vec<String>,
    ) -> CommandResult<Vec<Entity>> {
        let distance_mm = resolve_length_value_mm(
            &self.parameters,
            Some(&offset_curve.distance),
            "offset distance",
        )?;
        if distance_is_effectively_zero(distance_mm) {
            return Err(CommandError::InvalidValue {
                field: "offset distance",
                reason: "must be greater than zero",
            });
        }

        let source_entities = if offset_curve.source_resolved_entity_ids.is_empty() {
            let mut sources = Vec::new();
            for source_id in &offset_curve.source_entity_ids {
                if let Some(source) = self.entity(source_id) {
                    sources.push(source.clone());
                    continue;
                }
                let source_derived_element = self.derived_element(source_id).ok_or_else(|| {
                    CommandError::broken_reference("derived element", "source", source_id)
                })?;
                sources.extend(
                    self.resolve_derived_element_with_stack(source_derived_element, stack)?,
                );
            }
            sources
        } else {
            let source_id = &offset_curve.source_entity_ids[0];
            let source_derived_element = self.derived_element(source_id).ok_or_else(|| {
                CommandError::broken_reference("derived element", "source", source_id)
            })?;
            let resolved =
                self.resolve_derived_element_with_stack(source_derived_element, stack)?;
            offset_curve
                .source_resolved_entity_ids
                .iter()
                .map(|resolved_id| {
                    resolved
                        .iter()
                        .find(|entity| &entity.id == resolved_id)
                        .cloned()
                        .ok_or_else(|| {
                            CommandError::broken_reference(
                                "resolved derived entity",
                                "source",
                                resolved_id,
                            )
                        })
                })
                .collect::<CommandResult<Vec<_>>>()?
        };

        offset_entities_for_sources(
            &derived_element.id,
            derived_element.layer_id.clone(),
            derived_element.style_id.clone(),
            &source_entities,
            distance_mm,
            offset_curve.direction,
        )
    }

    fn resolve_fillet(
        &self,
        derived_element: &DerivedElement,
        fillet: &Fillet,
        stack: &mut Vec<String>,
    ) -> CommandResult<Vec<Entity>> {
        let radius_mm =
            resolve_length_value_mm(&self.parameters, Some(&fillet.radius), "fillet radius")?;
        if distance_is_effectively_zero(radius_mm) {
            return Err(CommandError::InvalidValue {
                field: "fillet radius",
                reason: "must be greater than zero",
            });
        }

        let mut source_entities = Vec::new();
        for source_id in &fillet.source_entity_ids {
            if let Some(source) = self.entity(source_id) {
                source_entities.push(source.clone());
                continue;
            }
            let source_derived_element = self.derived_element(source_id).ok_or_else(|| {
                CommandError::broken_reference("derived element", "source", source_id)
            })?;
            source_entities
                .extend(self.resolve_derived_element_with_stack(source_derived_element, stack)?);
        }

        fillet_entities_for_sources(
            &derived_element.id,
            derived_element.layer_id.clone(),
            derived_element.style_id.clone(),
            &source_entities,
            radius_mm,
            fillet.closed,
        )
    }

    pub(crate) fn add_derived_element(&mut self, derived_element: DerivedElement) -> CommandResult {
        self.validate_derived_element(&derived_element)?;
        ensure_unique_id(
            self.derived_elements
                .iter()
                .map(|existing| existing.id.as_str()),
            "derived element",
            &derived_element.id,
        )?;
        self.resolve_derived_element(&derived_element)?;
        let derived_element_id = derived_element.id.clone();
        let mut candidate = self.clone();
        candidate.derived_elements.push(derived_element);
        candidate.ensure_fillet_sources_are_unique()?;
        self.derived_elements = candidate.store.derived_elements;
        self.auto_assign_derived_element_to_part(&derived_element_id);
        Ok(())
    }

    pub(crate) fn update_derived_element(
        &mut self,
        derived_element: DerivedElement,
    ) -> CommandResult {
        let index = self
            .derived_elements
            .iter()
            .position(|existing| existing.id == derived_element.id)
            .ok_or_else(|| CommandError::missing("derived element", derived_element.id.clone()))?;
        let mut candidate = self.clone();
        candidate.derived_elements[index] = derived_element;
        let candidate_derived_element = &candidate.derived_elements[index];
        candidate.validate_derived_element(candidate_derived_element)?;
        candidate.resolve_derived_element(candidate_derived_element)?;
        candidate.ensure_fillet_sources_are_unique()?;
        self.derived_elements = candidate.store.derived_elements;
        Ok(())
    }

    pub(crate) fn set_derived_distance(
        &mut self,
        derived_element_id: &str,
        value: ConstraintValue,
    ) -> CommandResult {
        let mut derived = self
            .derived_element(derived_element_id)
            .cloned()
            .ok_or_else(|| CommandError::missing("derived element", derived_element_id))?;
        let DerivedElementKind::OffsetCurve(offset) = &mut derived.kind else {
            return Err(CommandError::InvalidValue {
                field: "derived element",
                reason: "distance requires an offset curve",
            });
        };
        offset.distance = value;
        self.update_derived_element(derived)
    }

    pub(crate) fn set_derived_radius(
        &mut self,
        derived_element_id: &str,
        value: ConstraintValue,
    ) -> CommandResult {
        let mut derived = self
            .derived_element(derived_element_id)
            .cloned()
            .ok_or_else(|| CommandError::missing("derived element", derived_element_id))?;
        let DerivedElementKind::Fillet(fillet) = &mut derived.kind else {
            return Err(CommandError::InvalidValue {
                field: "derived element",
                reason: "radius requires a fillet",
            });
        };
        fillet.radius = value;
        self.update_derived_element(derived)
    }

    pub(crate) fn set_derived_radius_from_point(
        &mut self,
        derived_element_id: &str,
        resolved_index: usize,
        position: Point2,
    ) -> CommandResult {
        if !position.x_mm.is_finite() || !position.y_mm.is_finite() {
            return Err(CommandError::InvalidValue {
                field: "position",
                reason: "must be finite",
            });
        }
        let derived = self
            .derived_element(derived_element_id)
            .cloned()
            .ok_or_else(|| CommandError::missing("derived element", derived_element_id))?;
        if !matches!(derived.kind, DerivedElementKind::Fillet(_)) {
            return Err(CommandError::InvalidValue {
                field: "derived element",
                reason: "radius requires a fillet",
            });
        }
        let resolved = self.resolve_derived_element(&derived)?;
        let entity = resolved
            .get(resolved_index)
            .ok_or(CommandError::InvalidValue {
                field: "resolvedIndex",
                reason: "must reference an existing resolved fillet entity",
            })?;
        let EntityKind::Arc(arc) = entity.kind else {
            return Err(CommandError::InvalidValue {
                field: "resolvedIndex",
                reason: "must reference a resolved fillet arc",
            });
        };
        let radius_mm = (position.x_mm - arc.center.x_mm).hypot(position.y_mm - arc.center.y_mm);
        self.set_derived_radius(derived_element_id, ConstraintValue::FixedMm(radius_mm))
    }

    pub(crate) fn set_derived_direction(
        &mut self,
        derived_element_id: &str,
        direction: OffsetDirection,
    ) -> CommandResult {
        let mut derived = self
            .derived_element(derived_element_id)
            .cloned()
            .ok_or_else(|| CommandError::missing("derived element", derived_element_id))?;
        let DerivedElementKind::OffsetCurve(offset) = &mut derived.kind else {
            return Err(CommandError::InvalidValue {
                field: "derived element",
                reason: "direction requires an offset curve",
            });
        };
        offset.direction = direction;
        self.update_derived_element(derived)
    }

    pub(crate) fn set_derived_layer(&mut self, id: &str, layer_id: Option<&str>) -> CommandResult {
        if let Some(layer_id) = layer_id {
            self.ensure_layer_exists("derived element", layer_id)?;
        }
        let mut derived = self
            .derived_element(id)
            .cloned()
            .ok_or_else(|| CommandError::missing("derived element", id))?;
        derived.layer_id = layer_id.map(str::to_owned);
        self.update_derived_element(derived)
    }

    pub(crate) fn set_derived_shared_style(
        &mut self,
        id: &str,
        style_id: Option<&str>,
    ) -> CommandResult {
        if let Some(style_id) = style_id {
            self.ensure_shared_style_exists("derived element", style_id)?;
        }
        let mut derived = self
            .derived_element(id)
            .cloned()
            .ok_or_else(|| CommandError::missing("derived element", id))?;
        derived.style_id = style_id.map(str::to_owned);
        self.update_derived_element(derived)
    }

    pub(crate) fn set_fillet_sources(
        &mut self,
        id: &str,
        source_entity_ids: Vec<EntityId>,
        closed: bool,
    ) -> CommandResult {
        let mut derived = self
            .derived_element(id)
            .cloned()
            .ok_or_else(|| CommandError::missing("derived element", id))?;
        let DerivedElementKind::Fillet(fillet) = &mut derived.kind else {
            return Err(CommandError::InvalidValue {
                field: "derived element",
                reason: "sources require a fillet",
            });
        };
        fillet.source_entity_ids = source_entity_ids;
        fillet.closed = closed;
        self.update_derived_element(derived)
    }

    fn ensure_fillet_sources_are_unique(&self) -> CommandResult {
        let mut source_ids = BTreeSet::new();
        for derived_element in &self.derived_elements {
            let DerivedElementKind::Fillet(fillet) = &derived_element.kind else {
                continue;
            };
            for source_id in &fillet.source_entity_ids {
                if !source_ids.insert(source_id.as_str()) {
                    return Err(CommandError::InvalidValue {
                        field: "fillet source",
                        reason: "source entity must not be shared by multiple fillets",
                    });
                }
            }
        }
        Ok(())
    }

    pub(crate) fn delete_derived_element(&mut self, derived_element_id: &str) -> CommandResult {
        if self
            .derived_elements
            .iter()
            .all(|derived_element| derived_element.id != derived_element_id)
        {
            return Err(CommandError::missing(
                "derived element",
                derived_element_id.to_owned(),
            ));
        }
        let mut removed_ids = BTreeSet::from([derived_element_id.to_owned()]);
        self.collect_dependent_derived_element_ids(derived_element_id, &mut removed_ids);
        self.derived_elements
            .retain(|derived_element| !removed_ids.contains(&derived_element.id));
        self.stitch_start_points
            .retain(|stitch_start_point| !removed_ids.contains(&stitch_start_point.target_id));
        self.push_removed_derived_warnings(
            removed_ids
                .into_iter()
                .filter(|id| id != derived_element_id)
                .collect(),
        );
        Ok(())
    }

    fn ensure_derived_element_is_acyclic(&self, derived_element_id: &str) -> CommandResult {
        fn visit(
            document: &ProjectDocument,
            current_id: &str,
            stack: &mut Vec<String>,
            visited: &mut BTreeSet<String>,
        ) -> CommandResult {
            if stack.iter().any(|id| id == current_id) {
                return Err(CommandError::InvalidValue {
                    field: "derived element",
                    reason: "cyclic derived element dependency is not allowed",
                });
            }
            if !visited.insert(current_id.to_owned()) {
                return Ok(());
            }
            let Some(current) = document.derived_element(current_id) else {
                return Ok(());
            };
            stack.push(current_id.to_owned());
            for source_id in derived_element_source_ids(current) {
                if document.derived_element(source_id).is_some() {
                    visit(document, source_id, stack, visited)?;
                }
            }
            stack.pop();
            Ok(())
        }

        let mut stack = Vec::new();
        let mut visited = BTreeSet::new();
        visit(self, derived_element_id, &mut stack, &mut visited)
    }

    pub(in crate::document) fn collect_dependent_derived_element_ids(
        &self,
        source_id: &str,
        removed_ids: &mut BTreeSet<String>,
    ) {
        let dependents = self
            .derived_elements
            .iter()
            .filter(|derived_element| {
                !removed_ids.contains(&derived_element.id)
                    && derived_element_references_source(derived_element, source_id)
            })
            .map(|derived_element| derived_element.id.clone())
            .collect::<Vec<_>>();
        for dependent_id in dependents {
            removed_ids.insert(dependent_id.clone());
            self.collect_dependent_derived_element_ids(&dependent_id, removed_ids);
        }
    }

    pub(in crate::document) fn push_removed_derived_warnings(
        &mut self,
        removed_ids: BTreeSet<String>,
    ) {
        for derived_element_id in removed_ids {
            self.document_warnings.push(DocumentWarning {
                kind: DocumentWarningKind::DerivedElementRemoved,
                derived_element_id: derived_element_id.clone(),
                measurement_annotation_id: String::new(),
                part_id: String::new(),
                message: format!(
                    "元図形または参照の変更により、派生要素 {derived_element_id} を削除しました。"
                ),
            });
        }
    }

    pub(in crate::document) fn derived_element_sources_are_all_deleted(
        &self,
        derived_element_id: &str,
        deleted_entity_ids: &BTreeSet<String>,
    ) -> bool {
        let source_ids = self
            .base_entity_source_ids_for_derived_element(derived_element_id, &mut BTreeSet::new());
        !source_ids.is_empty() && source_ids.is_subset(deleted_entity_ids)
    }

    fn base_entity_source_ids_for_derived_element(
        &self,
        derived_element_id: &str,
        visited: &mut BTreeSet<String>,
    ) -> BTreeSet<String> {
        if !visited.insert(derived_element_id.to_owned()) {
            return BTreeSet::new();
        }
        let Some(derived_element) = self.derived_element(derived_element_id) else {
            return BTreeSet::new();
        };
        let mut source_ids = BTreeSet::new();
        for source_id in derived_element_source_ids(derived_element) {
            if self.entity(source_id).is_some() {
                source_ids.insert(source_id.clone());
            } else if self.derived_element(source_id).is_some() {
                source_ids
                    .extend(self.base_entity_source_ids_for_derived_element(source_id, visited));
            }
        }
        source_ids
    }
}

pub(in crate::document) fn derived_element_drawing_metadata(
    document: &ProjectDocument,
    view_mode: CanvasViewMode,
) -> Vec<DrawingEntityMetadata> {
    let suppressed_source_ids = match view_mode {
        CanvasViewMode::EditDisplay => document
            .derived_elements
            .iter()
            .filter(|item| {
                matches!(item.kind, DerivedElementKind::Fillet(_))
                    && derived_element_is_visible(document, item)
                    && document.resolve_derived_element(item).is_ok()
            })
            .flat_map(|item| derived_element_source_ids(item).cloned())
            .filter(|source_id| document.entity(source_id).is_some())
            .collect::<BTreeSet<_>>(),
        CanvasViewMode::OutputPreview => BTreeSet::new(),
    };

    let mut metadata = document
        .entities
        .iter()
        .map(|entity| DrawingEntityMetadata {
            entity_id: entity.id.clone(),
            suppressed_by_fillet: suppressed_source_ids.contains(&entity.id),
            ..DrawingEntityMetadata::default()
        })
        .collect::<Vec<_>>();

    for derived_element in &document.derived_elements {
        let visible = match view_mode {
            CanvasViewMode::EditDisplay => derived_element_is_visible(document, derived_element),
            CanvasViewMode::OutputPreview => {
                derived_element_is_output_visible(document, derived_element)
            }
        };
        if !visible {
            continue;
        }
        let Ok(resolved) = document.resolve_derived_element(derived_element) else {
            continue;
        };
        let source_ids = resolved_source_ids(document, derived_element, &resolved);
        metadata.extend(resolved.into_iter().enumerate().map(|(index, entity)| {
            DrawingEntityMetadata {
                entity_id: entity.id,
                derived_element_id: Some(derived_element.id.clone()),
                resolved_index: Some(index),
                source_entity_id: source_ids.get(index).cloned().flatten(),
                suppressed_by_fillet: false,
            }
        }));
    }
    metadata
}

fn resolved_source_ids(
    document: &ProjectDocument,
    derived_element: &DerivedElement,
    resolved: &[Entity],
) -> Vec<Option<String>> {
    match &derived_element.kind {
        DerivedElementKind::OffsetCurve(offset) => {
            let source_ids = if offset.source_resolved_entity_ids.is_empty() {
                &offset.source_entity_ids
            } else {
                &offset.source_resolved_entity_ids
            };
            if source_ids.len() == resolved.len() {
                return source_ids.iter().cloned().map(Some).collect();
            }
            let source_id = (source_ids.len() == 1).then(|| source_ids[0].clone());
            vec![source_id; resolved.len()]
        }
        DerivedElementKind::Fillet(fillet) => {
            let mut sources = Vec::new();
            for source_id in &fillet.source_entity_ids {
                if let Some(source) = document.entity(source_id) {
                    sources.push(source.clone());
                } else if let Some(source_derived) = document.derived_element(source_id) {
                    if let Ok(mut source_resolved) =
                        document.resolve_derived_element(source_derived)
                    {
                        sources.append(&mut source_resolved);
                    }
                }
            }
            let Ok(ordered_sources) = ordered_fillet_source_entities(&sources, fillet.closed)
            else {
                return vec![None; resolved.len()];
            };
            let mut next_line = 0;
            resolved
                .iter()
                .map(|entity| {
                    if !matches!(entity.kind, EntityKind::LineSegment(_)) {
                        return None;
                    }
                    let source_id = ordered_sources.get(next_line).map(|item| item.id.clone());
                    next_line += 1;
                    source_id
                })
                .collect()
        }
    }
}

pub(in crate::document) fn derived_element_references_entity(
    derived_element: &DerivedElement,
    entity_id: &str,
) -> bool {
    derived_element_references_source(derived_element, entity_id)
}

fn derived_element_references_source(derived_element: &DerivedElement, source_id: &str) -> bool {
    derived_element_source_ids(derived_element)
        .any(|source_entity_id| source_entity_id == source_id)
}

pub(in crate::document) fn derived_element_source_ids(
    derived_element: &DerivedElement,
) -> std::slice::Iter<'_, String> {
    match &derived_element.kind {
        DerivedElementKind::OffsetCurve(offset_curve) => offset_curve.source_entity_ids.iter(),
        DerivedElementKind::Fillet(fillet) => fillet.source_entity_ids.iter(),
    }
}

pub(in crate::document) fn derived_elements_reference_parameter(
    derived_elements: &[DerivedElement],
    parameter_id: &str,
) -> bool {
    derived_elements.iter().any(|derived_element| match &derived_element.kind {
        DerivedElementKind::OffsetCurve(offset_curve) => {
            matches!(&offset_curve.distance, ConstraintValue::Parameter(id) if id == parameter_id)
        }
        DerivedElementKind::Fillet(fillet) => {
            matches!(&fillet.radius, ConstraintValue::Parameter(id) if id == parameter_id)
        }
    })
}

fn derived_element_is_visible(
    document: &ProjectDocument,
    derived_element: &DerivedElement,
) -> bool {
    let own_layer_is_visible = match &derived_element.layer_id {
        Some(layer_id) => document
            .layers
            .iter()
            .find(|layer| &layer.id == layer_id)
            .map(|layer| layer.visible)
            .unwrap_or(false),
        None => true,
    };
    document.derived_is_part_visible(&derived_element.id, false)
        && own_layer_is_visible
        && derived_element_sources_are_visible(
            document,
            derived_element,
            false,
            &mut BTreeSet::new(),
        )
}

fn derived_element_is_output_visible(
    document: &ProjectDocument,
    derived_element: &DerivedElement,
) -> bool {
    let own_layer_is_output_visible = derived_element
        .layer_id
        .as_deref()
        .and_then(|layer_id| document.layers.iter().find(|layer| layer.id == layer_id))
        .map(|layer| layer.visible && layer.printable)
        .unwrap_or(true);
    document.derived_is_part_visible(&derived_element.id, true)
        && own_layer_is_output_visible
        && derived_element_sources_are_visible(
            document,
            derived_element,
            true,
            &mut BTreeSet::new(),
        )
}

fn derived_element_sources_are_visible(
    document: &ProjectDocument,
    derived_element: &DerivedElement,
    output: bool,
    visited: &mut BTreeSet<String>,
) -> bool {
    if !visited.insert(derived_element.id.clone()) {
        return false;
    }
    derived_element_source_ids(derived_element).all(|source_id| {
        if let Some(entity) = document.entity(source_id) {
            if output {
                document.entity_is_output_visible(entity)
            } else {
                document
                    .layers
                    .iter()
                    .find(|layer| entity.layer_id.as_deref() == Some(layer.id.as_str()))
                    .map(|layer| layer.visible)
                    .unwrap_or(true)
            }
        } else if let Some(source_derived_element) = document.derived_element(source_id) {
            if output {
                derived_element_is_output_visible_with_visited(
                    document,
                    source_derived_element,
                    visited,
                )
            } else {
                derived_element_is_visible_with_visited(document, source_derived_element, visited)
            }
        } else {
            false
        }
    })
}

fn derived_element_is_visible_with_visited(
    document: &ProjectDocument,
    derived_element: &DerivedElement,
    visited: &mut BTreeSet<String>,
) -> bool {
    let own_layer_is_visible = match &derived_element.layer_id {
        Some(layer_id) => document
            .layers
            .iter()
            .find(|layer| &layer.id == layer_id)
            .map(|layer| layer.visible)
            .unwrap_or(false),
        None => true,
    };
    own_layer_is_visible
        && derived_element_sources_are_visible(document, derived_element, false, visited)
}

fn derived_element_is_output_visible_with_visited(
    document: &ProjectDocument,
    derived_element: &DerivedElement,
    visited: &mut BTreeSet<String>,
) -> bool {
    let own_layer_is_output_visible = derived_element
        .layer_id
        .as_deref()
        .and_then(|layer_id| document.layers.iter().find(|layer| layer.id == layer_id))
        .map(|layer| layer.visible && layer.printable)
        .unwrap_or(true);
    own_layer_is_output_visible
        && derived_element_sources_are_visible(document, derived_element, true, visited)
}

fn fillet_entities_for_sources(
    derived_id: &str,
    layer_id: Option<String>,
    style_id: Option<String>,
    sources: &[Entity],
    radius_mm: f64,
    allows_closed_path: bool,
) -> CommandResult<Vec<Entity>> {
    if sources.len() < 2 {
        return Err(CommandError::InvalidValue {
            field: "fillet source",
            reason: "fillet requires at least two source entities",
        });
    }

    let ordered_sources = ordered_fillet_source_entities(sources, allows_closed_path)?;
    let closed_path = allows_closed_path && source_path_is_closed(&ordered_sources);
    if ordered_sources
        .iter()
        .any(|source| matches!(source.kind, EntityKind::Arc(_)))
    {
        if ordered_sources.len() != 2 || closed_path {
            return Err(CommandError::InvalidValue {
                field: "fillet source",
                reason: "line-arc fillets require exactly two non-closed source entities",
            });
        }
        return match (&ordered_sources[0].kind, &ordered_sources[1].kind) {
            (EntityKind::LineSegment(_) | EntityKind::CenterLine(_), EntityKind::Arc(_)) => {
                fillet_line_arc_entities(
                    derived_id,
                    layer_id,
                    style_id,
                    &ordered_sources[0],
                    &ordered_sources[1],
                    radius_mm,
                )
            }
            (EntityKind::Arc(_), EntityKind::LineSegment(_) | EntityKind::CenterLine(_)) => {
                let line = reverse_source_entity(&ordered_sources[1])?;
                let arc = reverse_source_entity(&ordered_sources[0])?;
                let reversed_entities = fillet_line_arc_entities(
                    derived_id, layer_id, style_id, &line, &arc, radius_mm,
                )?;
                let mut entities = reversed_entities
                    .iter()
                    .rev()
                    .map(reverse_source_entity)
                    .collect::<CommandResult<Vec<_>>>()?;
                for (index, entity) in entities.iter_mut().enumerate() {
                    entity.id = resolved_entity_id(derived_id, index);
                }
                Ok(entities)
            }
            _ => Err(CommandError::InvalidValue {
                field: "fillet source",
                reason: "source entity must be a line segment or arc",
            }),
        };
    }
    ordered_sources
        .iter()
        .try_for_each(|source| fillet_source_line(source).map(|_| ()))?;
    if closed_path && ordered_sources.len() < 3 {
        return Err(CommandError::InvalidValue {
            field: "fillet source",
            reason: "closed fillet paths require at least three source entities",
        });
    }

    let ordered_lines = ordered_sources
        .iter()
        .map(fillet_source_line)
        .collect::<CommandResult<Vec<_>>>()?;
    if closed_path {
        ensure_closed_fillet_path_is_convex(&ordered_lines)?;
    }
    let corner_count = if closed_path {
        ordered_lines.len()
    } else {
        ordered_lines.len() - 1
    };
    let corners = (0..corner_count)
        .map(|previous_index| {
            let next_index = (previous_index + 1) % ordered_lines.len();
            fillet_corner_for_lines(
                previous_index,
                next_index,
                ordered_lines[previous_index],
                ordered_lines[next_index],
                radius_mm,
            )
        })
        .collect::<CommandResult<Vec<_>>>()?;

    let mut entities = Vec::new();
    let mut next_resolved_index = 0;
    for (line_index, line) in ordered_lines.iter().enumerate() {
        let start = corners
            .iter()
            .find(|corner| corner.next_index == line_index)
            .map(|corner| corner.next_tangent)
            .unwrap_or(line.start);
        let end = corners
            .iter()
            .find(|corner| corner.previous_index == line_index)
            .map(|corner| corner.previous_tangent)
            .unwrap_or(line.end);
        if distance_between(start, end) <= GEOMETRY_EPSILON_MM
            || !trimmed_line_preserves_direction(*line, start, end)
        {
            return Err(CommandError::InvalidValue {
                field: "fillet radius",
                reason: "radius is too large for source entities",
            });
        }
        entities.push(Entity {
            id: resolved_entity_id(derived_id, next_resolved_index),
            layer_id: layer_id.clone(),
            style_id: style_id.clone(),
            kind: EntityKind::LineSegment(LineSegment::new(start, end)),
        });
        next_resolved_index += 1;

        if let Some(corner) = corners
            .iter()
            .find(|corner| corner.previous_index == line_index)
        {
            entities.push(Entity {
                id: resolved_entity_id(derived_id, next_resolved_index),
                layer_id: layer_id.clone(),
                style_id: style_id.clone(),
                kind: EntityKind::Arc(corner.arc),
            });
            next_resolved_index += 1;
        }
    }

    Ok(entities)
}

pub(super) fn ordered_fillet_source_entities(
    sources: &[Entity],
    allows_closed_path: bool,
) -> CommandResult<Vec<Entity>> {
    let ordered_sources = if allows_closed_path {
        order_continuous_sources(sources)
    } else {
        order_continuous_sources_preserving_sequence(sources)
    }
    .map_err(|error| match error {
        CommandError::InvalidValue {
            field: "offset source",
            reason,
        } => CommandError::InvalidValue {
            field: "fillet source",
            reason,
        },
        other => other,
    })?;
    Ok(ordered_sources)
}

fn trimmed_line_preserves_direction(line: LineSegment, start: Point2, end: Point2) -> bool {
    let original_dx = line.end.x_mm - line.start.x_mm;
    let original_dy = line.end.y_mm - line.start.y_mm;
    let trimmed_dx = end.x_mm - start.x_mm;
    let trimmed_dy = end.y_mm - start.y_mm;
    original_dx * trimmed_dx + original_dy * trimmed_dy > GEOMETRY_EPSILON_MM
}

fn ensure_closed_fillet_path_is_convex(lines: &[LineSegment]) -> CommandResult {
    let area = signed_area_for_lines(lines);
    if area.abs() <= GEOMETRY_EPSILON_MM {
        return Err(CommandError::InvalidValue {
            field: "fillet source",
            reason: "closed fillet contours must be convex",
        });
    }
    let orientation = area.signum();
    for (index, previous_line) in lines.iter().enumerate() {
        let next_line = &lines[(index + 1) % lines.len()];
        let turn_cross = line_turn_cross(*previous_line, *next_line);
        if turn_cross * orientation <= GEOMETRY_EPSILON_MM {
            return Err(CommandError::InvalidValue {
                field: "fillet source",
                reason: "closed fillet contours must be convex",
            });
        }
    }
    Ok(())
}

fn signed_area_for_lines(lines: &[LineSegment]) -> f64 {
    lines
        .iter()
        .map(|line| line.start.x_mm * line.end.y_mm - line.end.x_mm * line.start.y_mm)
        .sum::<f64>()
        / 2.0
}

fn line_turn_cross(previous_line: LineSegment, next_line: LineSegment) -> f64 {
    let previous_dx = previous_line.end.x_mm - previous_line.start.x_mm;
    let previous_dy = previous_line.end.y_mm - previous_line.start.y_mm;
    let next_dx = next_line.end.x_mm - next_line.start.x_mm;
    let next_dy = next_line.end.y_mm - next_line.start.y_mm;
    previous_dx * next_dy - previous_dy * next_dx
}

#[derive(Debug, Clone, Copy)]
struct FilletCorner {
    previous_index: usize,
    next_index: usize,
    previous_tangent: Point2,
    next_tangent: Point2,
    arc: crate::geometry::Arc,
}

#[derive(Debug, Clone, Copy)]
struct LineArcFillet {
    line_tangent: Point2,
    fillet_arc: crate::geometry::Arc,
    trimmed_arc: crate::geometry::Arc,
    score: f64,
}

fn fillet_line_arc_entities(
    derived_id: &str,
    layer_id: Option<String>,
    style_id: Option<String>,
    line_source: &Entity,
    arc_source: &Entity,
    radius_mm: f64,
) -> CommandResult<Vec<Entity>> {
    let line = fillet_source_line(line_source)?;
    let EntityKind::Arc(arc) = arc_source.kind else {
        return Err(CommandError::InvalidValue {
            field: "fillet source",
            reason: "source entity must be a line segment or arc",
        });
    };
    let corner = fillet_corner_for_line_and_arc(line, arc, radius_mm)?;
    if distance_between(line.start, corner.line_tangent) <= GEOMETRY_EPSILON_MM {
        return Err(CommandError::InvalidValue {
            field: "fillet radius",
            reason: "radius is too large for source entities",
        });
    }

    Ok(vec![
        Entity {
            id: resolved_entity_id(derived_id, 0),
            layer_id: layer_id.clone(),
            style_id: style_id.clone(),
            kind: EntityKind::LineSegment(LineSegment::new(line.start, corner.line_tangent)),
        },
        Entity {
            id: resolved_entity_id(derived_id, 1),
            layer_id: layer_id.clone(),
            style_id: style_id.clone(),
            kind: EntityKind::Arc(corner.fillet_arc),
        },
        Entity {
            id: resolved_entity_id(derived_id, 2),
            layer_id,
            style_id,
            kind: EntityKind::Arc(corner.trimmed_arc),
        },
    ])
}

fn fillet_corner_for_line_and_arc(
    line: LineSegment,
    arc: crate::geometry::Arc,
    radius_mm: f64,
) -> CommandResult<LineArcFillet> {
    let vertex = line.end;
    let arc_start = point_on_arc(&arc, arc.start_angle_rad);
    if !points_approximately_equal(vertex, arc_start) {
        return Err(CommandError::InvalidValue {
            field: "fillet source",
            reason: "source entities must share one endpoint",
        });
    }
    let line_length = distance_between(line.start, vertex);
    let from_vertex_to_line_start = unit_vector(vertex, line.start)?;
    let line_path_direction = unit_vector(line.start, vertex)?;
    let mut candidates = Vec::new();

    for normal in [
        (-from_vertex_to_line_start.1, from_vertex_to_line_start.0),
        (from_vertex_to_line_start.1, -from_vertex_to_line_start.0),
    ] {
        let offset_line_origin = add_scaled(vertex, normal, radius_mm);
        let relative = Point2::new(
            offset_line_origin.x_mm - arc.center.x_mm,
            offset_line_origin.y_mm - arc.center.y_mm,
        );
        let projection = relative.x_mm * from_vertex_to_line_start.0
            + relative.y_mm * from_vertex_to_line_start.1;
        for target_distance in [
            Some(arc.radius_mm + radius_mm),
            (arc.radius_mm > radius_mm + GEOMETRY_EPSILON_MM).then_some(arc.radius_mm - radius_mm),
        ]
        .into_iter()
        .flatten()
        {
            let discriminant = projection * projection
                - (relative.x_mm * relative.x_mm + relative.y_mm * relative.y_mm
                    - target_distance * target_distance);
            if discriminant < -GEOMETRY_EPSILON_MM {
                continue;
            }
            let root = discriminant.max(0.0).sqrt();
            for distance_on_line in [-projection - root, -projection + root] {
                if distance_on_line <= GEOMETRY_EPSILON_MM
                    || distance_on_line >= line_length - GEOMETRY_EPSILON_MM
                {
                    continue;
                }
                let line_tangent = add_scaled(vertex, from_vertex_to_line_start, distance_on_line);
                let center = add_scaled(line_tangent, normal, radius_mm);
                let center_to_source = unit_vector(arc.center, center)?;
                let arc_tangent = add_scaled(arc.center, center_to_source, arc.radius_mm);
                let Some((traversed_sweep, trimmed_arc)) =
                    trimmed_arc_after_tangent(arc, arc_tangent)
                else {
                    continue;
                };
                let start_angle_rad =
                    (line_tangent.y_mm - center.y_mm).atan2(line_tangent.x_mm - center.x_mm);
                let end_angle_rad =
                    (arc_tangent.y_mm - center.y_mm).atan2(arc_tangent.x_mm - center.x_mm);
                for sweep_angle_rad in [
                    positive_sweep(start_angle_rad, end_angle_rad),
                    -positive_sweep(end_angle_rad, start_angle_rad),
                ] {
                    let start_tangent =
                        arc_tangent_direction(center, line_tangent, sweep_angle_rad)?;
                    let end_tangent = arc_tangent_direction(center, arc_tangent, sweep_angle_rad)?;
                    let source_arc_direction =
                        arc_tangent_direction(arc.center, arc_tangent, arc.sweep_angle_rad)?;
                    if vector_dot(start_tangent, line_path_direction) < 1.0 - GEOMETRY_EPSILON_MM
                        || vector_dot(end_tangent, source_arc_direction) < 1.0 - GEOMETRY_EPSILON_MM
                    {
                        continue;
                    }
                    candidates.push(LineArcFillet {
                        line_tangent,
                        fillet_arc: crate::geometry::Arc {
                            center,
                            radius_mm,
                            start_angle_rad,
                            sweep_angle_rad,
                        },
                        trimmed_arc,
                        score: distance_on_line + traversed_sweep.abs() * arc.radius_mm,
                    });
                }
            }
        }
    }

    candidates
        .into_iter()
        .min_by(|lhs, rhs| lhs.score.total_cmp(&rhs.score))
        .ok_or(CommandError::InvalidValue {
            field: "fillet radius",
            reason: "radius is too large for source entities",
        })
}

fn trimmed_arc_after_tangent(
    arc: crate::geometry::Arc,
    tangent: Point2,
) -> Option<(f64, crate::geometry::Arc)> {
    let tangent_angle = (tangent.y_mm - arc.center.y_mm).atan2(tangent.x_mm - arc.center.x_mm);
    let traversed_sweep = if arc.sweep_angle_rad > 0.0 {
        (tangent_angle - arc.start_angle_rad).rem_euclid(std::f64::consts::TAU)
    } else {
        -(arc.start_angle_rad - tangent_angle).rem_euclid(std::f64::consts::TAU)
    };
    if traversed_sweep.abs() <= GEOMETRY_EPSILON_MM
        || traversed_sweep.abs() >= arc.sweep_angle_rad.abs() - GEOMETRY_EPSILON_MM
    {
        return None;
    }
    Some((
        traversed_sweep,
        crate::geometry::Arc {
            center: arc.center,
            radius_mm: arc.radius_mm,
            start_angle_rad: tangent_angle,
            sweep_angle_rad: arc.sweep_angle_rad - traversed_sweep,
        },
    ))
}

fn arc_tangent_direction(
    center: Point2,
    point: Point2,
    sweep_angle_rad: f64,
) -> CommandResult<(f64, f64)> {
    let radial = unit_vector(center, point)?;
    Ok(if sweep_angle_rad >= 0.0 {
        (-radial.1, radial.0)
    } else {
        (radial.1, -radial.0)
    })
}

fn vector_dot(lhs: (f64, f64), rhs: (f64, f64)) -> f64 {
    lhs.0 * rhs.0 + lhs.1 * rhs.1
}

fn fillet_corner_for_lines(
    previous_index: usize,
    next_index: usize,
    previous_line: LineSegment,
    next_line: LineSegment,
    radius_mm: f64,
) -> CommandResult<FilletCorner> {
    if !points_approximately_equal(previous_line.end, next_line.start) {
        return Err(CommandError::InvalidValue {
            field: "fillet source",
            reason: "source entities must share one endpoint",
        });
    }
    let vertex = previous_line.end;
    let previous_far = previous_line.start;
    let next_far = next_line.end;
    let previous_length = distance_between(vertex, previous_far);
    let next_length = distance_between(vertex, next_far);
    let previous_unit = unit_vector(vertex, previous_far)?;
    let next_unit = unit_vector(vertex, next_far)?;
    let dot = clamp(
        previous_unit.0 * next_unit.0 + previous_unit.1 * next_unit.1,
        -1.0,
        1.0,
    );
    let theta = dot.acos();
    if theta <= GEOMETRY_EPSILON_MM || (std::f64::consts::PI - theta) <= GEOMETRY_EPSILON_MM {
        return Err(CommandError::InvalidValue {
            field: "fillet source",
            reason: "fillet angle must be non-degenerate",
        });
    }

    let tangent_distance = radius_mm / (theta / 2.0).tan();
    if tangent_distance <= GEOMETRY_EPSILON_MM
        || tangent_distance >= previous_length
        || tangent_distance >= next_length
    {
        return Err(CommandError::InvalidValue {
            field: "fillet radius",
            reason: "radius is too large for source entities",
        });
    }

    let previous_tangent = add_scaled(vertex, previous_unit, tangent_distance);
    let next_tangent = add_scaled(vertex, next_unit, tangent_distance);
    let bisector =
        normalize_vector((previous_unit.0 + next_unit.0, previous_unit.1 + next_unit.1))?;
    let center_distance = radius_mm / (theta / 2.0).sin();
    let center = add_scaled(vertex, bisector, center_distance);
    let cross = previous_unit.0 * next_unit.1 - previous_unit.1 * next_unit.0;
    let start_angle_rad =
        (previous_tangent.y_mm - center.y_mm).atan2(previous_tangent.x_mm - center.x_mm);
    let end_angle_rad = (next_tangent.y_mm - center.y_mm).atan2(next_tangent.x_mm - center.x_mm);
    let sweep_angle_rad = if cross > 0.0 {
        -positive_sweep(end_angle_rad, start_angle_rad)
    } else {
        positive_sweep(start_angle_rad, end_angle_rad)
    };

    Ok(FilletCorner {
        previous_index,
        next_index,
        previous_tangent,
        next_tangent,
        arc: crate::geometry::Arc {
            center,
            radius_mm,
            start_angle_rad,
            sweep_angle_rad,
        },
    })
}

fn fillet_source_line(entity: &Entity) -> CommandResult<LineSegment> {
    match entity.kind {
        EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => Ok(line),
        EntityKind::Arc(_) => Err(CommandError::InvalidValue {
            field: "fillet source",
            reason: "line-arc fillets are not implemented yet",
        }),
        EntityKind::Circle(_) | EntityKind::Point(_) => Err(CommandError::InvalidValue {
            field: "fillet source",
            reason: "source entity must be a line segment or arc",
        }),
    }
}

fn unit_vector(from: Point2, to: Point2) -> CommandResult<(f64, f64)> {
    let length = distance_between(from, to);
    if length <= GEOMETRY_EPSILON_MM {
        return Err(CommandError::InvalidValue {
            field: "fillet source",
            reason: "source entity is too short",
        });
    }
    Ok((
        (to.x_mm - from.x_mm) / length,
        (to.y_mm - from.y_mm) / length,
    ))
}

fn normalize_vector(vector: (f64, f64)) -> CommandResult<(f64, f64)> {
    let length = vector.0.hypot(vector.1);
    if length <= GEOMETRY_EPSILON_MM {
        return Err(CommandError::InvalidValue {
            field: "fillet source",
            reason: "fillet angle must be non-degenerate",
        });
    }
    Ok((vector.0 / length, vector.1 / length))
}

fn add_scaled(point: Point2, vector: (f64, f64), scale: f64) -> Point2 {
    Point2::new(point.x_mm + vector.0 * scale, point.y_mm + vector.1 * scale)
}

fn positive_sweep(start_angle_rad: f64, end_angle_rad: f64) -> f64 {
    let sweep = normalize_positive_angle(end_angle_rad - start_angle_rad);
    if sweep <= GEOMETRY_EPSILON_MM {
        std::f64::consts::TAU
    } else {
        sweep
    }
}

fn offset_entities_for_sources(
    derived_id: &str,
    layer_id: Option<String>,
    style_id: Option<String>,
    sources: &[Entity],
    distance_mm: f64,
    direction: OffsetDirection,
) -> CommandResult<Vec<Entity>> {
    let ordered_sources = order_continuous_sources(sources)?;
    let sources = ordered_sources.as_slice();
    let closed = source_path_is_closed(sources);
    let side = offset_side_for_sources(sources, direction, closed);
    let mut entities = Vec::new();
    let mut generated_index = 0;
    let mut previous_end: Option<Point2> = None;

    for (source_index, source) in sources.iter().enumerate() {
        let (mut offset_entities, start, end) = offset_entity(OffsetEntityContext {
            source,
            distance_mm,
            side,
            closed_path: closed,
            path_relative_direction: sources.len() > 1,
            derived_id,
            layer_id: layer_id.clone(),
            style_id: style_id.clone(),
            index: generated_index,
        })?;
        generated_index += offset_entities.len();

        if !closed {
            if let Some(previous_end) = previous_end {
                if let Some(vertex) = shared_vertex(&sources[source_index - 1], source) {
                    if !points_approximately_equal(previous_end, start) {
                        entities.push(offset_connector_arc(
                            derived_id,
                            generated_index,
                            layer_id.clone(),
                            style_id.clone(),
                            vertex,
                            previous_end,
                            start,
                        )?);
                        generated_index += 1;
                    }
                }
            }
        }
        previous_end = Some(end);
        entities.append(&mut offset_entities);
    }

    if closed {
        return connect_closed_offset_entities(derived_id, layer_id, style_id, entities, sources);
    }

    Ok(entities)
}

fn connect_closed_offset_entities(
    derived_id: &str,
    layer_id: Option<String>,
    style_id: Option<String>,
    mut entities: Vec<Entity>,
    sources: &[Entity],
) -> CommandResult<Vec<Entity>> {
    if entities.len() <= 1 {
        return Ok(entities);
    }

    for index in 0..entities.len() {
        let next_index = (index + 1) % entities.len();
        miter_adjacent_offset_lines(&mut entities, index, next_index);
    }

    let mut connected = Vec::new();
    let mut generated_index = entities.len();
    for index in 0..entities.len() {
        let current = entities[index].clone();
        let current_end = source_end_point(&current);
        let next_index = (index + 1) % entities.len();
        let next_start = source_start_point(&entities[next_index]);
        connected.push(current);
        if let (Some(current_end), Some(next_start)) = (current_end, next_start) {
            if !points_approximately_equal(current_end, next_start) {
                if let Some(vertex) = shared_vertex(&sources[index], &sources[next_index]) {
                    connected.push(offset_connector_arc(
                        derived_id,
                        generated_index,
                        layer_id.clone(),
                        style_id.clone(),
                        vertex,
                        current_end,
                        next_start,
                    )?);
                } else {
                    connected.push(offset_connector_line(
                        derived_id,
                        generated_index,
                        layer_id.clone(),
                        style_id.clone(),
                        current_end,
                        next_start,
                    )?);
                }
                generated_index += 1;
            }
        }
    }
    Ok(connected)
}

fn miter_adjacent_offset_lines(entities: &mut [Entity], first_index: usize, second_index: usize) {
    let Some(first_line) = line_for_miter(&entities[first_index]) else {
        return;
    };
    let Some(second_line) = line_for_miter(&entities[second_index]) else {
        return;
    };
    let Some(intersection) = line_intersection(first_line, second_line) else {
        return;
    };
    set_line_end(&mut entities[first_index], intersection);
    set_line_start(&mut entities[second_index], intersection);
}

fn order_continuous_sources(sources: &[Entity]) -> CommandResult<Vec<Entity>> {
    if sources.len() <= 1 {
        return Ok(sources.to_vec());
    }
    ensure_continuous_sources_can_be_ordered(sources)?;

    for start_index in 0..sources.len() {
        for reverse_start in [false, true] {
            let mut remaining = sources.to_vec();
            let first = remaining.remove(start_index);
            if let Some(ordered) = order_continuous_from_start(first, remaining, reverse_start)? {
                return Ok(ordered);
            }
        }
    }

    Err(continuous_path_error())
}

pub(super) fn ordered_continuous_offset_sources(sources: &[Entity]) -> CommandResult<Vec<Entity>> {
    order_continuous_sources(sources)
}

fn order_continuous_sources_preserving_sequence(sources: &[Entity]) -> CommandResult<Vec<Entity>> {
    if sources.len() <= 1 {
        return Ok(sources.to_vec());
    }
    ensure_continuous_sources_can_be_ordered(sources)?;

    for reverse_start in [false, true] {
        let first = sources[0].clone();
        let remaining = sources[1..].to_vec();
        if let Some(ordered) = order_continuous_in_sequence(first, remaining, reverse_start)? {
            return Ok(ordered);
        }
    }

    Err(continuous_path_error())
}

fn ensure_continuous_sources_can_be_ordered(sources: &[Entity]) -> CommandResult {
    if sources
        .iter()
        .any(|source| matches!(source.kind, EntityKind::Circle(_)))
    {
        return Err(CommandError::InvalidValue {
            field: "offset source",
            reason: "circles cannot be mixed in a continuous offset source",
        });
    }
    Ok(())
}

fn order_continuous_from_start(
    first: Entity,
    remaining: Vec<Entity>,
    reverse_start: bool,
) -> CommandResult<Option<Vec<Entity>>> {
    order_continuous_path(first, remaining, reverse_start, true)
}

fn order_continuous_in_sequence(
    first: Entity,
    remaining: Vec<Entity>,
    reverse_start: bool,
) -> CommandResult<Option<Vec<Entity>>> {
    order_continuous_path(first, remaining, reverse_start, false)
}

fn order_continuous_path(
    first: Entity,
    mut remaining: Vec<Entity>,
    reverse_start: bool,
    allow_reordering: bool,
) -> CommandResult<Option<Vec<Entity>>> {
    let mut ordered = vec![if reverse_start {
        reverse_source_entity(&first)?
    } else {
        first
    }];

    while !remaining.is_empty() {
        let Some(current_end) = ordered.last().and_then(source_end_point) else {
            return Ok(None);
        };
        let Some((match_index, should_reverse)) =
            next_continuous_source(&remaining, current_end, allow_reordering)
        else {
            return Ok(None);
        };
        let next = remaining.remove(match_index);
        ordered.push(if should_reverse {
            reverse_source_entity(&next)?
        } else {
            next
        });
    }

    Ok(Some(ordered))
}

fn next_continuous_source(
    candidates: &[Entity],
    current_end: Point2,
    allow_reordering: bool,
) -> Option<(usize, bool)> {
    let candidate_range = if allow_reordering {
        0..candidates.len()
    } else {
        0..usize::min(1, candidates.len())
    };
    for index in candidate_range {
        let candidate = &candidates[index];
        if source_start_point(candidate)
            .is_some_and(|point| points_approximately_equal(current_end, point))
        {
            return Some((index, false));
        }
        if source_end_point(candidate)
            .is_some_and(|point| points_approximately_equal(current_end, point))
        {
            return Some((index, true));
        }
    }
    None
}

fn continuous_path_error() -> CommandError {
    CommandError::InvalidValue {
        field: "offset source",
        reason: "multiple offset sources must form one continuous path",
    }
}

fn reverse_source_entity(entity: &Entity) -> CommandResult<Entity> {
    let mut reversed = entity.clone();
    reversed.kind = match entity.kind {
        EntityKind::LineSegment(line) => {
            EntityKind::LineSegment(LineSegment::new(line.end, line.start))
        }
        EntityKind::CenterLine(line) => {
            EntityKind::CenterLine(LineSegment::new(line.end, line.start))
        }
        EntityKind::Arc(arc) => EntityKind::Arc(crate::geometry::Arc {
            center: arc.center,
            radius_mm: arc.radius_mm,
            start_angle_rad: arc.start_angle_rad + arc.sweep_angle_rad,
            sweep_angle_rad: -arc.sweep_angle_rad,
        }),
        EntityKind::Circle(_) | EntityKind::Point(_) => {
            return Err(CommandError::InvalidValue {
                field: "offset source",
                reason: "source cannot be reversed",
            });
        }
    };
    Ok(reversed)
}

struct OffsetEntityContext<'a> {
    source: &'a Entity,
    distance_mm: f64,
    side: f64,
    closed_path: bool,
    path_relative_direction: bool,
    derived_id: &'a str,
    layer_id: Option<String>,
    style_id: Option<String>,
    index: usize,
}

fn offset_entity(context: OffsetEntityContext<'_>) -> CommandResult<(Vec<Entity>, Point2, Point2)> {
    let OffsetEntityContext {
        source,
        distance_mm,
        side,
        closed_path,
        path_relative_direction,
        derived_id,
        layer_id,
        style_id,
        index,
    } = context;

    match source.kind {
        EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => {
            let offset = offset_line_segment(line, distance_mm, side)?;
            let entity = Entity {
                id: resolved_entity_id(derived_id, index),
                layer_id,
                style_id,
                kind: match source.kind {
                    EntityKind::CenterLine(_) => EntityKind::CenterLine(offset),
                    _ => EntityKind::LineSegment(offset),
                },
            };
            Ok((vec![entity], offset.start, offset.end))
        }
        EntityKind::Circle(circle) => {
            let radius_mm = circle.radius_mm + side * distance_mm;
            if radius_mm <= GEOMETRY_EPSILON_MM {
                return Err(CommandError::InvalidValue {
                    field: "offset distance",
                    reason: "offset circle radius would be non-positive",
                });
            }
            let entity = Entity {
                id: resolved_entity_id(derived_id, index),
                layer_id,
                style_id,
                kind: EntityKind::Circle(Circle {
                    center: circle.center,
                    radius_mm,
                }),
            };
            Ok((
                vec![entity],
                Point2::new(circle.center.x_mm + radius_mm, circle.center.y_mm),
                Point2::new(circle.center.x_mm + radius_mm, circle.center.y_mm),
            ))
        }
        EntityKind::Arc(arc) => {
            let radius_side = if path_relative_direction {
                -side * arc.sweep_angle_rad.signum()
            } else {
                side
            };
            let radius_mm = arc.radius_mm + radius_side * distance_mm;
            if radius_mm <= GEOMETRY_EPSILON_MM {
                if closed_path {
                    // Inward offsets can collapse a fillet arc to its center; adjacent lines miter there.
                    return Ok((Vec::new(), arc.center, arc.center));
                }
                return Err(CommandError::InvalidValue {
                    field: "offset distance",
                    reason: "offset arc radius would be non-positive",
                });
            }
            let offset_arc = crate::geometry::Arc {
                center: arc.center,
                radius_mm,
                start_angle_rad: arc.start_angle_rad,
                sweep_angle_rad: arc.sweep_angle_rad,
            };
            let entity = Entity {
                id: resolved_entity_id(derived_id, index),
                layer_id,
                style_id,
                kind: EntityKind::Arc(offset_arc),
            };
            Ok((
                vec![entity],
                point_on_arc(&offset_arc, offset_arc.start_angle_rad),
                point_on_arc(
                    &offset_arc,
                    offset_arc.start_angle_rad + offset_arc.sweep_angle_rad,
                ),
            ))
        }
        EntityKind::Point(_) => Err(CommandError::InvalidValue {
            field: "offset source",
            reason: "points cannot be offset",
        }),
    }
}

fn offset_line_segment(
    line: LineSegment,
    distance_mm: f64,
    side: f64,
) -> CommandResult<LineSegment> {
    let dx = line.end.x_mm - line.start.x_mm;
    let dy = line.end.y_mm - line.start.y_mm;
    let length = dx.hypot(dy);
    if length <= GEOMETRY_EPSILON_MM {
        return Err(CommandError::InvalidValue {
            field: "offset source",
            reason: "line segment is too short",
        });
    }
    let normal_x = -dy / length * side * distance_mm;
    let normal_y = dx / length * side * distance_mm;
    Ok(LineSegment::new(
        Point2::new(line.start.x_mm + normal_x, line.start.y_mm + normal_y),
        Point2::new(line.end.x_mm + normal_x, line.end.y_mm + normal_y),
    ))
}

fn offset_connector_arc(
    derived_id: &str,
    index: usize,
    layer_id: Option<String>,
    style_id: Option<String>,
    center: Point2,
    start: Point2,
    end: Point2,
) -> CommandResult<Entity> {
    let radius_mm = (start.x_mm - center.x_mm).hypot(start.y_mm - center.y_mm);
    if radius_mm <= GEOMETRY_EPSILON_MM {
        return Err(CommandError::InvalidValue {
            field: "offset connector",
            reason: "connector radius is too small",
        });
    }
    let start_angle_rad = (start.y_mm - center.y_mm).atan2(start.x_mm - center.x_mm);
    let end_angle_rad = (end.y_mm - center.y_mm).atan2(end.x_mm - center.x_mm);
    let mut sweep_angle_rad = end_angle_rad - start_angle_rad;
    while sweep_angle_rad <= -std::f64::consts::PI {
        sweep_angle_rad += std::f64::consts::TAU;
    }
    while sweep_angle_rad > std::f64::consts::PI {
        sweep_angle_rad -= std::f64::consts::TAU;
    }
    Ok(Entity {
        id: resolved_entity_id(derived_id, index),
        layer_id,
        style_id,
        kind: EntityKind::Arc(crate::geometry::Arc {
            center,
            radius_mm,
            start_angle_rad,
            sweep_angle_rad,
        }),
    })
}

fn offset_connector_line(
    derived_id: &str,
    index: usize,
    layer_id: Option<String>,
    style_id: Option<String>,
    start: Point2,
    end: Point2,
) -> CommandResult<Entity> {
    if points_approximately_equal(start, end) {
        return Err(CommandError::InvalidValue {
            field: "offset connector",
            reason: "connector line is too short",
        });
    }
    Ok(Entity {
        id: resolved_entity_id(derived_id, index),
        layer_id,
        style_id,
        kind: EntityKind::LineSegment(LineSegment::new(start, end)),
    })
}

fn line_for_miter(entity: &Entity) -> Option<LineSegment> {
    match entity.kind {
        EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => Some(line),
        _ => None,
    }
}

fn set_line_start(entity: &mut Entity, start: Point2) {
    match &mut entity.kind {
        EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => {
            line.start = start;
        }
        _ => {}
    }
}

fn set_line_end(entity: &mut Entity, end: Point2) {
    match &mut entity.kind {
        EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => {
            line.end = end;
        }
        _ => {}
    }
}

fn line_intersection(first: LineSegment, second: LineSegment) -> Option<Point2> {
    let first_dx = first.end.x_mm - first.start.x_mm;
    let first_dy = first.end.y_mm - first.start.y_mm;
    let second_dx = second.end.x_mm - second.start.x_mm;
    let second_dy = second.end.y_mm - second.start.y_mm;
    let denominator = first_dx * second_dy - first_dy * second_dx;
    if denominator.abs() <= GEOMETRY_EPSILON_MM {
        return None;
    }

    let relative_x = second.start.x_mm - first.start.x_mm;
    let relative_y = second.start.y_mm - first.start.y_mm;
    let first_scale = (relative_x * second_dy - relative_y * second_dx) / denominator;
    Some(Point2::new(
        first.start.x_mm + first_scale * first_dx,
        first.start.y_mm + first_scale * first_dy,
    ))
}

fn offset_side_for_sources(sources: &[Entity], direction: OffsetDirection, closed: bool) -> f64 {
    match direction {
        OffsetDirection::Left => 1.0,
        OffsetDirection::Right => -1.0,
        OffsetDirection::Outward => {
            if closed && signed_area_for_sources(sources) > 0.0 {
                -1.0
            } else {
                1.0
            }
        }
        OffsetDirection::Inward => {
            if closed && signed_area_for_sources(sources) > 0.0 {
                1.0
            } else {
                -1.0
            }
        }
    }
}

fn source_path_is_closed(sources: &[Entity]) -> bool {
    if sources.len() < 2 {
        return false;
    }
    let Some(first_start) = source_start_point(&sources[0]) else {
        return false;
    };
    let Some(last_end) = source_end_point(sources.last().unwrap()) else {
        return false;
    };
    points_approximately_equal(first_start, last_end)
        && sources
            .windows(2)
            .all(|pair| shared_vertex(&pair[0], &pair[1]).is_some())
}

fn signed_area_for_sources(sources: &[Entity]) -> f64 {
    let points = sources
        .iter()
        .flat_map(signed_area_points_for_source)
        .collect::<Vec<_>>();
    if points.len() < 3 {
        return 0.0;
    }
    points
        .iter()
        .zip(points.iter().cycle().skip(1))
        .take(points.len())
        .map(|(lhs, rhs)| lhs.x_mm * rhs.y_mm - rhs.x_mm * lhs.y_mm)
        .sum::<f64>()
        / 2.0
}

fn signed_area_points_for_source(entity: &Entity) -> Vec<Point2> {
    match entity.kind {
        EntityKind::Arc(arc) => arc_signed_area_points(arc),
        _ => source_start_point(entity).into_iter().collect(),
    }
}

fn arc_signed_area_points(arc: crate::geometry::Arc) -> Vec<Point2> {
    let segment_count = (arc.sweep_angle_rad.abs() / (std::f64::consts::PI / 16.0))
        .ceil()
        .max(2.0) as usize;
    (0..segment_count)
        .map(|index| {
            let ratio = index as f64 / segment_count as f64;
            point_on_arc(&arc, arc.start_angle_rad + arc.sweep_angle_rad * ratio)
        })
        .collect()
}

fn shared_vertex(first: &Entity, second: &Entity) -> Option<Point2> {
    let first_end = source_end_point(first)?;
    let second_start = source_start_point(second)?;
    points_approximately_equal(first_end, second_start).then_some(first_end)
}

fn source_start_point(entity: &Entity) -> Option<Point2> {
    match entity.kind {
        EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => Some(line.start),
        EntityKind::Arc(arc) => Some(point_on_arc(&arc, arc.start_angle_rad)),
        EntityKind::Circle(circle) => Some(Point2::new(
            circle.center.x_mm + circle.radius_mm,
            circle.center.y_mm,
        )),
        EntityKind::Point(point) => Some(point),
    }
}

fn source_end_point(entity: &Entity) -> Option<Point2> {
    match entity.kind {
        EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => Some(line.end),
        EntityKind::Arc(arc) => Some(point_on_arc(
            &arc,
            arc.start_angle_rad + arc.sweep_angle_rad,
        )),
        EntityKind::Circle(circle) => Some(Point2::new(
            circle.center.x_mm + circle.radius_mm,
            circle.center.y_mm,
        )),
        EntityKind::Point(point) => Some(point),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::command::DocumentCommand;
    use crate::layers::{Layer, LayerKind};

    fn point(x_mm: f64, y_mm: f64) -> Point2 {
        Point2::new(x_mm, y_mm)
    }

    fn line_entity(id: &str, start: Point2, end: Point2) -> Entity {
        Entity::new(id, EntityKind::LineSegment(LineSegment::new(start, end)))
    }

    fn center_line_entity(id: &str, start: Point2, end: Point2) -> Entity {
        Entity::new(id, EntityKind::CenterLine(LineSegment::new(start, end)))
    }

    fn arc_entity(
        id: &str,
        center: Point2,
        radius_mm: f64,
        start_angle_rad: f64,
        sweep_angle_rad: f64,
    ) -> Entity {
        Entity::new(
            id,
            EntityKind::Arc(crate::geometry::Arc {
                center,
                radius_mm,
                start_angle_rad,
                sweep_angle_rad,
            }),
        )
    }

    fn layer(id: &str, visible: bool, printable: bool) -> Layer {
        let mut layer = Layer::new(id, id, LayerKind::Dimension, printable);
        layer.visible = visible;
        layer
    }

    fn assert_approx_eq(lhs: f64, rhs: f64) {
        assert!(
            (lhs - rhs).abs() <= GEOMETRY_EPSILON_MM,
            "expected {lhs} to equal {rhs}"
        );
    }

    fn assert_line(entity: &Entity, expected_start: Point2, expected_end: Point2) {
        let (EntityKind::LineSegment(line) | EntityKind::CenterLine(line)) = entity.kind else {
            panic!("expected line-like entity, got {:?}", entity.kind);
        };
        assert_approx_eq(line.start.x_mm, expected_start.x_mm);
        assert_approx_eq(line.start.y_mm, expected_start.y_mm);
        assert_approx_eq(line.end.x_mm, expected_end.x_mm);
        assert_approx_eq(line.end.y_mm, expected_end.y_mm);
    }

    fn offset_curve(id: &str, layer_id: Option<&str>, source_ids: Vec<&str>) -> DerivedElement {
        DerivedElement::offset_curve(
            id,
            layer_id.map(str::to_owned),
            OffsetCurve {
                source_entity_ids: source_ids.into_iter().map(str::to_owned).collect(),
                source_resolved_entity_ids: Vec::new(),
                distance: ConstraintValue::FixedMm(1.0),
                direction: OffsetDirection::Left,
            },
        )
    }

    #[test]
    fn offset_entity_preserves_center_line_kind_and_offsets_skew_line() {
        let source = center_line_entity("entity:center", point(1.0, 2.0), point(4.0, 6.0));
        let (resolved, start, end) = offset_entity(OffsetEntityContext {
            source: &source,
            distance_mm: 5.0,
            side: 1.0,
            closed_path: false,
            path_relative_direction: false,
            derived_id: "derived:offset",
            layer_id: None,
            style_id: None,
            index: 0,
        })
        .expect("center line should offset");

        assert_eq!(resolved.len(), 1);
        assert!(matches!(resolved[0].kind, EntityKind::CenterLine(_)));
        assert_line(&resolved[0], point(-3.0, 5.0), point(0.0, 9.0));
        assert_approx_eq(start.x_mm, -3.0);
        assert_approx_eq(start.y_mm, 5.0);
        assert_approx_eq(end.x_mm, 0.0);
        assert_approx_eq(end.y_mm, 9.0);
    }

    #[test]
    fn arc_offset_keeps_single_arc_radial_direction_and_uses_path_direction_for_ranges() {
        let source = arc_entity(
            "entity:arc",
            point(0.0, 0.0),
            5.0,
            0.0,
            std::f64::consts::FRAC_PI_2,
        );
        for (side, path_relative_direction) in [(-1.0, false), (1.0, true)] {
            let (resolved, _, _) = offset_entity(OffsetEntityContext {
                source: &source,
                distance_mm: 3.0,
                side,
                closed_path: false,
                path_relative_direction,
                derived_id: "derived:offset",
                layer_id: None,
                style_id: None,
                index: 0,
            })
            .expect("arc should offset inward");
            let EntityKind::Arc(arc) = resolved[0].kind else {
                panic!("expected arc");
            };
            assert_approx_eq(arc.radius_mm, 2.0);
        }
    }

    #[test]
    fn offset_connector_arc_normalizes_shortest_sweep_across_pi_boundary() {
        let start_angle = 170.0_f64.to_radians();
        let end_angle = (-170.0_f64).to_radians();
        let center = point(0.0, 0.0);
        let start = point(2.0 * start_angle.cos(), 2.0 * start_angle.sin());
        let end = point(2.0 * end_angle.cos(), 2.0 * end_angle.sin());

        let connector =
            offset_connector_arc("derived:offset", 3, None, None, center, start, end).unwrap();
        let EntityKind::Arc(arc) = connector.kind else {
            panic!("expected connector arc");
        };

        assert_approx_eq(arc.radius_mm, 2.0);
        assert_approx_eq(arc.start_angle_rad, start_angle);
        assert_approx_eq(arc.sweep_angle_rad, 20.0_f64.to_radians());

        let reverse_connector =
            offset_connector_arc("derived:offset", 4, None, None, center, end, start).unwrap();
        let EntityKind::Arc(reverse_arc) = reverse_connector.kind else {
            panic!("expected reverse connector arc");
        };
        assert_approx_eq(reverse_arc.sweep_angle_rad, -20.0_f64.to_radians());
    }

    #[test]
    fn open_offset_polyline_inserts_connector_arc_between_generated_lines() {
        let sources = vec![
            line_entity("entity:bottom", point(0.0, 0.0), point(10.0, 0.0)),
            line_entity("entity:right", point(10.0, 0.0), point(10.0, 10.0)),
        ];

        let resolved = offset_entities_for_sources(
            "derived:offset",
            None,
            None,
            &sources,
            1.0,
            OffsetDirection::Left,
        )
        .expect("open polyline should offset");

        assert_eq!(
            resolved
                .iter()
                .map(|entity| entity.id.as_str())
                .collect::<Vec<_>>(),
            vec![
                "derived:offset:resolved:0",
                "derived:offset:resolved:2",
                "derived:offset:resolved:1",
            ]
        );
        assert_line(&resolved[0], point(0.0, 1.0), point(10.0, 1.0));
        assert_line(&resolved[2], point(9.0, 0.0), point(9.0, 10.0));
        let EntityKind::Arc(connector) = resolved[1].kind else {
            panic!("expected connector arc");
        };
        assert_approx_eq(connector.center.x_mm, 10.0);
        assert_approx_eq(connector.center.y_mm, 0.0);
        assert_approx_eq(connector.radius_mm, 1.0);
        assert_approx_eq(connector.sweep_angle_rad, std::f64::consts::FRAC_PI_2);
    }

    #[test]
    fn reverse_source_entity_swaps_line_and_arc_direction() {
        let reversed_line = reverse_source_entity(&line_entity(
            "entity:line",
            point(1.0, 2.0),
            point(4.0, 6.0),
        ))
        .expect("line should reverse");
        assert_line(&reversed_line, point(4.0, 6.0), point(1.0, 2.0));

        let reversed_arc =
            reverse_source_entity(&arc_entity("entity:arc", point(0.0, 0.0), 3.0, 0.25, 1.5))
                .expect("arc should reverse");
        let EntityKind::Arc(arc) = reversed_arc.kind else {
            panic!("expected reversed arc");
        };
        assert_approx_eq(arc.start_angle_rad, 1.75);
        assert_approx_eq(arc.sweep_angle_rad, -1.5);
    }

    #[test]
    fn closed_source_area_and_offset_side_follow_source_orientation() {
        let counter_clockwise = vec![
            line_entity("bottom", point(0.0, 0.0), point(10.0, 0.0)),
            line_entity("right", point(10.0, 0.0), point(10.0, 10.0)),
            line_entity("top", point(10.0, 10.0), point(0.0, 10.0)),
            line_entity("left", point(0.0, 10.0), point(0.0, 0.0)),
        ];
        let clockwise = vec![
            line_entity("left", point(0.0, 0.0), point(0.0, 10.0)),
            line_entity("top", point(0.0, 10.0), point(10.0, 10.0)),
            line_entity("right", point(10.0, 10.0), point(10.0, 0.0)),
            line_entity("bottom", point(10.0, 0.0), point(0.0, 0.0)),
        ];

        assert_approx_eq(signed_area_for_sources(&counter_clockwise), 100.0);
        assert_approx_eq(signed_area_for_sources(&clockwise), -100.0);
        assert_approx_eq(
            offset_side_for_sources(&counter_clockwise, OffsetDirection::Inward, true),
            1.0,
        );
        assert_approx_eq(
            offset_side_for_sources(&counter_clockwise, OffsetDirection::Outward, true),
            -1.0,
        );
        assert_approx_eq(
            offset_side_for_sources(&clockwise, OffsetDirection::Inward, true),
            -1.0,
        );
        assert_approx_eq(
            offset_side_for_sources(&clockwise, OffsetDirection::Outward, true),
            1.0,
        );

        let open = vec![line_entity(
            "open",
            point(0.0, 0.0),
            point(0.0, GEOMETRY_EPSILON_MM),
        )];
        assert_approx_eq(
            offset_side_for_sources(&open, OffsetDirection::Inward, false),
            -1.0,
        );
        assert_approx_eq(
            offset_side_for_sources(&open, OffsetDirection::Outward, false),
            1.0,
        );
    }

    #[test]
    fn source_area_helpers_preserve_line_arc_and_circle_endpoints() {
        let triangle = vec![
            LineSegment::new(point(0.0, 0.0), point(6.0, 0.0)),
            LineSegment::new(point(6.0, 0.0), point(2.0, 3.0)),
            LineSegment::new(point(2.0, 3.0), point(0.0, 0.0)),
        ];
        assert_approx_eq(signed_area_for_lines(&triangle), 9.0);
        assert_approx_eq(line_turn_cross(triangle[0], triangle[1]), 18.0);

        let arc = crate::geometry::Arc {
            center: point(1.0, 2.0),
            radius_mm: 4.0,
            start_angle_rad: std::f64::consts::FRAC_PI_2,
            sweep_angle_rad: -std::f64::consts::PI,
        };
        let arc_source = arc_entity(
            "entity:arc",
            arc.center,
            arc.radius_mm,
            arc.start_angle_rad,
            arc.sweep_angle_rad,
        );
        let circle = Entity::new(
            "entity:circle",
            EntityKind::Circle(Circle {
                center: point(5.0, 6.0),
                radius_mm: 3.0,
            }),
        );

        assert_approx_eq(source_start_point(&arc_source).unwrap().x_mm, 1.0);
        assert_approx_eq(source_start_point(&arc_source).unwrap().y_mm, 6.0);
        assert_approx_eq(source_end_point(&arc_source).unwrap().x_mm, 1.0);
        assert_approx_eq(source_end_point(&arc_source).unwrap().y_mm, -2.0);
        assert_eq!(source_start_point(&circle).unwrap(), point(8.0, 6.0));
        assert_eq!(source_end_point(&circle).unwrap(), point(8.0, 6.0));

        let area_points = arc_signed_area_points(arc);
        assert_eq!(area_points.len(), 16);
        assert_approx_eq(area_points[0].x_mm, 1.0);
        assert_approx_eq(area_points[0].y_mm, 6.0);
        assert_approx_eq(area_points[8].x_mm, 5.0);
        assert_approx_eq(area_points[8].y_mm, 2.0);
    }

    #[test]
    fn fillet_corner_for_lines_computes_tangents_center_and_sweep() {
        let corner = fillet_corner_for_lines(
            0,
            1,
            LineSegment::new(point(0.0, 0.0), point(10.0, 0.0)),
            LineSegment::new(point(10.0, 0.0), point(10.0, 10.0)),
            2.0,
        )
        .expect("corner should fillet");

        assert_eq!(corner.previous_index, 0);
        assert_eq!(corner.next_index, 1);
        assert_approx_eq(corner.previous_tangent.x_mm, 8.0);
        assert_approx_eq(corner.previous_tangent.y_mm, 0.0);
        assert_approx_eq(corner.next_tangent.x_mm, 10.0);
        assert_approx_eq(corner.next_tangent.y_mm, 2.0);
        assert_approx_eq(corner.arc.center.x_mm, 8.0);
        assert_approx_eq(corner.arc.center.y_mm, 2.0);
        assert_approx_eq(corner.arc.radius_mm, 2.0);
        assert_approx_eq(corner.arc.sweep_angle_rad, std::f64::consts::FRAC_PI_2);

        let clockwise_corner = fillet_corner_for_lines(
            1,
            2,
            LineSegment::new(point(10.0, 10.0), point(10.0, 0.0)),
            LineSegment::new(point(10.0, 0.0), point(0.0, 0.0)),
            2.0,
        )
        .expect("clockwise corner should fillet");
        assert_approx_eq(
            clockwise_corner.arc.sweep_angle_rad,
            -std::f64::consts::FRAC_PI_2,
        );
    }

    #[test]
    fn derived_reference_visibility_and_output_suppression_require_all_conditions() {
        let mut document = ProjectDocument::new("Derived Visibility");
        document
            .apply_command(DocumentCommand::AddLayer(layer(
                "layer:visible",
                true,
                true,
            )))
            .expect("visible layer");
        document
            .apply_command(DocumentCommand::AddLayer(layer(
                "layer:hidden",
                false,
                true,
            )))
            .expect("hidden layer");
        document
            .apply_command(DocumentCommand::AddLayer(layer(
                "layer:non-print",
                true,
                false,
            )))
            .expect("non-print layer");
        let mut source = line_entity("entity:source", point(0.0, 0.0), point(10.0, 0.0));
        source.layer_id = Some("layer:visible".to_owned());
        let mut non_print_source =
            line_entity("entity:non-print", point(0.0, 2.0), point(10.0, 2.0));
        non_print_source.layer_id = Some("layer:non-print".to_owned());
        document
            .apply_command(DocumentCommand::AddEntity(source))
            .expect("source entity");
        document
            .apply_command(DocumentCommand::AddEntity(non_print_source))
            .expect("non-print source entity");

        let visible = offset_curve(
            "derived:visible",
            Some("layer:visible"),
            vec!["entity:source"],
        );
        let hidden = offset_curve(
            "derived:hidden",
            Some("layer:hidden"),
            vec!["entity:source"],
        );
        let from_non_print = offset_curve("derived:non-print", None, vec!["entity:non-print"]);
        let dependent = offset_curve("derived:dependent", None, vec!["derived:visible"]);
        document
            .apply_command(DocumentCommand::AddDerivedElement(visible.clone()))
            .expect("visible offset");
        document
            .apply_command(DocumentCommand::AddDerivedElement(hidden.clone()))
            .expect("hidden offset");
        document
            .apply_command(DocumentCommand::AddDerivedElement(from_non_print.clone()))
            .expect("non-print offset");
        document
            .apply_command(DocumentCommand::AddDerivedElement(dependent.clone()))
            .expect("dependent offset");

        assert!(derived_element_references_entity(&visible, "entity:source"));
        assert!(!derived_element_references_entity(&visible, "entity:other"));
        assert!(derived_element_references_source(
            &dependent,
            "derived:visible"
        ));
        assert!(!derived_element_references_source(
            &dependent,
            "entity:source"
        ));

        assert!(derived_element_is_visible(&document, &visible));
        assert!(derived_element_is_output_visible(&document, &visible));
        assert!(!derived_element_is_visible(&document, &hidden));
        assert!(!derived_element_is_output_visible(&document, &hidden));
        assert!(derived_element_is_visible(&document, &from_non_print));
        assert!(!derived_element_is_output_visible(
            &document,
            &from_non_print
        ));

        document
            .apply_command(DocumentCommand::SetLayerVisibility {
                layer_id: "layer:visible".to_owned(),
                visible: false,
            })
            .expect("hide source layer");
        assert!(!derived_element_is_visible(&document, &visible));
        assert!(!derived_element_is_visible(&document, &dependent));
        assert!(!derived_element_is_output_visible(&document, &dependent));
    }

    #[test]
    fn output_suppressed_fillet_sources_excludes_hidden_invalid_and_derived_sources() {
        let mut document = ProjectDocument::new("Fillet Suppression");
        document
            .apply_command(DocumentCommand::AddLayer(layer(
                "layer:hidden",
                false,
                true,
            )))
            .expect("hidden layer");
        document
            .apply_command(DocumentCommand::AddEntity(line_entity(
                "entity:a",
                point(0.0, 0.0),
                point(10.0, 0.0),
            )))
            .expect("entity a");
        document
            .apply_command(DocumentCommand::AddEntity(line_entity(
                "entity:b",
                point(10.0, 0.0),
                point(10.0, 10.0),
            )))
            .expect("entity b");
        document
            .apply_command(DocumentCommand::AddEntity(line_entity(
                "entity:c",
                point(20.0, 0.0),
                point(30.0, 0.0),
            )))
            .expect("entity c");
        document
            .apply_command(DocumentCommand::AddEntity(line_entity(
                "entity:d",
                point(30.0, 0.0),
                point(30.0, 10.0),
            )))
            .expect("entity d");

        document
            .apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
                "derived:visible-fillet",
                None,
                Fillet {
                    source_entity_ids: vec!["entity:a".to_owned(), "entity:b".to_owned()],
                    radius: ConstraintValue::FixedMm(1.0),
                    closed: false,
                },
            )))
            .expect("visible fillet");
        document
            .apply_command(DocumentCommand::AddDerivedElement(DerivedElement::fillet(
                "derived:hidden-fillet",
                Some("layer:hidden".to_owned()),
                Fillet {
                    source_entity_ids: vec!["entity:c".to_owned(), "entity:d".to_owned()],
                    radius: ConstraintValue::FixedMm(1.0),
                    closed: false,
                },
            )))
            .expect("hidden fillet");

        let suppressed = document.output_suppressed_fillet_source_ids();
        assert_eq!(
            suppressed,
            BTreeSet::from(["entity:a".to_owned(), "entity:b".to_owned()])
        );
    }

    #[test]
    fn deleting_derived_element_removes_dependent_chain_and_warns_for_dependents() {
        let mut document = ProjectDocument::new("Delete Derived Chain");
        document
            .apply_command(DocumentCommand::AddEntity(line_entity(
                "entity:base",
                point(0.0, 0.0),
                point(10.0, 0.0),
            )))
            .expect("base line");
        document
            .apply_command(DocumentCommand::AddDerivedElement(
                DerivedElement::offset_curve(
                    "derived:first",
                    None,
                    OffsetCurve {
                        source_entity_ids: vec!["entity:base".to_owned()],
                        source_resolved_entity_ids: Vec::new(),
                        distance: ConstraintValue::FixedMm(2.0),
                        direction: OffsetDirection::Left,
                    },
                ),
            ))
            .expect("first offset");
        document
            .apply_command(DocumentCommand::AddDerivedElement(
                DerivedElement::offset_curve(
                    "derived:second",
                    None,
                    OffsetCurve {
                        source_entity_ids: vec!["derived:first".to_owned()],
                        source_resolved_entity_ids: Vec::new(),
                        distance: ConstraintValue::FixedMm(2.0),
                        direction: OffsetDirection::Left,
                    },
                ),
            ))
            .expect("second offset");

        document
            .apply_command(DocumentCommand::DeleteDerivedElement(
                "derived:first".to_owned(),
            ))
            .expect("delete first derived element");

        assert!(document.derived_element("derived:first").is_none());
        assert!(document.derived_element("derived:second").is_none());
        assert_eq!(document.document_warnings().len(), 1);
        assert_eq!(
            document.document_warnings()[0].derived_element_id,
            "derived:second"
        );
    }
}
