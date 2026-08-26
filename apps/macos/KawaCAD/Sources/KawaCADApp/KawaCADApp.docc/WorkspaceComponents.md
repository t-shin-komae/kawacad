# Workspace components

ワークスペース部品は、キャンバス、ツールパレット、Inspector、下部サマリーを画面に配置する。パネル幅や compact 表示はプレゼンテーション状態として UI が所有する。

| コンポーネント | Swift の実装 | 対応する Tauri 実装 | 役割 |
| --- | --- | --- | --- |
| WorkspaceCanvasLayout | `Features/Workspace/Components/WorkspaceCanvasLayout.swift` | `WorkspaceCanvasLayout.tsx` | 利用可能幅に応じてキャンバス列と Inspector 列を配置する。 |
| WorkspaceCanvasSurface | `Features/Workspace/Components/WorkspaceCanvasSurface.swift` | `WorkspaceCanvasSurface.tsx` | キャンバス本体と一時オーバーレイの積層順を管理する。 |
| PanelResizeHandle | `Features/Workspace/Components/PanelResizeHandle.swift` | `PanelResizeHandle.tsx` | パネル幅のドラッグ変更とキーボード操作を提供する。 |
| BottomWorkbench | `Features/Workspace/Components/BottomWorkbench.swift` | `BottomWorkbench.tsx` | 選択図形、拘束、レイヤー、パラメータの要約を表示する。 |
| WorkspaceBanners / AppErrorBanner | `Features/Workspace/Components/WorkspaceBanners.swift` / `AppErrorBanner.swift` | `WorkspaceBanners.tsx` / `AppErrorBanner.tsx` | アプリエラーと復旧保存失敗をキャンバス上部へ通知する。 |
