import AppKit
import SwiftUI

/// Horizontal column ruler aligned with the editor text column (`Theme.editorInsetX`) and monospace advance width.
struct ColumnRulerView: NSViewRepresentable {
    var fontSize: CGFloat

    func makeNSView(context: Context) -> ColumnRulerNSView {
        let v = ColumnRulerNSView()
        v.fontSize = fontSize
        return v
    }

    func updateNSView(_ nsView: ColumnRulerNSView, context: Context) {
        nsView.fontSize = fontSize
    }
}

final class ColumnRulerNSView: NSView {
    var fontSize: CGFloat = 16 {
        didSet {
            if oldValue != fontSize { needsDisplay = true }
        }
    }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        Theme.backgroundColor.setFill()
        bounds.fill()

        let font = Theme.editorFont(ofSize: fontSize)
        let charW = max(1, ("M" as NSString).size(withAttributes: [.font: font]).width)
        let inset = Theme.editorInsetX
        let textWidth = max(0, bounds.width - 2 * inset)
        let maxCol = min(512, max(1, Int(floor(textWidth / charW))))

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular),
            .foregroundColor: Theme.syntaxColor
        ]

        let h = bounds.height
        let baselineY = h * 0.42

        for col in 0..<maxCol {
            let colNumber = col + 1
            let x = inset + (CGFloat(col) + 0.5) * charW
            if x > bounds.width - inset { break }

            let isMajor = colNumber % 10 == 0
            let tickH: CGFloat = isMajor ? h * 0.45 : (colNumber % 5 == 0 ? h * 0.28 : h * 0.16)
            let path = NSBezierPath()
            path.move(to: NSPoint(x: x, y: h - 1))
            path.line(to: NSPoint(x: x, y: h - 1 - tickH))
            let lineColor = isMajor ? Theme.syntaxColor : Theme.syntaxColor.withAlphaComponent(0.4)
            lineColor.setStroke()
            path.lineWidth = isMajor ? 1.0 : 0.5
            path.stroke()

            if isMajor {
                let label = "\(colNumber)"
                let size = (label as NSString).size(withAttributes: labelAttrs)
                (label as NSString).draw(
                    at: NSPoint(x: x - size.width / 2, y: baselineY - size.height / 2),
                    withAttributes: labelAttrs
                )
            }
        }
    }
}
