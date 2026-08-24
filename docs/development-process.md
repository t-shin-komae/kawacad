# 開発プロセス

KawaCADのIssue作成からリリースまでの進め方を定めます。

## Issue

変更の目的と概要を記載し、次のラベルを付けます。

| ラベル          | 用途                    |
| --------------- | ----------------------- |
| `enhancement`   | 機能追加、変更、改善    |
| `bug`           | 不具合の修正            |
| `documentation` | 文書のみの変更          |
| `manual_test`   | Milestone末の手動テスト |

検討の経過はIssueのコメントに残します。確定した外部仕様や設計は、`docs/spec/`または`docs/design/`へ反映します。

## Milestone

- リリース予定が決まったIssueは、`v0.x.y`形式のMilestoneに登録します。
- Milestoneの説明には、そのバージョンで導入する主な機能を記載します。
- リリース時期が未定のIssueは、`backlog`に登録します。予定が決まった時点で対象のMilestoneへ移します。

## ブランチ

作業ブランチは`main`から作成します。

| 種別                 | 名前                               |
| -------------------- | ---------------------------------- |
| 機能追加、変更、改善 | `feature/<概要>-issue-<Issue番号>` |
| 不具合修正           | `bugfix/<概要>-issue-<Issue番号>`  |
| 文書のみの変更       | `docs/<概要>-issue-<Issue番号>`    |

作業ブランチは短期間で完了させ、マージ後に削除します。当面はリリース用ブランチを作成しません。

## Pull Request

- `main`への直接pushは禁止し、作業ブランチからPull Requestを作成します。
- タイトルには、対応するIssue番号を含めます。
- 本文には、変更概要、確認内容、`Closes #123`のようなIssueを閉じる記述を含めます。
- UIを変更した場合は、Draft Pull Requestを作成して番号を確定した後、PR単位のローカル比較レポートを生成します。作業完了時に、依頼者へレポートの場所、差分の要点、比較対象を報告します。
- Before / Afterは、画面サイズ、テーマ、表示内容、拡大率を揃えて撮影します。画面全体ではなく、差分を判断できるコンポーネント単位で構いません。
- CIが成功したことを確認してから、Squashマージします。

比較成果物はGit管理外の`test-results/ui-reviews/pr-<PR番号>/`へ保存します。`before/`と`after/`に画像と撮影元commitを保存し、`index.html`では画像ファイルの内容が異なるものと、片側だけに存在するものだけを横並びと重ね合わせで確認できます。完全一致した画像はレポートから除外し、除外件数だけを表示します。保存先はGitの共通ディレクトリから決めるため、複数worktreeから同じ場所を参照でき、PR番号の異なる画像を上書きしません。

固定シナリオを撮影する場合は、作業ブランチを切り替えず、基準revisionのworktreeを指定して次を実行します。`--variant`には`all`、`tauri`、`swift`を指定できます。再撮影時は、指定した側とvariantの古い画像を削除してから撮影するため、廃止・改名したシナリオも片側だけの差分として検出されます。

```bash
node scripts/ui-review.mjs capture --pr 123 --side before --source-root /path/to/base-worktree
node scripts/ui-review.mjs capture --pr 123 --side after
```

2回目の撮影後、`test-results/ui-reviews/pr-123/index.html`を開いて差のある画像だけを確認します。固定シナリオにないコンポーネントは、同じファイル名の画像を各`screenshots/`へ追加し、`node scripts/ui-review.mjs report --pr 123`でレポートを再生成します。レビューでは、仕様どおりの差分か、意図しないレイアウト崩れがないか、Before / Afterの条件が揃っているかを確認します。

## 手動テスト

テストは可能な限り自動化します。自動化できない確認だけを手動テストの対象とし、Milestone末にまとめて実施します。

`v0.2.0`以降は、各Milestoneに`manual_test`ラベルのIssueを1件作成します。テスト項目はIssue本文のチェックリストにまとめ、確認条件、手順、期待結果、対象環境、結果を記載します。項目を追加した場合はコメントに経過を残し、本文にも反映します。

手動テストは、Milestone内のすべての`bug`と`enhancement`が完了してから、Milestone末に1回実施します。不合格の場合は同じMilestoneに`bug` Issueを作成し、修正後に不合格項目と影響範囲を再確認します。すべての項目が合格したら、手動テスト用Issueを完了します。

```mermaid
stateDiagram-v2
    state "開発中" as Development
    state "手動テスト" as ManualTest
    state "修正中" as Fixing
    state "完了" as Completed
    [*] --> Development
    Development --> ManualTest: bugとenhancementが完了
    ManualTest --> Fixing: 不合格
    Fixing --> ManualTest: 修正完了
    ManualTest --> Completed: すべて合格
```

## タグ

Milestone内のIssueがすべて完了し、Pull Requestのマージと`main`のCI成功を確認した後、`main`にMilestoneと同じ`v0.x.y`形式のタグを付けます。
