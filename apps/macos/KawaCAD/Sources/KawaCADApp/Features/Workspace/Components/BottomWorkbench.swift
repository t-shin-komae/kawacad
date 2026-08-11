import KawaCADOutput
import SwiftUI

struct BottomWorkbench: View {
  let state: BottomWorkbenchState

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      CompactWorkbenchSection(
        title: AppStrings.tr("workbench.selection"), symbolName: "cursorarrow"
      ) {
        if let selectedEntity = state.selectedEntity {
          CompactWorkbenchLine(
            primary: selectedEntity.label, secondary: selectedEntity.kind.displayName)
          CompactWorkbenchMeta(
            label: AppStrings.tr("workbench.layer"), value: layerName(for: selectedEntity))
        } else {
          CompactWorkbenchLine(
            primary: AppStrings.tr("workbench.none_selected"),
            secondary: AppStrings.tr("workbench.select_on_canvas"))
        }
      }

      CompactWorkbenchSection(title: AppStrings.tr("workbench.constraint"), symbolName: "link") {
        CompactWorkbenchConstraintSummary(
          status: state.constraintStatus,
          count: state.constraints.count
        )
        if let constraint = state.constraints.first {
          CompactWorkbenchMeta(
            label: AppStrings.tr("workbench.state"), value: constraint.kind)
        } else {
          CompactWorkbenchMeta(
            label: AppStrings.tr("workbench.state"),
            value: AppStrings.tr("workbench.no_constraints"))
        }
      }

      CompactWorkbenchSection(title: AppStrings.tr("workbench.parameter"), symbolName: "number") {
        let unusedCount = state.parameters.filter(\.isUnused).count
        let usedCount = state.parameters.count - unusedCount
        if let parameter = state.parameters.first {
          CompactWorkbenchLine(
            primary:
              "\(parameter.name)  \(String(format: "%.2f", parameter.valueMM)) \(parameter.unitLabel)",
            secondary: AppStrings.tr(
              "workbench.parameter_summary", usedCount, unusedCount)
          )
        } else {
          CompactWorkbenchLine(
            primary: AppStrings.tr("workbench.no_parameters"),
            secondary: AppStrings.tr("workbench.unused_zero"))
        }
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, minHeight: 84, maxHeight: 84, alignment: .top)
    .background {
      MacVisualEffectBackground(style: .content)
    }
    .overlay(alignment: .top) {
      Divider()
    }
  }

  private func layerName(for entity: CanvasEntity) -> String {
    guard let layerID = entity.layerID else {
      return AppStrings.tr("workbench.none")
    }
    return state.layers.first(where: { $0.id == layerID })?.name ?? layerID
  }
}

private struct CompactWorkbenchSection<Content: View>: View {
  let title: String
  let symbolName: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 7) {
        Image(systemName: symbolName)
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(LeatherColors.accent)
          .frame(width: 14)
        Text(title)
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(LeatherColors.ink)
        Spacer(minLength: 0)
      }

      VStack(alignment: .leading, spacing: 4) {
        content
      }
    }
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(LeatherColors.insetFill.opacity(0.55))
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .strokeBorder(LeatherColors.panelStroke.opacity(0.35))
    )
  }
}

private struct CompactWorkbenchLine: View {
  let primary: String
  let secondary: String

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(primary)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(LeatherColors.ink)
        .lineLimit(1)
        .truncationMode(.middle)
      Text(secondary)
        .font(.system(size: 10))
        .foregroundStyle(LeatherColors.secondaryInk)
        .lineLimit(1)
        .truncationMode(.tail)
    }
  }
}

private struct CompactWorkbenchMeta: View {
  let label: String
  let value: String

  var body: some View {
    HStack(spacing: 6) {
      Text(label)
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(LeatherColors.secondaryInk)
      Text(value)
        .font(.system(size: 10))
        .foregroundStyle(LeatherColors.secondaryInk)
        .lineLimit(1)
        .truncationMode(.middle)
    }
  }
}

private struct CompactWorkbenchConstraintSummary: View {
  let status: ConstraintStatus
  let count: Int

  var body: some View {
    HStack(spacing: 8) {
      ConstraintStatusBadge(status: status, compact: true)
      Text(AppStrings.tr("workbench.item_count", count))
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(LeatherColors.secondaryInk)
    }
  }
}
