# Component Gallery

`ComponentGalleryView` は、SwiftUI の表示コンポーネントを実行時に確認するための macOS 用カタログである。Storybook のようにページを切り替えながら、選択状態や入力状態を含む部品を実際に描画する。

## 起動

```bash
cd apps/macos/KawaCAD
swift run KawaCAD --component-gallery
```

ギャラリーは `AppCoordinator` と Core プロセスを初期化しない。各ページの fixture が表示用 state と action を提供するため、部品のレイアウトや操作を安全に確認できる。

## ページ

- **Canvas** — `CADToolbar`、`ToolPalette`、ツールアイコン
- **Workspace** — `DocumentHeader`、`CanvasStatusBar`、パネル共通部品
- **Inspector** — `InspectorSection`、`InspectorDisclosureRow`、`SyncedTextField`
- **Feedback** — recovery banner、error banner、save confirmation
- **Core-bound components** — Core、実文書、または AppKit の実行時状態が必要な部品の対応状況

Canvas ページの `Content width` を変更すると、`CADToolbar` は実アプリと同じ `ViewThatFits` により expanded / condensed を切り替える。`Tool palette` の幅も独立して変更できる。

Core-bound の部品は、実行可能な状態を無理に複製せず、通常のアプリと既存の UI テストで確認する。新しい表示部品を追加したときは、独立した fixture を作れるかを確認し、必要な場合だけこのギャラリーにページまたはカードを追加する。
