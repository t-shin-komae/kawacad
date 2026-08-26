# Shared components

Shared は、複数 feature が同じ表示上の意味で再利用する部品だけを置く。ドメイン固有の状態や action を Shared へ移さない。

| コンポーネント | Swift の実装 | 対応する Tauri 実装 | 役割 |
| --- | --- | --- | --- |
| DesignSystem | `Shared/Components/DesignSystem.swift` | `src/app/styles.css` / `InspectorPrimitives.tsx` | 色、寸法、Inspector の共通表示、ツール表示の定数を提供する。 |
| SyncedTextField | `Shared/Components/SyncedTextField.swift` | `src/shared/state/syncedField.ts` と各入力部品 | Core の最新値、編集中の値、競合、確定結果を区別する入力状態を提供する。 |
| TextEntryDialog | 操作箇所の `SyncedTextField` | `src/shared/components/TextEntryDialog.tsx` | 複数 feature が利用する汎用文字入力。macOS は操作箇所の入力 UI に内包する。 |
| Inspector primitives | `DesignSystem.swift` と Inspector component 内の共通 View | `src/shared/components/InspectorPrimitives.tsx` | セクション、展開行、編集面のレイアウトを揃える。 |

入力部品の更新規則は、ユーザー入力をすぐに Core へ送らず、検証に成功した値だけ action へ渡すことである。外部から新しい値が届いたとき、編集中でなければ表示を同期し、編集中なら競合として明示する。

