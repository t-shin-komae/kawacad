import AppKit
import SwiftUI

enum KawaCADHelpSection: String, CaseIterable, Identifiable {
  case overview
  case tools
  case canvas

  var id: String { rawValue }

  var title: String {
    switch self {
    case .overview: return AppStrings.tr("help.section.overview")
    case .tools: return AppStrings.tr("help.section.tools")
    case .canvas: return AppStrings.tr("help.section.canvas")
    }
  }
}

private final class KawaCADHelpPanelState: ObservableObject {
  @Published var section: KawaCADHelpSection

  init(section: KawaCADHelpSection) {
    self.section = section
  }
}

private struct KawaCADHelpDialog: View {
  @ObservedObject var state: KawaCADHelpPanelState
  @State private var query = ""

  private var matchingTools: [CanvasTool] {
    let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedQuery.isEmpty else { return CanvasTool.allCases }
    return CanvasTool.allCases.filter {
      $0.displayName.localizedCaseInsensitiveContains(normalizedQuery)
        || $0.idleMessage.localizedCaseInsensitiveContains(normalizedQuery)
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text(AppStrings.tr("help.title"))
            .font(.title2.bold())
          Text(AppStrings.tr("help.subtitle"))
            .foregroundStyle(.secondary)
            .font(.subheadline)
        }
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)

      Picker(AppStrings.tr("help.section_picker"), selection: $state.section) {
        ForEach(KawaCADHelpSection.allCases) { section in
          Text(section.title).tag(section)
        }
      }
      .pickerStyle(.segmented)
      .padding(20)

      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          switch state.section {
          case .overview:
            HelpOverview()
          case .tools:
            HelpTools(query: $query, tools: matchingTools)
          case .canvas:
            HelpCanvas()
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
      }
    }
    .frame(minWidth: 760, minHeight: 620)
  }
}

private struct HelpOverview: View {
  var body: some View {
    HelpSectionView(
      title: AppStrings.tr("help.basic.title"),
      description: AppStrings.tr("help.basic.body"),
      bullets: [
        AppStrings.tr("help.basic.cancel"),
        AppStrings.tr("help.basic.inspector"),
        AppStrings.tr("help.basic.edit_menu"),
        AppStrings.tr("help.basic.view_menu"),
      ]
    )
  }
}

private struct HelpTools: View {
  @Binding var query: String
  let tools: [CanvasTool]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(AppStrings.tr("help.tools.title"))
        .font(.headline)
      Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
        GridRow {
          Text(AppStrings.tr("help.shortcut.command"))
            .fontWeight(.semibold)
          Text(AppStrings.tr("help.shortcut.action"))
            .fontWeight(.semibold)
        }
        ForEach([
          ("⌘/Ctrl + 1〜5", AppStrings.tr("help.shortcut.tools")),
          ("⌘/Ctrl + Z", AppStrings.tr("help.shortcut.undo")),
          ("⌘/Ctrl + Shift + Z", AppStrings.tr("help.shortcut.redo")),
          ("⌘/Ctrl + S", AppStrings.tr("help.shortcut.save")),
          ("Esc", AppStrings.tr("help.shortcut.cancel")),
        ], id: \.0) { shortcut, action in
          GridRow {
            Text(shortcut).monospaced()
            Text(action).foregroundStyle(.secondary)
          }
        }
      }

      TextField(AppStrings.tr("help.search"), text: $query)
        .textFieldStyle(.roundedBorder)
        .accessibilityLabel(AppStrings.tr("help.search"))

      Text(AppStrings.tr("help.tools.list"))
        .font(.subheadline.bold())
        .padding(.top, 4)
      LazyVStack(alignment: .leading, spacing: 8) {
        ForEach(tools) { tool in
          VStack(alignment: .leading, spacing: 2) {
            Text(tool.displayName).fontWeight(.semibold)
            Text(tool.idleMessage).foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical, 4)
          Divider()
        }
        if tools.isEmpty {
          Text(AppStrings.tr("help.search.empty"))
            .foregroundStyle(.secondary)
        }
      }
    }
  }
}

private struct HelpCanvas: View {
  var body: some View {
    HelpSectionView(
      title: AppStrings.tr("help.canvas.title"),
      description: AppStrings.tr("help.canvas.body"),
      bullets: [
        AppStrings.tr("help.canvas.grid_snap"),
        AppStrings.tr("help.canvas.point_snap"),
        AppStrings.tr("help.canvas.control_snap"),
        AppStrings.tr("help.canvas.marquee"),
        AppStrings.tr("help.canvas.option_duplicate"),
        AppStrings.tr("help.canvas.display_aids"),
      ]
    )
  }
}

private struct HelpSectionView: View {
  let title: String
  let description: String
  let bullets: [String]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title).font(.headline)
      Text(description).foregroundStyle(.secondary)
      ForEach(bullets, id: \.self) { bullet in
        Label(bullet, systemImage: "circle.fill")
          .labelStyle(.titleAndIcon)
          .font(.body)
      }
    }
  }
}

enum KawaCADHelpPanel {
  private static var window: NSWindow?
  private static var state: KawaCADHelpPanelState?

  static func present(section: KawaCADHelpSection, application: NSApplication = .shared) {
    if let window, let state {
      state.section = section
      window.makeKeyAndOrderFront(nil)
      application.activate(ignoringOtherApps: true)
      return
    }

    let panelState = KawaCADHelpPanelState(section: section)
    let controller = NSHostingController(rootView: KawaCADHelpDialog(state: panelState))
    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 780, height: 660),
      styleMask: [.titled, .closable, .resizable],
      backing: .buffered,
      defer: false
    )
    panel.contentViewController = controller
    panel.title = AppStrings.tr("help.title")
    panel.isReleasedWhenClosed = false
    panel.center()
    state = panelState
    window = panel
    panel.makeKeyAndOrderFront(nil)
    application.activate(ignoringOtherApps: true)
  }
}
