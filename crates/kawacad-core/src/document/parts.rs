use super::semantic_operations::duplicate_id;
use super::*;
use crate::parts::{Part, PartAlignment, PartDistributionAxis};
use std::collections::{BTreeSet, VecDeque};

const PART_GEOMETRY_TOLERANCE_MM: f64 = 0.001;

#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
/// Core が UI のローカルライブラリ保持用に書き出す不透明なパーツ項目。
pub struct PartLibraryExport {
    /// UI が内容を解釈せず、そのまま配置コマンドへ渡すトークン。
    pub library_json: String,
    /// 一覧表示と旧形式互換に使う登録時のパーツ情報。
    pub source_part: Part,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct PartLibraryClipboard {
    clipboard_json: String,
    source_part: Part,
}

#[derive(Clone)]
struct ContourSegment {
    id: String,
    start: Point2,
    end: Point2,
    interior: Vec<Point2>,
}

#[derive(Clone)]
struct ClosedLoop {
    ids: Vec<String>,
    vertices: Vec<Point2>,
    area: f64,
}

impl ProjectDocument {
    /// パーツと依存閉包を Core 所有の不透明なライブラリ項目として書き出す。
    pub fn export_part_library_item(&self, part_id: &str) -> CommandResult<PartLibraryExport> {
        let source_part = self
            .parts
            .iter()
            .find(|part| part.id == part_id)
            .cloned()
            .ok_or_else(|| CommandError::missing("part", part_id))?;
        let selection = part_selection(&source_part);
        let clipboard_json = self.export_selection(selection)?.clipboard_json;
        let library_json = serde_json::to_string(&PartLibraryClipboard {
            clipboard_json,
            source_part: source_part.clone(),
        })
        .map_err(|_| CommandError::InvalidValue {
            field: "part library",
            reason: "failed to serialize part library item",
        })?;
        Ok(PartLibraryExport {
            library_json,
            source_part,
        })
    }

    pub(crate) fn create_part(
        &mut self,
        id: String,
        name: String,
        origin_mm: Option<Point2>,
        entity_ids: Vec<String>,
    ) -> CommandResult {
        ensure_non_empty_id("part", &id)?;
        ensure_unique_id(self.parts.iter().map(|part| part.id.as_str()), "part", &id)?;
        validate_part_name(&self.parts, None, &name)?;
        if let Some(origin_mm) = origin_mm {
            validate_part_origin(origin_mm)?;
        }
        if entity_ids.is_empty() {
            return Err(invalid_part_entities("must include a closed outline"));
        }
        let selected_ids = entity_ids.into_iter().collect::<BTreeSet<_>>();
        if selected_ids.len() < 2
            && !selected_ids.iter().any(|id| {
                self.entity(id)
                    .is_some_and(|entity| matches!(entity.kind, EntityKind::Circle(_)))
            })
        {
            return Err(invalid_part_entities("must include a closed outline"));
        }
        for entity_id in &selected_ids {
            self.ensure_entity_exists("part", entity_id)?;
            if self
                .parts
                .iter()
                .any(|part| part.entity_ids.contains(entity_id))
            {
                return Err(invalid_part_entities(
                    "an entity already belongs to another part",
                ));
            }
        }

        let selected_entities = selected_ids
            .iter()
            .filter_map(|id| self.entity(id).cloned())
            .collect::<Vec<_>>();
        let origin_mm = origin_mm.unwrap_or_else(|| {
            let anchors = selected_entities
                .iter()
                .map(entity_anchor)
                .collect::<Vec<_>>();
            Point2::new(
                anchors.iter().map(|point| point.x_mm).sum::<f64>() / anchors.len() as f64,
                anchors.iter().map(|point| point.y_mm).sum::<f64>() / anchors.len() as f64,
            )
        });
        let mut loops = closed_loops(&selected_entities);
        if loops.is_empty() {
            return Err(invalid_part_entities("must include a closed outline"));
        }
        loops.sort_by(|lhs, rhs| rhs.area.abs().total_cmp(&lhs.area.abs()));
        let outline = loops.remove(0);
        for candidate in &loops {
            if !point_inside_or_on_boundary(
                polygon_centroid(&candidate.vertices),
                &outline.vertices,
            ) {
                return Err(invalid_part_entities(
                    "closed contours outside the outline are not allowed",
                ));
            }
        }
        for entity in &selected_entities {
            if outline.ids.contains(&entity.id)
                || loops
                    .iter()
                    .any(|candidate| candidate.ids.contains(&entity.id))
            {
                continue;
            }
            if !point_inside_or_on_boundary(entity_anchor(entity), &outline.vertices) {
                return Err(invalid_part_entities(
                    "selected entities must be inside the outline",
                ));
            }
        }

        self.parts.push(Part {
            id,
            name: name.trim().to_owned(),
            origin_mm,
            outline_entity_ids: outline.ids,
            hole_entity_id_groups: loops.into_iter().map(|item| item.ids).collect(),
            entity_ids: selected_ids.into_iter().collect(),
            derived_element_ids: Vec::new(),
            free_text_ids: Vec::new(),
            measurement_annotation_ids: Vec::new(),
            visible: true,
            printable: true,
            // Creation temporarily keeps the part editable while existing
            // dependent elements are collected below. It is finalized before
            // the command returns.
            locked: false,
            quantity: 1,
        });

        // Elements that already depended on, or were placed inside, the selected
        // figures become part members as soon as the part is created. This keeps
        // creation order from changing the resulting project structure.
        let derived_ids = self
            .derived_elements
            .iter()
            .map(|item| item.id.clone())
            .collect::<Vec<_>>();
        let free_text_ids = self
            .free_texts
            .iter()
            .map(|item| item.id.clone())
            .collect::<Vec<_>>();
        let measurement_ids = self
            .measurement_annotations()
            .iter()
            .map(|item| item.id.clone())
            .collect::<Vec<_>>();
        for derived_id in derived_ids {
            self.auto_assign_derived_element_to_part(&derived_id);
        }
        for free_text_id in free_text_ids {
            self.auto_assign_free_text_to_part(&free_text_id);
        }
        for measurement_id in measurement_ids {
            self.auto_assign_measurement_to_part(&measurement_id);
        }
        self.parts
            .last_mut()
            .expect("the newly created part exists")
            .locked = true;
        Ok(())
    }

    pub(crate) fn rename_part(&mut self, id: &str, name: &str) -> CommandResult {
        validate_part_name(&self.parts, Some(id), name)?;
        let part = self
            .parts
            .iter_mut()
            .find(|part| part.id == id)
            .ok_or_else(|| CommandError::missing("part", id))?;
        part.name = name.trim().to_owned();
        Ok(())
    }
    pub(crate) fn update_part(&mut self, id: &str, name: &str, origin_mm: Point2) -> CommandResult {
        let part = self
            .parts
            .iter()
            .find(|part| part.id == id)
            .ok_or_else(|| CommandError::missing("part", id))?;
        if part.origin_mm != origin_mm {
            return Err(fixed_part_error());
        }
        self.rename_part(id, name)
    }

    pub(crate) fn set_part_visibility(&mut self, id: &str, visible: bool) -> CommandResult {
        let part = self
            .parts
            .iter_mut()
            .find(|part| part.id == id)
            .ok_or_else(|| CommandError::missing("part", id))?;
        part.visible = visible;
        Ok(())
    }
    pub(crate) fn set_part_printable(&mut self, id: &str, printable: bool) -> CommandResult {
        let part = self
            .parts
            .iter_mut()
            .find(|part| part.id == id)
            .ok_or_else(|| CommandError::missing("part", id))?;
        part.printable = printable;
        Ok(())
    }
    pub(crate) fn set_part_quantity(&mut self, id: &str, quantity: u32) -> CommandResult {
        if quantity == 0 {
            return Err(CommandError::InvalidValue {
                field: "part quantity",
                reason: "must be at least 1",
            });
        }
        let part = self
            .parts
            .iter_mut()
            .find(|part| part.id == id)
            .ok_or_else(|| CommandError::missing("part", id))?;
        part.quantity = quantity;
        Ok(())
    }
    pub(crate) fn update_part_settings(
        &mut self,
        id: &str,
        visible: bool,
        printable: bool,
        locked: bool,
        quantity: u32,
    ) -> CommandResult {
        if !locked {
            return Err(CommandError::InvalidValue {
                field: "part fixed",
                reason: "parts cannot be unlocked",
            });
        }
        self.set_part_visibility(id, visible)?;
        self.set_part_printable(id, printable)?;
        self.set_part_quantity(id, quantity)
    }

    pub(crate) fn delete_part(&mut self, id: &str) -> CommandResult {
        let index = self
            .parts
            .iter()
            .position(|part| part.id == id)
            .ok_or_else(|| CommandError::missing("part", id))?;
        self.parts.remove(index);
        Ok(())
    }

    pub(crate) fn move_part(&mut self, id: &str, delta: Point2) -> CommandResult {
        validate_part_origin(delta)?;
        let part = self
            .parts
            .iter()
            .find(|part| part.id == id)
            .cloned()
            .ok_or_else(|| CommandError::missing("part", id))?;
        self.move_entities(part.entity_ids.clone(), delta, false)?;
        for text_id in &part.free_text_ids {
            let text = self
                .free_texts
                .iter_mut()
                .find(|text| &text.id == text_id)
                .ok_or_else(|| CommandError::missing("free text", text_id))?;
            text.position_mm.x_mm += delta.x_mm;
            text.position_mm.y_mm += delta.y_mm;
        }
        let moved = self
            .parts
            .iter_mut()
            .find(|part| part.id == id)
            .ok_or_else(|| CommandError::missing("part", id))?;
        moved.origin_mm.x_mm += delta.x_mm;
        moved.origin_mm.y_mm += delta.y_mm;
        Ok(())
    }

    pub(crate) fn set_part_position(&mut self, id: &str, position: Point2) -> CommandResult {
        validate_part_origin(position)?;
        let origin = self
            .parts
            .iter()
            .find(|part| part.id == id)
            .map(|part| part.origin_mm)
            .ok_or_else(|| CommandError::missing("part", id))?;
        self.move_part(
            id,
            Point2::new(position.x_mm - origin.x_mm, position.y_mm - origin.y_mm),
        )
    }

    pub(crate) fn duplicate_part(
        &mut self,
        source_id: &str,
        new_part_id: String,
        new_name: String,
        id_namespace: &str,
        delta: Point2,
    ) -> CommandResult {
        ensure_non_empty_id("part", &new_part_id)?;
        ensure_unique_id(
            self.parts.iter().map(|part| part.id.as_str()),
            "part",
            &new_part_id,
        )?;
        validate_part_name(&self.parts, None, &new_name)?;
        validate_part_origin(delta)?;
        let source = self
            .parts
            .iter()
            .find(|part| part.id == source_id)
            .cloned()
            .ok_or_else(|| CommandError::missing("part", source_id))?;
        let selection = part_selection(&source);
        self.duplicate_selection(selection, id_namespace, delta)?;
        self.install_copied_part(source, new_part_id, new_name, id_namespace, delta)
    }

    pub(crate) fn insert_part_library_item(
        &mut self,
        library_json: &str,
        legacy_source_part: Option<Part>,
        new_part_id: String,
        new_name: String,
        id_namespace: &str,
        delta: Point2,
    ) -> CommandResult {
        ensure_non_empty_id("part", &new_part_id)?;
        ensure_unique_id(
            self.parts.iter().map(|part| part.id.as_str()),
            "part",
            &new_part_id,
        )?;
        validate_part_name(&self.parts, None, &new_name)?;
        validate_part_origin(delta)?;

        let (clipboard_json, source_part) =
            match serde_json::from_str::<PartLibraryClipboard>(library_json) {
                Ok(item) => (item.clipboard_json, item.source_part),
                Err(_) => (
                    library_json.to_owned(),
                    legacy_source_part.ok_or(CommandError::InvalidValue {
                        field: "part library",
                        reason: "library token is invalid",
                    })?,
                ),
            };
        self.paste_selection(&clipboard_json, id_namespace, delta)?;
        self.install_copied_part(source_part, new_part_id, new_name, id_namespace, delta)
    }

    fn install_copied_part(
        &mut self,
        source: Part,
        new_part_id: String,
        new_name: String,
        id_namespace: &str,
        delta: Point2,
    ) -> CommandResult {
        let map = |kind: &str, id: &String| duplicate_id(kind, id_namespace, id);
        let entity_ids = source
            .entity_ids
            .iter()
            .map(|id| map("entity", id))
            .collect::<Vec<_>>();
        let derived_ids = source
            .derived_element_ids
            .iter()
            .map(|id| map("derived", id))
            .collect::<Vec<_>>();
        let text_ids = source
            .free_text_ids
            .iter()
            .map(|id| map("free-text", id))
            .collect::<Vec<_>>();
        let measurement_ids = source
            .measurement_annotation_ids
            .iter()
            .map(|id| map("measurement", id))
            .collect::<Vec<_>>();
        let entity_set = entity_ids.iter().cloned().collect::<BTreeSet<_>>();
        let derived_set = derived_ids.iter().cloned().collect::<BTreeSet<_>>();
        let text_set = text_ids.iter().cloned().collect::<BTreeSet<_>>();
        let measurement_set = measurement_ids.iter().cloned().collect::<BTreeSet<_>>();
        for part in &mut self.parts {
            part.entity_ids.retain(|id| !entity_set.contains(id));
            part.derived_element_ids
                .retain(|id| !derived_set.contains(id));
            part.free_text_ids.retain(|id| !text_set.contains(id));
            part.measurement_annotation_ids
                .retain(|id| !measurement_set.contains(id));
        }
        self.parts.push(Part {
            id: new_part_id,
            name: new_name.trim().to_owned(),
            origin_mm: Point2::new(
                source.origin_mm.x_mm + delta.x_mm,
                source.origin_mm.y_mm + delta.y_mm,
            ),
            outline_entity_ids: source
                .outline_entity_ids
                .iter()
                .map(|id| map("entity", id))
                .collect(),
            hole_entity_id_groups: source
                .hole_entity_id_groups
                .iter()
                .map(|group| group.iter().map(|id| map("entity", id)).collect())
                .collect(),
            entity_ids,
            derived_element_ids: derived_ids,
            free_text_ids: text_ids,
            measurement_annotation_ids: measurement_ids,
            visible: source.visible,
            printable: source.printable,
            locked: true,
            quantity: source.quantity,
        });
        Ok(())
    }

    pub(crate) fn align_parts(
        &mut self,
        part_ids: Vec<String>,
        alignment: PartAlignment,
    ) -> CommandResult {
        let ids = validated_arrangement_ids(self, part_ids, 2, "alignParts")?;
        let bounds = ids
            .iter()
            .map(|id| part_bounds(self, id).map(|bounds| (id.clone(), bounds)))
            .collect::<CommandResult<Vec<_>>>()?;
        let aggregate = PartBounds {
            min_x: bounds
                .iter()
                .map(|(_, item)| item.min_x)
                .fold(f64::INFINITY, f64::min),
            max_x: bounds
                .iter()
                .map(|(_, item)| item.max_x)
                .fold(f64::NEG_INFINITY, f64::max),
            min_y: bounds
                .iter()
                .map(|(_, item)| item.min_y)
                .fold(f64::INFINITY, f64::min),
            max_y: bounds
                .iter()
                .map(|(_, item)| item.max_y)
                .fold(f64::NEG_INFINITY, f64::max),
        };
        for (id, item) in bounds {
            let delta = match alignment {
                PartAlignment::Left => Point2::new(aggregate.min_x - item.min_x, 0.0),
                PartAlignment::HorizontalCenter => {
                    Point2::new(aggregate.center_x() - item.center_x(), 0.0)
                }
                PartAlignment::Right => Point2::new(aggregate.max_x - item.max_x, 0.0),
                PartAlignment::Bottom => Point2::new(0.0, aggregate.min_y - item.min_y),
                PartAlignment::VerticalCenter => {
                    Point2::new(0.0, aggregate.center_y() - item.center_y())
                }
                PartAlignment::Top => Point2::new(0.0, aggregate.max_y - item.max_y),
            };
            self.move_part(&id, delta)?;
        }
        Ok(())
    }

    pub(crate) fn distribute_parts(
        &mut self,
        part_ids: Vec<String>,
        axis: PartDistributionAxis,
    ) -> CommandResult {
        let ids = validated_arrangement_ids(self, part_ids, 3, "distributeParts")?;
        let mut bounds = ids
            .iter()
            .map(|id| part_bounds(self, id).map(|bounds| (id.clone(), bounds)))
            .collect::<CommandResult<Vec<_>>>()?;
        match axis {
            PartDistributionAxis::Horizontal => bounds.sort_by(|lhs, rhs| {
                lhs.1
                    .min_x
                    .total_cmp(&rhs.1.min_x)
                    .then_with(|| lhs.0.cmp(&rhs.0))
            }),
            PartDistributionAxis::Vertical => bounds.sort_by(|lhs, rhs| {
                lhs.1
                    .min_y
                    .total_cmp(&rhs.1.min_y)
                    .then_with(|| lhs.0.cmp(&rhs.0))
            }),
        }
        let first = bounds.first().expect("validated non-empty").1;
        let last = bounds.last().expect("validated non-empty").1;
        let total_size: f64 = bounds
            .iter()
            .map(|(_, item)| match axis {
                PartDistributionAxis::Horizontal => item.width(),
                PartDistributionAxis::Vertical => item.height(),
            })
            .sum();
        let span = match axis {
            PartDistributionAxis::Horizontal => last.max_x - first.min_x,
            PartDistributionAxis::Vertical => last.max_y - first.min_y,
        };
        let gap = (span - total_size) / (bounds.len() - 1) as f64;
        let mut cursor = match axis {
            PartDistributionAxis::Horizontal => first.min_x,
            PartDistributionAxis::Vertical => first.min_y,
        };
        for (id, item) in bounds {
            let delta = match axis {
                PartDistributionAxis::Horizontal => Point2::new(cursor - item.min_x, 0.0),
                PartDistributionAxis::Vertical => Point2::new(0.0, cursor - item.min_y),
            };
            self.move_part(&id, delta)?;
            cursor += match axis {
                PartDistributionAxis::Horizontal => item.width() + gap,
                PartDistributionAxis::Vertical => item.height() + gap,
            };
        }
        Ok(())
    }

    pub(crate) fn add_entities_to_part(
        &mut self,
        part_id: &str,
        entity_ids: Vec<String>,
    ) -> CommandResult {
        if self.parts.iter().any(|part| part.id == part_id) {
            return Err(fixed_part_error());
        }
        let requested = non_empty_part_entity_set(entity_ids, "addEntitiesToPart")?;
        let index = self
            .parts
            .iter()
            .position(|part| part.id == part_id)
            .ok_or_else(|| CommandError::missing("part", part_id))?;
        let outline = part_outline_loop(self, &self.parts[index])
            .ok_or_else(|| invalid_part_entities("part outline is not closed"))?;
        for entity_id in &requested {
            let entity = self
                .entity(entity_id)
                .ok_or_else(|| CommandError::missing("entity", entity_id))?;
            if self.parts[index].entity_ids.contains(entity_id) {
                return Err(invalid_part_entities(
                    "entity already belongs to the target part",
                ));
            }
            if self.parts.iter().enumerate().any(|(part_index, part)| {
                part_index != index && part.entity_ids.contains(entity_id)
            }) {
                return Err(invalid_part_entities(
                    "an entity already belongs to another part",
                ));
            }
            if !point_inside_or_on_boundary(entity_anchor(entity), &outline.vertices) {
                return Err(invalid_part_entities(
                    "selected entities must be inside the outline",
                ));
            }
        }
        self.parts[index].entity_ids.extend(requested);
        self.parts[index].entity_ids.sort();
        self.parts[index].entity_ids.dedup();
        self.refresh_part_dependencies(part_id);
        Ok(())
    }

    pub(crate) fn remove_entities_from_part(
        &mut self,
        part_id: &str,
        entity_ids: Vec<String>,
    ) -> CommandResult {
        if self.parts.iter().any(|part| part.id == part_id) {
            return Err(fixed_part_error());
        }
        let requested = non_empty_part_entity_set(entity_ids, "removeEntitiesFromPart")?;
        let index = self
            .parts
            .iter()
            .position(|part| part.id == part_id)
            .ok_or_else(|| CommandError::missing("part", part_id))?;
        let boundary = self.parts[index]
            .outline_entity_ids
            .iter()
            .chain(self.parts[index].hole_entity_id_groups.iter().flatten())
            .cloned()
            .collect::<BTreeSet<_>>();
        if requested.iter().any(|id| boundary.contains(id)) {
            return Err(invalid_part_entities(
                "outline and hole entities cannot be removed from membership",
            ));
        }
        for entity_id in &requested {
            self.ensure_entity_exists("part", entity_id)?;
            if !self.parts[index].entity_ids.contains(entity_id) {
                return Err(invalid_part_entities("entity is not a member of the part"));
            }
        }
        self.parts[index]
            .entity_ids
            .retain(|id| !requested.contains(id));
        self.refresh_part_dependencies(part_id);
        Ok(())
    }

    pub(crate) fn set_part_boundary(
        &mut self,
        part_id: &str,
        entity_ids: Vec<String>,
    ) -> CommandResult {
        if self.parts.iter().any(|part| part.id == part_id) {
            return Err(fixed_part_error());
        }
        let requested = non_empty_part_entity_set(entity_ids, "setPartBoundary")?;
        let index = self
            .parts
            .iter()
            .position(|part| part.id == part_id)
            .ok_or_else(|| CommandError::missing("part", part_id))?;
        if requested
            .iter()
            .any(|id| !self.parts[index].entity_ids.contains(id))
        {
            return Err(invalid_part_entities(
                "boundary entities must already belong to the part",
            ));
        }
        let selected = requested
            .iter()
            .map(|id| {
                self.entity(id)
                    .cloned()
                    .ok_or_else(|| CommandError::missing("entity", id))
            })
            .collect::<CommandResult<Vec<_>>>()?;
        let (outline, holes) = classify_part_loops(&selected)?;
        let boundary_ids = outline
            .ids
            .iter()
            .chain(holes.iter().flat_map(|hole| hole.ids.iter()))
            .cloned()
            .collect::<BTreeSet<_>>();
        if boundary_ids != requested {
            return Err(invalid_part_entities(
                "boundary selection must contain only closed contours",
            ));
        }
        self.parts[index].outline_entity_ids = outline.ids;
        self.parts[index].hole_entity_id_groups = holes.into_iter().map(|item| item.ids).collect();

        let outline = part_outline_loop(self, &self.parts[index])
            .ok_or_else(|| invalid_part_entities("part outline is not closed"))?;
        let retained_entities = self.parts[index]
            .entity_ids
            .iter()
            .filter(|id| {
                requested.contains(*id)
                    || self.entity(id).is_some_and(|entity| {
                        point_inside_or_on_boundary(entity_anchor(entity), &outline.vertices)
                    })
            })
            .cloned()
            .collect::<Vec<_>>();
        let retained_texts = self.parts[index]
            .free_text_ids
            .iter()
            .filter(|id| {
                self.free_texts.iter().any(|text| {
                    &text.id == *id
                        && point_inside_or_on_boundary(text.position_mm, &outline.vertices)
                })
            })
            .cloned()
            .collect::<Vec<_>>();
        self.parts[index].entity_ids = retained_entities;
        self.parts[index].free_text_ids = retained_texts;
        self.refresh_part_dependencies(part_id);
        Ok(())
    }

    fn refresh_part_dependencies(&mut self, part_id: &str) {
        let Some(index) = self.parts.iter().position(|part| part.id == part_id) else {
            return;
        };
        loop {
            let available = self.parts[index]
                .entity_ids
                .iter()
                .chain(self.parts[index].derived_element_ids.iter())
                .cloned()
                .collect::<BTreeSet<_>>();
            let retained = self.parts[index]
                .derived_element_ids
                .iter()
                .filter(|id| {
                    self.derived_element(id).is_some_and(|derived| {
                        derived_element_source_ids(derived).all(|source| available.contains(source))
                    })
                })
                .cloned()
                .collect::<Vec<_>>();
            if retained == self.parts[index].derived_element_ids {
                break;
            }
            self.parts[index].derived_element_ids = retained;
        }
        let entity_ids = self.parts[index]
            .entity_ids
            .iter()
            .cloned()
            .collect::<BTreeSet<_>>();
        let retained_measurements = self.parts[index]
            .measurement_annotation_ids
            .iter()
            .filter(|id| {
                self.view_annotations
                    .measurement_annotations
                    .iter()
                    .find(|annotation| &annotation.id == *id)
                    .is_some_and(|annotation| {
                        annotation
                            .targets
                            .iter()
                            .all(|target| entity_ids.contains(target_entity_id(target)))
                    })
            })
            .cloned()
            .collect::<Vec<_>>();
        self.parts[index].measurement_annotation_ids = retained_measurements;

        let derived_ids = self
            .derived_elements
            .iter()
            .map(|item| item.id.clone())
            .collect::<Vec<_>>();
        let measurement_ids = self
            .measurement_annotations()
            .iter()
            .map(|item| item.id.clone())
            .collect::<Vec<_>>();
        for id in derived_ids {
            self.auto_assign_derived_element_to_part(&id);
        }
        for id in measurement_ids {
            self.auto_assign_measurement_to_part(&id);
        }
    }

    pub(in crate::document) fn auto_assign_entity_to_part(&mut self, entity_id: &str) {
        let Some(anchor) = self.entity(entity_id).map(entity_anchor) else {
            return;
        };
        if let Some(index) = unique_containing_part_index(self, anchor) {
            if !self.parts[index]
                .entity_ids
                .iter()
                .any(|id| id == entity_id)
            {
                self.parts[index].entity_ids.push(entity_id.to_owned());
                self.parts[index].entity_ids.sort();
            }
        }
    }

    pub(in crate::document) fn auto_assign_free_text_to_part(&mut self, free_text_id: &str) {
        let Some(anchor) = self
            .free_texts
            .iter()
            .find(|item| item.id == free_text_id)
            .map(|item| item.position_mm)
        else {
            return;
        };
        if let Some(index) = unique_containing_part_index(self, anchor) {
            self.parts[index]
                .free_text_ids
                .push(free_text_id.to_owned());
            self.parts[index].free_text_ids.sort();
            self.parts[index].free_text_ids.dedup();
        }
    }

    pub(in crate::document) fn auto_assign_derived_element_to_part(
        &mut self,
        derived_element_id: &str,
    ) {
        let Some(derived) = self.derived_element(derived_element_id) else {
            return;
        };
        let source_ids = derived_element_source_ids(derived)
            .cloned()
            .collect::<Vec<_>>();
        let matches = self
            .parts
            .iter()
            .enumerate()
            .filter(|(_, part)| {
                !part.locked
                    && source_ids.iter().all(|source_id| {
                        part.entity_ids.contains(source_id)
                            || part.derived_element_ids.contains(source_id)
                    })
            })
            .map(|(index, _)| index)
            .collect::<Vec<_>>();
        if let [index] = matches.as_slice() {
            self.parts[*index]
                .derived_element_ids
                .push(derived_element_id.to_owned());
            self.parts[*index].derived_element_ids.sort();
            self.parts[*index].derived_element_ids.dedup();
        }
    }

    pub(in crate::document) fn auto_assign_measurement_to_part(&mut self, annotation_id: &str) {
        let Some(annotation) = self
            .measurement_annotations()
            .iter()
            .find(|item| item.id == annotation_id)
        else {
            return;
        };
        let target_ids = annotation
            .targets
            .iter()
            .map(target_entity_id)
            .collect::<Vec<_>>();
        let matches = self
            .parts
            .iter()
            .enumerate()
            .filter(|(_, part)| {
                !part.locked && target_ids.iter().all(|id| part.entity_ids.contains(*id))
            })
            .map(|(index, _)| index)
            .collect::<Vec<_>>();
        if let [index] = matches.as_slice() {
            self.parts[*index]
                .measurement_annotation_ids
                .push(annotation_id.to_owned());
            self.parts[*index].measurement_annotation_ids.sort();
            self.parts[*index].measurement_annotation_ids.dedup();
        }
    }

    pub(in crate::document) fn reconcile_parts(&mut self) {
        let entity_ids = self
            .entities
            .iter()
            .map(|item| item.id.clone())
            .collect::<BTreeSet<_>>();
        let derived_ids = self
            .derived_elements
            .iter()
            .map(|item| item.id.clone())
            .collect::<BTreeSet<_>>();
        let free_text_ids = self
            .free_texts
            .iter()
            .map(|item| item.id.clone())
            .collect::<BTreeSet<_>>();
        let measurement_ids = self
            .measurement_annotations()
            .iter()
            .map(|item| item.id.clone())
            .collect::<BTreeSet<_>>();

        for part in &mut self.parts {
            part.entity_ids.retain(|id| entity_ids.contains(id));
            part.derived_element_ids
                .retain(|id| derived_ids.contains(id));
            part.free_text_ids.retain(|id| free_text_ids.contains(id));
            part.measurement_annotation_ids
                .retain(|id| measurement_ids.contains(id));
            part.hole_entity_id_groups
                .retain(|group| group.iter().all(|id| entity_ids.contains(id)));
        }

        let removed = self
            .parts
            .iter()
            .filter(|part| part_outline_loop(self, part).is_none())
            .map(|part| (part.id.clone(), part.name.clone()))
            .collect::<Vec<_>>();
        if removed.is_empty() {
            return;
        }
        let removed_ids = removed
            .iter()
            .map(|(id, _)| id.as_str())
            .collect::<BTreeSet<_>>();
        self.parts
            .retain(|part| !removed_ids.contains(part.id.as_str()));
        for (part_id, name) in removed {
            self.document_warnings.push(DocumentWarning {
                kind: DocumentWarningKind::PartRemoved,
                derived_element_id: String::new(),
                measurement_annotation_id: String::new(),
                part_id,
                message: format!(
                    "part '{name}' was ungrouped because its outline is no longer closed"
                ),
            });
        }
    }
}

fn part_selection(part: &Part) -> SelectionReference {
    SelectionReference {
        entity_ids: part.entity_ids.clone(),
        derived_element_ids: part.derived_element_ids.clone(),
        constraint_ids: Vec::new(),
        measurement_annotation_ids: part.measurement_annotation_ids.clone(),
        stitch_start_point_ids: Vec::new(),
        free_text_ids: part.free_text_ids.clone(),
    }
}

pub(in crate::document) fn validate_parts_for_document(
    document: &ProjectDocument,
) -> Result<(), DocumentValidationError> {
    let mut ids = BTreeSet::new();
    let mut names = BTreeSet::new();
    let mut member_entities = BTreeSet::new();
    let mut member_derived = BTreeSet::new();
    let mut member_texts = BTreeSet::new();
    let mut member_measurements = BTreeSet::new();
    for part in &document.parts {
        if part.id.trim().is_empty() {
            return Err(DocumentValidationError::EmptyId("part"));
        }
        if !ids.insert(part.id.as_str()) {
            return Err(DocumentValidationError::DuplicateId {
                kind: "part",
                id: part.id.clone(),
            });
        }
        let normalized_name = part.name.trim();
        if normalized_name.is_empty() {
            return Err(DocumentValidationError::InvalidValue {
                field: "part name",
                reason: "must not be empty",
            });
        }
        if !names.insert(normalized_name) {
            return Err(DocumentValidationError::InvalidValue {
                field: "part name",
                reason: "must be unique",
            });
        }
        if !part.origin_mm.x_mm.is_finite() || !part.origin_mm.y_mm.is_finite() {
            return Err(DocumentValidationError::InvalidValue {
                field: "part origin",
                reason: "must be finite",
            });
        }
        if part.quantity == 0 {
            return Err(DocumentValidationError::InvalidValue {
                field: "part quantity",
                reason: "must be at least 1",
            });
        }
        let outline =
            part_outline_loop(document, part).ok_or(DocumentValidationError::InvalidValue {
                field: "part outlineEntityIds",
                reason: "must describe a closed outline",
            })?;
        if part
            .outline_entity_ids
            .iter()
            .collect::<BTreeSet<_>>()
            .len()
            != part.outline_entity_ids.len()
        {
            return Err(DocumentValidationError::InvalidValue {
                field: "part outlineEntityIds",
                reason: "must not contain duplicate entities",
            });
        }
        for group in &part.hole_entity_id_groups {
            if group.iter().collect::<BTreeSet<_>>().len() != group.len() {
                return Err(DocumentValidationError::InvalidValue {
                    field: "part holeEntityIdGroups",
                    reason: "must not contain duplicate entities",
                });
            }
            let Some(hole) = closed_loop_from_ids(document, group) else {
                return Err(DocumentValidationError::InvalidValue {
                    field: "part holeEntityIdGroups",
                    reason: "must describe closed holes",
                });
            };
            if !point_inside_or_on_boundary(polygon_centroid(&hole.vertices), &outline.vertices) {
                return Err(DocumentValidationError::InvalidValue {
                    field: "part holeEntityIdGroups",
                    reason: "must be inside the part outline",
                });
            }
        }
        validate_unique_members(
            &part.entity_ids,
            &mut member_entities,
            "part entity membership",
        )?;
        validate_unique_members(
            &part.derived_element_ids,
            &mut member_derived,
            "part derived element membership",
        )?;
        validate_unique_members(
            &part.free_text_ids,
            &mut member_texts,
            "part free text membership",
        )?;
        validate_unique_members(
            &part.measurement_annotation_ids,
            &mut member_measurements,
            "part measurement membership",
        )?;
    }
    Ok(())
}

fn validate_unique_members<'a>(
    ids: &'a [String],
    global: &mut BTreeSet<&'a str>,
    field: &'static str,
) -> Result<(), DocumentValidationError> {
    let mut local = BTreeSet::new();
    for id in ids {
        if !local.insert(id.as_str()) || !global.insert(id.as_str()) {
            return Err(DocumentValidationError::InvalidValue {
                field,
                reason: "must not contain duplicate membership",
            });
        }
    }
    Ok(())
}

fn invalid_part_entities(reason: &'static str) -> CommandError {
    CommandError::InvalidValue {
        field: "part entityIds",
        reason,
    }
}

fn non_empty_part_entity_set(
    entity_ids: Vec<String>,
    operation: &'static str,
) -> CommandResult<BTreeSet<String>> {
    let ids = entity_ids.into_iter().collect::<BTreeSet<_>>();
    if ids.is_empty() {
        return Err(CommandError::InvalidValue {
            field: operation,
            reason: "must include at least one entity",
        });
    }
    Ok(ids)
}

fn classify_part_loops(entities: &[Entity]) -> CommandResult<(ClosedLoop, Vec<ClosedLoop>)> {
    let mut loops = closed_loops(entities);
    if loops.is_empty() {
        return Err(invalid_part_entities("must include a closed outline"));
    }
    loops.sort_by(|lhs, rhs| rhs.area.abs().total_cmp(&lhs.area.abs()));
    let outline = loops.remove(0);
    for candidate in &loops {
        if !point_inside_or_on_boundary(polygon_centroid(&candidate.vertices), &outline.vertices) {
            return Err(invalid_part_entities(
                "closed contours outside the outline are not allowed",
            ));
        }
    }
    Ok((outline, loops))
}

fn validate_part_name(parts: &[Part], current_id: Option<&str>, name: &str) -> CommandResult {
    let normalized = name.trim();
    if normalized.is_empty() {
        return Err(CommandError::InvalidValue {
            field: "part name",
            reason: "must not be empty",
        });
    }
    if parts
        .iter()
        .any(|part| Some(part.id.as_str()) != current_id && part.name.trim() == normalized)
    {
        return Err(CommandError::InvalidValue {
            field: "part name",
            reason: "must be unique",
        });
    }
    Ok(())
}

fn validate_part_origin(origin: Point2) -> CommandResult {
    if origin.x_mm.is_finite() && origin.y_mm.is_finite() {
        Ok(())
    } else {
        Err(CommandError::InvalidValue {
            field: "part origin",
            reason: "must be finite",
        })
    }
}

fn unique_containing_part_index(document: &ProjectDocument, point: Point2) -> Option<usize> {
    let matches = document
        .parts
        .iter()
        .enumerate()
        .filter(|(_, part)| {
            !part.locked
                && part_outline_loop(document, part)
                    .is_some_and(|outline| point_inside_or_on_boundary(point, &outline.vertices))
        })
        .map(|(index, _)| index)
        .collect::<Vec<_>>();
    match matches.as_slice() {
        [index] => Some(*index),
        _ => None,
    }
}

fn part_outline_loop(document: &ProjectDocument, part: &Part) -> Option<ClosedLoop> {
    closed_loop_from_ids(document, &part.outline_entity_ids)
}

fn closed_loop_from_ids(document: &ProjectDocument, ids: &[String]) -> Option<ClosedLoop> {
    let entities = ids
        .iter()
        .map(|id| document.entity(id).cloned())
        .collect::<Option<Vec<_>>>()?;
    closed_loops(&entities)
        .into_iter()
        .find(|candidate| candidate.ids.len() == ids.len())
}

fn closed_loops(entities: &[Entity]) -> Vec<ClosedLoop> {
    let mut result = Vec::new();
    let mut segments = Vec::new();
    for entity in entities {
        match entity.kind {
            EntityKind::Circle(circle) => {
                let vertices = (0..64)
                    .map(|index| {
                        let angle = std::f64::consts::TAU * index as f64 / 64.0;
                        Point2::new(
                            circle.center.x_mm + circle.radius_mm * angle.cos(),
                            circle.center.y_mm + circle.radius_mm * angle.sin(),
                        )
                    })
                    .collect::<Vec<_>>();
                result.push(ClosedLoop {
                    ids: vec![entity.id.clone()],
                    area: signed_area(&vertices),
                    vertices,
                });
            }
            EntityKind::LineSegment(line) => segments.push(ContourSegment {
                id: entity.id.clone(),
                start: line.start,
                end: line.end,
                interior: Vec::new(),
            }),
            EntityKind::Arc(arc) => {
                let count = ((arc.sweep_angle_rad.abs() / (std::f64::consts::PI / 24.0)).ceil()
                    as usize)
                    .max(2);
                segments.push(ContourSegment {
                    id: entity.id.clone(),
                    start: arc_point(arc, 0.0),
                    end: arc_point(arc, 1.0),
                    interior: (1..count)
                        .map(|index| arc_point(arc, index as f64 / count as f64))
                        .collect(),
                });
            }
            EntityKind::Point(_) | EntityKind::CenterLine(_) => {}
        }
    }

    for component in segment_components(&segments) {
        if let Some(ordered) = order_closed_segments(&component) {
            let ids = ordered.iter().map(|segment| segment.id.clone()).collect();
            let vertices = ordered
                .iter()
                .flat_map(|segment| {
                    std::iter::once(segment.start).chain(segment.interior.iter().copied())
                })
                .collect::<Vec<_>>();
            result.push(ClosedLoop {
                ids,
                area: signed_area(&vertices),
                vertices,
            });
        }
    }
    result
}

fn segment_components(segments: &[ContourSegment]) -> Vec<Vec<ContourSegment>> {
    let mut visited = vec![false; segments.len()];
    let mut result = Vec::new();
    for start in 0..segments.len() {
        if visited[start] {
            continue;
        }
        visited[start] = true;
        let mut queue = VecDeque::from([start]);
        let mut component = Vec::new();
        while let Some(index) = queue.pop_front() {
            component.push(segments[index].clone());
            for candidate in 0..segments.len() {
                if !visited[candidate] && segments_touch(&segments[index], &segments[candidate]) {
                    visited[candidate] = true;
                    queue.push_back(candidate);
                }
            }
        }
        result.push(component);
    }
    result
}

fn order_closed_segments(segments: &[ContourSegment]) -> Option<Vec<ContourSegment>> {
    if segments.len() < 2 {
        return None;
    }
    for reversed in [false, true] {
        let mut remaining = segments.to_vec();
        let mut first = remaining.remove(0);
        if reversed {
            reverse_segment(&mut first);
        }
        let mut ordered = vec![first.clone()];
        let mut failed = false;
        while !remaining.is_empty() {
            let current_end = ordered.last()?.end;
            let Some(index) = remaining.iter().position(|candidate| {
                points_near(candidate.start, current_end) || points_near(candidate.end, current_end)
            }) else {
                failed = true;
                break;
            };
            let mut next = remaining.remove(index);
            if points_near(next.end, current_end) {
                reverse_segment(&mut next);
            }
            ordered.push(next);
        }
        if !failed && points_near(ordered.last()?.end, ordered.first()?.start) {
            return Some(ordered);
        }
    }
    None
}

fn reverse_segment(segment: &mut ContourSegment) {
    std::mem::swap(&mut segment.start, &mut segment.end);
    segment.interior.reverse();
}

fn segments_touch(lhs: &ContourSegment, rhs: &ContourSegment) -> bool {
    points_near(lhs.start, rhs.start)
        || points_near(lhs.start, rhs.end)
        || points_near(lhs.end, rhs.start)
        || points_near(lhs.end, rhs.end)
}

fn points_near(lhs: Point2, rhs: Point2) -> bool {
    (lhs.x_mm - rhs.x_mm).hypot(lhs.y_mm - rhs.y_mm) <= PART_GEOMETRY_TOLERANCE_MM
}

fn arc_point(arc: Arc, ratio: f64) -> Point2 {
    let angle = arc.start_angle_rad + arc.sweep_angle_rad * ratio;
    Point2::new(
        arc.center.x_mm + arc.radius_mm * angle.cos(),
        arc.center.y_mm + arc.radius_mm * angle.sin(),
    )
}

fn entity_anchor(entity: &Entity) -> Point2 {
    match entity.kind {
        EntityKind::Point(point) => point,
        EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => Point2::new(
            (line.start.x_mm + line.end.x_mm) / 2.0,
            (line.start.y_mm + line.end.y_mm) / 2.0,
        ),
        EntityKind::Circle(circle) => circle.center,
        EntityKind::Arc(arc) => arc_point(arc, 0.5),
    }
}

fn signed_area(vertices: &[Point2]) -> f64 {
    if vertices.len() < 3 {
        return 0.0;
    }
    vertices
        .iter()
        .zip(vertices.iter().cycle().skip(1))
        .take(vertices.len())
        .map(|(lhs, rhs)| lhs.x_mm * rhs.y_mm - rhs.x_mm * lhs.y_mm)
        .sum::<f64>()
        / 2.0
}

fn polygon_centroid(vertices: &[Point2]) -> Point2 {
    let count = vertices.len().max(1) as f64;
    Point2::new(
        vertices.iter().map(|point| point.x_mm).sum::<f64>() / count,
        vertices.iter().map(|point| point.y_mm).sum::<f64>() / count,
    )
}

fn point_inside_or_on_boundary(point: Point2, vertices: &[Point2]) -> bool {
    if vertices.len() < 3 {
        return false;
    }
    for (start, end) in vertices
        .iter()
        .zip(vertices.iter().cycle().skip(1))
        .take(vertices.len())
    {
        let dx = end.x_mm - start.x_mm;
        let dy = end.y_mm - start.y_mm;
        let length_sq = dx * dx + dy * dy;
        if length_sq > 0.0 {
            let ratio = (((point.x_mm - start.x_mm) * dx + (point.y_mm - start.y_mm) * dy)
                / length_sq)
                .clamp(0.0, 1.0);
            let projected = Point2::new(start.x_mm + ratio * dx, start.y_mm + ratio * dy);
            if (point.x_mm - projected.x_mm).hypot(point.y_mm - projected.y_mm)
                <= PART_GEOMETRY_TOLERANCE_MM
            {
                return true;
            }
        }
    }
    let mut inside = false;
    for (first, second) in vertices
        .iter()
        .zip(vertices.iter().cycle().skip(1))
        .take(vertices.len())
    {
        if (first.y_mm > point.y_mm) != (second.y_mm > point.y_mm) {
            let x = (second.x_mm - first.x_mm) * (point.y_mm - first.y_mm)
                / (second.y_mm - first.y_mm)
                + first.x_mm;
            if point.x_mm < x {
                inside = !inside;
            }
        }
    }
    inside
}

#[derive(Debug, Clone, Copy)]
struct PartBounds {
    min_x: f64,
    max_x: f64,
    min_y: f64,
    max_y: f64,
}

impl PartBounds {
    fn width(self) -> f64 {
        self.max_x - self.min_x
    }

    fn height(self) -> f64 {
        self.max_y - self.min_y
    }

    fn center_x(self) -> f64 {
        (self.min_x + self.max_x) / 2.0
    }

    fn center_y(self) -> f64 {
        (self.min_y + self.max_y) / 2.0
    }
}

fn validated_arrangement_ids(
    document: &ProjectDocument,
    part_ids: Vec<String>,
    minimum: usize,
    field: &'static str,
) -> CommandResult<Vec<String>> {
    let ids = part_ids.into_iter().collect::<BTreeSet<_>>();
    if ids.len() < minimum {
        return Err(CommandError::InvalidValue {
            field,
            reason: "does not include enough unique parts",
        });
    }
    for id in &ids {
        document
            .parts
            .iter()
            .find(|part| &part.id == id)
            .ok_or_else(|| CommandError::missing("part", id))?;
    }
    Ok(ids.into_iter().collect())
}

fn fixed_part_error() -> CommandError {
    CommandError::InvalidValue {
        field: "part fixed",
        reason: "part shape and membership cannot be changed; ungroup the part before editing",
    }
}

fn part_bounds(document: &ProjectDocument, part_id: &str) -> CommandResult<PartBounds> {
    let part = document
        .parts
        .iter()
        .find(|part| part.id == part_id)
        .ok_or_else(|| CommandError::missing("part", part_id))?;
    let outline = part_outline_loop(document, part)
        .ok_or_else(|| invalid_part_entities("part outline is not closed"))?;
    Ok(PartBounds {
        min_x: outline
            .vertices
            .iter()
            .map(|point| point.x_mm)
            .fold(f64::INFINITY, f64::min),
        max_x: outline
            .vertices
            .iter()
            .map(|point| point.x_mm)
            .fold(f64::NEG_INFINITY, f64::max),
        min_y: outline
            .vertices
            .iter()
            .map(|point| point.y_mm)
            .fold(f64::INFINITY, f64::min),
        max_y: outline
            .vertices
            .iter()
            .map(|point| point.y_mm)
            .fold(f64::NEG_INFINITY, f64::max),
    })
}

fn target_entity_id(target: &ConstraintTarget) -> &String {
    match target {
        ConstraintTarget::Entity(entity_id) | ConstraintTarget::ControlPoint { entity_id, .. } => {
            entity_id
        }
    }
}
