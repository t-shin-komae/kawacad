//! 名前付き寸法パラメータ。

/// 名前付きパラメータの安定 ID。
pub type ParameterId = String;

/// ユーザーが編集できる名前付きミリメートル値。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Parameter {
    /// パラメータの安定 ID。
    pub id: ParameterId,
    /// ユーザー向けのパラメータ名。
    pub name: String,
    /// パラメータ値。単位はミリメートル。
    pub value_mm: f64,
    /// このパラメータの単位。
    pub unit: ParameterUnit,
    /// ユーザー用の任意メモ。
    pub memo: String,
}

/// 対応するパラメータ単位。
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ParameterUnit {
    /// ミリメートル。
    Millimeter,
}
