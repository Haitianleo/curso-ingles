import SwiftUI
import UIKit
import WebKit

/// Instagram (su página web) a pantalla completa, con una barra arriba para volver.
/// Al mantener pulsada una imagen o un GIF aparece el botón que lo pasa a stickers
/// (lo añade `Recursos/grab.js`).
struct InstagramScreen: View {
    @ObservedObject var hub: Hub

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cerrar") { hub.showInstagram = false }
                Spacer()
                Text("Instagram").font(.headline)
                Spacer()
                Button { hub.reloadInstagram() } label: { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("Recargar")
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            Text("Mantén pulsado un sticker o GIF para pasarlo")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.bottom, 6)
            InstagramWeb(hub: hub)
        }
    }
}

private struct InstagramWeb: UIViewRepresentable {
    let hub: Hub

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        hub.instagramView(delegate: context.coordinator)
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        /// Todo se queda dentro de esta vista: el inicio de sesión pasa por varios dominios.
        /// Lo que no es web (por ejemplo el enlace que abriría la app de Instagram) se ignora.
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let scheme = navigationAction.request.url?.scheme?.lowercased() else { decisionHandler(.cancel); return }
            switch scheme {
            case "http", "https", "about", "blob", "data": decisionHandler(.allow)
            default: decisionHandler(.cancel)
            }
        }

        /// Enlaces que piden pestaña nueva: se abren aquí mismo.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
            return nil
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            webView.reload()
        }
    }
}
