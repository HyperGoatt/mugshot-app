import AppKit
import WebKit

// Renders the isolated, static design board to exact iPhone-size PNGs.
// This does not build, install, or alter the Mugshot app.
final class PageDelegate: NSObject, WKNavigationDelegate {
    var loaded = false
    var error: Error?

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded = true
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.error = error
        loaded = true
    }
}

let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let source = folder.appendingPathComponent("mockups.html")
let destination = folder.appendingPathComponent("screens")
let repoRoot = folder.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let names = [
    "01-recipe-book", "02-paste-inspiration", "03-component-recipe",
    "04-drink-recipe", "05-home-method", "06-latte-recent",
    "07-latte-recognition", "08-component-sheet", "09-adjust-setup",
    "10-make-base", "11-actuals", "12-capture", "13-reflection",
    "13b-reflection-criteria",
    "14-keep-change", "15-review-private", "15b-review-private-details",
    "16-review-friends", "17-journal-detail", "17b-journal-preparation",
    "18-journal-discovery", "19-quick-log"
]

try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
let application = NSApplication.shared
application.setActivationPolicy(.prohibited)
let configuration = WKWebViewConfiguration()
let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 390, height: 844), configuration: configuration)
let delegate = PageDelegate()
webView.navigationDelegate = delegate
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 390, height: 844),
                      styleMask: .borderless, backing: .buffered, defer: false)
window.contentView = webView
window.orderFront(nil)
webView.loadFileURL(source, allowingReadAccessTo: repoRoot)

func spin(until done: @escaping () -> Bool) {
    while !done() {
        _ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.03))
    }
}

spin { delegate.loaded }
if let error = delegate.error { throw error }
// Local-file WebKit previews do not consistently execute inline scripts at
// navigation completion. Evaluate the static screen data once, then capture.
var initialized = false
var initializationError: Error?
webView.evaluateJavaScript("eval(document.querySelector('script').textContent)") { _, error in
    initializationError = error
    initialized = true
}
spin { initialized }
if let initializationError { throw initializationError }

for name in names {
    var rendered = false
    var renderError: Error?
    let safeName = name.replacingOccurrences(of: "'", with: "")
    webView.evaluateJavaScript("window.renderScreen('\(safeName)')") { _, error in
        renderError = error
        rendered = true
    }
    spin { rendered }
    if let renderError { throw renderError }
    // Give file-backed photography and Mugsy artwork time to resolve.
    let readyAt = Date().addingTimeInterval(0.20)
    spin { Date() >= readyAt }

    let capture = WKSnapshotConfiguration()
    capture.rect = CGRect(x: 0, y: 0, width: 390, height: 844)
    // WebKit encodes this at the host's 2x backing scale, yielding a
    // 1170-pixel-wide iPhone screenshot without oversized repository assets.
    capture.snapshotWidth = NSNumber(value: 585)
    var finished = false
    var outputError: Error?
    webView.takeSnapshot(with: capture) { image, error in
        defer { finished = true }
        if let error { outputError = error; return }
        guard let image, let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            outputError = NSError(domain: "MugshotV4Render", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "Could not encode \(name)"])
            return
        }
        do {
            try png.write(to: destination.appendingPathComponent("\(name).png"))
        } catch {
            outputError = error
        }
    }
    spin { finished }
    if let outputError { throw outputError }
    print("Rendered \(name)")
}
window.orderOut(nil)
