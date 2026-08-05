# KawaCAD

> **WIP:** KawaCADは現在開発中で、実用段階にはありません。仕様や実装は今後変更される可能性があります。

KawaCADは、レザークラフトの型紙制作を目的としたmacOS中心のパラメトリック2D CADです。

現在の製品は、拘束付き自由作図、派生ジオメトリ、レザークラフトの意味情報、複数パーツの型紙管理、`.lcraft`永続化、A4実寸PDF出力およびmacOS直接印刷を提供します。

## ドキュメント

まず[`docs/README.md`](docs/README.md)を読み、そこに記載された順序に従ってください。外部仕様は`docs/spec/`、設計契約は`docs/design/`、機械可読な`.lcraft`およびUI/Core契約は`schemas/`にあります。

## ビルドと実行

SwiftパッケージはmacOS 13以降に対応しています。完全なXcode環境とRustツールチェーンが必要です。

```sh
cargo build -p kawacad-core-process
swift build --package-path apps/macos/KawaCAD
KAWACAD_CORE_PROCESS="$PWD/target/debug/kawacad-core-process" \
  swift run --package-path apps/macos/KawaCAD KawaCAD
```

実行可能なアプリケーションバンドルを作成するには、次を実行します。

```sh
node scripts/kawacad.mjs release --platform macos --variant all
```

releaseパッケージの作成方法と、実際のCoreを使った結合テストについては[`scripts/README.md`](scripts/README.md)を参照してください。

## ローカルチェック

必要に応じて、リポジトリのチェックを個別に実行できます。

```sh
cargo fmt --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
swift test --package-path apps/macos/KawaCAD
```

ローカルのpre-commitチェックをまとめて実行するには、次を使います。

```sh
node scripts/kawacad.mjs pre-commit
```

リポジトリ管理のGit hookは、pre-commitチェックとmacOS上のSwift pre-push検証を同じCLIから実行します。インストールするには、次を実行します。

```sh
git config core.hooksPath .githooks
```

Pull Request、GitHub Actions CI、pre-push検証の運用は[`CONTRIBUTING.md`](CONTRIBUTING.md)を参照してください。
