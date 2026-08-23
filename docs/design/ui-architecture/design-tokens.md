# Swift / Tauri 共通デザイントークン

## 1. 目的

Swift/macOS と Tauri/React の共通 UI を変更するときに参照する、視覚上の基準値と意味の対応を定義する。値の共有はコード生成で同期せず、各プラットフォームの既存の仕組みを正本として保守する。

共通トークンは、どちらの UI でも同じ役割を持つ値だけを対象にする。キャンバス上の注釈、PDF 出力、OS 固有の material など、機能やプラットフォームに固有の値は各 feature の定義を正本とする。

## 2. 定義場所

| 役割 | Swift/macOS | Tauri/React |
| --- | --- | --- |
| semantic color | `LeatherColors` | `:root` の色変数と `prefers-color-scheme: dark` |
| 文字階層 | `LeatherDesignMetrics.Typography` | `--font-size-*` / `--font-weight-*` |
| 余白 | `LeatherDesignMetrics.Spacing` | `--space-*` |
| 角丸 | `LeatherDesignMetrics.Radius` | `--control-radius` / `--card-radius` / `--radius-pill` |
| 操作部品の高さ | `LeatherDesignMetrics.Control` | `--control-height` / `--control-compact-height` |
| アイコン寸法 | `LeatherDesignMetrics.Icon` | `--icon-size-*` |
| 境界 | `LeatherDesignMetrics.Border` | `--border-width-*` と `--panel-stroke` |
| 影 | OS の標準表示または feature の View | `--panel-shadow` と feature 固有の影 |

Swift側の共通表示部品は `apps/macos/KawaCAD/Sources/KawaCADApp/Shared/Components/DesignSystem.swift` に、Tauri側の共通変数は `apps/tauri/KawaCAD/src/app/styles.css` の `:root` に置く。

## 3. 色と外観モード

- Swift は `NSColor.windowBackgroundColor`、`controlBackgroundColor`、`labelColor` などの semantic color を `LeatherColors` から参照する。light/dark と active/inactive window の解決は AppKit に委譲する。
- Tauri は `:root` の light 値を基準にし、`prefers-color-scheme: dark` で semantic role ごとの値を切り替える。ブラウザ内の focus 状態は `:focus-visible` で扱う。
- 両版で見た目の RGB 値を完全一致させることは目的にしない。背景、本文、補助文、選択、警告、破壊的操作などの役割を対応させる。

## 4. 変更ルール

1. 既存の共通トークンに該当する値は、feature 側へ新しい固定値を追加せず、対応するトークンを参照する。
2. feature 固有の値を共通化する場合は、複数画面で同じ役割を持つかを確認する。キャンバス描画や出力形式の精度に関わる値は無理に移動しない。
3. Swift と Tauri の値を変更するときは、対応する両方の定義、`visualStyleContracts`、Swift のデザイントークンテストを更新する。
4. 新しい token を追加したときは、本書の表に役割を追加し、利用側が参照すべき定義場所を明確にする。

## 5. 対応値

| Swift | Tauri | 用途 |
| --- | --- | --- |
| `Spacing.panel = 16` | `--space-panel: 16px` | パネルの基本内側余白 |
| `Radius.control = 6` | `--control-radius: 6px` | ボタン、入力、選択 UI |
| `Radius.card = 8` | `--card-radius: 8px` | カード、浮動パネル |
| `Typography.body = 13` | `--font-size-body: 13px` | 通常 UI の本文 |
| `Typography.label = 11` | `--font-size-label: 11px` | 補助ラベル |
| `Icon.toolbar = 22` | `--icon-size-toolbar: 22px` | 上部ツールバーのアイコン枠 |
| `Icon.palette = 15` | `--icon-size-palette: 15px` | ツールパレットのアイコン |
| `Control.height = 24` | `--control-height: 24px` | 標準操作部品 |
| `Border.hairline = 1` | `--border-width-hairline: 1px` | 通常の境界線 |
