import SwiftUI
import UIKit
import WebKit

/// La pantalla única de la app: la app web de PasaStickers dentro de un WKWebView.
struct WebScreen: UIViewRepresentable {
    /// La app web publicada. Al cargarse desde aquí, las mejoras de la parte web
    /// llegan sin tener que reinstalar la app.
    static let home = URL(string: "https://haitianleo.github.io/curso-ingles/stickers/")!

    let hub: Hub

    func makeCoordinator() -> Coordinator { Coordinator(hub: hub) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true                 // el video de la grabación se ve dentro de la página
        config.mediaTypesRequiringUserActionForPlayback = []    // y puede arrancar solo, en silencio

        // La página sabe que corre dentro de la app porque existe este canal «pasa».
        let content = config.userContentController
        content.add(context.coordinator, name: "pasa")
        content.addUserScript(WKUserScript(
            source: "window.PasaNative = { version: 2 };",        // 2: además sabe abrir Instagram
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true))

        let fondo = UIColor(red: 0.07, green: 0.075, blue: 0.10, alpha: 1)
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        web.scrollView.contentInsetAdjustmentBehavior = .never  // la página ya respeta el notch por su cuenta
        web.isOpaque = false
        web.backgroundColor = fondo
        web.scrollView.backgroundColor = fondo
        web.allowsLinkPreview = false
        context.coordinator.web = web
        hub.stickers = web
        context.coordinator.loadHome()
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        weak var web: WKWebView?
        private let hub: Hub

        init(hub: Hub) { self.hub = hub }

        func loadHome() {
            // Siempre se pregunta al servidor si hay versión nueva de la página.
            web?.load(URLRequest(url: WebScreen.home, cachePolicy: .reloadRevalidatingCacheData))
        }

        // MARK: Mensajes que manda la página

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
            switch type {
            case "whatsappPack": sendPackToWhatsApp(body)
            case "instagram": hub.showInstagram = true
            case "reload": loadHome()
            default: break
            }
        }

        /// Le cuenta a la página cómo salió lo que pidió. `code` es una palabra fija, sin comillas.
        private func reply(_ ok: Bool, _ code: String) {
            let js = "window.PasaNativeResult && window.PasaNativeResult(\(ok ? "true" : "false"), '\(code)')"
            DispatchQueue.main.async { self.web?.evaluateJavaScript(js, completionHandler: nil) }
        }

        // MARK: Paquete de stickers para WhatsApp

        /// Entrega un paquete de stickers a WhatsApp por su vía oficial para apps de terceros:
        /// el paquete se deja en el portapapeles con un tipo propio de WhatsApp y luego se abre
        /// `whatsapp://stickerPack`; WhatsApp lo lee y pide confirmación para guardarlo.
        /// La página manda las imágenes ya en el formato que WhatsApp exige
        /// (WebP de 512×512; bandeja PNG de 96×96; entre 3 y 30 stickers).
        private func sendPackToWhatsApp(_ body: [String: Any]) {
            guard
                let identifier = body["identifier"] as? String,
                let name = body["name"] as? String,
                let publisher = body["publisher"] as? String,
                let tray = body["tray"] as? String,
                let incoming = body["stickers"] as? [[String: Any]],
                incoming.count >= 3, incoming.count <= 30
            else { reply(false, "datos"); return }

            let stickers: [[String: Any]] = incoming.compactMap { item in
                guard let data = item["data"] as? String, !data.isEmpty else { return nil }
                return ["image_data": data, "emojis": (item["emojis"] as? [String]) ?? ["😀"]]
            }
            guard stickers.count == incoming.count else { reply(false, "datos"); return }

            var pack: [String: Any] = [
                "identifier": identifier,
                "name": name,
                "publisher": publisher,
                "tray_image": tray,
                "stickers": stickers,
                "ios_app_store_link": "",
                "android_play_store_link": "",
            ]
            if (body["animated"] as? Bool) == true { pack["animated_sticker_pack"] = true }

            guard let url = URL(string: "whatsapp://stickerPack"), UIApplication.shared.canOpenURL(url) else {
                reply(false, "sin-whatsapp"); return
            }
            guard let data = try? JSONSerialization.data(withJSONObject: pack, options: []) else {
                reply(false, "datos"); return
            }
            UIPasteboard.general.setItems(
                [["net.whatsapp.third-party.sticker-pack": data]],
                options: [.localOnly: true, .expirationDate: Date(timeIntervalSinceNow: 60)])
            UIApplication.shared.open(url, options: [:]) { opened in
                self.reply(opened, opened ? "abierto" : "sin-whatsapp")
            }
        }

        // MARK: Navegación

        /// Dentro de la app solo se navega por PasaStickers; cualquier otro enlace se abre fuera.
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url, let scheme = url.scheme?.lowercased() else {
                decisionHandler(.allow); return
            }
            if scheme == "about" || scheme == "blob" || scheme == "data" { decisionHandler(.allow); return }
            if (scheme == "https" || scheme == "http") && url.host == WebScreen.home.host { decisionHandler(.allow); return }
            if navigationAction.targetFrame?.isMainFrame == false { decisionHandler(.allow); return }
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            decisionHandler(.cancel)
        }

        /// Enlaces que piden pestaña nueva (por ejemplo el bot de Telegram): se abren fuera.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            return nil
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            hub.stickersDidStartLoading()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            hub.stickersDidLoad()          // si esperaba algo traído de Instagram, se entrega ahora
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            showOffline()
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            loadHome()
        }

        /// Sin conexión no hay página que mostrar: aviso sencillo con un botón para reintentar.
        private func showOffline() {
            let html = """
            <!doctype html><html lang="es"><meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <body style="margin:0;height:100vh;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:18px;
              background:#12131a;color:#f4f1e8;font:17px -apple-system,system-ui,sans-serif;text-align:center;padding:24px">
              <p style="margin:0;max-width:300px">No hay conexión. PasaStickers necesita internet para abrir.</p>
              <button onclick="window.webkit.messageHandlers.pasa.postMessage({type:'reload'})"
                style="font:inherit;font-weight:700;border:0;border-radius:14px;padding:14px 22px;background:#ffd23f;color:#1a1505">Reintentar</button>
            </body></html>
            """
            web?.loadHTMLString(html, baseURL: nil)
        }
    }
}
