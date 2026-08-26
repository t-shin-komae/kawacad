# Components

Swift/macOS UI の表示コンポーネント一覧。各ページは実装上の入口、担当する表示責務、状態の流れを短く説明する。

同じ利用者向け責務を持つ Tauri/React の実装は、各行の Tauri 欄と [`component-correspondence.md`](../../../../../docs/design/ui-architecture/component-correspondence.md) からたどれる。

| 領域 | DocC ページ | 内容 |
| --- | --- | --- |
| キャンバス | <doc:CanvasComponents> | 作図、ツール、ズーム、注記、キャンバス内編集 |
| Inspector | <doc:InspectorComponents> | 選択・レイヤー・スタイル・パラメータ・パーツの編集 |
| ドキュメント | <doc:DocumentComponents> | 名前、保存確認、レイヤー削除、貼り付け位置 |
| ワークスペース | <doc:WorkspaceComponents> | 画面レイアウト、パネル、バナー、サマリー |
| ダイアログ | <doc:DialogComponents> | 拘束値、出力、復旧、ライセンス、About |
| 共通部品 | <doc:SharedComponents> | デザイン定数と Core 同期入力 |

## 対応表

表示責務単位の対応表は、Swift と Tauri の双方から参照できる設計文書を正本とする。

- [Swift / Tauri UI コンポーネント対応表](../../../../../docs/design/ui-architecture/component-correspondence.md)
- [UI アーキテクチャ](../../../../../docs/design/ui-architecture/overview.md)

