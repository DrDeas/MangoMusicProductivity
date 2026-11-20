import SwiftUI
import CoreText
import UIKit

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

extension Font {
    /// Lato, the typeface of the instrument. Falls back to the system font if registration failed.
    static func lato(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "Lato-Bold" : "Lato-Regular", size: size)
    }
}

enum Fonts {
    /// Registers the bundled .ttf files so `Font.custom` can find them. Call once at launch.
    static func register() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

enum Haptics {
    static var enabled = true

    static func tap() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func detent() {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

enum PanelStyle {
    /// Dark slate scene panel with white labels.
    case slate
    /// Light grey panel with a black title strip.
    case light
    /// The navy modulation bar.
    case navy
    /// The orange LFO section.
    case orange
}

struct PanelColors {
    var fill: Color
    var border: Color
    var titleFill: Color
    var titleText: Color
    var text: Color
    var subtext: Color
    /// Slider groove and wedge on this panel.
    var groove: Color
    var wedge: Color
}

/// Every colour the app draws with. Two skins, as in the plugin: Classic and Dark.
struct Skin {
    var isDark: Bool
    var header: Color
    var headerText: Color
    var gutter: Color
    var accent: Color
    /// Selected cell of a switch.
    var switchOn: Color
    var switchOnText: Color
    var pressed: Color
    var pressedText: Color
    var face: Color
    var faceBorder: Color
    var faceText: Color
    var faceDim: Color
    var handle: [Color]
    var handleStroke: Color
    var handleGrip: Color
    /// Dark-brown "LCD" wells with orange text.
    var lcd: Color
    var lcdText: Color
    var display: Color
    var displayGrid: Color
    var displayLine: Color
    var wave: Color
    var vuBack: Color
    var vuBorder: Color
    var modBlue = Color(hex: 0x2E86FE)
    var modFill = Color(hex: 0x123463)
    var modFrame = Color(hex: 0x205DB0)
    var modUsed = Color(hex: 0x40ADFF)
    var modSelectedFill = Color(hex: 0x2364C0)
    var modSelectedText = Color(hex: 0x90D8FF)
    var armedFill = Color(hex: 0x74AC48)
    var armedText = Color(hex: 0xADFF6B)
    var menuBack = Color(hex: 0x303030)
    var infoBack = Color.white
    var infoText = Color.black
    var danger = Color(hex: 0xD44040)
    var slate: PanelColors
    var light: PanelColors
    var navy: PanelColors
    var orange: PanelColors

    func panel(_ style: PanelStyle) -> PanelColors {
        switch style {
        case .slate: return slate
        case .light: return light
        case .navy: return navy
        case .orange: return orange
        }
    }

    /// Channel colours for boards and blocks.
    static let hues: [Color] = [
        Color(hex: 0xFF9000), Color(hex: 0x4487F6), Color(hex: 0x74AC48), Color(hex: 0xE85D4A),
        Color(hex: 0x40C8C0), Color(hex: 0xB79CE8), Color(hex: 0xF8C56D), Color(hex: 0xE88BB0),
    ]

    func hue(_ index: Int) -> Color {
        Skin.hues[((index % Skin.hues.count) + Skin.hues.count) % Skin.hues.count]
    }

    static let onHue = Color(hex: 0x1D1D1D)

    static let classic = Skin(
        isDark: false,
        header: Color(hex: 0xCDCED4),
        headerText: .black,
        gutter: .black,
        accent: Color(hex: 0xFF9000),
        switchOn: Color(hex: 0xFF9A10),
        switchOnText: Color(hex: 0x1D1D1D),
        pressed: Color(hex: 0x804900),
        pressedText: Color(hex: 0xFF9300),
        face: Color(hex: 0xE3E3E3),
        faceBorder: Color(hex: 0x979797),
        faceText: .black,
        faceDim: Color(hex: 0x979797),
        handle: [Color(hex: 0xDCDCDC), Color(hex: 0xC2C2C2)],
        handleStroke: .black,
        handleGrip: Color(hex: 0x393B45),
        lcd: Color(hex: 0x2F1C04),
        lcdText: Color(hex: 0xFF9000),
        display: .black,
        displayGrid: Color(hex: 0x404040),
        displayLine: Color(hex: 0x5A5A5A),
        wave: Color(hex: 0xFF9000),
        vuBack: Color(hex: 0x151515),
        vuBorder: Color(hex: 0x979797),
        slate: PanelColors(fill: Color(hex: 0x393B45), border: Color(hex: 0x4B515D), titleFill: Color(hex: 0x393B45),
                           titleText: .white, text: .white, subtext: Color(hex: 0xB6B6BA),
                           groove: .black, wedge: Color(hex: 0x98999B)),
        light: PanelColors(fill: Color(hex: 0xCDCED4), border: Color(hex: 0x4B515D), titleFill: .black,
                           titleText: Color(hex: 0xFF9000), text: .black, subtext: Color(hex: 0x4C4C4C),
                           groove: Color(hex: 0xF5F5F6), wedge: Color(hex: 0x98999B)),
        navy: PanelColors(fill: Color(hex: 0x1A3460), border: Color(hex: 0x4487F6), titleFill: Color(hex: 0x1A3460),
                          titleText: Color(hex: 0x90D8FF), text: Color(hex: 0xC0EBFF), subtext: Color(hex: 0x40ADFF),
                          groove: .black, wedge: Color(hex: 0x3C8DFC)),
        orange: PanelColors(fill: Color(hex: 0xFF9000), border: Color(hex: 0x393B45), titleFill: Color(hex: 0xDB7C00),
                            titleText: .black, text: .black, subtext: Color(hex: 0x5A3300),
                            groove: .black, wedge: Color(hex: 0xB06000))
    )

    static let dark = Skin(
        isDark: true,
        header: Color(hex: 0x2D2D2D),
        headerText: Color(hex: 0xB4B4B4),
        gutter: Color(hex: 0x050505),
        accent: Color(hex: 0xFF9300),
        switchOn: Color(hex: 0x399DFF),
        switchOnText: .white,
        pressed: Color(hex: 0xFF9300),
        pressedText: .black,
        face: Color(hex: 0x242424),
        faceBorder: Color(hex: 0x050505),
        faceText: Color(hex: 0xB4B4B4),
        faceDim: Color(hex: 0x737373),
        handle: [Color(hex: 0xE0E0E0), Color(hex: 0xA0A0A0)],
        handleStroke: Color(hex: 0x0F0F0F),
        handleGrip: Color(hex: 0x1F1F1F),
        lcd: Color(hex: 0x131313),
        lcdText: Color(hex: 0x40ADFF),
        display: Color(hex: 0x1A1A1A),
        displayGrid: Color(hex: 0x3C3C3C),
        displayLine: Color(hex: 0x4F4F4F),
        wave: Color(hex: 0x2E86FE),
        vuBack: Color(hex: 0x0F0F0F),
        vuBorder: Color(hex: 0x202020),
        slate: PanelColors(fill: Color(hex: 0x2D2D2D), border: Color(hex: 0x3C3C3C), titleFill: Color(hex: 0x005CB6),
                           titleText: Color(hex: 0xE5E5E5), text: Color(hex: 0xD0D0D0), subtext: Color(hex: 0x808080),
                           groove: Color(hex: 0xEEEEEE), wedge: Color(hex: 0x4F4F4F)),
        light: PanelColors(fill: Color(hex: 0x242424), border: Color(hex: 0x3C3C3C), titleFill: Color(hex: 0x043367),
                           titleText: Color(hex: 0xE5E5E5), text: Color(hex: 0xD0D0D0), subtext: Color(hex: 0x808080),
                           groove: Color(hex: 0xEEEEEE), wedge: Color(hex: 0x4F4F4F)),
        navy: PanelColors(fill: Color(hex: 0x1C1C1C), border: Color(hex: 0x2E86FE), titleFill: Color(hex: 0x1C1C1C),
                          titleText: Color(hex: 0x90D8FF), text: Color(hex: 0xC0EBFF), subtext: Color(hex: 0x40ADFF),
                          groove: Color(hex: 0xEEEEEE), wedge: Color(hex: 0x205DB0)),
        orange: PanelColors(fill: Color(hex: 0x2D2D2D), border: Color(hex: 0x3C3C3C), titleFill: Color(hex: 0x005CB6),
                            titleText: Color(hex: 0xE5E5E5), text: Color(hex: 0xD0D0D0), subtext: Color(hex: 0x808080),
                            groove: Color(hex: 0xEEEEEE), wedge: Color(hex: 0x4F4F4F))
    )
}

private struct SkinKey: EnvironmentKey {
    static let defaultValue = Skin.classic
}

private struct PanelStyleKey: EnvironmentKey {
    static let defaultValue = PanelStyle.slate
}

extension EnvironmentValues {
    var skin: Skin {
        get { self[SkinKey.self] }
        set { self[SkinKey.self] = newValue }
    }

    /// The panel a control sits on, so it can pick light or dark labels.
    var panelStyle: PanelStyle {
        get { self[PanelStyleKey.self] }
        set { self[PanelStyleKey.self] = newValue }
    }
}
