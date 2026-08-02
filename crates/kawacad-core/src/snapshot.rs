//! コアからフロントエンド描画処理へ返す描画スナップショット。

use crate::constraints::ConstraintStatus;
use crate::document::ProjectDocument;
use crate::geometry::{Entity, Point2};

/// 描画可能なドキュメントエンティティと集約済み拘束状態。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DrawingSnapshot {
    /// このスナップショットの生成に使ったキャンバス表示モード。
    pub view_mode: CanvasViewMode,
    /// 描画対象の表示エンティティ。
    pub entities: Vec<Entity>,
    /// UI 表示用に集約した拘束状態。
    pub constraint_status: ConstraintStatus,
}

/// Canvas 上の意味要素について Core が解決した非永続の描画投影。
#[derive(Debug, Clone, Default, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CanvasProjection {
    /// 表示対象の自由テキスト ID。
    pub visible_free_text_ids: Vec<String>,
    /// 解決済み縫い始め点。
    pub stitch_start_points: Vec<ResolvedCanvasPoint>,
    /// 計測表示の解決済み基準図形。
    pub measurement_annotations: Vec<ResolvedCanvasGeometry>,
    /// 寸法拘束表示の解決済み基準図形。
    pub dimension_constraints: Vec<ResolvedCanvasGeometry>,
    /// 拘束マーカーの意味上のアンカー。
    pub constraint_markers: Vec<ResolvedCanvasPoint>,
}

/// ID、mm 座標、表示可否を持つ解決済み点。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ResolvedCanvasPoint {
    /// 意味要素 ID。
    pub id: String,
    /// 解決済み mm 座標。
    pub position_mm: Point2,
    /// 現在の表示モードで描画するか。
    pub visible: bool,
}

/// 寸法線または角度弧を描くための意味上の基準点。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ResolvedCanvasGeometry {
    /// 注記または拘束 ID。
    pub id: String,
    /// 現在の表示モードで描画するか。
    pub visible: bool,
    /// 直線対ではなく円弧に由来する角度投影か。
    #[serde(default, skip_serializing_if = "is_false")]
    pub arc: bool,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    /// 角度弧または半径の中心。
    pub center_mm: Option<Point2>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    /// 第一基準点。
    pub start_mm: Option<Point2>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    /// 第二基準点。
    pub end_mm: Option<Point2>,
}

/// 描画エンティティと保存上の意味要素との対応。
#[derive(Debug, Clone, Default, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DrawingEntityMetadata {
    /// 対象となる描画エンティティ ID。
    #[serde(skip)]
    pub entity_id: String,
    /// 解決元の派生要素 ID。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub derived_element_id: Option<String>,
    /// 派生要素内の解決 index。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub resolved_index: Option<usize>,
    /// この解決形状に対応する意味上の元図形 ID。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub source_entity_id: Option<String>,
    /// 編集表示でフィレット解決形状に置換される元図形か。
    #[serde(default, skip_serializing_if = "is_false")]
    pub suppressed_by_fillet: bool,
}

fn is_false(value: &bool) -> bool {
    !*value
}

impl DrawingSnapshot {
    /// 非表示レイヤーを除外して、ドキュメントからスナップショットを作成する。
    pub(crate) fn from_document(document: &ProjectDocument, view_mode: CanvasViewMode) -> Self {
        let entities = match view_mode {
            CanvasViewMode::EditDisplay => document
                .resolved_entities()
                .into_iter()
                .filter(|entity| entity_is_visible(document, entity))
                .collect(),
            CanvasViewMode::OutputPreview => document.output_entities(),
        };
        Self {
            view_mode,
            entities,
            constraint_status: summarize_constraint_status(document),
        }
    }
}

/// ユーザーが選択できるキャンバス表示モード。
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum CanvasViewMode {
    /// 編集可能な操作履歴と元形状を表示する。
    EditDisplay,
    /// PDF/印刷に近い出力プレビュー表示にする。
    OutputPreview,
}

fn entity_is_visible(document: &ProjectDocument, entity: &Entity) -> bool {
    document.entity_is_part_visible(&entity.id)
        && match &entity.layer_id {
            Some(layer_id) => document
                .layers
                .iter()
                .find(|layer| &layer.id == layer_id)
                .map(|layer| layer.visible)
                .unwrap_or(false),
            None => true,
        }
}

fn summarize_constraint_status(document: &ProjectDocument) -> ConstraintStatus {
    let statuses = document.evaluated_constraint_statuses();
    if statuses.is_empty() {
        return ConstraintStatus::Unknown;
    }
    if statuses.contains(&ConstraintStatus::Conflicting) {
        return ConstraintStatus::Conflicting;
    }
    if statuses.contains(&ConstraintStatus::OverConstrained) {
        return ConstraintStatus::OverConstrained;
    }
    if statuses
        .iter()
        .all(|status| *status == ConstraintStatus::FullyConstrained)
    {
        return ConstraintStatus::FullyConstrained;
    }
    if statuses.contains(&ConstraintStatus::UnderConstrained) {
        return ConstraintStatus::UnderConstrained;
    }
    ConstraintStatus::Unknown
}
