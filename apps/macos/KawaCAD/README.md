# KawaCAD macOS UI

## DocC

Swift/macOS の UI コンポーネントは `Sources/KawaCADApp/KawaCADApp.docc` に DocC カタログとして整理しています。ローカル HTML を生成するには、Xcode の Developer Toolchain を選択した状態で次を実行します。

```bash
cd apps/macos/KawaCAD
xcrun docc convert Sources/KawaCADApp/KawaCADApp.docc \
  --output-path .build/docc \
  --fallback-display-name KawaCADApp \
  --fallback-bundle-identifier com.kawacad.app \
  --transform-for-static-hosting
```

DocC の HTML は `file://` で直接開かず、生成物のルートを HTTP で配信します。

```bash
python3 -m http.server 8000 --directory .build/docc
```

ブラウザで <http://127.0.0.1:8000/documentation/kawacadapp/> を開いてください。`Ctrl-C` でサーバーを停止できます。

## ComponentGallery

SwiftUI の部品を実際に描画して確認する場合は、Core を起動しないギャラリーを実行します。

```bash
swift run KawaCAD --component-gallery
```

通常のアプリと同じ target に含め、fixture の state で既存コンポーネントを再利用しています。Core や AppKit の実行時状態が必要な部品は、ギャラリー内の `Core-bound components` に対応状況を表示します。

カタログは表示コンポーネントの責務と Swift/Tauri の対応を扱います。外部仕様は [`docs/spec/`](../../../docs/spec/)、対応表は [`component-correspondence.md`](../../../docs/design/ui-architecture/component-correspondence.md) を参照してください。
