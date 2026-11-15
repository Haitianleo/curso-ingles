import SwiftUI
import UIKit
import WebKit

/// Lo que comparten las dos pantallas de la app: la de stickers (la app web) y la de Instagram.
///
/// Cuando en Instagram se elige una imagen o un GIF, la página manda aquí su dirección; se
/// descarga el archivo original y se le entrega a la app web, que lo convierte en sticker.
final class Hub: NSObject, ObservableObject, WKScriptMessageHandler {
    /// Si la pantalla de Instagram está a la vista.
    @Published var showInstagram = false

    weak var stickers: WKWebView?
    /// La página de Instagram se conserva entre aperturas para no perder por dónde ibas.
    private(set) var instagram: WKWebView?

    private var stickersReady = false
    private var waiting: [String: Any]?

    /// Se presenta como Safari de iPhone: con el nombre de una app embebida, Instagram recorta
    /// funciones o insiste en abrir su app.
    static let safariUserAgent: String = {
        let parts = UIDevice.current.systemVersion.split(separator: ".")
        let os = parts.joined(separator: "_")
        let short = parts.prefix(2).joined(separator: ".")
        return "Mozilla/5.0 (iPhone; CPU iPhone OS \(os) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(short) Mobile/15E148 Safari/604.1"
    }()

    // MARK: Pantalla de stickers

    func stickersDidStartLoading() { stickersReady = false }

    func stickersDidLoad() {
        stickersReady = true
        if let item = waiting { waiting = nil; hand(item) }
    }

    /// Entrega un archivo a la app web. `edit` pide abrirlo en el recorte manual.
    private func deliver(base64: String, type: String, edit: Bool) {
        DispatchQueue.main.async {
            self.showInstagram = false
            let item: [String: Any] = ["data": base64, "type": type, "edit": edit]
            if self.stickersReady { self.hand(item) } else { self.waiting = item }
        }
    }

    private func hand(_ item: [String: Any]) {
        // Un instante de margen para que la pantalla de Instagram termine de cerrarse.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.stickers?.callAsyncJavaScript(
                "if (window.PasaImport) { window.PasaImport({ data: data, type: type, edit: edit }); }",
                arguments: item, in: nil, in: .page, completionHandler: nil)
        }
    }

    // MARK: Pantalla de Instagram

    /// Crea (la primera vez) la vista con la página de Instagram y el script que añade el
    /// botón «Pasar a PasaStickers».
    func instagramView(delegate: WKNavigationDelegate & WKUIDelegate) -> WKWebView {
        if let web = instagram {
            web.navigationDelegate = delegate
            web.uiDelegate = delegate
            return web
        }
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        // El script corre en un mundo aparte: la página de Instagram no puede verlo ni usar el canal.
        let world = WKContentWorld.defaultClient
        config.userContentController.add(self, contentWorld: world, name: "pasa")
        if let url = Bundle.main.url(forResource: "grab", withExtension: "js"),
           let source = try? String(contentsOf: url, encoding: .utf8) {
            config.userContentController.addUserScript(
                WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: world))
        }
        let web = WKWebView(frame: .zero, configuration: config)
        web.customUserAgent = Hub.safariUserAgent
        web.allowsBackForwardNavigationGestures = true
        web.allowsLinkPreview = false
        web.navigationDelegate = delegate
        web.uiDelegate = delegate
        web.load(URLRequest(url: URL(string: "https://www.instagram.com/")!))
        instagram = web
        return web
    }

    func reloadInstagram() {
        guard let web = instagram else { return }
        if web.url == nil { web.load(URLRequest(url: URL(string: "https://www.instagram.com/")!)) } else { web.reload() }
    }

    /// Mensajes del script de Instagram.
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], (body["type"] as? String) == "grab" else { return }
        let edit = (body["edit"] as? Bool) ?? false
        if let data = body["data"] as? String, !data.isEmpty {
            deliver(base64: data, type: (body["mime"] as? String) ?? "", edit: edit)
            return
        }
        guard let text = body["url"] as? String, let url = URL(string: text),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
            tellInstagram("Eso no se puede pasar.")
            return
        }
        var candidates = [url]
        if let gif = Hub.gifVersion(of: url) { candidates.insert(gif, at: 0) }
        fetch(candidates, 0, edit)
    }

    /// Los GIF de los comentarios vienen de GIPHY, que guarda cada animación en varios formatos
    /// con la misma dirección y distinta terminación. La versión .gif es la más fácil de leer
    /// cuadro a cuadro, así que se pide esa primero.
    static func gifVersion(of url: URL) -> URL? {
        guard let host = url.host?.lowercased(), host.hasSuffix("giphy.com") else { return nil }
        let ext = url.pathExtension.lowercased()
        guard ext == "webp" || ext == "mp4" else { return nil }
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        parts.path = String(parts.path.dropLast(ext.count)) + "gif"
        return parts.url
    }

    private func fetch(_ urls: [URL], _ index: Int, _ edit: Bool) {
        guard index < urls.count else { tellInstagram("No pude descargar eso."); return }
        var request = URLRequest(url: urls[index])
        request.timeoutInterval = 30
        request.setValue(Hub.safariUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.instagram.com/", forHTTPHeaderField: "Referer")
        URLSession.shared.dataTask(with: request) { data, response, _ in
            guard let data = data, let http = response as? HTTPURLResponse, http.statusCode == 200,
                  data.count > 64, data.count < 30_000_000 else {
                self.fetch(urls, index + 1, edit)
                return
            }
            self.deliver(base64: data.base64EncodedString(), type: http.mimeType ?? "", edit: edit)
        }.resume()
    }

    private func tellInstagram(_ text: String) {
        DispatchQueue.main.async {
            self.instagram?.callAsyncJavaScript(
                "if (window.__pasaSay) { window.__pasaSay(text); }",
                arguments: ["text": text], in: nil, in: .defaultClient, completionHandler: nil)
        }
    }
}
