use super::*;
use std::collections::HashSet;

pub(in crate::document) fn validate_parameter(parameter: &Parameter) -> CommandResult {
    ensure_non_empty_id("parameter", &parameter.id)?;
    if parameter.name.trim().is_empty() {
        return Err(CommandError::InvalidValue {
            field: "parameter name",
            reason: "must not be empty",
        });
    }
    validate_non_negative_finite("parameter value", parameter.value_mm)
}

pub(in crate::document) fn implicit_constraints_for_entity(_entity: &Entity) -> Vec<Constraint> {
    Vec::new()
}

pub(in crate::document) fn validate_layer(layer: &Layer) -> CommandResult {
    ensure_non_empty_id("layer", &layer.id)?;
    if layer.name.trim().is_empty() {
        return Err(CommandError::InvalidValue {
            field: "layer name",
            reason: "must not be empty",
        });
    }
    validate_layer_style(&layer.style)
}

pub(in crate::document) fn validate_layer_style(style: &LayerStyle) -> CommandResult {
    if !style.stroke_width_mm.is_finite() || style.stroke_width_mm <= 0.0 {
        return Err(CommandError::InvalidValue {
            field: "layer stroke width",
            reason: "must be a positive finite value",
        });
    }
    let stroke = style.stroke;
    for (field, value) in [
        ("layer stroke red", stroke.red),
        ("layer stroke green", stroke.green),
        ("layer stroke blue", stroke.blue),
        ("layer stroke alpha", stroke.alpha),
    ] {
        if !value.is_finite() || !(0.0..=1.0).contains(&value) {
            return Err(CommandError::InvalidValue {
                field,
                reason: "must be between 0.0 and 1.0",
            });
        }
    }
    Ok(())
}

pub(in crate::document) fn validate_shared_style(style: &SharedStyle) -> CommandResult {
    ensure_non_empty_id("shared style", &style.id)?;
    if style.name.trim().is_empty() {
        return Err(CommandError::InvalidValue {
            field: "shared style name",
            reason: "must not be empty",
        });
    }
    validate_layer_style(&style.style)
}

pub(in crate::document) fn validate_non_negative_finite(
    field: &'static str,
    value: f64,
) -> CommandResult {
    if !value.is_finite() {
        return Err(CommandError::InvalidValue {
            field,
            reason: "must be finite",
        });
    }
    if value < 0.0 {
        return Err(CommandError::InvalidValue {
            field,
            reason: "must not be negative",
        });
    }
    Ok(())
}

pub(in crate::document) fn validate_collection_ids<'a>(
    items: impl Iterator<Item = (&'static str, &'a str)>,
    kind: &'static str,
) -> Result<HashSet<&'a str>, DocumentValidationError> {
    let mut ids = HashSet::new();
    for (_, id) in items {
        if id.trim().is_empty() {
            return Err(DocumentValidationError::EmptyId(kind));
        }
        if !ids.insert(id) {
            return Err(DocumentValidationError::DuplicateId {
                kind,
                id: id.to_owned(),
            });
        }
    }
    Ok(ids)
}

pub(in crate::document) fn ensure_id_in_set(
    source: &'static str,
    target_kind: &'static str,
    target_id: &str,
    ids: &HashSet<&str>,
) -> Result<(), DocumentValidationError> {
    if ids.contains(target_id) {
        Ok(())
    } else {
        Err(DocumentValidationError::BrokenReference {
            source,
            target_kind,
            target_id: target_id.to_owned(),
        })
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(in crate::document) enum AllowedConstraintValue {
    None,
    Length,
    Degrees,
}

pub(in crate::document) fn ensure_value_kind(
    value: &Option<ConstraintValue>,
    allowed: AllowedConstraintValue,
    field: &'static str,
) -> CommandResult {
    match (allowed, value) {
        (AllowedConstraintValue::None, None) => Ok(()),
        (AllowedConstraintValue::None, Some(_)) => Err(CommandError::InvalidValue {
            field,
            reason: "must not include a value",
        }),
        (AllowedConstraintValue::Length, Some(ConstraintValue::FixedMm(length_mm))) => {
            validate_non_negative_finite(field, *length_mm)
        }
        (AllowedConstraintValue::Length, Some(ConstraintValue::Parameter(_))) => Ok(()),
        (AllowedConstraintValue::Length, Some(ConstraintValue::FixedDegrees(_))) => {
            Err(CommandError::InvalidValue {
                field,
                reason: "must use a millimeter value",
            })
        }
        (AllowedConstraintValue::Length, None) => Err(CommandError::InvalidValue {
            field,
            reason: "must include a value",
        }),
        (AllowedConstraintValue::Degrees, Some(ConstraintValue::FixedDegrees(value_degrees))) => {
            if value_degrees.is_finite() {
                Ok(())
            } else {
                Err(CommandError::InvalidValue {
                    field,
                    reason: "must be finite",
                })
            }
        }
        (AllowedConstraintValue::Degrees, Some(_)) => Err(CommandError::InvalidValue {
            field,
            reason: "must use a degree value",
        }),
        (AllowedConstraintValue::Degrees, None) => Err(CommandError::InvalidValue {
            field,
            reason: "must include a value",
        }),
    }
}

pub(in crate::document) fn resolve_length_value_mm(
    parameters: &[Parameter],
    value: Option<&ConstraintValue>,
    field: &'static str,
) -> Result<f64, CommandError> {
    match value {
        Some(ConstraintValue::FixedMm(length_mm)) => {
            validate_non_negative_finite(field, *length_mm)?;
            Ok(*length_mm)
        }
        Some(ConstraintValue::Parameter(parameter_id)) => {
            let parameter = parameters
                .iter()
                .find(|parameter| parameter.id == *parameter_id)
                .ok_or_else(|| {
                    CommandError::broken_reference("constraint", "parameter", parameter_id)
                })?;
            validate_non_negative_finite(field, parameter.value_mm)?;
            Ok(parameter.value_mm)
        }
        Some(ConstraintValue::FixedDegrees(_)) => Err(CommandError::InvalidValue {
            field,
            reason: "must use a millimeter value",
        }),
        None => Err(CommandError::InvalidValue {
            field,
            reason: "must include a value",
        }),
    }
}

pub(in crate::document) fn resolve_degrees_value(
    value: Option<&ConstraintValue>,
    field: &'static str,
) -> Result<f64, CommandError> {
    match value {
        Some(ConstraintValue::FixedDegrees(value_degrees)) if value_degrees.is_finite() => {
            Ok(*value_degrees)
        }
        Some(ConstraintValue::FixedDegrees(_)) => Err(CommandError::InvalidValue {
            field,
            reason: "must be finite",
        }),
        Some(_) => Err(CommandError::InvalidValue {
            field,
            reason: "must use a degree value",
        }),
        None => Err(CommandError::InvalidValue {
            field,
            reason: "must include a value",
        }),
    }
}

impl ProjectDocument {
    /// 現在のドキュメント全体を検証する。
    pub fn validate(&self) -> Result<(), DocumentValidationError> {
        if self.file_format_version != FILE_FORMAT_VERSION {
            return Err(DocumentValidationError::UnsupportedFileFormatVersion {
                found: self.file_format_version.clone(),
            });
        }
        if self.schema_version != SCHEMA_VERSION {
            return Err(DocumentValidationError::UnsupportedSchemaVersion {
                found: self.schema_version.clone(),
            });
        }
        if self.metadata.id.trim().is_empty() {
            return Err(DocumentValidationError::EmptyId("document metadata"));
        }
        if self.metadata.unit != "mm" {
            return Err(DocumentValidationError::InvalidValue {
                field: "document unit",
                reason: "must be mm",
            });
        }

        let layer_ids = validate_collection_ids(
            self.layers.iter().map(|layer| ("layer", layer.id.as_str())),
            "layer",
        )?;
        let shared_style_ids = validate_collection_ids(
            self.shared_styles
                .iter()
                .map(|style| ("shared style", style.id.as_str())),
            "shared style",
        )?;
        let parameter_ids = validate_collection_ids(
            self.parameters
                .iter()
                .map(|parameter| ("parameter", parameter.id.as_str())),
            "parameter",
        )?;
        let entity_ids = validate_collection_ids(
            self.entities
                .iter()
                .map(|entity| ("entity", entity.id.as_str())),
            "entity",
        )?;
        validate_collection_ids(
            self.round_holes
                .iter()
                .map(|round_hole| ("round hole", round_hole.id.as_str())),
            "round hole",
        )?;
        validate_collection_ids(
            self.stitch_start_points
                .iter()
                .map(|stitch_start_point| ("stitch start point", stitch_start_point.id.as_str())),
            "stitch start point",
        )?;
        validate_collection_ids(
            self.constraints
                .iter()
                .map(|constraint| ("constraint", constraint.id.as_str())),
            "constraint",
        )?;
        let derived_element_ids = validate_collection_ids(
            self.derived_elements
                .iter()
                .map(|derived_element| ("derived element", derived_element.id.as_str())),
            "derived element",
        )?;
        let free_text_ids = validate_collection_ids(
            self.free_texts
                .iter()
                .map(|item| ("free text", item.id.as_str())),
            "free text",
        )?;
        let measurement_annotation_ids = validate_collection_ids(
            self.view_annotations
                .measurement_annotations
                .iter()
                .map(|annotation| ("measurement annotation", annotation.id.as_str())),
            "measurement annotation",
        )?;

        for parameter in &self.parameters {
            validate_parameter(parameter).map_err(DocumentValidationError::from)?;
        }

        for shared_style in &self.shared_styles {
            validate_shared_style(shared_style).map_err(DocumentValidationError::from)?;
        }

        for entity in &self.entities {
            entity
                .validate()
                .map_err(|error| DocumentValidationError::InvalidEntity {
                    entity_id: entity.id.clone(),
                    error,
                })?;
            if let Some(layer_id) = &entity.layer_id {
                ensure_id_in_set("entity", "layer", layer_id, &layer_ids)?;
            }
            if let Some(style_id) = &entity.style_id {
                ensure_id_in_set("entity", "shared style", style_id, &shared_style_ids)?;
            }
        }

        for derived_element in &self.derived_elements {
            if let Some(layer_id) = &derived_element.layer_id {
                ensure_id_in_set("derived element", "layer", layer_id, &layer_ids)?;
            }
            if let Some(style_id) = &derived_element.style_id {
                ensure_id_in_set(
                    "derived element",
                    "shared style",
                    style_id,
                    &shared_style_ids,
                )?;
            }
            for source_id in derived_element_source_ids(derived_element) {
                if !entity_ids.contains(source_id.as_str())
                    && !derived_element_ids.contains(source_id.as_str())
                {
                    return Err(DocumentValidationError::BrokenReference {
                        source: "derived element",
                        target_kind: "source",
                        target_id: source_id.clone(),
                    });
                }
            }
        }

        for round_hole in &self.round_holes {
            ensure_id_in_set("round hole", "entity", &round_hole.entity_id, &entity_ids)?;
            let Some(entity) = self
                .entities
                .iter()
                .find(|entity| entity.id == round_hole.entity_id)
            else {
                return Err(DocumentValidationError::BrokenReference {
                    source: "round hole",
                    target_kind: "entity",
                    target_id: round_hole.entity_id.clone(),
                });
            };
            if !matches!(entity.kind, EntityKind::Circle(_)) {
                return Err(DocumentValidationError::InvalidValue {
                    field: "round hole entity",
                    reason: "must reference a circle",
                });
            }
        }

        for stitch_start_point in &self.stitch_start_points {
            validate_stitch_start_point(self, stitch_start_point).map_err(|error| {
                DocumentValidationError::InvalidValue {
                    field: "stitch start point",
                    reason: match error {
                        CommandError::InvalidValue { reason, .. } => reason,
                        CommandError::BrokenReference { .. } => "target must exist",
                        _ => "must reference a valid stitch line",
                    },
                }
            })?;
        }

        for constraint in &self.constraints {
            if constraint.targets.is_empty() {
                return Err(DocumentValidationError::InvalidValue {
                    field: "constraint targets",
                    reason: "must include at least one target",
                });
            }
            for target in &constraint.targets {
                ensure_id_in_set(
                    "constraint",
                    "entity",
                    constraint_target_entity_id(target),
                    &entity_ids,
                )?;
            }
            if let Some(ConstraintValue::Parameter(parameter_id)) = &constraint.value {
                ensure_id_in_set("constraint", "parameter", parameter_id, &parameter_ids)?;
            }
            validate_constraint_semantics(self, constraint)
                .map_err(DocumentValidationError::from)?;
        }

        for derived_element in &self.derived_elements {
            self.validate_derived_element(derived_element)
                .map_err(DocumentValidationError::from)?;
            self.resolve_derived_element(derived_element)
                .map_err(DocumentValidationError::from)?;
        }

        for annotation in &self.view_annotations.measurement_annotations {
            for target in &annotation.targets {
                ensure_id_in_set(
                    "measurement annotation",
                    "entity",
                    constraint_target_entity_id(target),
                    &entity_ids,
                )?;
            }
        }

        for part in &self.parts {
            if !part.locked {
                return Err(DocumentValidationError::InvalidValue {
                    field: "part fixed",
                    reason: "must be true",
                });
            }
            for entity_id in part
                .outline_entity_ids
                .iter()
                .chain(part.hole_entity_id_groups.iter().flatten())
                .chain(part.entity_ids.iter())
            {
                ensure_id_in_set("part", "entity", entity_id, &entity_ids)?;
            }
            for derived_element_id in &part.derived_element_ids {
                ensure_id_in_set(
                    "part",
                    "derived element",
                    derived_element_id,
                    &derived_element_ids,
                )?;
            }
            for free_text_id in &part.free_text_ids {
                ensure_id_in_set("part", "free text", free_text_id, &free_text_ids)?;
            }
            for annotation_id in &part.measurement_annotation_ids {
                ensure_id_in_set(
                    "part",
                    "measurement annotation",
                    annotation_id,
                    &measurement_annotation_ids,
                )?;
            }
            if !part
                .outline_entity_ids
                .iter()
                .all(|id| part.entity_ids.contains(id))
                || !part
                    .hole_entity_id_groups
                    .iter()
                    .flatten()
                    .all(|id| part.entity_ids.contains(id))
            {
                return Err(DocumentValidationError::InvalidValue {
                    field: "part entityIds",
                    reason: "must contain outline and hole entities",
                });
            }
        }
        validate_parts_for_document(self)?;

        Ok(())
    }
}
