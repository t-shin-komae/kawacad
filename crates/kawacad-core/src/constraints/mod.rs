//! パラメトリックスケッチの拘束データモデル。

use crate::geometry::EntityId;

/// 拘束の安定 ID。
pub type ConstraintId = String;
/// 拘束から参照される名前付きパラメータの安定 ID。
pub type ParameterId = String;

/// ドキュメントエンティティへ適用する幾何または寸法ルール。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Constraint {
    /// 拘束の安定 ID。
    pub id: ConstraintId,
    /// この拘束が表す関係の種類。
    pub kind: ConstraintKind,
    /// このルールで拘束されるエンティティまたは制御点。
    pub targets: Vec<ConstraintTarget>,
    /// 寸法拘束で使う固定値またはパラメータ由来の任意値。
    pub value: Option<ConstraintValue>,
    /// この拘束に対する現在のソルバ分類。
    pub status: ConstraintStatus,
}

/// 拘束の対象になる選択可能なドキュメント要素。
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ConstraintTarget {
    /// エンティティ全体を対象にする。
    Entity(EntityId),
    /// エンティティ上の特定の制御点を対象にする。
    ControlPoint {
        /// 制御点を所有するエンティティの ID。
        entity_id: EntityId,
        /// 拘束する制御点の種類。
        point: ControlPointKind,
    },
}

/// 現行の幾何エンティティが公開する選択可能な制御点。
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ControlPointKind {
    /// 線分系エンティティの始点。
    Start,
    /// 線分系エンティティの終点。
    End,
    /// 円、円弧、中心基準エンティティの中心点。
    Center,
}

/// 現行で対応する拘束種別。
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ConstraintKind {
    /// 2つの点または互換性のある対象を一致させる。
    Coincident,
    /// 線分または点ペアを水平に保つ。
    Horizontal,
    /// 線分または点ペアを垂直に保つ。
    Vertical,
    /// 2つの線分系対象を平行に保つ。
    Parallel,
    /// 2つの線分系対象を直交させる。
    Perpendicular,
    /// 線分系対象と円弧を接線連続に保つ。
    Tangent,
    /// 点対象を中心線に対して対称に保つ。
    Symmetric,
    /// 2つの点対象間の距離を拘束する。
    Distance,
    /// 2つの点対象間の水平距離を拘束する。
    HorizontalDistance,
    /// 2つの点対象間の垂直距離を拘束する。
    VerticalDistance,
    /// 点対象と線分対象の垂直距離を拘束する。
    PointLineDistance,
    /// 2つの線分系対象の支持直線間距離を拘束する。
    LineLineDistance,
    /// 点対象を線分系対象の支持直線上に保つ。
    PointOnLine,
    /// 線分長を拘束する。
    SegmentLength,
    /// 互換性のある対象間の角度を拘束する。
    Angle,
    /// 対象を固定する。
    Fixed,
    /// 円の直径を拘束する。
    Diameter,
    /// 円または円弧の半径を拘束する。
    Radius,
    /// 2つの線分長を一致させる。
    EqualSegmentLength,
}

/// 寸法拘束で使う数値の取得元。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ConstraintValue {
    /// 固定長。単位はミリメートル。
    FixedMm(f64),
    /// 固定角。単位は度数法。
    FixedDegrees(f64),
    /// 名前付きパラメータから読み取る値。
    Parameter(ParameterId),
}

/// 拘束のソルバ状態および検証状態。
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ConstraintStatus {
    /// ソルバがまだ拘束を分類していない。
    Unknown,
    /// スケッチに自由度が残っている。
    UnderConstrained,
    /// スケッチが完全拘束されている。
    FullyConstrained,
    /// スケッチに冗長な拘束が含まれている。
    OverConstrained,
    /// 1つ以上の拘束を同時に満たせない。
    Conflicting,
}
