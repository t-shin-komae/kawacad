use super::*;
use crate::geometry::EntityId;
use crate::parameters::ParameterId;
use crate::round_holes::{RoundHoleId, RoundHoleKind};

pub(in crate::document) struct CommandApplier;

struct CreateEntityFromGestureRequest {
    id: String,
    layer_id: Option<String>,
    style_id: Option<String>,
    gesture: EntityGesture,
    start_snap: Option<GestureSnapConstraint>,
    end_snap: Option<GestureSnapConstraint>,
    axis_constraint_id: Option<String>,
}

impl CommandApplier {
    pub(in crate::document) fn apply_command_without_history(
        document: &mut ProjectDocument,
        command: DocumentCommand,
    ) -> CommandResult {
        if let DocumentCommand::Compound(commands) = command {
            return Self::apply_compound(document, commands);
        }

        Self::apply_command_without_history_with_context(document, command, None)
    }

    fn apply_compound(
        document: &mut ProjectDocument,
        commands: Vec<DocumentCommand>,
    ) -> CommandResult {
        if commands.is_empty() {
            return Err(CommandError::InvalidValue {
                field: "compound",
                reason: "must include at least one command",
            });
        }
        let compound_deleted_entity_ids = commands
            .iter()
            .filter_map(|command| match command {
                DocumentCommand::DeleteEntity(entity_id) => Some(entity_id.clone()),
                _ => None,
            })
            .collect::<BTreeSet<_>>();
        for command in commands {
            if matches!(command, DocumentCommand::Compound(_)) {
                return Err(CommandError::InvalidValue {
                    field: "compound",
                    reason: "nested compound commands are not supported",
                });
            }
            Self::apply_command_without_history_with_context(
                document,
                command,
                Some(&compound_deleted_entity_ids),
            )?;
        }
        Ok(())
    }

    fn apply_command_without_history_with_context(
        document: &mut ProjectDocument,
        command: DocumentCommand,
        compound_deleted_entity_ids: Option<&BTreeSet<String>>,
    ) -> CommandResult {
        match command {
            DocumentCommand::RenameDocument { name } => document.rename_document(&name),
            DocumentCommand::SetPrintOrientation { orientation } => {
                document.set_print_orientation(orientation)
            }
            DocumentCommand::AddEntity(entity) => document.add_entity(entity),
            DocumentCommand::CreateEntityFromGesture {
                id,
                layer_id,
                style_id,
                gesture,
                start_snap,
                end_snap,
                axis_constraint_id,
            } => document.create_entity_from_gesture(CreateEntityFromGestureRequest {
                id,
                layer_id,
                style_id,
                gesture,
                start_snap,
                end_snap,
                axis_constraint_id,
            }),
            DocumentCommand::UpdateEntity(entity) => document.update_entity(entity),
            DocumentCommand::MoveEntities {
                entity_ids,
                delta,
                allow_single_line_stretch,
            } => document.move_entities(entity_ids, delta, allow_single_line_stretch),
            DocumentCommand::MoveControlPoint {
                target,
                position,
                allow_projection,
            } => document.move_control_point(target, position, allow_projection),
            DocumentCommand::SetEntityMetric { entity_id, metric } => {
                document.set_entity_metric(&entity_id, metric)
            }
            DocumentCommand::SetEntityLayer {
                entity_id,
                layer_id,
            } => document.set_entity_layer(&entity_id, layer_id.as_deref()),
            DocumentCommand::SmoothArcTangencies { arc_entity_id } => {
                document.smooth_arc_tangencies(&arc_entity_id)
            }
            DocumentCommand::DeleteEntity(entity_id) => {
                document.delete_entity_with_context(&entity_id, compound_deleted_entity_ids)
            }
            DocumentCommand::AddDerivedElement(derived_element) => {
                document.add_derived_element(derived_element)
            }
            DocumentCommand::UpdateDerivedElement(derived_element) => {
                document.update_derived_element(derived_element)
            }
            DocumentCommand::SetDerivedDistance {
                derived_element_id,
                value,
            } => document.set_derived_distance(&derived_element_id, value),
            DocumentCommand::SetDerivedRadius {
                derived_element_id,
                value,
            } => document.set_derived_radius(&derived_element_id, value),
            DocumentCommand::SetDerivedRadiusFromPoint {
                derived_element_id,
                resolved_index,
                position,
            } => document.set_derived_radius_from_point(
                &derived_element_id,
                resolved_index,
                position,
            ),
            DocumentCommand::SetDerivedDirection {
                derived_element_id,
                direction,
            } => document.set_derived_direction(&derived_element_id, direction),
            DocumentCommand::SetDerivedLayer {
                derived_element_id,
                layer_id,
            } => document.set_derived_layer(&derived_element_id, layer_id.as_deref()),
            DocumentCommand::SetDerivedSharedStyle {
                derived_element_id,
                style_id,
            } => document.set_derived_shared_style(&derived_element_id, style_id.as_deref()),
            DocumentCommand::SetFilletSources {
                derived_element_id,
                source_entity_ids,
                closed,
            } => document.set_fillet_sources(&derived_element_id, source_entity_ids, closed),
            DocumentCommand::DeleteDerivedElement(derived_element_id) => {
                document.delete_derived_element(&derived_element_id)
            }
            DocumentCommand::AddFreeText(free_text) => document.add_free_text(free_text),
            DocumentCommand::UpdateFreeText(free_text) => document.update_free_text(free_text),
            DocumentCommand::DeleteFreeText(free_text_id) => delete_by_id(
                &mut document.free_texts,
                "free text",
                &free_text_id,
                |free_text| &free_text.id,
            ),
            DocumentCommand::AddRoundHole(round_hole) => document.add_round_hole(round_hole),
            DocumentCommand::UpdateRoundHole(round_hole) => document.update_round_hole(round_hole),
            DocumentCommand::CreateRoundHole {
                id,
                entity_id,
                center,
                diameter_mm,
                round_hole_kind,
                layer_id,
                style_id,
            } => document.create_round_hole(
                id,
                entity_id,
                center,
                diameter_mm,
                round_hole_kind,
                layer_id,
                style_id,
            ),
            DocumentCommand::SetRoundHoleDiameter {
                round_hole_id,
                diameter_mm,
            } => document.set_round_hole_diameter(&round_hole_id, diameter_mm),
            DocumentCommand::SetRoundHoleKind {
                round_hole_id,
                kind,
            } => document.set_round_hole_kind(&round_hole_id, kind),
            DocumentCommand::DeleteRoundHole(round_hole_id) => delete_by_id(
                &mut document.round_holes,
                "round hole",
                &round_hole_id,
                |round_hole| &round_hole.id,
            ),
            DocumentCommand::AddStitchStartPoint(stitch_start_point) => {
                document.add_stitch_start_point(stitch_start_point)
            }
            DocumentCommand::PlaceStitchStartPoint {
                id,
                position,
                candidate_target_ids,
                max_distance_mm,
            } => document.place_stitch_start_point(
                id,
                position,
                candidate_target_ids,
                max_distance_mm,
            ),
            DocumentCommand::UpdateStitchStartPoint(stitch_start_point) => {
                document.update_stitch_start_point(stitch_start_point)
            }
            DocumentCommand::DeleteStitchStartPoint(stitch_start_point_id) => delete_by_id(
                &mut document.stitch_start_points,
                "stitch start point",
                &stitch_start_point_id,
                |stitch_start_point| &stitch_start_point.id,
            ),
            DocumentCommand::AddLayer(layer) => document.add_layer(layer),
            DocumentCommand::RenameLayer { layer_id, name } => {
                document.rename_layer(&layer_id, &name)
            }
            DocumentCommand::DeleteLayer(layer_id) => document.delete_layer(&layer_id),
            DocumentCommand::SetLayerVisibility { layer_id, visible } => {
                document.set_layer_visibility(&layer_id, visible)
            }
            DocumentCommand::SetLayerPrintable {
                layer_id,
                printable,
            } => document.set_layer_printable(&layer_id, printable),
            DocumentCommand::SetLayerStyle { layer_id, style } => {
                document.set_layer_style(&layer_id, style)
            }
            DocumentCommand::AddSharedStyle(style) => document.add_shared_style(style),
            DocumentCommand::UpdateSharedStyle(style) => document.update_shared_style(style),
            DocumentCommand::DeleteSharedStyle(style_id) => document.delete_shared_style(&style_id),
            DocumentCommand::SetEntitySharedStyle {
                entity_id,
                style_id,
            } => document.set_entity_shared_style(&entity_id, style_id.as_deref()),
            DocumentCommand::AddConstraint(constraint) => document.add_constraint(constraint),
            DocumentCommand::UpdateConstraint(constraint) => document.update_constraint(constraint),
            DocumentCommand::SetConstraintValue {
                constraint_id,
                value,
            } => document.set_constraint_value(&constraint_id, value),
            DocumentCommand::SetConstraintParameter {
                constraint_id,
                parameter_id,
            } => document.set_constraint_parameter(&constraint_id, parameter_id),
            DocumentCommand::DeleteConstraint(constraint_id) => {
                document.delete_constraint(&constraint_id)
            }
            DocumentCommand::AddMeasurementAnnotation(annotation) => {
                document.add_measurement_annotation(annotation)
            }
            DocumentCommand::UpdateMeasurementAnnotation(annotation) => {
                document.update_measurement_annotation(annotation)
            }
            DocumentCommand::MoveMeasurementAnnotation {
                annotation_id,
                delta,
                label_only,
            } => document.move_measurement_annotation(&annotation_id, delta, label_only),
            DocumentCommand::DeleteMeasurementAnnotation(annotation_id) => delete_by_id(
                &mut document.view_annotations.measurement_annotations,
                "measurement annotation",
                &annotation_id,
                |annotation| &annotation.id,
            ),
            DocumentCommand::ConvertMeasurementToConstraint {
                annotation_id,
                constraint_id,
            } => document.convert_measurement_to_constraint(&annotation_id, constraint_id),
            DocumentCommand::AddDimensionConstraintAnnotation(annotation) => {
                document.add_dimension_constraint_annotation(annotation)
            }
            DocumentCommand::UpdateDimensionConstraintAnnotation(annotation) => {
                document.update_dimension_constraint_annotation(annotation)
            }
            DocumentCommand::MoveDimensionConstraintAnnotation {
                constraint_id,
                delta,
                label_only,
            } => document.move_dimension_constraint_annotation(&constraint_id, delta, label_only),
            DocumentCommand::DeleteDimensionConstraintAnnotation(constraint_id) => delete_by_id(
                &mut document.view_annotations.dimension_constraint_annotations,
                "dimension constraint annotation",
                &constraint_id,
                |annotation| &annotation.constraint_id,
            ),
            DocumentCommand::AddParameter(parameter) => document.add_parameter(parameter),
            DocumentCommand::UpdateParameter(parameter) => document.update_parameter(parameter),
            DocumentCommand::DeleteParameter {
                parameter_id,
                replacement_value_mm,
            } => document.delete_parameter(&parameter_id, replacement_value_mm),
            DocumentCommand::SetParameterValue {
                parameter_id,
                value_mm,
            } => document.set_parameter_value(&parameter_id, value_mm),
            DocumentCommand::CreatePart {
                id,
                name,
                origin_mm,
                entity_ids,
            } => document.create_part(id, name, origin_mm, entity_ids),
            DocumentCommand::UpdatePart {
                id,
                name,
                origin_mm,
            } => document.update_part(&id, &name, origin_mm),
            DocumentCommand::RenamePart { part_id, name } => document.rename_part(&part_id, &name),
            DocumentCommand::SetPartVisibility { part_id, visible } => {
                document.set_part_visibility(&part_id, visible)
            }
            DocumentCommand::SetPartPrintable { part_id, printable } => {
                document.set_part_printable(&part_id, printable)
            }
            DocumentCommand::SetPartQuantity { part_id, quantity } => {
                document.set_part_quantity(&part_id, quantity)
            }
            DocumentCommand::UpdatePartSettings {
                part_id,
                visible,
                printable,
                locked,
                quantity,
            } => document.update_part_settings(&part_id, visible, printable, locked, quantity),
            DocumentCommand::DeletePart(part_id) => document.delete_part(&part_id),
            DocumentCommand::MovePart { part_id, delta } => document.move_part(&part_id, delta),
            DocumentCommand::SetPartPosition { part_id, position } => {
                document.set_part_position(&part_id, position)
            }
            DocumentCommand::DuplicatePart {
                part_id,
                new_part_id,
                new_name,
                id_namespace,
                delta,
            } => document.duplicate_part(&part_id, new_part_id, new_name, &id_namespace, delta),
            DocumentCommand::InsertPartLibraryItem {
                library_json,
                legacy_source_part,
                new_part_id,
                new_name,
                id_namespace,
                delta,
            } => document.insert_part_library_item(
                &library_json,
                legacy_source_part,
                new_part_id,
                new_name,
                &id_namespace,
                delta,
            ),
            DocumentCommand::AddEntitiesToPart {
                part_id,
                entity_ids,
            } => document.add_entities_to_part(&part_id, entity_ids),
            DocumentCommand::RemoveEntitiesFromPart {
                part_id,
                entity_ids,
            } => document.remove_entities_from_part(&part_id, entity_ids),
            DocumentCommand::SetPartBoundary {
                part_id,
                entity_ids,
            } => document.set_part_boundary(&part_id, entity_ids),
            DocumentCommand::AlignParts {
                part_ids,
                alignment,
            } => document.align_parts(part_ids, alignment),
            DocumentCommand::DistributeParts { part_ids, axis } => {
                document.distribute_parts(part_ids, axis)
            }
            DocumentCommand::DuplicateSelection {
                selection,
                id_namespace,
                delta,
            } => document.duplicate_selection(selection, &id_namespace, delta),
            DocumentCommand::PasteSelection {
                clipboard_json,
                id_namespace,
                delta,
            } => document.paste_selection(&clipboard_json, &id_namespace, delta),
            DocumentCommand::Compound(_) => {
                unreachable!("compound is handled before command dispatch")
            }
        }
    }
}

impl ProjectDocument {
    /// 入力ジェスチャーから正規図形と任意の付随拘束を作成する。
    fn create_entity_from_gesture(
        &mut self,
        request: CreateEntityFromGestureRequest,
    ) -> CommandResult {
        let CreateEntityFromGestureRequest {
            id,
            layer_id,
            style_id,
            gesture,
            start_snap,
            end_snap,
            axis_constraint_id,
        } = request;
        let (kind, line_axis) = match gesture {
            EntityGesture::Point { position } => (EntityKind::Point(position), None),
            EntityGesture::Line {
                start,
                mut end,
                center_line,
                axis,
            } => {
                match axis {
                    Some(GestureAxis::Horizontal) => end.y_mm = start.y_mm,
                    Some(GestureAxis::Vertical) => end.x_mm = start.x_mm,
                    None => {}
                }
                let line = LineSegment::new(start, end);
                (
                    if center_line {
                        EntityKind::CenterLine(line)
                    } else {
                        EntityKind::LineSegment(line)
                    },
                    axis,
                )
            }
            EntityGesture::Circle {
                center,
                radius_point,
            } => (
                EntityKind::Circle(Circle {
                    center,
                    radius_mm: (radius_point.x_mm - center.x_mm)
                        .hypot(radius_point.y_mm - center.y_mm),
                }),
                None,
            ),
            EntityGesture::Arc {
                center,
                start,
                end,
                sweep_reference_rad,
            } => {
                let start_angle_rad = (start.y_mm - center.y_mm).atan2(start.x_mm - center.x_mm);
                let end_angle_rad = (end.y_mm - center.y_mm).atan2(end.x_mm - center.x_mm);
                let shortest_sweep = normalize_signed_angle(end_angle_rad - start_angle_rad);
                let sweep_angle_rad = sweep_reference_rad
                    .filter(|reference| reference.is_finite())
                    .map(|reference| {
                        (-1..=1)
                            .map(|turn| shortest_sweep + f64::from(turn) * std::f64::consts::TAU)
                            .min_by(|lhs, rhs| {
                                (lhs - reference).abs().total_cmp(&(rhs - reference).abs())
                            })
                            .unwrap_or(shortest_sweep)
                    })
                    .unwrap_or(shortest_sweep);
                if !sweep_angle_rad.is_finite()
                    || sweep_angle_rad.abs() <= GEOMETRY_EPSILON_MM
                    || sweep_angle_rad.abs() >= std::f64::consts::TAU - GEOMETRY_EPSILON_MM
                {
                    return Err(CommandError::InvalidValue {
                        field: "gesture.sweepAngleRad",
                        reason: "must be a finite non-zero sweep smaller than one turn",
                    });
                }
                (
                    EntityKind::Arc(Arc {
                        center,
                        radius_mm: (start.x_mm - center.x_mm).hypot(start.y_mm - center.y_mm),
                        start_angle_rad,
                        sweep_angle_rad,
                    }),
                    None,
                )
            }
        };

        let is_line = matches!(kind, EntityKind::LineSegment(_) | EntityKind::CenterLine(_));
        if !is_line && (start_snap.is_some() || end_snap.is_some() || axis_constraint_id.is_some())
        {
            return Err(CommandError::InvalidValue {
                field: "gesture constraints",
                reason: "snap and axis constraints require a line gesture",
            });
        }
        if line_axis.is_none() && axis_constraint_id.is_some() {
            return Err(CommandError::InvalidValue {
                field: "axisConstraintId",
                reason: "requires a horizontal or vertical gesture axis",
            });
        }

        let mut entity = Entity::new(id.clone(), kind);
        entity.layer_id = layer_id;
        entity.style_id = style_id;
        self.add_entity(entity)?;

        for (point, snap) in [
            (ControlPointKind::Start, start_snap),
            (ControlPointKind::End, end_snap),
        ] {
            let Some(snap) = snap else { continue };
            self.add_constraint(Constraint {
                id: snap.constraint_id,
                kind: ConstraintKind::Coincident,
                targets: vec![
                    ConstraintTarget::ControlPoint {
                        entity_id: id.clone(),
                        point,
                    },
                    snap.target,
                ],
                value: None,
                status: ConstraintStatus::Unknown,
            })?;
        }
        if let (Some(axis), Some(constraint_id)) = (line_axis, axis_constraint_id) {
            self.add_constraint(Constraint {
                id: constraint_id,
                kind: match axis {
                    GestureAxis::Horizontal => ConstraintKind::Horizontal,
                    GestureAxis::Vertical => ConstraintKind::Vertical,
                },
                targets: vec![ConstraintTarget::Entity(id)],
                value: None,
                status: ConstraintStatus::Unknown,
            })?;
        }
        Ok(())
    }

    /// ドキュメントへエンティティを追加する。
    pub(crate) fn add_entity(&mut self, entity: Entity) -> CommandResult {
        entity.validate().map_err(CommandError::InvalidEntity)?;
        ensure_unique_id(
            self.entities.iter().map(|existing| existing.id.as_str()),
            "entity",
            &entity.id,
        )?;
        if let Some(layer_id) = &entity.layer_id {
            self.ensure_layer_exists("entity", layer_id)?;
        }
        if let Some(style_id) = &entity.style_id {
            self.ensure_shared_style_exists("entity", style_id)?;
        }

        let implicit_constraints = implicit_constraints_for_entity(&entity);
        let entity_id = entity.id.clone();
        self.entities.push(entity);
        self.constraints.extend(implicit_constraints);
        self.auto_assign_entity_to_part(&entity_id);
        Ok(())
    }

    /// ドキュメントへ自由テキストを追加する。
    pub(crate) fn add_free_text(&mut self, free_text: FreeText) -> CommandResult {
        free_text
            .validate()
            .map_err(|error| CommandError::InvalidValue {
                field: "free text",
                reason: match error {
                    crate::free_text::FreeTextValidationError::EmptyId => "id must not be empty",
                    crate::free_text::FreeTextValidationError::EmptyContent => {
                        "content must not be empty"
                    }
                    crate::free_text::FreeTextValidationError::NonFinitePosition => {
                        "position must be finite"
                    }
                    crate::free_text::FreeTextValidationError::InvalidFontSize => {
                        "font size must be a positive finite value"
                    }
                },
            })?;
        ensure_unique_id(
            self.free_texts.iter().map(|existing| existing.id.as_str()),
            "free text",
            &free_text.id,
        )?;
        let free_text_id = free_text.id.clone();
        self.free_texts.push(free_text);
        self.auto_assign_free_text_to_part(&free_text_id);
        Ok(())
    }

    /// 既存自由テキストを検証済みの新しい内容で置き換える。
    pub(crate) fn update_free_text(&mut self, free_text: FreeText) -> CommandResult {
        free_text
            .validate()
            .map_err(|error| CommandError::InvalidValue {
                field: "free text",
                reason: match error {
                    crate::free_text::FreeTextValidationError::EmptyId => "id must not be empty",
                    crate::free_text::FreeTextValidationError::EmptyContent => {
                        "content must not be empty"
                    }
                    crate::free_text::FreeTextValidationError::NonFinitePosition => {
                        "position must be finite"
                    }
                    crate::free_text::FreeTextValidationError::InvalidFontSize => {
                        "font size must be a positive finite value"
                    }
                },
            })?;
        let existing = self
            .free_texts
            .iter_mut()
            .find(|existing| existing.id == free_text.id)
            .ok_or_else(|| CommandError::missing("free text", free_text.id.clone()))?;
        *existing = free_text;
        Ok(())
    }

    /// 円エンティティへ丸穴用途を追加する。
    pub(crate) fn add_round_hole(&mut self, round_hole: RoundHole) -> CommandResult {
        validate_round_hole(self, &round_hole)?;
        ensure_unique_id(
            self.round_holes.iter().map(|existing| existing.id.as_str()),
            "round hole",
            &round_hole.id,
        )?;
        self.round_holes.push(round_hole);
        Ok(())
    }

    pub(crate) fn update_round_hole(&mut self, round_hole: RoundHole) -> CommandResult {
        validate_round_hole(self, &round_hole)?;
        let existing = self
            .round_holes
            .iter_mut()
            .find(|item| item.id == round_hole.id)
            .ok_or_else(|| CommandError::missing("round hole", round_hole.id.clone()))?;
        *existing = round_hole;
        Ok(())
    }

    /// 既存丸穴用途を置き換える。
    /// 作図意図から参照円と丸穴用途を同時に作成する。
    #[allow(clippy::too_many_arguments)]
    pub(crate) fn create_round_hole(
        &mut self,
        id: RoundHoleId,
        entity_id: EntityId,
        center: Point2,
        diameter_mm: f64,
        kind: RoundHoleKind,
        layer_id: Option<String>,
        style_id: Option<String>,
    ) -> CommandResult {
        if !diameter_mm.is_finite() || diameter_mm <= 0.0 {
            return Err(CommandError::InvalidValue {
                field: "round hole diameter",
                reason: "must be a positive finite value",
            });
        }
        let mut entity = Entity::new(
            entity_id.clone(),
            EntityKind::Circle(Circle {
                center,
                radius_mm: diameter_mm / 2.0,
            }),
        );
        entity.layer_id = layer_id;
        entity.style_id = style_id;
        self.add_entity(entity)?;
        self.add_round_hole(RoundHole::new(id, entity_id, kind))
    }

    /// 丸穴用途を保持したまま参照円の直径だけを更新する。
    pub(crate) fn set_round_hole_diameter(
        &mut self,
        round_hole_id: &str,
        diameter_mm: f64,
    ) -> CommandResult {
        if !diameter_mm.is_finite() || diameter_mm <= 0.0 {
            return Err(CommandError::InvalidValue {
                field: "round hole diameter",
                reason: "must be a positive finite value",
            });
        }
        let entity_id = self
            .round_holes
            .iter()
            .find(|round_hole| round_hole.id == round_hole_id)
            .map(|round_hole| round_hole.entity_id.clone())
            .ok_or_else(|| CommandError::missing("round hole", round_hole_id))?;
        self.set_entity_metric(
            &entity_id,
            EntityMetric::CircleRadius {
                value_mm: diameter_mm / 2.0,
            },
        )
    }

    /// 丸穴用途を保持済みの参照円を触らずに変更する。
    pub(crate) fn set_round_hole_kind(
        &mut self,
        round_hole_id: &str,
        kind: RoundHoleKind,
    ) -> CommandResult {
        let round_hole = self
            .round_holes
            .iter_mut()
            .find(|round_hole| round_hole.id == round_hole_id)
            .ok_or_else(|| CommandError::missing("round hole", round_hole_id))?;
        round_hole.kind = kind;
        Ok(())
    }

    /// 縫い線へ紐づく縫い始め点を追加する。
    pub(crate) fn add_stitch_start_point(
        &mut self,
        stitch_start_point: StitchStartPoint,
    ) -> CommandResult {
        validate_stitch_start_point(self, &stitch_start_point)?;
        ensure_unique_id(
            self.stitch_start_points
                .iter()
                .map(|existing| existing.id.as_str()),
            "stitch start point",
            &stitch_start_point.id,
        )?;
        self.stitch_start_points.push(stitch_start_point);
        Ok(())
    }

    /// 既存縫い始め点を置き換える。
    pub(crate) fn update_stitch_start_point(
        &mut self,
        stitch_start_point: StitchStartPoint,
    ) -> CommandResult {
        validate_stitch_start_point(self, &stitch_start_point)?;
        let existing = self
            .stitch_start_points
            .iter_mut()
            .find(|existing| existing.id == stitch_start_point.id)
            .ok_or_else(|| {
                CommandError::missing("stitch start point", stitch_start_point.id.clone())
            })?;
        *existing = stitch_start_point;
        Ok(())
    }

    /// 既存エンティティを検証済みの新しい内容で置き換える。
    pub(crate) fn update_entity(&mut self, entity: Entity) -> CommandResult {
        entity.validate().map_err(CommandError::InvalidEntity)?;
        if let Some(layer_id) = &entity.layer_id {
            self.ensure_layer_exists("entity", layer_id)?;
        }
        if let Some(style_id) = &entity.style_id {
            self.ensure_shared_style_exists("entity", style_id)?;
        }
        let index = self
            .entities
            .iter()
            .position(|existing| existing.id == entity.id)
            .ok_or_else(|| CommandError::missing("entity", entity.id.clone()))?;
        let mut updated_entities = self.entities.clone();
        updated_entities[index] = entity;
        project_entity_update_to_axis_constraints(
            &self.entities[index],
            &mut updated_entities[index],
            &self.constraints,
        );
        project_entity_update_to_connected_axis_constraints(
            &self.entities,
            &mut updated_entities,
            index,
            &self.constraints,
        )?;
        let moved_targets = moved_point_targets_between(&self.entities, &updated_entities);
        if !moved_targets.is_empty() {
            PropagationGraph::new(&self.constraints).propagate_connected_endpoint_changes(
                &self.parameters,
                &mut updated_entities,
                moved_targets.clone(),
            )?;
        }
        let mut solved_entities = ConstraintSolver::solve_constraints_from_entities(
            self,
            &self.parameters,
            &updated_entities,
            &self.constraints,
        )?;
        if !moved_targets.is_empty() {
            PropagationGraph::new(&self.constraints).propagate_connected_endpoint_changes(
                &self.parameters,
                &mut solved_entities,
                moved_targets,
            )?;
        }
        self.ensure_constraints_not_conflicting(solved_entities.clone(), self.constraints.clone())?;
        ensure_round_holes_reference_circles(&self.round_holes, &solved_entities)?;
        ensure_stitch_start_points_resolve(self, &self.stitch_start_points)?;
        self.entities = solved_entities;
        Ok(())
    }

    pub(crate) fn move_entities(
        &mut self,
        entity_ids: Vec<String>,
        delta: Point2,
        allow_single_line_stretch: bool,
    ) -> CommandResult {
        if entity_ids.is_empty() {
            return Err(CommandError::InvalidValue {
                field: "entityIds",
                reason: "moveEntities requires at least one entity",
            });
        }
        validate_point_delta(delta)?;
        let entity_ids = self.normalized_move_entity_ids(entity_ids)?;

        let direct_updates = entity_ids
            .iter()
            .map(|entity_id| {
                let entity = self
                    .entity(entity_id)
                    .ok_or_else(|| CommandError::missing("entity", entity_id.clone()))?;
                Ok(DocumentCommand::UpdateEntity(translated_entity(
                    entity, delta,
                )))
            })
            .collect::<CommandResult<Vec<_>>>()?;

        match apply_candidate_command(self, DocumentCommand::Compound(direct_updates)) {
            Ok(()) => Ok(()),
            Err(direct_error) if allow_single_line_stretch && entity_ids.len() == 1 => {
                let entity_id = &entity_ids[0];
                for candidate in single_line_stretch_candidates(self, entity_id, delta)? {
                    if apply_candidate_command(self, DocumentCommand::UpdateEntity(candidate))
                        .is_ok()
                    {
                        return Ok(());
                    }
                }
                Err(direct_error)
            }
            Err(error) => Err(error),
        }
    }

    fn normalized_move_entity_ids(&self, requested_ids: Vec<String>) -> CommandResult<Vec<String>> {
        let mut normalized = BTreeSet::new();
        for requested_id in requested_ids {
            if self.entity(&requested_id).is_some() {
                let paired_fillet_sources = self
                    .derived_elements
                    .iter()
                    .filter_map(|derived| match &derived.kind {
                        DerivedElementKind::Fillet(fillet)
                            if fillet.source_entity_ids.len() == 2
                                && fillet.source_entity_ids.contains(&requested_id) =>
                        {
                            Some(&fillet.source_entity_ids)
                        }
                        _ => None,
                    })
                    .flatten()
                    .cloned()
                    .collect::<Vec<_>>();
                if paired_fillet_sources.is_empty() {
                    normalized.insert(requested_id);
                } else {
                    normalized.extend(paired_fillet_sources);
                }
                continue;
            }

            let derived = self.derived_elements.iter().find(|derived| {
                self.resolve_derived_element(derived)
                    .is_ok_and(|entities| entities.iter().any(|entity| entity.id == requested_id))
            });
            match derived.map(|item| &item.kind) {
                Some(DerivedElementKind::Fillet(fillet)) => {
                    normalized.extend(fillet.source_entity_ids.iter().cloned());
                }
                Some(DerivedElementKind::OffsetCurve(_)) => {
                    return Err(CommandError::InvalidValue {
                        field: "entityIds",
                        reason: "resolved offset geometry cannot be moved directly",
                    });
                }
                None => return Err(CommandError::missing("entity", requested_id)),
            }
        }
        Ok(normalized.into_iter().collect())
    }

    pub(crate) fn move_control_point(
        &mut self,
        target: ConstraintTarget,
        position: Point2,
        allow_projection: bool,
    ) -> CommandResult {
        validate_point_delta(position)?;
        let entity_id = constraint_target_entity_id(&target).to_owned();
        let entity = self
            .entity(&entity_id)
            .ok_or_else(|| CommandError::missing("entity", entity_id.clone()))?;
        let entity = entity.clone();
        let direct = entity_with_control_point(&entity, &target, position)?;

        match apply_candidate_command(self, DocumentCommand::UpdateEntity(direct)) {
            Ok(()) => Ok(()),
            Err(direct_error) if allow_projection => {
                let Some(projected) =
                    projected_line_control_point_move(&entity, &target, position)?
                else {
                    return Err(direct_error);
                };
                apply_candidate_command(self, DocumentCommand::UpdateEntity(projected))
                    .map_err(|_| direct_error)
            }
            Err(error) => Err(error),
        }
    }

    /// ドキュメント名を更新する。
    pub(crate) fn rename_document(&mut self, name: &str) -> CommandResult {
        let trimmed = name.trim();
        if trimmed.is_empty() {
            return Err(CommandError::InvalidValue {
                field: "document name",
                reason: "must not be empty",
            });
        }
        self.metadata.name = trimmed.to_owned();
        Ok(())
    }

    fn delete_entity_with_context(
        &mut self,
        entity_id: &str,
        compound_deleted_entity_ids: Option<&BTreeSet<String>>,
    ) -> CommandResult {
        delete_by_id(&mut self.entities, "entity", entity_id, |entity| &entity.id)?;

        self.constraints
            .retain(|constraint| !constraint_targets_entity(constraint, entity_id));
        self.remove_measurement_annotations_for_entity(entity_id);
        self.round_holes
            .retain(|round_hole| round_hole.entity_id != entity_id);
        self.stitch_start_points
            .retain(|stitch_start_point| stitch_start_point.target_id != entity_id);
        let mut removed_ids = self
            .derived_elements
            .iter()
            .filter(|derived_element| derived_element_references_entity(derived_element, entity_id))
            .map(|derived_element| derived_element.id.clone())
            .collect::<BTreeSet<_>>();
        for derived_element_id in removed_ids.clone() {
            self.collect_dependent_derived_element_ids(&derived_element_id, &mut removed_ids);
        }
        let warning_ids = if let Some(deleted_entity_ids) = compound_deleted_entity_ids {
            removed_ids
                .iter()
                .filter(|derived_element_id| {
                    !self.derived_element_sources_are_all_deleted(
                        derived_element_id,
                        deleted_entity_ids,
                    )
                })
                .cloned()
                .collect()
        } else {
            removed_ids.clone()
        };
        self.derived_elements
            .retain(|derived_element| !removed_ids.contains(&derived_element.id));
        self.push_removed_derived_warnings(warning_ids);

        Ok(())
    }

    /// 描画レイヤーを追加する。
    pub(crate) fn add_layer(&mut self, layer: Layer) -> CommandResult {
        validate_layer(&layer)?;
        ensure_unique_id(
            self.layers.iter().map(|existing| existing.id.as_str()),
            "layer",
            &layer.id,
        )?;
        ensure_unique_layer_name(self.layers.iter(), &layer.name, None)?;
        self.layers.push(layer);
        Ok(())
    }

    /// レイヤー名を更新する。
    pub(crate) fn rename_layer(&mut self, layer_id: &str, name: &str) -> CommandResult {
        let trimmed = name.trim();
        if trimmed.is_empty() {
            return Err(CommandError::InvalidValue {
                field: "layer name",
                reason: "must not be empty",
            });
        }
        ensure_unique_layer_name(self.layers.iter(), trimmed, Some(layer_id))?;
        let layer = self
            .layers
            .iter_mut()
            .find(|layer| layer.id == layer_id)
            .ok_or_else(|| CommandError::missing("layer", layer_id))?;
        layer.name = trimmed.to_owned();
        Ok(())
    }

    /// レイヤーを削除し、参照中のエンティティを残りのレイヤーへ付け替える。
    pub(crate) fn delete_layer(&mut self, layer_id: &str) -> CommandResult {
        let index = self
            .layers
            .iter()
            .position(|layer| layer.id == layer_id)
            .ok_or_else(|| CommandError::missing("layer", layer_id))?;
        if self.layers.len() <= 1 {
            return Err(CommandError::InvalidValue {
                field: "layer",
                reason: "must keep at least one layer",
            });
        }
        let fallback_layer_id = self
            .layers
            .iter()
            .find(|layer| layer.id != layer_id)
            .map(|layer| layer.id.clone())
            .ok_or(CommandError::InvalidValue {
                field: "layer",
                reason: "must keep at least one layer",
            })?;

        self.layers.remove(index);
        for entity in &mut self.entities {
            if entity.layer_id.as_deref() == Some(layer_id) {
                entity.layer_id = Some(fallback_layer_id.clone());
            }
        }
        for derived_element in &mut self.derived_elements {
            if derived_element.layer_id.as_deref() == Some(layer_id) {
                derived_element.layer_id = Some(fallback_layer_id.clone());
            }
        }
        Ok(())
    }

    /// レイヤーの表示状態を更新する。
    pub(crate) fn set_layer_visibility(&mut self, layer_id: &str, visible: bool) -> CommandResult {
        let layer = self
            .layers
            .iter_mut()
            .find(|layer| layer.id == layer_id)
            .ok_or_else(|| CommandError::missing("layer", layer_id))?;
        layer.visible = visible;
        Ok(())
    }

    /// レイヤーの印刷対象状態を更新する。
    pub(crate) fn set_layer_printable(&mut self, layer_id: &str, printable: bool) -> CommandResult {
        let layer = self
            .layers
            .iter_mut()
            .find(|layer| layer.id == layer_id)
            .ok_or_else(|| CommandError::missing("layer", layer_id))?;
        if printable && layer.kind == LayerKind::Construction {
            return Err(CommandError::InvalidValue {
                field: "layer printable",
                reason: "construction layers must stay non-printable",
            });
        }
        layer.printable = printable;
        Ok(())
    }

    /// レイヤーの線スタイルを更新する。
    pub(crate) fn set_layer_style(&mut self, layer_id: &str, style: LayerStyle) -> CommandResult {
        validate_layer_style(&style)?;
        let layer = self
            .layers
            .iter_mut()
            .find(|layer| layer.id == layer_id)
            .ok_or_else(|| CommandError::missing("layer", layer_id))?;
        layer.style = style;
        Ok(())
    }

    /// 共有スタイルを追加する。
    pub(crate) fn add_shared_style(&mut self, style: SharedStyle) -> CommandResult {
        validate_shared_style(&style)?;
        ensure_unique_id(
            self.shared_styles
                .iter()
                .map(|existing| existing.id.as_str()),
            "shared style",
            &style.id,
        )?;
        self.shared_styles.push(style);
        Ok(())
    }

    /// 既存共有スタイルを置き換える。
    pub(crate) fn update_shared_style(&mut self, style: SharedStyle) -> CommandResult {
        validate_shared_style(&style)?;
        let existing = self
            .shared_styles
            .iter_mut()
            .find(|existing| existing.id == style.id)
            .ok_or_else(|| CommandError::missing("shared style", style.id.clone()))?;
        *existing = style;
        Ok(())
    }

    /// 共有スタイルを削除し、参照中の図形はスタイル未設定へ戻す。
    pub(crate) fn delete_shared_style(&mut self, style_id: &str) -> CommandResult {
        delete_by_id(&mut self.shared_styles, "shared style", style_id, |style| {
            &style.id
        })?;
        for entity in &mut self.entities {
            if entity.style_id.as_deref() == Some(style_id) {
                entity.style_id = None;
            }
        }
        for derived_element in &mut self.derived_elements {
            if derived_element.style_id.as_deref() == Some(style_id) {
                derived_element.style_id = None;
            }
        }
        Ok(())
    }

    /// エンティティへ共有スタイルを適用または解除する。
    pub(crate) fn set_entity_shared_style(
        &mut self,
        entity_id: &str,
        style_id: Option<&str>,
    ) -> CommandResult {
        if let Some(style_id) = style_id {
            self.ensure_shared_style_exists("entity", style_id)?;
        }
        let entity = self
            .entities
            .iter_mut()
            .find(|entity| entity.id == entity_id)
            .ok_or_else(|| CommandError::missing("entity", entity_id))?;
        entity.style_id = style_id.map(str::to_owned);
        Ok(())
    }

    pub(crate) fn set_entity_layer(
        &mut self,
        entity_id: &str,
        layer_id: Option<&str>,
    ) -> CommandResult {
        if let Some(layer_id) = layer_id {
            self.ensure_layer_exists("entity", layer_id)?;
        }
        let entity = self
            .entities
            .iter_mut()
            .find(|entity| entity.id == entity_id)
            .ok_or_else(|| CommandError::missing("entity", entity_id))?;
        entity.layer_id = layer_id.map(str::to_owned);
        Ok(())
    }

    /// 対象とパラメータ参照を確認した上で拘束を追加する。
    pub(crate) fn add_constraint(&mut self, constraint: Constraint) -> CommandResult {
        ensure_non_empty_id("constraint", &constraint.id)?;
        ensure_unique_id(
            self.constraints.iter().map(|existing| existing.id.as_str()),
            "constraint",
            &constraint.id,
        )?;
        for target in &constraint.targets {
            let entity_id = constraint_target_entity_id(target);
            self.ensure_entity_exists("constraint", entity_id)?;
        }

        if let Some(ConstraintValue::Parameter(parameter_id)) = &constraint.value {
            self.ensure_parameter_exists("constraint", parameter_id)?;
        }

        validate_constraint_semantics(self, &constraint)?;
        self.ensure_no_equivalent_constraint(&constraint)?;

        let mut accepted_constraint = constraint.clone();
        let mut updated_constraints = self.constraints.clone();
        updated_constraints.push(accepted_constraint.clone());
        let mut updated_entities = ConstraintSolver::solve_constraints_from_entities(
            self,
            &self.parameters,
            &self.entities,
            &updated_constraints,
        )?;
        if let Err(error) = self.ensure_constraints_not_conflicting(
            updated_entities.clone(),
            updated_constraints.clone(),
        ) {
            if matches!(constraint.kind, ConstraintKind::Coincident) {
                let mut reversed_constraint = constraint.clone();
                reversed_constraint.targets.reverse();
                let mut reversed_constraints = self.constraints.clone();
                reversed_constraints.push(reversed_constraint.clone());
                updated_entities = ConstraintSolver::solve_constraints_from_entities(
                    self,
                    &self.parameters,
                    &self.entities,
                    &reversed_constraints,
                )?;
                self.ensure_constraints_not_conflicting(
                    updated_entities.clone(),
                    reversed_constraints,
                )?;
                accepted_constraint = reversed_constraint;
            } else {
                return Err(error);
            }
        }

        self.entities = updated_entities;
        self.constraints.push(accepted_constraint);
        Ok(())
    }

    fn ensure_no_equivalent_constraint(&self, candidate: &Constraint) -> CommandResult {
        if let Some(existing) = self
            .constraints
            .iter()
            .find(|existing| constraints_are_equivalent(self, existing, candidate))
        {
            return Err(CommandError::Constraint(Box::new(ConstraintCommandError {
                code: ConstraintCommandErrorCode::Duplicate,
                constraint_kind: candidate.kind,
                constraint_id: candidate.id.clone(),
                target_ids: candidate.targets.iter().map(constraint_target_id).collect(),
                actual_target_count: Some(candidate.targets.len()),
                required_target_count: None,
                expected_target_kinds: Vec::new(),
                invalid_target_ids: Vec::new(),
                existing_constraint_id: Some(existing.id.clone()),
                conflicting_constraint_ids: Vec::new(),
            })));
        }
        Ok(())
    }

    /// 既存拘束を検証済みの新しい内容で置き換える。
    pub(crate) fn update_constraint(&mut self, constraint: Constraint) -> CommandResult {
        ensure_non_empty_id("constraint", &constraint.id)?;
        for target in &constraint.targets {
            let entity_id = constraint_target_entity_id(target);
            self.ensure_entity_exists("constraint", entity_id)?;
        }

        if let Some(ConstraintValue::Parameter(parameter_id)) = &constraint.value {
            self.ensure_parameter_exists("constraint", parameter_id)?;
        }

        validate_constraint_semantics(self, &constraint)?;

        let index = self
            .constraints
            .iter()
            .position(|existing| existing.id == constraint.id)
            .ok_or_else(|| CommandError::missing("constraint", constraint.id.clone()))?;

        let mut accepted_constraint = constraint.clone();
        let mut updated_constraints = self.constraints.clone();
        updated_constraints[index] = accepted_constraint.clone();
        let mut updated_entities = ConstraintSolver::solve_constraints_from_entities(
            self,
            &self.parameters,
            &self.entities,
            &updated_constraints,
        )?;
        if let Err(error) = self.ensure_constraints_not_conflicting(
            updated_entities.clone(),
            updated_constraints.clone(),
        ) {
            if matches!(constraint.kind, ConstraintKind::Coincident) {
                let mut reversed_constraint = constraint.clone();
                reversed_constraint.targets.reverse();
                let mut reversed_constraints = self.constraints.clone();
                reversed_constraints[index] = reversed_constraint.clone();
                updated_entities = ConstraintSolver::solve_constraints_from_entities(
                    self,
                    &self.parameters,
                    &self.entities,
                    &reversed_constraints,
                )?;
                self.ensure_constraints_not_conflicting(
                    updated_entities.clone(),
                    reversed_constraints,
                )?;
                accepted_constraint = reversed_constraint;
            } else {
                return Err(error);
            }
        }

        self.entities = updated_entities;
        self.constraints[index] = accepted_constraint;
        Ok(())
    }

    /// 拘束の対象や種別を保持したまま固定値だけを変更する。
    pub(crate) fn set_constraint_value(
        &mut self,
        constraint_id: &str,
        value: ConstraintValue,
    ) -> CommandResult {
        let mut constraint = self
            .constraints
            .iter()
            .find(|constraint| constraint.id == constraint_id)
            .cloned()
            .ok_or_else(|| CommandError::missing("constraint", constraint_id))?;
        constraint.value = Some(value);
        self.update_constraint(constraint)
    }

    /// 拘束の対象や種別を保持したままパラメータ参照へ切り替える。
    pub(crate) fn set_constraint_parameter(
        &mut self,
        constraint_id: &str,
        parameter_id: ParameterId,
    ) -> CommandResult {
        self.set_constraint_value(constraint_id, ConstraintValue::Parameter(parameter_id))
    }

    /// 名前付きパラメータを追加する。
    pub(crate) fn add_parameter(&mut self, parameter: Parameter) -> CommandResult {
        validate_parameter(&parameter)?;
        ensure_unique_id(
            self.parameters.iter().map(|existing| existing.id.as_str()),
            "parameter",
            &parameter.id,
        )?;
        ensure_unique_parameter_name(self.parameters.iter(), &parameter.name, None)?;

        self.parameters.push(parameter);
        Ok(())
    }

    /// 既存パラメータを検証済みの新しい内容で置き換える。
    pub(crate) fn update_parameter(&mut self, parameter: Parameter) -> CommandResult {
        validate_parameter(&parameter)?;
        ensure_unique_parameter_name(self.parameters.iter(), &parameter.name, Some(&parameter.id))?;
        let rollback = DocumentRollback::capture(self);
        let parameter_id = parameter.id.clone();
        let existing = self
            .parameters
            .iter_mut()
            .find(|existing| existing.id == parameter_id)
            .ok_or_else(|| CommandError::missing("parameter", parameter.id.clone()))?;
        *existing = parameter;
        self.resolve_current_parameter_references_or_restore(rollback)
    }

    /// パラメータを削除し、すべての参照を固定値へ変換する。
    pub(crate) fn delete_parameter(
        &mut self,
        parameter_id: &str,
        replacement_value_mm: f64,
    ) -> CommandResult {
        validate_non_negative_finite("replacement value", replacement_value_mm)?;
        let rollback = DocumentRollback::capture(self);
        delete_by_id(
            &mut self.parameters,
            "parameter",
            parameter_id,
            |parameter| &parameter.id,
        )?;

        for constraint in &mut self.constraints {
            if matches!(
                constraint.value,
                Some(ConstraintValue::Parameter(ref id)) if id == parameter_id
            ) {
                constraint.value = Some(ConstraintValue::FixedMm(replacement_value_mm));
            }
        }
        for derived_element in &mut self.derived_elements {
            match &mut derived_element.kind {
                DerivedElementKind::OffsetCurve(offset_curve) => {
                    if matches!(
                        offset_curve.distance,
                        ConstraintValue::Parameter(ref id) if id == parameter_id
                    ) {
                        offset_curve.distance = ConstraintValue::FixedMm(replacement_value_mm);
                    }
                }
                DerivedElementKind::Fillet(fillet) => {
                    if matches!(
                        fillet.radius,
                        ConstraintValue::Parameter(ref id) if id == parameter_id
                    ) {
                        fillet.radius = ConstraintValue::FixedMm(replacement_value_mm);
                    }
                }
            }
        }

        self.resolve_current_parameter_references_or_restore(rollback)
    }

    /// 既存パラメータの値をミリメートル単位で更新する。
    pub(crate) fn set_parameter_value(
        &mut self,
        parameter_id: &str,
        value_mm: f64,
    ) -> CommandResult {
        validate_non_negative_finite("parameter value", value_mm)?;
        let rollback = DocumentRollback::capture(self);
        let parameter = self
            .parameters
            .iter_mut()
            .find(|parameter| parameter.id == parameter_id)
            .ok_or_else(|| CommandError::missing("parameter", parameter_id))?;

        parameter.value_mm = value_mm;
        self.resolve_current_parameter_value_update_or_restore(rollback, parameter_id)
    }

    fn resolve_current_parameter_references_or_restore(
        &mut self,
        rollback: DocumentRollback,
    ) -> CommandResult {
        let restore_snapshot = rollback.clone();
        self.resolve_current_constraints_or_restore(rollback)?;
        if let Err(error) = self.ensure_derived_elements_resolve() {
            self.restore_document_state(restore_snapshot);
            return Err(error);
        }
        Ok(())
    }

    fn resolve_current_parameter_value_update_or_restore(
        &mut self,
        rollback: DocumentRollback,
        parameter_id: &str,
    ) -> CommandResult {
        let restore_snapshot = rollback.clone();
        self.resolve_current_constraints_or_restore(rollback)?;
        if derived_elements_reference_parameter(&self.derived_elements, parameter_id) {
            if let Err(error) = self.ensure_derived_elements_resolve() {
                self.restore_document_state(restore_snapshot);
                return Err(error);
            }
        }
        Ok(())
    }

    fn ensure_derived_elements_resolve(&self) -> CommandResult {
        for derived_element in &self.derived_elements {
            self.resolve_derived_element(derived_element)?;
        }
        Ok(())
    }

    pub(in crate::document) fn restore_document_state(&mut self, rollback: DocumentRollback) {
        self.parameters = rollback.parameters;
        self.entities = rollback.entities;
        self.derived_elements = rollback.derived_elements;
        self.free_texts = rollback.free_texts;
        self.round_holes = rollback.round_holes;
        self.parts = rollback.parts;
        self.stitch_start_points = rollback.stitch_start_points;
        self.constraints = rollback.constraints;
        self.view_annotations = rollback.view_annotations;
    }
}

fn normalize_signed_angle(angle_rad: f64) -> f64 {
    let mut normalized = angle_rad % std::f64::consts::TAU;
    if normalized <= -std::f64::consts::PI {
        normalized += std::f64::consts::TAU;
    } else if normalized > std::f64::consts::PI {
        normalized -= std::f64::consts::TAU;
    }
    normalized
}

fn ensure_unique_layer_name<'a>(
    mut layers: impl Iterator<Item = &'a Layer>,
    candidate: &str,
    excluded_id: Option<&str>,
) -> CommandResult {
    if layers.any(|layer| {
        Some(layer.id.as_str()) != excluded_id && layer.name.trim() == candidate.trim()
    }) {
        return Err(CommandError::InvalidValue {
            field: "layer name",
            reason: "must be unique",
        });
    }
    Ok(())
}

fn ensure_unique_parameter_name<'a>(
    mut parameters: impl Iterator<Item = &'a Parameter>,
    candidate: &str,
    excluded_id: Option<&str>,
) -> CommandResult {
    if parameters.any(|parameter| {
        Some(parameter.id.as_str()) != excluded_id && parameter.name.trim() == candidate.trim()
    }) {
        return Err(CommandError::InvalidValue {
            field: "parameter name",
            reason: "must be unique",
        });
    }
    Ok(())
}

fn validate_round_hole(document: &ProjectDocument, round_hole: &RoundHole) -> CommandResult {
    ensure_non_empty_id("round hole", &round_hole.id)?;
    let entity = document.entity(&round_hole.entity_id).ok_or_else(|| {
        CommandError::broken_reference("round hole", "entity", &round_hole.entity_id)
    })?;
    if !matches!(entity.kind, EntityKind::Circle(_)) {
        return Err(CommandError::InvalidValue {
            field: "round hole entity",
            reason: "must reference a circle",
        });
    }
    Ok(())
}

fn ensure_round_holes_reference_circles(
    round_holes: &[RoundHole],
    entities: &[Entity],
) -> CommandResult {
    for round_hole in round_holes {
        let Some(entity) = entities
            .iter()
            .find(|entity| entity.id == round_hole.entity_id)
        else {
            return Err(CommandError::broken_reference(
                "round hole",
                "entity",
                &round_hole.entity_id,
            ));
        };
        if !matches!(entity.kind, EntityKind::Circle(_)) {
            return Err(CommandError::InvalidValue {
                field: "round hole entity",
                reason: "must reference a circle",
            });
        }
    }
    Ok(())
}

pub(in crate::document) fn validate_stitch_start_point(
    document: &ProjectDocument,
    stitch_start_point: &StitchStartPoint,
) -> CommandResult {
    ensure_non_empty_id("stitch start point", &stitch_start_point.id)?;
    if stitch_start_point.target_id.trim().is_empty() {
        return Err(CommandError::InvalidValue {
            field: "stitch start point target",
            reason: "targetId must not be empty",
        });
    }
    if !stitch_start_point.position_ratio.is_finite()
        || !(0.0..=1.0).contains(&stitch_start_point.position_ratio)
    {
        return Err(CommandError::InvalidValue {
            field: "stitch start point positionRatio",
            reason: "must be a finite value between 0 and 1",
        });
    }
    stitch_start_point_position(document, stitch_start_point)?;
    Ok(())
}

fn ensure_stitch_start_points_resolve(
    document: &ProjectDocument,
    stitch_start_points: &[StitchStartPoint],
) -> CommandResult {
    for stitch_start_point in stitch_start_points {
        stitch_start_point_position(document, stitch_start_point)?;
    }
    Ok(())
}

pub(in crate::document) fn stitch_start_point_position(
    document: &ProjectDocument,
    stitch_start_point: &StitchStartPoint,
) -> CommandResult<Point2> {
    let entity = stitch_start_target_entity(document, stitch_start_point)?;
    point_on_stitch_target(entity, stitch_start_point.position_ratio)
}

fn stitch_start_target_entity(
    document: &ProjectDocument,
    stitch_start_point: &StitchStartPoint,
) -> CommandResult<Entity> {
    if let Some(entity) = document.entity(&stitch_start_point.target_id) {
        ensure_stitch_style(entity.style_id.as_deref(), "stitch start point target")?;
        return Ok(entity.clone());
    }

    let derived_element = document
        .derived_element(&stitch_start_point.target_id)
        .ok_or_else(|| {
            CommandError::broken_reference(
                "stitch start point",
                "target",
                &stitch_start_point.target_id,
            )
        })?;
    ensure_stitch_style(
        derived_element.style_id.as_deref(),
        "stitch start point target",
    )?;
    let resolved = document.resolve_derived_element(derived_element)?;
    let index = stitch_start_point.resolved_index.unwrap_or(0);
    resolved
        .get(index)
        .cloned()
        .ok_or(CommandError::InvalidValue {
            field: "stitch start point resolvedIndex",
            reason: "must reference an existing resolved stitch line",
        })
}

fn ensure_stitch_style(style_id: Option<&str>, field: &'static str) -> CommandResult {
    if style_id == Some("style:stitch-line") {
        return Ok(());
    }
    Err(CommandError::InvalidValue {
        field,
        reason: "must reference an element with stitch-line shared style",
    })
}

fn point_on_stitch_target(entity: Entity, ratio: f64) -> CommandResult<Point2> {
    match entity.kind {
        EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => Ok(Point2::new(
            line.start.x_mm + (line.end.x_mm - line.start.x_mm) * ratio,
            line.start.y_mm + (line.end.y_mm - line.start.y_mm) * ratio,
        )),
        EntityKind::Arc(arc) => {
            let angle = arc.start_angle_rad + arc.sweep_angle_rad * ratio;
            Ok(Point2::new(
                arc.center.x_mm + arc.radius_mm * angle.cos(),
                arc.center.y_mm + arc.radius_mm * angle.sin(),
            ))
        }
        EntityKind::Point(_) | EntityKind::Circle(_) => Err(CommandError::InvalidValue {
            field: "stitch start point target",
            reason: "must reference a line, center line, or arc",
        }),
    }
}

fn apply_candidate_command(
    document: &mut ProjectDocument,
    command: DocumentCommand,
) -> CommandResult {
    let mut candidate = document.clone();
    CommandApplier::apply_command_without_history(&mut candidate, command)?;
    *document = candidate;
    Ok(())
}

fn validate_point_delta(point: Point2) -> CommandResult {
    if point.x_mm.is_finite() && point.y_mm.is_finite() {
        Ok(())
    } else {
        Err(CommandError::InvalidValue {
            field: "point",
            reason: "coordinates must be finite",
        })
    }
}

pub(in crate::document) fn translated_entity(entity: &Entity, delta: Point2) -> Entity {
    let mut translated = entity.clone();
    translated.kind = match entity.kind {
        EntityKind::Point(point) => EntityKind::Point(translate_point(point, delta)),
        EntityKind::LineSegment(line) => EntityKind::LineSegment(LineSegment::new(
            translate_point(line.start, delta),
            translate_point(line.end, delta),
        )),
        EntityKind::CenterLine(line) => EntityKind::CenterLine(LineSegment::new(
            translate_point(line.start, delta),
            translate_point(line.end, delta),
        )),
        EntityKind::Circle(circle) => EntityKind::Circle(Circle {
            center: translate_point(circle.center, delta),
            radius_mm: circle.radius_mm,
        }),
        EntityKind::Arc(arc) => EntityKind::Arc(Arc {
            center: translate_point(arc.center, delta),
            radius_mm: arc.radius_mm,
            start_angle_rad: arc.start_angle_rad,
            sweep_angle_rad: arc.sweep_angle_rad,
        }),
    };
    translated
}

fn translate_point(point: Point2, delta: Point2) -> Point2 {
    Point2::new(point.x_mm + delta.x_mm, point.y_mm + delta.y_mm)
}

fn single_line_stretch_candidates(
    document: &ProjectDocument,
    entity_id: &str,
    delta: Point2,
) -> CommandResult<Vec<Entity>> {
    let entity = document
        .entity(entity_id)
        .ok_or_else(|| CommandError::missing("entity", entity_id.to_owned()))?;
    let line = match entity.kind {
        EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => line,
        _ => return Ok(Vec::new()),
    };
    let start = translate_point(line.start, delta);
    let end = translate_point(line.end, delta);
    Ok(vec![
        line_entity_with_points(entity, start, line.end),
        line_entity_with_points(entity, line.start, end),
    ])
}

fn line_entity_with_points(entity: &Entity, start: Point2, end: Point2) -> Entity {
    let mut updated = entity.clone();
    updated.kind = match entity.kind {
        EntityKind::CenterLine(_) => EntityKind::CenterLine(LineSegment::new(start, end)),
        _ => EntityKind::LineSegment(LineSegment::new(start, end)),
    };
    updated
}

fn entity_with_control_point(
    entity: &Entity,
    target: &ConstraintTarget,
    position: Point2,
) -> CommandResult<Entity> {
    let ConstraintTarget::ControlPoint { point, .. } = target else {
        return Err(CommandError::InvalidValue {
            field: "target",
            reason: "moveControlPoint requires a control point target",
        });
    };
    let mut updated = entity.clone();
    updated.kind = match (entity.kind.clone(), point) {
        (EntityKind::LineSegment(line), ControlPointKind::Start) => {
            EntityKind::LineSegment(LineSegment::new(position, line.end))
        }
        (EntityKind::LineSegment(line), ControlPointKind::End) => {
            EntityKind::LineSegment(LineSegment::new(line.start, position))
        }
        (EntityKind::CenterLine(line), ControlPointKind::Start) => {
            EntityKind::CenterLine(LineSegment::new(position, line.end))
        }
        (EntityKind::CenterLine(line), ControlPointKind::End) => {
            EntityKind::CenterLine(LineSegment::new(line.start, position))
        }
        (EntityKind::Circle(circle), ControlPointKind::Center) => EntityKind::Circle(Circle {
            center: position,
            radius_mm: circle.radius_mm,
        }),
        (EntityKind::Arc(arc), ControlPointKind::Center) => EntityKind::Arc(Arc {
            center: position,
            radius_mm: arc.radius_mm,
            start_angle_rad: arc.start_angle_rad,
            sweep_angle_rad: arc.sweep_angle_rad,
        }),
        (EntityKind::Arc(arc), ControlPointKind::Start) => {
            let radius_mm = distance(position, arc.center);
            EntityKind::Arc(Arc {
                center: arc.center,
                radius_mm,
                start_angle_rad: angle_radians(arc.center, position),
                sweep_angle_rad: arc.sweep_angle_rad,
            })
        }
        (EntityKind::Arc(arc), ControlPointKind::End) => {
            let radius_mm = distance(position, arc.center);
            let end_angle = angle_radians(arc.center, position);
            let mut sweep_angle_rad = end_angle - arc.start_angle_rad;
            if arc.sweep_angle_rad >= 0.0 && sweep_angle_rad <= 0.0 {
                sweep_angle_rad += std::f64::consts::TAU;
            } else if arc.sweep_angle_rad < 0.0 && sweep_angle_rad >= 0.0 {
                sweep_angle_rad -= std::f64::consts::TAU;
            }
            EntityKind::Arc(Arc {
                center: arc.center,
                radius_mm,
                start_angle_rad: arc.start_angle_rad,
                sweep_angle_rad,
            })
        }
        _ => {
            return Err(CommandError::InvalidValue {
                field: "target",
                reason: "control point target is incompatible with the referenced entity",
            });
        }
    };
    Ok(updated)
}

fn projected_line_control_point_move(
    entity: &Entity,
    target: &ConstraintTarget,
    desired_point: Point2,
) -> CommandResult<Option<Entity>> {
    let ConstraintTarget::ControlPoint { point, .. } = target else {
        return Ok(None);
    };
    let line = match entity.kind {
        EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => line,
        _ => return Ok(None),
    };
    let (anchor, original) = match point {
        ControlPointKind::Start => (line.end, line.start),
        ControlPointKind::End => (line.start, line.end),
        ControlPointKind::Center => return Ok(None),
    };
    let direction = Point2::new(original.x_mm - anchor.x_mm, original.y_mm - anchor.y_mm);
    let length = distance(direction, Point2::new(0.0, 0.0));
    if length <= 0.001 {
        return Ok(None);
    }
    let unit = Point2::new(direction.x_mm / length, direction.y_mm / length);
    let desired = Point2::new(
        desired_point.x_mm - anchor.x_mm,
        desired_point.y_mm - anchor.y_mm,
    );
    let projected_length = desired.x_mm * unit.x_mm + desired.y_mm * unit.y_mm;
    if projected_length.abs() <= 0.001 {
        return Ok(None);
    }
    let projected = Point2::new(
        anchor.x_mm + unit.x_mm * projected_length,
        anchor.y_mm + unit.y_mm * projected_length,
    );
    Ok(Some(match point {
        ControlPointKind::Start => line_entity_with_points(entity, projected, line.end),
        ControlPointKind::End => line_entity_with_points(entity, line.start, projected),
        ControlPointKind::Center => unreachable!("center handled above"),
    }))
}

fn distance(first: Point2, second: Point2) -> f64 {
    (first.x_mm - second.x_mm).hypot(first.y_mm - second.y_mm)
}

fn angle_radians(center: Point2, point: Point2) -> f64 {
    (point.y_mm - center.y_mm).atan2(point.x_mm - center.x_mm)
}
