import AppKit
import SwiftUI

enum LeatherColors {
  static let canvasBackground = NSColor.white
  static let window = Color(nsColor: .windowBackgroundColor)
  static let panel = Color(nsColor: .controlBackgroundColor)
  static let panelStroke = Color(nsColor: .separatorColor)
  static let ink = Color(nsColor: .labelColor)
  static let secondaryInk = Color(nsColor: .secondaryLabelColor)
  static let tertiaryInk = Color(nsColor: .tertiaryLabelColor)
  static let accent = Color.accentColor
  static let selectedControlFill = Color(nsColor: .selectedControlColor)
  static let selectedControlInk = Color(nsColor: .selectedControlTextColor)
  static let warning = Color(nsColor: .systemOrange)
  static let destructive = Color(nsColor: .systemRed)
  static let selectedFill = Color.accentColor.opacity(0.14)
  static let selectedStroke = Color.accentColor.opacity(0.75)
  static let insetFill = Color(nsColor: .textBackgroundColor).opacity(0.55)
  static let canvas = Color(nsColor: canvasBackground)
}

enum ToolPaletteMetrics {
  static let width: CGFloat = 176
  static let toolbarLabelWidth: CGFloat = 162
}

/// Shared dimensions mirrored by the Tauri design tokens in `styles.css`.
///
/// These values describe the common visual vocabulary only. Feature-specific
/// geometry (for example, canvas annotations) stays with the feature that owns
/// it instead of being forced into this namespace.
enum LeatherDesignMetrics {
  enum Spacing {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 6
    static let medium: CGFloat = 8
    static let large: CGFloat = 10
    static let extraLarge: CGFloat = 12
    static let panel: CGFloat = 16
    static let dialog: CGFloat = 20
  }

  enum Radius {
    static let control: CGFloat = 6
    static let tool: CGFloat = 7
    static let card: CGFloat = 8
    static let icon: CGFloat = 8
    static let pill: CGFloat = 999
  }

  enum Typography {
    static let body: CGFloat = 13
    static let title: CGFloat = 15
    static let section: CGFloat = 12
    static let label: CGFloat = 11
    static let caption: CGFloat = 10
  }

  enum Icon {
    static let toolbar: CGFloat = 22
    static let tool: CGFloat = 18
    static let palette: CGFloat = 15
    static let paletteFrame: CGFloat = 16
    static let action: CGFloat = 12
    static let small: CGFloat = 13
  }

  enum Control {
    static let height: CGFloat = 28
    static let compactHeight: CGFloat = 22
    static let toolButton: CGFloat = 34
    static let paletteToolHeight: CGFloat = 38
    static let chip: CGFloat = 28
  }

  enum Border {
    static let hairline: CGFloat = 1
    static let selected: CGFloat = 1.2
  }

}

extension View {
  func leatherControlHeight() -> some View {
    frame(minHeight: LeatherDesignMetrics.Control.height)
  }
}

extension Color {
  init(hex: String) {
    let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    var rgb: UInt64 = 0
    Scanner(string: value).scanHexInt64(&rgb)

    let red = Double((rgb >> 16) & 0xFF) / 255.0
    let green = Double((rgb >> 8) & 0xFF) / 255.0
    let blue = Double(rgb & 0xFF) / 255.0

    self.init(red: red, green: green, blue: blue)
  }
}

struct PanelHeader: View {
  let title: String
  let symbolName: String

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: symbolName)
        .font(.system(size: LeatherDesignMetrics.Typography.section, weight: .semibold))
        .foregroundStyle(LeatherColors.accent)
        .frame(width: 16)
      Text(title)
        .font(.system(size: LeatherDesignMetrics.Typography.section, weight: .semibold))
        .foregroundStyle(LeatherColors.ink)
      Spacer()
    }
  }
}

struct CanvasToolButton: View {
  let tool: CanvasTool
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      ToolIcon(
        tool: tool,
        size: LeatherDesignMetrics.Icon.tool,
        color: isSelected ? LeatherColors.accent : LeatherColors.ink
      )
      .frame(
        width: LeatherDesignMetrics.Control.toolButton,
        height: LeatherDesignMetrics.Control.toolButton
      )
      .background(isSelected ? LeatherColors.selectedFill : .clear)
      .clipShape(
        RoundedRectangle(cornerRadius: LeatherDesignMetrics.Radius.icon, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: LeatherDesignMetrics.Radius.icon, style: .continuous)
          .stroke(
            isSelected ? LeatherColors.selectedStroke : .clear,
            lineWidth: LeatherDesignMetrics.Border.selected
          )
      )
    }
    .buttonStyle(.borderless)
    .help(tool.displayName)
  }
}

struct LabeledToolButton: View {
  let tool: CanvasTool
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        ToolIcon(tool: tool, size: LeatherDesignMetrics.Icon.tool - 1, color: LeatherColors.ink)
          .frame(width: 20)
        Text(tool.displayName)
          .font(.system(size: LeatherDesignMetrics.Typography.section))
          .lineLimit(1)
        Spacer(minLength: 0)
      }
      .foregroundStyle(isSelected ? LeatherColors.ink : LeatherColors.ink)
      .padding(.horizontal, LeatherDesignMetrics.Spacing.large)
      .frame(height: LeatherDesignMetrics.Control.toolButton)
      .background(isSelected ? LeatherColors.selectedFill : .clear)
      .clipShape(
        RoundedRectangle(cornerRadius: LeatherDesignMetrics.Radius.tool, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: LeatherDesignMetrics.Radius.tool, style: .continuous)
          .stroke(
            isSelected ? LeatherColors.selectedStroke : .clear,
            lineWidth: LeatherDesignMetrics.Border.selected
          )
      )
    }
    .buttonStyle(.borderless)
    .help(tool.idleMessage)
  }
}

struct PaletteToolButton: View {
  let tool: CanvasTool
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(alignment: .top, spacing: 6) {
        ToolIcon(
          tool: tool,
          size: LeatherDesignMetrics.Icon.palette,
          color: isSelected ? LeatherColors.accent : LeatherColors.ink
        )
        .frame(
          width: LeatherDesignMetrics.Icon.paletteFrame,
          height: LeatherDesignMetrics.Icon.paletteFrame
        )
        Text(tool.displayName)
          .font(
            .system(
              size: LeatherDesignMetrics.Typography.section,
              weight: isSelected ? .semibold : .medium
            )
          )
          .lineLimit(2)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)
        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(LeatherColors.accent)
            .accessibilityHidden(true)
        }
      }
      .foregroundStyle(LeatherColors.ink)
      .padding(.horizontal, LeatherDesignMetrics.Spacing.small)
      .padding(.vertical, LeatherDesignMetrics.Spacing.small)
      .frame(
        maxWidth: .infinity,
        minHeight: LeatherDesignMetrics.Control.paletteToolHeight,
        alignment: .leading
      )
      .background(
        isSelected
          ? LeatherColors.selectedFill : Color(nsColor: .controlBackgroundColor).opacity(0.28)
      )
      .clipShape(
        RoundedRectangle(cornerRadius: LeatherDesignMetrics.Radius.control, style: .continuous)
      )
      .overlay(
        RoundedRectangle(
          cornerRadius: LeatherDesignMetrics.Radius.control,
          style: .continuous
        )
        .stroke(
          isSelected ? LeatherColors.selectedStroke : LeatherColors.panelStroke.opacity(0.26),
          lineWidth: isSelected
            ? LeatherDesignMetrics.Border.selected : LeatherDesignMetrics.Border.hairline
        )
      )
    }
    .buttonStyle(.borderless)
    .help(tool.idleMessage)
  }
}

struct ToolIcon: View {
  let tool: CanvasTool
  let size: CGFloat
  let color: Color

  var body: some View {
    switch tool.iconKind {
    case .system(let symbolName):
      Image(systemName: symbolName)
        .font(.system(size: size * 0.82, weight: .semibold))
        .foregroundStyle(color)
        .frame(width: size, height: size)
    default:
      ToolIconDrawing(kind: tool.iconKind, color: color)
        .frame(width: size, height: size)
    }
  }
}

private struct ToolIconDrawing: View {
  let kind: CanvasToolIconKind
  let color: Color

  var body: some View {
    Canvas { context, size in
      let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1.5, dy: 1.5)
      let stroke = GraphicsContext.Shading.color(color)
      let lineWidth = max(1.4, min(size.width, size.height) * 0.085)
      let dashStyle = StrokeStyle(
        lineWidth: lineWidth, lineCap: .round, lineJoin: .round, dash: [3, 2])
      let solidStyle = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)

      func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
      }

      func strokeLine(_ start: CGPoint, _ end: CGPoint, style: StrokeStyle = solidStyle) {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(path, with: stroke, style: style)
      }

      func strokeCircle(center: CGPoint, radius: CGFloat, style: StrokeStyle = solidStyle) {
        let circleRect = CGRect(
          x: center.x - radius,
          y: center.y - radius,
          width: radius * 2,
          height: radius * 2
        )
        context.stroke(Path(ellipseIn: circleRect), with: stroke, style: style)
      }

      func fillCircle(center: CGPoint, radius: CGFloat) {
        let circleRect = CGRect(
          x: center.x - radius,
          y: center.y - radius,
          width: radius * 2,
          height: radius * 2
        )
        context.fill(Path(ellipseIn: circleRect), with: stroke)
      }

      func strokeChevron(at tip: CGPoint, backA: CGPoint, backB: CGPoint) {
        strokeLine(backA, tip)
        strokeLine(backB, tip)
      }

      func strokeTick(center: CGPoint, height: CGFloat) {
        strokeLine(
          CGPoint(x: center.x - height * 0.35, y: center.y + height / 2),
          CGPoint(x: center.x + height * 0.35, y: center.y - height / 2)
        )
      }

      switch kind {
      case .point:
        fillCircle(center: point(0.5, 0.5), radius: rect.width * 0.16)
        strokeCircle(center: point(0.5, 0.5), radius: rect.width * 0.34)
      case .line:
        strokeLine(point(0.18, 0.82), point(0.82, 0.18))
        fillCircle(center: point(0.18, 0.82), radius: rect.width * 0.08)
        fillCircle(center: point(0.82, 0.18), radius: rect.width * 0.08)
      case .arc:
        var arc = Path()
        arc.addArc(
          center: point(0.5, 0.54),
          radius: rect.width * 0.34,
          startAngle: .degrees(205),
          endAngle: .degrees(342),
          clockwise: false
        )
        context.stroke(arc, with: stroke, style: solidStyle)
        fillCircle(center: point(0.18, 0.65), radius: rect.width * 0.06)
        fillCircle(center: point(0.82, 0.40), radius: rect.width * 0.06)
      case .centerLine(.diagonal):
        strokeLine(point(0.16, 0.84), point(0.84, 0.16), style: dashStyle)
        fillCircle(center: point(0.5, 0.5), radius: rect.width * 0.07)
      case .centerLine(.horizontal):
        strokeLine(point(0.12, 0.5), point(0.88, 0.5), style: dashStyle)
        strokeLine(point(0.5, 0.18), point(0.5, 0.82), style: dashStyle)
      case .centerLine(.vertical):
        strokeLine(point(0.5, 0.12), point(0.5, 0.88), style: dashStyle)
        strokeLine(point(0.18, 0.5), point(0.82, 0.5), style: dashStyle)
      case .fillet:
        strokeLine(point(0.18, 0.82), point(0.18, 0.42))
        strokeLine(point(0.58, 0.82), point(0.18, 0.82))
        var fillet = Path()
        fillet.addArc(
          center: point(0.58, 0.42),
          radius: rect.width * 0.40,
          startAngle: .degrees(180),
          endAngle: .degrees(90),
          clockwise: true
        )
        context.stroke(fillet, with: stroke, style: solidStyle)
      case .coincident:
        strokeCircle(center: point(0.43, 0.5), radius: rect.width * 0.18)
        strokeCircle(center: point(0.57, 0.5), radius: rect.width * 0.18)
        fillCircle(center: point(0.5, 0.5), radius: rect.width * 0.06)
      case .horizontalConstraint:
        strokeLine(point(0.16, 0.42), point(0.84, 0.42))
        strokeLine(point(0.16, 0.58), point(0.84, 0.58))
      case .verticalConstraint:
        strokeLine(point(0.42, 0.16), point(0.42, 0.84))
        strokeLine(point(0.58, 0.16), point(0.58, 0.84))
      case .parallel:
        strokeLine(point(0.30, 0.82), point(0.55, 0.18))
        strokeLine(point(0.50, 0.82), point(0.75, 0.18))
      case .perpendicular:
        strokeLine(point(0.24, 0.76), point(0.74, 0.76))
        strokeLine(point(0.24, 0.76), point(0.24, 0.26))
        var corner = Path()
        corner.move(to: point(0.24, 0.52))
        corner.addLine(to: point(0.46, 0.52))
        corner.addLine(to: point(0.46, 0.76))
        context.stroke(
          corner, with: stroke,
          style: StrokeStyle(lineWidth: lineWidth * 0.75, lineCap: .square, lineJoin: .miter))
      case .equalLength:
        strokeLine(point(0.16, 0.34), point(0.84, 0.34))
        strokeLine(point(0.16, 0.68), point(0.84, 0.68))
        strokeTick(center: point(0.42, 0.34), height: rect.width * 0.30)
        strokeTick(center: point(0.58, 0.68), height: rect.width * 0.30)
        fillCircle(center: point(0.16, 0.34), radius: rect.width * 0.045)
        fillCircle(center: point(0.84, 0.34), radius: rect.width * 0.045)
        fillCircle(center: point(0.16, 0.68), radius: rect.width * 0.045)
        fillCircle(center: point(0.84, 0.68), radius: rect.width * 0.045)
      case .angle:
        strokeLine(point(0.22, 0.78), point(0.78, 0.78))
        strokeLine(point(0.22, 0.78), point(0.68, 0.30))
        var arc = Path()
        arc.addArc(
          center: point(0.22, 0.78),
          radius: rect.width * 0.28,
          startAngle: .degrees(315),
          endAngle: .degrees(0),
          clockwise: false
        )
        context.stroke(
          arc, with: stroke, style: StrokeStyle(lineWidth: lineWidth * 0.75, lineCap: .round))
      case .symmetric:
        strokeLine(point(0.5, 0.12), point(0.5, 0.88), style: dashStyle)
        strokeLine(point(0.20, 0.34), point(0.42, 0.50))
        strokeLine(point(0.20, 0.66), point(0.42, 0.50))
        strokeLine(point(0.80, 0.34), point(0.58, 0.50))
        strokeLine(point(0.80, 0.66), point(0.58, 0.50))
      case .distance:
        fillCircle(center: point(0.20, 0.74), radius: rect.width * 0.065)
        fillCircle(center: point(0.80, 0.26), radius: rect.width * 0.065)
        strokeLine(point(0.20, 0.62), point(0.20, 0.36), style: dashStyle)
        strokeLine(point(0.80, 0.38), point(0.80, 0.64), style: dashStyle)
        strokeLine(point(0.30, 0.50), point(0.70, 0.50))
        strokeChevron(at: point(0.30, 0.50), backA: point(0.41, 0.42), backB: point(0.41, 0.58))
        strokeChevron(at: point(0.70, 0.50), backA: point(0.59, 0.42), backB: point(0.59, 0.58))
      case .segmentLength:
        strokeLine(point(0.16, 0.34), point(0.84, 0.34))
        fillCircle(center: point(0.16, 0.34), radius: rect.width * 0.055)
        fillCircle(center: point(0.84, 0.34), radius: rect.width * 0.055)
        strokeLine(point(0.16, 0.50), point(0.16, 0.78))
        strokeLine(point(0.84, 0.50), point(0.84, 0.78))
        strokeLine(point(0.25, 0.66), point(0.75, 0.66))
        strokeChevron(at: point(0.25, 0.66), backA: point(0.36, 0.58), backB: point(0.36, 0.74))
        strokeChevron(at: point(0.75, 0.66), backA: point(0.64, 0.58), backB: point(0.64, 0.74))
      case .diameter:
        strokeCircle(center: point(0.42, 0.58), radius: rect.width * 0.30)
        strokeLine(point(0.17, 0.58), point(0.67, 0.58))
        strokeChevron(at: point(0.17, 0.58), backA: point(0.29, 0.50), backB: point(0.29, 0.66))
        strokeChevron(at: point(0.67, 0.58), backA: point(0.55, 0.50), backB: point(0.55, 0.66))
        context.draw(
          Text("D")
            .font(.system(size: rect.width * 0.34, weight: .bold))
            .foregroundColor(color),
          at: point(0.80, 0.20)
        )
      case .radius:
        strokeCircle(center: point(0.42, 0.58), radius: rect.width * 0.30)
        strokeLine(point(0.42, 0.58), point(0.70, 0.48))
        fillCircle(center: point(0.42, 0.58), radius: rect.width * 0.045)
        context.draw(
          Text("r")
            .font(.system(size: rect.width * 0.34, weight: .bold))
            .foregroundColor(color),
          at: point(0.80, 0.20)
        )
      case .system:
        break
      }
    }
  }
}

struct ChipView: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.system(size: LeatherDesignMetrics.Typography.label, weight: .semibold))
      .foregroundStyle(LeatherColors.secondaryInk)
      .padding(.horizontal, LeatherDesignMetrics.Spacing.large)
      .frame(height: LeatherDesignMetrics.Control.chip)
      .background(LeatherColors.insetFill)
      .clipShape(Capsule())
  }
}

struct ConstraintStatusBadge: View {
  let status: ConstraintStatus
  var compact: Bool = false

  private var colors: (foreground: Color, background: Color) {
    switch status {
    case .unknown:
      return (Color(hex: "#475569"), Color(hex: "#E7EBE5"))
    case .underConstrained:
      return (Color(hex: "#9A3412"), Color(hex: "#FFEDD5"))
    case .fullyConstrained:
      return (Color(hex: "#166534"), Color(hex: "#DCFCE7"))
    case .overConstrained:
      return (Color(hex: "#92400E"), Color(hex: "#FEF3C7"))
    case .conflicting:
      return (Color(hex: "#991B1B"), Color(hex: "#FEE2E2"))
    }
  }

  private var symbolName: String {
    switch status {
    case .unknown:
      return "questionmark.circle"
    case .underConstrained:
      return "exclamationmark.triangle.fill"
    case .fullyConstrained:
      return "checkmark.circle.fill"
    case .overConstrained:
      return "exclamationmark.triangle"
    case .conflicting:
      return "exclamationmark.octagon.fill"
    }
  }

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: symbolName)
        .font(.system(size: compact ? 9 : 10, weight: .semibold))
        .accessibilityHidden(true)
      Text(status.displayName)
    }
    .font(.system(size: compact ? 10 : 11, weight: .bold))
    .foregroundStyle(colors.foreground)
    .padding(.horizontal, compact ? 8 : 10)
    .frame(height: compact ? 24 : 28)
    .background(colors.background)
    .clipShape(Capsule())
  }
}

struct InspectorSection<Content: View>: View {
  let title: String
  let symbolName: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: LeatherDesignMetrics.Spacing.large) {
      PanelHeader(title: title, symbolName: symbolName)
      VStack(alignment: .leading, spacing: LeatherDesignMetrics.Spacing.large) {
        content
      }
      .padding(.leading, 24)
      .padding(.trailing, 4)
    }
    .padding(.vertical, 6)
  }
}

struct InsetSurface<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    content
      .padding(LeatherDesignMetrics.Spacing.large)
      .background(LeatherColors.insetFill)
      .clipShape(
        RoundedRectangle(cornerRadius: LeatherDesignMetrics.Radius.card, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: LeatherDesignMetrics.Radius.card, style: .continuous)
          .strokeBorder(
            LeatherColors.panelStroke.opacity(0.45),
            lineWidth: LeatherDesignMetrics.Border.hairline
          )
      )
  }
}

struct SectionSeparator: View {
  var body: some View {
    Divider()
      .padding(.leading, 24)
  }
}

enum MacBackgroundMaterial {
  case window
  case header
  case sidebar
  case content

  var material: NSVisualEffectView.Material {
    switch self {
    case .window:
      return .windowBackground
    case .header:
      return .headerView
    case .sidebar:
      return .sidebar
    case .content:
      return .contentBackground
    }
  }

  var blendingMode: NSVisualEffectView.BlendingMode {
    switch self {
    case .window, .sidebar:
      return .behindWindow
    case .header, .content:
      return .withinWindow
    }
  }
}

struct MacVisualEffectBackground: NSViewRepresentable {
  let style: MacBackgroundMaterial

  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.state = .active
    return view
  }

  func updateNSView(_ view: NSVisualEffectView, context: Context) {
    view.material = style.material
    view.blendingMode = style.blendingMode
    view.state = .active
    view.isEmphasized = false
  }
}
