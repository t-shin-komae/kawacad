//! 描画レイヤーの種類、表示可否、印刷可否、表示スタイル。

/// レイヤーの安定 ID。
pub type LayerId = String;

/// 表示、印刷、スタイルを制御する描画レイヤー。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Layer {
    /// レイヤーの安定 ID。
    pub id: LayerId,
    /// ユーザー向けのレイヤー名。
    pub name: String,
    /// レイヤーのドメイン上の役割。
    pub kind: LayerKind,
    /// このレイヤー上のエンティティを描画スナップショットに含めるかどうか。
    pub visible: bool,
    /// このレイヤー上のエンティティを印刷またはエクスポート出力に含めるかどうか。
    pub printable: bool,
    /// このレイヤー上のエンティティに使う既定の表示スタイル。
    pub style: LayerStyle,
}

impl Layer {
    /// 新規ドキュメントで使う既定レイヤーセットを返す。
    pub(crate) fn default_layers() -> Vec<Self> {
        vec![Self::new(
            "layer:cut-line",
            "Cut Line",
            LayerKind::CutLine,
            true,
        )]
    }

    /// 指定した役割と既定スタイルでレイヤーを作成する。
    pub fn new(id: &str, name: &str, kind: LayerKind, printable: bool) -> Self {
        Self {
            id: id.to_owned(),
            name: name.to_owned(),
            kind,
            visible: true,
            printable,
            style: LayerStyle::default_for(kind),
        }
    }
}

/// 描画レイヤーのドメイン上の役割。
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum LayerKind {
    /// 主要な実線形状。
    CutLine,
    /// 寸法表示用の補助レイヤー。
    Dimension,
    /// 印刷スケール確認や位置合わせのガイド。
    PrintGuide,
    /// 印刷しない補助形状。
    Construction,
}

/// レイヤーに紐づく線スタイル。
#[derive(Debug, Clone, Copy, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LayerStyle {
    /// 線色。
    pub stroke: Rgba,
    /// 線幅。単位はミリメートル。
    pub stroke_width_mm: f64,
    /// 線種。
    pub pattern: LinePattern,
}

impl LayerStyle {
    /// レイヤー種別に応じた既定スタイルを返す。
    pub(crate) fn default_for(kind: LayerKind) -> Self {
        let pattern = match kind {
            LayerKind::Construction => LinePattern::Dashed,
            _ => LinePattern::Solid,
        };

        Self {
            stroke: Rgba::BLACK,
            stroke_width_mm: 0.2,
            pattern,
        }
    }
}

/// 各チャンネルを `0.0..=1.0` で表す RGBA 色。
#[derive(Debug, Clone, Copy, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Rgba {
    /// 赤チャンネル。
    pub red: f32,
    /// 緑チャンネル。
    pub green: f32,
    /// 青チャンネル。
    pub blue: f32,
    /// アルファチャンネル。
    pub alpha: f32,
}

impl Rgba {
    /// 不透明の黒。
    pub const BLACK: Self = Self {
        red: 0.0,
        green: 0.0,
        blue: 0.0,
        alpha: 1.0,
    };
}

/// 線の描画と印刷に使う線種。
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum LinePattern {
    /// 連続した実線。
    Solid,
    /// 破線。
    Dashed,
    /// 点線。
    Dotted,
    /// 印刷しない補助形状に使う線。
    Construction,
}
