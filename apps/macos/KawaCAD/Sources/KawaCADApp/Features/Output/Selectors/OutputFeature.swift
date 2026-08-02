import KawaCADOutput

/// Pure output presentation calculations.
enum OutputFeature {
  static func presentationOptions(
    orientation: OutputPrintOrientation,
    includeDimensionLabels: Bool = true,
    includeScaleGuide: Bool = true,
    rotationDeg: Int = 0
  ) -> OutputPresentationOptions {
    OutputPresentationOptions(
      orientation: orientation,
      includeDimensionLabels: includeDimensionLabels,
      includeScaleGuide: includeScaleGuide,
      rotationDeg: rotationDeg
    )
  }

  static func executionDisabledReason(
    for draft: OutputRequestDraft
  ) -> String? {
    guard case .ready(let preparedState) = draft.buildState else {
      switch draft.buildState {
      case .idle, .loading:
        return AppStrings.tr("output.sheet.build_loading")
      case .failed(let message):
        return message
      case .ready:
        return nil
      }
    }
    if preparedState.buildResult.outputDocumentModel.pageCount == 0
      || preparedState.buildResult.warnings.contains(where: { $0.kind == .emptyDocument })
    {
      return AppStrings.tr("output.sheet.empty_output")
    }
    if !preparedState.buildResult.warnings.isEmpty, !draft.warningAcknowledged {
      return AppStrings.tr("output.sheet.warning_ack_required")
    }
    return nil
  }
}
