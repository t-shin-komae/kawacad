//! レザークラフト用の縫い始め点メタデータ。

/// 縫い始め点 ID。
pub type StitchStartPointId = String;

/// 縫い線上の縫い始め位置。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StitchStartPoint {
    /// 縫い始め点 ID。
    pub id: StitchStartPointId,
    /// 対象の通常図形 ID または派生要素 ID。
    pub target_id: String,
    /// 派生要素が複数の解決済み図形を持つ場合の対象 index。
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub resolved_index: Option<usize>,
    /// 対象線分または円弧上の位置。0.0 が開始側、1.0 が終了側。
    pub position_ratio: f64,
}

impl StitchStartPoint {
    /// 縫い始め点を作成する。
    pub fn new(
        id: impl Into<StitchStartPointId>,
        target_id: impl Into<String>,
        resolved_index: Option<usize>,
        position_ratio: f64,
    ) -> Self {
        Self {
            id: id.into(),
            target_id: target_id.into(),
            resolved_index,
            position_ratio,
        }
    }
}
