import SwiftUI
import WebKit

/// Hosts the bundled game (Game/index.html) in a full-screen WKWebView.
///
/// - Saves: ios-bridge.js is injected at document start with the native save (see SaveStore).
/// - Arcade: cabinets load our other games from GitHub Pages inside an iframe, so sub-frame
///   navigation to the web is allowed; anything that tries to leave the game itself (the making-of
///   link, "Open in its own tab") opens in Safari instead.
/// - If iOS kills the web content process (memory pressure), the game reloads with the latest save.
struct GameView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "saves")
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .sanctuaryNight
        web.scrollView.backgroundColor = .sanctuaryNight
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.isScrollEnabled = false
        web.scrollView.bounces = false
        web.allowsLinkPreview = false
        web.allowsBackForwardNavigationGestures = false
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        #if DEBUG
        web.isInspectable = true  // Safari ▸ Develop ▸ (device) to debug the page
        #endif

        context.coordinator.web = web
        context.coordinator.loadGame()
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        weak var web: WKWebView?

        /// (Re)loads the game with a fresh copy of the save, so a reload never brings back an old one.
        func loadGame() {
            guard let web, let index = Bundle.main.gameResource("index", "html") else { return }
            let bridge = Bundle.main.gameResource("ios-bridge", "js").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
            let scripts = web.configuration.userContentController
            scripts.removeAllUserScripts()
            scripts.addUserScript(WKUserScript(source: SaveStore.shared.seedScript() + "\n" + bridge,
                                               injectionTime: .atDocumentStart, forMainFrameOnly: true))
            web.loadFileURL(index, allowingReadAccessTo: index.deletingLastPathComponent())
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "saves", message.frameInfo.isMainFrame else { return }
            SaveStore.shared.handle(message.body)
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = action.request.url else { return .cancel }
            let local = url.isFileURL || ["about", "blob", "data"].contains(url.scheme ?? "")
            let inFrame = !(action.targetFrame?.isMainFrame ?? true)
            if local || inFrame { return .allow }
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return .cancel
        }

        // target="_blank" links and window.open: hand them to Safari.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = action.request.url, !url.isFileURL { UIApplication.shared.open(url, options: [:], completionHandler: nil) }
            return nil
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            SaveStore.shared.flush()
            loadGame()
        }
    }
}

extension Bundle {
    /// Finds a file from the Game folder whether Xcode copied it flat or kept the folder.
    func gameResource(_ name: String, _ ext: String) -> URL? {
        url(forResource: name, withExtension: ext) ?? url(forResource: name, withExtension: ext, subdirectory: "Game")
    }
}
