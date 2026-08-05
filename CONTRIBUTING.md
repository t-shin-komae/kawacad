# Contributing to KawaCAD

## 開発環境

Node.jsは`.node-version`の24.18.0、Rustは`rust-toolchain.toml`の1.97.1を使用します。Swift開発とpre-push検証にはmacOS、Xcode 26.6、Swift 6.3系が必要です。Tauri依存関係は次のコマンドで導入します。

```sh
npm ci --prefix apps/tauri/KawaCAD
```

## Git hooks

clone後に一度、リポジトリ管理のGit hookを有効にします。

```sh
git config core.hooksPath .githooks
```

pre-commitはformat、lint、型検査を実行します。pre-pushはmacOS専用で、Swift format、実Core processを使う通常・結合テスト、Swift版の署名なしrelease buildとアプリbundleの組み立てを検証します。

各hookは次のコマンドで手動再現できます。

```sh
node scripts/kawacad.mjs pre-commit
node scripts/kawacad.mjs pre-push
```

Swift検証はGitHub Actionsでは実行されないため、push時にpre-pushを迂回しないでください。

## GitHub Actions CI

CIは`pull_request`、`main`へのpush、`workflow_dispatch`で実行します。PR更新時は同じPRの古い実行をキャンセルします。

- `linux-quality-core`: format、lint、型検査、automation CLIテスト、Rust Core系テスト
- `linux-tauri`: React/Vitest、Tauri Rust adapter、Playwright E2E、Linux向けrelease build
- `ci-gate`: 2つのLinuxジョブが成功した場合だけ成功する統合チェック

Playwrightのtraceは失敗時だけ7日間保存します。CIは`contents: read`権限のみを持ち、秘密情報、署名証明書、`pull_request_target`を使用しません。

## Pull Request運用

`main`へ直接pushせず、Pull Requestを作成します。`ci-gate`の成功と未解決会話がないことをマージ条件とし、人のレビュー承認は必須にしません。

private repositoryをGitHub Freeで運用する間、この条件とpre-push実行は運用規約です。GitHub側で強制できるプランへ移行した場合は、`main`にPR必須、`ci-gate`必須、最新`main`への追従、会話解決、force-push・削除禁止、承認0名のrulesetを設定します。
