import AppKit
import Foundation

enum LayerKind: Hashable {
  case cutLine
  case dimension
  case printGuide
  case construction
  case unknown(String)

  var displayName: String {
    switch self {
    case .cutLine: return AppStrings.tr("layer_kind.cut_line")
    case .dimension: return AppStrings.tr("layer_kind.dimension")
    case .printGuide: return AppStrings.tr("layer_kind.print_guide")
    case .construction: return AppStrings.tr("layer_kind.construction")
    case .unknown(let value): return value
    }
  }
}

enum LinePattern: String, CaseIterable, Identifiable, Hashable {
  case solid
  case dashed
  case dotted
  case construction

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .solid: return AppStrings.tr("line_pattern.solid")
    case .dashed: return AppStrings.tr("line_pattern.dashed")
    case .dotted: return AppStrings.tr("line_pattern.dotted")
    case .construction: return AppStrings.tr("line_pattern.construction")
    }
  }
}

struct LayerColorPreset: Identifiable, Hashable {
  let id: String
  let displayName: String
  let colorHex: String

  static let all: [LayerColorPreset] = [
    LayerColorPreset(
      id: "black", displayName: AppStrings.tr("style.color.black"), colorHex: "#111827"),
    LayerColorPreset(
      id: "gray", displayName: AppStrings.tr("style.color.gray"), colorHex: "#6B7280"),
    LayerColorPreset(id: "red", displayName: AppStrings.tr("style.color.red"), colorHex: "#DC2626"),
    LayerColorPreset(
      id: "blue", displayName: AppStrings.tr("style.color.blue"), colorHex: "#2563EB"),
    LayerColorPreset(
      id: "green", displayName: AppStrings.tr("style.color.green"), colorHex: "#16A34A"),
    LayerColorPreset(
      id: "orange", displayName: AppStrings.tr("style.color.orange"), colorHex: "#EA580C"),
    LayerColorPreset(
      id: "purple", displayName: AppStrings.tr("style.color.purple"), colorHex: "#9333EA"),
  ]

  static func matching(_ colorHex: String) -> LayerColorPreset? {
    let normalized = colorHex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    return all.first { $0.colorHex.uppercased() == normalized }
  }
}

struct LayerStrokeWidthPreset: Identifiable, Hashable {
  let widthMM: Double

  var id: Double { widthMM }

  var displayName: String {
    String(format: "%.2f mm", widthMM)
  }

  static let all: [LayerStrokeWidthPreset] = [0.13, 0.18, 0.25, 0.35, 0.50, 0.70]
    .map { LayerStrokeWidthPreset(widthMM: $0) }

  static func matching(_ widthMM: Double) -> LayerStrokeWidthPreset? {
    all.first { abs($0.widthMM - widthMM) < 0.000_001 }
  }
}

enum EntityKind: Hashable {
  case point
  case lineSegment
  case circle
  case arc
  case centerLine
  case unsupported(String)

  var displayName: String {
    switch self {
    case .point: return AppStrings.tr("entity_kind.point")
    case .lineSegment: return AppStrings.tr("entity_kind.line_segment")
    case .circle: return AppStrings.tr("entity_kind.circle")
    case .arc: return AppStrings.tr("entity_kind.arc")
    case .centerLine: return AppStrings.tr("entity_kind.center_line")
    case .unsupported(let value): return value
    }
  }
}

struct ProjectLayer: Identifiable, Hashable {
  let id: String
  let name: String
  let kind: LayerKind
  let visible: Bool
  let printable: Bool
  let colorHex: String
  let strokeWidthMM: Double
  let linePattern: LinePattern

  init(
    id: String,
    name: String,
    kind: LayerKind,
    visible: Bool,
    printable: Bool,
    colorHex: String,
    strokeWidthMM: Double = 0.2,
    linePattern: LinePattern = .solid
  ) {
    self.id = id
    self.name = name
    self.kind = kind
    self.visible = visible
    self.printable = printable
    self.colorHex = colorHex
    self.strokeWidthMM = strokeWidthMM
    self.linePattern = linePattern
  }
}

struct ProjectSharedStyle: Identifiable, Hashable {
  let id: String
  let name: String
  let colorHex: String
  let strokeWidthMM: Double
  let linePattern: LinePattern

  var stylePayload: [String: Any] {
    [
      "stroke": rgbaPayload(fromHex: colorHex),
      "strokeWidthMm": strokeWidthMM,
      "pattern": linePattern.rawValue,
    ]
  }

  var documentCommandPayload: [String: Any] {
    [
      "id": id,
      "name": name,
      "style": stylePayload,
    ]
  }

  func withName(_ name: String) -> ProjectSharedStyle {
    ProjectSharedStyle(
      id: id, name: name, colorHex: colorHex, strokeWidthMM: strokeWidthMM, linePattern: linePattern
    )
  }

  func withStyle(colorHex: String, strokeWidthMM: Double, linePattern: LinePattern)
    -> ProjectSharedStyle
  {
    ProjectSharedStyle(
      id: id, name: name, colorHex: colorHex, strokeWidthMM: strokeWidthMM, linePattern: linePattern
    )
  }
}

private func rgbaPayload(fromHex hex: String) -> [String: Double] {
  let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
  var rgb: UInt64 = 0
  Scanner(string: value).scanHexInt64(&rgb)

  return [
    "red": Double((rgb >> 16) & 0xFF) / 255.0,
    "green": Double((rgb >> 8) & 0xFF) / 255.0,
    "blue": Double(rgb & 0xFF) / 255.0,
    "alpha": 1.0,
  ]
}

struct UserAlertMessage: Identifiable, Hashable {
  let id = UUID()
  let message: String
}

struct LayerDeletionConfirmation: Identifiable, Hashable {
  let id = UUID()
  let layer: ProjectLayer
  let entityCount: Int

  var message: String {
    let entityText =
      entityCount > 0 ? AppStrings.tr("layer_deletion.entity_count", entityCount) : nil
    let references = [entityText].compactMap { $0 }.joined(separator: "、")
    return AppStrings.tr("layer_deletion.message", layer.name, references)
  }
}

extension Array where Element == ConstraintStatus {
  func aggregated() -> ConstraintStatus {
    if isEmpty {
      return .unknown
    }
    if contains(.conflicting) {
      return .conflicting
    }
    if contains(.overConstrained) {
      return .overConstrained
    }
    if allSatisfy({ $0 == .fullyConstrained }) {
      return .fullyConstrained
    }
    if contains(.underConstrained) {
      return .underConstrained
    }
    return .unknown
  }
}
