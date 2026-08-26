import SwiftUI

/// Layer-specific editor. Shared style editing stays in the shared-style
/// feature; this view only adapts layer metadata and its two visibility flags.
struct LayerEditorRow: View {
  let layer: ProjectLayer
  let canDelete: Bool
  let onRename: (String) -> Bool
  let onToggleVisibility: () -> Void
  let onTogglePrintable: () -> Void
  let onStyleChange: (ProjectLayer) -> Bool
  let onDelete: () -> Void

  var body: some View {
    StyleEditorRow(
      style: ProjectSharedStyle(
        id: layer.id,
        name: layer.name,
        colorHex: normalizedHex(layer.colorHex),
        strokeWidthMM: layer.strokeWidthMM,
        linePattern: layer.linePattern
      ),
      namePlaceholder: AppStrings.tr("inspector.layer_name_placeholder"),
      onChange: { updatedStyle in
        if updatedStyle.name != layer.name {
          return onRename(updatedStyle.name)
        }
        return onStyleChange(
          ProjectLayer(
            id: layer.id,
            name: layer.name,
            kind: layer.kind,
            visible: layer.visible,
            printable: layer.printable,
            colorHex: updatedStyle.colorHex,
            strokeWidthMM: updatedStyle.strokeWidthMM,
            linePattern: updatedStyle.linePattern
          )
        )
      },
      accessoryButtons: Group {
        Button(action: onToggleVisibility) {
          Image(systemName: layer.visible ? "eye" : "eye.slash")
            .frame(
              width: LeatherDesignMetrics.Control.height,
              height: LeatherDesignMetrics.Control.height
            )
        }
        .buttonStyle(.borderless)
        .foregroundStyle(layer.visible ? LeatherColors.ink : LeatherColors.secondaryInk)

        Button(action: onTogglePrintable) {
          Image(systemName: layer.printable ? "printer.fill" : "printer")
            .frame(
              width: LeatherDesignMetrics.Control.height,
              height: LeatherDesignMetrics.Control.height
            )
        }
        .buttonStyle(.borderless)
        .foregroundStyle(layer.printable ? LeatherColors.ink : LeatherColors.secondaryInk)
      },
      deleteButton: Button(action: onDelete) {
        Image(systemName: "trash")
          .frame(
            width: LeatherDesignMetrics.Control.height,
            height: LeatherDesignMetrics.Control.height
          )
      }
      .buttonStyle(.borderless)
      .foregroundStyle(canDelete ? LeatherColors.destructive : LeatherColors.secondaryInk)
      .disabled(!canDelete)
    )
  }

  private func normalizedHex(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.hasPrefix("#") ? trimmed : "#\(trimmed)"
  }
}
