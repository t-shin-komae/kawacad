# Document components

ドキュメント領域は、ファイルや Core の確定状態に対する操作の入口を表示する。名前編集などの入力途中状態は UI に保持し、確定時に action へ渡す。

| コンポーネント | Swift の実装 | 対応する Tauri 実装 | 役割 |
| --- | --- | --- | --- |
| MainWindowView | `App/MainWindowView.swift` | `src/app/MainWindowView.tsx` | UI の表示ルートと feature / adapter の組み立て。 |
| DocumentHeader | `Features/Document/Components/DocumentHeader.swift` | `src/features/document/components/DocumentHeader.tsx` | プロジェクト名、ファイル形式、用紙情報を表示し、名前変更を確定する。 |
| DocumentSaveConfirmationDialog | `Features/Document/Components/DocumentSaveConfirmationDialog.swift` | `DocumentSaveConfirmationDialog.tsx` | 保存、破棄、キャンセルを選択させる。 |
| LayerDeletionDialog | `Features/Document/Components/LayerDeletionDialog.swift` | `LayerDeletionDialog.tsx` | レイヤー削除の影響を示し、明示的な確認を受ける。macOS は `confirmationDialog` を使う。 |
| PasteOptionsOverlay | `Features/Document/Components/PasteOptionsOverlay.swift` | `PasteOptionsOverlay.tsx` | 貼り付け位置をカーソルまたは元位置付近から選び、1 回の配置を完了する。 |

ドキュメントの確定状態、Undo / Redo 履歴、ファイル入出力は Rust Core と adapter の責務である。表示コンポーネントは成功した結果を受け取って更新する。

