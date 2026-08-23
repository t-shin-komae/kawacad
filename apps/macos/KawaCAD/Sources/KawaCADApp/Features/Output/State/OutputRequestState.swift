import Combine
import Foundation
import KawaCADOutput

enum OutputDestination: String, Identifiable, Equatable {
  case pdf
  case directPrint

  var id: String { rawValue }

  var title: String {
    switch self {
    case .pdf:
      return AppStrings.tr("output.destination.pdf")
    case .directPrint:
      return AppStrings.tr("output.destination.direct_print")
    }
  }

  func confirmationTitle(hasWarnings: Bool) -> String {
    switch self {
    case .pdf:
      return AppStrings.tr(
        hasWarnings ? "output.confirmation.save_with_warnings" : "output.confirmation.save")
    case .directPrint:
      return AppStrings.tr(
        hasWarnings ? "output.confirmation.print_with_warnings" : "output.confirmation.print")
    }
  }
}

struct OutputRequestDraft: Identifiable, Equatable {
  let id = UUID()
  var destination: OutputDestination
  var options: OutputPresentationOptions
  var directPrinterNames: [String] = []
  var selectedDirectPrinterName: String? = nil
  var directPrintSession: OutputDirectPrintSession?
  var buildRevision: Int = 0
  var buildState: OutputRequestBuildState = .idle
  var title: String { destination.title }
  var confirmationTitle: String {
    destination.confirmationTitle(hasWarnings: !(buildResult?.warnings.isEmpty ?? true))
  }

  var buildResult: OutputBuildResult? {
    if case .ready(let result) = buildState {
      return result.buildResult
    }
    return nil
  }
}

struct OutputRequestPreparedState: Equatable {
  let buildResult: OutputBuildResult
  let buildOptions: OutputBuildOptions
  let directPrintSession: OutputDirectPrintSession?
}

enum OutputRequestBuildState: Equatable {
  case idle
  case loading
  case ready(OutputRequestPreparedState)
  case failed(String)
}

/// Output dialog and preview state, corresponding to the output state owned by
/// React's application composition layer.
final class OutputPresentationState: ObservableObject {
  @Published private(set) var requestDraft: OutputRequestDraft?
  @Published private(set) var previewBuildResult: OutputBuildResult?
  private var buildTask: Task<Void, Never>?
  private var buildSequence = 0

  private let service: OutputService

  init(service: OutputService = OutputService()) {
    self.service = service
  }

  func setRequestDraft(_ draft: OutputRequestDraft?) {
    requestDraft = draft
  }

  func setPreviewBuildResult(_ result: OutputBuildResult?) {
    previewBuildResult = result
  }

  func makePDFBuildOptions(
    presentation: OutputPresentationOptions
  ) -> OutputBuildOptions {
    service.makePDFBuildOptions(presentation: presentation)
  }

  func availablePrinterNames() -> [String] {
    service.availablePrinterNames()
  }

  func makeDirectPrintSession(
    presentation: OutputPresentationOptions,
    printerName: String?
  ) -> OutputResult<OutputDirectPrintSession> {
    service.makeDirectPrintSession(presentation: presentation, printerName: printerName)
  }

  func prepareDirectPrintSession(
    presentation: OutputPresentationOptions,
    session: OutputDirectPrintSession
  ) -> OutputResult<OutputPreparedDirectPrintSession> {
    service.prepareDirectPrintSession(presentation: presentation, session: session)
  }

  func prepareOutput(
    options: OutputBuildOptions,
    session: any OutputSession
  ) -> OutputResult<OutputBuildResult> {
    service.prepareOutput(options: options, session: session)
  }

  func exportPDF(
    to url: URL,
    options: OutputBuildOptions,
    session: any OutputSession
  ) -> OutputResult<String> {
    service.exportPDF(to: url, options: options, session: session)
  }

  func savePreparedPDF(
    buildResult: OutputBuildResult,
    to url: URL,
    session: any OutputSession
  ) -> OutputResult<String> {
    service.savePreparedPDF(buildResult: buildResult, to: url, session: session)
  }

  func directPrint(
    presentation: OutputPresentationOptions,
    session: any OutputSession,
    documentName: String
  ) -> OutputResult<String> {
    service.directPrint(
      presentation: presentation,
      session: session,
      documentName: documentName
    )
  }

  func runPreparedDirectPrint(
    buildResult: OutputBuildResult,
    documentName: String,
    session: any OutputSession,
    directPrintSession: OutputDirectPrintSession
  ) -> OutputResult<String> {
    service.runPreparedDirectPrint(
      buildResult: buildResult,
      documentName: documentName,
      session: session,
      directPrintSession: directPrintSession
    )
  }

  func updateDraft(
    session: any OutputSession,
    _ update: (inout OutputRequestDraft) -> Void
  ) {
    guard var draft = requestDraft else { return }
    update(&draft)
    requestDraft = draft
    scheduleBuild(session: session)
  }

  func failDirectPrintSelection(printerName: String, message: String) {
    buildTask?.cancel()
    guard var draft = requestDraft, draft.destination == .directPrint else { return }

    buildSequence += 1
    draft.buildRevision = buildSequence
    draft.selectedDirectPrinterName = printerName
    draft.directPrintSession = nil
    draft.buildState = .failed(message)
    requestDraft = draft
  }

  func scheduleBuild(session: any OutputSession) {
    buildTask?.cancel()
    guard var draft = requestDraft else { return }

    buildSequence += 1
    let revision = buildSequence
    draft.buildRevision = revision
    draft.buildState = .loading
    requestDraft = draft

    buildTask = Task { @MainActor [weak self] in
      guard let self else { return }
      try? await Task.sleep(for: .milliseconds(150))
      guard !Task.isCancelled else { return }

      let buildOptionsResult: OutputResult<OutputBuildOptions>
      var directPrintSession: OutputDirectPrintSession?
      switch draft.destination {
      case .pdf:
        buildOptionsResult = .success(
          makePDFBuildOptions(presentation: draft.options)
        )
      case .directPrint:
        guard let baseDirectPrintSession = draft.directPrintSession else {
          buildOptionsResult = .failure(
            OutputError(AppStrings.tr("output.sheet.print_session_missing"))
          )
          break
        }
        switch prepareDirectPrintSession(
          presentation: draft.options,
          session: baseDirectPrintSession
        ) {
        case .success(let prepared):
          directPrintSession = prepared.session
          buildOptionsResult = .success(prepared.buildOptions)
        case .failure(let error):
          buildOptionsResult = .failure(error)
        }
      }

      let nextState: OutputRequestBuildState
      switch buildOptionsResult {
      case .success(let buildOptions):
        switch prepareOutput(options: buildOptions, session: session) {
        case .success(let buildResult):
          nextState = .ready(
            OutputRequestPreparedState(
              buildResult: buildResult,
              buildOptions: buildOptions,
              directPrintSession: directPrintSession
            ))
        case .failure(let error):
          nextState = .failed(error.message)
        }
      case .failure(let error):
        nextState = .failed(error.message)
      }

      guard var refreshedDraft = requestDraft,
        refreshedDraft.id == draft.id,
        refreshedDraft.buildRevision == revision
      else {
        return
      }
      refreshedDraft.buildState = nextState
      requestDraft = refreshedDraft
    }
  }

  func cancelRequest() {
    buildTask?.cancel()
    requestDraft = nil
  }
}
