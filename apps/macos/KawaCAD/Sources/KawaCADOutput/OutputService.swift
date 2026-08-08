import Foundation

public final class OutputService {
  private let printController: any PrintControlling

  public init(printController: any PrintControlling = LivePrintController()) {
    self.printController = printController
  }

  public func makePDFBuildOptions(presentation: OutputPresentationOptions) -> OutputBuildOptions {
    OutputBuildOptions(
      orientation: presentation.orientation,
      includeDimensionLabels: presentation.includeDimensionLabels,
      includeScaleGuide: presentation.includeScaleGuide,
      rotationDeg: presentation.rotationDeg,
      printableAreaMm: Self.pdfPrintableArea(for: presentation.orientation)
    )
  }

  public func availablePrinterNames() -> [String] {
    printController.availablePrinterNames()
  }

  public func makeDirectPrintSession(
    presentation: OutputPresentationOptions,
    printerName: String?
  ) -> OutputResult<OutputDirectPrintSession> {
    printController.makeDirectPrintSession(presentation: presentation, printerName: printerName)
  }

  public func prepareDirectPrintSession(
    presentation: OutputPresentationOptions,
    session: OutputDirectPrintSession
  ) -> OutputResult<OutputPreparedDirectPrintSession> {
    printController.prepareDirectPrintSession(presentation: presentation, session: session)
  }

  public func prepareOutput(
    options: OutputBuildOptions,
    session: any OutputSession
  ) -> OutputResult<OutputBuildResult> {
    return buildOutputDocumentModel(options: options, session: session)
  }

  public func exportPDF(
    to url: URL,
    options: OutputBuildOptions,
    session: any OutputSession
  ) -> OutputResult<String> {
    let buildResult: OutputBuildResult
    switch prepareOutput(options: options, session: session) {
    case .success(let value):
      buildResult = value
    case .failure(let error):
      return .failure(error)
    }
    return savePreparedPDF(
      buildResult: buildResult,
      to: url,
      session: session
    )
  }

  public func savePreparedPDF(
    buildResult: OutputBuildResult,
    to url: URL,
    session: any OutputSession
  ) -> OutputResult<String> {
    switch session.renderPDF(outputDocumentModel: buildResult.outputDocumentModel) {
    case .success(let pdfData):
      do {
        try pdfData.write(to: url, options: [.atomic])
        return .success(
          pdfExportSuccessMessage(fileName: url.lastPathComponent, warnings: buildResult.warnings))
      } catch {
        return .failure(
          OutputError(OutputStrings.tr("output.save_pdf_failed", error.localizedDescription)))
      }
    case .failure(let error):
      return .failure(error)
    }
  }

  public func directPrint(
    presentation: OutputPresentationOptions,
    session: any OutputSession,
    documentName: String
  ) -> OutputResult<String> {
    let directPrintSession: OutputDirectPrintSession
    switch makeDirectPrintSession(presentation: presentation, printerName: nil) {
    case .success(let value):
      directPrintSession = value
    case .failure(let error):
      return .failure(error)
    }
    let preparedSession: OutputPreparedDirectPrintSession
    switch prepareDirectPrintSession(presentation: presentation, session: directPrintSession) {
    case .success(let value):
      preparedSession = value
    case .failure(let error):
      return .failure(error)
    }
    let buildResult: OutputBuildResult
    switch prepareOutput(options: preparedSession.buildOptions, session: session) {
    case .success(let value):
      buildResult = value
    case .failure(let error):
      return .failure(error)
    }
    return runPreparedDirectPrint(
      buildResult: buildResult,
      documentName: documentName,
      session: session,
      directPrintSession: preparedSession.session
    )
  }

  public func runPreparedDirectPrint(
    buildResult: OutputBuildResult,
    documentName: String,
    session: any OutputSession,
    directPrintSession: OutputDirectPrintSession
  ) -> OutputResult<String> {
    switch session.renderPrint(outputDocumentModel: buildResult.outputDocumentModel) {
    case .success(let renderData):
      switch printController.runDirectPrint(
        renderData: renderData,
        session: directPrintSession,
        documentName: documentName
      ) {
      case .success:
        return .success(directPrintSuccessMessage(warnings: buildResult.warnings))
      case .failure(let error):
        return .failure(error)
      }
    case .failure(let error):
      return .failure(error)
    }
  }

  private func buildOutputDocumentModel(
    options: OutputBuildOptions,
    session: any OutputSession
  ) -> OutputResult<OutputBuildResult> {
    session.buildOutputDocumentModel(options: options)
  }

  private func pdfExportSuccessMessage(fileName: String, warnings: [OutputWarning]) -> String {
    guard !warnings.isEmpty else {
      return OutputStrings.tr("output.pdf_exported", fileName)
    }
    let warningSummary = warnings.map(\.message).joined(
      separator: OutputStrings.tr("output.warning_separator"))
    return OutputStrings.tr("output.pdf_exported_with_warning", fileName, warningSummary)
  }

  private func directPrintSuccessMessage(warnings: [OutputWarning]) -> String {
    guard !warnings.isEmpty else {
      return OutputStrings.tr("output.direct_print_opened")
    }
    let warningSummary = warnings.map(\.message).joined(
      separator: OutputStrings.tr("output.warning_separator"))
    return OutputStrings.tr("output.direct_print_opened_with_warning", warningSummary)
  }

  private static func pdfPrintableArea(for orientation: OutputPrintOrientation)
    -> OutputPrintableAreaMm
  {
    OutputPaperDefaults.pdfPrintableAreaMm(for: orientation)
  }
}
