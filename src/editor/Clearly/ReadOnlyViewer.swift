import AppKit
import WebKit

/// A minimal read-only viewer window for quick file browsing.
/// Opens as a separate small window with rendered markdown preview.
/// No toolbar, no editing, no save prompts -- just traffic lights + content.
final class ReadOnlyViewer: NSWindowController {
    private static var openViewers: [URL: ReadOnlyViewer] = [:]

    /// Open a viewer for the given file URL.
    /// If a viewer for this file is already open and visible, brings it to front.
    static func open(fileURL: URL) {
        if let existing = openViewers[fileURL], existing.window?.isVisible == true {
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }
        let viewer = ReadOnlyViewer(fileURL: fileURL)
        openViewers[fileURL] = viewer
        viewer.showWindow(nil)
    }

    convenience init(fileURL: URL) {
        // 1. Read file content
        let content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""

        // 2. Render markdown to HTML
        let rawBody = MarkdownRenderer.renderHTML(content)
        let htmlBody = LocalImageSupport.resolveImageSources(in: rawBody, relativeTo: fileURL)

        // 3. Build full HTML document
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>\(PreviewCSS.css(fontSize: 13))</style>
        </head>
        <body>\(htmlBody)</body>
        </html>
        """

        // 4. Create WKWebView
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(LocalImageSchemeHandler(), forURLScheme: LocalImageSupport.scheme)
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 500, height: 400), configuration: config)
        webView.loadHTMLString(html, baseURL: fileURL.deletingLastPathComponent())

        // 5. Create window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = fileURL.lastPathComponent
        window.contentView = webView
        window.isReleasedWhenClosed = true
        window.center()

        self.init(window: window)
    }
}
