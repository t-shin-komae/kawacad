import Testing

@testable import KawaCADApp

private let parameter = ProjectParameter(
  id: "parameter:length",
  name: "length",
  valueMM: 12.345,
  unit: "millimeter",
  memo: "",
  usageCount: 1,
  usedConstraintIDs: ["constraint:length"]
)

@Test("#133 固定値とパラメータ参照値を小数点以下2桁で表示する")
func inspector_value_formatting_resolves_fixed_and_parameter_values() {
  #expect(
    InspectorValueFormatting.resolvedText(
      fixedValue: 10,
      parameterID: nil,
      parameters: [parameter]
    ) == "10.00")
  #expect(
    InspectorValueFormatting.resolvedText(
      fixedValue: nil,
      parameterID: parameter.id,
      parameters: [parameter]
    ) == "12.35")
}

@Test("#133 未解決値と非有限値は無関係な既定値を補わず空欄にする")
func inspector_value_formatting_leaves_unresolved_values_empty() {
  #expect(
    InspectorValueFormatting.resolvedText(
      fixedValue: nil,
      parameterID: "parameter:missing",
      parameters: [parameter]
    ).isEmpty)
  #expect(InspectorValueFormatting.format(.infinity).isEmpty)
}
