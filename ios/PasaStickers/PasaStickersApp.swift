import SwiftUI

/// PasaStickers para iPhone.
///
/// La app es una carcasa: muestra la app web de PasaStickers a pantalla completa
/// y le presta lo que una página no puede hacer por sí sola, que es entregar
/// paquetes de stickers a WhatsApp por su vía oficial (ver `WebScreen.swift`).
@main
struct PasaStickersApp: App {
    var body: some Scene {
        WindowGroup {
            WebScreen()
                .ignoresSafeArea()
        }
    }
}
