use crate::constraints::Constraint;
use crate::derived::DerivedElement;
use crate::free_text::FreeText;
use crate::geometry::Entity;
use crate::layers::Layer;
use crate::measurement::ViewAnnotations;
use crate::parameters::Parameter;
use crate::parts::Part;
use crate::print::PrintSettings;
use crate::round_holes::RoundHole;
use crate::shared_styles::SharedStyle;
use crate::stitch_start_points::StitchStartPoint;

use super::{DocumentMetadata, DocumentWarning, FILE_FORMAT_VERSION, SCHEMA_VERSION};

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DocumentStore {
    /// このドキュメントが表す `.lcraft` ファイル形式のバージョン。
    pub(crate) file_format_version: String,
    /// このドキュメントの検証に使う外部 JSON Schema のバージョン。
    pub(crate) schema_version: String,
    /// 名前や単位などのドキュメントメタデータ。
    #[serde(rename = "document")]
    pub(crate) metadata: DocumentMetadata,
    /// 用紙と実寸印刷の設定。
    pub(crate) settings: PrintSettings,
    /// ドキュメントで利用可能な描画レイヤー。
    pub(crate) layers: Vec<Layer>,
    /// ドキュメントで利用可能な共有線スタイル。
    #[serde(default)]
    pub(crate) shared_styles: Vec<SharedStyle>,
    /// 名前付きミリメートルパラメータ。
    pub(crate) parameters: Vec<Parameter>,
    /// 革を切り出す単位として図形と付随要素をまとめるパーツ。
    #[serde(default)]
    pub(crate) parts: Vec<Part>,
    /// 幾何エンティティ。
    pub(crate) entities: Vec<Entity>,
    /// 元図形に追従する派生要素。
    #[serde(default)]
    pub(crate) derived_elements: Vec<DerivedElement>,
    /// ユーザーが型紙上へ配置する自由テキスト注記。
    #[serde(default)]
    pub(crate) free_texts: Vec<FreeText>,
    /// 円エンティティへ用途を付与した丸穴。
    #[serde(default)]
    pub(crate) round_holes: Vec<RoundHole>,
    /// 縫い線へ紐づく縫い始め点。
    #[serde(default)]
    pub(crate) stitch_start_points: Vec<StitchStartPoint>,
    /// パラメトリック拘束。
    pub(crate) constraints: Vec<Constraint>,
    /// 作図データ本体から分離した表示補助メタデータ。
    #[serde(default)]
    pub(crate) view_annotations: ViewAnnotations,
    /// 直近のコマンドで発生したユーザー向け警告。
    #[serde(skip, default)]
    pub(crate) document_warnings: Vec<DocumentWarning>,
}

impl DocumentStore {
    pub(crate) fn new(name: impl Into<String>) -> Self {
        Self {
            file_format_version: FILE_FORMAT_VERSION.to_owned(),
            schema_version: SCHEMA_VERSION.to_owned(),
            metadata: DocumentMetadata::new(name),
            settings: PrintSettings::a4_portrait(),
            layers: Layer::default_layers(),
            shared_styles: SharedStyle::default_leathercraft_presets(),
            parameters: Vec::new(),
            parts: Vec::new(),
            entities: Vec::new(),
            derived_elements: Vec::new(),
            free_texts: Vec::new(),
            round_holes: Vec::new(),
            stitch_start_points: Vec::new(),
            constraints: Vec::new(),
            view_annotations: ViewAnnotations::default(),
            document_warnings: Vec::new(),
        }
    }
}

impl PartialEq for DocumentStore {
    fn eq(&self, other: &Self) -> bool {
        self.file_format_version == other.file_format_version
            && self.schema_version == other.schema_version
            && self.metadata == other.metadata
            && self.settings == other.settings
            && self.layers == other.layers
            && self.shared_styles == other.shared_styles
            && self.parameters == other.parameters
            && self.parts == other.parts
            && self.entities == other.entities
            && self.derived_elements == other.derived_elements
            && self.free_texts == other.free_texts
            && self.round_holes == other.round_holes
            && self.stitch_start_points == other.stitch_start_points
            && self.constraints == other.constraints
            && self.view_annotations == other.view_annotations
    }
}
