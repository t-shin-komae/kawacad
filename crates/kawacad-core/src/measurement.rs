//! Human-facing canvas annotation metadata.

use crate::constraints::ConstraintId;
use crate::constraints::ConstraintTarget;
use crate::constraints::ConstraintValue;
use crate::geometry::Point2;

/// Stable ID for a non-driving measurement annotation.
pub type MeasurementAnnotationId = String;

/// Stable ID for dimension-constraint display metadata.
pub type DimensionConstraintAnnotationId = ConstraintId;

/// View-oriented annotations stored separately from drawing semantics.
#[derive(Debug, Clone, Default, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ViewAnnotations {
    /// Non-driving dimensions and angle indicators used for visual inspection.
    #[serde(default)]
    pub measurement_annotations: Vec<MeasurementAnnotation>,
    /// Display offsets for driving dimension constraints.
    #[serde(default)]
    pub dimension_constraint_annotations: Vec<DimensionConstraintAnnotation>,
}

/// A visual measurement annotation that never drives geometry.
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MeasurementAnnotation {
    /// Stable annotation ID.
    pub id: MeasurementAnnotationId,
    /// Measurement type.
    pub kind: MeasurementAnnotationKind,
    /// Referenced entities or control points used to compute the value.
    pub targets: Vec<ConstraintTarget>,
    /// User-controlled displacement for the label only, in drawing coordinates.
    pub label_offset_mm: Point2,
    /// User-controlled displacement for the whole annotation, in drawing coordinates.
    pub overall_offset_mm: Point2,
    /// Whether the annotation should be shown on the canvas.
    pub visible: bool,
}

/// Visual metadata for a driving dimension constraint.
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DimensionConstraintAnnotation {
    /// Constraint ID this annotation belongs to.
    pub constraint_id: DimensionConstraintAnnotationId,
    /// User-controlled displacement for the label only, in drawing coordinates.
    pub label_offset_mm: Point2,
    /// User-controlled displacement for the whole displayed dimension, in drawing coordinates.
    pub overall_offset_mm: Point2,
    /// Whether the annotation should be shown on the canvas.
    pub visible: bool,
}

/// Supported non-driving measurement types.
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum MeasurementAnnotationKind {
    /// Distance between two point targets.
    Distance,
    /// Length of a line target.
    SegmentLength,
    /// Signed angle between two line targets that share one endpoint.
    Angle,
    /// Radius of a circle or arc target.
    Radius,
    /// Diameter of a circle or arc target.
    Diameter,
    /// Sweep angle of an arc target.
    ArcSweepAngle,
}

/// 現在形状から Core が評価した非永続の計測結果。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MeasurementEvaluation {
    /// 評価元の計測表示 ID。
    pub annotation_id: MeasurementAnnotationId,
    /// 計測種別。
    pub kind: MeasurementAnnotationKind,
    /// Core が計算した正規値。
    pub value: ConstraintValue,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    /// 角度または半径表示の意味上の中心。
    pub center: Option<Point2>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    /// 寸法線または角度表示の開始基準点。
    pub start: Option<Point2>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    /// 寸法線または角度表示の終了基準点。
    pub end: Option<Point2>,
}
