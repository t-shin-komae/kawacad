//! [`ProjectDocument`](crate::document::ProjectDocument) を変更するコマンド型。

use crate::constraints::{Constraint, ConstraintKind, ConstraintTarget, ConstraintValue};
use crate::derived::{DerivedElement, DerivedElementId, OffsetDirection};
use crate::free_text::{FreeText, FreeTextId};
use crate::geometry::{Entity, EntityId, Point2};
use crate::layers::{Layer, LayerStyle};
use crate::measurement::{
    DimensionConstraintAnnotation, DimensionConstraintAnnotationId, MeasurementAnnotation,
    MeasurementAnnotationId,
};
use crate::parameters::{Parameter, ParameterId};
use crate::parts::{Part, PartAlignment, PartDistributionAxis, PartId};
use crate::round_holes::{RoundHole, RoundHoleId, RoundHoleKind};
use crate::shared_styles::{SharedStyle, SharedStyleId};
use crate::stitch_start_points::{StitchStartPoint, StitchStartPointId};

/// 作図ジェスチャーから生成する線の方向補正。
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum GestureAxis {
    /// Y 座標を始点へ合わせる。
    Horizontal,
    /// X 座標を始点へ合わせる。
    Vertical,
}

/// UI が確定した作図ジェスチャー。正規図形への変換は Core が行う。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(
    tag = "kind",
    rename_all = "camelCase",
    rename_all_fields = "camelCase"
)]
pub enum EntityGesture {
    /// 単一点。
    Point {
        /// 配置位置。
        position: Point2,
    },
    /// 線分または中心線。
    Line {
        /// 始点。
        start: Point2,
        /// 終点候補。
        end: Point2,
        #[serde(default)]
        /// 中心線として作るか。
        center_line: bool,
        #[serde(default)]
        /// 任意の方向補正。
        axis: Option<GestureAxis>,
    },
    /// 中心と円周上の一点で指定する円。
    Circle {
        /// 円の中心。
        center: Point2,
        /// 円周上の点。
        radius_point: Point2,
    },
    /// 中心、円周上の開始点・終点とドラッグ継続方向で指定する円弧。
    Arc {
        /// 円弧の中心。
        center: Point2,
        /// 円弧の開始点。
        start: Point2,
        /// 円弧の終点候補。
        end: Point2,
        /// 180 度を超えるドラッグを保持するための掃引角参照値。
        #[serde(default)]
        sweep_reference_rad: Option<f64>,
    },
}

/// 新規線端点と既存 target の一致拘束作成意図。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GestureSnapConstraint {
    /// 新しく作る拘束 ID。
    pub constraint_id: String,
    /// 一致させる既存 target。
    pub target: ConstraintTarget,
}

/// UI が数値編集で指定する幾何上の意味値。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(
    tag = "kind",
    rename_all = "camelCase",
    rename_all_fields = "camelCase"
)]
pub enum EntityMetric {
    /// 線分または中心線の始点を保った長さ。
    SegmentLength {
        /// 設定する長さ。単位はミリメートル。
        value_mm: f64,
    },
    /// 円の半径。
    CircleRadius {
        /// 設定する半径。単位はミリメートル。
        value_mm: f64,
    },
    /// 円弧の半径、開始角、掃引角。
    Arc {
        /// 半径。単位はミリメートル。
        radius_mm: f64,
        /// 開始角。単位はラジアン。
        start_angle_rad: f64,
        /// 掃引角。単位はラジアン。
        sweep_angle_rad: f64,
    },
    /// 現在の円弧を基準に、指定された値だけを変更する。
    ArcUpdate {
        /// 新しい半径。省略時は保持する。
        #[serde(default)]
        radius_mm: Option<f64>,
        /// 新しい開始角。省略時は保持する。
        #[serde(default)]
        start_angle_rad: Option<f64>,
        /// 新しい掃引角。省略時は保持する。
        #[serde(default)]
        sweep_angle_rad: Option<f64>,
    },
}

/// Core が依存閉包を求めるための選択参照。
#[derive(Debug, Clone, Default, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SelectionReference {
    #[serde(default)]
    /// 選択中の通常図形 ID。
    pub entity_ids: Vec<String>,
    #[serde(default)]
    /// 選択中の派生要素 ID。
    pub derived_element_ids: Vec<String>,
    #[serde(default)]
    /// 明示選択された拘束 ID。
    pub constraint_ids: Vec<String>,
    #[serde(default)]
    /// 明示選択された計測表示 ID。
    pub measurement_annotation_ids: Vec<String>,
    #[serde(default)]
    /// 明示選択された縫い始め点 ID。
    pub stitch_start_point_ids: Vec<String>,
    #[serde(default)]
    /// 選択中の自由テキスト ID。
    pub free_text_ids: Vec<String>,
}

/// Rust コアが受け付ける粗い粒度のドキュメント変更。
///
/// ドキュメントはコマンド適用時に ID と参照を検証するため、
/// フロントエンドは可能な限り直接変更ではなくこのコマンド境界を使う。
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(
    tag = "kind",
    content = "payload",
    rename_all = "camelCase",
    rename_all_fields = "camelCase"
)]
pub enum DocumentCommand {
    /// ドキュメント名を更新する。
    RenameDocument {
        /// 新しいドキュメント名。
        name: String,
    },
    /// 幾何エンティティを追加する。
    AddEntity(Entity),
    /// 作図ジェスチャーから正規図形と付随拘束を原子的に追加する。
    CreateEntityFromGesture {
        /// 新しい図形 ID。
        id: EntityId,
        /// 配置レイヤー。
        layer_id: Option<String>,
        /// 任意の共有スタイル。
        #[serde(default)]
        style_id: Option<String>,
        /// 確定済みの入力ジェスチャー。
        gesture: EntityGesture,
        /// 線始点の任意の一致拘束。
        #[serde(default)]
        start_snap: Option<GestureSnapConstraint>,
        /// 線終点の任意の一致拘束。
        #[serde(default)]
        end_snap: Option<GestureSnapConstraint>,
        /// 水平・垂直補正に付随して作る任意の方向拘束 ID。
        #[serde(default)]
        axis_constraint_id: Option<String>,
    },
    /// 既存の幾何エンティティを置き換える。
    UpdateEntity(Entity),
    /// 既存エンティティ集合を希望差分で移動する。
    MoveEntities {
        /// 移動対象のエンティティ ID。
        entity_ids: Vec<EntityId>,
        /// 希望移動差分。単位はミリメートル。
        delta: Point2,
        /// 通常移動が解けない単一線分を、片端伸縮として試してよいか。
        allow_single_line_stretch: bool,
    },
    /// 既存エンティティの制御点を希望位置へ移動する。
    MoveControlPoint {
        /// 移動する制御点 target。
        target: ConstraintTarget,
        /// 希望位置。単位はミリメートル。
        position: Point2,
        /// 線分端点を元方向へ射影した候補として試してよいか。
        allow_projection: bool,
    },
    /// 現在形状に対して意味値を設定し、Core が正規図形を導出する。
    SetEntityMetric {
        /// 対象図形 ID。
        entity_id: EntityId,
        /// 設定する意味値。
        metric: EntityMetric,
    },
    /// エンティティのレイヤーだけを変更する。
    SetEntityLayer {
        /// 対象エンティティ ID。
        entity_id: EntityId,
        /// 新しいレイヤー ID。未指定ならレイヤー参照を解除する。
        layer_id: Option<String>,
    },
    /// 選択円弧と接続線分を滑らかな接線関係へ再構成する。
    SmoothArcTangencies {
        /// 対象円弧 ID。
        arc_entity_id: EntityId,
    },
    /// エンティティを削除し、依存する拘束を取り除く。
    DeleteEntity(EntityId),
    /// 元図形に追従する派生要素を追加する。
    AddDerivedElement(DerivedElement),
    /// Core 内部の正規化済み派生要素を置き換える。
    UpdateDerivedElement(DerivedElement),
    /// オフセット派生要素の距離だけを変更する。
    SetDerivedDistance {
        /// 対象派生要素 ID。
        derived_element_id: DerivedElementId,
        /// 新しい距離値。
        value: crate::constraints::ConstraintValue,
    },
    /// フィレット派生要素の半径だけを変更する。
    SetDerivedRadius {
        /// 対象派生要素 ID。
        derived_element_id: DerivedElementId,
        /// 新しい半径値。
        value: crate::constraints::ConstraintValue,
    },
    /// 解決済みフィレット円弧とポインタ位置から半径だけを変更する。
    SetDerivedRadiusFromPoint {
        /// 対象派生要素 ID。
        derived_element_id: DerivedElementId,
        /// 基準にする解決済み円弧 index。
        resolved_index: usize,
        /// 利用者が指定した位置。
        position: Point2,
    },
    /// オフセット派生要素の方向だけを変更する。
    SetDerivedDirection {
        /// 対象派生要素 ID。
        derived_element_id: DerivedElementId,
        /// 新しい方向。
        direction: OffsetDirection,
    },
    /// 派生要素のレイヤーだけを変更する。
    SetDerivedLayer {
        /// 対象派生要素 ID。
        derived_element_id: DerivedElementId,
        /// 新しいレイヤー ID。
        layer_id: Option<String>,
    },
    /// 派生要素の共有スタイルだけを変更する。
    SetDerivedSharedStyle {
        /// 対象派生要素 ID。
        derived_element_id: DerivedElementId,
        /// 新しい共有スタイル ID。
        style_id: Option<SharedStyleId>,
    },
    /// フィレットの元図形と閉輪郭指定だけを変更する。
    SetFilletSources {
        /// 対象フィレット ID。
        derived_element_id: DerivedElementId,
        /// 新しい元図形 ID 群。
        source_entity_ids: Vec<EntityId>,
        /// 閉輪郭として解釈するか。
        closed: bool,
    },
    /// 派生要素を削除する。
    DeleteDerivedElement(DerivedElementId),
    /// ユーザー自由テキストを追加する。
    AddFreeText(FreeText),
    /// 既存のユーザー自由テキストを置き換える。
    UpdateFreeText(FreeText),
    /// ID を指定してユーザー自由テキストを削除する。
    DeleteFreeText(FreeTextId),
    /// 円エンティティへ用途を付与した丸穴を追加する。
    AddRoundHole(RoundHole),
    /// Core 内部の丸穴メタデータを置き換える。
    UpdateRoundHole(RoundHole),
    /// 作図位置と用途から円図形および丸穴メタデータを原子的に作成する。
    CreateRoundHole {
        /// 新しい丸穴 ID。
        id: RoundHoleId,
        /// 新しい参照円 ID。
        entity_id: EntityId,
        /// 円の中心位置。
        center: Point2,
        /// 丸穴直径。単位はミリメートル。
        diameter_mm: f64,
        /// レザークラフト上の用途。
        round_hole_kind: RoundHoleKind,
        /// 配置レイヤー。
        layer_id: Option<String>,
        /// 任意の共有スタイル。
        #[serde(default)]
        style_id: Option<String>,
    },
    /// 丸穴が参照する円の直径だけを変更する。
    SetRoundHoleDiameter {
        /// 対象丸穴 ID。
        round_hole_id: RoundHoleId,
        /// 新しい直径。
        diameter_mm: f64,
    },
    /// 丸穴の用途だけを変更する。
    SetRoundHoleKind {
        /// 対象丸穴 ID。
        round_hole_id: RoundHoleId,
        /// 新しい用途。
        kind: RoundHoleKind,
    },
    /// ID を指定して丸穴用途メタデータを削除する。
    DeleteRoundHole(RoundHoleId),
    /// 縫い線へ紐づく縫い始め点を追加する。
    AddStitchStartPoint(StitchStartPoint),
    /// モデル座標から有効な縫い線上の正規位置を決めて縫い始め点を追加する。
    PlaceStitchStartPoint {
        /// 新しい縫い始め点 ID。
        id: StitchStartPointId,
        /// ユーザーが指定したモデル座標。
        position: Point2,
        #[serde(default)]
        /// UI が空間検索で絞り込んだ任意の候補 ID。
        candidate_target_ids: Vec<String>,
        /// 候補として許容する最大距離。
        max_distance_mm: f64,
    },
    /// 既存の縫い始め点を置き換える。
    UpdateStitchStartPoint(StitchStartPoint),
    /// ID を指定して縫い始め点を削除する。
    DeleteStitchStartPoint(StitchStartPointId),
    /// 描画レイヤーを追加する。
    AddLayer(Layer),
    /// ID を指定してレイヤー名を更新する。
    RenameLayer {
        /// 更新するレイヤーの ID。
        layer_id: crate::layers::LayerId,
        /// 新しいレイヤー名。
        name: String,
    },
    /// ID を指定してレイヤーを削除する。
    DeleteLayer(crate::layers::LayerId),
    /// ID を指定してレイヤーの表示状態を更新する。
    SetLayerVisibility {
        /// 更新するレイヤーの ID。
        layer_id: crate::layers::LayerId,
        /// `true` の場合、このレイヤー上のエンティティをスナップショットへ含める。
        visible: bool,
    },
    /// ID を指定してレイヤーの印刷対象状態を更新する。
    SetLayerPrintable {
        /// 更新するレイヤーの ID。
        layer_id: crate::layers::LayerId,
        /// `true` の場合、このレイヤー上のエンティティを印刷または出力対象にする。
        printable: bool,
    },
    /// ID を指定してレイヤーの線スタイルを更新する。
    SetLayerStyle {
        /// 更新するレイヤーの ID。
        layer_id: crate::layers::LayerId,
        /// 新しい線スタイル。
        style: LayerStyle,
    },
    /// 共有スタイルを追加する。
    AddSharedStyle(SharedStyle),
    /// 既存の共有スタイルを置き換える。
    UpdateSharedStyle(SharedStyle),
    /// ID を指定して共有スタイルを削除する。
    DeleteSharedStyle(SharedStyleId),
    /// ID を指定してエンティティへ共有スタイルを適用または解除する。
    SetEntitySharedStyle {
        /// 更新するエンティティの ID。
        entity_id: EntityId,
        /// 適用する共有スタイル ID。`None` の場合は共有スタイル参照を解除する。
        style_id: Option<SharedStyleId>,
    },
    /// 幾何、寸法、対称、固定の拘束を追加する。
    AddConstraint(Constraint),
    /// 既存の拘束を置き換える。
    UpdateConstraint(Constraint),
    /// 拘束の値だけを変更する。
    SetConstraintValue {
        /// 対象拘束 ID。
        constraint_id: String,
        /// 新しい固定値。
        value: ConstraintValue,
    },
    /// 拘束を名前付きパラメータ参照へ切り替える。
    SetConstraintParameter {
        /// 対象拘束 ID。
        constraint_id: String,
        /// 参照するパラメータ ID。
        parameter_id: ParameterId,
    },
    /// ID を指定して拘束を削除する。
    DeleteConstraint(crate::constraints::ConstraintId),
    /// 視覚補助用の計測表示を追加する。
    AddMeasurementAnnotation(MeasurementAnnotation),
    /// Core 内部の計測注記を置き換える。
    UpdateMeasurementAnnotation(MeasurementAnnotation),
    /// 計測注記の永続オフセットへ差分を加える。
    MoveMeasurementAnnotation {
        /// 対象注記 ID。
        annotation_id: MeasurementAnnotationId,
        /// 加算する mm 差分。
        delta: Point2,
        /// ラベルのみを動かすか。
        label_only: bool,
    },
    /// ID を指定して計測表示を削除する。
    DeleteMeasurementAnnotation(MeasurementAnnotationId),
    /// 現在の正規計測値から寸法拘束を作り、元の計測表示を削除する。
    ConvertMeasurementToConstraint {
        /// 変換元の計測表示 ID。
        annotation_id: MeasurementAnnotationId,
        /// 新しく作る拘束 ID。
        constraint_id: String,
    },
    /// 寸法拘束に紐づく表示位置を追加する。
    AddDimensionConstraintAnnotation(DimensionConstraintAnnotation),
    /// Core 内部の寸法拘束注記を置き換える。
    UpdateDimensionConstraintAnnotation(DimensionConstraintAnnotation),
    /// 寸法拘束注記の永続オフセットへ差分を加える。未作成なら既定値から作成する。
    MoveDimensionConstraintAnnotation {
        /// 対象拘束 ID。
        constraint_id: DimensionConstraintAnnotationId,
        /// 加算する mm 差分。
        delta: Point2,
        /// ラベルのみを動かすか。
        label_only: bool,
    },
    /// 拘束 ID を指定して寸法拘束表示位置を削除する。
    DeleteDimensionConstraintAnnotation(DimensionConstraintAnnotationId),
    /// 名前付きミリメートルパラメータを追加する。
    AddParameter(Parameter),
    /// 既存パラメータを置き換える。
    UpdateParameter(Parameter),
    /// パラメータを削除し、既存の拘束参照を固定値へ置き換える。
    DeleteParameter {
        /// 削除するパラメータの ID。
        parameter_id: ParameterId,
        /// そのパラメータを参照していた拘束に設定する固定ミリメートル値。
        replacement_value_mm: f64,
    },
    /// 既存パラメータのミリメートル値を更新する。
    SetParameterValue {
        /// 更新するパラメータの ID。
        parameter_id: ParameterId,
        /// 新しいパラメータ値。単位はミリメートル。
        value_mm: f64,
    },
    /// 選択した通常図形から閉じた外形と穴を判定してパーツを作成する。
    CreatePart {
        /// 新しいパーツ ID。
        id: PartId,
        /// 利用者向けのパーツ名。
        name: String,
        /// パーツ内座標の基準となる原点。省略時は Core が選択図形から決める。
        #[serde(default)]
        origin_mm: Option<Point2>,
        /// 外形、穴、付随図形の候補として選択された通常図形 ID。
        entity_ids: Vec<EntityId>,
    },
    /// 互換コマンド。旧形式の呼び出しを受け付ける。
    UpdatePart {
        /// パーツ ID。
        id: PartId,
        /// 名称。
        name: String,
        /// 原点。
        origin_mm: Point2,
    },
    /// パーツ名だけを変更する。
    RenamePart {
        /// 対象パーツ ID。
        part_id: PartId,
        /// 新しい名前。
        name: String,
    },
    /// パーツの表示設定だけを変更する。
    SetPartVisibility {
        /// 対象パーツ ID。
        part_id: PartId,
        /// 表示するか。
        visible: bool,
    },
    /// パーツの印刷設定だけを変更する。
    SetPartPrintable {
        /// 対象パーツ ID。
        part_id: PartId,
        /// 印刷するか。
        printable: bool,
    },
    /// パーツ数量だけを変更する。
    SetPartQuantity {
        /// 対象パーツ ID。
        part_id: PartId,
        /// 新しい数量。
        quantity: u32,
    },
    /// 互換コマンド。旧形式の呼び出しを受け付ける。
    UpdatePartSettings {
        /// パーツ ID。
        part_id: PartId,
        /// 表示設定。
        visible: bool,
        /// 印刷設定。
        printable: bool,
        /// 固定設定。
        locked: bool,
        /// 数量。
        quantity: u32,
    },
    /// パーツのまとまりだけを解除し、所属要素は残す。
    DeletePart(PartId),
    /// パーツに所属する作図内容と原点を同じ差分で移動する。
    MovePart {
        /// 移動対象のパーツ ID。
        part_id: PartId,
        /// 希望移動差分。単位はミリメートル。
        delta: Point2,
    },
    /// パーツ原点を絶対位置へ移動する。
    SetPartPosition {
        /// 移動対象のパーツ ID。
        part_id: PartId,
        /// 希望する原点位置。単位はミリメートル。
        position: Point2,
    },
    /// パーツ定義と所属内容を新しい ID 群へ複製する。
    DuplicatePart {
        /// 複製元パーツ ID。
        part_id: PartId,
        /// 新しいパーツ ID。
        new_part_id: PartId,
        /// 新しいパーツ名。
        new_name: String,
        /// 新しい ID を一意にする名前空間。
        id_namespace: String,
        /// 複製先への移動差分。
        delta: Point2,
    },
    /// Core が書き出した不透明なパーツライブラリ項目を配置する。
    InsertPartLibraryItem {
        /// `exportPartLibraryItem` が返した不透明 JSON 文字列。
        library_json: String,
        /// 旧 UI が保存した選択 clipboard 形式のライブラリ項目との互換情報。
        #[serde(default)]
        legacy_source_part: Option<Part>,
        /// 新しいパーツ ID。
        new_part_id: PartId,
        /// 新しいパーツ名。
        new_name: String,
        /// 新しい内部 ID を一意にする名前空間。
        id_namespace: String,
        /// 登録時の位置から配置先への移動差分。
        delta: Point2,
    },
    /// 未所属の通常図形を既存パーツへ追加する。
    AddEntitiesToPart {
        /// 更新対象のパーツ ID。
        part_id: PartId,
        /// 追加する通常図形 ID。
        entity_ids: Vec<EntityId>,
    },
    /// 外形・穴以外の通常図形を既存パーツから除外する。
    RemoveEntitiesFromPart {
        /// 更新対象のパーツ ID。
        part_id: PartId,
        /// 除外する通常図形 ID。
        entity_ids: Vec<EntityId>,
    },
    /// 選択中の所属図形から外形と穴を再判定する。
    SetPartBoundary {
        /// 更新対象のパーツ ID。
        part_id: PartId,
        /// 新しい外形と穴の候補となる通常図形 ID。
        entity_ids: Vec<EntityId>,
    },
    /// 複数パーツを外形境界で整列する。
    AlignParts {
        /// 対象パーツ ID。2件以上。
        part_ids: Vec<PartId>,
        /// 揃える境界または中心。
        alignment: PartAlignment,
    },
    /// 複数パーツの外形間隔を均等にする。
    DistributeParts {
        /// 対象パーツ ID。3件以上。
        part_ids: Vec<PartId>,
        /// 均等化する軸。
        axis: PartDistributionAxis,
    },
    /// 選択対象の依存閉包を ID と参照を再割り当てして複製する。
    DuplicateSelection {
        /// 複製の起点となる選択参照。
        selection: SelectionReference,
        /// 新しい ID を一意にする名前空間。
        id_namespace: String,
        /// 複製先への移動差分。
        delta: Point2,
    },
    /// Core が書き出した不透明な選択スナップショットを貼り付ける。
    PasteSelection {
        /// `exportSelection` が返した不透明 JSON 文字列。
        clipboard_json: String,
        /// 新規 ID の衝突を避ける名前空間。
        id_namespace: String,
        /// 元位置からの移動量。
        delta: Point2,
    },
    /// 複数のコマンドを1つの原子的な変更単位として適用する。
    Compound(Vec<DocumentCommand>),
}

impl DocumentCommand {
    /// UI/Core 境界で使うコマンド種別名。
    pub fn kind_name(&self) -> &'static str {
        match self {
            Self::RenameDocument { .. } => "renameDocument",
            Self::AddEntity(_) => "addEntity",
            Self::CreateEntityFromGesture { .. } => "createEntityFromGesture",
            Self::UpdateEntity(_) => "updateEntity",
            Self::MoveEntities { .. } => "moveEntities",
            Self::MoveControlPoint { .. } => "moveControlPoint",
            Self::SetEntityMetric { .. } => "setEntityMetric",
            Self::SetEntityLayer { .. } => "setEntityLayer",
            Self::SmoothArcTangencies { .. } => "smoothArcTangencies",
            Self::DeleteEntity(_) => "deleteEntity",
            Self::AddDerivedElement(_) => "addDerivedElement",
            Self::UpdateDerivedElement(_) => "updateDerivedElement",
            Self::SetDerivedDistance { .. } => "setDerivedDistance",
            Self::SetDerivedRadius { .. } => "setDerivedRadius",
            Self::SetDerivedRadiusFromPoint { .. } => "setDerivedRadiusFromPoint",
            Self::SetDerivedDirection { .. } => "setDerivedDirection",
            Self::SetDerivedLayer { .. } => "setDerivedLayer",
            Self::SetDerivedSharedStyle { .. } => "setDerivedSharedStyle",
            Self::SetFilletSources { .. } => "setFilletSources",
            Self::DeleteDerivedElement(_) => "deleteDerivedElement",
            Self::AddFreeText(_) => "addFreeText",
            Self::UpdateFreeText(_) => "updateFreeText",
            Self::DeleteFreeText(_) => "deleteFreeText",
            Self::AddRoundHole(_) => "addRoundHole",
            Self::UpdateRoundHole(_) => "updateRoundHole",
            Self::CreateRoundHole { .. } => "createRoundHole",
            Self::SetRoundHoleDiameter { .. } => "setRoundHoleDiameter",
            Self::SetRoundHoleKind { .. } => "setRoundHoleKind",
            Self::DeleteRoundHole(_) => "deleteRoundHole",
            Self::AddStitchStartPoint(_) => "addStitchStartPoint",
            Self::PlaceStitchStartPoint { .. } => "placeStitchStartPoint",
            Self::UpdateStitchStartPoint(_) => "updateStitchStartPoint",
            Self::DeleteStitchStartPoint(_) => "deleteStitchStartPoint",
            Self::AddLayer(_) => "addLayer",
            Self::RenameLayer { .. } => "renameLayer",
            Self::DeleteLayer(_) => "deleteLayer",
            Self::SetLayerVisibility { .. } => "setLayerVisibility",
            Self::SetLayerPrintable { .. } => "setLayerPrintable",
            Self::SetLayerStyle { .. } => "setLayerStyle",
            Self::AddSharedStyle(_) => "addSharedStyle",
            Self::UpdateSharedStyle(_) => "updateSharedStyle",
            Self::DeleteSharedStyle(_) => "deleteSharedStyle",
            Self::SetEntitySharedStyle { .. } => "setEntitySharedStyle",
            Self::AddConstraint(_) => "addConstraint",
            Self::UpdateConstraint(_) => "updateConstraint",
            Self::SetConstraintValue { .. } => "setConstraintValue",
            Self::SetConstraintParameter { .. } => "setConstraintParameter",
            Self::DeleteConstraint(_) => "deleteConstraint",
            Self::AddMeasurementAnnotation(_) => "addMeasurementAnnotation",
            Self::UpdateMeasurementAnnotation(_) => "updateMeasurementAnnotation",
            Self::MoveMeasurementAnnotation { .. } => "moveMeasurementAnnotation",
            Self::DeleteMeasurementAnnotation(_) => "deleteMeasurementAnnotation",
            Self::ConvertMeasurementToConstraint { .. } => "convertMeasurementToConstraint",
            Self::AddDimensionConstraintAnnotation(_) => "addDimensionConstraintAnnotation",
            Self::UpdateDimensionConstraintAnnotation(_) => "updateDimensionConstraintAnnotation",
            Self::MoveDimensionConstraintAnnotation { .. } => "moveDimensionConstraintAnnotation",
            Self::DeleteDimensionConstraintAnnotation(_) => "deleteDimensionConstraintAnnotation",
            Self::AddParameter(_) => "addParameter",
            Self::UpdateParameter(_) => "updateParameter",
            Self::DeleteParameter { .. } => "deleteParameter",
            Self::SetParameterValue { .. } => "setParameterValue",
            Self::CreatePart { .. } => "createPart",
            Self::UpdatePart { .. } => "updatePart",
            Self::RenamePart { .. } => "renamePart",
            Self::SetPartVisibility { .. } => "setPartVisibility",
            Self::SetPartPrintable { .. } => "setPartPrintable",
            Self::SetPartQuantity { .. } => "setPartQuantity",
            Self::UpdatePartSettings { .. } => "updatePartSettings",
            Self::DeletePart(_) => "deletePart",
            Self::MovePart { .. } => "movePart",
            Self::SetPartPosition { .. } => "setPartPosition",
            Self::DuplicatePart { .. } => "duplicatePart",
            Self::InsertPartLibraryItem { .. } => "insertPartLibraryItem",
            Self::AddEntitiesToPart { .. } => "addEntitiesToPart",
            Self::RemoveEntitiesFromPart { .. } => "removeEntitiesFromPart",
            Self::SetPartBoundary { .. } => "setPartBoundary",
            Self::AlignParts { .. } => "alignParts",
            Self::DistributeParts { .. } => "distributeParts",
            Self::DuplicateSelection { .. } => "duplicateSelection",
            Self::PasteSelection { .. } => "pasteSelection",
            Self::Compound(_) => "compound",
        }
    }
}

/// 拘束操作で UI が分岐に使う失敗分類。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ConstraintCommandErrorCode {
    /// 拘束種別に必要な対象数を満たしていない。
    InsufficientTargets,
    /// 拘束種別に対して対象の種類または組み合わせが不正。
    InvalidTarget,
    /// 同じ意味の拘束が既に存在する。
    Duplicate,
    /// 既存拘束または現在形状と両立しない。
    Conflicting,
}

/// 拘束操作失敗時に UI/Core 境界へ渡す構造化情報。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ConstraintCommandError {
    /// UI/Core 境界で使う拘束失敗分類。
    pub code: ConstraintCommandErrorCode,
    /// 失敗に関わる拘束種別。
    pub constraint_kind: ConstraintKind,
    /// 失敗に関わる拘束 ID。
    pub constraint_id: String,
    /// 失敗に関わる target ID。
    pub target_ids: Vec<String>,
    /// 実際に指定された target 数。
    pub actual_target_count: Option<usize>,
    /// 拘束種別が必要とする target 数。
    pub required_target_count: Option<usize>,
    /// UI が案内に使う期待 target 種別。
    pub expected_target_kinds: Vec<&'static str>,
    /// 不正な target として UI が強調できる target ID。
    pub invalid_target_ids: Vec<String>,
    /// 重複元として既に存在する拘束 ID。
    pub existing_constraint_id: Option<String>,
    /// 矛盾に関わる既存拘束 ID。
    pub conflicting_constraint_ids: Vec<String>,
}

/// ドキュメントコマンドを安全に適用できない場合に返すエラー。
#[derive(Debug, Clone, PartialEq)]
pub enum CommandError {
    /// 必須 ID フィールドが空、または空白のみだった。
    EmptyId(&'static str),
    /// 既に存在する ID のオブジェクトを作成しようとした。
    DuplicateId {
        /// ID が重複したオブジェクト種別。
        kind: &'static str,
        /// 重複した ID。
        id: String,
    },
    /// 存在しないオブジェクトを更新または削除しようとした。
    MissingId {
        /// 見つからなかったオブジェクト種別。
        kind: &'static str,
        /// 見つからなかった ID。
        id: String,
    },
    /// エンティティが幾何レベルの検証に失敗した。
    InvalidEntity(crate::geometry::GeometryValidationError),
    /// 数値またはテキスト値がドキュメントレベルの検証に失敗した。
    InvalidValue {
        /// 不正だったフィールド名。
        field: &'static str,
        /// 検証失敗の理由。
        reason: &'static str,
    },
    /// コマンドがドキュメント内に存在しないオブジェクトを参照した。
    BrokenReference {
        /// 作成または更新しようとしていたオブジェクト。
        source: &'static str,
        /// 参照先オブジェクトの種別。
        target_kind: &'static str,
        /// 見つからなかった参照先 ID。
        target_id: String,
    },
    /// 拘束追加または更新に固有の検証に失敗した。
    Constraint(Box<ConstraintCommandError>),
}

/// ドキュメントコマンド操作が返す結果型。
pub type CommandResult<T = ()> = Result<T, CommandError>;

impl CommandError {
    /// ID 重複エラーを作成する。
    pub(crate) fn duplicate(kind: &'static str, id: impl Into<String>) -> Self {
        Self::DuplicateId {
            kind,
            id: id.into(),
        }
    }

    /// ID 不存在エラーを作成する。
    pub(crate) fn missing(kind: &'static str, id: impl Into<String>) -> Self {
        Self::MissingId {
            kind,
            id: id.into(),
        }
    }

    /// 参照切れエラーを作成する。
    pub(crate) fn broken_reference(
        source: &'static str,
        target_kind: &'static str,
        target_id: impl Into<String>,
    ) -> Self {
        Self::BrokenReference {
            source,
            target_kind,
            target_id: target_id.into(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::constraints::{Constraint, ConstraintKind, ConstraintStatus};
    use crate::derived::{DerivedElement, Fillet};
    use crate::geometry::{Entity, EntityKind, LineSegment, Point2};
    use crate::layers::{Layer, LayerKind, LayerStyle};
    use crate::measurement::{
        DimensionConstraintAnnotation, MeasurementAnnotation, MeasurementAnnotationKind,
    };
    use crate::parameters::{Parameter, ParameterUnit};

    fn point(x_mm: f64, y_mm: f64) -> Point2 {
        Point2::new(x_mm, y_mm)
    }

    fn sample_entity(id: &str) -> Entity {
        Entity::new(
            id,
            EntityKind::LineSegment(LineSegment::new(point(0.0, 0.0), point(1.0, 0.0))),
        )
    }

    fn sample_constraint(id: &str) -> Constraint {
        Constraint {
            id: id.to_owned(),
            kind: ConstraintKind::Fixed,
            targets: vec![crate::constraints::ConstraintTarget::Entity(
                "entity:line".to_owned(),
            )],
            value: None,
            status: ConstraintStatus::Unknown,
        }
    }

    fn sample_derived_element(id: &str) -> DerivedElement {
        DerivedElement::fillet(
            id,
            None,
            Fillet {
                source_entity_ids: vec!["entity:a".to_owned(), "entity:b".to_owned()],
                radius: crate::constraints::ConstraintValue::FixedMm(1.0),
                closed: false,
            },
        )
    }

    fn sample_annotation(id: &str) -> MeasurementAnnotation {
        MeasurementAnnotation {
            id: id.to_owned(),
            kind: MeasurementAnnotationKind::SegmentLength,
            targets: vec![crate::constraints::ConstraintTarget::Entity(
                "entity:line".to_owned(),
            )],
            label_offset_mm: point(0.0, 0.0),
            overall_offset_mm: point(0.0, 0.0),
            visible: true,
        }
    }

    fn sample_dimension_annotation(constraint_id: &str) -> DimensionConstraintAnnotation {
        DimensionConstraintAnnotation {
            constraint_id: constraint_id.to_owned(),
            label_offset_mm: point(0.0, 0.0),
            overall_offset_mm: point(0.0, 0.0),
            visible: true,
        }
    }

    fn sample_parameter(id: &str) -> Parameter {
        Parameter {
            id: id.to_owned(),
            name: "Length".to_owned(),
            value_mm: 10.0,
            unit: ParameterUnit::Millimeter,
            memo: String::new(),
        }
    }

    fn sample_free_text(id: &str) -> FreeText {
        FreeText::new(id, "Note", point(12.0, -8.0), 4.0)
    }

    #[test]
    fn document_command_kind_name_covers_all_command_variants() {
        let style = LayerStyle::default_for(LayerKind::Dimension);
        let commands = vec![
            (
                DocumentCommand::RenameDocument {
                    name: "Renamed".to_owned(),
                },
                "renameDocument",
            ),
            (
                DocumentCommand::AddEntity(sample_entity("entity:add")),
                "addEntity",
            ),
            (
                DocumentCommand::UpdateEntity(sample_entity("entity:update")),
                "updateEntity",
            ),
            (
                DocumentCommand::DeleteEntity("entity:delete".to_owned()),
                "deleteEntity",
            ),
            (
                DocumentCommand::CreateRoundHole {
                    id: "round-hole:create".to_owned(),
                    entity_id: "entity:round-hole:create".to_owned(),
                    center: Point2::new(1.0, 2.0),
                    diameter_mm: 4.0,
                    round_hole_kind: RoundHoleKind::Rivet,
                    layer_id: None,
                    style_id: None,
                },
                "createRoundHole",
            ),
            (
                DocumentCommand::SetRoundHoleKind {
                    round_hole_id: "round-hole:set-kind".to_owned(),
                    kind: RoundHoleKind::Decorative,
                },
                "setRoundHoleKind",
            ),
            (
                DocumentCommand::AddDerivedElement(sample_derived_element("derived:add")),
                "addDerivedElement",
            ),
            (
                DocumentCommand::DeleteDerivedElement("derived:delete".to_owned()),
                "deleteDerivedElement",
            ),
            (
                DocumentCommand::AddFreeText(sample_free_text("free-text:add")),
                "addFreeText",
            ),
            (
                DocumentCommand::UpdateFreeText(sample_free_text("free-text:update")),
                "updateFreeText",
            ),
            (
                DocumentCommand::DeleteFreeText("free-text:delete".to_owned()),
                "deleteFreeText",
            ),
            (
                DocumentCommand::AddLayer(Layer::new(
                    "layer:add",
                    "Add",
                    LayerKind::Dimension,
                    true,
                )),
                "addLayer",
            ),
            (
                DocumentCommand::RenameLayer {
                    layer_id: "layer:rename".to_owned(),
                    name: "Rename".to_owned(),
                },
                "renameLayer",
            ),
            (
                DocumentCommand::DeleteLayer("layer:delete".to_owned()),
                "deleteLayer",
            ),
            (
                DocumentCommand::SetLayerVisibility {
                    layer_id: "layer:visibility".to_owned(),
                    visible: false,
                },
                "setLayerVisibility",
            ),
            (
                DocumentCommand::SetLayerPrintable {
                    layer_id: "layer:printable".to_owned(),
                    printable: false,
                },
                "setLayerPrintable",
            ),
            (
                DocumentCommand::SetLayerStyle {
                    layer_id: "layer:style".to_owned(),
                    style,
                },
                "setLayerStyle",
            ),
            (
                DocumentCommand::AddConstraint(sample_constraint("constraint:add")),
                "addConstraint",
            ),
            (
                DocumentCommand::UpdateConstraint(sample_constraint("constraint:update")),
                "updateConstraint",
            ),
            (
                DocumentCommand::SetConstraintValue {
                    constraint_id: "constraint:set-value".to_owned(),
                    value: ConstraintValue::FixedMm(12.0),
                },
                "setConstraintValue",
            ),
            (
                DocumentCommand::SetConstraintParameter {
                    constraint_id: "constraint:set-parameter".to_owned(),
                    parameter_id: "parameter:width".to_owned(),
                },
                "setConstraintParameter",
            ),
            (
                DocumentCommand::DeleteConstraint("constraint:delete".to_owned()),
                "deleteConstraint",
            ),
            (
                DocumentCommand::AddMeasurementAnnotation(sample_annotation("measurement:add")),
                "addMeasurementAnnotation",
            ),
            (
                DocumentCommand::DeleteMeasurementAnnotation("measurement:delete".to_owned()),
                "deleteMeasurementAnnotation",
            ),
            (
                DocumentCommand::AddDimensionConstraintAnnotation(sample_dimension_annotation(
                    "constraint:dimension-add",
                )),
                "addDimensionConstraintAnnotation",
            ),
            (
                DocumentCommand::DeleteDimensionConstraintAnnotation(
                    "constraint:dimension-delete".to_owned(),
                ),
                "deleteDimensionConstraintAnnotation",
            ),
            (
                DocumentCommand::AddParameter(sample_parameter("parameter:add")),
                "addParameter",
            ),
            (
                DocumentCommand::UpdateParameter(sample_parameter("parameter:update")),
                "updateParameter",
            ),
            (
                DocumentCommand::DeleteParameter {
                    parameter_id: "parameter:delete".to_owned(),
                    replacement_value_mm: 10.0,
                },
                "deleteParameter",
            ),
            (
                DocumentCommand::SetParameterValue {
                    parameter_id: "parameter:set".to_owned(),
                    value_mm: 20.0,
                },
                "setParameterValue",
            ),
            (DocumentCommand::Compound(Vec::new()), "compound"),
        ];

        for (command, expected_name) in commands {
            assert_eq!(command.kind_name(), expected_name);
        }
    }

    #[test]
    fn command_error_constructors_keep_context() {
        assert_eq!(
            CommandError::duplicate("entity", "entity:a"),
            CommandError::DuplicateId {
                kind: "entity",
                id: "entity:a".to_owned()
            }
        );
        assert_eq!(
            CommandError::missing("layer", "layer:missing"),
            CommandError::MissingId {
                kind: "layer",
                id: "layer:missing".to_owned()
            }
        );
        assert_eq!(
            CommandError::broken_reference("constraint", "entity", "entity:missing"),
            CommandError::BrokenReference {
                source: "constraint",
                target_kind: "entity",
                target_id: "entity:missing".to_owned()
            }
        );
    }
}
