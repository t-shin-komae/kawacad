import KawaCADOutput
import SwiftUI

struct OutputDialog: View {
  let state: OutputRequestSheetState
  let actions: OutputRequestSheetActions

  @ViewBuilder
  var body: some View {
    if let draft = state.draft {
      HStack(spacing: 0) {
        VStack(alignment: .leading, spacing: 18) {
          VStack(alignment: .leading, spacing: 6) {
            Text(draft.title)
              .font(.system(size: 17, weight: .semibold))
              .foregroundStyle(LeatherColors.ink)

            Text(AppStrings.tr("output.sheet.preview_help"))
              .font(.system(size: 12))
              .foregroundStyle(LeatherColors.secondaryInk)
          }

          VStack(alignment: .leading, spacing: 12) {
            if draft.directPrinterNames.isEmpty {
              summaryRow(AppStrings.tr("output.sheet.destination"), value: draft.destination.title)
            } else {
              Picker(
                AppStrings.tr("output.sheet.destination"),
                selection: Binding(
                  get: { draft.destination },
                  set: actions.setDestination
                )
              ) {
                Text(OutputDestination.pdf.title).tag(OutputDestination.pdf)
                Text(OutputDestination.directPrint.title).tag(OutputDestination.directPrint)
              }
              .pickerStyle(.menu)
            }
            summaryRow(
              AppStrings.tr("output.sheet.paper"), value: AppStrings.tr("output.sheet.paper_value"))
            summaryRow(
              AppStrings.tr("output.sheet.scale"),
              value: AppStrings.tr("output.sheet.scale_actual_size"))
            summaryRow(AppStrings.tr("output.sheet.page_count"), value: pageCountText(for: draft))
          }

          VStack(alignment: .leading, spacing: 12) {
            Toggle(
              AppStrings.tr("sheet.include_dimension_labels"), isOn: includeDimensionLabelsBinding)
            Toggle(AppStrings.tr("sheet.include_scale_guide"), isOn: includeScaleGuideBinding)
          }

          if draft.destination == .directPrint {
            VStack(alignment: .leading, spacing: 10) {
              settingGroupLabel(AppStrings.tr("output.sheet.print_session"))
              summaryRow(
                AppStrings.tr("output.sheet.printer"),
                value: draft.selectedDirectPrinterName
                  ?? draft.directPrintSession?.printerName
                  ?? AppStrings.tr("output.sheet.print_session_unknown")
              )
              Picker(
                AppStrings.tr("output.sheet.printer"), selection: directPrinterBinding(for: draft)
              ) {
                ForEach(draft.directPrinterNames, id: \.self) { printerName in
                  Text(printerName).tag(printerName)
                }
              }
              summaryRow(
                AppStrings.tr("output.sheet.printable_area"),
                value: printableAreaText(for: draft.directPrintSession?.printableAreaMm)
              )
            }
          }

          outputStatusSection(draft: draft)

          if let disabledReason = state.disabledReason {
            Text(disabledReason)
              .font(.system(size: 11, weight: .medium))
              .foregroundStyle(LeatherColors.secondaryInk)
              .accessibilityLabel(Text(disabledReason))
          }

          Spacer(minLength: 0)

          HStack(spacing: 8) {
            Spacer()
            Button(AppStrings.tr("common.cancel")) {
              actions.cancel()
            }
            .buttonStyle(.bordered)

            Button(draft.confirmationTitle) {
              actions.confirm()
            }
            .buttonStyle(.borderedProminent)
            .disabled(state.disabledReason != nil)
          }
        }
        .padding(24)
        .frame(width: 340, alignment: .topLeading)

        Divider()

        OutputRequestPreviewPane(draft: draft)
      }
      .frame(minWidth: 920, minHeight: 640)
      .background {
        MacVisualEffectBackground(style: .content)
      }
    }
  }

  @ViewBuilder
  private func outputStatusSection(draft: OutputRequestDraft) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      settingGroupLabel(AppStrings.tr("output.sheet.status"))
      switch draft.buildState {
      case .idle, .loading:
        Label(AppStrings.tr("output.sheet.build_loading"), systemImage: "hourglass")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(LeatherColors.secondaryInk)
      case .failed(let message):
        Label(message, systemImage: "exclamationmark.triangle.fill")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.orange)
      case .ready(let preparedState):
        Label(
          preparedState.buildResult.warnings.isEmpty
            ? AppStrings.tr("output.sheet.ready")
            : AppStrings.tr("output.sheet.warning_count", preparedState.buildResult.warnings.count),
          systemImage: preparedState.buildResult.warnings.isEmpty
            ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
        )
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(preparedState.buildResult.warnings.isEmpty ? .green : .orange)

        if !preparedState.buildResult.warnings.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(preparedState.buildResult.warnings.enumerated()), id: \.offset) {
              _, warning in
              Label(warning.message, systemImage: warningSymbolName(for: warning))
                .font(.system(size: 11))
                .foregroundStyle(LeatherColors.ink)
            }

          }
          .padding(12)
          .background(LeatherColors.panel)
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
      }
    }
  }

  private func summaryRow(_ label: String, value: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(label)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(LeatherColors.secondaryInk)
      Spacer(minLength: 8)
      Text(value)
        .font(.system(size: 12))
        .foregroundStyle(LeatherColors.ink)
    }
  }

  private func settingGroupLabel(_ label: String) -> some View {
    Text(label)
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(LeatherColors.secondaryInk)
  }

  private func pageCountText(for draft: OutputRequestDraft) -> String {
    if case .ready(let preparedState) = draft.buildState {
      return AppStrings.tr(
        "output.sheet.page_count_value", preparedState.buildResult.outputDocumentModel.pageCount)
    }
    return "..."
  }

  private func printableAreaText(for area: OutputPrintableAreaMm?) -> String {
    guard let area else {
      return AppStrings.tr("output.sheet.print_session_unknown")
    }
    return AppStrings.tr(
      "output.sheet.printable_area_value",
      area.leftMm,
      area.rightMm,
      area.topMm,
      area.bottomMm
    )
  }

  private func warningSymbolName(for warning: OutputWarning) -> String {
    switch warning.kind {
    case .emptyDocument:
      return "tray"
    case .outOfPrintableBounds:
      return "arrow.up.left.and.arrow.down.right"
    case .pageBoundaryCrossing:
      return "square.split.2x2"
    case .actualScaleNotGuaranteed:
      return "ruler"
    }
  }

  private func directPrinterBinding(for draft: OutputRequestDraft) -> Binding<String> {
    Binding(
      get: {
        draft.selectedDirectPrinterName
          ?? draft.directPrintSession?.printerName
          ?? draft.directPrinterNames.first
          ?? ""
      },
      set: actions.selectDirectPrintPrinter
    )
  }
  private var includeDimensionLabelsBinding: Binding<Bool> {
    draftOptionBinding(
      state.draft?.options.includeDimensionLabels, default: true,
      set: actions.setIncludeDimensionLabels)
  }

  private var includeScaleGuideBinding: Binding<Bool> {
    draftOptionBinding(
      state.draft?.options.includeScaleGuide, default: true, set: actions.setIncludeScaleGuide)
  }

  private func draftOptionBinding<Value>(
    _ value: Value?,
    default defaultValue: Value,
    set: @escaping (Value) -> Void
  ) -> Binding<Value> {
    Binding(get: { value ?? defaultValue }, set: set)
  }
}

private struct OutputRequestPreviewPane: View {
  let draft: OutputRequestDraft

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(AppStrings.tr("output.sheet.preview"))
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(LeatherColors.ink)
        Spacer()
        Text(previewSummary)
          .font(.system(size: 11))
          .foregroundStyle(LeatherColors.secondaryInk)
      }

      Group {
        switch draft.buildState {
        case .idle, .loading:
          VStack(spacing: 10) {
            ProgressView()
            Text(AppStrings.tr("output.sheet.preview_loading"))
              .font(.system(size: 12))
              .foregroundStyle(LeatherColors.secondaryInk)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
          VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
              .font(.system(size: 24))
              .foregroundStyle(.orange)
            Text(message)
              .font(.system(size: 12))
              .foregroundStyle(LeatherColors.ink)
              .multilineTextAlignment(.center)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready(let preparedState):
          ScrollView([.horizontal, .vertical]) {
            OutputRequestPreviewCanvas(model: preparedState.buildResult.outputDocumentModel)
              .padding(18)
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(LeatherColors.panel.opacity(0.7))
      .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    .padding(24)
  }

  private var previewSummary: String {
    if case .ready(let preparedState) = draft.buildState {
      return AppStrings.tr(
        "output.sheet.page_count_value", preparedState.buildResult.outputDocumentModel.pageCount)
    }
    return AppStrings.tr("output.sheet.preview_unavailable")
  }
}

private struct OutputRequestPreviewCanvas: View {
  let model: OutputDocumentModel

  var body: some View {
    GeometryReader { proxy in
      Canvas { context, size in
        drawPreview(in: &context, size: size)
      }
      .frame(
        width: max(proxy.size.width, intrinsicCanvasSize.width),
        height: max(proxy.size.height, intrinsicCanvasSize.height)
      )
    }
    .frame(minWidth: intrinsicCanvasSize.width, minHeight: intrinsicCanvasSize.height)
  }

  private var intrinsicCanvasSize: CGSize {
    let bounds = pageBounds
    return CGSize(
      width: max(420, bounds.width * 1.4 + 48),
      height: max(420, bounds.height * 1.4 + 48)
    )
  }

  private var pageBounds: CGRect {
    guard !model.pages.isEmpty else {
      return .zero
    }
    var minX = CGFloat.greatestFiniteMagnitude
    var maxX = -CGFloat.greatestFiniteMagnitude
    var minY = CGFloat.greatestFiniteMagnitude
    var maxY = -CGFloat.greatestFiniteMagnitude
    for page in model.pages {
      let centerX = CGFloat(Double(page.gridColumn) * page.widthMm)
      let centerY = CGFloat(Double(page.gridRow) * page.heightMm)
      minX = min(minX, centerX - CGFloat(page.widthMm) / 2)
      maxX = max(maxX, centerX + CGFloat(page.widthMm) / 2)
      minY = min(minY, centerY - CGFloat(page.heightMm) / 2)
      maxY = max(maxY, centerY + CGFloat(page.heightMm) / 2)
    }
    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
  }

  private func drawPreview(in context: inout GraphicsContext, size: CGSize) {
    guard !model.pages.isEmpty else {
      return
    }
    let bounds = pageBounds
    let scale = min(
      (size.width - 32) / max(bounds.width, 1),
      (size.height - 32) / max(bounds.height, 1)
    )
    let offsetX = (size.width - bounds.width * scale) / 2 - bounds.minX * scale
    let offsetY = (size.height - bounds.height * scale) / 2 + bounds.maxY * scale

    for (index, page) in model.pages.enumerated() {
      let pageRect = previewRect(for: page, scale: scale, offsetX: offsetX, offsetY: offsetY)
      context.fill(
        Path(roundedRect: pageRect, cornerRadius: 8),
        with: .color(.white)
      )
      context.stroke(
        Path(roundedRect: pageRect, cornerRadius: 8),
        with: .color(Color.black.opacity(0.14)),
        lineWidth: 1
      )

      let printableRect = printablePreviewRect(page, pageRect: pageRect)
      context.stroke(
        Path(
          CGRect(
            x: printableRect.minX,
            y: printableRect.minY,
            width: printableRect.width,
            height: printableRect.height
          )),
        with: .color(Color.blue.opacity(0.55)),
        style: StrokeStyle(lineWidth: 1, dash: [5, 4])
      )

      drawPageContent(page, in: &context, pageRect: pageRect, printableRect: printableRect)

      let labelPoint = CGPoint(x: pageRect.minX + 14, y: pageRect.minY + 14)
      context.draw(
        Text("\(index + 1)")
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(.white),
        in: CGRect(x: labelPoint.x, y: labelPoint.y, width: 22, height: 18)
      )
      context.fill(
        Path(
          roundedRect: CGRect(x: labelPoint.x - 4, y: labelPoint.y - 2, width: 28, height: 20),
          cornerRadius: 5),
        with: .color(.blue)
      )
      context.draw(
        Text("\(index + 1)")
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(.white),
        at: CGPoint(x: labelPoint.x + 10, y: labelPoint.y + 8), anchor: .center
      )
    }
  }

  private func previewRect(
    for page: OutputPage,
    scale: CGFloat,
    offsetX: CGFloat,
    offsetY: CGFloat
  ) -> CGRect {
    let centerX = CGFloat(Double(page.gridColumn) * page.widthMm)
    let centerY = CGFloat(Double(page.gridRow) * page.heightMm)
    let width = CGFloat(page.widthMm) * scale
    let height = CGFloat(page.heightMm) * scale
    let minX = offsetX + (centerX - CGFloat(page.widthMm) / 2) * scale
    let minY = offsetY - (centerY + CGFloat(page.heightMm) / 2) * scale
    return CGRect(x: minX, y: minY, width: width, height: height)
  }

  private func printablePreviewRect(_ page: OutputPage, pageRect: CGRect) -> CGRect {
    let xScale = pageRect.width / CGFloat(page.widthMm)
    let yScale = pageRect.height / CGFloat(page.heightMm)
    let left = pageRect.midX + CGFloat(page.printableAreaMm.leftMm) * xScale
    let right = pageRect.midX + CGFloat(page.printableAreaMm.rightMm) * xScale
    let top = pageRect.midY - CGFloat(page.printableAreaMm.topMm) * yScale
    let bottom = pageRect.midY - CGFloat(page.printableAreaMm.bottomMm) * yScale
    return CGRect(x: left, y: top, width: right - left, height: bottom - top)
  }

  private func drawPageContent(
    _ page: OutputPage,
    in context: inout GraphicsContext,
    pageRect: CGRect,
    printableRect: CGRect
  ) {
    for graphic in page.graphics {
      drawGraphic(graphic, in: &context, pageRect: pageRect)
    }
    for text in page.texts {
      let position = point(for: text.positionMm, in: pageRect, page: page)
      context.draw(
        Text(text.content)
          .font(.system(size: max(8, text.fontSizeMm * 2.2)))
          .foregroundColor(text.kind == .freeText ? .primary : .secondary),
        at: position,
        anchor: .topLeading
      )
    }
    if let guide = page.guide {
      var path = Path()
      path.move(to: point(for: guide.startMm, in: pageRect, page: page))
      path.addLine(to: point(for: guide.endMm, in: pageRect, page: page))
      context.stroke(
        path, with: .color(.blue.opacity(0.65)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
      context.draw(
        Text(guide.label)
          .font(.system(size: 10, weight: .medium))
          .foregroundColor(.blue),
        at: point(for: guide.labelPositionMm, in: pageRect, page: page),
        anchor: .center
      )
    }

    if page.graphics.isEmpty, page.texts.isEmpty, page.guide == nil {
      context.stroke(
        Path(
          ellipseIn: CGRect(
            x: printableRect.midX - 12,
            y: printableRect.midY - 12,
            width: 24,
            height: 24
          )),
        with: .color(Color.secondary.opacity(0.4)),
        style: StrokeStyle(lineWidth: 1, dash: [3, 3])
      )
    }
  }

  private func drawGraphic(
    _ graphic: OutputGraphic, in context: inout GraphicsContext, pageRect: CGRect
  ) {
    let color = Color(
      red: graphic.style.stroke.red,
      green: graphic.style.stroke.green,
      blue: graphic.style.stroke.blue,
      opacity: graphic.style.stroke.alpha
    )
    let lineWidth = max(0.8, graphic.style.strokeWidthMm * 1.8)
    let strokeStyle = StrokeStyle(
      lineWidth: lineWidth, dash: dashPattern(for: graphic.style.pattern))

    switch graphic.geometry {
    case .point(let positionMm):
      let point = point(for: positionMm, in: pageRect, page: nil)
      context.fill(
        Path(ellipseIn: CGRect(x: point.x - 1.5, y: point.y - 1.5, width: 3, height: 3)),
        with: .color(color))
    case .lineSegment(let startMm, let endMm), .centerLine(let startMm, let endMm):
      var path = Path()
      path.move(to: point(for: startMm, in: pageRect, page: nil))
      path.addLine(to: point(for: endMm, in: pageRect, page: nil))
      context.stroke(path, with: .color(color), style: strokeStyle)
    case .circle(let centerMm, let radiusMm):
      let center = point(for: centerMm, in: pageRect, page: nil)
      let radius = CGFloat(radiusMm) * (pageRect.width / CGFloat(model.pages.first?.widthMm ?? 1))
      context.stroke(
        Path(
          ellipseIn: CGRect(
            x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
        with: .color(color),
        style: strokeStyle
      )
    case .arc(let centerMm, let radiusMm, let startAngleRad, let sweepAngleRad):
      let center = point(for: centerMm, in: pageRect, page: nil)
      let radius = CGFloat(radiusMm) * (pageRect.width / CGFloat(model.pages.first?.widthMm ?? 1))
      var path = Path()
      path.addArc(
        center: center,
        radius: radius,
        startAngle: .radians(-startAngleRad),
        endAngle: .radians(-(startAngleRad + sweepAngleRad)),
        clockwise: sweepAngleRad > 0
      )
      context.stroke(path, with: .color(color), style: strokeStyle)
    }
  }

  private func point(for pointMm: OutputPointMm, in pageRect: CGRect, page: OutputPage?) -> CGPoint
  {
    let widthMm = CGFloat(page?.widthMm ?? model.pages.first?.widthMm ?? 1)
    let heightMm = CGFloat(page?.heightMm ?? model.pages.first?.heightMm ?? 1)
    let x = pageRect.midX + CGFloat(pointMm.xMm) * (pageRect.width / widthMm)
    let y = pageRect.midY - CGFloat(pointMm.yMm) * (pageRect.height / heightMm)
    return CGPoint(x: x, y: y)
  }

  private func dashPattern(for pattern: OutputLinePattern) -> [CGFloat] {
    switch pattern {
    case .solid:
      return []
    case .dashed:
      return [6, 4]
    case .dotted:
      return [2, 3]
    case .construction:
      return [8, 4, 2, 4]
    }
  }
}
