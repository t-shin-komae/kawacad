//! 革を切り出す単位として図形と付随要素をまとめるパーツモデル。

use crate::geometry::{EntityId, Point2};

/// プロジェクト内で安定して参照するパーツ ID。
pub type PartId = String;

fn default_true() -> bool {
    true
}

fn default_quantity() -> u32 {
    1
}

/// 複数パーツを外形境界のどこへ揃えるか。
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum PartAlignment {
    /// 左端を揃える。
    Left,
    /// 水平方向の中心を揃える。
    HorizontalCenter,
    /// 右端を揃える。
    Right,
    /// 下端を揃える。
    Bottom,
    /// 垂直方向の中心を揃える。
    VerticalCenter,
    /// 上端を揃える。
    Top,
}

/// 複数パーツの外形間隔を均等化する軸。
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum PartDistributionAxis {
    /// 左右方向の外形間隔を均等化する。
    Horizontal,
    /// 上下方向の外形間隔を均等化する。
    Vertical,
}

/// 1つの閉じた外形と、その内側の穴・付随要素をまとめるパーツ。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Part {
    /// プロジェクト内で一意な ID。
    pub id: PartId,
    /// 利用者が識別するパーツ名。
    pub name: String,
    /// パーツ内座標の基準となる作図座標上の原点。
    pub origin_mm: Point2,
    /// 外側ループを構成する順序付き通常図形 ID。
    pub outline_entity_ids: Vec<EntityId>,
    /// 内側ループごとの順序付き通常図形 ID。
    #[serde(default)]
    pub hole_entity_id_groups: Vec<Vec<EntityId>>,
    /// 外形、穴、付随図形を含む所属通常図形 ID。
    pub entity_ids: Vec<EntityId>,
    /// 所属する派生要素 ID。
    #[serde(default)]
    pub derived_element_ids: Vec<String>,
    /// 所属する自由テキスト ID。
    #[serde(default)]
    pub free_text_ids: Vec<String>,
    /// 所属する計測表示 ID。
    #[serde(default)]
    pub measurement_annotation_ids: Vec<String>,
    /// 編集キャンバスへ所属要素を表示するか。
    #[serde(default = "default_true")]
    pub visible: bool,
    /// PDF と直接印刷へ所属要素を含めるか。
    #[serde(default = "default_true")]
    pub printable: bool,
    /// 互換性のため保存する固定状態。パーツは常に固定される。
    #[serde(default = "default_true")]
    pub locked: bool,
    /// この形状を製作する必要数。
    #[serde(default = "default_quantity")]
    pub quantity: u32,
}

impl Part {
    /// 構成を保ったまま名称と配置基準点を置き換えた値を返す。
    pub fn with_metadata(&self, name: impl Into<String>, origin_mm: Point2) -> Self {
        let mut updated = self.clone();
        updated.name = name.into();
        updated.origin_mm = origin_mm;
        updated
    }
}
