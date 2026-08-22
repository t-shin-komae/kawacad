# KawaCAD

Windows、Linux、macOSで動作するKawaCADのTauri + React UIです。既存のRust Coreを変更せず、Tauri adapterは既存の`DocumentCommand`、preflight、snapshot、`.kawa`入出力だけを呼び出します。Reactが所有するのは選択、作図途中、viewport、パネル表示などの一時状態です。

## 現在含む操作

- 新規、開く、保存、Undo / Redo
- 点、線分、円、円弧、中心線、丸穴、自由テキスト、縫い始め点
- 選択、矩形選択、移動、パン、ズーム、グリッド／点スナップ
- 拘束、寸法拘束、計測注記、オフセット、フィレット
- コピー、貼り付け、複製、削除、パーツ化、パーツの整列／均等配置
- レイヤー、共有線種の適用、パラメータ、パーツ、注記の Inspector 操作、パーツライブラリの登録／配置
- デスクトップアプリの主要メニュー・ショートカット

PDF出力と直接印刷は意図的に含めません。出力機能のCoreは変更していません。

パーツライブラリと復旧スナップショットは、TauriのOS別アプリケーションデータディレクトリに保存します。

## 実行と検証

```bash
cd apps/tauri/KawaCAD
npm install
npx playwright install chromium
npm run format:check
npm test
npm run test:e2e
npm run screenshots:comparison
npm run build
npm run tauri dev
```

`npm run test:e2e` はViteで起動したUIにPlaywrightから接続し、実際の
`kawacad-core-process` とTauriのinvoke形式の境界を通してワークスペースを検証します。
通常はPlaywrightが管理するChromiumを使用します。既存のGoogle Chromeなどを使う場合だけ、
`LEATHER_E2E_CHROME` に実行ファイルのパスを指定してください。

`npm run screenshots:comparison` は目視比較用のTauri Browser画面を
`test-results/comparison-screenshots/screenshots/`へ再生成します。このディレクトリはGit管理外です。
通常のE2Eでは画像を更新しません。
レイヤー削除は実Coreを操作し、復旧候補とPDF出力は固定データで同じ画面状態を再現します。
OSのタイトルバーを含むSwift/Tauri初期ウィンドウ画像は対象外です。

Rust adapter はリポジトリルートから検証します。

```bash
cargo fmt --check
cargo test -p kawa-cad-tauri
```

設計は [`docs/design/architecture.md`](../../../docs/design/architecture.md)、[`docs/design/internal-interface-spec.md`](../../../docs/design/internal-interface-spec.md)、[`docs/design/ui-architecture/overview.md`](../../../docs/design/ui-architecture/overview.md) を参照してください。
