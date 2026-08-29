import SwiftUI

struct InspectorPartsTab: View {
  let appState: PartInspectorModel

  var body: some View {
    InspectorSection(title: AppStrings.tr("inspector.parts"), symbolName: "square.stack.3d.up") {
      if appState.data.parts.isEmpty {
        Text(AppStrings.tr("inspector.no_parts"))
          .font(.system(size: 12))
          .foregroundStyle(LeatherColors.secondaryInk)
      } else {
        ForEach(appState.data.parts) { part in
          InspectorDisclosureRow(
            title: part.name,
            subtitle: AppStrings.tr(
              "inspector.part_structure", part.outlineEntityIDs.count, part.holeEntityIDGroups.count
            ),
            metadata: AppStrings.tr(
              "inspector.part_quantity_members", part.quantity, part.entityIDs.count),
            isSelected: appState.data.inspectorSelectedPartID == part.id,
            onSelect: { appState.actions.selectPartContents(part) }
          ) {
            PartEditor(part: part, appState: appState)
          }
        }
      }

      if !appState.data.parts.isEmpty {
        Divider()
        Text(AppStrings.tr("inspector.part_arrangement_help"))
          .font(.system(size: LeatherDesignMetrics.Typography.label))
          .foregroundStyle(LeatherColors.secondaryInk)
        HStack(spacing: 6) {
          ForEach(
            [
              ("left", "align.horizontal.left"),
              ("horizontalCenter", "align.horizontal.center"),
              ("right", "align.horizontal.right"),
              ("bottom", "align.vertical.bottom"),
              ("verticalCenter", "align.vertical.center"),
              ("top", "align.vertical.top"),
            ], id: \.0
          ) { item in
            Button {
              appState.actions.alignSelectedParts(item.0)
            } label: {
              Image(systemName: item.1)
            }
          }
        }
        .buttonStyle(.bordered)
        .leatherControlHeight()
        .disabled(appState.data.arrangementSelectedPartIDs.count < 2)
        HStack(spacing: 8) {
          Button(AppStrings.tr("inspector.distribute_horizontal")) {
            appState.actions.distributeSelectedParts("horizontal")
          }
          Button(AppStrings.tr("inspector.distribute_vertical")) {
            appState.actions.distributeSelectedParts("vertical")
          }
        }
        .buttonStyle(.bordered)
        .leatherControlHeight()
        .disabled(appState.data.arrangementSelectedPartIDs.count < 3)
      }

      Button {
        appState.actions.createPartFromSelection()
      } label: {
        Label(
          AppStrings.tr("inspector.create_part_from_selection"),
          systemImage: "square.stack.3d.up.badge.plus"
        )
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .font(.system(size: LeatherDesignMetrics.Typography.section, weight: .semibold))
      .leatherControlHeight()
      .disabled(appState.data.selectedEntities.isEmpty)
    }

    InspectorSection(title: AppStrings.tr("inspector.part_library"), symbolName: "books.vertical") {
      if appState.data.partLibraryEntries.isEmpty {
        Text(AppStrings.tr("inspector.part_library_empty"))
          .font(.system(size: 12))
          .foregroundStyle(LeatherColors.secondaryInk)
      } else {
        ForEach(appState.data.partLibraryEntries) { entry in
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(entry.name).font(.system(size: 12, weight: .semibold))
              Text(AppStrings.tr("inspector.part_library_quantity", entry.sourcePart.quantity))
                .font(.system(size: LeatherDesignMetrics.Typography.label))
                .foregroundStyle(LeatherColors.secondaryInk)
            }
            Spacer()
            Button {
              appState.actions.insertPartFromLibrary(entry)
            } label: {
              Image(systemName: "plus.square.on.square")
            }
            Button(role: .destructive) {
              appState.actions.removePartLibraryEntry(entry)
            } label: {
              Image(systemName: "trash")
            }
          }
          .buttonStyle(.bordered)
          .leatherControlHeight()
        }
      }
    }
  }
}
