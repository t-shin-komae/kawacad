//! 出力用中間表現。

use crate::geometry::Point2;
use crate::layers::LayerStyle;
use crate::print::PrintOrientation;

/// Core が出力用中間表現を生成する際の入力オプション。
#[derive(Debug, Clone, PartialEq)]
pub struct BuildOutputDocumentModelOptions {
    /// 用紙向き。
    pub orientation: PrintOrientation,
    /// 寸法拘束数値表示を含めるかどうか。
    pub include_dimension_labels: bool,
    /// 50mm ガイドを含めるかどうか。
    pub include_scale_guide: bool,
    /// 回転角度。現行仕様では 0 または 90 のみ。
    pub rotation_deg: u16,
    /// macOS 側で取得した印刷可能領域。
    pub printable_area_mm: PrintableAreaMm,
}

/// Output Document Model の生成結果。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BuildOutputDocumentModelResult {
    /// Output Engine へ渡す中間表現。
    pub output_document_model: OutputDocumentModel,
    /// 出力前に UI が提示する警告。
    pub warnings: Vec<PrintWarning>,
}

/// Output Document Model の生成失敗。
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum OutputBuildError {
    /// 出力対象がA4 5x5グリッドの範囲外に出ている。
    OutOfGridBounds,
}

impl std::fmt::Display for OutputBuildError {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            OutputBuildError::OutOfGridBounds => {
                write!(formatter, "output target exceeds the A4 5x5 grid bounds")
            }
        }
    }
}

impl std::error::Error for OutputBuildError {}

/// Output Engine へ渡す出力用中間表現の最小単位。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct OutputDocumentModel {
    /// 現行仕様では A4 固定。
    pub paper_size: OutputPaperSize,
    /// 用紙向き。
    pub orientation: PrintOrientation,
    /// 現行仕様では常に 100% 実寸。
    pub scale: OutputScale,
    /// ページ数。A4内に収まる場合は単一ページ、A4タイル出力では複数ページ。
    pub page_count: usize,
    /// ページごとの配置結果。
    pub pages: Vec<OutputPage>,
}

/// 1ページ分の配置結果。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct OutputPage {
    /// ページ幅。単位はミリメートル。
    pub width_mm: f64,
    /// ページ高さ。単位はミリメートル。
    pub height_mm: f64,
    /// 原点固定A4グリッド上の列。原点ページを 0 とする。
    pub grid_column: i32,
    /// 原点固定A4グリッド上の行。原点ページを 0 とする。
    pub grid_row: i32,
    /// ページ内で適用する回転角度。現行仕様では 0 または 90。
    pub rotation_deg: u16,
    /// 印刷可能領域。
    pub printable_area_mm: PrintableAreaMm,
    /// 出力対象の図形要素。
    pub graphics: Vec<OutputGraphic>,
    /// 出力対象の文字要素。
    pub texts: Vec<OutputText>,
    /// 実寸確認ガイド。
    pub guide: Option<OutputGuide>,
}

/// 出力対象の図形要素。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct OutputGraphic {
    /// 元エンティティの ID。
    pub entity_id: String,
    /// 図形種別。
    pub kind: OutputGraphicKind,
    /// 図形の幾何情報。
    pub geometry: OutputGraphicGeometry,
    /// 適用する出力スタイル。
    pub style: LayerStyle,
}

/// 出力対象の図形種別。
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum OutputGraphicKind {
    /// 点。
    Point,
    /// 線分。
    LineSegment,
    /// 円。
    Circle,
    /// 円弧。
    Arc,
    /// 中心線。
    CenterLine,
}

/// 出力対象図形の幾何情報。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase", tag = "kind", content = "payload")]
pub enum OutputGraphicGeometry {
    /// 点。
    Point {
        /// 点の位置。
        position_mm: Point2,
    },
    /// 線分。
    LineSegment {
        /// 始点。
        start_mm: Point2,
        /// 終点。
        end_mm: Point2,
    },
    /// 円。
    Circle {
        /// 中心。
        center_mm: Point2,
        /// 半径。
        radius_mm: f64,
    },
    /// 円弧。
    Arc {
        /// 中心。
        center_mm: Point2,
        /// 半径。
        radius_mm: f64,
        /// 開始角。単位はラジアン。
        start_angle_rad: f64,
        /// 掃引角。単位はラジアン。
        sweep_angle_rad: f64,
    },
    /// 中心線。
    CenterLine {
        /// 始点。
        start_mm: Point2,
        /// 終点。
        end_mm: Point2,
    },
}

/// 出力対象の文字要素。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct OutputText {
    /// 文字要素の役割。
    pub kind: OutputTextKind,
    /// 表示内容。
    pub content: String,
    /// モデル空間上の基準位置。
    pub position_mm: Point2,
    /// 文字サイズ。単位はミリメートル。
    pub font_size_mm: f64,
}

/// 出力対象の文字種別。
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum OutputTextKind {
    /// 寸法拘束の数値表示。
    DimensionLabel,
    /// ガイドの数値ラベル。
    GuideLabel,
    /// ユーザーが配置した自由テキスト注記。
    FreeText,
}

/// 実寸確認用ガイド。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct OutputGuide {
    /// 基準線の始点。
    pub start_mm: Point2,
    /// 基準線の終点。
    pub end_mm: Point2,
    /// 数値ラベル。
    pub label: String,
    /// ラベル基準位置。
    pub label_position_mm: Point2,
}

/// 用紙中心基準で表した印刷可能領域。
#[derive(Debug, Clone, Copy, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PrintableAreaMm {
    /// 左端。
    pub left_mm: f64,
    /// 右端。
    pub right_mm: f64,
    /// 上端。
    pub top_mm: f64,
    /// 下端。
    pub bottom_mm: f64,
}

/// 出力前警告。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PrintWarning {
    /// 警告種別。
    pub kind: PrintWarningKind,
    /// UI 表示用メッセージ。
    pub message: String,
}

/// 出力前警告の種別。
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum PrintWarningKind {
    /// 出力対象が存在しない。
    EmptyDocument,
    /// 印刷可能領域にはみ出している。
    OutOfPrintableBounds,
    /// 図形がA4ページ境界をまたいでいる。
    PageBoundaryCrossing,
    /// 実寸印刷が最終的に保証できない。
    ActualScaleNotGuaranteed,
}

/// 現行仕様で扱う用紙サイズ。
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum OutputPaperSize {
    /// ISO A4。
    A4,
}

/// 現行仕様で扱うスケール。
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum OutputScale {
    /// 100% 実寸。
    ActualSize,
}
