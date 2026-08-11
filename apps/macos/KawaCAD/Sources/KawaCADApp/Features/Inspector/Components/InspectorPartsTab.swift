import SwiftUI

struct InspectorPartsTab: View {
  @EnvironmentObject private var appState: InspectorFeatureModel

  var body: some View {
    InspectorSection(title: AppStrings.tr("inspector.parts"), symbolName: "square.stack.3d.up") {
      if appState.parts.isEmpty {
        Text(AppStrings.tr("inspector.no_parts"))
          .font(.system(size: 12))
          .foregroundStyle(LeatherColors.secondaryInk)
      } else {
        ForEach(appState.parts) { part in
          InspectorDisclosureRow(
            title: part.name,
            subtitle: AppStrings.tr(
              "inspector.part_structure", part.outlineEntityIDs.count, part.holeEntityIDGroups.count
            ),
            metadata: AppStrings.tr(
              "inspector.part_quantity_members", part.quantity, part.entityIDs.count),
            isSelected: appState.inspectorSelectedPartID == part.id,
            onSelect: { appState.selectPartContents(part) }
          ) {
            PartEditor(part: part)
          }
        }
      }

      if !appState.parts.isEmpty {
        Divider()
        Text(AppStrings.tr("inspector.part_arrangement_help"))
          .font(.system(size: 10))
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
              appState.alignSelectedParts(item.0)
            } label: {
              Image(systemName: item.1)
            }
          }
        }
        .buttonStyle(.bordered)
        .disabled(appState.arrangementSelectedPartIDs.count < 2)
        HStack(spacing: 8) {
          Button(AppStrings.tr("inspector.distribute_horizontal")) {
            appState.distributeSelectedParts("horizontal")
          }
          Button(AppStrings.tr("inspector.distribute_vertical")) {
            appState.distributeSelectedParts("vertical")
          }
        }
        .buttonStyle(.bordered)
        .disabled(appState.arrangementSelectedPartIDs.count < 3)
      }

      Button {
        appState.createPartFromSelection()
      } label: {
        Label(
          AppStrings.tr("inspector.create_part_from_selection"),
          systemImage: "square.stack.3d.up.badge.plus"
        )
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .font(.system(size: 12, weight: .semibold))
      .disabled(appState.selectedEntities.isEmpty)
    }

    InspectorSection(title: AppStrings.tr("inspector.part_library"), symbolName: "books.vertical") {
      if appState.partLibraryEntries.isEmpty {
        Text(AppStrings.tr("inspector.part_library_empty"))
          .font(.system(size: 12))
          .foregroundStyle(LeatherColors.secondaryInk)
      } else {
        ForEach(appState.partLibraryEntries) { entry in
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(entry.name).font(.system(size: 12, weight: .semibold))
              Text(AppStrings.tr("inspector.part_library_quantity", entry.sourcePart.quantity))
                .font(.system(size: 10))
                .foregroundStyle(LeatherColors.secondaryInk)
            }
            Spacer()
            Button {
              appState.insertPartFromLibrary(entry)
            } label: {
              Image(systemName: "plus.square.on.square")
            }
            Button(role: .destructive) {
              appState.removePartLibraryEntry(entry)
            } label: {
              Image(systemName: "trash")
            }
          }
          .buttonStyle(.bordered)
        }
      }
    }
  }
}
