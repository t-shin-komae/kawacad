//! 元図形に追従する派生要素。

use crate::constraints::ConstraintValue;
use crate::geometry::{EntityId, LayerId, GEOMETRY_EPSILON_MM};
use crate::shared_styles::SharedStyleId;

/// 派生要素の安定 ID。
pub type DerivedElementId = String;

/// ドキュメントに保存する派生要素。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DerivedElement {
    /// 派生要素の安定 ID。
    pub id: DerivedElementId,
    /// この派生要素を所有するレイヤーの任意 ID。
    pub layer_id: Option<LayerId>,
    /// 任意で参照するプロジェクト共有スタイル ID。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub style_id: Option<SharedStyleId>,
    /// 派生要素の内容。
    pub kind: DerivedElementKind,
}

impl DerivedElement {
    /// オフセット線の派生要素を作成する。
    pub fn offset_curve(
        id: impl Into<DerivedElementId>,
        layer_id: Option<LayerId>,
        offset: OffsetCurve,
    ) -> Self {
        Self {
            id: id.into(),
            layer_id,
            style_id: None,
            kind: DerivedElementKind::OffsetCurve(offset),
        }
    }

    /// フィレットの派生要素を作成する。
    pub fn fillet(
        id: impl Into<DerivedElementId>,
        layer_id: Option<LayerId>,
        fillet: Fillet,
    ) -> Self {
        Self {
            id: id.into(),
            layer_id,
            style_id: None,
            kind: DerivedElementKind::Fillet(fillet),
        }
    }

    /// 共有スタイルを設定した派生要素を返す。
    pub fn with_style(mut self, style_id: impl Into<SharedStyleId>) -> Self {
        self.style_id = Some(style_id.into());
        self
    }
}

/// 派生要素の種類。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum DerivedElementKind {
    /// 元図形から一定距離のオフセット線を生成する。
    OffsetCurve(OffsetCurve),
    /// 接続する元図形の角を指定半径の円弧で丸める。
    Fillet(Fillet),
}

/// オフセット線の保存情報。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct OffsetCurve {
    /// 参照元図形 ID。連続要素では順序を保持する。
    pub source_entity_ids: Vec<EntityId>,
    /// 派生要素の解決済み形状から一部だけを使う場合の解決済み図形 ID。
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub source_resolved_entity_ids: Vec<EntityId>,
    /// オフセット距離。固定値または名前付きパラメータ参照。
    pub distance: ConstraintValue,
    /// オフセット方向。
    pub direction: OffsetDirection,
}

/// フィレットの保存情報。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Fillet {
    /// 角または連続パスを構成する参照元図形 ID。2 要素以上を使う。
    pub source_entity_ids: Vec<EntityId>,
    /// フィレット半径。固定値または名前付きパラメータ参照。
    pub radius: ConstraintValue,
    /// 幾何的に閉じた参照元列を閉じた輪郭として扱うか。
    #[serde(default = "default_fillet_closed", skip_serializing_if = "is_true")]
    pub closed: bool,
}

/// オフセット方向。
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum OffsetDirection {
    /// 開いた線または連続線の左側。
    Left,
    /// 開いた線または連続線の右側。
    Right,
    /// 閉じた輪郭の内側。
    Inward,
    /// 閉じた輪郭の外側。
    Outward,
}

fn default_fillet_closed() -> bool {
    true
}

fn is_true(value: &bool) -> bool {
    *value
}

impl OffsetCurve {
    /// 参照先 ID と距離値を検証する。
    pub fn validate_shape(&self) -> Result<(), DerivedElementValidationError> {
        if self.source_entity_ids.is_empty() {
            return Err(DerivedElementValidationError::EmptySourceList);
        }
        if self
            .source_entity_ids
            .iter()
            .chain(self.source_resolved_entity_ids.iter())
            .any(|entity_id| entity_id.trim().is_empty())
        {
            return Err(DerivedElementValidationError::EmptySourceId);
        }
        if !self.source_resolved_entity_ids.is_empty() && self.source_entity_ids.len() != 1 {
            return Err(DerivedElementValidationError::InvalidResolvedSourceSelection);
        }
        match &self.distance {
            ConstraintValue::FixedMm(value_mm) if value_mm.is_finite() && *value_mm > 0.0 => Ok(()),
            ConstraintValue::Parameter(parameter_id) if !parameter_id.trim().is_empty() => Ok(()),
            ConstraintValue::FixedMm(_) => Err(DerivedElementValidationError::InvalidDistance),
            ConstraintValue::FixedDegrees(_) => Err(DerivedElementValidationError::InvalidDistance),
            ConstraintValue::Parameter(_) => Err(DerivedElementValidationError::EmptyParameterId),
        }
    }
}

impl Fillet {
    /// 参照先 ID と半径値を検証する。
    pub fn validate_shape(&self) -> Result<(), DerivedElementValidationError> {
        if self.source_entity_ids.len() < 2 {
            return Err(DerivedElementValidationError::InvalidSourceCount);
        }
        if self
            .source_entity_ids
            .iter()
            .any(|entity_id| entity_id.trim().is_empty())
        {
            return Err(DerivedElementValidationError::EmptySourceId);
        }
        match &self.radius {
            ConstraintValue::FixedMm(value_mm) if value_mm.is_finite() && *value_mm > 0.0 => Ok(()),
            ConstraintValue::Parameter(parameter_id) if !parameter_id.trim().is_empty() => Ok(()),
            ConstraintValue::FixedMm(_) => Err(DerivedElementValidationError::InvalidRadius),
            ConstraintValue::FixedDegrees(_) => Err(DerivedElementValidationError::InvalidRadius),
            ConstraintValue::Parameter(_) => Err(DerivedElementValidationError::EmptyParameterId),
        }
    }
}

/// 派生要素の検証エラー。
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DerivedElementValidationError {
    /// 派生要素 ID が空。
    EmptyDerivedElementId,
    /// 参照元が空。
    EmptySourceList,
    /// 参照元 ID が空。
    EmptySourceId,
    /// 参照元数が派生要素の要件を満たさない。
    InvalidSourceCount,
    /// 解決済み形状の部分選択に対応する派生要素が一意でない。
    InvalidResolvedSourceSelection,
    /// パラメータ ID が空。
    EmptyParameterId,
    /// 距離指定が正の有限ミリメートル値またはパラメータ参照ではない。
    InvalidDistance,
    /// 半径指定が正の有限ミリメートル値またはパラメータ参照ではない。
    InvalidRadius,
}

/// 派生要素 ID から生成エンティティ ID を作る。
pub(crate) fn resolved_entity_id(derived_id: &str, index: usize) -> String {
    format!("{derived_id}:resolved:{index}")
}

pub(crate) fn distance_is_effectively_zero(distance_mm: f64) -> bool {
    distance_mm <= GEOMETRY_EPSILON_MM
}
