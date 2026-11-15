import SwiftUI

/// PasaStickers para iPhone.
///
/// La app es una carcasa alrededor de la app web de PasaStickers. Le presta lo que una
/// página no puede hacer por sí sola:
///  - entregar paquetes de stickers a WhatsApp por su vía oficial (`WebScreen.swift`);
///  - mostrar Instagram por dentro y sacar de ahí el archivo original de un sticker o un GIF
///    (`InstagramScreen.swift`, `Hub.swift`, `Recursos/grab.js`).
@main
struct PasaStickersApp: App {
    @StateObject private var hub = Hub()

    var body: some Scene {
        WindowGroup {
            WebScreen(hub: hub)
                .ignoresSafeArea()
                .fullScreenCover(isPresented: $hub.showInstagram) {
                    InstagramScreen(hub: hub)
                }
        }
    }
}
