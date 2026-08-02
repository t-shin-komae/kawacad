# KawaCAD 全体設計

## 1. 目的

本書は、機能別の設計文書を読む前に、KawaCAD 全体の構造と代表的な振る舞いを掴むための概略設計である。

次の3つの視点を分けて示す。

- **静的構造** — どの構成要素があり、何を所有・参照するか
- **動的構造** — ユーザー操作に対して、構成要素がどの順で協調するか
- **状態遷移** — 確定前、検証中、確定後、失敗時がどう移り変わるか

個別 API、型定義、アルゴリズム、画面レイアウトは扱わない。詳細な判断は各機能領域の設計文書、境界契約は `docs/design/internal-interface-spec.md`、保存形式は `docs/spec/file-format-spec.md` を正とする。

## 2. 設計の要点

| 観点     | 全体方針                                                                      |
| -------- | ----------------------------------------------------------------------------- |
| 正本     | 図形、拘束、パラメータ、パーツなどのドキュメント状態は Rust Core が所有する   |
| UI       | 表示、入力解釈、確定前の操作、OS 連携を担当する                               |
| 境界     | UI は操作の意図をコマンドとして送り、Core は確定済み状態またはエラーを返す    |
| 変更     | 1回のユーザー操作を原子的に適用し、失敗時は状態と履歴を変えない               |
| 保存     | 再現に必要なドキュメント状態だけを `.lcraft` に保存する                       |
| 出力     | Core がページ配置を確定し、共通の Output Engine から PDF と直接印刷を生成する |
| 機能拡張 | CAD 図形を基盤とし、派生要素、型紙の意味情報、パーツを上に重ねる              |

## 3. 静的構造

### 3.1 実行時コンポーネント

次の図は、アプリ実行中の主要な構成要素と責務境界を示す。

```plantuml
@startuml
top to bottom direction

skinparam shadowing false
skinparam componentStyle rectangle
skinparam packageStyle rectangle
skinparam linetype ortho

actor "ユーザー" as User

package "Swift/macOS アプリ" as SwiftApp {
  component "SwiftUI / AppKit UI\n表示・入力・操作中状態" as SwiftUI
  component "Core adapter\nプロセス起動・要求応答" as SwiftCoreAdapter
  component "OS adapter\nファイル選択・PDF保存・印刷" as SwiftOSAdapter

  SwiftUI -down- SwiftCoreAdapter
  SwiftUI -down- SwiftOSAdapter
}

package "別プロセス" as ProcessBoundary {
  component "kawacad-core-process\n1行1 JSON・要求の振り分け" as CoreProcess
}

package "Tauri/React アプリ" as TauriApp {
  component "React UI\n表示・入力・操作中状態" as ReactUI
  component "invoke adapter\n要求応答" as InvokeAdapter
  component "Tauri backend\nCore セッション・OS 連携" as TauriBackend

  ReactUI -down- InvokeAdapter
  InvokeAdapter -down- TauriBackend
}

package "共通の OS 非依存 Rust" as Rust {
  component "kawacad-core\n図形 / 拘束 / 履歴 / 保存" as Core
  component "Output Document Model\nページ分割済みの共通出力表現" as OutputModel
  component "Output Engine\n共通描画規則" as Engine

  Core -down-> OutputModel
  OutputModel -down-> Engine
}

artifact ".lcraft" as Lcraft
artifact "PDF" as PDF
node "macOS 印刷" as Printer

User -down-> SwiftUI
User -down-> ReactUI
SwiftCoreAdapter <--> CoreProcess : 標準入出力 JSON
CoreProcess <--> Core : コマンド / 状態
TauriBackend <--> Core : 同一プロセス内で直接呼び出し
Core <--> Lcraft : 保存 / 読み込み
Engine -down-> SwiftOSAdapter
SwiftOSAdapter -down-> PDF
SwiftOSAdapter -down-> Printer
@enduml
```

図の `kawacad-core` は両アプリが利用する共通実装を表し、実行時に同じセッションを共有することを意味しない。Swift/macOS は `kawacad-core-process` を別プロセスとして起動する。Tauri/React は別プロセスを起動せず、Tauri backend が同じアプリプロセス内で `kawacad-core` を呼び出す。両経路で要求・応答データの意味契約を共有する。

| 境界 | UI 側が決めること | 境界の先が決めること |
| --- | --- | --- |
| UI ↔ Core | 操作意図、表示方法、確定前状態 | 操作の成立可否、確定済み状態、履歴 |
| Swift adapter ↔ Core process | プロセスのライフサイクル、要求送信、応答受信 | JSON メッセージの解釈と Core 呼び出し |
| React UI ↔ Tauri backend | invoke の開始と応答の表示 | セッション保持、Core 呼び出し、OS 連携 |
| Core ↔ `.lcraft` | 保存・読み込みの意味 | JSON の検証可能な形状は Schema |
| Core ↔ Output Engine | 出力対象、ページ、位置、警告 | PDF / 印刷用データへの描画 |
| UI ↔ OS adapter | アプリ上の導線と判断 | ダイアログ、ウィンドウ、端末内データなどの副作用 |

### 3.2 ドメイン概念

最初の図は、`ProjectDocument` が所有する概念と、そこから導出する実行時情報を示す。

```plantuml
@startuml
top to bottom direction

skinparam shadowing false
skinparam packageStyle rectangle
skinparam linetype ortho
skinparam classAttributeIconSize 0
hide methods

class "ProjectDocument\nプロジェクトの正本" as ProjectDocument <<正本>>

package "CAD 基盤" as CAD {
  class "Layer\n表示・印刷・既定線スタイル" as Layer
  class "SharedStyle\n共有する線スタイル" as SharedStyle
  class "Entity\n点・線分・円・円弧・中心線" as Entity
  class "DerivedElement\nオフセット・フィレット" as DerivedElement
  class "Constraint\n幾何・寸法・固定" as Constraint
  class "Parameter\n名前付き寸法値" as Parameter

  Layer -[hidden]down- SharedStyle
  SharedStyle -[hidden]down- Entity
  Entity -[hidden]down- DerivedElement
  DerivedElement -[hidden]down- Constraint
  Constraint -[hidden]down- Parameter
}

package "型紙の意味情報・パーツ" as Pattern {
  class "RoundHole\n丸穴" as RoundHole
  class "StitchStartPoint\n縫い始め点" as StitchStartPoint
  class "FreeText\n自由テキスト" as FreeText
  class "MeasurementAnnotation\n計測表示" as MeasurementAnnotation
  class "DimensionConstraintAnnotation\n寸法拘束表示" as DimensionConstraintAnnotation
  class "Part\n外形・穴・所属・原点" as Part

  RoundHole -[hidden]down- StitchStartPoint
  StitchStartPoint -[hidden]down- FreeText
  FreeText -[hidden]down- MeasurementAnnotation
  MeasurementAnnotation -[hidden]down- DimensionConstraintAnnotation
  DimensionConstraintAnnotation -[hidden]down- Part
}

package "実行時・派生状態" as Runtime {
  class "OperationHistory\nUndo / Redo" as OperationHistory
  class "DrawingSnapshot\n編集表示状態" as DrawingSnapshot <<導出>>
  class "OutputDocumentModel\n出力ページ用" as OutputDocumentModel <<導出>>

  OperationHistory -[hidden]down- DrawingSnapshot
  DrawingSnapshot -[hidden]down- OutputDocumentModel
}

ProjectDocument *-down- CAD : 保存要素
ProjectDocument *-down- Pattern : 保存要素
ProjectDocument *-down- OperationHistory

DrawingSnapshot ..> ProjectDocument : 導出
OutputDocumentModel ..> ProjectDocument : 導出
@enduml
```

`CAD 基盤` と `型紙の意味情報・パーツ` の主要な関連は次の通り。中央の関連名は関係の意味、各端の多重度は許容件数を表す。

```plantuml
@startuml
top to bottom direction

skinparam shadowing false
skinparam packageStyle rectangle
skinparam linetype ortho
skinparam classAttributeIconSize 0
skinparam nodesep 100
skinparam ranksep 100
hide methods

package "型紙の意味情報・パーツ" as Pattern {
  class Part
  class RoundHole
  class StitchStartPoint
  class FreeText
  class MeasurementAnnotation
  class DimensionConstraintAnnotation

  Part -[hidden]down- FreeText
  FreeText -[hidden]down- MeasurementAnnotation
  MeasurementAnnotation -[hidden]down- RoundHole
  RoundHole -[hidden]down- StitchStartPoint
  StitchStartPoint -[hidden]down- DimensionConstraintAnnotation
}

package "CAD 基盤" as CAD {
  abstract class "GeometryElement\n<<概念>>" as GeometryElement
  class DerivedElement
  class Constraint
  class Entity
  class Parameter
  class Layer
  class SharedStyle

  DerivedElement -up-|> GeometryElement
  Entity -up-|> GeometryElement

  DerivedElement -[hidden]right- GeometryElement
  GeometryElement -[hidden]right- Entity
  Constraint -[hidden]right- Parameter
  Layer -[hidden]right- SharedStyle
  DerivedElement -[hidden]down- Constraint
  Constraint -[hidden]down- Layer
}

Part "0..1" --> "1..*" Entity : パーツ所属
Part "0..1" --> "0..*" DerivedElement : パーツ所属
Part "0..1" --> "0..*" FreeText : パーツ所属
Part "0..1" --> "0..*" MeasurementAnnotation : パーツ所属

RoundHole "0..*" --> "1" Entity : 丸穴用途
StitchStartPoint "0..*" --> "1" GeometryElement : 縫い線参照
MeasurementAnnotation "0..*" --> "1..*" Entity : 計測対象
DimensionConstraintAnnotation "0..1" --> "1" Constraint : 表示対象

DerivedElement "0..*" --> "1..*" GeometryElement : 派生元
DerivedElement "0..*" --> "0..1" Parameter : 値参照
Constraint "0..*" --> "1..*" Entity : 拘束対象
Constraint "0..*" --> "0..1" Parameter : 値参照

GeometryElement "0..*" --> "0..1" Layer : レイヤー所属
GeometryElement "0..*" --> "0..1" SharedStyle : スタイル適用
@enduml
```

多重度は、左端が1つの参照先から見た参照元の件数、右端が1つの参照元が保持できる参照先の件数を表す。図中の `GeometryElement` は保存オブジェクトではなく、`Entity` と `DerivedElement` に共通する関連端をまとめるための概念上の抽象である。

- `DerivedElement.sourceIds` は `Entity` または別の `DerivedElement` を1件以上参照する。`Fillet` では2件以上で、派生要素間の循環参照は禁止する。
- `StitchStartPoint.targetId` は `Entity` または `DerivedElement` のどちらか1件を参照する。
- `RoundHole` と `StitchStartPoint` のパーツ所属は参照先から導出し、`Part` 自体にはそれらの ID を保存しない。

関連端は `.lcraft` Schema、Rust の保存モデル、ドキュメント検証を照合している。特に次の非対称な多重度に注意する。

- `Part` は `Entity` を1件以上持つが、派生要素、自由テキスト、計測表示は0件でもよい。各要素は複数の `Part` に重複所属できないため、逆端は `0..1` となる。
- `Entity` と `DerivedElement` の `layerId`、`styleId` は任意であり、1要素から見た参照先は `0..1` となる。
- `Constraint.targets` と `MeasurementAnnotation.targets` は1件以上である。対象は通常図形またはその制御点であり、派生要素を直接参照しない。
- `DimensionConstraintAnnotation` は必ず1つの寸法拘束を参照し、同じ拘束に対する表示位置は最大1件である。
- `RoundHole` は必ず1つの円 `Entity` を参照する。現行モデルは同じ円を参照する丸穴用途の重複を禁止していないため、逆端は `0..*` とする。

この構造では、同じ座標や形状を用途別に重複保存しない。例えば、丸穴は円の座標を複製せず円図形を参照し、オフセット線は解決後の形状を正本にせず元図形と距離を参照する。

### 3.3 永続状態と一時状態

```plantuml
@startuml
left to right direction

skinparam shadowing false
skinparam packageStyle rectangle
skinparam linetype ortho
package ".lcraft に保存する" as Saved {
  rectangle "図形 / 拘束 / パラメータ" as Document
  rectangle "型紙の意味情報・パーツ" as Meaning
  rectangle "レイヤー / 共有スタイル" as Style
  rectangle "注釈の参照と配置" as AnnotationData
}

package "必要時に再生成する" as Derived {
  rectangle "自由度評価" as Dof
  rectangle "派生要素の解決形状" as Resolved
  rectangle "編集表示状態" as Snapshot
  rectangle "Output Document Model" as Output
}

package "UI だけが保持する" as UIOnly {
  rectangle "選択 / ハイライト" as Selection
  rectangle "ドラッグ / プレビュー" as Preview
  rectangle "ズーム / パン / パネル / シート" as Presentation
}

Saved --> Derived
@enduml
```

保存対象の境界は「再読み込み後にプロジェクトの意味を再現するために必要か」で決める。計算結果と UI の一時状態は保存しない。

## 4. 動的構造

### 4.1 編集コマンド

代表的な編集は、プレビューと確定を分け、Core での検証に成功した場合だけ履歴へ追加する。

```plantuml
@startuml
skinparam shadowing false
skinparam responseMessageBelowArrow true

actor "ユーザー" as User
participant "UI feature" as UI
participant "Core adapter" as Adapter
participant "Rust Core" as Core
participant "ProjectDocument" as Doc

    User->UI: クリック / ドラッグ / 値入力
    opt 確定前の候補表示が必要
        UI->Adapter: previewCommand
        Adapter->Core: preview request
        Core->Doc: 複製状態で検証・計算
        Core-->Adapter: プレビュー状態またはエラー
        Adapter-->UI: 候補表示
    end
    User->UI: 確定
    UI->Adapter: applyCommand
    Adapter->Core: command request
    Core->Doc: 参照・拘束・値を検証
    alt 成功
        Doc->Doc: 状態を原子的に更新
        Doc->Doc: 自由度と派生情報を再評価
        Doc->Doc: Undo / Redo 履歴へ追加
        Core-->Adapter: 確定済み DocumentState
    else 失敗
        Core-->Adapter: error + 変更前の状態を維持
    end
    Adapter-->UI: 応答を返す
@enduml
```

`Core adapter` は共通の意味上の境界を表す。Swift/macOS では標準入出力で別プロセスへ要求し、Tauri/React では invoke を経由して同一プロセス内の Core を呼び出す。

### 4.2 保存と読み込み

```plantuml
@startuml
skinparam shadowing false
skinparam responseMessageBelowArrow true

actor "ユーザー" as User
participant "UI" as UI
participant "OS adapter" as OS
participant "Core adapter" as Adapter
participant "Rust Core" as Core
participant ".lcraft" as File

    alt 保存
        User->UI: 保存
        UI->OS: 保存先を選択
        OS-->UI: path
        UI->Adapter: save(path)
        Adapter->Core: 保存要求
        Core->Core: 永続対象を検証・直列化
        Core->File: JSON を書き込む
        Core-->Adapter: 保存済み状態またはエラー
        Adapter-->UI: 結果
    else 読み込み
        User->UI: ファイルを選択
        UI->OS: 読み込み元を選択
        OS-->UI: path
        UI->Adapter: open(path)
        Adapter->Core: 読み込み要求
        Core->File: JSON を読む
        Core->Core: バージョン・形式・参照整合性を検証
        Core->Core: 派生情報を再計算
        alt 成功
            Core-->Adapter: DocumentState
        else 失敗
            Core-->Adapter: error + 現在のドキュメントを維持
        end
        Adapter-->UI: 結果
    end
@enduml
```

ファイル選択と Core 呼び出しの具体的な接続方法は UI ごとに異なるが、保存対象、読み込み検証、成功・失敗時の状態保証は共通である。

### 4.3 PDF・直接印刷（Swift/macOS）

Tauri/React は Output Document Model による出力プレビューまでを提供し、PDF 生成と直接印刷は行わない。次のフローは Swift/macOS に適用する。

```plantuml
@startuml
skinparam shadowing false
skinparam responseMessageBelowArrow true

actor "ユーザー" as User
participant "UI / OS Adapter" as UI
participant "Rust Core" as Core
participant "Output Document Model" as Model
participant "Output Engine" as Engine
participant "macOS" as OS

    User->UI: 出力設定を確定
    UI->Core: buildOutputDocumentModel(options)
    Core->Core: 出力対象抽出・A4ページ分割・警告判定
    Core-->Model: ページ配置済みデータ
    Model-->UI: model + 警告
    alt 続行できない失敗
        UI-->User: 理由を表示
    else 警告があり利用者判断が必要
        UI-->User: はみ出し・境界またぎなどを表示
        User->UI: 続行または中止
    end
    alt PDF
        UI->Engine: renderPdf(model)
        Engine-->UI: PDF データ
        UI->OS: 保存
    else 直接印刷
        UI->Engine: renderPrint(model)
        Engine-->UI: 印刷用描画データ
        UI->OS: 印刷
    end
@enduml
```

## 5. 状態遷移

ここで示す状態は、設計を理解するための概念状態であり、同名の enum や型を実装へ要求するものではない。

### 5.1 編集操作の状態遷移

```plantuml
@startuml
skinparam shadowing false

top to bottom direction
    state "確定済み" as Stable
    state "操作中" as Draft
    state "Rust Core 検証中" as Validate
    state "変更確定" as Commit
    state "履歴適用中" as History

    [*] --> Stable
    Stable --> Draft: 開始
    Draft --> Stable: 取消
    Draft --> Validate: 確定
    Stable --> Validate: 直接コマンド

    Validate --> Commit: 成功
    Commit --> Stable: 状態・履歴・表示を更新
    Validate --> Stable: 失敗 / 変更前を維持

    Stable --> History: Undo / Redo
    History --> Stable: 再評価完了
@enduml
```

不変条件は、`操作中` と `Core 検証中` では永続状態と履歴を確定変更せず、`変更確定` に到達した操作だけを Undo 単位にすることである。

### 5.2 出力ユースケースの状態遷移

```plantuml
@startuml
skinparam shadowing false

top to bottom direction
    state "編集中" as Editing
    state "出力設定中" as Settings
    state "中間表現生成中" as Building
    state "出力不可" as Failed
    state "警告確認中" as Warning
    state "描画中" as Rendering
    state "OS 処理中" as OS

    [*] --> Editing
    Editing --> Settings: 開始
    Settings --> Editing: 取消
    Settings --> Building: 設定確定

    Building --> Failed: 空 / 範囲外 / 生成失敗
    Failed --> Editing: 理由を確認

    Building --> Warning: 続行可能な警告
    Warning --> Editing: 中止
    Warning --> Rendering: 続行

    Building --> Rendering: 警告なし
    Rendering --> Editing: 描画失敗
    Rendering --> OS: 描画データ生成
    OS --> Editing: 完了 / キャンセル
@enduml
```

出力のどの状態でも、編集中の `ProjectDocument` と Undo/Redo 履歴は変更しない。

## 6. 横断する不変条件

| 不変条件                                 | 守る理由                                     |
| ---------------------------------------- | -------------------------------------------- |
| Core がドキュメントの正本を持つ          | UI と保存結果の食い違いを防ぐ                |
| 失敗した変更を部分反映しない             | 寸法・参照・履歴の整合性を保つ               |
| 参照は安定した ID で表す                 | 保存・複製・Undo/Redo 後も同じ関係を追跡する |
| 派生情報を正本と分ける                   | 元情報の変更後に一貫して再計算できる         |
| UI の一時状態を保存しない                | プロジェクトの意味と画面都合を分離する       |
| PDF と印刷で中間表現と描画規則を共有する | 実寸とレイアウトの差を防ぐ                   |
| 出力処理でドキュメントを変更しない       | 保存状態と履歴に副作用を残さない             |

## 7. 技術境界と UI 構成

KawaCAD は、OS 依存の UI / adapter と OS 非依存の Rust Core を分離する。Swift/macOS と Tauri/React は同じ Core の意味と保存形式を利用し、表示・一時操作・OS 連携だけをそれぞれの環境で担う。

| 領域 | 方針 |
| --- | --- |
| Swift/macOS | SwiftUI、AppKit、Core Graphics。macOS 13 以降の UI、ファイルダイアログ、PDF 保存、直接印刷を担当 |
| Tauri/React | Tauri、React、TypeScript。Windows・Linux・macOS の編集 UI と出力プレビューを担当し、PDF/直接印刷は含めない |
| Rust Core | 図形、拘束、派生要素、パラメータ、パーツ、履歴、保存、表示状態、出力中間表現を担当 |
| `kawacad-core-process` | macOS UI と Core の標準入出力 JSON 境界を担当 |
| Tauri adapter | React UI の invoke を受け、同じプロセス内の Core を直接呼び出す。UI から OS や Core の内部実装を直接参照させない |
| Output Engine | Core が確定した出力中間表現を PDF または印刷用描画データへ変換 |

両 UI は feature-first の責務分割を採用する。macOS は `Features/<Feature>/<Layer>`、Tauri/React は `features/<feature>/<layer>` を基本とし、entry point、adapter、共有語彙、UI 文言の責務を別に保つ。UI は選択、ドラッグ中の候補、viewport、パネル表示などの一時状態を所有し、ドキュメントの確定状態は Core が所有する。

## 8. 保存と主要フロー

`.lcraft` は再読み込み後にプロジェクトの意味を再現する永続状態だけを保存する。選択、ハイライト、ドラッグ中のプレビュー、ズーム、パン、パネル状態、自由度や派生形状の計算結果は必要時に再生成する。形式の外部契約は [`../spec/file-format-spec.md`](../spec/file-format-spec.md)、機械可読な形状は `schemas/lcraft/**` を正とする。

UI/Core の編集フローは、操作意図、必要に応じた preview、Core による検証、原子的な commit、状態再取得の順で進む。保存と出力は編集状態を変更せず、失敗時は現在のドキュメントと履歴を維持する。

```mermaid
sequenceDiagram
    participant User as 利用者
    participant UI as UI
    participant Core as Rust Core
    participant Store as .lcraft / Output Engine
    User->>UI: 編集・保存・出力を要求
    UI->>Core: 操作意図または設定
    Core->>Core: 検証・意味解釈
    alt 編集成功
        Core-->>UI: 確定状態
    else 失敗
        Core-->>UI: エラーと変更前状態
    end
    opt 保存
        Core->>Store: 永続状態を書き出す
    end
    opt 出力
        Core->>Store: 出力中間表現を生成
        Store-->>UI: PDF / 印刷用データまたは警告
    end
```

## 9. 検証境界

Rust Core と Output Engine は OS 非依存の自動テストで、Swift/macOS と Tauri/React は UI、adapter、OS 連携、通常の境界で検証する。ここでの責務分担はテスト一覧を定義するものではなく、変更時に影響範囲を判断するための境界である。

## 10. 機能別設計への案内

| 全体図の要素                   | 詳細を読む文書                                                                              |
| ------------------------------ | ------------------------------------------------------------------------------------------- |
| CAD 基盤、コマンド、履歴、保存 | [CAD 基盤](cad-foundation/overview.md)                                                      |
| 自由度評価、連結成分、拘束状態 | [自由度評価](constraints/dof-algorithm.md)                                                  |
| オフセット、フィレット         | [オフセット線](derived-elements/offset-curves.md)、[フィレット](derived-elements/fillet.md) |
| 型紙の意味情報                 | [型紙要素の表現](pattern-elements/representation.md)                                        |
| パーツ                         | [パーツ管理](parts/overview.md)                                                             |
| 出力経路                       | [出力・印刷](output/overview.md)                                                            |
| 出力の静的構造                 | [出力中間表現](output/document-model.md)                                                    |
| A4 ページ分割                  | [A4 タイル出力](a4-tile-output/overview.md)                                                 |
| UI 内部の責務                  | [UI アーキテクチャ](ui-architecture/overview.md)                                            |
| ツールごとの選択               | [選択対象](interaction/selection-targets.md)                                                |

## 11. 参照する正本

- [`../spec/functional-spec.md`](../spec/functional-spec.md)
- [`architecture.md`](architecture.md)
- [`internal-interface-spec.md`](internal-interface-spec.md)
- [`../spec/file-format-spec.md`](../spec/file-format-spec.md)
- [`../glossary.md`](../glossary.md)
