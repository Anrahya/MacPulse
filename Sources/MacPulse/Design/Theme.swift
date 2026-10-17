import SwiftUI
import AppKit

// MARK: - Dynamic color helper

extension Color {
    /// Builds an appearance-aware color from two hex values.
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}

// MARK: - Theme

/// Warm monochrome editorial design tokens.
enum Theme {

    // MARK: Surfaces
    static let canvas        = Color.adaptive(light: 0xFBFAF8, dark: 0x171716)
    static let surface       = Color.adaptive(light: 0xFFFFFF, dark: 0x1E1E1C)
    static let surfaceSunken = Color.adaptive(light: 0xF5F4F1, dark: 0x141413)
    static let border        = Color.adaptive(light: 0xE8E7E3, dark: 0x2C2C29)
    static let borderStrong  = Color.adaptive(light: 0xD8D6D0, dark: 0x3A3A36)

    // MARK: Ink
    static let ink           = Color.adaptive(light: 0x1A1A18, dark: 0xF2F1ED)
    static let inkSecondary  = Color.adaptive(light: 0x787774, dark: 0x9A9893)
    static let inkTertiary   = Color.adaptive(light: 0xA8A6A1, dark: 0x6E6C68)

    // MARK: Muted pastel semantics
    static let accentRed     = Color.adaptive(light: 0x9F2F2D, dark: 0xE8928E)
    static let accentRedBg   = Color.adaptive(light: 0xFDEBEC, dark: 0x3A1F1E)
    static let accentBlue    = Color.adaptive(light: 0x1F6C9F, dark: 0x86BFE4)
    static let accentBlueBg  = Color.adaptive(light: 0xE1F3FE, dark: 0x172E3D)
    static let accentGreen   = Color.adaptive(light: 0x346538, dark: 0x96BE9A)
    static let accentGreenBg = Color.adaptive(light: 0xEDF3EC, dark: 0x1C2A1D)
    static let accentYellow  = Color.adaptive(light: 0x956400, dark: 0xD9B25C)
    static let accentYellowBg = Color.adaptive(light: 0xFBF3DB, dark: 0x322915)

    // MARK: Metrics
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let s: CGFloat = 4
        static let m: CGFloat = 8
        static let l: CGFloat = 12
    }

    // MARK: Type scale
    enum Typeface {
        /// Editorial serif for headline numerals and section titles.
        static func display(_ size: CGFloat) -> Font {
            .system(size: size, weight: .regular, design: .serif)
        }
        static func title(_ size: CGFloat = 17) -> Font {
            .system(size: size, weight: .regular, design: .serif)
        }
        static func heading(_ size: CGFloat = 12) -> Font {
            .system(size: size, weight: .semibold, design: .default)
        }
        static func body(_ size: CGFloat = 12) -> Font {
            .system(size: size, weight: .regular, design: .default)
        }
        static func caption(_ size: CGFloat = 11) -> Font {
            .system(size: size, weight: .regular, design: .default)
        }
        /// Tabular figures keep live-updating numbers from jittering.
        static func numeric(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .rounded)
                .monospacedDigit()
        }
        static func mono(_ size: CGFloat = 10, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
    }
}

// MARK: - Semantic status

/// Maps a 0...1 load ratio to a restrained semantic colour.
enum LoadLevel {
    case calm, elevated, high, critical

    init(_ ratio: Double) {
        switch ratio {
        case ..<0.55: self = .calm
        case ..<0.75: self = .elevated
        case ..<0.9:  self = .high
        default:      self = .critical
        }
    }

    var color: Color {
        switch self {
        case .calm:     Theme.accentGreen
        case .elevated: Theme.accentYellow
        case .high:     Theme.accentRed
        case .critical: Theme.accentRed
        }
    }

    var label: String {
        switch self {
        case .calm:     "Nominal"
        case .elevated: "Elevated"
        case .high:     "High"
        case .critical: "Critical"
        }
    }
}

// MARK: - Uppercase micro label

struct MicroLabel: View {
    let text: String
    var color: Color = Theme.inkTertiary

    var body: some View {
        Text(text.uppercased())
            .font(Theme.Typeface.mono(9, weight: .medium))
            .tracking(0.9)
            .foregroundStyle(color)
    }
}
