import AppKit
import KawaCADOutput
import SwiftUI

/// PDF and direct-print request actions.
extension OutputActionHandler {
  func exportPDFPanel() {
    let options = OutputFeature.presentationOptions(
      orientation: workspacePreferences.a4ReferenceOrientation
    )
    let buildOptions = outputPresentation.makePDFBuildOptions(presentation: options)
    let buildState: OutputRequestBuildState
    switch outputPresentation.prepareOutput(options: buildOptions, session: cadSession) {
    case .success(let buildResult):
      buildState = .ready(
        OutputRequestPreparedState(
          buildResult: buildResult,
          buildOptions: buildOptions,
          directPrintSession: nil
        ))
    case .failure(let error):
      buildState = .failed(error.message)
    }

    var draft = OutputRequestDraft(
      destination: .pdf,
      options: options,
      directPrintSession: nil
    )
    draft.buildState = buildState
    outputPresentation.setRequestDraft(draft)
  }

  func exportPDF(to url: URL, options: OutputBuildOptions) {
    switch outputPresentation.exportPDF(to: url, options: options, session: cadSession) {
    case .success(let message):
      statusMessage = message
    case .failure(let error):
      coreStatus = .unavailable(error.message)
      presentAlert(error.message)
    }
  }

  func printDirectPanel() {
    let options = OutputFeature.presentationOptions(
      orientation: workspacePreferences.a4ReferenceOrientation
    )
    switch outputPresentation.captureDirectPrintSession(presentation: options) {
    case .success(.cancelled):
      return
    case .success(.ready(let directPrintSession)):
      outputPresentation.setRequestDraft(
        OutputRequestDraft(
          destination: .directPrint,
          options: OutputPresentationOptions(
            orientation: directPrintSession.orientation,
            includeDimensionLabels: options.includeDimensionLabels,
            includeScaleGuide: options.includeScaleGuide,
            rotationDeg: options.rotationDeg
          ),
          directPrintSession: directPrintSession
        ))
      workspacePreferences.setA4ReferenceOrientation(directPrintSession.orientation)
    case .failure(let error):
      coreStatus = .unavailable(error.message)
      presentAlert(error.message)
      return
    }
    outputPresentation.scheduleBuild(session: cadSession)
  }

  func printDirect() {
    printDirect(
      presentation: OutputFeature.presentationOptions(
        orientation: workspacePreferences.a4ReferenceOrientation
      ))
  }

  func printDirect(presentation: OutputPresentationOptions) {
    switch outputPresentation.directPrint(
      presentation: presentation, session: cadSession, documentName: documentName)
    {
    case .success(let message):
      statusMessage = message
    case .failure(let error):
      coreStatus = .unavailable(error.message)
      presentAlert(error.message)
    }
  }

  func cancelOutputRequest() {
    outputPresentation.cancelRequest()
  }

  func confirmOutputRequest(saveURL: URL? = nil) {
    guard let draft = outputPresentation.requestDraft,
      case .ready(let preparedState) = draft.buildState
    else {
      return
    }
    if OutputFeature.executionDisabledReason(for: draft) != nil {
      return
    }
    executePreparedOutput(
      destination: draft.destination,
      preparedState: preparedState,
      saveURL: saveURL
    )
  }

  func setOutputRequestOrientation(_ orientation: OutputPrintOrientation) {
    workspacePreferences.setA4ReferenceOrientation(orientation)
    outputPresentation.updateDraft(session: cadSession) { draft in
      draft.options = OutputPresentationOptions(
        orientation: orientation,
        includeDimensionLabels: draft.options.includeDimensionLabels,
        includeScaleGuide: draft.options.includeScaleGuide,
        rotationDeg: draft.options.rotationDeg
      )
    }
  }

  func setOutputRequestRotation(_ rotationDeg: Int) {
    outputPresentation.updateDraft(session: cadSession) { draft in
      draft.options = OutputPresentationOptions(
        orientation: draft.options.orientation,
        includeDimensionLabels: draft.options.includeDimensionLabels,
        includeScaleGuide: draft.options.includeScaleGuide,
        rotationDeg: rotationDeg
      )
    }
  }

  func setOutputRequestIncludeDimensionLabels(_ enabled: Bool) {
    outputPresentation.updateDraft(session: cadSession) { draft in
      draft.options = OutputPresentationOptions(
        orientation: draft.options.orientation,
        includeDimensionLabels: enabled,
        includeScaleGuide: draft.options.includeScaleGuide,
        rotationDeg: draft.options.rotationDeg
      )
    }
  }

  func setOutputRequestIncludeScaleGuide(_ enabled: Bool) {
    outputPresentation.updateDraft(session: cadSession) { draft in
      draft.options = OutputPresentationOptions(
        orientation: draft.options.orientation,
        includeDimensionLabels: draft.options.includeDimensionLabels,
        includeScaleGuide: enabled,
        rotationDeg: draft.options.rotationDeg
      )
    }
  }

  func setOutputWarningsAcknowledged(_ acknowledged: Bool) {
    guard var draft = outputPresentation.requestDraft else {
      return
    }
    draft.warningAcknowledged = acknowledged
    outputPresentation.setRequestDraft(draft)
  }

  func refreshDirectPrintSession() {
    guard let draft = outputPresentation.requestDraft else {
      return
    }
    let currentOptions = draft.options
    switch outputPresentation.captureDirectPrintSession(presentation: currentOptions) {
    case .success(.cancelled):
      return
    case .success(.ready(let directPrintSession)):
      outputPresentation.updateDraft(session: cadSession) { refreshedDraft in
        refreshedDraft.directPrintSession = directPrintSession
        refreshedDraft.options = OutputPresentationOptions(
          orientation: directPrintSession.orientation,
          includeDimensionLabels: refreshedDraft.options.includeDimensionLabels,
          includeScaleGuide: refreshedDraft.options.includeScaleGuide,
          rotationDeg: refreshedDraft.options.rotationDeg
        )
      }
      workspacePreferences.setA4ReferenceOrientation(directPrintSession.orientation)
    case .failure(let error):
      coreStatus = .unavailable(error.message)
      presentAlert(error.message)
    }
  }

  private func executePreparedOutput(
    destination: OutputDestination,
    preparedState: OutputRequestPreparedState,
    saveURL: URL?
  ) {
    switch destination {
    case .pdf:
      guard
        let url = saveURL
          ?? desktopEnvironment.promptForSavePDFURL(documentName: documentName)
      else {
        return
      }
      switch outputPresentation.savePreparedPDF(
        buildResult: preparedState.buildResult, to: url, session: cadSession)
      {
      case .success(let message):
        outputPresentation.cancelRequest()
        statusMessage = message
      case .failure(let error):
        coreStatus = .unavailable(error.message)
        presentAlert(error.message)
      }
    case .directPrint:
      guard let directPrintSession = preparedState.directPrintSession else {
        return
      }
      switch outputPresentation.runPreparedDirectPrint(
        buildResult: preparedState.buildResult,
        documentName: documentName,
        session: cadSession,
        directPrintSession: directPrintSession
      ) {
      case .success(let message):
        outputPresentation.cancelRequest()
        statusMessage = message
      case .failure(let error):
        coreStatus = .unavailable(error.message)
        presentAlert(error.message)
      }
    }
  }

  func outputExecutionDisabledReason(for draft: OutputRequestDraft) -> String? {
    OutputFeature.executionDisabledReason(for: draft)
  }

  func refreshOutputPreviewBuildResult() {
    let options = outputPresentation.makePDFBuildOptions(
      presentation: OutputFeature.presentationOptions(
        orientation: workspacePreferences.a4ReferenceOrientation
      )
    )
    switch outputPresentation.prepareOutput(options: options, session: cadSession) {
    case .success(let buildResult):
      outputPresentation.setPreviewBuildResult(buildResult)
    case .failure(let error):
      outputPresentation.setPreviewBuildResult(nil)
      coreStatus = .unavailable(error.message)
      statusMessage = error.message
      presentAlert(error.message)
    }
  }

}
