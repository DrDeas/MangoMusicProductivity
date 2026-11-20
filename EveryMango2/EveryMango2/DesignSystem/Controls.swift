import SwiftUI

// MARK: Slider

/// The plugin's horizontal slider: a thin groove with a wedge showing the scale and a pill handle.
/// Drags are relative to where you touch, so grabbing it never makes the value jump. Double-tap resets.
struct SynthSlider: View {
    @Environment(\.skin) private var skin
    @Environment(\.panelStyle) private var style
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var defaultValue: Double?
    var format: (Double) -> String = { String(Int($0.rounded())) }

    @State private var dragStart: Double?

    private let handleWidth: CGFloat = 30
    private let inset: CGFloat = 16

    private var fraction: CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return CGFloat((min(max(value, range.lowerBound), range.upperBound) - range.lowerBound) / span)
    }

    var body: some View {
        let c = skin.panel(style)
        VStack(spacing: 1) {
            GeometryReader { geo in
                let travel = max(1, geo.size.width - inset * 2)
                ZStack(alignment: .topLeading) {
                    Canvas { ctx, size in
                        let y: CGFloat = 13
                        var wedge = Path()
                        wedge.move(to: CGPoint(x: inset, y: y - 1))
                        wedge.addLine(to: CGPoint(x: size.width - inset, y: y - 1))
                        wedge.addLine(to: CGPoint(x: size.width - inset, y: y - 8))
                        wedge.closeSubpath()
                        ctx.fill(wedge, with: .color(c.wedge))
                        ctx.fill(Path(CGRect(x: inset - 6, y: y - 1, width: size.width - inset * 2 + 12, height: 2)), with: .color(c.groove))
                        ctx.fill(Path(CGRect(x: inset - 1, y: y - 7, width: 1, height: 14)), with: .color(c.groove))
                        ctx.fill(Path(CGRect(x: size.width - inset, y: y - 7, width: 1, height: 14)), with: .color(c.groove))
                    }
                    handle
                        .offset(x: inset + travel * fraction - handleWidth / 2, y: 3)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { g in
                            if dragStart == nil { dragStart = value }
                            let span = range.upperBound - range.lowerBound
                            let raw = (dragStart ?? value) + Double(g.translation.width / travel) * span
                            set(raw)
                        }
                        .onEnded { _ in dragStart = nil }
                )
                .onTapGesture(count: 2) {
                    if let d = defaultValue { set(d) }
                }
            }
            .frame(height: 26)
            HStack {
                Text(label)
                    .font(.lato(11))
                    .foregroundStyle(c.subtext)
                Spacer()
                Text(format(value))
                    .font(.lato(12, bold: true))
                    .foregroundStyle(dragStart == nil ? c.text : skin.accent)
            }
            .padding(.horizontal, inset - 6)
        }
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(format(value))
        .accessibilityAdjustableAction { direction in
            set(value + (direction == .increment ? step : -step))
        }
    }

    private var handle: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(LinearGradient(colors: skin.handle, startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(skin.handleStroke, lineWidth: 1))
            .overlay(Rectangle().fill(dragStart == nil ? skin.handleGrip : skin.accent).frame(width: 1.5).padding(.vertical, 3))
            .frame(width: handleWidth, height: 20)
            .shadow(color: .black.opacity(skin.isDark ? 0.6 : 0.25), radius: 1, y: 1)
    }

    private func set(_ raw: Double) {
        var v = min(max(raw, range.lowerBound), range.upperBound)
        if step > 0 { v = (v / step).rounded() * step }
        if v != value {
            value = v
            Haptics.detent()
        }
    }
}

/// A slider over a fixed list of integer stops, such as the task-length steps.
struct SteppedSlider: View {
    let label: String
    let stops: [Int]
    @Binding var value: Int
    var format: (Int) -> String

    var body: some View {
        let index = Binding<Double>(
            get: { Double(nearest(to: value)) },
            set: { value = stops[min(max(Int($0.rounded()), 0), stops.count - 1)] }
        )
        SynthSlider(label: label, value: index, range: 0...Double(max(1, stops.count - 1)), step: 1,
                    format: { format(stops[min(max(Int($0.rounded()), 0), stops.count - 1)]) })
    }

    private func nearest(to v: Int) -> Int {
        var best = 0
        for (i, s) in stops.enumerated() where abs(s - v) < abs(stops[best] - v) { best = i }
        return best
    }
}

// MARK: Knob

/// A rotary knob. Drag up or down to turn it; double-tap resets.
struct SynthKnob: View {
    @Environment(\.skin) private var skin
    @Environment(\.panelStyle) private var style
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var defaultValue: Double?
    var size: CGFloat = 58
    var format: (Double) -> String = { String(Int($0.rounded())) }

    @State private var dragStart: Double?

    private var fraction: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return (min(max(value, range.lowerBound), range.upperBound) - range.lowerBound) / span
    }

    var body: some View {
        let c = skin.panel(style)
        VStack(spacing: 3) {
            Canvas { ctx, sz in
                drawKnob(&ctx, size: sz, track: c.groove)
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { g in
                        if dragStart == nil { dragStart = value }
                        let span = range.upperBound - range.lowerBound
                        set((dragStart ?? value) + Double((g.translation.width - g.translation.height) / 140) * span)
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .onTapGesture(count: 2) {
                if let d = defaultValue { set(d) }
            }
            Text(format(value))
                .font(.lato(12, bold: true))
                .foregroundStyle(dragStart == nil ? c.text : skin.accent)
                .lineLimit(1)
            Text(label)
                .font(.lato(10))
                .foregroundStyle(c.subtext)
                .lineLimit(1)
        }
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(format(value))
        .accessibilityAdjustableAction { direction in
            set(value + (direction == .increment ? step : -step))
        }
    }

    private func drawKnob(_ ctx: inout GraphicsContext, size sz: CGSize, track trackColor: Color) {
        let center = CGPoint(x: sz.width / 2, y: sz.height / 2)
        let radius: CGFloat = min(sz.width, sz.height) / 2 - 3
        let sweep: Double = 270
        let start = Angle.degrees(135)
        let valueEnd = Angle.degrees(135 + sweep * fraction)
        let fullEnd = Angle.degrees(135 + sweep)
        let stroke = StrokeStyle(lineWidth: 3, lineCap: .round)

        var track = Path()
        track.addArc(center: center, radius: radius, startAngle: start, endAngle: fullEnd, clockwise: false)
        ctx.stroke(track, with: .color(trackColor.opacity(0.9)), style: stroke)

        var arc = Path()
        arc.addArc(center: center, radius: radius, startAngle: start, endAngle: valueEnd, clockwise: false)
        ctx.stroke(arc, with: .color(skin.accent), style: stroke)

        let faceRadius: CGFloat = radius - 6
        let face = CGRect(x: center.x - faceRadius, y: center.y - faceRadius, width: faceRadius * 2, height: faceRadius * 2)
        let top = CGPoint(x: face.midX, y: face.minY)
        let bottom = CGPoint(x: face.midX, y: face.maxY)
        ctx.fill(Path(ellipseIn: face), with: .linearGradient(Gradient(colors: skin.handle), startPoint: top, endPoint: bottom))
        ctx.stroke(Path(ellipseIn: face), with: .color(skin.handleStroke), lineWidth: 1)

        let radians: Double = (135 + sweep * fraction) * Double.pi / 180
        let dx = CGFloat(cos(radians))
        let dy = CGFloat(sin(radians))
        let inner: CGFloat = radius - 15
        let outer: CGFloat = radius - 7
        var pointer = Path()
        pointer.move(to: CGPoint(x: center.x + dx * inner, y: center.y + dy * inner))
        pointer.addLine(to: CGPoint(x: center.x + dx * outer, y: center.y + dy * outer))
        let pointerColor: Color = dragStart == nil ? skin.handleGrip : skin.accent
        ctx.stroke(pointer, with: .color(pointerColor), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
    }

    private func set(_ raw: Double) {
        var v = min(max(raw, range.lowerBound), range.upperBound)
        if step > 0 { v = (v / step).rounded() * step }
        if v != value {
            value = v
            Haptics.detent()
        }
    }
}

// MARK: Switches

struct SwitchOption<T: Hashable>: Identifiable {
    let value: T
    let label: String
    var id: String { label }

    init(_ value: T, _ label: String) {
        self.value = value
        self.label = label
    }
}

/// The self-drawn multi-switch: one face, thin separators, the chosen cell lit orange.
struct MultiSwitch<T: Hashable>: View {
    @Environment(\.skin) private var skin
    let options: [SwitchOption<T>]
    @Binding var selection: T
    var height: CGFloat = 30
    var fontSize: CGFloat = 11

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                let on = option.value == selection
                Button {
                    if !on {
                        selection = option.value
                        Haptics.tap()
                    }
                } label: {
                    Text(option.label.uppercased())
                        .font(.lato(fontSize, bold: true))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(on ? skin.switchOnText : skin.faceText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(RoundedRectangle(cornerRadius: 2).fill(on ? skin.switchOn : Color.clear).padding(2))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
                if index < options.count - 1 {
                    Rectangle().fill(skin.faceBorder.opacity(0.6)).frame(width: 1).padding(.vertical, 5)
                }
            }
        }
        .frame(height: height)
        .background(RoundedRectangle(cornerRadius: 3).fill(skin.face))
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(skin.faceBorder, lineWidth: 1))
    }
}

/// A small latching button, like the mixer's mute and solo.
struct LatchButton: View {
    @Environment(\.skin) private var skin
    let label: String
    @Binding var isOn: Bool
    var onColor: Color?

    var body: some View {
        Button {
            isOn.toggle()
            Haptics.tap()
        } label: {
            Text(label.uppercased())
                .font(.lato(11, bold: true))
                .lineLimit(1)
                .foregroundStyle(isOn ? Skin.onHue : skin.faceText)
                .padding(.horizontal, 10)
                .frame(minWidth: 34, minHeight: 28)
                .background(RoundedRectangle(cornerRadius: 3).fill(isOn ? (onColor ?? skin.switchOn) : skin.face))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(skin.faceBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: Buttons

/// The plugin's text button: grey face, brown when pressed with orange text.
struct SynthButtonStyle: ButtonStyle {
    @Environment(\.skin) private var skin
    @Environment(\.isEnabled) private var enabled
    var prominent = false
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let fill: Color = pressed ? skin.pressed : (prominent ? skin.switchOn : skin.face)
        let text: Color = pressed ? skin.pressedText : (prominent ? skin.switchOnText : skin.faceText)
        return configuration.label
            .font(.lato(compact ? 11 : 12, bold: true))
            .textCase(.uppercase)
            .lineLimit(1)
            .foregroundStyle(text)
            .padding(.horizontal, compact ? 8 : 12)
            .frame(minHeight: compact ? 26 : 32)
            .background(RoundedRectangle(cornerRadius: 3).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(skin.faceBorder, lineWidth: 1))
            .opacity(enabled ? 1 : 0.5)
    }
}

extension ButtonStyle where Self == SynthButtonStyle {
    static var synth: SynthButtonStyle { SynthButtonStyle() }
    static var synthProminent: SynthButtonStyle { SynthButtonStyle(prominent: true) }
    static var synthCompact: SynthButtonStyle { SynthButtonStyle(compact: true) }
}

enum ModState {
    case unused, used, selected, armed
}

/// A modulation-source button: navy, square-cornered, cyan text; green when armed.
struct ModButton: View {
    @Environment(\.skin) private var skin
    let title: String
    var state: ModState = .unused
    var action: () -> Void

    var body: some View {
        let fill: Color
        let frame: Color
        let text: Color
        switch state {
        case .unused: fill = skin.modFill; frame = skin.modFrame; text = skin.modBlue
        case .used: fill = skin.modFill; frame = skin.modUsed; text = skin.modUsed
        case .selected: fill = skin.modSelectedFill; frame = skin.modSelectedText; text = skin.modSelectedText
        case .armed: fill = skin.armedFill; frame = skin.armedText; text = skin.armedText
        }
        return Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(.lato(11, bold: true))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(text)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: 28)
                .background(fill)
                .overlay(Rectangle().strokeBorder(frame, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The menu-as-control: label on the left, value on the right, a small black triangle.
struct MenuField<MenuContent: View>: View {
    @Environment(\.skin) private var skin
    let label: String
    let value: String
    @ViewBuilder var content: () -> MenuContent

    var body: some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 6) {
                Text(label)
                    .font(.lato(12))
                    .foregroundStyle(skin.faceDim)
                Spacer(minLength: 4)
                Text(value)
                    .font(.lato(12, bold: true))
                    .foregroundStyle(skin.faceText)
                    .lineLimit(1)
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(skin.faceText)
            }
            .padding(.horizontal, 9)
            .frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 3).fill(skin.face))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(skin.faceBorder, lineWidth: 1))
        }
    }
}

/// A text field drawn as a white dialog field (classic) or dark well (dark skin).
struct SynthField: View {
    @Environment(\.skin) private var skin
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal
    var onSubmit: (() -> Void)?

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(skin.faceDim), axis: axis)
            .font(.lato(14))
            .foregroundStyle(skin.isDark ? Color(hex: 0xE5E5E5) : Color.black)
            .tint(skin.accent)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 3).fill(skin.isDark ? Color(hex: 0x131313) : Color.white))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(skin.isDark ? Color(hex: 0x3C3C3C) : Color(hex: 0xA0A0A0), lineWidth: 1))
            .onSubmit { onSubmit?() }
    }
}

// MARK: Meters

/// The output meter: blue rising through orange into red past the 0 dB mark.
/// Here 1.0 means "the day is exactly full"; anything beyond runs into the red.
struct VUMeter: View {
    @Environment(\.skin) private var skin
    /// Top bar.
    var level: Double
    /// Bottom bar.
    var second: Double?

    var body: some View {
        Canvas { ctx, size in
            let inner = CGRect(x: 2, y: 2, width: size.width - 4, height: size.height - 4)
            let gradient = Gradient(stops: [
                .init(color: Color(hex: 0x399DFF), location: 0),
                .init(color: Color(hex: 0x399DFF), location: 0.115),
                .init(color: Color(hex: 0xFF9300), location: 0.79),
                .init(color: Color(hex: 0xFF0101), location: 0.80),
                .init(color: Color(hex: 0xFF0101), location: 1),
            ])
            var bars: [(value: Double, rect: CGRect)] = [(level, inner)]
            if let second {
                let h = (inner.height - 1) / 2
                bars = [
                    (level, CGRect(x: inner.minX, y: inner.minY, width: inner.width, height: h)),
                    (second, CGRect(x: inner.minX, y: inner.minY + h + 1, width: inner.width, height: h)),
                ]
            }
            for bar in bars {
                let width = bar.rect.width * CGFloat(min(max(bar.value, 0), 1.26) / 1.26)
                if width <= 0 { continue }
                let rect = bar.rect
                ctx.drawLayer { layer in
                    layer.clip(to: Path(CGRect(x: rect.minX, y: rect.minY, width: width, height: rect.height)))
                    layer.fill(Path(rect), with: .linearGradient(gradient, startPoint: CGPoint(x: rect.minX, y: 0), endPoint: CGPoint(x: rect.maxX, y: 0)))
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 3).fill(skin.vuBack))
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(skin.vuBorder, lineWidth: 1))
    }
}

// MARK: Task light

/// The round status light on every task. Tap to finish; it glows orange when done.
struct TaskLight: View {
    @Environment(\.skin) private var skin
    let status: TaskStatus
    var size: CGFloat = 24
    var action: () -> Void

    var body: some View {
        Button {
            status == .done ? Haptics.tap() : Haptics.success()
            action()
        } label: {
            ZStack {
                Circle().fill(fill)
                Circle().strokeBorder(skin.faceBorder, lineWidth: 1)
                if status == .done {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.45, weight: .heavy))
                        .foregroundStyle(Skin.onHue)
                } else if status == .working {
                    Circle().fill(skin.accent).frame(width: size * 0.36, height: size * 0.36)
                } else if status == .stuck {
                    Circle().fill(skin.modBlue).frame(width: size * 0.36, height: size * 0.36)
                }
            }
            .frame(width: size, height: size)
            .shadow(color: status == .done ? skin.accent.opacity(0.7) : .clear, radius: 4)
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(status == .done ? "Mark not done" : "Mark done")
    }

    private var fill: Color {
        status == .done ? skin.accent : skin.face
    }
}

/// A tiny square colour tag, like the mixer's route blocks.
struct HueTag: View {
    @Environment(\.skin) private var skin
    let hue: Int
    var width: CGFloat = 5

    var body: some View {
        RoundedRectangle(cornerRadius: 1).fill(skin.hue(hue)).frame(width: width)
    }
}
