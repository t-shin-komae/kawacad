use super::*;
use crate::derived::OffsetDirection;

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
/// 派生要素 preflight の種別。
pub enum DerivedElementPreflightKind {
    /// オフセット元候補を評価する。
    OffsetCurve,
    /// フィレット元候補を評価する。
    Fillet,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
/// オフセット元として利用者へ提示する範囲。
pub enum OffsetSourceScope {
    /// 単一要素。
    SingleElement,
    /// 利用者が明示選択した連続区間。
    SelectedRange,
    /// 接続された閉輪郭。
    ClosedContour,
}

#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
/// Core が正規化したオフセット元候補。
pub struct OffsetSourceOption {
    /// UI が選択肢表示に使う範囲種別。
    pub scope: OffsetSourceScope,
    /// 順序付きの正規元参照。
    pub source_entity_ids: Vec<String>,
    /// 派生要素の解決済み形状から選択した範囲。
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub source_resolved_entity_ids: Vec<String>,
    /// クリック位置から決定した方向。
    pub direction: OffsetDirection,
}

#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
/// 派生要素作成・更新前の意味解釈結果。
pub struct DerivedElementPreflightResult {
    /// 評価した派生要素種別。
    pub kind: DerivedElementPreflightKind,
    #[serde(default)]
    /// オフセット元の提示候補。
    pub offset_options: Vec<OffsetSourceOption>,
    #[serde(default)]
    /// フィレット用の正規元参照。
    pub source_entity_ids: Vec<String>,
    #[serde(default)]
    /// 既存フィレットを更新する場合の ID。
    pub update_derived_element_id: Option<String>,
    #[serde(default)]
    /// フィレット元を閉輪郭として扱うか。
    pub closed: bool,
}

#[derive(Debug, Clone)]
struct ContourSegment {
    entity_id: String,
    source_id: String,
    start: Point2,
    end: Point2,
    interior: Vec<Point2>,
}

impl ProjectDocument {
    /// 画面上の候補 ID とクリック位置から派生要素の正規入力を求める。
    pub fn preflight_derived_element(
        &self,
        kind: DerivedElementPreflightKind,
        hit_entity_id: Option<String>,
        selected_entity_ids: Vec<String>,
        click_point: Option<Point2>,
    ) -> CommandResult<DerivedElementPreflightResult> {
        match kind {
            DerivedElementPreflightKind::OffsetCurve => {
                self.preflight_offset(hit_entity_id, selected_entity_ids, click_point)
            }
            DerivedElementPreflightKind::Fillet => {
                self.preflight_fillet(hit_entity_id, selected_entity_ids)
            }
        }
    }

    fn preflight_offset(
        &self,
        hit_entity_id: Option<String>,
        selected_entity_ids: Vec<String>,
        click_point: Option<Point2>,
    ) -> CommandResult<DerivedElementPreflightResult> {
        let hit_id = hit_entity_id.ok_or(CommandError::InvalidValue {
            field: "derived element preflight",
            reason: "offset preflight requires a hit entity",
        })?;
        let (hit_entity, hit_root, hit_derived) = self.resolve_preflight_entity(&hit_id)?;
        let mut selected_roots = Vec::new();
        for selected in &selected_entity_ids {
            let (_, root, _) = self.resolve_preflight_entity(selected)?;
            if !selected_roots.contains(&root) {
                selected_roots.push(root);
            }
        }
        if selected_entity_ids.len() > 1 {
            if let Some(derived_id) = hit_derived.as_deref() {
                if let Some(resolved_ids) =
                    self.selected_fillet_resolved_ids(derived_id, &selected_entity_ids)?
                {
                    let resolved = self
                        .derived_element(derived_id)
                        .ok_or_else(|| CommandError::missing("derived element", derived_id))?;
                    let resolved_entities = self.resolve_derived_element(resolved)?;
                    let selected_resolved_entities = resolved_ids
                        .iter()
                        .filter_map(|id| {
                            resolved_entities
                                .iter()
                                .find(|entity| &entity.id == id)
                                .cloned()
                        })
                        .collect::<Vec<_>>();
                    let ordered_sources =
                        ordered_continuous_offset_sources(&selected_resolved_entities)?;
                    let direction_entity = ordered_sources
                        .iter()
                        .find(|entity| entity.id == hit_entity.id)
                        .unwrap_or(&hit_entity);
                    let ordered_resolved_ids = ordered_sources
                        .iter()
                        .map(|entity| entity.id.clone())
                        .collect();
                    return Ok(DerivedElementPreflightResult {
                        kind: DerivedElementPreflightKind::OffsetCurve,
                        offset_options: vec![OffsetSourceOption {
                            scope: OffsetSourceScope::SelectedRange,
                            source_entity_ids: vec![derived_id.to_owned()],
                            source_resolved_entity_ids: ordered_resolved_ids,
                            direction: offset_direction(direction_entity, click_point),
                        }],
                        source_entity_ids: Vec::new(),
                        update_derived_element_id: None,
                        closed: false,
                    });
                }
            }
        }
        if selected_roots.len() > 1 {
            let ordered_sources = self.ordered_selected_offset_sources(&selected_roots)?;
            let direction_entity = ordered_sources
                .iter()
                .find(|entity| entity.id == hit_entity.id)
                .unwrap_or(&hit_entity);
            return Ok(DerivedElementPreflightResult {
                kind: DerivedElementPreflightKind::OffsetCurve,
                offset_options: vec![OffsetSourceOption {
                    scope: OffsetSourceScope::SelectedRange,
                    source_entity_ids: selected_roots,
                    source_resolved_entity_ids: Vec::new(),
                    direction: offset_direction(direction_entity, click_point),
                }],
                source_entity_ids: Vec::new(),
                update_derived_element_id: None,
                closed: false,
            });
        }
        let single_resolved_ids = hit_derived
            .as_deref()
            .and_then(|derived_id| self.derived_element(derived_id))
            .and_then(|derived| match derived.kind {
                DerivedElementKind::Fillet(_) => Some(vec![hit_entity.id.clone()]),
                _ => None,
            })
            .unwrap_or_default();
        let single = OffsetSourceOption {
            scope: OffsetSourceScope::SingleElement,
            source_entity_ids: vec![hit_root.clone()],
            source_resolved_entity_ids: single_resolved_ids,
            direction: offset_direction(&hit_entity, click_point),
        };
        let closed = if let Some(derived_id) = hit_derived {
            let derived = self.derived_element(&derived_id);
            match derived.map(|item| &item.kind) {
                Some(DerivedElementKind::Fillet(fillet)) if fillet.closed => {
                    self.closed_derived_option(&derived_id, click_point)
                }
                _ => None,
            }
        } else {
            self.closed_base_option(&hit_id, click_point)
        };
        let mut options = Vec::new();
        if let Some(closed) = closed {
            options.push(closed);
        }
        options.push(single);
        Ok(DerivedElementPreflightResult {
            kind: DerivedElementPreflightKind::OffsetCurve,
            offset_options: options,
            source_entity_ids: Vec::new(),
            update_derived_element_id: None,
            closed: false,
        })
    }

    fn preflight_fillet(
        &self,
        hit_entity_id: Option<String>,
        selected_entity_ids: Vec<String>,
    ) -> CommandResult<DerivedElementPreflightResult> {
        let mut inputs = selected_entity_ids;
        if inputs.is_empty() {
            if let Some(hit) = hit_entity_id {
                inputs.push(hit);
            }
        }
        let mut sources = Vec::new();
        for id in &inputs {
            let source = self.fillet_source_id(id)?;
            if !sources.contains(&source) {
                sources.push(source);
            }
        }
        if sources.len() < 2 {
            return Err(CommandError::InvalidValue {
                field: "derived element preflight",
                reason: "fillet requires at least two source entities",
            });
        }
        let overlapping = self
            .derived_elements
            .iter()
            .filter_map(|derived| match &derived.kind {
                DerivedElementKind::Fillet(fillet)
                    if fillet
                        .source_entity_ids
                        .iter()
                        .any(|id| sources.contains(id)) =>
                {
                    Some((derived, fillet))
                }
                _ => None,
            })
            .collect::<Vec<_>>();
        let (sources, update, was_closed) = if let [(derived, fillet)] = overlapping.as_slice() {
            if candidate_closes_path(self, &fillet.source_entity_ids, &sources) {
                (
                    fillet.source_entity_ids.clone(),
                    Some(derived.id.clone()),
                    true,
                )
            } else {
                (
                    merged_sources(&fillet.source_entity_ids, &sources),
                    Some(derived.id.clone()),
                    fillet.closed,
                )
            }
        } else {
            (sources, None, false)
        };
        if !fillet_sources_are_connected(self, &sources) {
            return Err(CommandError::InvalidValue {
                field: "derived element preflight",
                reason: "fillet source entities must form one connected path",
            });
        }
        let closed = was_closed || sources_form_closed_contour(self, &sources);
        let sources = canonical_fillet_source_ids(self, &sources, closed)?;
        Ok(DerivedElementPreflightResult {
            kind: DerivedElementPreflightKind::Fillet,
            offset_options: Vec::new(),
            source_entity_ids: sources,
            update_derived_element_id: update,
            closed,
        })
    }

    fn ordered_selected_offset_sources(&self, source_ids: &[String]) -> CommandResult<Vec<Entity>> {
        let mut sources = Vec::new();
        for source_id in source_ids {
            if let Some(entity) = self.entity(source_id) {
                sources.push(entity.clone());
                continue;
            }
            let derived = self
                .derived_element(source_id)
                .ok_or_else(|| CommandError::missing("derived element", source_id))?;
            sources.extend(self.resolve_derived_element(derived)?);
        }
        ordered_continuous_offset_sources(&sources)
    }

    fn selected_fillet_resolved_ids(
        &self,
        derived_id: &str,
        selected_entity_ids: &[String],
    ) -> CommandResult<Option<Vec<String>>> {
        let Some(derived) = self.derived_element(derived_id) else {
            return Ok(None);
        };
        let DerivedElementKind::Fillet(fillet) = &derived.kind else {
            return Ok(None);
        };
        let resolved = self.resolve_derived_element(derived)?;
        let resolved_ids = resolved
            .iter()
            .map(|entity| entity.id.as_str())
            .collect::<BTreeSet<_>>();
        if selected_entity_ids
            .iter()
            .all(|id| resolved_ids.contains(id.as_str()))
        {
            return Ok(Some(selected_entity_ids.to_vec()));
        }

        let selected_source_ids = selected_entity_ids.iter().collect::<BTreeSet<_>>();
        if !selected_entity_ids
            .iter()
            .all(|id| fillet.source_entity_ids.contains(id))
        {
            return Ok(None);
        }

        let mut sources = Vec::new();
        for source_id in &fillet.source_entity_ids {
            let Some(entity) = self.entity(source_id) else {
                return Ok(None);
            };
            sources.push(entity.clone());
        }
        let ordered_sources = ordered_fillet_source_entities(&sources, fillet.closed)?;
        let selected = ordered_sources
            .iter()
            .map(|entity| selected_source_ids.contains(&entity.id))
            .collect::<Vec<_>>();
        let selected_count = selected.iter().filter(|value| **value).count();
        if selected_count != selected_entity_ids.len() {
            return Ok(None);
        }

        let closed =
            fillet.closed && selected.first() == Some(&true) && selected.last() == Some(&true);
        let start = if closed {
            selected
                .iter()
                .enumerate()
                .find(|(index, value)| {
                    **value && !selected[(*index + selected.len() - 1) % selected.len()]
                })
                .map(|(index, _)| index)
                .unwrap_or(0)
        } else {
            selected.iter().position(|value| *value).unwrap_or(0)
        };

        let mut indices = Vec::new();
        let mut index = start;
        loop {
            if !selected[index] {
                break;
            }
            indices.push(index);
            index = (index + 1) % selected.len();
            if index == start {
                break;
            }
        }
        if indices.len() != selected_count {
            return Err(CommandError::InvalidValue {
                field: "offset source",
                reason: "selected fillet sources must form one continuous range",
            });
        }

        let all_selected = selected_count == selected.len();
        let mut range_ids = Vec::new();
        for (position, source_index) in indices.iter().enumerate() {
            range_ids.push(crate::derived::resolved_entity_id(
                derived_id,
                source_index * 2,
            ));
            let has_selected_next = position + 1 < indices.len() || all_selected;
            let arc_index = source_index * 2 + 1;
            let arc_id = crate::derived::resolved_entity_id(derived_id, arc_index);
            if has_selected_next && resolved_ids.contains(arc_id.as_str()) {
                range_ids.push(arc_id);
            }
        }
        Ok(Some(range_ids))
    }

    fn resolve_preflight_entity(
        &self,
        entity_id: &str,
    ) -> CommandResult<(Entity, String, Option<String>)> {
        if let Some(entity) = self.entity(entity_id) {
            return Ok((entity.clone(), entity.id.clone(), None));
        }
        for derived in &self.derived_elements {
            if let Ok(resolved) = self.resolve_derived_element(derived) {
                if let Some(entity) = resolved.into_iter().find(|entity| entity.id == entity_id) {
                    return Ok((entity, derived.id.clone(), Some(derived.id.clone())));
                }
            }
        }
        Err(CommandError::missing("entity", entity_id))
    }

    fn fillet_source_id(&self, entity_id: &str) -> CommandResult<String> {
        if self.entity(entity_id).is_some() {
            return Ok(entity_id.to_owned());
        }
        for derived in &self.derived_elements {
            let Ok(resolved) = self.resolve_derived_element(derived) else {
                continue;
            };
            let Some(index) = resolved.iter().position(|entity| entity.id == entity_id) else {
                continue;
            };
            if let DerivedElementKind::Fillet(fillet) = &derived.kind {
                if index.is_multiple_of(2) {
                    if let Some(source) = fillet.source_entity_ids.get(index / 2) {
                        return Ok(source.clone());
                    }
                }
            }
            return Ok(derived.id.clone());
        }
        Err(CommandError::missing("entity", entity_id))
    }

    fn closed_base_option(
        &self,
        entity_id: &str,
        click_point: Option<Point2>,
    ) -> Option<OffsetSourceOption> {
        let segments = base_segments(&self.entities);
        let start = segments
            .iter()
            .position(|segment| segment.entity_id == entity_id)?;
        for reversed in [false, true] {
            let ordered = ordered_closed_contour(start, reversed, &segments)?;
            let sources = ordered
                .iter()
                .map(|segment| segment.source_id.clone())
                .collect::<Vec<_>>();
            if sources.len() >= 2 && sources.iter().collect::<BTreeSet<_>>().len() == sources.len()
            {
                return Some(OffsetSourceOption {
                    scope: OffsetSourceScope::ClosedContour,
                    source_entity_ids: sources,
                    source_resolved_entity_ids: Vec::new(),
                    direction: closed_direction(&ordered, click_point),
                });
            }
        }
        None
    }

    fn closed_derived_option(
        &self,
        derived_id: &str,
        click_point: Option<Point2>,
    ) -> Option<OffsetSourceOption> {
        let derived = self.derived_element(derived_id)?;
        let entities = self.resolve_derived_element(derived).ok()?;
        let segments = base_segments(&entities);
        if segments.len() < 2 {
            return None;
        }
        for reversed in [false, true] {
            if let Some(ordered) = ordered_closed_contour(0, reversed, &segments) {
                return Some(OffsetSourceOption {
                    scope: OffsetSourceScope::ClosedContour,
                    source_entity_ids: vec![derived_id.to_owned()],
                    source_resolved_entity_ids: Vec::new(),
                    direction: closed_direction(&ordered, click_point),
                });
            }
        }
        None
    }
}

fn canonical_fillet_source_ids(
    document: &ProjectDocument,
    source_ids: &[String],
    closed: bool,
) -> CommandResult<Vec<String>> {
    let sources = source_ids
        .iter()
        .map(|id| {
            document
                .entity(id)
                .cloned()
                .ok_or_else(|| CommandError::missing("entity", id))
        })
        .collect::<CommandResult<Vec<_>>>()?;
    let ordered = ordered_continuous_offset_sources(&sources).map_err(|error| match error {
        CommandError::InvalidValue {
            field: "offset source",
            reason,
        } => CommandError::InvalidValue {
            field: "fillet source",
            reason,
        },
        other => other,
    })?;
    let ids = ordered
        .into_iter()
        .map(|entity| entity.id)
        .collect::<Vec<_>>();
    Ok(if closed {
        canonical_closed_source_ids(ids)
    } else {
        canonical_open_source_ids(ids)
    })
}

fn canonical_open_source_ids(ids: Vec<String>) -> Vec<String> {
    let mut reversed = ids.clone();
    reversed.reverse();
    if reversed < ids {
        reversed
    } else {
        ids
    }
}

fn canonical_closed_source_ids(ids: Vec<String>) -> Vec<String> {
    let Some(start) = ids
        .iter()
        .enumerate()
        .min_by_key(|(_, id)| *id)
        .map(|(index, _)| index)
    else {
        return ids;
    };
    let mut forward = ids.clone();
    forward.rotate_left(start);
    let mut reverse = ids;
    reverse.reverse();
    let reverse_start = reverse.iter().position(|id| id == &forward[0]).unwrap_or(0);
    reverse.rotate_left(reverse_start);
    if reverse < forward {
        reverse
    } else {
        forward
    }
}

fn fillet_sources_are_connected(document: &ProjectDocument, source_ids: &[String]) -> bool {
    let entities = source_ids
        .iter()
        .map(|id| document.entity(id).cloned())
        .collect::<Option<Vec<_>>>();
    let Some(entities) = entities else {
        return false;
    };
    let segments = base_segments(&entities);
    if segments.len() != entities.len() {
        return false;
    }
    let Some(first) = segments.first() else {
        return false;
    };
    let mut visited = vec![false; segments.len()];
    visited[0] = true;
    let mut queue = vec![(first.start, first.end)];
    while let Some(current) = queue.pop() {
        for (index, candidate) in segments.iter().enumerate() {
            if visited[index] {
                continue;
            }
            if close(current.0, candidate.start)
                || close(current.0, candidate.end)
                || close(current.1, candidate.start)
                || close(current.1, candidate.end)
            {
                visited[index] = true;
                queue.push((candidate.start, candidate.end));
            }
        }
    }
    visited.into_iter().all(|item| item)
}

fn base_segments(entities: &[Entity]) -> Vec<ContourSegment> {
    entities
        .iter()
        .filter_map(|entity| match entity.kind {
            EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => Some(ContourSegment {
                entity_id: entity.id.clone(),
                source_id: entity.id.clone(),
                start: line.start,
                end: line.end,
                interior: Vec::new(),
            }),
            EntityKind::Arc(arc) => {
                let count = ((arc.sweep_angle_rad.abs() / (std::f64::consts::PI / 16.0)).ceil()
                    as usize)
                    .max(2);
                let interior = (1..count)
                    .map(|index| point_on_arc(arc, index as f64 / count as f64))
                    .collect();
                Some(ContourSegment {
                    entity_id: entity.id.clone(),
                    source_id: entity.id.clone(),
                    start: point_on_arc(arc, 0.0),
                    end: point_on_arc(arc, 1.0),
                    interior,
                })
            }
            _ => None,
        })
        .collect()
}

fn point_on_arc(arc: Arc, ratio: f64) -> Point2 {
    let angle = arc.start_angle_rad + arc.sweep_angle_rad * ratio;
    Point2::new(
        arc.center.x_mm + arc.radius_mm * angle.cos(),
        arc.center.y_mm + arc.radius_mm * angle.sin(),
    )
}

fn ordered_closed_contour(
    start_index: usize,
    reversed: bool,
    segments: &[ContourSegment],
) -> Option<Vec<ContourSegment>> {
    let mut remaining = segments.to_vec();
    let first = orient(remaining.remove(start_index), reversed);
    let mut ordered = vec![first.clone()];
    while !remaining.is_empty() {
        let current_end = ordered.last()?.end;
        if close(current_end, first.start) && ordered.len() >= 2 {
            return Some(ordered);
        }
        let index = remaining.iter().position(|candidate| {
            close(candidate.start, current_end) || close(candidate.end, current_end)
        })?;
        let candidate = remaining.remove(index);
        let should_reverse = close(candidate.end, current_end);
        ordered.push(orient(candidate, should_reverse));
    }
    (ordered.len() >= 2 && close(ordered.last()?.end, first.start)).then_some(ordered)
}

fn orient(mut segment: ContourSegment, reversed: bool) -> ContourSegment {
    if reversed {
        std::mem::swap(&mut segment.start, &mut segment.end);
        segment.interior.reverse();
    }
    segment
}

fn close(first: Point2, second: Point2) -> bool {
    (first.x_mm - second.x_mm).hypot(first.y_mm - second.y_mm) <= 0.001
}

fn closed_direction(segments: &[ContourSegment], click: Option<Point2>) -> OffsetDirection {
    match click {
        Some(point) if point_inside(point, segments) => OffsetDirection::Inward,
        Some(_) => OffsetDirection::Outward,
        None => OffsetDirection::Inward,
    }
}

fn point_inside(point: Point2, segments: &[ContourSegment]) -> bool {
    let vertices = segments
        .iter()
        .flat_map(|segment| std::iter::once(segment.start).chain(segment.interior.iter().copied()))
        .collect::<Vec<_>>();
    if vertices.len() < 3 {
        return false;
    }
    let mut inside = false;
    for index in 0..vertices.len() {
        let first = vertices[index];
        let second = vertices[(index + 1) % vertices.len()];
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

fn offset_direction(entity: &Entity, click: Option<Point2>) -> OffsetDirection {
    let Some(point) = click else {
        return OffsetDirection::Left;
    };
    match entity.kind {
        EntityKind::LineSegment(line) | EntityKind::CenterLine(line) => {
            let cross = (line.end.x_mm - line.start.x_mm) * (point.y_mm - line.start.y_mm)
                - (line.end.y_mm - line.start.y_mm) * (point.x_mm - line.start.x_mm);
            if cross >= 0.0 {
                OffsetDirection::Left
            } else {
                OffsetDirection::Right
            }
        }
        EntityKind::Circle(circle) => {
            if (point.x_mm - circle.center.x_mm).hypot(point.y_mm - circle.center.y_mm)
                <= circle.radius_mm
            {
                OffsetDirection::Inward
            } else {
                OffsetDirection::Outward
            }
        }
        EntityKind::Arc(arc) => {
            if (point.x_mm - arc.center.x_mm).hypot(point.y_mm - arc.center.y_mm) <= arc.radius_mm {
                OffsetDirection::Right
            } else {
                OffsetDirection::Left
            }
        }
        _ => OffsetDirection::Left,
    }
}

fn candidate_closes_path(
    document: &ProjectDocument,
    existing: &[String],
    candidate: &[String],
) -> bool {
    existing.len() >= 3
        && existing.first().is_some_and(|id| candidate.contains(id))
        && existing.last().is_some_and(|id| candidate.contains(id))
        && sources_form_closed_contour(document, existing)
}

fn sources_form_closed_contour(document: &ProjectDocument, sources: &[String]) -> bool {
    let source_set = sources.iter().collect::<BTreeSet<_>>();
    let segments = base_segments(&document.entities)
        .into_iter()
        .filter(|segment| source_set.contains(&segment.source_id))
        .collect::<Vec<_>>();
    if segments.len() != source_set.len() {
        return false;
    }
    let Some(first_id) = sources.first() else {
        return false;
    };
    let Some(start) = segments
        .iter()
        .position(|segment| &segment.source_id == first_id)
    else {
        return false;
    };
    ordered_closed_contour(start, false, &segments).is_some()
        || ordered_closed_contour(start, true, &segments).is_some()
}

fn merged_sources(existing: &[String], candidate: &[String]) -> Vec<String> {
    let Some(shared) = candidate.iter().find(|id| existing.contains(id)) else {
        return append_unique(existing.to_vec(), candidate.iter().cloned());
    };
    if existing.last() == Some(shared) {
        let index = candidate.iter().position(|id| id == shared).unwrap_or(0);
        let after = candidate
            .iter()
            .skip(index + 1)
            .cloned()
            .collect::<Vec<_>>();
        return if after.is_empty() {
            append_unique(
                existing.to_vec(),
                candidate.iter().take(index).rev().cloned(),
            )
        } else {
            append_unique(existing.to_vec(), after)
        };
    }
    if existing.first() == Some(shared) {
        let index = candidate.iter().position(|id| id == shared).unwrap_or(0);
        let before = candidate.iter().take(index).cloned().collect::<Vec<_>>();
        return if before.is_empty() {
            append_unique(
                candidate.iter().skip(1).rev().cloned().collect(),
                existing.iter().cloned(),
            )
        } else {
            append_unique(before, existing.iter().cloned())
        };
    }
    append_unique(existing.to_vec(), candidate.iter().cloned())
}

fn append_unique<I: IntoIterator<Item = String>>(mut base: Vec<String>, values: I) -> Vec<String> {
    for value in values {
        if !base.contains(&value) {
            base.push(value);
        }
    }
    base
}
