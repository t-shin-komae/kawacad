//! プロジェクトドキュメントのルートとドキュメント単位の変更ロジック。

mod canvas_projection;
mod command_applier;
mod constraint_apply;
mod constraint_semantics;
mod constraint_status;
mod derived_elements;
mod derived_preflight;
mod entity_update;
mod history;
mod io;
mod measurement_annotations;
mod metadata;
mod output_model_builder;
mod parts;
mod planar_geometry;
mod preflight;
mod semantic_operations;
mod solver;
mod store;
mod target_resolution;
mod validation;

use crate::command::{
    CommandError, CommandResult, ConstraintCommandError, ConstraintCommandErrorCode,
    DocumentCommand, EntityGesture, EntityMetric, GestureAxis, GestureSnapConstraint,
    SelectionReference,
};
use crate::constraints::{
    Constraint, ConstraintKind, ConstraintStatus, ConstraintTarget, ConstraintValue,
    ControlPointKind,
};
use crate::derived::{DerivedElement, DerivedElementKind};
use crate::free_text::FreeText;
use crate::geometry::{Arc, Circle, Entity, EntityKind, LineSegment, Point2, GEOMETRY_EPSILON_MM};
use crate::layers::{Layer, LayerKind, LayerStyle};
use crate::measurement::{
    DimensionConstraintAnnotation, MeasurementAnnotation, MeasurementEvaluation, ViewAnnotations,
};
use crate::output::{
    BuildOutputDocumentModelOptions, BuildOutputDocumentModelResult, OutputBuildError,
};
use crate::parameters::Parameter;
use crate::parts::Part;
use crate::print::PrintSettings;
use crate::round_holes::RoundHole;
use crate::shared_styles::SharedStyle;
use crate::snapshot::{
    CanvasProjection, CanvasViewMode, DrawingEntityMetadata, DrawingSnapshot,
    ResolvedCanvasGeometry, ResolvedCanvasPoint,
};
use crate::stitch_start_points::StitchStartPoint;
use std::collections::BTreeSet;
use std::ops::{Deref, DerefMut};
use std::path::Path;

use command_applier::{
    stitch_start_point_position, translated_entity, validate_stitch_start_point, CommandApplier,
};
use constraint_apply::*;
use constraint_semantics::*;
use constraint_status::*;
use derived_elements::*;
pub use derived_preflight::{
    DerivedElementPreflightKind, DerivedElementPreflightResult, OffsetSourceOption,
    OffsetSourceScope,
};
use entity_update::*;
use history::HistoryStore;
use io::DocumentIo;
pub use metadata::{DocumentIoError, DocumentMetadata, DocumentValidationError};
use output_model_builder::OutputModelBuilder;
pub use parts::PartLibraryExport;
use parts::*;
use planar_geometry::*;
pub use preflight::ConstraintPreflightResult;
pub use semantic_operations::{SelectionBounds, SelectionClipboardExport};
use solver::ConstraintSolver;
use store::DocumentStore;
use target_resolution::*;
use validation::*;

/// 現在のプロジェクトファイル形式バージョン。
pub const FILE_FORMAT_VERSION: &str = "0.2.0";
/// `.lcraft` ファイル用の現在の JSON Schema バージョン。
pub const SCHEMA_VERSION: &str = "0.1.0";

/// KawaCAD プロジェクトのトップレベルドキュメント。
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ProjectDocument {
    /// 永続化されるドキュメント状態。
    #[serde(flatten)]
    pub(crate) store: DocumentStore,
    /// Undo/Redo 用の一時履歴。
    #[serde(skip, default)]
    history: HistoryStore,
}

#[derive(Debug, Clone)]
struct DocumentRollback {
    parameters: Vec<Parameter>,
    entities: Vec<Entity>,
    derived_elements: Vec<DerivedElement>,
    free_texts: Vec<FreeText>,
    round_holes: Vec<RoundHole>,
    parts: Vec<Part>,
    stitch_start_points: Vec<StitchStartPoint>,
    constraints: Vec<Constraint>,
    view_annotations: ViewAnnotations,
}

impl DocumentRollback {
    fn capture(document: &ProjectDocument) -> Self {
        Self {
            parameters: document.parameters.clone(),
            entities: document.entities.clone(),
            derived_elements: document.derived_elements.clone(),
            free_texts: document.free_texts.clone(),
            round_holes: document.round_holes.clone(),
            parts: document.parts.clone(),
            stitch_start_points: document.stitch_start_points.clone(),
            constraints: document.constraints.clone(),
            view_annotations: document.view_annotations.clone(),
        }
    }
}

/// エンティティ単位で評価した拘束状態。
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EntityConstraintStatus {
    /// 評価対象のエンティティ ID。
    pub entity_id: String,
    /// 対象エンティティの拘束状態。
    pub status: ConstraintStatus,
    /// 評価後に残っている自由度の概数。
    pub remaining_dof: usize,
}

/// 一致拘束から導かれる論理的な点グループ。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CoincidentPointGroup {
    /// 派生グループの安定表示用 ID。
    pub id: String,
    /// グループの代表位置。
    pub representative: Point2,
    /// 同じ位置として扱う拘束対象。
    pub targets: Vec<ConstraintTarget>,
}

/// ドキュメント操作で発生した一時的なユーザー向け警告。
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DocumentWarning {
    /// 警告種別。
    pub kind: DocumentWarningKind,
    /// 影響を受けた派生要素 ID。
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub derived_element_id: String,
    /// 影響を受けた計測表示 ID。
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub measurement_annotation_id: String,
    /// 影響を受けたパーツ ID。
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub part_id: String,
    /// 表示用メッセージ。
    pub message: String,
}

/// ドキュメント警告の種別。
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum DocumentWarningKind {
    /// 元図形や参照の変更により派生要素が無効になり削除された。
    DerivedElementRemoved,
    /// 元図形や参照の変更により計測表示が無効になり削除された。
    MeasurementAnnotationRemoved,
    /// 外形が維持できなくなったためパーツのまとまりが解除された。
    PartRemoved,
}

/// レイヤー削除で別レイヤーへ移される保存要素の件数。
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LayerDeletionImpact {
    /// 対象レイヤー ID。
    pub layer_id: String,
    /// 付け替え対象となる通常図形数。
    pub entity_count: usize,
    /// 付け替え対象となる派生要素数。
    pub derived_element_count: usize,
}

impl PartialEq for ProjectDocument {
    fn eq(&self, other: &Self) -> bool {
        self.store == other.store
    }
}

impl Deref for ProjectDocument {
    type Target = DocumentStore;

    fn deref(&self) -> &Self::Target {
        &self.store
    }
}

impl DerefMut for ProjectDocument {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut self.store
    }
}

impl ProjectDocument {
    /// レイヤーを削除した場合の保存要素への影響を返す。
    pub fn layer_deletion_impact(&self, layer_id: &str) -> CommandResult<LayerDeletionImpact> {
        if !self.layers.iter().any(|layer| layer.id == layer_id) {
            return Err(CommandError::missing("layer", layer_id));
        }
        Ok(LayerDeletionImpact {
            layer_id: layer_id.to_owned(),
            entity_count: self
                .entities
                .iter()
                .filter(|entity| entity.layer_id.as_deref() == Some(layer_id))
                .count(),
            derived_element_count: self
                .derived_elements
                .iter()
                .filter(|item| item.layer_id.as_deref() == Some(layer_id))
                .count(),
        })
    }
    /// 既定値を使って新規ドキュメントを作成する。
    pub fn new(name: impl Into<String>) -> Self {
        Self {
            store: DocumentStore::new(name),
            history: HistoryStore::default(),
        }
    }

    /// このドキュメントが表す `.lcraft` ファイル形式のバージョンを返す。
    pub fn file_format_version(&self) -> &str {
        &self.file_format_version
    }

    /// このドキュメントの検証に使う外部 JSON Schema のバージョンを返す。
    pub fn schema_version(&self) -> &str {
        &self.schema_version
    }

    /// 名前や単位などのドキュメントメタデータを返す。
    pub fn metadata(&self) -> &DocumentMetadata {
        &self.metadata
    }

    /// 用紙と実寸印刷の設定を返す。
    pub fn settings(&self) -> &PrintSettings {
        &self.settings
    }

    /// ドキュメントで利用可能な描画レイヤーを返す。
    pub fn layers(&self) -> &[Layer] {
        &self.layers
    }

    /// ドキュメントで利用可能な共有線スタイルを返す。
    pub fn shared_styles(&self) -> &[SharedStyle] {
        &self.shared_styles
    }

    /// 名前付きミリメートルパラメータを返す。
    pub fn parameters(&self) -> &[Parameter] {
        &self.parameters
    }

    /// プロジェクトで管理しているパーツを返す。
    pub fn parts(&self) -> &[Part] {
        &self.parts
    }

    /// 幾何エンティティを返す。
    pub fn entities(&self) -> &[Entity] {
        &self.entities
    }

    /// 元図形に追従する派生要素を返す。
    pub fn derived_elements(&self) -> &[DerivedElement] {
        &self.derived_elements
    }

    /// ユーザーが型紙上へ配置した自由テキスト注記を返す。
    pub fn free_texts(&self) -> &[FreeText] {
        &self.free_texts
    }

    /// 円エンティティへ用途を付与した丸穴を返す。
    pub fn round_holes(&self) -> &[RoundHole] {
        &self.round_holes
    }

    /// 縫い線へ紐づく縫い始め点を返す。
    pub fn stitch_start_points(&self) -> &[StitchStartPoint] {
        &self.stitch_start_points
    }

    /// 直近のコマンドで発生した警告。
    pub fn document_warnings(&self) -> &[DocumentWarning] {
        &self.document_warnings
    }

    /// パラメトリック拘束を返す。
    pub fn constraints(&self) -> &[Constraint] {
        &self.constraints
    }

    /// 作図データ本体から分離した表示補助メタデータを返す。
    pub fn view_annotations(&self) -> &ViewAnnotations {
        &self.view_annotations
    }

    /// 視覚補助用の計測表示を返す。
    pub fn measurement_annotations(&self) -> &[MeasurementAnnotation] {
        &self.view_annotations.measurement_annotations
    }

    /// 寸法拘束に紐づく表示位置メタデータを返す。
    pub fn dimension_constraint_annotations(&self) -> &[DimensionConstraintAnnotation] {
        &self.view_annotations.dimension_constraint_annotations
    }

    /// 出力用中間表現を生成する。
    pub fn build_output_document_model(
        &self,
        options: BuildOutputDocumentModelOptions,
    ) -> Result<BuildOutputDocumentModelResult, OutputBuildError> {
        OutputModelBuilder::build(self, options)
    }

    pub(in crate::document) fn entity_is_output_visible(&self, entity: &Entity) -> bool {
        self.parts
            .iter()
            .find(|part| part.entity_ids.contains(&entity.id))
            .map(|part| part.printable)
            .unwrap_or(true)
            && entity
                .layer_id
                .as_deref()
                .and_then(|layer_id| self.layers.iter().find(|layer| layer.id == layer_id))
                .map(|layer| layer.visible && layer.printable)
                .unwrap_or(true)
    }

    pub(crate) fn entity_is_part_visible(&self, entity_id: &str) -> bool {
        self.parts
            .iter()
            .find(|part| part.entity_ids.iter().any(|id| id == entity_id))
            .map(|part| part.visible)
            .unwrap_or(true)
    }

    pub(crate) fn derived_is_part_visible(&self, derived_id: &str, output: bool) -> bool {
        self.parts
            .iter()
            .find(|part| part.derived_element_ids.iter().any(|id| id == derived_id))
            .map(|part| if output { part.printable } else { part.visible })
            .unwrap_or(true)
    }

    pub(in crate::document) fn ensure_shared_style_exists(
        &self,
        source: &'static str,
        style_id: &str,
    ) -> CommandResult {
        if self.shared_styles.iter().any(|style| style.id == style_id) {
            Ok(())
        } else {
            Err(CommandError::broken_reference(
                source,
                "shared style",
                style_id,
            ))
        }
    }

    /// ID と参照を検証した上で粗い粒度のコマンドを適用する。
    pub fn apply_command(&mut self, command: DocumentCommand) -> CommandResult {
        let undo_entry = HistoryStore::capture_pending_entry(self)?;
        let mut candidate = self.clone();
        candidate.document_warnings.clear();
        let result = CommandApplier::apply_command_without_history(&mut candidate, command);
        if result.is_ok() {
            candidate.prune_unresolvable_derived_elements();
            candidate.prune_unresolvable_measurement_annotations();
            candidate.reconcile_parts();
            ensure_locked_parts_unchanged(self, &candidate)?;
            *self = candidate;
            self.history.record_applied_command(undo_entry);
            self.refresh_constraint_statuses();
        }
        result
    }

    /// コマンド適用後の候補状態を、現在状態と履歴を変更せずに返す。
    pub fn preview_command(&self, command: DocumentCommand) -> Result<Self, CommandError> {
        let mut candidate = self.clone();
        candidate.document_warnings.clear();
        CommandApplier::apply_command_without_history(&mut candidate, command)?;
        candidate.prune_unresolvable_derived_elements();
        candidate.prune_unresolvable_measurement_annotations();
        candidate.reconcile_parts();
        ensure_locked_parts_unchanged(self, &candidate)?;
        candidate.history = self.history.clone();
        candidate.refresh_constraint_statuses();
        Ok(candidate)
    }

    /// ID でエンティティを検索する。
    pub fn entity(&self, entity_id: &str) -> Option<&Entity> {
        self.entities.iter().find(|entity| entity.id == entity_id)
    }

    /// ID で派生要素を検索する。
    pub fn derived_element(&self, derived_element_id: &str) -> Option<&DerivedElement> {
        self.derived_elements
            .iter()
            .find(|derived_element| derived_element.id == derived_element_id)
    }

    /// ID でパラメータを検索する。
    pub fn parameter(&self, parameter_id: &str) -> Option<&Parameter> {
        self.parameters
            .iter()
            .find(|parameter| parameter.id == parameter_id)
    }

    /// 直前のユーザー操作を取り消す。
    pub fn undo(&mut self) -> CommandResult {
        let mut history = std::mem::take(&mut self.history);
        let mut restored = match history.undo_document(self) {
            Ok(document) => document,
            Err(error) => {
                self.history = history;
                return Err(error);
            }
        };
        restored.history = history;
        restored.document_warnings.clear();
        *self = restored;
        Ok(())
    }

    /// 取り消し可能な履歴を持つかどうかを返す。
    pub fn can_undo(&self) -> bool {
        self.history.can_undo()
    }

    /// 直前に取り消したユーザー操作をやり直す。
    pub fn redo(&mut self) -> CommandResult {
        let mut history = std::mem::take(&mut self.history);
        let mut restored = match history.redo_document(self) {
            Ok(document) => document,
            Err(error) => {
                self.history = history;
                return Err(error);
            }
        };
        restored.history = history;
        restored.document_warnings.clear();
        *self = restored;
        Ok(())
    }

    /// やり直し可能な履歴を持つかどうかを返す。
    pub fn can_redo(&self) -> bool {
        self.history.can_redo()
    }

    /// 指定されたキャンバス表示モード向けの描画スナップショットを作成する。
    pub fn drawing_snapshot(&self, view_mode: CanvasViewMode) -> DrawingSnapshot {
        DrawingSnapshot::from_document(self, view_mode)
    }

    /// 指定表示モードの描画エンティティと意味要素との対応を返す。
    pub fn drawing_entity_metadata(&self, view_mode: CanvasViewMode) -> Vec<DrawingEntityMetadata> {
        derived_element_drawing_metadata(self, view_mode)
    }

    /// 現在の幾何状態から各拘束の評価済みステータスを返す。
    pub(crate) fn evaluated_constraint_statuses(&self) -> Vec<ConstraintStatus> {
        ConstraintSolver::evaluated_constraint_statuses(self)
    }

    /// 現在の幾何状態からエンティティ単位の拘束状態を返す。
    pub fn entity_constraint_statuses(&self) -> Vec<EntityConstraintStatus> {
        evaluate_entity_constraint_statuses(self)
    }

    fn refresh_constraint_statuses(&mut self) {
        ConstraintSolver::refresh_constraint_statuses(self);
    }

    fn ensure_constraints_not_conflicting(
        &self,
        entities: Vec<Entity>,
        constraints: Vec<Constraint>,
    ) -> CommandResult {
        ConstraintSolver::ensure_constraints_not_conflicting(self, entities, constraints)
    }

    fn resolve_current_constraints_or_restore(
        &mut self,
        rollback: DocumentRollback,
    ) -> CommandResult {
        ConstraintSolver::resolve_current_constraints_or_restore(self, rollback)
    }

    /// ドキュメントを整形済み JSON 文字列へ変換する。
    pub fn to_json_pretty_string(&self) -> Result<String, DocumentIoError> {
        DocumentIo::to_json_pretty_string(self)
    }

    /// JSON 文字列からドキュメントを読み込む。
    pub fn from_json_str(json: &str) -> Result<Self, DocumentIoError> {
        DocumentIo::from_json_str(json)
    }

    /// ドキュメントを `.lcraft` JSON ファイルへ保存する。
    pub fn write_json_file(&self, path: impl AsRef<Path>) -> Result<(), DocumentIoError> {
        DocumentIo::write_json_file(self, path)
    }

    /// `.lcraft` JSON ファイルからドキュメントを読み込む。
    pub fn read_json_file(path: impl AsRef<Path>) -> Result<Self, DocumentIoError> {
        DocumentIo::read_json_file(path)
    }

    fn ensure_entity_exists(&self, source: &'static str, entity_id: &str) -> CommandResult {
        if self.entity(entity_id).is_some() {
            Ok(())
        } else {
            Err(CommandError::broken_reference(source, "entity", entity_id))
        }
    }

    fn ensure_layer_exists(&self, source: &'static str, layer_id: &str) -> CommandResult {
        if self.layers.iter().any(|layer| layer.id == layer_id) {
            Ok(())
        } else {
            Err(CommandError::broken_reference(source, "layer", layer_id))
        }
    }

    fn ensure_parameter_exists(&self, source: &'static str, parameter_id: &str) -> CommandResult {
        if self.parameter(parameter_id).is_some() {
            Ok(())
        } else {
            Err(CommandError::broken_reference(
                source,
                "parameter",
                parameter_id,
            ))
        }
    }
}

fn ensure_locked_parts_unchanged(
    before: &ProjectDocument,
    after: &ProjectDocument,
) -> CommandResult {
    for original in &before.parts {
        let Some(updated) = after.parts.iter().find(|part| part.id == original.id) else {
            if fixed_part_contents_match(before, after, original, Point2::new(0.0, 0.0)) {
                // Explicitly dissolving a part leaves all of its contents in
                // place and removes only the part relationship.
                continue;
            }
            return Err(locked_part_error());
        };
        if original.outline_entity_ids != updated.outline_entity_ids
            || original.hole_entity_id_groups != updated.hole_entity_id_groups
            || original.entity_ids != updated.entity_ids
            || original.derived_element_ids != updated.derived_element_ids
            || original.free_text_ids != updated.free_text_ids
            || original.measurement_annotation_ids != updated.measurement_annotation_ids
        {
            return Err(locked_part_error());
        }

        let delta = Point2::new(
            updated.origin_mm.x_mm - original.origin_mm.x_mm,
            updated.origin_mm.y_mm - original.origin_mm.y_mm,
        );
        if !fixed_part_contents_match(before, after, original, delta) {
            return Err(locked_part_error());
        }
    }
    Ok(())
}

fn fixed_part_contents_match(
    before: &ProjectDocument,
    after: &ProjectDocument,
    original: &Part,
    delta: Point2,
) -> bool {
    let expected_entities = before
        .entities
        .iter()
        .filter(|item| original.entity_ids.contains(&item.id))
        .map(|item| translated_entity(item, delta))
        .collect::<Vec<_>>();
    let actual_entities = after
        .entities
        .iter()
        .filter(|item| original.entity_ids.contains(&item.id))
        .cloned()
        .collect::<Vec<_>>();
    if expected_entities != actual_entities {
        return false;
    }

    let expected_free_texts = before
        .free_texts
        .iter()
        .filter(|item| original.free_text_ids.contains(&item.id))
        .cloned()
        .map(|mut item| {
            item.position_mm.x_mm += delta.x_mm;
            item.position_mm.y_mm += delta.y_mm;
            item
        })
        .collect::<Vec<_>>();
    let actual_free_texts = after
        .free_texts
        .iter()
        .filter(|item| original.free_text_ids.contains(&item.id))
        .cloned()
        .collect::<Vec<_>>();
    if expected_free_texts != actual_free_texts {
        return false;
    }

    {
        let owns = |id: &String| {
            original.entity_ids.contains(id) || original.derived_element_ids.contains(id)
        };
        if before
            .derived_elements
            .iter()
            .filter(|item| original.derived_element_ids.contains(&item.id))
            .ne(after
                .derived_elements
                .iter()
                .filter(|item| original.derived_element_ids.contains(&item.id)))
            || before
                .measurement_annotations()
                .iter()
                .filter(|item| original.measurement_annotation_ids.contains(&item.id))
                .ne(after
                    .measurement_annotations()
                    .iter()
                    .filter(|item| original.measurement_annotation_ids.contains(&item.id)))
            || before
                .round_holes
                .iter()
                .filter(|item| original.entity_ids.contains(&item.entity_id))
                .ne(after
                    .round_holes
                    .iter()
                    .filter(|item| original.entity_ids.contains(&item.entity_id)))
            || before
                .stitch_start_points
                .iter()
                .filter(|item| owns(&item.target_id))
                .ne(after
                    .stitch_start_points
                    .iter()
                    .filter(|item| owns(&item.target_id)))
        {
            return false;
        }

        let touches_part = |constraint: &&Constraint| {
            constraint.targets.iter().any(|target| match target {
                ConstraintTarget::Entity(id)
                | ConstraintTarget::ControlPoint { entity_id: id, .. } => owns(id),
            })
        };
        let before_constraints = before
            .constraints
            .iter()
            .filter(touches_part)
            .collect::<Vec<_>>();
        let after_constraints = after
            .constraints
            .iter()
            .filter(touches_part)
            .collect::<Vec<_>>();
        if before_constraints != after_constraints {
            return false;
        }

        let mut parameter_ids = BTreeSet::new();
        for constraint in &before_constraints {
            if let Some(ConstraintValue::Parameter(id)) = &constraint.value {
                parameter_ids.insert(id.clone());
            }
        }
        for derived in before
            .derived_elements
            .iter()
            .filter(|item| original.derived_element_ids.contains(&item.id))
        {
            match &derived.kind {
                DerivedElementKind::OffsetCurve(offset) => {
                    if let ConstraintValue::Parameter(id) = &offset.distance {
                        parameter_ids.insert(id.clone());
                    }
                }
                DerivedElementKind::Fillet(fillet) => {
                    if let ConstraintValue::Parameter(id) = &fillet.radius {
                        parameter_ids.insert(id.clone());
                    }
                }
            }
        }
        if before
            .parameters
            .iter()
            .filter(|item| parameter_ids.contains(&item.id))
            .ne(after
                .parameters
                .iter()
                .filter(|item| parameter_ids.contains(&item.id)))
        {
            return false;
        }
    }
    true
}

fn locked_part_error() -> CommandError {
    CommandError::InvalidValue {
        field: "part fixed",
        reason: "part shape and membership cannot be changed; ungroup the part before editing",
    }
}

fn ensure_non_empty_id(kind: &'static str, id: &str) -> CommandResult {
    if id.trim().is_empty() {
        Err(CommandError::EmptyId(kind))
    } else {
        Ok(())
    }
}

fn ensure_unique_id<'a>(
    mut existing_ids: impl Iterator<Item = &'a str>,
    kind: &'static str,
    id: &str,
) -> CommandResult {
    ensure_non_empty_id(kind, id)?;
    if existing_ids.any(|existing_id| existing_id == id) {
        Err(CommandError::duplicate(kind, id))
    } else {
        Ok(())
    }
}

fn delete_by_id<T>(
    items: &mut Vec<T>,
    kind: &'static str,
    id: &str,
    id_of: impl Fn(&T) -> &String,
) -> CommandResult {
    let index = items
        .iter()
        .position(|item| id_of(item) == id)
        .ok_or_else(|| CommandError::missing(kind, id))?;
    items.remove(index);
    Ok(())
}
