//! 図形へ適用できるプロジェクト共有線スタイル。

use crate::layers::{LayerStyle, LinePattern, Rgba};

/// 共有スタイルの安定 ID。
pub type SharedStyleId = String;

/// プロジェクト単位で管理する共有線スタイル。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SharedStyle {
    /// 共有スタイルの安定 ID。
    pub id: SharedStyleId,
    /// ユーザー向けのスタイル名。
    pub name: String,
    /// 線色、線幅、線種。
    pub style: LayerStyle,
}

impl SharedStyle {
    /// 指定した ID、名前、線スタイルで共有スタイルを作成する。
    pub fn new(id: impl Into<SharedStyleId>, name: impl Into<String>, style: LayerStyle) -> Self {
        Self {
            id: id.into(),
            name: name.into(),
            style,
        }
    }

    /// 新規ドキュメントに含めるレザークラフト向けの既定共有スタイルを返す。
    pub fn default_leathercraft_presets() -> Vec<Self> {
        vec![
            Self::new(
                "style:outer-cut-line",
                "外形カット線",
                style(hex(0x11, 0x18, 0x27), 0.25, LinePattern::Solid),
            ),
            Self::new(
                "style:stitch-line",
                "縫い線",
                style(hex(0xdc, 0x26, 0x26), 0.18, LinePattern::Dashed),
            ),
            Self::new(
                "style:fold-line",
                "折り線",
                style(hex(0x25, 0x63, 0xeb), 0.18, LinePattern::Dashed),
            ),
            Self::new(
                "style:center-line",
                "中心線",
                style(hex(0x16, 0xa3, 0x4a), 0.13, LinePattern::Dotted),
            ),
            Self::new(
                "style:construction-line",
                "補助線",
                style(hex(0x6b, 0x72, 0x80), 0.13, LinePattern::Construction),
            ),
            Self::new(
                "style:dimension-line",
                "寸法線",
                style(hex(0x93, 0x33, 0xea), 0.13, LinePattern::Solid),
            ),
        ]
    }
}

fn style(stroke: Rgba, stroke_width_mm: f64, pattern: LinePattern) -> LayerStyle {
    LayerStyle {
        stroke,
        stroke_width_mm,
        pattern,
    }
}

fn hex(red: u8, green: u8, blue: u8) -> Rgba {
    Rgba {
        red: f32::from(red) / 255.0,
        green: f32::from(green) / 255.0,
        blue: f32::from(blue) / 255.0,
        alpha: 1.0,
    }
}
