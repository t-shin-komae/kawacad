import KawaCADOutput
import SwiftUI

/// A local, executable catalog for SwiftUI and AppKit-facing UI components.
///
/// The gallery uses small fixture states so visual changes can be checked
/// without creating a document or starting the Core process.
private enum ComponentGalleryAppearance: String, CaseIterable, Hashable, Identifiable {
  case system
  case light
  case dark

  var id: String { rawValue }

  var title: String {
    switch self {
    case .system: return "System"
    case .light: return "Light"
    case .dark: return "Dark"
    }
  }

  var colorScheme: ColorScheme? {
    switch self {
    case .system: return nil
    case .light: return .light
    case .dark: return .dark
    }
  }
}

struct ComponentGalleryView: View {
  private enum Page: String, CaseIterable, Identifiable {
    case canvas
    case workspace
    case inspector
    case feedback
    case boundComponents

    var id: String { rawValue }

    var title: String {
      switch self {
      case .canvas: return "Canvas"
      case .workspace: return "Workspace"
      case .inspector: return "Inspector"
      case .feedback: return "Feedback"
      case .boundComponents: return "Core-bound components"
      }
    }

    var symbolName: String {
      switch self {
      case .canvas: return "square.grid.3x3"
      case .workspace: return "rectangle.split.3x1"
      case .inspector: return "sidebar.right"
      case .feedback: return "exclamationmark.bubble"
      case .boundComponents: return "link"
      }
    }
  }

  @State private var selectedPage: Page? = .canvas
  @State private var previewWidth: CGFloat = 820
  @State private var toolPaletteWidth: CGFloat = 300
  @State private var appearance: ComponentGalleryAppearance = .system

  var body: some View {
    NavigationSplitView {
      VStack(spacing: 0) {
        List(Page.allCases, selection: $selectedPage) { page in
          Label(page.title, systemImage: page.symbolName)
            .tag(page)
        }
        .listStyle(.sidebar)

        Divider()

        GalleryControls(
          previewWidth: $previewWidth,
          toolPaletteWidth: $toolPaletteWidth,
          appearance: $appearance
        )
      }
      .navigationTitle("Component Gallery")
    } detail: {
      ScrollView {
        pageContent
          .frame(width: previewWidth, alignment: .topLeading)
          .padding(24)
      }
      .background(LeatherColors.window)
    }
    .frame(minWidth: 1_040, minHeight: 720)
    .preferredColorScheme(appearance.colorScheme)
  }

  @ViewBuilder
  private var pageContent: some View {
    switch selectedPage ?? .canvas {
    case .canvas:
      CanvasGalleryPage(toolPaletteWidth: toolPaletteWidth)
    case .workspace:
      WorkspaceGalleryPage()
    case .inspector:
      InspectorGalleryPage()
    case .feedback:
      FeedbackGalleryPage()
    case .boundComponents:
      BoundComponentsGalleryPage()
    }
  }
}

private struct GalleryControls: View {
  @Binding var previewWidth: CGFloat
  @Binding var toolPaletteWidth: CGFloat
  @Binding var appearance: ComponentGalleryAppearance

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Preview")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(LeatherColors.secondaryInk)

      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text("Content width")
          Spacer()
          Text("\(Int(previewWidth)) pt")
            .foregroundStyle(LeatherColors.secondaryInk)
        }
        .font(.system(size: 11))

        Slider(value: $previewWidth, in: 560...1_600, step: 20)
          .accessibilityLabel("Content width")
      }

      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text("Tool palette")
          Spacer()
          Text("\(Int(toolPaletteWidth)) pt")
            .foregroundStyle(LeatherColors.secondaryInk)
        }
        .font(.system(size: 11))

        Slider(value: $toolPaletteWidth, in: 176...360, step: 8)
          .accessibilityLabel("Tool palette width")
      }

      Picker("Appearance", selection: $appearance) {
        ForEach(ComponentGalleryAppearance.allCases) { appearance in
          Text(appearance.title).tag(appearance)
        }
      }
      .pickerStyle(.menu)
      .font(.system(size: 11))
    }
    .padding(14)
  }
}

private struct GalleryPageHeader: View {
  let title: String
  let description: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.system(size: 25, weight: .bold))
        .foregroundStyle(LeatherColors.ink)
      Text(description)
        .font(.system(size: 13))
        .foregroundStyle(LeatherColors.secondaryInk)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.bottom, 8)
  }
}

private struct GalleryCard<Content: View>: View {
  let title: String
  let source: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Text(title)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(LeatherColors.ink)
        Spacer(minLength: 8)
        Text(source)
          .font(.system(size: 10, design: .monospaced))
          .foregroundStyle(LeatherColors.tertiaryInk)
          .lineLimit(1)
      }

      content
    }
    .padding(16)
    .background(LeatherColors.panel)
    .clipShape(RoundedRectangle(cornerRadius: LeatherDesignMetrics.cardRadius, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: LeatherDesignMetrics.cardRadius, style: .continuous)
        .stroke(LeatherColors.panelStroke.opacity(0.7))
    )
  }
}

private struct CanvasGalleryPage: View {
  let toolPaletteWidth: CGFloat

  private let iconTools: [CanvasTool] = [
    .select, .point, .line, .circle, .arc, .freeText, .centerLine, .measureDistance,
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      GalleryPageHeader(
        title: "Canvas components",
        description:
          "Tool selection, CAD toolbar controls, and the tool palette with fixture state."
      )

      GalleryCard(title: "Tool icons", source: "DesignSystem.swift") {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 12) {
          ForEach(iconTools) { tool in
            VStack(spacing: 8) {
              ToolIcon(tool: tool, size: 28, color: LeatherColors.ink)
                .frame(width: 42, height: 42)
              Text(tool.displayName)
                .font(.system(size: 11))
                .foregroundStyle(LeatherColors.secondaryInk)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 70)
          }
        }
      }

      GalleryCard(title: "CAD toolbar", source: "Features/Canvas/Components/CADToolbar.swift") {
        CADToolbarFixture()
      }

      GalleryCard(title: "Tool palette", source: "Features/Canvas/Components/ToolPalette.swift") {
        ToolPaletteFixture(width: toolPaletteWidth)
          .frame(height: 520)
          .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
      }
    }
  }
}

private struct CADToolbarFixture: View {
  @State private var selectedTool: CanvasTool = .line
  @State private var viewMode: CanvasViewMode = .editDisplay
  @State private var activeLayerID = "cut"
  @State private var gridVisible = true
  @State private var a4ReferenceVisible = true
  @State private var a4ReferenceOrientation: OutputPrintOrientation = .portrait
  @State private var gridSnapEnabled = true
  @State private var pointSnapEnabled = true
  @State private var inspectorPanelVisible = true

  private let layers = [
    ProjectLayer(
      id: "cut", name: "Cut lines", kind: .cutLine, visible: true, printable: true,
      colorHex: "#111827", linePattern: .solid),
    ProjectLayer(
      id: "construction", name: "Construction", kind: .construction, visible: true,
      printable: false, colorHex: "#2563EB", linePattern: .dashed),
  ]

  var body: some View {
    ViewThatFits(in: .horizontal) {
      toolbar(density: .expanded)
      toolbar(density: .condensed)
    }
    .frame(height: 54)
    .background {
      MacVisualEffectBackground(style: .header)
    }
    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
  }

  private func toolbar(density: CADToolbarDensity) -> some View {
    CADToolbar(
      state: toolbarState,
      actions: toolbarActions,
      workspaceLayoutMode: .wide,
      density: density
    )
  }

  private var toolbarState: CADToolbarState {
    CADToolbarState(
      selectedTool: selectedTool,
      viewMode: viewMode,
      layers: layers,
      activeLayerID: activeLayerID,
      constraintStatus: .underConstrained,
      zoomScale: 1.25,
      gridVisible: gridVisible,
      a4ReferenceVisible: a4ReferenceVisible,
      a4ReferenceOrientation: a4ReferenceOrientation,
      gridSnapEnabled: gridSnapEnabled,
      pointSnapEnabled: pointSnapEnabled,
      inspectorPanelVisible: inspectorPanelVisible,
      canCopySelection: true,
      canPasteSelection: true,
      canDuplicateSelection: true
    )
  }

  private var toolbarActions: CADToolbarActions {
    CADToolbarActions(
      showToolPalette: {},
      toggleInspector: { _ in inspectorPanelVisible.toggle() },
      setActiveLayer: { activeLayerID = $0 },
      setViewMode: { viewMode = $0 },
      zoomIn: {},
      zoomOut: {},
      zoomToFit: {},
      setGridVisible: { gridVisible = $0 },
      setA4ReferenceVisible: { a4ReferenceVisible = $0 },
      setA4ReferenceOrientation: { a4ReferenceOrientation = $0 },
      setGridSnapEnabled: { gridSnapEnabled = $0 },
      setPointSnapEnabled: { pointSnapEnabled = $0 },
      copySelection: {},
      pasteSelection: {},
      duplicateSelection: {}
    )
  }
}

private struct ToolPaletteFixture: View {
  let width: CGFloat

  @State private var selectedTool: CanvasTool = .select
  @State private var activeStyleID = "solid"
  @State private var roundHoleKind: ProjectRoundHoleKind = .keyRing
  @State private var showsDetailedTools = false
  @State private var collapsedGroupIDs: Set<String> = []

  private let sharedStyles = [
    ProjectSharedStyle(
      id: "solid", name: "Solid", colorHex: "#111827", strokeWidthMM: 0.2, linePattern: .solid),
    ProjectSharedStyle(
      id: "construction", name: "Construction", colorHex: "#2563EB", strokeWidthMM: 0.18,
      linePattern: .dashed),
  ]

  var body: some View {
    ToolPalette(
      state: ToolPaletteState(
        selectedTool: selectedTool,
        sharedStyles: sharedStyles,
        activePatternLineStyleID: activeStyleID,
        selectedEntityCount: 2,
        activeRoundHoleKind: roundHoleKind,
        activeRoundHoleDiameterMM: 4,
        showsDetailedTools: showsDetailedTools,
        collapsedGroupIDs: collapsedGroupIDs
      ),
      actions: ToolPaletteActions(
        activateTool: { selectedTool = $0 },
        setActivePatternLineStyle: { activeStyleID = $0 },
        applyActivePatternLineStyleToSelection: {},
        setActiveRoundHoleKind: { roundHoleKind = $0 },
        setActiveRoundHoleDiameter: { _ in true },
        setActiveRoundHoleDiameterInputValid: { _ in },
        setShowsDetailedTools: { showsDetailedTools = $0 },
        setGroupCollapsed: { isCollapsed, groupID in
          if isCollapsed {
            collapsedGroupIDs.insert(groupID)
          } else {
            collapsedGroupIDs.remove(groupID)
          }
        }
      ),
      width: width
    )
  }
}

private struct WorkspaceGalleryPage: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      GalleryPageHeader(
        title: "Workspace components",
        description: "The document header, status bar, panel chrome, and layout affordances."
      )

      GalleryCard(
        title: "Document header", source: "Features/Document/Components/DocumentHeader.swift"
      ) {
        DocumentHeaderFixture()
          .background {
            MacVisualEffectBackground(style: .header)
          }
          .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
      }

      GalleryCard(
        title: "Canvas status bar", source: "Features/Canvas/Components/CanvasStatusBar.swift"
      ) {
        CanvasStatusBarFixture()
          .background(LeatherColors.canvas)
          .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
      }

      GalleryCard(title: "Panel primitives", source: "Shared/Components/DesignSystem.swift") {
        VStack(alignment: .leading, spacing: 14) {
          PanelHeader(title: "Layers", symbolName: "square.stack.3d.up")
          HStack(spacing: 8) {
            ConstraintStatusBadge(status: .fullyConstrained)
            ConstraintStatusBadge(status: .underConstrained)
            ConstraintStatusBadge(status: .conflicting)
            ChipView(text: "A4 / 1:1")
          }
          SectionSeparator()
          HStack(spacing: 0) {
            Text("Resizable panel")
              .font(.system(size: 12))
            Spacer()
            PanelResizeHandle(alignment: .trailing, onChanged: { _ in }, onEnded: { _ in }) {
              _ in
            }
            .frame(height: 44)
          }
        }
      }
    }
  }
}

private struct DocumentHeaderFixture: View {
  @State private var documentName = "Sample project"

  var body: some View {
    DocumentHeader(
      state: DocumentHeaderState(
        documentName: documentName,
        canRenameDocument: true,
        unitLabel: "mm",
        paperLabel: "A4 portrait"
      ),
      actions: DocumentHeaderActions(
        updateDocumentNameDraft: { _ in },
        commitDocumentName: { value in
          documentName = value
          return .success(canonicalValue: value)
        }
      )
    )
  }
}

private struct CanvasStatusBarFixture: View {
  @State private var bottomWorkbenchVisible = false

  var body: some View {
    CanvasStatusBar(
      state: CanvasStatusBarState(
        visibleEntityCount: 12,
        selectionText: "2 selected",
        cursorCoordinateText: "X 24.00 / Y 18.50 mm",
        outputPreviewSummaryText: "A4 · 1:1",
        outputPreviewHasWarnings: false,
        statusMessage: "Ready",
        bottomWorkbenchVisible: bottomWorkbenchVisible
      ),
      actions: CanvasStatusBarActions(
        setBottomWorkbenchVisible: { bottomWorkbenchVisible = $0 }
      )
    )
  }
}

private struct InspectorGalleryPage: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      GalleryPageHeader(
        title: "Inspector components",
        description: "Reusable sections, disclosure rows, editable fields, and inset surfaces."
      )

      GalleryCard(title: "Inspector section", source: "Shared/Components/DesignSystem.swift") {
        InspectorFixture()
      }

      GalleryCard(
        title: "Selection disclosure row",
        source: "Features/Inspector/Components/InspectorSelectionEditors.swift"
      ) {
        DisclosureRowFixture()
      }

      GalleryCard(title: "Inspector surfaces", source: "Shared/Components/DesignSystem.swift") {
        InsetSurface {
          VStack(alignment: .leading, spacing: 8) {
            Text("InsetSurface")
              .font(.system(size: 12, weight: .semibold))
            Text("Use this surface for grouped values inside an inspector section.")
              .font(.system(size: 11))
              .foregroundStyle(LeatherColors.secondaryInk)
          }
        }
      }
    }
  }
}

private struct InspectorFixture: View {
  @State private var value = "24.00"

  var body: some View {
    InspectorSection(title: "Geometry", symbolName: "scribble.variable") {
      HStack {
        Text("Width")
          .font(.system(size: 12))
        Spacer()
        SyncedTextField(
          placeholder: "Width",
          sourceValue: value,
          onCommit: {
            value = $0
            return true
          },
          width: 90,
          font: .system(size: 11, design: .monospaced)
        )
      }
      HStack {
        Text("Constraint")
          .font(.system(size: 12))
        Spacer()
        ConstraintStatusBadge(status: .fullyConstrained, compact: true)
      }
    }
  }
}

private struct DisclosureRowFixture: View {
  @State private var isSelected = true

  var body: some View {
    InspectorDisclosureRow(
      title: "Line segment",
      subtitle: "A selected drawing entity",
      metadata: "24.00 mm",
      isSelected: isSelected,
      onSelect: { isSelected.toggle() },
      content: {
        InsetSurface {
          HStack {
            Label("Layer", systemImage: "square.stack.3d.up")
            Spacer()
            Text("Cut lines")
              .foregroundStyle(LeatherColors.secondaryInk)
          }
          .font(.system(size: 11))
        }
      }
    )
  }
}

private struct FeedbackGalleryPage: View {
  private let errorPresentation = AppErrorPresentation.make(
    category: .operationFailure,
    code: "GALLERY_SAMPLE",
    operation: "save project",
    message: "The project could not be saved.",
    details: "This is a fixture for the expandable diagnostic details.",
    recoverySuggestion: "Check the destination and try again."
  )

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      GalleryPageHeader(
        title: "Feedback components",
        description:
          "Error, recovery, and confirmation states shown with representative fixture data."
      )

      GalleryCard(
        title: "Recovery save failure",
        source: "Features/Recovery/Components/RecoverySaveFailureBanner.swift"
      ) {
        RecoverySaveFailureBanner(
          banner: DocumentRecoveryBannerState(
            recoveryID: "gallery-recovery",
            message: "Recovery snapshot could not be written.",
            details: "The fixture demonstrates retry, details, and dismiss actions."
          ),
          onRetry: {},
          onDismiss: {}
        )
      }

      GalleryCard(
        title: "Application error", source: "Features/Workspace/Components/AppErrorBanner.swift"
      ) {
        AppErrorBanner(presentation: errorPresentation, onDismiss: {})
      }

      GalleryCard(
        title: "Save confirmation",
        source: "Features/Document/Components/DocumentSaveConfirmationDialog.swift"
      ) {
        DocumentSaveConfirmationDialog(
          confirmation: DocumentSaveConfirmation(
            documentName: "Sample project",
            reason: "Save changes before closing this document?"
          ),
          actions: DocumentSaveConfirmationActions(cancel: {}, discard: {}, save: {})
        )
        .background {
          MacVisualEffectBackground(style: .content)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
      }
    }
  }
}

private struct BoundComponentsGalleryPage: View {
  private enum Component: String, CaseIterable, Identifiable {
    case cadCanvas = "CADCanvas / LeatherCanvasView"
    case workspaceSurface = "WorkspaceCanvasLayout / WorkspaceCanvasSurface"
    case inspectorPanel = "InspectorPanel and feature tabs"
    case outputDialogs = "OutputDialog / RecoveryChooserDialog"
    case documentOverlays = "LayerDeletionDialog / PasteOptionsOverlay"
    case appPanels = "AboutPanel / LicensesPanel"

    var id: String { rawValue }

    var detail: String {
      switch self {
      case .cadCanvas:
        return
          "Requires Core render and interaction snapshots; the gallery intentionally does not start the Core process."
      case .workspaceSurface:
        return
          "Requires the assembled WorkspaceViewState and action routing owned by AppCoordinator."
      case .inspectorPanel:
        return
          "Requires selection, layer, style, parameter, or parts models produced by the live document."
      case .outputDialogs:
        return "Requires output or recovery request state and platform presentation actions."
      case .documentOverlays:
        return "Requires a live document selection or clipboard payload."
      case .appPanels:
        return
          "AppKit panels are opened by application commands and are verified through the running app."
      }
    }

    var source: String {
      switch self {
      case .cadCanvas: return "Features/Canvas/Components"
      case .workspaceSurface: return "Features/Workspace/Components"
      case .inspectorPanel: return "Features/Inspector/Components"
      case .outputDialogs: return "Features/Output, Features/Recovery"
      case .documentOverlays: return "Features/Document/Components"
      case .appPanels: return "App/KawaCADAboutPanel.swift"
      }
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      GalleryPageHeader(
        title: "Core-bound components",
        description:
          "Components that are cataloged but need live document/Core or AppKit presentation state."
      )

      GalleryCard(title: "Integration boundary", source: "App/AppCoordinator.swift") {
        VStack(alignment: .leading, spacing: 10) {
          Label(
            "Run the normal application to verify these components with real state.",
            systemImage: "info.circle"
          )
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(LeatherColors.ink)
          Text(
            "This page keeps the catalog complete without introducing a second Core lifecycle or fake document model."
          )
          .font(.system(size: 11))
          .foregroundStyle(LeatherColors.secondaryInk)
        }
      }

      ForEach(Component.allCases) { component in
        GalleryCard(title: component.rawValue, source: component.source) {
          Text(component.detail)
            .font(.system(size: 12))
            .foregroundStyle(LeatherColors.secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }
}
