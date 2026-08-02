# 計測表示

## 1. 目的

方眼紙だけでは読み取りにくい寸法や角度を、形状を駆動しない補助表示としてキャンバス上に置けるようにする。

計測表示は、人が確認するための視覚補助であり、図形、派生要素、拘束、パラメータとは分離する。値は保存せず、参照対象から都度計算する。

計測値と、寸法線・投影線・共有端点・角度弧に必要な意味上の基準点は
Core が現在形状から評価する。UI は Core が返す mm 座標の解決済み投影へ
保存済み表示オフセットを適用し、見た目と重なり回避だけを扱う。
寸法拘束も同じ投影モデルを使い、対象レイヤーまたは所属パーツが
非表示の場合の表示可否も Core が返す。

## 2. 責務分離

```plantuml
@startuml
left to right direction

skinparam shadowing false
skinparam packageStyle rectangle
skinparam linetype ortho
  rectangle "entities\n図形" as Entities
  rectangle "measurementAnnotations\n計測表示" as Measure
Entities --> Measure
  rectangle "constraints\n拘束" as Constraints
Constraints ..> Measure : 変換時だけ追加
  rectangle "derivedElements\n派生要素" as Derived
Derived ..> Measure : 通常の対象にはしない
  rectangle "parameters\n名前付きパラメータ" as Parameters
Parameters ..> Measure : 参照しない

  rectangle "編集キャンバス\n補助表示" as Canvas
Measure --> Canvas
  rectangle "Output Document Model\nPDF / 直接印刷" as Output
Measure ..> Output : 含めない
@enduml
```

| 項目 | 扱い |
| --- | --- |
| 図形への影響 | なし |
| 拘束状態への影響 | なし |
| 自由度評価への影響 | なし |
| 保存 | `.lcraft` の補助情報領域に保存 |
| 出力 | V1 では PDF/印刷へ出力しない |

## 3. データの流れ

```plantuml
@startuml
skinparam shadowing false
skinparam responseMessageBelowArrow true

actor "ユーザー" as User
participant "macOS UI" as UI
participant "Rust Core" as Core
participant ".lcraft" as File

    User->UI: 計測表示ツールで対象を選択
    UI->Core: addMeasurementAnnotation
    Core-->UI: DocumentStateResponse.measurementAnnotations
    UI->UI: 対象から値を計算して描画
    User->UI: ラベルまたは表示全体をドラッグ
    UI->Core: updateMeasurementAnnotation(offset)
    Core-->UI: DocumentStateResponse
    Core->File: viewAnnotations.measurementAnnotations として保存
@enduml
```

## 4. 保存内容

計測表示は次の情報だけを持つ。

| フィールド | 目的 |
| --- | --- |
| `id` | 計測表示の識別 |
| `kind` | 計測表示種別 |
| `targets` | 値を計算する参照対象 |
| `labelOffsetMm` | ラベル位置の調整量 |
| `overallOffsetMm` | 寸法線または角度弧全体の調整量 |
| `visible` | 表示可否 |

値そのものは保存しない。対象図形が変わった場合は、次回表示時に再計算する。

## 5. 対象種別

| kind | 対象 |
| --- | --- |
| `distance` | 2点 |
| `segmentLength` | 線分または中心線 |
| `angle` | 共有端点を持つ2線分 |
| `radius` | 円または円弧 |
| `diameter` | 円または円弧 |
| `arcSweepAngle` | 円弧 |

## 6. Undo/Redo と参照切れ

計測表示の追加、更新、削除は `DocumentCommand` として扱い、Undo/Redo 対象にする。

```plantuml
@startuml
top to bottom direction

skinparam shadowing false
skinparam packageStyle rectangle
skinparam linetype ortho
  rectangle "add/update/deleteMeasurementAnnotation" as Command
  rectangle "Undo / Redo 履歴" as History
Command --> History
  rectangle "対象図形の削除" as DeleteTarget
  rectangle "参照チェック" as Check
DeleteTarget --> Check
  rectangle "計測表示を維持" as Keep
Check --> Keep : 参照可能
  rectangle "計測表示を削除し警告" as Remove
Check --> Remove : 参照切れ
  rectangle "DocumentStateResponse" as State
Remove --> State
@enduml
```

参照対象が削除された、または対象種別が不正になった計測表示は、図形本体の復元や拘束評価を止めない。Core は該当計測表示を整理し、警告を返す。

## 7. 拘束への変換

数値を編集したい場合、計測表示自体を数値編集するのではなく、対応する寸法拘束または角度拘束へ変換する。

```plantuml
@startuml
skinparam shadowing false
skinparam responseMessageBelowArrow true

participant "macOS UI" as UI
participant "Rust Core" as Core

    UI->UI: 現在の実測値を計算
    UI->Core: compound(addConstraint, deleteMeasurementAnnotation)
    alt 成功
        Core-->UI: 追加拘束あり、元計測表示なし
    else 失敗
        Core-->UI: 変更前状態
    end
@enduml
```

変換は1つの Undo/Redo 単位にする。変換に失敗した場合は計測表示を残し、既存状態を変更しない。
