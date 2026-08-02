//! KawaCAD の OS 非依存ドメインコア。
//!
//! このクレートは、プラットフォーム固有のフロントエンドから利用される
//! パラメトリックなドキュメントモデル、幾何プリミティブ、拘束、レイヤー、
//! 印刷設定、描画スナップショットを担当する。
#![deny(missing_docs)]

/// ドキュメントを粗い単位で変更するコマンド。
pub mod command;
/// パラメトリック作図の拘束モデル。
pub mod constraints;
/// 元図形に追従する派生要素。
pub mod derived;
/// トップレベルのプロジェクトドキュメントとファイル形式メタデータ。
pub mod document;
/// ユーザーが型紙上へ配置する自由テキスト注記。
pub mod free_text;
/// 幾何プリミティブとエンティティ検証。
pub mod geometry;
/// レイヤー定義と描画スタイル。
pub mod layers;
/// キャンバス表示用の補助注記メタデータ。
pub mod measurement;
/// 出力用中間表現。
pub mod output;
/// 名前付きミリメートルパラメータ。
pub mod parameters;
/// 閉じた外形と付随要素をまとめるパーツ。
pub mod parts;
/// 用紙と実寸印刷の設定。
pub mod print;
/// 円エンティティへ用途を付与する丸穴メタデータ。
pub mod round_holes;
/// 図形へ適用できるプロジェクト共有線スタイル。
pub mod shared_styles;
/// フロントエンド描画処理へ返す描画スナップショット型。
pub mod snapshot;
pub mod stitch_start_points;

/// トップレベルのプロジェクトドキュメントの公開エイリアス。
pub use document::ProjectDocument;

/// 既定値を持つ新規プロジェクトドキュメントを作成する。
pub fn new_document(name: impl Into<String>) -> ProjectDocument {
    ProjectDocument::new(name)
}
