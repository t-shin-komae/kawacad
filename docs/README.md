# ドキュメントガイド

`docs/`は、各文書の責務ごとに整理されています。製品の振る舞いを実装詳細なしで読めるように外部契約と内部設計を分離し、設計上の判断は開発者が参照できるようにしています。

`docs/old/`は過去の資料であり、現在のドキュメント体系には含まれません。

## 構成

| パス | 責務 |
| --- | --- |
| [`spec/`](spec/) | 外部動作、ファイル形式、UI/UX契約 |
| [`design/`](design/) | アーキテクチャ、内部境界、機能領域の設計 |
| [`glossary.md`](glossary.md) | プロジェクト共通の用語 |
| [`backlog/`](backlog/) | 未解決の論点と将来の対象 |

外部仕様書は、ユーザーが観測できる内容を定義します。設計文書は、所有関係、境界、データフロー、設計上の不変条件を説明します。用語集は、複数の文書で使われる用語を定義します。バックログ文書は、現在の製品契約ではありません。

## 読む順序

1. このページ
2. 製品の振る舞いは[`spec/functional-spec.md`](spec/functional-spec.md)
3. 操作と表示は[`spec/ui-ux-spec.md`](spec/ui-ux-spec.md)
4. `.kawa`は[`spec/file-format-spec.md`](spec/file-format-spec.md)
5. システム概要は[`design/architecture.md`](design/architecture.md)
6. UI/Core契約は[`design/internal-interface-spec.md`](design/internal-interface-spec.md)
7. 対象となる機能領域の設計文書
8. 共通用語を確認する場合は[`glossary.md`](glossary.md)
9. 未決定事項や将来の対象を調査する場合のみ[`backlog/`](backlog/)

## 更新先の責務

- 観測可能な製品動作の変更は`spec/functional-spec.md`に記載します。
- 画面構成、操作、フィードバック、アクセシビリティの変更は`spec/ui-ux-spec.md`に記載します。
- `.kawa`の永続化や互換性の変更は`spec/file-format-spec.md`と該当するスキーマに記載します。
- UI/Core境界の変更は`design/internal-interface-spec.md`と該当するスキーマまたはfixtureに記載します。
- システムの所有関係、技術境界、主要フローの変更は`design/architecture.md`に記載します。
- 共通用語は`glossary.md`に記載します。
- 未決定事項や将来候補は`backlog/`に記載します。

文書には、現在の契約または継続的に有効な設計を記載します。一時的な作業計画、移行台帳、検証マトリクス、日付付きの調査記録は、現在のドキュメント体系には含めません。
