import AppKit
import KawaCADOutput
import SwiftUI
import XCTest

@testable import KawaCADApp

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

private enum ComponentFixtureKind {
  case toolbar(CADToolbarDensity)
  case toolPalette
  case canvas
  case inspector
  case inspectorParametersEmpty
  case summary
  case constraintHUD
  case pasteOptions
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

    try captureIndependentComponents(outputDirectory)
    try createComparisonImages(screenshotDirectory: outputDirectory)
  }
}

@MainActor
private func captureIndependentComponents(_ outputDirectory: URL) throws {
  let line = lineEntity(
    id: "entity:comparison-line",
    label: "線分",
    start: ModelPoint(xMM: -70, yMM: -20),
    end: ModelPoint(xMM: 70, yMM: 20)
  )
  let parameter = ProjectParameter(
    id: "parameter:width",
    name: "幅",
    valueMM: 25,
    unit: "millimeter",
    memo: "",
    usageCount: 0,
    usedConstraintIDs: []
  )

  for theme in ScreenshotTheme.allCases {
    let suffix = theme.rawValue
    let appearanceName = theme.appearanceName

    let expandedToolbar = makeScreenshotAppState()
    expandedToolbar.workspaceLayout.setWindowLayoutMode(.wide)
    try renderComponentFixture(
      expandedToolbar,
      kind: .toolbar(.expanded),
      size: CGSize(width: 1532, height: 54),
      to: outputDirectory.appendingPathComponent("swift-toolbar-expanded-\(suffix).png"),
      appearanceName: appearanceName
    )

    let condensedToolbar = makeScreenshotAppState()
    condensedToolbar.workspaceLayout.setWindowLayoutMode(.regular)
    try renderComponentFixture(
      condensedToolbar,
      kind: .toolbar(.condensed),
      size: CGSize(width: 900, height: 54),
      to: outputDirectory.appendingPathComponent("swift-toolbar-condensed-\(suffix).png"),
      appearanceName: appearanceName
    )

    let basicPalette = makeScreenshotAppState()
    basicPalette.workspacePreferences.setDetailedToolsVisible(false)
    try renderComponentFixture(
      basicPalette,
      kind: .toolPalette,
      size: CGSize(width: 240, height: 800),
      to: outputDirectory.appendingPathComponent("swift-tool-palette-basic-\(suffix).png"),
      appearanceName: appearanceName
    )

    let detailedPalette = makeScreenshotAppState()
    detailedPalette.workspacePreferences.setDetailedToolsVisible(true)
    for group in ToolPalette.allToolGroups {
      detailedPalette.workspacePreferences.setToolGroupCollapsed(false, groupID: group.id)
    }
    try renderComponentFixture(
      detailedPalette,
      kind: .toolPalette,
      size: CGSize(width: 240, height: 800),
      to: outputDirectory.appendingPathComponent("swift-tool-palette-detailed-\(suffix).png"),
      appearanceName: appearanceName
    )

    let emptyCanvas = makeScreenshotAppState()
    try renderComponentFixture(
      emptyCanvas,
      kind: .canvas,
      size: CGSize(width: 800, height: 520),
      to: outputDirectory.appendingPathComponent("swift-canvas-empty-\(suffix).png"),
      appearanceName: appearanceName
    )

    let geometryState = makeScreenshotAppState(
      documentState: makeDocumentState(name: "比較用ドキュメント", entities: [line])
    )
    geometryState.canvasPresentation.selectEntity(line.id)
    try renderComponentFixture(
      geometryState,
      kind: .canvas,
      size: CGSize(width: 800, height: 520),
      to: outputDirectory.appendingPathComponent("swift-canvas-geometry-\(suffix).png"),
      appearanceName: appearanceName
    )

    let inspectorState = makeScreenshotAppState(
      documentState: makeDocumentState(
        name: "比較用ドキュメント",
        parameters: [parameter],
        entities: [line]
      )
    )
    inspectorState.canvasPresentation.selectEntity(line.id)
    try renderComponentFixture(
      inspectorState,
      kind: .inspector,
      size: CGSize(width: 520, height: 820),
      to: outputDirectory.appendingPathComponent("swift-inspector-selection-\(suffix).png"),
      appearanceName: appearanceName
    )

    let emptyParametersState = makeScreenshotAppState(
      documentState: makeDocumentState(name: "比較用ドキュメント")
    )
    try renderComponentFixture(
      emptyParametersState,
      kind: .inspectorParametersEmpty,
      size: CGSize(width: 520, height: 280),
      to: outputDirectory.appendingPathComponent("swift-inspector-parameters-empty-\(suffix).png"),
      appearanceName: appearanceName
    )

    let summaryState = makeScreenshotAppState(
      documentState: makeDocumentState(
        name: "比較用ドキュメント",
        parameters: [parameter],
        entities: [line]
      )
    )
    summaryState.canvasPresentation.selectEntity(line.id)
    try renderComponentFixture(
      summaryState,
      kind: .summary,
      size: CGSize(width: 1032, height: 84),
      to: outputDirectory.appendingPathComponent("swift-summary-\(suffix).png"),
      appearanceName: appearanceName
    )

    try captureConstraintHUD(
      outputDirectory,
      fileName: "swift-constraint-hud-\(suffix).png",
      appearanceName: appearanceName
    )
    try captureContextMenu(
      outputDirectory,
      fileName: "swift-context-menu-\(suffix).png",
      appearanceName: appearanceName
    )
    try capturePasteOptions(
      outputDirectory,
      fileName: "swift-paste-options-\(suffix).png",
      appearanceName: appearanceName
    )
    try captureLicenses(
      outputDirectory,
      fileName: "swift-licenses-dialog-\(suffix).png",
      appearanceName: appearanceName
    )
    try captureRecoveryCandidates(
      outputDirectory,
      fileName: "swift-recovery-dialog-\(suffix).png",
      appearanceName: appearanceName
    )
    try captureLayerDeletion(
      outputDirectory,
      fileName: "swift-layer-deletion-dialog-\(suffix).png",
      appearanceName: appearanceName,
      size: CGSize(width: 360, height: 160)
    )
    try capturePDFOutput(
      outputDirectory,
      fileName: "swift-pdf-dialog-\(suffix).png",
      appearanceName: appearanceName
    )
  }
}

@MainActor
private func captureConstraintHUD(
  _ outputDirectory: URL,
  fileName: String = "swift-constraint-hud.png",
  appearanceName: NSAppearance.Name = .aqua
) throws {
  let size = CGSize(width: 190, height: 46)
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
  try renderComponentFixture(
    appState,
    kind: .constraintHUD,
    size: size,
    to: outputDirectory.appendingPathComponent(fileName),
    appearanceName: appearanceName
  )
}

@MainActor
private func captureContextMenu(
  _ outputDirectory: URL,
  fileName: String = "swift-context-menu.png",
  appearanceName: NSAppearance.Name = .aqua
) throws {
  // A native NSMenu is a separate WindowServer window. Represent the same
  // item in-process so this visual fixture remains deterministic and does not
  // require Screen Recording permission.
  let comparisonView = Text(AppStrings.tr("canvas.menu.delete_constraint"))
    .font(.system(size: 13))
    .foregroundStyle(Color(nsColor: .systemRed))
    .padding(.horizontal, 8)
    .frame(width: 120, height: 40, alignment: .leading)
    .background(Color(nsColor: .windowBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 6, style: .continuous)
        .stroke(Color.black.opacity(0.14), lineWidth: 0.5)
    }
    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
  try renderScreenshot(
    comparisonView,
    size: CGSize(width: 120, height: 40),
    to: outputDirectory.appendingPathComponent(fileName),
    appearanceName: appearanceName
  )
}

@MainActor
private func capturePasteOptions(
  _ outputDirectory: URL,
  fileName: String = "swift-paste-options.png",
  appearanceName: NSAppearance.Name = .aqua
) throws {
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
  try renderComponentFixture(
    appState,
    kind: .pasteOptions,
    size: CGSize(width: 172, height: 28),
    to: outputDirectory.appendingPathComponent(fileName),
    appearanceName: appearanceName
  )
}

@MainActor
private func captureLicenses(
  _ outputDirectory: URL,
  fileName: String = "swift-oss-licenses.png",
  appearanceName: NSAppearance.Name = .aqua
) throws {
  let comparisonView = VStack(spacing: 0) {
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
  try renderScreenshot(
    comparisonView,
    size: CGSize(width: 680, height: 520),
    to: outputDirectory.appendingPathComponent(fileName),
    appearanceName: appearanceName
  )
}

@MainActor
private func captureLayerDeletion(
  _ outputDirectory: URL,
  fileName: String = "swift-layer-deletion-confirmation.png",
  appearanceName: NSAppearance.Name = .aqua,
  size: CGSize = CGSize(width: 300, height: 150)
) throws {
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
  let confirmation = LayerDeletionConfirmation(layer: verificationLayer, entityCount: 1)
  // SwiftUI's confirmationDialog is a separate native presentation and is not
  // included when an NSHostingView is drawn into a bitmap. Keep this fixture
  // in-process, just like the native context-menu fixture above.
  let comparisonView = VStack(alignment: .leading, spacing: 12) {
    Text(AppStrings.tr("dialog.delete_layer_title", verificationLayer.name))
      .font(.system(size: 14, weight: .semibold))
    Text(confirmation.message)
      .font(.system(size: 12))
      .foregroundStyle(LeatherColors.secondaryInk)
    HStack(spacing: 8) {
      Spacer()
      Button(AppStrings.tr("common.cancel")) {}
        .buttonStyle(.bordered)
      Button(AppStrings.tr("common.delete")) {}
        .buttonStyle(.borderedProminent)
        .tint(.red)
    }
  }
  .padding(18)
  .frame(width: size.width, alignment: .topLeading)
  .background(Color(nsColor: .windowBackgroundColor))
  .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
  .shadow(color: .black.opacity(0.24), radius: 18, x: 0, y: 8)
  try renderScreenshot(
    comparisonView,
    size: size,
    to: outputDirectory.appendingPathComponent(fileName),
    appearanceName: appearanceName
  )
}

@MainActor
private func captureRecoveryCandidates(
  _ outputDirectory: URL,
  fileName: String = "swift-recovery-candidates.png",
  appearanceName: NSAppearance.Name = .aqua
) throws {
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
  let comparisonView = RecoveryChooserDialog(
    state: dialogState,
    actions: dialogActions,
    chooser: chooser
  )
  .frame(width: 660, height: 400)
  .background(Color(nsColor: .windowBackgroundColor))
  .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
  .shadow(color: .black.opacity(0.24), radius: 18, x: 0, y: 8)
  try renderScreenshot(
    comparisonView,
    size: CGSize(width: 660, height: 400),
    to: outputDirectory.appendingPathComponent(fileName),
    appearanceName: appearanceName
  )
}

@MainActor
private func capturePDFOutput(
  _ outputDirectory: URL,
  fileName: String = "swift-pdf-output-settings.png",
  appearanceName: NSAppearance.Name = .aqua
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
  let dialogSize = CGSize(width: 920, height: 640)
  let comparisonView = OutputDialog(state: dialogState, actions: dialogActions)
    .frame(width: dialogSize.width, height: dialogSize.height)
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    .shadow(color: .black.opacity(0.24), radius: 18, x: 0, y: 8)
  try renderScreenshot(
    comparisonView,
    size: dialogSize,
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
private func renderComponentFixture(
  _ appState: AppCoordinator,
  kind: ComponentFixtureKind,
  size: CGSize,
  to outputURL: URL,
  appearanceName: NSAppearance.Name = .aqua
) throws {
  let workspace = workspaceProps(appState)
  let state = workspace.workspaceViewState
  let actions = workspace.workspaceViewActions

  let content: AnyView
  var renderToFittingSize = false
  switch kind {
  case .toolbar(let density):
    content = AnyView(
      CADToolbar(
        state: state.toolbarState,
        actions: actions.toolbarActions,
        workspaceLayoutMode: state.windowLayoutMode,
        density: density
      )
      .background(LeatherColors.panel)
    )
  case .toolPalette:
    content = AnyView(
      ToolPalette(
        state: state.toolPaletteState,
        actions: actions.toolPaletteActions,
        width: size.width
      )
    )
  case .inspector:
    content = AnyView(
      WorkspaceInspector(model: state.inspectorPanelModel, width: size.width)
    )
  case .inspectorParametersEmpty:
    content = AnyView(
      InspectorParametersTab(appState: state.inspectorPanelModel.parameters)
        .frame(width: size.width, alignment: .topLeading)
    )
    renderToFittingSize = true
  case .summary:
    content = AnyView(BottomWorkbench(state: state.bottomWorkbenchState))
  case .constraintHUD:
    content = AnyView(
      ValueEntryDialogPresenter(
        state: state.constraintEntryHUDState,
        actions: actions.constraintEntryHUDActions,
        standalone: true
      )
    )
  case .pasteOptions:
    guard let presentation = state.pasteOptionsPresentation else {
      throw ScreenshotCaptureError.missingFixtureState("paste-options")
    }
    let standalonePresentation = PasteOptionsPresentation(
      clipboard: presentation.clipboard,
      sourceAnchor: presentation.sourceAnchor,
      pasteNamespace: presentation.pasteNamespace,
      cursorPoint: presentation.cursorPoint,
      canvasPoint: nil,
      nearSourcePoint: presentation.nearSourcePoint,
      activeMode: presentation.activeMode
    )
    content = AnyView(
      ZStack(alignment: .topLeading) {
        PasteOptionsOverlay(
          presentation: standalonePresentation,
          selectMode: actions.selectPastePlacement,
          dismiss: actions.dismissPasteOptions,
          standalone: true
        )
      }
      .background(LeatherColors.canvas)
    )
    renderToFittingSize = true
  case .canvas:
    content = AnyView(
      CADCanvas(
        renderInput: state.canvasRenderInput,
        interactionInput: state.canvasInteractionInput,
        actions: actions.canvasActionGroups
      )
      .background(LeatherColors.canvas)
    )
  }

  if renderToFittingSize {
    try renderFittedScreenshot(content, to: outputURL, appearanceName: appearanceName)
  } else {
    try renderScreenshot(content, size: size, to: outputURL, appearanceName: appearanceName)
  }
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
private func renderFittedScreenshot<Content: View>(
  _ content: Content,
  to outputURL: URL,
  appearanceName: NSAppearance.Name = .aqua
) throws {
  let sizingView = NSHostingView(rootView: content)
  sizingView.layoutSubtreeIfNeeded()
  let fittingSize = sizingView.fittingSize
  let size = CGSize(
    width: max(1, ceil(fittingSize.width)),
    height: max(1, ceil(fittingSize.height))
  )
  try renderScreenshot(content, size: size, to: outputURL, appearanceName: appearanceName)
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
  try capture(
    view: view,
    rect: NSRect(origin: .zero, size: logicalSize),
    to: outputURL
  )
}

@MainActor
private func capture(view: NSView, rect: NSRect, to outputURL: URL) throws {
  view.layoutSubtreeIfNeeded()
  let captureRect = rect.integral
  guard
    let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: max(1, Int(captureRect.width)),
      pixelsHigh: max(1, Int(captureRect.height)),
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
  bitmap.size = captureRect.size
  view.cacheDisplay(in: captureRect, to: bitmap)

  guard let data = bitmap.representation(using: .png, properties: [:]) else {
    throw ScreenshotCaptureError.cannotEncodePNG
  }
  try data.write(to: outputURL, options: .atomic)
}

private func createComparisonImages(screenshotDirectory: URL) throws {
  let screenshotNames = try FileManager.default.contentsOfDirectory(
    at: screenshotDirectory,
    includingPropertiesForKeys: nil
  )
  .map(\.lastPathComponent)
  .filter { $0.hasPrefix("tauri-") && $0.hasSuffix(".jpg") }
  .sorted()
  let comparisonDirectory =
    screenshotDirectory
    .deletingLastPathComponent()
    .appendingPathComponent("comparisons", isDirectory: true)
  try FileManager.default.createDirectory(
    at: comparisonDirectory,
    withIntermediateDirectories: true
  )

  for tauriFileName in screenshotNames {
    let key = String(tauriFileName.dropFirst("tauri-".count).dropLast(".jpg".count))
    let swiftFileName = "swift-\(key).png"
    let swiftURL = screenshotDirectory.appendingPathComponent(swiftFileName)
    let tauriURL = screenshotDirectory.appendingPathComponent(tauriFileName)
    guard let swiftImage = NSImage(contentsOf: swiftURL),
      let tauriImage = NSImage(contentsOf: tauriURL)
    else {
      continue
    }
    let panelSize = CGSize(
      width: max(swiftImage.size.width, tauriImage.size.width),
      height: max(swiftImage.size.height, tauriImage.size.height)
    )
    try renderComparisonImage(
      swiftImage: swiftImage,
      tauriImage: tauriImage,
      panelSize: panelSize,
      to: comparisonDirectory.appendingPathComponent("comparison-\(key).png")
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
      WorkspacePreferencesAdapter.toolPaletteVisibleKey,
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
  case missingFixtureState(String)
}
