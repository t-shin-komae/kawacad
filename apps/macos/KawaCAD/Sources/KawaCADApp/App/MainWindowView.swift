import KawaCADOutput
import SwiftUI

struct MainWindowView: View {
  @EnvironmentObject private var appState: AppCoordinator

  var body: some View {
    ObservedWorkspaceRoot(appState: appState)
  }
}

/// SwiftUI equivalent of React re-rendering from the individual hooks used by
/// `MainWindowView.tsx`. The coordinator supplies actions and derived props, while each
/// feature state remains independently observable.
private struct ObservedWorkspaceRoot: View {
  let appState: AppCoordinator
  @ObservedObject private var cadSession: CadSessionState
  @ObservedObject private var annotationSelection: AnnotationSelectionState
  @ObservedObject private var canvasPresentation: CanvasPresentationState
  @ObservedObject private var documentPresentation: DocumentPresentationState
  @ObservedObject private var errorPresentation: AppErrorPresentationState
  @ObservedObject private var inspectorPresentation: InspectorPresentationState
  @ObservedObject private var outputPresentation: OutputPresentationState
  @ObservedObject private var recoverySnapshot: RecoverySnapshotState
  @ObservedObject private var workspacePreferences: WorkspacePreferencesState
  @ObservedObject private var workspaceLayout: WorkspaceLayoutState
  @ObservedObject private var partLibrary: PartLibraryState

  init(appState: AppCoordinator) {
    self.appState = appState
    cadSession = appState.cadSession
    annotationSelection = appState.annotationSelection
    canvasPresentation = appState.canvasPresentation
    documentPresentation = appState.documentPresentation
    errorPresentation = appState.errorPresentationState
    inspectorPresentation = appState.inspectorPresentation
    outputPresentation = appState.outputPresentation
    recoverySnapshot = appState.recoverySnapshotState
    workspacePreferences = appState.workspacePreferences
    workspaceLayout = appState.workspaceLayout
    partLibrary = appState.partLibraryState
  }

  var body: some View {
    let workspace = WorkspaceViewPropsFactory(
      actions: appState.actions,
      inspectorPresentation: inspectorPresentation,
      canvasPresentation: canvasPresentation
    )
    WorkspaceView(
      state: workspace.workspaceViewState,
      actions: workspace.workspaceViewActions
    )
    .background {
      WindowStateBridge(
        title: appState.actions.document.documentWindowPresentation.title,
        accessibilityLabel: appState.actions.document.documentWindowPresentation.accessibilityLabel,
        representedURL: appState.actions.document.documentWindowPresentation.documentURL,
        isDocumentEdited: appState.actions.document.documentWindowPresentation.isDocumentEdited,
        lifecycleController: appState.documentLifecycleController
      )
    }
  }
}

struct WorkspaceView: View {
  let state: WorkspaceViewState
  let actions: WorkspaceViewActions
  @State private var toolResizeBaseWidth: CGFloat?

  var body: some View {
    GeometryReader { geometry in
      let policy = WindowLayoutPolicy.make(
        contentWidth: geometry.size.width,
        storedToolWidth: state.toolPanelWidth,
        storedInspectorWidth: state.inspectorPanelWidth,
        previousMode: state.windowLayoutMode,
        toolPaletteVisible: state.toolbarState.toolPaletteVisible
      )

      HStack(spacing: 0) {
        if policy.toolDockVisible {
          ToolPalette(
            state: state.toolPaletteState,
            actions: actions.toolPaletteActions,
            width: policy.toolDockWidth
          )
          .zIndex(10)
          PanelResizeHandle(alignment: .trailing) { translation in
            let base = toolResizeBaseWidth ?? policy.toolDockWidth
            toolResizeBaseWidth = toolResizeBaseWidth ?? base
          } onEnded: { translation in
            if let base = toolResizeBaseWidth {
              let proposedWidth = base + translation.width
              actions.setToolPanelWidth(
                WindowLayoutPolicy.snappedToolWidth(
                  proposedWidth,
                  for: policy.mode
                )
              )
            }
            toolResizeBaseWidth = nil
          } onKeyboardAdjust: { delta in
            actions.setToolPanelWidth(
              WindowLayoutPolicy.toolWidthAfterKeyboardAdjustment(
                currentWidth: policy.toolDockWidth,
                delta: delta,
                for: policy.mode
              )
            )
          }
        }

        VStack(spacing: 0) {
          topChrome(layoutMode: policy.mode)
            .zIndex(1)
          ZStack(alignment: .top) {
            WorkspaceCanvasLayout(
              state: WorkspaceCanvasLayoutState(
                inspectorPanelWidth: state.inspectorPanelWidth,
                inspectorPanelVisible: state.inspectorPanelVisible,
                compactDrawer: state.compactDrawer,
                toolPaletteState: state.toolPaletteState
              ),
              actions: WorkspaceCanvasLayoutActions(
                setInspectorPanelWidth: actions.setInspectorPanelWidth,
                showCompactDrawer: actions.showCompactDrawer,
                toolPaletteActions: actions.toolPaletteActions
              ),
              policy: policy,
              canvasColumn: canvasColumn,
              inspectorPanel: { inspectorPanel(width: $0) }
            )

            WorkspaceBanners(
              recoveryBanner: state.recoveryBanner,
              errorPresentation: state.errorPresentation,
              onRetryRecovery: actions.retryRecoveryBanner,
              onDismissRecovery: actions.dismissRecoveryBanner,
              onDismissError: actions.dismissPresentedError
            )
            .padding(.top, 8)
            .padding(.horizontal, 12)
            .zIndex(40)
          }
          .onAppear {
            actions.updateWindowLayoutMode(policy.mode)
          }
          .onChange(of: policy.mode) { newMode in
            actions.updateWindowLayoutMode(newMode)
          }
          .frame(maxHeight: .infinity)
          .clipped()
          .zIndex(0)
        }
      }
    }
    .frame(minWidth: WindowLayoutPolicy.minimumWindowWidth, minHeight: 700)
    .background {
      MacVisualEffectBackground(style: .window)
    }
    .alert(item: alertBinding) { alert in
      Alert(
        title: Text(AppStrings.tr("alert.cannot_complete_operation")),
        message: Text(alert.message),
        dismissButton: .default(Text(AppStrings.tr("common.ok")))
      )
    }
    .sheet(item: outputRequestDraftBinding) { _ in
      OutputDialog(
        state: state.outputRequestSheetState,
        actions: actions.outputRequestSheetActions
      )
    }
    .sheet(item: documentSaveConfirmationBinding) { confirmation in
      DocumentSaveConfirmationDialog(
        confirmation: confirmation,
        actions: actions.documentSaveConfirmationActions
      )
    }
    .sheet(item: recoveryChooserBinding) { chooser in
      RecoveryChooserDialog(
        state: state.recoveryChooserState,
        actions: actions.recoveryChooserActions,
        chooser: chooser
      )
    }
    .modifier(
      LayerDeletionDialog(
        state: state.layerDeletionDialogState,
        actions: actions.layerDeletionDialogActions
      )
    )
  }

  private var canvasColumn: some View {
    VStack(spacing: 0) {
      WorkspaceCanvasSurface(
        state: WorkspaceCanvasSurfaceState(
          canvasRenderInput: state.canvasRenderInput,
          canvasInteractionInput: state.canvasInteractionInput,
          constraintEntryHUDState: state.constraintEntryHUDState,
          pasteOptionsPresentation: state.pasteOptionsPresentation
        ),
        actions: WorkspaceCanvasSurfaceActions(
          canvasActionGroups: actions.canvasActionGroups,
          constraintEntryHUDActions: actions.constraintEntryHUDActions,
          selectPastePlacement: actions.selectPastePlacement,
          dismissPasteOptions: actions.dismissPasteOptions
        )
      )
      .frame(minWidth: 640, minHeight: 480)

      if state.bottomWorkbenchVisible {
        BottomWorkbench(state: state.bottomWorkbenchState)
      }

      CanvasStatusBar(state: state.canvasStatusBarState, actions: actions.canvasStatusBarActions)
    }
  }

  private func inspectorPanel(width: CGFloat) -> some View {
    WorkspaceInspector(model: state.inspectorPanelModel, width: width)
  }

  private func clamp(_ value: CGFloat, within range: ClosedRange<CGFloat>) -> CGFloat {
    min(max(value, range.lowerBound), range.upperBound)
  }

  private func topChrome(layoutMode: WindowLayoutMode) -> some View {
    VStack(spacing: 0) {
      responsiveToolbar(for: layoutMode)

      Divider()
    }
    .background {
      MacVisualEffectBackground(style: .header)
    }
  }

  @ViewBuilder
  private func responsiveToolbar(for workspaceLayoutMode: WindowLayoutMode) -> some View {
    // Panel topology and toolbar density respond to different available
    // spaces. SwiftUI can choose the toolbar's intrinsic fit directly;
    // the workspace mode remains responsible only for dock/drawer actions.
    ViewThatFits(in: .horizontal) {
      CADToolbar(
        state: state.toolbarState,
        actions: actions.toolbarActions,
        workspaceLayoutMode: workspaceLayoutMode,
        density: .expanded
      )
      CADToolbar(
        state: state.toolbarState,
        actions: actions.toolbarActions,
        workspaceLayoutMode: workspaceLayoutMode,
        density: .condensed
      )
    }
  }

  private var alertBinding: Binding<UserAlertMessage?> {
    dismissibleBinding(state.alertMessage, onDismiss: actions.dismissAlert)
  }

  private var outputRequestDraftBinding: Binding<OutputRequestDraft?> {
    dismissibleBinding(state.outputRequestDraft, onDismiss: actions.dismissOutputRequest)
  }

  private var documentSaveConfirmationBinding: Binding<DocumentSaveConfirmation?> {
    dismissibleBinding(
      state.documentSaveConfirmation, onDismiss: actions.dismissDocumentSaveConfirmation)
  }

  private var recoveryChooserBinding: Binding<DocumentRecoveryChooserState?> {
    dismissibleBinding(state.recoveryChooser, onDismiss: actions.dismissRecoveryChooser)
  }

  private func dismissibleBinding<Value>(
    _ value: Value?,
    onDismiss: @escaping () -> Void
  ) -> Binding<Value?> {
    Binding(get: { value }, set: { if $0 == nil { onDismiss() } })
  }
}
