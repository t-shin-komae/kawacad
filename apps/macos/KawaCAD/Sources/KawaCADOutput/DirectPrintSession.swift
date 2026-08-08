import AppKit
import ApplicationServices
import Foundation

public struct OutputDirectPrintSession {
  public let orientation: OutputPrintOrientation
  public let printableAreaMm: OutputPrintableAreaMm
  public let paperWidthMm: Double
  public let paperHeightMm: Double
  public let scalingFactor: Double
  public let printerName: String?
  public let isSingleSided: Bool

  let printInfo: NSPrintInfo

  public init(printInfo: NSPrintInfo) {
    let copiedPrintInfo = (printInfo.copy() as? NSPrintInfo) ?? printInfo
    self.printInfo = copiedPrintInfo
    orientation = copiedPrintInfo.orientation == .portrait ? .portrait : .landscape
    printableAreaMm = LivePrintController.printableAreaMM(
      from: copiedPrintInfo, orientation: orientation)
    paperWidthMm = LivePrintController.pointsToMillimeters(copiedPrintInfo.paperSize.width)
    paperHeightMm = LivePrintController.pointsToMillimeters(copiedPrintInfo.paperSize.height)
    scalingFactor = copiedPrintInfo.scalingFactor
    printerName = copiedPrintInfo.printer.name
    var duplexMode = PMDuplexMode(kPMDuplexNone)
    let printSettings = OpaquePointer(copiedPrintInfo.pmPrintSettings())
    isSingleSided =
      PMGetDuplex(printSettings, &duplexMode) == noErr
      && duplexMode == PMDuplexMode(kPMDuplexNone)
  }

  public var isA4Paper: Bool {
    let a4 = OutputPaperDefaults.a4PageSizeMm(for: orientation)
    return abs(paperWidthMm - a4.widthMm) < 0.5 && abs(paperHeightMm - a4.heightMm) < 0.5
  }

  public var isActualScale: Bool {
    abs(scalingFactor - 1.0) < 0.0001
  }
}

extension OutputDirectPrintSession: Equatable {
  public static func == (lhs: OutputDirectPrintSession, rhs: OutputDirectPrintSession) -> Bool {
    lhs.orientation == rhs.orientation
      && lhs.printableAreaMm == rhs.printableAreaMm
      && lhs.paperWidthMm == rhs.paperWidthMm
      && lhs.paperHeightMm == rhs.paperHeightMm
      && lhs.scalingFactor == rhs.scalingFactor
      && lhs.printerName == rhs.printerName
      && lhs.isSingleSided == rhs.isSingleSided
  }
}
