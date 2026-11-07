import AppKit
import SwiftUI

@main
struct FireTVRemoteApp: App {
    @StateObject private var model = RemoteModel()

    init() {
        // Sem ícone no Dock: o app vive só na barra de menu.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            RemoteView(model: model)
        } label: {
            Image(systemName: "tv")
        }
        .menuBarExtraStyle(.window)
    }
}
