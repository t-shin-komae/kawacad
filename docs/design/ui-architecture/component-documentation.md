# UI コンポーネントドキュメント

Swift/macOS と Tauri/React の表示コンポーネントは、実装言語ごとのドキュメントツールで確認できるようにする。

| UI | ツール | 入口 | 主な用途 |
| --- | --- | --- | --- |
| Swift/macOS | DocC + ComponentGallery | [`KawaCADApp.docc`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/KawaCADApp.docc/) / [`ComponentGalleryView.swift`](../../../apps/macos/KawaCAD/Sources/KawaCADApp/App/ComponentGalleryView.swift) | feature ごとの責務、状態の流れ、実際の部品描画 |
| Tauri/React | Storybook | [`src/stories/ComponentCatalog.stories.tsx`](../../../apps/tauri/KawaCAD/src/stories/ComponentCatalog.stories.tsx) | コンポーネント対応表、入力境界、独立部品のライブ例 |

## 対象範囲

`docs/design/ui-architecture/component-correspondence.md` の表示責務を対象とする。action、state、selector、adapter の全ファイルを Storybook の画面として公開することはしない。Core スナップショットや OS サービスを必要とするコンポーネントは、Storybook では責務と実装入口を表示し、既存のテストと実アプリで動作を検証する。

独立した共通部品と入力ダイアログには、Swift 側は `ComponentGalleryView`、React 側は Storybook で実際のコンポーネントを描画するライブ例も用意する。これにより、ドキュメント用のモックが製品の入力処理を再実装することを避ける。

## 更新規則

- コンポーネントの責務や対応実装を変更したら、DocC の該当表と Tauri の `componentCatalog.ts` を同じ変更で更新する。
- UI の利用者向け動作を変更した場合は、先に `docs/spec/ui-ux-spec.md` を更新する。
- コンポーネントの入力やアクセシビリティを変更した場合は、Storybook のライブ例または既存テストを更新する。
- Core や adapter の挙動を Storybook 用に簡略化しない。必要な状態は表示モデルとして固定し、実行時の副作用は adapter 境界の外へ出さない。
