//! ユーザーが型紙上へ配置する自由テキスト注記。

use crate::geometry::Point2;

/// 自由テキスト注記の安定 ID。
pub type FreeTextId = String;

/// 型紙上へ配置する自由テキスト注記。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FreeText {
    /// 自由テキスト注記の安定 ID。
    pub id: FreeTextId,
    /// 表示文字列。
    pub content: String,
    /// モデル空間上の基準位置。
    pub position_mm: Point2,
    /// 文字サイズ。単位はミリメートル。
    pub font_size_mm: f64,
}

impl FreeText {
    /// 自由テキスト注記を作成する。
    pub fn new(
        id: impl Into<FreeTextId>,
        content: impl Into<String>,
        position_mm: Point2,
        font_size_mm: f64,
    ) -> Self {
        Self {
            id: id.into(),
            content: content.into(),
            position_mm,
            font_size_mm,
        }
    }

    /// ID、内容、位置、文字サイズを検証する。
    pub fn validate(&self) -> Result<(), FreeTextValidationError> {
        if self.id.trim().is_empty() {
            return Err(FreeTextValidationError::EmptyId);
        }
        if self.content.trim().is_empty() {
            return Err(FreeTextValidationError::EmptyContent);
        }
        if !self.position_mm.x_mm.is_finite() || !self.position_mm.y_mm.is_finite() {
            return Err(FreeTextValidationError::NonFinitePosition);
        }
        if !self.font_size_mm.is_finite() || self.font_size_mm <= 0.0 {
            return Err(FreeTextValidationError::InvalidFontSize);
        }
        Ok(())
    }
}

/// 自由テキスト注記の検証エラー。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FreeTextValidationError {
    /// ID が空。
    EmptyId,
    /// 表示文字列が空。
    EmptyContent,
    /// 位置が有限値ではない。
    NonFinitePosition,
    /// 文字サイズが正の有限値ではない。
    InvalidFontSize,
}

impl std::fmt::Display for FreeTextValidationError {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::EmptyId => write!(formatter, "free text id must not be empty"),
            Self::EmptyContent => write!(formatter, "free text content must not be empty"),
            Self::NonFinitePosition => write!(formatter, "free text position must be finite"),
            Self::InvalidFontSize => {
                write!(
                    formatter,
                    "free text font size must be a positive finite value"
                )
            }
        }
    }
}

impl std::error::Error for FreeTextValidationError {}
