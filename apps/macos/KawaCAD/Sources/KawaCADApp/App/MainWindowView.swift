import KawaCADOutput
import SwiftUI

struct MainWindowView: View {
  @EnvironmentObject private var appState: AppCoordinator

  var body: some View {
    ObservedWorkspaceRoot(appState: appState)
  }
}

/// SwiftUI equivalent of React re-rendering from the individual hooks used by
/// `App.tsx`. The coordinator supplies actions and derived props, while each
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
        previousMode: state.windowLayoutMode
      )

      HStack(spacing: 0) {
        if policy.toolDockVisible {
          ProjectSidebar(
            state: state.toolPaletteState,
            actions: actions.toolPaletteActions,
            width: policy.toolDockWidth
          )
          .zIndex(10)
          PanelResizeHandle(alignment: .trailing) { translation in
            let base = toolResizeBaseWidth ?? state.toolPanelWidth
            toolResizeBaseWidth = toolResizeBaseWidth ?? base
            let range = WindowLayoutPolicy.toolWidthRange(for: policy.mode)
            actions.setToolPanelWidth(clamp(base + translation.width, within: range))
          } onEnded: {
            toolResizeBaseWidth = nil
          } onKeyboardAdjust: { delta in
            actions.setToolPanelWidth(
              clamp(
                state.toolPanelWidth + delta,
                within: WindowLayoutPolicy.toolWidthRange(for: policy.mode)
              ))
          }
        }

        VStack(spacing: 0) {
          topChrome(layoutMode: policy.mode)
            .zIndex(1)
          ZStack(alignment: .top) {
            WorkspaceCanvasLayout(
              state: state,
              actions: actions,
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
      OutputRequestSheet(
        state: state.outputRequestSheetState,
        actions: actions.outputRequestSheetActions
      )
    }
    .sheet(item: documentSaveConfirmationBinding) { confirmation in
      DocumentSaveConfirmationSheet(
        confirmation: confirmation,
        actions: actions.documentSaveConfirmationActions
      )
    }
    .sheet(item: recoveryChooserBinding) { chooser in
      RecoveryChooserSheet(
        state: state.recoveryChooserState,
        actions: actions.recoveryChooserActions,
        chooser: chooser
      )
    }
    .modifier(
      LayerDeletionConfirmationModifier(
        state: state.layerDeletionDialogState,
        actions: actions.layerDeletionDialogActions
      )
    )
  }

  private var canvasColumn: some View {
    VStack(spacing: 0) {
      ZStack(alignment: .topLeading) {
        LeatherCanvasRepresentable(state: state.canvasState, actions: actions.canvasActions)

        ConstraintValueEntryHUD(
          state: state.constraintEntryHUDState,
          actions: actions.constraintEntryHUDActions
        )

        if let pasteOptionsPresentation = state.pasteOptionsPresentation {
          PasteOptionsOverlay(
            presentation: pasteOptionsPresentation,
            selectMode: actions.selectPastePlacement,
            dismiss: actions.dismissPasteOptions
          )
        }

      }
      .frame(minWidth: 640, minHeight: 480)

      if state.bottomWorkbenchVisible {
        BottomWorkbench(state: state.bottomWorkbenchState)
      }

      CanvasStatusBar(state: state.canvasStatusBarState, actions: actions.canvasStatusBarActions)
    }
  }

  private func inspectorPanel(width: CGFloat) -> some View {
    InspectorPanel(appState: state.inspectorFeatureModel)
      .frame(width: width)
      .background(MacVisualEffectBackground(style: .sidebar))
      .overlay(alignment: .leading) {
        Rectangle()
          .fill(LeatherColors.panelStroke.opacity(0.65))
          .frame(width: 1)
      }
  }

  private func clamp(_ value: CGFloat, within range: ClosedRange<CGFloat>) -> CGFloat {
    min(max(value, range.lowerBound), range.upperBound)
  }

  private func topChrome(layoutMode: WindowLayoutMode) -> some View {
    VStack(spacing: 0) {
      DocumentHeader(state: state.documentHeaderState, actions: actions.documentHeaderActions)
        .frame(height: 42)

      Divider()

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

struct PanelResizeHandle: View {
  let alignment: HorizontalAlignment
  let onChanged: (CGSize) -> Void
  let onEnded: () -> Void
  let onKeyboardAdjust: (CGFloat) -> Void

  var body: some View {
    Rectangle()
      .fill(Color.clear)
      .frame(width: WindowLayoutPolicy.panelResizeHandleWidth)
      .contentShape(Rectangle())
      .overlay(alignment: alignment == .leading ? .leading : .trailing) {
        Rectangle()
          .fill(LeatherColors.panelStroke.opacity(0.7))
          .frame(width: 1)
      }
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            onChanged(value.translation)
          }
          .onEnded { _ in
            onEnded()
          }
      )
      .accessibilityLabel(AppStrings.tr("accessibility.resize_panel"))
      .accessibilityHint(AppStrings.tr("accessibility.resize_panel_hint"))
      .focusable()
      .onMoveCommand { direction in
        switch (alignment, direction) {
        case (.trailing, .right), (.leading, .left):
          onKeyboardAdjust(8)
        case (.trailing, .left), (.leading, .right):
          onKeyboardAdjust(-8)
        default:
          break
        }
      }
      .accessibilityAdjustableAction { direction in
        onKeyboardAdjust(direction == .increment ? 8 : -8)
      }
  }
}

struct RecoveryBannerView: View {
  let banner: DocumentRecoveryBannerState
  let onRetry: () -> Void
  let onDismiss: () -> Void
  @State private var detailsExpanded = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        VStack(alignment: .leading, spacing: 4) {
          Text(banner.message)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(LeatherColors.ink)

          if detailsExpanded {
            Text(banner.details)
              .font(.system(size: 11))
              .foregroundStyle(LeatherColors.secondaryInk)
          }
        }

        Spacer(minLength: 8)

        Button(AppStrings.tr("common.retry")) {
          onRetry()
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .medium))

        Button(AppStrings.tr("error.banner.details")) {
          detailsExpanded.toggle()
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .medium))

        Button(AppStrings.tr("error.banner.dismiss")) {
          onDismiss()
        }
        .buttonStyle(.plain)
        .font(.system(size: 11, weight: .medium))
      }
    }
    .padding(12)
    .background(LeatherColors.panel)
    .overlay(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(LeatherColors.panelStroke.opacity(0.7))
    )
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
  }
}

private struct ConstraintValueEntryHUD: View {
  let state: ConstraintEntryHUDState
  let actions: ConstraintEntryHUDActions
  @FocusState private var isFocused: Bool

  var body: some View {
    GeometryReader { proxy in
      if let draft = state.draft,
        draft.kind != "fillet" || draft.filletIsReadyForValueEntry
      {
        valueEntryContent(draft)
          .frame(width: hudWidth(for: draft))
          .background(LeatherColors.panel.opacity(0.94))
          .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .stroke(LeatherColors.panelStroke.opacity(0.55))
          )
          .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
          .position(hudPosition(in: proxy.size, width: hudWidth(for: draft), draft: draft))
          .onAppear { isFocused = true }
      }
    }
    .allowsHitTesting(state.draft != nil)
  }

  @ViewBuilder
  private func valueEntryContent(_ draft: PendingConstraintValueDraft) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      if draft.kind == "fillet" {
        Text(
          AppStrings.tr(
            "fillet.draft.summary",
            draft.filletSourceEntityIDs.count,
            draft.filletCornerCount,
            draft.filletClosed
              ? AppStrings.tr("fillet.draft.closed") : AppStrings.tr("fillet.draft.open")
          )
        )
        .font(.caption)
        .foregroundStyle(LeatherColors.secondaryInk)
      }
      if draft.kind == "offsetCurve", draft.offsetSourceScopeOptions.count > 1 {
        Picker(
          AppStrings.tr("sheet.offset_source_scope"),
          selection: Binding(
            get: {
              state.draft?.selectedOffsetSourceScope
                ?? draft.offsetSourceScopeOptions.first?.scope
                ?? .closedContour
            },
            set: actions.updateOffsetSourceScope
          )
        ) {
          ForEach(draft.offsetSourceScopeOptions, id: \.scope) { option in
            Text(option.scope.label)
              .tag(option.scope)
          }
        }
        .pickerStyle(.segmented)
      } else if draft.kind == "offsetCurve",
        let option = draft.offsetSourceScopeOptions.first,
        option.scope == .selectedRange
      {
        HStack {
          Text(AppStrings.tr("sheet.offset_source_scope"))
          Spacer()
          Text(
            AppStrings.tr(
              "offset_source_scope.selected_range_with_count",
              option.sourceEntityIDs.count
            )
          )
          .foregroundStyle(.secondary)
        }
        .font(.caption)
      }

      if draft.allowsParameterReference, !state.parameters.isEmpty {
        Picker(
          AppStrings.tr("sheet.input_method"),
          selection: Binding(
            get: { state.draft?.entryMode ?? .fixedValue },
            set: actions.updateEntryMode
          )
        ) {
          Text(ConstraintValueEntryMode.fixedValue.label)
            .tag(ConstraintValueEntryMode.fixedValue)
          Text(ConstraintValueEntryMode.parameterReference.label)
            .tag(ConstraintValueEntryMode.parameterReference)
        }
        .pickerStyle(.segmented)
      }

      HStack(spacing: 6) {
        if draft.entryMode == .parameterReference, draft.allowsParameterReference,
          !state.parameters.isEmpty
        {
          Picker(
            AppStrings.tr("sheet.reference_parameter"),
            selection: Binding(
              get: {
                state.draft?.selectedParameterID ?? state.parameters
                  .first?.id ?? ""
              },
              set: actions.updateParameterID
            )
          ) {
            ForEach(state.parameters) { parameter in
              Text(
                "\(parameter.name) (\(parameter.valueMM.formatted(.number.precision(.fractionLength(0...2)))) \(parameter.unitLabel))"
              )
              .tag(parameter.id)
            }
          }
          .labelsHidden()
        } else {
          TextField(
            draft.title,
            text: Binding(
              get: { state.draft?.valueText ?? "" },
              set: actions.updateValueText
            )
          )
          .textFieldStyle(.roundedBorder)
          .focused($isFocused)
          .onSubmit(actions.commit)

          Text(draft.unit)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(LeatherColors.secondaryInk)
        }

        Button {
          actions.cancel()
        } label: {
          Image(systemName: "xmark")
            .frame(width: 18, height: 18)
        }
        .buttonStyle(.borderless)
        .keyboardShortcut(.cancelAction)
        .help(AppStrings.tr("common.cancel"))

        if draft.kind != "fillet" || draft.filletIsReadyForValueEntry {
          Button {
            actions.commit()
          } label: {
            Image(systemName: "checkmark")
              .frame(width: 18, height: 18)
          }
          .buttonStyle(.borderless)
          .keyboardShortcut(.defaultAction)
          .help(AppStrings.tr("common.apply"))
          .foregroundStyle(LeatherColors.accent)
        }
      }
    }
    .padding(8)
  }

  private func hudWidth(for draft: PendingConstraintValueDraft) -> CGFloat {
    if draft.kind == "offsetCurve",
      draft.offsetSourceScopeOptions.count > 1
        || draft.offsetSourceScopeOptions.first?.scope == .selectedRange
    {
      return 260
    }
    if draft.allowsParameterReference, !state.parameters.isEmpty {
      return 236
    }
    return 190
  }

  private func hudHeight(for draft: PendingConstraintValueDraft) -> CGFloat {
    var height: CGFloat = 46
    if draft.allowsParameterReference, !state.parameters.isEmpty {
      height += 28
    }
    if draft.kind == "fillet" {
      height += 20
    }
    if draft.kind == "offsetCurve",
      draft.offsetSourceScopeOptions.count > 1
        || draft.offsetSourceScopeOptions.first?.scope == .selectedRange
    {
      height += 28
    }
    return height
  }

  private func hudPosition(
    in canvasSize: CGSize, width: CGFloat, draft: PendingConstraintValueDraft
  ) -> CGPoint {
    let height = hudHeight(for: draft)
    let anchor =
      draft.anchorCanvasPoint
      ?? CGPoint(x: canvasSize.width * 0.5, y: canvasSize.height * 0.5)
    let proposed = CGPoint(x: anchor.x + width / 2 + 14, y: anchor.y + height / 2 + 14)
    return CGPoint(
      x: min(
        max(width / 2 + 12, proposed.x), max(width / 2 + 12, canvasSize.width - width / 2 - 12)),
      y: min(
        max(height / 2 + 12, proposed.y), max(height / 2 + 12, canvasSize.height - height / 2 - 12))
    )
  }
}

private struct LayerDeletionConfirmationModifier: ViewModifier {
  let state: LayerDeletionDialogState
  let actions: LayerDeletionDialogActions

  func body(content: Content) -> some View {
    content.confirmationDialog(
      AppStrings.tr("dialog.delete_layer_title"),
      isPresented: Binding(
        get: { state.confirmation != nil },
        set: { isPresented in
          if !isPresented {
            actions.dismiss()
          }
        }
      ),
      titleVisibility: .visible
    ) {
      Button(AppStrings.tr("common.delete"), role: .destructive) {
        actions.confirm()
      }
      Button(AppStrings.tr("common.cancel"), role: .cancel) {
        actions.cancel()
      }
    } message: {
      Text(state.confirmation?.message ?? "")
    }
  }
}
