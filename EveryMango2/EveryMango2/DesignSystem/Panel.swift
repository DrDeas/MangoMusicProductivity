import SwiftUI

/// A titled section of the instrument: rounded 1px-bordered box with a small caps title.
struct Panel<Trailing: View, Content: View>: View {
    @Environment(\.skin) private var skin
    let title: String
    var style: PanelStyle = .slate
    var padding: CGFloat = 10
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    var body: some View {
        let c = skin.panel(style)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(title.uppercased())
                    .font(.lato(11, bold: true))
                    .tracking(1.2)
                    .foregroundStyle(c.titleText)
                    .lineLimit(1)
                Spacer(minLength: 4)
                trailing()
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(c.titleFill)
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(c.fill)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(c.border, lineWidth: 1))
        .environment(\.panelStyle, style)
    }
}

extension Panel where Trailing == EmptyView {
    init(_ title: String, style: PanelStyle = .slate, padding: CGFloat = 10, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.style = style
        self.padding = padding
        self.trailing = { EmptyView() }
        self.content = content
    }
}

extension Panel {
    init(_ title: String, style: PanelStyle = .slate, padding: CGFloat = 10,
         @ViewBuilder trailing: @escaping () -> Trailing, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.style = style
        self.padding = padding
        self.trailing = trailing
        self.content = content
    }
}

/// Small label text in the colour of the panel it sits on.
struct PanelLabel: View {
    @Environment(\.skin) private var skin
    @Environment(\.panelStyle) private var style
    let text: String
    var dim = false
    var size: CGFloat = 12
    var bold = false

    init(_ text: String, dim: Bool = false, size: CGFloat = 12, bold: Bool = false) {
        self.text = text
        self.dim = dim
        self.size = size
        self.bold = bold
    }

    var body: some View {
        let c = skin.panel(style)
        Text(text)
            .font(.lato(size, bold: bold))
            .foregroundStyle(dim ? c.subtext : c.text)
    }
}

/// The black oscillator-display well with its dot grid.
struct DisplayWell<Content: View>: View {
    @Environment(\.skin) private var skin
    var height: CGFloat = 110
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                let cols = 21, rows = 9
                for r in 1..<rows {
                    for c in 1..<cols {
                        let p = CGPoint(x: size.width * CGFloat(c) / CGFloat(cols), y: size.height * CGFloat(r) / CGFloat(rows))
                        ctx.fill(Path(CGRect(x: p.x - 0.5, y: p.y - 0.5, width: 1, height: 1)), with: .color(skin.displayGrid))
                    }
                }
            }
            content()
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(skin.display)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

/// Dark-brown LCD well with orange text, as on the play-mode list and pitch-bend fields.
struct LCD: ViewModifier {
    @Environment(\.skin) private var skin
    var size: CGFloat = 13
    var bold = true

    func body(content: Content) -> some View {
        content
            .font(.lato(size, bold: bold))
            .foregroundStyle(skin.lcdText)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 3).fill(skin.lcd))
    }
}

extension View {
    func lcd(size: CGFloat = 13, bold: Bool = true) -> some View {
        modifier(LCD(size: size, bold: bold))
    }
}

/// The value info window: white box, black 1px frame.
struct InfoWindow: View {
    @Environment(\.skin) private var skin
    let text: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Text(text)
                .font(.lato(13))
                .foregroundStyle(skin.infoText)
                .lineLimit(2)
            if let actionTitle, let action {
                Button(actionTitle.uppercased(), action: action)
                    .font(.lato(12, bold: true))
                    .foregroundStyle(Color(hex: 0x804900))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(skin.infoBack)
        .overlay(Rectangle().strokeBorder(Color.black, lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
    }
}
