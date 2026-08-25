import AppKit
import KawaCADOutput
import SwiftUI
import XCTest

@testable import KawaCADApp

private let regularScreenshotSize = CGSize(width: 1280, height: 800)
private let wideScreenshotSize = CGSize(width: 1800, height: 900)
private let themeMatrixWideScreenshotSize = CGSize(width: 1600, height: 900)
private let compactScreenshotSize = CGSize(width: 1024, height: 700)

private enum ScreenshotTheme: String, CaseIterable {
  case light
  case dark

  var appearanceName: NSAppearance.Name {
    switch self {
    case .light:
      return .aqua
    case .dark:
      return .darkAqua
    }
  }
}

final class ComparisonScreenshotTests: XCTestCase {
  @MainActor
  func testComparisonScreenshots() throws {
    guard
      let outputPath = ProcessInfo.processInfo.environment["KAWACAD_SCREENSHOT_OUTPUT_DIR"],
      !outputPath.isEmpty
    else {
      return
    }
    print("KAWACAD_SCREENSHOT_OUTPUT_DIR =", outputPath)
    let outputDirectory = URL(fileURLWithPath: outputPath, isDirectory: true)
    try FileManager.default.createDirectory(
      at: outputDirectory,
      withIntermediateDirectories: true
    )
    let preferences = ScreenshotPreferenceSnapshot.capture()
    defer { preferences.restore() }

    try captureInitialWorkspace(outputDirectory)
    try captureDetailedToolsAndSummary(outputDirectory)
    try captureWideToolbarStates(outputDirectory)
    try captureConstraintHUD(outputDirectory)
    try captureContextMenu(outputDirectory)
    try capturePasteOptions(outputDirectory)
    try captureFreeText(
      outputDirectory,
      fileName: "swift-free-text-default.png",
      selectedTool: .freeText
    )
    try captureFreeText(
      outputDirectory,
      fileName: "swift-inline-text-editor.png",
      selectedTool: .select
    )
    try captureCompactDrawers(outputDirectory)
    try captureLicenses(outputDirectory)
    try captureLayerDeletion(outputDirectory)
    try captureInspectorManagementTabs(outputDirectory)
    try captureSelectionEntityEditors(outputDirectory)
    try captureRecoveryCandidates(outputDirectory)
    try capturePDFOutput(outputDirectory)
    try captureRepresentativeThemeMatrix(outputDirectory)
    try createComparisonImages(screenshotDirectory: outputDirectory)
  }
}

@MainActor
private func captureInitialWorkspace(_ outputDirectory: URL) throws {
  try renderWorkspace(
    makeScreenshotAppState(),
    size: regularScreenshotSize,
    to: outputDirectory.appendingPathComponent("swift-browser-initial.png")
  )
}

@MainActor
private func captureDetailedToolsAndSummary(_ outputDirectory: URL) throws {
  let appState = makeScreenshotAppState()
  appState.workspacePreferences.setDetailedToolsVisible(true)
  appState.workspacePreferences.setBottomWorkbenchVisible(true)
  for group in ToolPalette.allToolGroups {
    appState.workspacePreferences.setToolGroupCollapsed(false, groupID: group.id)
  }
  try renderWorkspace(
    appState,
    size: regularScreenshotSize,
    to: outputDirectory.appendingPathComponent("swift-detailed-tools-summary.png")
  )
}

@MainActor
private func captureWideToolbarStates(_ outputDirectory: URL) throws {
  let appState = makeScreenshotAppState()
  appState.workspaceLayout.setToolPanelWidth(260)
  appState.workspaceLayout.setWindowLayoutMode(.wide)
  let capture: (String) throws -> Void = { fileName in
    try renderWorkspace(
      appState,
      size: wideScreenshotSize,
      to: outputDirectory.appendingPathComponent(fileName)
    )
  }

  try capture("swift-wide-toolbar.png")

  appState.workspacePreferences.setGridVisible(false)
  try capture("swift-wide-grid-off.png")
  appState.workspacePreferences.setGridVisible(true)

  appState.workspacePreferences.setA4ReferenceVisible(false)
  try capture("swift-wide-a4-reference-off.png")
  appState.workspacePreferences.setA4ReferenceVisible(true)

  appState.workspacePreferences.setA4ReferenceOrientation(.landscape)
  try capture("swift-wide-a4-landscape.png")
  appState.workspacePreferences.setA4ReferenceOrientation(.portrait)

  appState.workspacePreferences.setGridSnapEnabled(false)
  try capture("swift-wide-grid-snap-off.png")
  appState.workspacePreferences.setGridSnapEnabled(true)

  appState.workspacePreferences.setPointSnapEnabled(false)
  try capture("swift-wide-point-snap-off.png")
}

@MainActor
private func captureConstraintHUD(_ outputDirectory: URL) throws {
  let line = lineEntity(
    id: "entity:verification-line",
    label: "線分",
    start: ModelPoint(xMM: -30, yMM: 0),
    end: ModelPoint(xMM: 30, yMM: 0)
  )
  let horizontal = ProjectConstraint(
    id: "constraint:horizontal",
    rawKind: "horizontal",
    kind: "水平",
    targets: [line.id],
    targetsJSON: #"[{"entity":"entity:verification-line"}]"#,
    valueMM: nil,
    valueDegrees: nil,
    valueParameterID: nil,
    status: .underConstrained
  )
  var state = makeDocumentState(
    name: "無題プロジェクト",
    entities: [line],
    constraints: [horizontal],
    constraintStatus: .underConstrained
  )
  state.canvasProjection = canvasProjection(
    constraintMarkers: [
      resolvedCanvasPoint(
        id: horizontal.id,
        position: ModelPoint(xMM: 0, yMM: 0)
      )
    ]
  )
  let appState = makeScreenshotAppState(documentState: state)
  appState.canvasPresentation.selectEntity(line.id)
  appState.canvasPresentation.setSelectedTool(.segmentLength)
  appState.canvasPresentation.setPendingConstraintValueDraft(
    PendingConstraintValueDraft(
      kind: "segmentLength",
      title: "線分長",
      prompt: "値 (mm)",
      targets: [["entity": line.id]],
      valueText: "60.00",
      unit: "mm",
      allowsParameterReference: false,
      entryMode: .fixedValue,
      anchorCanvasPoint: CGPoint(x: 420, y: 290)
    )
  )
  try renderWorkspace(
    appState,
    size: regularScreenshotSize,
    to: outputDirectory.appendingPathComponent("swift-constraint-hud.png")
  )
}

@MainActor
private func captureContextMenu(_ outputDirectory: URL) throws {
  let line = lineEntity(
    id: "entity:context-line",
    start: ModelPoint(xMM: -30, yMM: 0),
    end: ModelPoint(xMM: 30, yMM: 0)
  )
  let constraint = ProjectConstraint(
    id: "constraint:context-horizontal",
    rawKind: "horizontal",
    kind: "水平",
    targets: [line.id],
    targetsJSON: #"[{"entity":"entity:context-line"}]"#,
    valueMM: nil,
    valueDegrees: nil,
    valueParameterID: nil,
    status: .underConstrained
  )
  var state = makeDocumentState(
    name: "無題プロジェクト",
    entities: [line],
    constraints: [constraint],
    constraintStatus: .underConstrained
  )
  state.canvasProjection = canvasProjection(
    constraintMarkers: [resolvedCanvasPoint(id: constraint.id, position: .zero)]
  )
  let appState = makeScreenshotAppState(documentState: state)
  appState.canvasPresentation.selectConstraint(constraint.id)

  // A native NSMenu is a separate WindowServer window. Represent the same
  // item in-process so this visual fixture remains deterministic and does not
  // require Screen Recording permission.
  let comparisonView = ZStack(alignment: .topLeading) {
    workspaceView(appState)
    Text(AppStrings.tr("canvas.menu.delete_constraint"))
      .font(.system(size: 13))
      .foregroundStyle(Color(nsColor: .systemRed))
      .frame(width: 164, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(Color(nsColor: .windowBackgroundColor))
      .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .stroke(Color.black.opacity(0.14), lineWidth: 0.5)
      }
      .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
      .offset(x: regularScreenshotSize.width * 0.46, y: regularScreenshotSize.height * 0.48)
  }
  try renderScreenshot(
    comparisonView,
    size: regularScreenshotSize,
    to: outputDirectory.appendingPathComponent("swift-context-menu.png")
  )
}

@MainActor
private func capturePasteOptions(_ outputDirectory: URL) throws {
  let line = lineEntity(
    id: "entity:pasted-line",
    start: ModelPoint(xMM: -60, yMM: 55),
    end: ModelPoint(xMM: -5, yMM: 55)
  )
  let appState = makeScreenshotAppState(
    documentState: makeDocumentState(name: "無題プロジェクト", entities: [line])
  )
  appState.canvasPresentation.selectEntity(line.id)
  let clipboard = ClipboardBundle(
    export: SelectionClipboardExport(
      clipboardJson: #"{"selection":true}"#,
      rootCount: 1,
      anchorPoint: CorePoint(xMm: -32.5, yMm: 55),
      bounds: CoreBounds(
        minPoint: CorePoint(xMm: -60, yMm: 55),
        maxPoint: CorePoint(xMm: -5, yMm: 55)
      )
    )
  )
  appState.documentPresentation.setPasteOptions(
    PasteOptionsPresentation(
      clipboard: clipboard,
      sourceAnchor: ModelPoint(xMM: -32.5, yMM: 55),
      pasteNamespace: "verification-paste",
      cursorPoint: ModelPoint(xMM: -55, yMM: 55),
      canvasPoint: CGPoint(x: 390, y: 50),
      nearSourcePoint: ModelPoint(xMM: -27.5, yMM: 60),
      activeMode: .cursor
    )
  )
  try renderWorkspace(
    appState,
    size: regularScreenshotSize,
    to: outputDirectory.appendingPathComponent("swift-paste-options.png")
  )
}

@MainActor
private func captureFreeText(
  _ outputDirectory: URL,
  fileName: String,
  selectedTool: CanvasTool
) throws {
  let note = ProjectFreeText(
    id: "free-text:verification-note",
    content: "注記",
    positionMM: ModelPoint(xMM: -10, yMM: 10),
    fontSizeMM: 4
  )
  var state = makeDocumentState(name: "無題プロジェクト", freeTexts: [note])
  state.canvasProjection = canvasProjection(visibleFreeTextIDs: [note.id])
  let appState = makeScreenshotAppState(documentState: state)
  appState.canvasPresentation.selectFreeText(note.id)
  appState.canvasPresentation.setSelectedTool(selectedTool)
  appState.canvasPresentation.setFreeTextInlineEditRequestID(note.id)
  try renderWorkspace(
    appState,
    size: regularScreenshotSize,
    to: outputDirectory.appendingPathComponent(fileName)
  )
}

@MainActor
private func captureCompactDrawers(_ outputDirectory: URL) throws {
  let note = ProjectFreeText(
    id: "free-text:compact-note",
    content: "注記",
    positionMM: ModelPoint(xMM: -10, yMM: 10),
    fontSizeMM: 4
  )
  var state = makeDocumentState(name: "無題プロジェクト", freeTexts: [note])
  state.canvasProjection = canvasProjection(visibleFreeTextIDs: [note.id])

  let toolsState = makeScreenshotAppState(documentState: state)
  toolsState.workspaceLayout.setWindowLayoutMode(.compact)
  toolsState.workspaceLayout.setCompactDrawer(.tools)
  try renderWorkspace(
    toolsState,
    size: compactScreenshotSize,
    to: outputDirectory.appendingPathComponent("swift-compact-tools-drawer.png")
  )

  let inspectorState = makeScreenshotAppState(documentState: state)
  inspectorState.canvasPresentation.selectFreeText(note.id)
  inspectorState.workspaceLayout.setWindowLayoutMode(.compact)
  inspectorState.workspaceLayout.setCompactDrawer(.inspector)
  try renderWorkspace(
    inspectorState,
    size: compactScreenshotSize,
    to: outputDirectory.appendingPathComponent("swift-compact-inspector-drawer.png")
  )
}

@MainActor
private func captureLicenses(_ outputDirectory: URL) throws {
  let appState = makeScreenshotAppState()
  let comparisonView = ZStack {
    workspaceView(appState)
    Color.black.opacity(0.14)
    VStack(spacing: 0) {
      HStack {
        Text(AppStrings.tr("menu.open_source_licenses"))
          .font(.system(size: 16, weight: .semibold))
        Spacer()
      }
      .padding(.horizontal, 20)
      .frame(height: 52)
      Divider()
      OpenSourceLicensesDialog(notices: KawaCADLicensesPanel.noticeText())
    }
    .frame(width: 680, height: 520)
    .background(LeatherColors.panel)
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    .shadow(color: .black.opacity(0.24), radius: 18, x: 0, y: 8)
  }
  try renderScreenshot(
    comparisonView,
    size: regularScreenshotSize,
    to: outputDirectory.appendingPathComponent("swift-oss-licenses.png")
  )
}

@MainActor
private func captureLayerDeletion(_ outputDirectory: URL) throws {
  let cutLayer = defaultLayers()[0]
  let verificationLayer = ProjectLayer(
    id: "layer:verification",
    name: "検証レイヤー",
    kind: .construction,
    visible: true,
    printable: false,
    colorHex: "#64748b",
    strokeWidthMM: 0.13,
    linePattern: .dashed
  )
  let line = lineEntity(
    id: "entity:verification-layer-line",
    layerID: verificationLayer.id,
    start: ModelPoint(xMM: -30, yMM: 0),
    end: ModelPoint(xMM: 30, yMM: 0)
  )
  let appState = makeScreenshotAppState(
    documentState: makeDocumentState(
      name: "無題プロジェクト",
      layers: [cutLayer, verificationLayer],
      entities: [line]
    )
  )
  appState.actions.inspector.setInspectorTab(.layers)
  appState.documentPresentation.setLayerDeletionConfirmation(
    LayerDeletionConfirmation(layer: verificationLayer, entityCount: 1)
  )
  try renderWorkspace(
    appState,
    size: regularScreenshotSize,
    to: outputDirectory.appendingPathComponent("swift-layer-deletion-confirmation.png")
  )
}

@MainActor
private func captureInspectorManagementTabs(_ outputDirectory: URL) throws {
  let verificationLayer = ProjectLayer(
    id: "layer:verification",
    name: "検証レイヤー",
    kind: .construction,
    visible: true,
    printable: false,
    colorHex: "#6B7280",
    strokeWidthMM: 0.13,
    linePattern: .dashed
  )
  let sharedStyles = [
    ProjectSharedStyle(
      id: "style:outer-cut-line", name: "外形カット線", colorHex: "#111827",
      strokeWidthMM: 0.25, linePattern: .solid),
    ProjectSharedStyle(
      id: "style:stitch", name: "縫い線", colorHex: "#DC2626", strokeWidthMM: 0.2,
      linePattern: .dashed),
    ProjectSharedStyle(
      id: "style:fold", name: "折り線", colorHex: "#2563EB", strokeWidthMM: 0.2,
      linePattern: .dashed),
    ProjectSharedStyle(
      id: "style:center", name: "中心線", colorHex: "#16A34A", strokeWidthMM: 0.2,
      linePattern: .dotted),
    ProjectSharedStyle(
      id: "style:construction", name: "補助線", colorHex: "#6B7280", strokeWidthMM: 0.13,
      linePattern: .construction),
    ProjectSharedStyle(
      id: "style:dimension", name: "寸法線", colorHex: "#9333EA", strokeWidthMM: 0.2,
      linePattern: .solid),
  ]
  let parameter = ProjectParameter(
    id: "parameter:width",
    name: "幅",
    valueMM: 25,
    unit: "millimeter",
    memo: "",
    usageCount: 0,
    usedConstraintIDs: []
  )
  let outline = [
    lineEntity(
      id: "entity:part-bottom",
      start: ModelPoint(xMM: -40, yMM: -20),
      end: ModelPoint(xMM: 40, yMM: -20)
    ),
    lineEntity(
      id: "entity:part-right",
      start: ModelPoint(xMM: 40, yMM: -20),
      end: ModelPoint(xMM: 0, yMM: 40)
    ),
    lineEntity(
      id: "entity:part-left",
      start: ModelPoint(xMM: 0, yMM: 40),
      end: ModelPoint(xMM: -40, yMM: -20)
    ),
  ]
  let part = ProjectPart(
    id: "part:body",
    name: "本体",
    originMM: ModelPoint(xMM: 0, yMM: 1.67),
    outlineEntityIDs: outline.map(\.id),
    holeEntityIDGroups: [],
    entityIDs: outline.map(\.id),
    derivedElementIDs: [],
    freeTextIDs: [],
    measurementAnnotationIDs: [],
    quantity: 1
  )
  let managementState = makeDocumentState(
    name: "無題プロジェクト",
    layers: [defaultLayers()[0], verificationLayer],
    sharedStyles: sharedStyles,
    parameters: [parameter]
  )

  let layersState = makeScreenshotAppState(documentState: managementState)
  layersState.actions.inspector.setInspectorTab(.layers)
  layersState.inspectorPresentation.setSelectedLayerID(verificationLayer.id)
  try renderWorkspace(
    layersState,
    size: wideScreenshotSize,
    to: outputDirectory.appendingPathComponent("swift-inspector-layers.png")
  )

  let stylesState = makeScreenshotAppState(documentState: managementState)
  stylesState.actions.inspector.setInspectorTab(.sharedStyles)
  stylesState.inspectorPresentation.setSelectedSharedStyleID(sharedStyles[0].id)
  try renderWorkspace(
    stylesState,
    size: wideScreenshotSize,
    to: outputDirectory.appendingPathComponent("swift-inspector-shared-styles.png")
  )

  let parametersState = makeScreenshotAppState(documentState: managementState)
  parametersState.actions.inspector.setInspectorTab(.parameters)
  parametersState.inspectorPresentation.setSelectedParameterID(parameter.id)
  try renderWorkspace(
    parametersState,
    size: wideScreenshotSize,
    to: outputDirectory.appendingPathComponent("swift-inspector-parameters.png")
  )

  let partsState = makeScreenshotAppState(
    documentState: makeDocumentState(
      name: "無題プロジェクト",
      sharedStyles: sharedStyles,
      parameters: [parameter],
      parts: [part],
      entities: outline
    )
  )
  partsState.actions.inspector.setInspectorTab(.parts)
  partsState.inspectorPresentation.setSelectedPartID(part.id)
  try renderWorkspace(
    partsState,
    size: wideScreenshotSize,
    to: outputDirectory.appendingPathComponent("swift-inspector-parts.png")
  )
}

@MainActor
private func captureSelectionEntityEditors(_ outputDirectory: URL) throws {
  let layerID = defaultLayers()[0].id
  let style = ProjectSharedStyle(
    id: "style:outer-cut-line",
    name: "外形カット線",
    colorHex: "#111827",
    strokeWidthMM: 0.25,
    linePattern: .solid
  )
  let entities: [(String, CanvasEntity)] = [
    (
      "line",
      CanvasEntity(
        id: "entity:selection-line",
        label: "線分",
        kind: .lineSegment,
        layerID: layerID,
        styleID: style.id,
        geometry: .line(
          start: ModelPoint(xMM: -30, yMM: 0),
          end: ModelPoint(xMM: 30, yMM: 0),
          centerLine: false
        )
      )
    ),
    (
      "circle",
      CanvasEntity(
        id: "entity:selection-circle",
        label: "円",
        kind: .circle,
        layerID: layerID,
        styleID: style.id,
        geometry: .circle(center: .zero, radiusMM: 25)
      )
    ),
    (
      "arc",
      CanvasEntity(
        id: "entity:selection-arc",
        label: "円弧",
        kind: .arc,
        layerID: layerID,
        styleID: style.id,
        geometry: .arc(
          center: .zero,
          radiusMM: 25,
          startAngleRad: 0,
          sweepAngleRad: .pi / 2
        )
      )
    ),
    (
      "point",
      CanvasEntity(
        id: "entity:selection-point",
        label: "点",
        kind: .point,
        layerID: layerID,
        styleID: style.id,
        geometry: .point(.zero)
      )
    ),
    (
      "center-line",
      CanvasEntity(
        id: "entity:selection-center-line",
        label: "中心線",
        kind: .centerLine,
        layerID: layerID,
        styleID: style.id,
        geometry: .line(
          start: ModelPoint(xMM: -30, yMM: 0),
          end: ModelPoint(xMM: 30, yMM: 0),
          centerLine: true
        )
      )
    ),
  ]

  for (name, entity) in entities {
    let appState = makeScreenshotAppState(
      documentState: makeDocumentState(
        name: "無題プロジェクト",
        sharedStyles: [style],
        entities: [entity]
      )
    )
    appState.canvasPresentation.selectEntity(entity.id)
    appState.canvasPresentation.setSelectedTool(.select)
    try renderWorkspace(
      appState,
      size: wideScreenshotSize,
      to: outputDirectory.appendingPathComponent("swift-selection-\(name).png")
    )
  }
}

@MainActor
private func captureRecoveryCandidates(_ outputDirectory: URL) throws {
  let originalTimeZone = NSTimeZone.default
  NSTimeZone.default = TimeZone(identifier: "Asia/Tokyo")!
  defer { NSTimeZone.default = originalTimeZone }

  let appState = makeScreenshotAppState()
  let candidates = [
    DocumentRecoveryCandidate(
      recoveryID: "recoverable",
      generationID: "generation-1",
      displayName: "カードケース",
      originalDocumentURL: URL(fileURLWithPath: "/projects/card-case.kawa"),
      updatedAt: Date(timeIntervalSince1970: 1_786_582_800),
      containerURL: URL(fileURLWithPath: "/tmp/recovery/recoverable"),
      metadataURL: URL(fileURLWithPath: "/tmp/recovery/recoverable/metadata.json"),
      status: .recoverable(
        snapshotURL: URL(fileURLWithPath: "/tmp/recovery/recoverable/snapshot.kawa")
      )
    ),
    DocumentRecoveryCandidate(
      recoveryID: "broken",
      generationID: nil,
      displayName: "破損した復旧候補",
      originalDocumentURL: nil,
      updatedAt: Date(timeIntervalSince1970: 1_786_582_200),
      containerURL: URL(fileURLWithPath: "/tmp/recovery/broken"),
      metadataURL: nil,
      status: .broken(details: "snapshot.kawa を読み込めません。")
    ),
  ]
  let chooser = DocumentRecoveryChooserState(candidates: candidates)
  appState.recoverySnapshotState.setChooser(chooser)
  let workspace = workspaceProps(appState)
  let dialogState = workspace.recoveryChooserState
  let dialogActions = workspace.recoveryChooserActions
  appState.recoverySnapshotState.setChooser(nil)
  let comparisonView = ZStack {
    workspaceView(appState)
    Color.black.opacity(0.14)
    RecoveryChooserDialog(
      state: dialogState,
      actions: dialogActions,
      chooser: chooser
    )
    .frame(width: 660, height: 400)
    .background(Color(nsColor: .windowBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    .shadow(color: .black.opacity(0.24), radius: 18, x: 0, y: 8)
  }
  try renderScreenshot(
    comparisonView,
    size: regularScreenshotSize,
    to: outputDirectory.appendingPathComponent("swift-recovery-candidates.png")
  )
}

@MainActor
private func capturePDFOutput(
  _ outputDirectory: URL,
  fileName: String = "swift-pdf-output-settings.png",
  appearanceName: NSAppearance.Name = .aqua,
  size: CGSize = regularScreenshotSize
) throws {
  let appState = makeScreenshotAppState()
  let presentationOptions = OutputPresentationOptions(
    orientation: .portrait,
    includeDimensionLabels: true,
    includeScaleGuide: true,
    rotationDeg: 0
  )
  let buildOptions = OutputBuildOptions(
    orientation: .portrait,
    includeDimensionLabels: true,
    includeScaleGuide: true,
    rotationDeg: 0,
    printableAreaMm: OutputPaperDefaults.pdfPrintableAreaMm(for: .portrait)
  )
  let buildResult = sampleOutputBuildResult(
    model: comparisonPDFOutputDocumentModel(),
    warnings: [
      OutputWarning(
        kind: .pageBoundaryCrossing,
        message: "ページ境界をまたぐ形状があります。"
      )
    ]
  )
  var draft = OutputRequestDraft(destination: .pdf, options: presentationOptions)
  draft.buildState = .ready(
    OutputRequestPreparedState(
      buildResult: buildResult,
      buildOptions: buildOptions,
      directPrintSession: nil
    )
  )
  appState.outputPresentation.setRequestDraft(draft)
  let workspace = workspaceProps(appState)
  let dialogState = workspace.outputRequestSheetState
  let dialogActions = workspace.outputRequestSheetActions
  appState.outputPresentation.setRequestDraft(nil)
  let comparisonView = ZStack {
    workspaceView(appState)
    Color.black.opacity(0.14)
    OutputDialog(state: dialogState, actions: dialogActions)
      .frame(width: 920, height: 640)
      .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
      .shadow(color: .black.opacity(0.24), radius: 18, x: 0, y: 8)
  }
  try renderScreenshot(
    comparisonView,
    size: size,
    to: outputDirectory.appendingPathComponent(fileName),
    appearanceName: appearanceName
  )
}

private func comparisonPDFOutputDocumentModel() -> OutputDocumentModel {
  let pageSize = OutputPaperDefaults.a4PageSizeMm(for: .portrait)
  let printableArea = OutputPaperDefaults.pdfPrintableAreaMm(for: .portrait)
  let circleStyle = OutputLayerStyle(
    stroke: OutputRGBA(red: 0.05, green: 0.32, blue: 0.78, alpha: 1),
    strokeWidthMm: 0.35,
    pattern: .dashed
  )
  return OutputDocumentModel(
    paperSize: .a4,
    orientation: .portrait,
    scale: .actualSize,
    pageCount: 1,
    pages: [
      OutputPage(
        widthMm: pageSize.widthMm,
        heightMm: pageSize.heightMm,
        rotationDeg: 0,
        printableAreaMm: printableArea,
        graphics: [
          OutputGraphic(
            entityId: "entity:comparison-line",
            kind: .lineSegment,
            geometry: .lineSegment(
              startMm: OutputPointMm(xMm: -35, yMm: -45),
              endMm: OutputPointMm(xMm: 35, yMm: -45)
            ),
            style: .default
          ),
          OutputGraphic(
            entityId: "entity:comparison-circle",
            kind: .circle,
            geometry: .circle(
              centerMm: OutputPointMm(xMm: 0, yMm: 15),
              radiusMm: 24
            ),
            style: circleStyle
          ),
        ],
        texts: [
          OutputText(
            kind: .freeText,
            content: "型紙プレビュー",
            positionMm: OutputPointMm(xMm: 0, yMm: 55),
            fontSizeMm: 4
          )
        ],
        guide: OutputGuide(
          startMm: OutputPointMm(xMm: -90, yMm: -130),
          endMm: OutputPointMm(xMm: -40, yMm: -130),
          label: "50mm",
          labelPositionMm: OutputPointMm(xMm: -65, yMm: -125)
        )
      )
    ]
  )
}

@MainActor
private func captureRepresentativeThemeMatrix(_ outputDirectory: URL) throws {
  let line = lineEntity(
    id: "entity:theme-matrix-line",
    start: ModelPoint(xMM: -35, yMM: 0),
    end: ModelPoint(xMM: 35, yMM: 0)
  )
  let selectedState = makeDocumentState(
    name: "無題プロジェクト",
    entities: [line]
  )

  for theme in ScreenshotTheme.allCases {
    let prefix = "swift-\(theme.rawValue)"

    let emptyState = makeScreenshotAppState()
    emptyState.workspaceLayout.setWindowLayoutMode(.compact)
    try renderWorkspace(
      emptyState,
      size: compactScreenshotSize,
      to: outputDirectory.appendingPathComponent("\(prefix)-compact-empty.png"),
      appearanceName: theme.appearanceName
    )

    let toolsState = makeScreenshotAppState()
    toolsState.workspaceLayout.setWindowLayoutMode(.compact)
    toolsState.workspaceLayout.setCompactDrawer(.tools)
    try renderWorkspace(
      toolsState,
      size: compactScreenshotSize,
      to: outputDirectory.appendingPathComponent("\(prefix)-compact-tools-drawer.png"),
      appearanceName: theme.appearanceName
    )

    let inspectorState = makeScreenshotAppState()
    inspectorState.workspaceLayout.setWindowLayoutMode(.compact)
    inspectorState.workspaceLayout.setCompactDrawer(.inspector)
    try renderWorkspace(
      inspectorState,
      size: compactScreenshotSize,
      to: outputDirectory.appendingPathComponent("\(prefix)-compact-inspector-drawer.png"),
      appearanceName: theme.appearanceName
    )

    let selectedInspectorState = makeScreenshotAppState(documentState: selectedState)
    selectedInspectorState.canvasPresentation.selectEntity(line.id)
    selectedInspectorState.workspaceLayout.setWindowLayoutMode(.regular)
    try renderWorkspace(
      selectedInspectorState,
      size: regularScreenshotSize,
      to: outputDirectory.appendingPathComponent("\(prefix)-regular-selected-inspector.png"),
      appearanceName: theme.appearanceName
    )

    try capturePDFOutput(
      outputDirectory,
      fileName: "\(prefix)-wide-dialog.png",
      appearanceName: theme.appearanceName,
      size: themeMatrixWideScreenshotSize
    )
  }
}

@MainActor
private func makeScreenshotAppState(
  documentState: LeatherDocumentState = makeDocumentState(name: "無題プロジェクト")
) -> AppCoordinator {
  let appState = AppCoordinator(
    documentAdapter: ScreenshotDocumentSessionAdapter(state: documentState),
    coreStatusProvider: { .connected(.init(fileFormatMajor: 1, schemaMajor: 2)) }
  )
  appState.workspacePreferences.setInspectorPanelVisible(true)
  appState.workspacePreferences.setDetailedToolsVisible(false)
  appState.workspacePreferences.setBottomWorkbenchVisible(false)
  appState.workspaceLayout.setToolPanelWidth(240)
  appState.workspaceLayout.setInspectorPanelWidth(440)
  appState.workspaceLayout.setWindowLayoutMode(.wide)
  for group in ToolPalette.allToolGroups {
    appState.workspacePreferences.setToolGroupCollapsed(
      !group.defaultExpanded,
      groupID: group.id
    )
  }
  return appState
}

private final class ScreenshotDocumentSessionAdapter: DocumentSessionAdapting {
  private var state: LeatherDocumentState

  var hasDocument = true
  var canUndo = false
  var canRedo = false
  var isDocumentDirty = false
  var documentURL: URL?

  init(state: LeatherDocumentState) {
    self.state = state
  }

  func recordAppliedState(_ state: LeatherDocumentState?) {
    guard let state else { return }
    self.state = state
    canUndo = state.history.canUndo
    canRedo = state.history.canRedo
  }

  func createNewDocument(viewMode: CanvasViewMode) -> LeatherCoreResult<
    LeatherDocumentState
  > {
    .success(state)
  }

  func openDocument(at url: URL, viewMode: CanvasViewMode) -> LeatherCoreResult<
    LeatherDocumentState
  > {
    .success(state)
  }

  func recoverDocument(
    from recoverySnapshotURL: URL,
    suggestedDocumentURL: URL?,
    viewMode: CanvasViewMode
  ) -> LeatherCoreResult<LeatherDocumentState> {
    .success(state)
  }

  func loadState(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState> {
    .success(state)
  }

  func saveDocument(to url: URL) -> LeatherCoreResult<Void> {
    .success(())
  }

  func writeSnapshot(to url: URL) -> LeatherCoreResult<Void> {
    .success(())
  }

  func previewCommand(_ payload: CoreDocumentCommand, viewMode: CanvasViewMode)
    -> LeatherCoreResult<LeatherDocumentState>
  {
    .success(state)
  }

  func preflightConstraint(kind: String, targets: [CoreConstraintTarget]) -> LeatherCoreResult<
    ConstraintPreflightResult
  > {
    .failure("unused in screenshots")
  }

  func preflightDerivedElement(
    kind: DerivedElementPreflightKind,
    hitEntityID: String?,
    selectedEntityIDs: [String],
    clickPoint: ModelPoint?
  ) -> LeatherCoreResult<DerivedElementPreflightResult> {
    .failure("unused in screenshots")
  }

  func evaluateMeasurement(annotationID: String) -> LeatherCoreResult<MeasurementEvaluation> {
    .failure("unused in screenshots")
  }

  func exportSelection(_ selection: CoreSelectionReference) -> LeatherCoreResult<
    SelectionClipboardExport
  > {
    .failure("unused in screenshots")
  }

  func applyCommand(_ payload: CoreDocumentCommand, viewMode: CanvasViewMode) -> LeatherCoreResult<
    LeatherDocumentState
  > {
    .success(state)
  }

  func undo(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState> {
    .success(state)
  }

  func redo(viewMode: CanvasViewMode) -> LeatherCoreResult<LeatherDocumentState> {
    .success(state)
  }

  func buildOutputDocumentModel(options: OutputBuildOptions) -> OutputResult<OutputBuildResult> {
    .success(sampleOutputBuildResult())
  }

  func renderPDF(outputDocumentModel: OutputDocumentModel) -> OutputResult<Data> {
    .success(Data("%PDF-1.4\n".utf8))
  }

  func renderPrint(outputDocumentModel: OutputDocumentModel) -> OutputResult<
    OutputPrintRenderData
  > {
    .success(samplePrintRenderData())
  }
}

@MainActor
private func workspaceProps(_ appState: AppCoordinator) -> WorkspaceViewPropsFactory {
  WorkspaceViewPropsFactory(
    actions: appState.actions,
    inspectorPresentation: appState.inspectorPresentation,
    canvasPresentation: appState.canvasPresentation
  )
}

@MainActor
private func workspaceView(_ appState: AppCoordinator) -> WorkspaceView {
  let workspace = workspaceProps(appState)
  return WorkspaceView(
    state: workspace.workspaceViewState,
    actions: workspace.workspaceViewActions
  )
}

@MainActor
private func renderWorkspace(
  _ appState: AppCoordinator,
  size: CGSize,
  to outputURL: URL,
  appearanceName: NSAppearance.Name = .aqua
) throws {
  try renderScreenshot(
    workspaceView(appState),
    size: size,
    to: outputURL,
    appearanceName: appearanceName
  )
}

@MainActor
private func renderScreenshot<Content: View>(
  _ content: Content,
  size: CGSize,
  to outputURL: URL,
  appearanceName: NSAppearance.Name = .aqua
) throws {
  let (window, hostingView) = try makeScreenshotWindow(
    content,
    size: size,
    appearanceName: appearanceName
  )
  defer { closeScreenshotWindow(window) }

  settle(hostingView)
  syncInlineTextEditor(in: hostingView)
  settle(hostingView)
  try capture(view: hostingView, logicalSize: size, to: outputURL)
}

@MainActor
private func makeScreenshotWindow<Content: View>(
  _ content: Content,
  size: CGSize,
  appearanceName: NSAppearance.Name
) throws -> (NSWindow, NSView) {
  let hostingView = NSHostingView(
    rootView:
      content
      .frame(width: size.width, height: size.height)
  )
  hostingView.frame = NSRect(origin: .zero, size: size)

  let window = NSWindow(
    contentRect: NSRect(origin: .zero, size: size),
    styleMask: [.borderless],
    backing: .buffered,
    defer: false
  )
  // The test owns this window through Swift ARC. AppKit's default `true` would
  // also release it from `close()`, causing an over-release when XCTest drains
  // the test's autorelease pool after all screenshots have been written.
  window.isReleasedWhenClosed = false
  window.contentView = hostingView
  let appearance = NSAppearance(named: appearanceName)
  window.appearance = appearance
  hostingView.appearance = appearance
  window.backgroundColor = .windowBackgroundColor
  return (window, hostingView)
}

@MainActor
private func closeScreenshotWindow(_ window: NSWindow) {
  if let sheet = window.attachedSheet {
    window.endSheet(sheet)
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
  }
  window.orderOut(nil)
  window.contentView = nil
  window.close()
  RunLoop.main.run(until: Date().addingTimeInterval(0.05))
}

@MainActor
private func settle(_ hostingView: NSView) {
  hostingView.layoutSubtreeIfNeeded()
  RunLoop.main.run(until: Date().addingTimeInterval(0.35))
  hostingView.layoutSubtreeIfNeeded()
}

@MainActor
private func syncInlineTextEditor(in view: NSView) {
  if let canvas = view as? LeatherCanvasView {
    canvas.syncInlineFreeTextEditorWithRequest()
    if !canvas.inlineFreeTextEditor.isEditing,
      let requestID = canvas.freeTextInlineEditRequestID,
      let freeText = canvas.freeTexts.first(where: { $0.id == requestID })
    {
      canvas.inlineFreeTextEditor.beginEditing(
        freeText,
        context: canvas.inlineTextEditorContext(in: canvas.pageRect(in: canvas.bounds)),
        in: canvas
      )
    }
    if let editor = canvas.subviews.first(where: { $0 is NSTextView }) as? NSTextView {
      // NSTextView's insertion caret is timer-driven. Freeze interaction only
      // after the editor is configured so the editing frame remains visible
      // without making the captured pixels depend on the blink phase.
      editor.insertionPointColor = .clear
      editor.isEditable = false
      editor.isSelectable = false
      editor.setSelectedRange(NSRange(location: 0, length: 0))
      editor.needsDisplay = true
      if !canvas.bounds.intersects(editor.frame) {
        editor.frame = editor.frame.offsetBy(
          dx: canvas.bounds.midX,
          dy: canvas.bounds.midY
        )
      }
    }
    canvas.layoutSubtreeIfNeeded()
    return
  }
  for subview in view.subviews {
    syncInlineTextEditor(in: subview)
  }
}

@MainActor
private func capture(view: NSView, logicalSize: CGSize, to outputURL: URL) throws {
  let bounds = NSRect(origin: .zero, size: logicalSize)
  view.frame = bounds
  view.layoutSubtreeIfNeeded()
  guard
    let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: Int(logicalSize.width),
      pixelsHigh: Int(logicalSize.height),
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bytesPerRow: 0,
      bitsPerPixel: 0
    )
  else {
    throw ScreenshotCaptureError.cannotAllocateBitmap
  }
  bitmap.size = logicalSize
  view.cacheDisplay(in: bounds, to: bitmap)

  guard let data = bitmap.representation(using: .png, properties: [:]) else {
    throw ScreenshotCaptureError.cannotEncodePNG
  }
  try data.write(to: outputURL, options: .atomic)
}

private func createComparisonImages(screenshotDirectory: URL) throws {
  let standardPanelSize = regularScreenshotSize
  let pairs: [(String, String, String, CGSize)] = [
    (
      "light-compact-empty", "swift-light-compact-empty.png",
      "tauri-light-compact-empty.jpg", compactScreenshotSize
    ),
    (
      "light-compact-tools-drawer", "swift-light-compact-tools-drawer.png",
      "tauri-light-compact-tools-drawer.jpg", compactScreenshotSize
    ),
    (
      "light-compact-inspector-drawer", "swift-light-compact-inspector-drawer.png",
      "tauri-light-compact-inspector-drawer.jpg", compactScreenshotSize
    ),
    (
      "light-regular-selected-inspector", "swift-light-regular-selected-inspector.png",
      "tauri-light-regular-selected-inspector.jpg", standardPanelSize
    ),
    (
      "light-wide-dialog", "swift-light-wide-dialog.png", "tauri-light-wide-dialog.jpg",
      themeMatrixWideScreenshotSize
    ),
    (
      "dark-compact-empty", "swift-dark-compact-empty.png",
      "tauri-dark-compact-empty.jpg", compactScreenshotSize
    ),
    (
      "dark-compact-tools-drawer", "swift-dark-compact-tools-drawer.png",
      "tauri-dark-compact-tools-drawer.jpg", compactScreenshotSize
    ),
    (
      "dark-compact-inspector-drawer", "swift-dark-compact-inspector-drawer.png",
      "tauri-dark-compact-inspector-drawer.jpg", compactScreenshotSize
    ),
    (
      "dark-regular-selected-inspector", "swift-dark-regular-selected-inspector.png",
      "tauri-dark-regular-selected-inspector.jpg", standardPanelSize
    ),
    (
      "dark-wide-dialog", "swift-dark-wide-dialog.png", "tauri-dark-wide-dialog.jpg",
      themeMatrixWideScreenshotSize
    ),
    ("initial", "swift-browser-initial.png", "tauri-browser-initial.jpg", standardPanelSize),
    (
      "detailed-tools-summary", "swift-detailed-tools-summary.png",
      "tauri-detailed-tools-summary.jpg", standardPanelSize
    ),
    (
      "wide-toolbar", "swift-wide-toolbar.png", "tauri-wide-toolbar.jpg",
      wideScreenshotSize
    ),
    (
      "wide-grid-off", "swift-wide-grid-off.png", "tauri-wide-grid-off.jpg",
      wideScreenshotSize
    ),
    (
      "wide-a4-reference-off", "swift-wide-a4-reference-off.png",
      "tauri-wide-a4-reference-off.jpg", wideScreenshotSize
    ),
    (
      "wide-a4-landscape", "swift-wide-a4-landscape.png", "tauri-wide-a4-landscape.jpg",
      wideScreenshotSize
    ),
    (
      "wide-grid-snap-off", "swift-wide-grid-snap-off.png", "tauri-wide-grid-snap-off.jpg",
      wideScreenshotSize
    ),
    (
      "wide-point-snap-off", "swift-wide-point-snap-off.png", "tauri-wide-point-snap-off.jpg",
      wideScreenshotSize
    ),
    ("constraint-hud", "swift-constraint-hud.png", "tauri-constraint-hud.jpg", standardPanelSize),
    ("context-menu", "swift-context-menu.png", "tauri-context-menu.jpg", standardPanelSize),
    ("paste-options", "swift-paste-options.png", "tauri-paste-options.jpg", standardPanelSize),
    (
      "free-text-default", "swift-free-text-default.png", "tauri-free-text-default.jpg",
      standardPanelSize
    ),
    (
      "inline-text-editor", "swift-inline-text-editor.png", "tauri-inline-text-editor.jpg",
      standardPanelSize
    ),
    (
      "compact-tools-drawer", "swift-compact-tools-drawer.png", "tauri-compact-tools-drawer.jpg",
      standardPanelSize
    ),
    (
      "compact-inspector-drawer", "swift-compact-inspector-drawer.png",
      "tauri-compact-inspector-drawer.jpg", standardPanelSize
    ),
    ("oss-licenses", "swift-oss-licenses.png", "tauri-oss-licenses.jpg", standardPanelSize),
    (
      "layer-deletion-confirmation", "swift-layer-deletion-confirmation.png",
      "tauri-layer-deletion-confirmation.jpg", standardPanelSize
    ),
    (
      "inspector-layers", "swift-inspector-layers.png", "tauri-inspector-layers.jpg",
      wideScreenshotSize
    ),
    (
      "inspector-shared-styles", "swift-inspector-shared-styles.png",
      "tauri-inspector-shared-styles.jpg", wideScreenshotSize
    ),
    (
      "inspector-parameters", "swift-inspector-parameters.png",
      "tauri-inspector-parameters.jpg", wideScreenshotSize
    ),
    (
      "inspector-parts", "swift-inspector-parts.png", "tauri-inspector-parts.jpg",
      wideScreenshotSize
    ),
    (
      "selection-line", "swift-selection-line.png", "tauri-selection-line.jpg",
      wideScreenshotSize
    ),
    (
      "selection-circle", "swift-selection-circle.png", "tauri-selection-circle.jpg",
      wideScreenshotSize
    ),
    (
      "selection-arc", "swift-selection-arc.png", "tauri-selection-arc.jpg",
      wideScreenshotSize
    ),
    (
      "selection-point", "swift-selection-point.png", "tauri-selection-point.jpg",
      wideScreenshotSize
    ),
    (
      "selection-center-line", "swift-selection-center-line.png",
      "tauri-selection-center-line.jpg", wideScreenshotSize
    ),
    (
      "recovery-candidates", "swift-recovery-candidates.png", "tauri-recovery-candidates.jpg",
      standardPanelSize
    ),
    (
      "pdf-output-settings", "swift-pdf-output-settings.png", "tauri-pdf-output-settings.jpg",
      standardPanelSize
    ),
  ]
  let comparisonDirectory =
    screenshotDirectory
    .deletingLastPathComponent()
    .appendingPathComponent("comparisons", isDirectory: true)
  try FileManager.default.createDirectory(
    at: comparisonDirectory,
    withIntermediateDirectories: true
  )

  for (name, swiftFileName, tauriFileName, panelSize) in pairs {
    let swiftURL = screenshotDirectory.appendingPathComponent(swiftFileName)
    let tauriURL = screenshotDirectory.appendingPathComponent(tauriFileName)
    guard let swiftImage = NSImage(contentsOf: swiftURL),
      let tauriImage = NSImage(contentsOf: tauriURL)
    else {
      continue
    }
    try renderComparisonImage(
      swiftImage: swiftImage,
      tauriImage: tauriImage,
      panelSize: panelSize,
      to: comparisonDirectory.appendingPathComponent("comparison-\(name).png")
    )
  }
}

private func renderComparisonImage(
  swiftImage: NSImage,
  tauriImage: NSImage,
  panelSize: CGSize,
  to outputURL: URL
) throws {
  let headerHeight: CGFloat = 40
  let outputSize = CGSize(width: panelSize.width * 2, height: panelSize.height + headerHeight)
  guard
    let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: Int(outputSize.width),
      pixelsHigh: Int(outputSize.height),
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bytesPerRow: 0,
      bitsPerPixel: 0
    ),
    let context = NSGraphicsContext(bitmapImageRep: bitmap)
  else {
    throw ScreenshotCaptureError.cannotAllocateBitmap
  }
  bitmap.size = outputSize

  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = context
  NSColor.windowBackgroundColor.setFill()
  NSBezierPath(rect: NSRect(origin: .zero, size: outputSize)).fill()
  drawAspectFit(swiftImage, in: CGRect(origin: .zero, size: panelSize))
  drawAspectFit(
    tauriImage,
    in: CGRect(x: panelSize.width, y: 0, width: panelSize.width, height: panelSize.height)
  )

  NSColor.separatorColor.setFill()
  NSBezierPath(
    rect: CGRect(x: panelSize.width - 0.5, y: 0, width: 1, height: outputSize.height)
  ).fill()
  let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
    .foregroundColor: NSColor.labelColor,
  ]
  drawCenteredLabel(
    "Swift / macOS",
    in: CGRect(x: 0, y: panelSize.height, width: panelSize.width, height: headerHeight),
    attributes: attributes
  )
  drawCenteredLabel(
    "Tauri",
    in: CGRect(
      x: panelSize.width,
      y: panelSize.height,
      width: panelSize.width,
      height: headerHeight
    ),
    attributes: attributes
  )
  context.flushGraphics()
  NSGraphicsContext.restoreGraphicsState()

  guard let data = bitmap.representation(using: .png, properties: [:]) else {
    throw ScreenshotCaptureError.cannotEncodePNG
  }
  try data.write(to: outputURL, options: .atomic)
}

private func drawAspectFit(_ image: NSImage, in bounds: CGRect) {
  guard image.size.width > 0, image.size.height > 0 else { return }
  let scale = min(bounds.width / image.size.width, bounds.height / image.size.height)
  let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
  let destination = CGRect(
    x: bounds.midX - size.width / 2,
    y: bounds.midY - size.height / 2,
    width: size.width,
    height: size.height
  )
  image.draw(
    in: destination,
    from: CGRect(origin: .zero, size: image.size),
    operation: .copy,
    fraction: 1
  )
}

private func drawCenteredLabel(
  _ label: String,
  in bounds: CGRect,
  attributes: [NSAttributedString.Key: Any]
) {
  let attributed = NSAttributedString(string: label, attributes: attributes)
  let size = attributed.size()
  attributed.draw(
    at: CGPoint(
      x: bounds.midX - size.width / 2,
      y: bounds.midY - size.height / 2
    )
  )
}

private struct ScreenshotPreferenceSnapshot {
  let values: [String: Any]
  let missingKeys: Set<String>

  static func capture(userDefaults: UserDefaults = .standard) -> ScreenshotPreferenceSnapshot {
    let keys = preferenceKeys
    var values: [String: Any] = [:]
    var missingKeys: Set<String> = []
    for key in keys {
      if let value = userDefaults.object(forKey: key) {
        values[key] = value
      } else {
        missingKeys.insert(key)
      }
    }
    return ScreenshotPreferenceSnapshot(values: values, missingKeys: missingKeys)
  }

  func restore(userDefaults: UserDefaults = .standard) {
    for key in Self.preferenceKeys {
      if missingKeys.contains(key) {
        userDefaults.removeObject(forKey: key)
      } else if let value = values[key] {
        userDefaults.set(value, forKey: key)
      }
    }
  }

  private static var preferenceKeys: [String] {
    [
      WorkspacePreferencesAdapter.showsDetailedToolsKey,
      WorkspacePreferencesAdapter.inspectorPanelVisibleKey,
      WorkspacePreferencesAdapter.toolPanelWidthKey,
      WorkspacePreferencesAdapter.inspectorPanelWidthKey,
    ]
      + ToolPalette.allToolGroups.map {
        WorkspacePreferencesAdapter.toolGroupCollapsedKey($0.id)
      }
  }
}

private enum ScreenshotCaptureError: Error {
  case cannotAllocateBitmap
  case cannotEncodePNG
}
