# Swift / Tauri UI コンポーネント対応表

## 1. 目的

本書は、同じ利用者向け責務を担う Swift/macOS と Tauri/React の UI コンポーネントを、現行実装から相互に探すための索引である。同じ行にある実装は責務上の対応を示し、型、ライフサイクル、内部構造が一致することは意味しない。

外部から観測できる振る舞いは [`docs/spec/ui-ux-spec.md`](../../spec/ui-ux-spec.md)、UI 内の責務分割と状態所有は [`overview.md`](overview.md) を正とする。本書は表示コンポーネントを対象とする。action、state、selector、adapter の対応は網羅せず、表示責務の一部がコンポーネント以外に置かれている場合だけ併記する。

共通の色、文字、余白、操作部品、アイコン、境界、影は [`design-tokens.md`](design-tokens.md) を参照する。

対応関係は次のように表記する。

| 表記 | 意味 |
| --- | --- |
| 1対1 | おおむね同じ粒度で同じ表示責務を持つ |
| 分割 | 一方の責務を他方では複数コンポーネントへ分けている |
| 統合 | 一方の独立コンポーネント相当を他方では親コンポーネントに内包している |
| 部分対応 | 責務の一部だけが対応し、対象範囲が異なる |
| プラットフォーム固有 | OS 標準 UI や利用可能機能の違いにより実装形態が異なる |
| 対応なし | 一方だけが独立した共通コンポーネントを持つ |

## 2. ワークスペースとキャンバス

| 論理コンポーネント | Swift/macOS | Tauri/React | 対応 |
| --- | --- | --- | --- |
| アプリの表示ルート | [`MainWindowView`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/App/MainWindowView.swift) | [`MainWindowView`](../../../apps/tauri/KawaCAD/src/app/MainWindowView.tsx) | 1対1。Swift は監視用の子 View を持ち、Tauri は React hooks を同じルートで購読する |
| レスポンシブなワークスペース配置 | [`WorkspaceCanvasLayout`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Workspace/Components/WorkspaceCanvasLayout.swift) | [`WorkspaceCanvasLayout`](../../../apps/tauri/KawaCAD/src/features/workspace/components/WorkspaceCanvasLayout.tsx) | 1対1 |
| CAD ツールバー | [`CADToolbar`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Canvas/Components/CADToolbar.swift) | [`CADToolbar`](../../../apps/tauri/KawaCAD/src/features/canvas/components/CadToolbar.tsx) | 1対1 |
| ツールパレット | [`ToolPalette`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Canvas/Components/ToolPalette.swift) | [`ToolPalette`](../../../apps/tauri/KawaCAD/src/features/canvas/components/ToolPalette.tsx) | 1対1 |
| ツールアイコンとパレットボタン | [`ToolIcon` / `PaletteToolButton`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Shared/Components/DesignSystem.swift) | [`ToolIcon`](../../../apps/tauri/KawaCAD/src/features/canvas/components/ToolIcon.tsx) / [`PaletteToolButton`](../../../apps/tauri/KawaCAD/src/features/canvas/components/ToolPalette.tsx) | 1対1 |
| パネル幅の変更ハンドル | [`PanelResizeHandle`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Workspace/Components/PanelResizeHandle.swift) | [`PanelResizeHandle`](../../../apps/tauri/KawaCAD/src/features/workspace/components/PanelResizeHandle.tsx) | 部分対応。Swift はツールパレットとインスペクタ、Tauri はツールパレットに使用する |
| キャンバスと一時オーバーレイの配置 | [`WorkspaceCanvasSurface`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Workspace/Components/WorkspaceCanvasSurface.swift) | [`WorkspaceCanvasSurface`](../../../apps/tauri/KawaCAD/src/features/workspace/components/WorkspaceCanvasSurface.tsx) | 1対1 |
| キャンバス描画と入力 | [`CADCanvas`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Canvas/Components/CADCanvas.swift) | [`CADCanvas`](../../../apps/tauri/KawaCAD/src/features/canvas/components/CadCanvas.tsx) | 1対1。Swift の内部描画は `LeatherCanvasView`、Tauri は `canvasRendering` へ委譲する |
| キャンバス内テキスト編集 | [`CanvasInlineTextEditorController`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Canvas/Components/CanvasInlineTextEditorController.swift) と `LeatherCanvasView.InlineEditor` | `CADCanvas` 内の `canvas-inline-text-editor` | 統合。Tauri は `CADCanvas` 内の input として表示する |
| キャンバスのコンテキストメニュー | [`CanvasContextMenu` のモデル](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Canvas/Components/CanvasContextMenu.swift) と `LeatherCanvasView` の `NSMenu` | [`CanvasContextMenu`](../../../apps/tauri/KawaCAD/src/features/canvas/components/CanvasContextMenu.tsx) | プラットフォーム固有。Swift は AppKit のネイティブメニューを使う |
| 貼り付け位置の選択 | [`PasteOptionsOverlay`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Document/Components/PasteOptionsOverlay.swift) | [`PasteOptionsOverlay`](../../../apps/tauri/KawaCAD/src/features/document/components/PasteOptionsOverlay.tsx) | 1対1 |
| 下部サマリー | [`BottomWorkbench`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Workspace/Components/BottomWorkbench.swift) | [`BottomWorkbench`](../../../apps/tauri/KawaCAD/src/features/workspace/components/BottomWorkbench.tsx) | 1対1 |
| ステータスバー | [`CanvasStatusBar`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Canvas/Components/CanvasStatusBar.swift) | [`CanvasStatusBar`](../../../apps/tauri/KawaCAD/src/features/canvas/components/CanvasStatusBar.tsx) | 1対1 |

## 3. インスペクタ

| 論理コンポーネント | Swift/macOS | Tauri/React | 対応 |
| --- | --- | --- | --- |
| インスペクタの配置とタブ本体 | [`WorkspaceInspector`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Inspector/Components/WorkspaceInspector.swift) / [`InspectorPanel`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Inspector/Components/InspectorPanel.swift) | [`WorkspaceInspector`](../../../apps/tauri/KawaCAD/src/features/inspector/components/WorkspaceInspector.tsx) / [`InspectorPanel`](../../../apps/tauri/KawaCAD/src/features/inspector/components/InspectorPanel.tsx) | 1対1 |
| セクションと展開行 | [`InspectorSection`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Shared/Components/DesignSystem.swift) / [`InspectorDisclosureRow`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Inspector/Components/InspectorSelectionEditors.swift) | [`InspectorSection` / `InspectorDisclosureRow`](../../../apps/tauri/KawaCAD/src/shared/components/InspectorPrimitives.tsx) | 1対1 |
| 選択中の拘束 | [`SelectedConstraintEditor`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Inspector/Components/InspectorSelectionEditors.swift) | [`SelectedConstraintEditor`](../../../apps/tauri/KawaCAD/src/features/inspector/components/InspectorSelectionEditors.tsx) | 1対1 |
| 選択中の計測表示、縫い始め点 | [`SelectedMeasurementEditor` / `SelectedStitchStartPointEditor`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Inspector/Components/InspectorSelectionEditors.swift) | [`SelectedMeasurementEditor` / `SelectedStitchStartPointEditor`](../../../apps/tauri/KawaCAD/src/features/inspector/components/InspectorSelectionEditors.tsx) | 1対1 |
| 自由テキスト編集 | [`FreeTextEditor`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Inspector/Components/InspectorSelectionEditors.swift) | [`FreeTextEditor`](../../../apps/tauri/KawaCAD/src/features/inspector/components/InspectorSelectionEditors.tsx) | 1対1 |
| 複数選択サマリー | [`MultiSelectionSummary`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Inspector/Components/InspectorSelectionEditors.swift) | [`MultiSelectionSummary`](../../../apps/tauri/KawaCAD/src/features/inspector/components/InspectorSelectionEditors.tsx) | 1対1 |
| 図形、派生要素、丸穴の編集 | [`EntityEditor` / `DerivedElementEditor` / `RoundHoleEditor` / `EntityGeometryEditor`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Inspector/Components/InspectorSelectionEditors.swift) | [`EntityEditor` / `DerivedElementEditor` / `RoundHoleEditor` / `EntityGeometryEditor`](../../../apps/tauri/KawaCAD/src/features/inspector/components/InspectorSelectionEditors.tsx) | 1対1 |
| レイヤータブ | [`InspectorLayerTab`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Inspector/Components/InspectorLayerTab.swift) | [`InspectorLayerTab`](../../../apps/tauri/KawaCAD/src/features/inspector/components/InspectorLayerTab.tsx) | 1対1 |
| 共有スタイルタブ | [`InspectorStylesTab`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Inspector/Components/InspectorStylesTab.swift) | [`InspectorStylesTab`](../../../apps/tauri/KawaCAD/src/features/inspector/components/InspectorStylesTab.tsx) | 1対1 |
| パラメータタブと編集 | [`InspectorParametersTab`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Inspector/Components/InspectorParametersTab.swift) / [`ParameterEditor`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Inspector/Components/InspectorEditors.swift) | [`InspectorParametersTab`](../../../apps/tauri/KawaCAD/src/features/inspector/components/InspectorParametersTab.tsx) / [`ParameterEditor`](../../../apps/tauri/KawaCAD/src/features/inspector/components/InspectorSelectionEditors.tsx) | 1対1 |
| パーツタブとパーツ編集 | [`InspectorPartsTab`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Inspector/Components/InspectorPartsTab.swift) / [`PartEditor`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Inspector/Components/InspectorSelectionEditors.swift) | [`InspectorPartsTab`](../../../apps/tauri/KawaCAD/src/features/parts/components/InspectorPartsTab.tsx) / [`PartEditor`](../../../apps/tauri/KawaCAD/src/features/parts/components/InspectorPartEditors.tsx) | 1対1 |

## 4. ダイアログ、シート、バナー

| 論理コンポーネント | Swift/macOS | Tauri/React | 対応 |
| --- | --- | --- | --- |
| 拘束値、オフセット値、フィレット半径の入力 | [`ConstraintValueDialog` / `DerivedValueDialog`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Constraints/Components/ValueEntryDialogs.swift) | [`ConstraintValueDialog`](../../../apps/tauri/KawaCAD/src/features/constraints/components/ConstraintValueDialog.tsx) / [`DerivedValueDialog`](../../../apps/tauri/KawaCAD/src/features/constraints/components/DerivedValueDialog.tsx) | 1対1 |
| 未保存ドキュメントの確認 | [`DocumentSaveConfirmationDialog`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Document/Components/DocumentSaveConfirmationDialog.swift) | [`DocumentSaveConfirmationDialog`](../../../apps/tauri/KawaCAD/src/features/document/components/DocumentSaveConfirmationDialog.tsx) | 1対1 |
| レイヤー削除の確認 | [`LayerDeletionDialog`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Document/Components/LayerDeletionDialog.swift) | [`LayerDeletionDialog`](../../../apps/tauri/KawaCAD/src/features/document/components/LayerDeletionDialog.tsx) | プラットフォーム固有。Swift は `ViewModifier` でネイティブの `confirmationDialog` を使う |
| 復旧候補の選択 | [`RecoveryChooserDialog`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Recovery/Components/RecoveryChooserDialog.swift) | [`RecoveryChooserDialog`](../../../apps/tauri/KawaCAD/src/features/recovery/components/RecoveryChooserDialog.tsx) | 1対1 |
| 復旧保存失敗の通知 | [`RecoverySaveFailureBanner`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Recovery/Components/RecoverySaveFailureBanner.swift) | [`RecoverySaveFailureBanner`](../../../apps/tauri/KawaCAD/src/features/recovery/components/RecoverySaveFailureBanner.tsx) | 1対1 |
| バナーの配置 | [`WorkspaceBanners`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Workspace/Components/WorkspaceBanners.swift) | [`WorkspaceBanners`](../../../apps/tauri/KawaCAD/src/features/workspace/components/WorkspaceBanners.tsx) | 1対1 |
| アプリエラーの通知 | [`AppErrorBanner`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Workspace/Components/AppErrorBanner.swift) | [`AppErrorBanner`](../../../apps/tauri/KawaCAD/src/features/workspace/components/AppErrorBanner.tsx) | 1対1 |
| PDF 出力と直接印刷 | [`OutputDialog`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/Features/Output/Components/OutputDialog.swift) | [`OutputDialog`](../../../apps/tauri/KawaCAD/src/features/output/components/OutputDialog.tsx) | 1対1。Tauri は出力先別の子ダイアログへ分ける |
| OSS ライセンス | [`OpenSourceLicensesDialog`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/App/KawaCADLicensesPanel.swift) | [`OpenSourceLicensesDialog`](../../../apps/tauri/KawaCAD/src/features/licenses/components/OpenSourceLicensesDialog.tsx) | プラットフォーム固有。Swift は独立した AppKit panel に載せる |
| About 画面 | [`KawaCADAboutPanel`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/App/KawaCADAboutPanel.swift) | [`nativeMenuAdapter` の定義済み About 項目](../../../apps/tauri/KawaCAD/src/adapters/nativeMenuAdapter.ts) | プラットフォーム固有。どちらも OS のネイティブ About UI を使う |
| 汎用文字入力モーダル | 操作箇所ごとの `SyncedTextField` またはキャンバス内編集 | [`TextEntryDialog`](../../../apps/tauri/KawaCAD/src/shared/components/TextEntryDialog.tsx) | 対応なし。Tauri だけが複数 feature 用の共通モーダルを持つ |

## 5. 対応表の更新規則

- 利用者向け責務が同じなら、ファイル名が異なっても同じ行へ置く。
- 一方だけに独立コンポーネントがある場合は、他方でその責務を内包する親を記載する。
- action、state、selector、adapter の対応は本表へ網羅的に追加しない。
- UI の振る舞いを変更した場合は先に外部仕様を更新し、本表は実装上の入口が変わったときだけ更新する。
