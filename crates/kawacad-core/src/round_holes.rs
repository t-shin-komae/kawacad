//! レザークラフト用の丸穴メタデータ。

use crate::geometry::EntityId;

/// 丸穴メタデータ ID。
pub type RoundHoleId = String;

/// レザークラフト上の丸穴用途。
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum RoundHoleKind {
    /// キーリング穴。
    KeyRing,
    /// カシメ穴。
    Rivet,
    /// ジャンパーホック穴。
    SnapFastener,
    /// 装飾穴。
    Decorative,
}

/// 円エンティティに用途を付与した丸穴。
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RoundHole {
    /// 丸穴メタデータ ID。
    pub id: RoundHoleId,
    /// 穴形状を表す円エンティティ ID。
    pub entity_id: EntityId,
    /// 丸穴用途。
    pub kind: RoundHoleKind,
}

impl RoundHole {
    /// 丸穴メタデータを作成する。
    pub fn new(
        id: impl Into<RoundHoleId>,
        entity_id: impl Into<EntityId>,
        kind: RoundHoleKind,
    ) -> Self {
        Self {
            id: id.into(),
            entity_id: entity_id.into(),
            kind,
        }
    }
}
