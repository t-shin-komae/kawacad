import SwiftUI

struct ValueEntryDialogPresenter: View {
  let state: ConstraintEntryHUDState
  let actions: ConstraintEntryHUDActions
  var standalone: Bool = false

  @ViewBuilder
  var body: some View {
    Group {
      if standalone {
        if let draft = state.draft,
          draft.kind != "fillet" || draft.filletIsReadyForValueEntry
        {
          styledDialog(for: draft)
        }
      } else {
        GeometryReader { proxy in
          if let draft = state.draft,
            draft.kind != "fillet" || draft.filletIsReadyForValueEntry
          {
            styledDialog(for: draft)
              .position(hudPosition(in: proxy.size, width: hudWidth(for: draft), draft: draft))
          }
        }
      }
    }
    .allowsHitTesting(state.draft != nil)
  }

  private func styledDialog(for draft: PendingConstraintValueDraft) -> some View {
    dialog(for: draft)
      .frame(
        width: hudWidth(for: draft),
        height: hudHeight(for: draft)
      )
      .background(LeatherColors.panel.opacity(0.94))
      .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .stroke(LeatherColors.panelStroke.opacity(0.55))
      )
      .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
  }

  @ViewBuilder
  private func dialog(for draft: PendingConstraintValueDraft) -> some View {
    if draft.kind == "offsetCurve" || draft.kind == "fillet" {
      DerivedValueDialog(state: state, actions: actions, draft: draft)
    } else {
      ConstraintValueDialog(state: state, actions: actions, draft: draft)
    }
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

private struct ConstraintValueDialog: View {
  let state: ConstraintEntryHUDState
  let actions: ConstraintEntryHUDActions
  let draft: PendingConstraintValueDraft

  var body: some View {
    ValueEntryFields(state: state, actions: actions, draft: draft)
      .padding(8)
  }
}

private struct DerivedValueDialog: View {
  let state: ConstraintEntryHUDState
  let actions: ConstraintEntryHUDActions
  let draft: PendingConstraintValueDraft

  var body: some View {
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
            Text(option.scope.label).tag(option.scope)
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
              "offset_source_scope.selected_range_with_count", option.sourceEntityIDs.count)
          )
          .foregroundStyle(.secondary)
        }
        .font(.caption)
      }

      ValueEntryFields(state: state, actions: actions, draft: draft)
    }
    .padding(8)
  }
}

private struct ValueEntryFields: View {
  let state: ConstraintEntryHUDState
  let actions: ConstraintEntryHUDActions
  let draft: PendingConstraintValueDraft
  @FocusState private var isFocused: Bool

  var body: some View {
    if draft.allowsParameterReference, !state.parameters.isEmpty {
      Picker(
        AppStrings.tr("sheet.input_method"),
        selection: Binding(
          get: { state.draft?.entryMode ?? .fixedValue },
          set: actions.updateEntryMode
        )
      ) {
        Text(ConstraintValueEntryMode.fixedValue.label).tag(ConstraintValueEntryMode.fixedValue)
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
            get: { state.draft?.selectedParameterID ?? state.parameters.first?.id ?? "" },
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
          .font(.system(size: LeatherDesignMetrics.Typography.label, weight: .medium))
          .foregroundStyle(LeatherColors.secondaryInk)
      }

      Button {
        actions.cancel()
      } label: {
        Image(systemName: "xmark")
          .frame(
            width: LeatherDesignMetrics.Control.height,
            height: LeatherDesignMetrics.Control.height
          )
      }
      .buttonStyle(.borderless)
      .keyboardShortcut(.cancelAction)
      .help(AppStrings.tr("common.cancel"))
      .accessibilityLabel(AppStrings.tr("common.cancel"))

      Button {
        actions.commit()
      } label: {
        Image(systemName: "checkmark")
          .frame(
            width: LeatherDesignMetrics.Control.height,
            height: LeatherDesignMetrics.Control.height
          )
      }
      .buttonStyle(.borderless)
      .keyboardShortcut(.defaultAction)
      .help(AppStrings.tr("common.apply"))
      .foregroundStyle(LeatherColors.accent)
      .accessibilityLabel(AppStrings.tr("common.apply"))
    }
    .onAppear { isFocused = true }
  }
}
