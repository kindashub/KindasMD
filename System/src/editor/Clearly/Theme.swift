import AppKit
import SwiftUI

enum Theme {
    /// KindasMD: Menlo (system monospaced UI font).
    private static let editorFontNameCandidates = ["Menlo", "Menlo-Regular"]

    // MARK: - Editor Font
    static var editorFontSize: CGFloat {
        let size = UserDefaults.standard.double(forKey: "editorFontSize")
        return size > 0 ? CGFloat(size) : 12
    }

    /// Primary editor face: Menlo when available, else system monospaced.
    static func editorFont(ofSize size: CGFloat) -> NSFont {
        for name in editorFontNameCandidates {
            if let font = NSFont(name: name, size: size) {
                return font
            }
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    static var editorFont: NSFont { editorFont(ofSize: editorFontSize) }

    static func editorFontBold(size: CGFloat) -> NSFont {
        let base = editorFont(ofSize: size)
        return NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: .bold)
    }

    static var editorFontSwiftUI: Font { Font(Self.editorFont) }

    // MARK: - Margins
    static let editorInsetX: CGFloat = 24
    static let editorInsetTop: CGFloat = 10
    static let editorInsetBottom: CGFloat = 20

    // MARK: - Line Spacing
    static let lineSpacing: CGFloat = 0

    /// Desired line height = font natural height + lineSpacing
    static var editorLineHeight: CGFloat {
        let font = editorFont
        return ceil(font.ascender - font.descender + font.leading) + lineSpacing
    }

    /// Baseline offset to vertically center text within the line height
    static var editorBaselineOffset: CGFloat {
        let font = editorFont
        let naturalHeight = ceil(font.ascender - font.descender + font.leading)
        return (editorLineHeight - naturalHeight) / 2
    }

    // MARK: - Dynamic Colors (auto-resolve for light/dark)

    // MARK: Mono Zen palette (dark) — light mode keeps neutral grays

    static let backgroundColor = NSColor(name: "mzBackground") { appearance in
        appearance.isDark
            ? NSColor(red: 0.110, green: 0.110, blue: 0.106, alpha: 1)   // #1C1C1B
            : NSColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1)
    }

    static let textColor = NSColor(name: "mzText") { appearance in
        appearance.isDark
            ? NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)         // #FFFFFF
            : NSColor(red: 0.133, green: 0.133, blue: 0.133, alpha: 1)
    }

    static let syntaxColor = NSColor(name: "mzSyntax") { appearance in
        appearance.isDark
            ? NSColor(red: 0.40, green: 0.40, blue: 0.38, alpha: 1)
            : NSColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
    }

    static let heading1Color = NSColor(name: "mzHeading1") { appearance in
        appearance.isDark
            ? NSColor(red: 0.827, green: 0.820, blue: 0.780, alpha: 1)   // #D3D1C7
            : NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
    }

    static let heading2Color = NSColor(name: "mzHeading2") { appearance in
        appearance.isDark
            ? NSColor(red: 0.706, green: 0.698, blue: 0.663, alpha: 1)   // #B4B2A9
            : NSColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
    }

    static let heading3Color = NSColor(name: "mzHeading3") { appearance in
        appearance.isDark
            ? NSColor(red: 0.533, green: 0.529, blue: 0.502, alpha: 1)   // #888780
            : NSColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1)
    }

    static let headingColor = heading1Color

    static let boldColor = NSColor(name: "mzBold") { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 0.788, green: 0.647, blue: 0.353, alpha: 1)   // #C9A55A gold
            : NSColor(srgbRed: 0.15, green: 0.15, blue: 0.15, alpha: 1)
    }

    static let italicColor = NSColor(name: "mzItalic") { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 0.478, green: 0.620, blue: 0.541, alpha: 1)   // #7A9E8A sage green
            : NSColor(srgbRed: 0.25, green: 0.25, blue: 0.25, alpha: 1)
    }

    static let codeColor = NSColor(name: "mzCode") { appearance in
        appearance.isDark
            ? NSColor(red: 0.753, green: 0.439, blue: 0.439, alpha: 1)   // #C07070
            : NSColor(red: 0.75, green: 0.2, blue: 0.2, alpha: 1)
    }

    static let codeBackgroundColor = NSColor(name: "mzCodeBg") { appearance in
        appearance.isDark
            ? NSColor(red: 0.173, green: 0.173, blue: 0.165, alpha: 1)   // #2C2C2A
            : NSColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1)
    }

    static let linkColor = NSColor(name: "mzLink") { appearance in
        appearance.isDark
            ? NSColor(red: 0.482, green: 0.561, blue: 0.631, alpha: 1)   // #7B8FA1
            : NSColor(red: 0.2, green: 0.4, blue: 0.7, alpha: 1)
    }

    static let mathColor = NSColor(name: "mzMath") { appearance in
        appearance.isDark
            ? NSColor(red: 0.7, green: 0.5, blue: 0.9, alpha: 1)
            : NSColor(red: 0.5, green: 0.25, blue: 0.7, alpha: 1)
    }

    static let blockquoteColor = NSColor(name: "mzBlockquote") { appearance in
        appearance.isDark
            ? NSColor(red: 0.541, green: 0.494, blue: 0.420, alpha: 1)   // #8A7E6B
            : NSColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1)
    }

    static let strikethroughColor = NSColor(name: "mzStrikethrough") { appearance in
        appearance.isDark
            ? NSColor(red: 0.373, green: 0.369, blue: 0.353, alpha: 1)   // #5F5E5A
            : NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
    }

    static let frontmatterColor = NSColor(name: "mzFrontmatter") { appearance in
        appearance.isDark
            ? NSColor(red: 0.55, green: 0.55, blue: 0.65, alpha: 1)
            : NSColor(red: 0.35, green: 0.35, blue: 0.5, alpha: 1)
    }

    static let findHighlightColor = NSColor(name: "themeFindHighlight") { appearance in
        appearance.isDark
            ? NSColor(red: 0.6, green: 0.5, blue: 0.0, alpha: 0.3)
            : NSColor(red: 1.0, green: 0.9, blue: 0.0, alpha: 0.4)
    }

    static let findCurrentHighlightColor = NSColor(name: "themeFindCurrentHighlight") { appearance in
        appearance.isDark
            ? NSColor(red: 0.8, green: 0.6, blue: 0.0, alpha: 0.5)
            : NSColor(red: 1.0, green: 0.7, blue: 0.0, alpha: 0.6)
    }

    static var backgroundColorSwiftUI: Color { Color(nsColor: backgroundColor) }
}

extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}
