//! 用紙、印刷可能領域、実寸印刷の設定。

/// プロジェクトドキュメントに保存する印刷設定。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PrintSettings {
    /// 用紙サイズ。
    pub paper_size: PaperSize,
    /// 用紙の向き。
    pub orientation: PrintOrientation,
    /// 要求する印刷スケール。
    pub scale: PrintScale,
    /// 用紙内でプリンタまたはエクスポートが安全に使える領域。
    pub printable_area: PrintableArea,
    /// 実寸確認ガイドの設定。
    pub scale_guide: ScaleGuide,
}

impl PrintSettings {
    /// A4縦向き、実寸出力の既定印刷設定を返す。
    pub(crate) fn a4_portrait() -> Self {
        Self {
            paper_size: PaperSize::A4,
            orientation: PrintOrientation::Portrait,
            scale: PrintScale::ActualSize,
            printable_area: PrintableArea {
                left_mm: 5.0,
                right_mm: 5.0,
                top_mm: 5.0,
                bottom_mm: 5.0,
            },
            scale_guide: ScaleGuide {
                enabled: true,
                length_mm: 50.0,
            },
        }
    }
}

/// 対応する用紙サイズ。
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum PaperSize {
    /// ISO A4 用紙。
    A4,
}

impl PaperSize {
    /// 用紙寸法をミリメートル単位で返す。
    pub fn dimensions_mm(self, orientation: PrintOrientation) -> (f64, f64) {
        match (self, orientation) {
            (Self::A4, PrintOrientation::Portrait) => (210.0, 297.0),
            (Self::A4, PrintOrientation::Landscape) => (297.0, 210.0),
        }
    }
}

/// 用紙の向き。
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum PrintOrientation {
    /// 縦向き。
    Portrait,
    /// 横向き。
    Landscape,
}

/// 印刷スケールモード。
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum PrintScale {
    /// 100% の実寸で出力する。
    ActualSize,
}

/// 用紙内の印刷不可余白。単位はミリメートル。
#[derive(Debug, Clone, Copy, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PrintableArea {
    /// 左側の印刷不可余白。
    pub left_mm: f64,
    /// 右側の印刷不可余白。
    pub right_mm: f64,
    /// 上側の印刷不可余白。
    pub top_mm: f64,
    /// 下側の印刷不可余白。
    pub bottom_mm: f64,
}

/// 実寸スケール確認ガイドの設定。
#[derive(Debug, Clone, Copy, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ScaleGuide {
    /// ガイドを印刷またはエクスポート出力に含めるかどうか。
    pub enabled: bool,
    /// ガイド長。単位はミリメートル。
    pub length_mm: f64,
}
