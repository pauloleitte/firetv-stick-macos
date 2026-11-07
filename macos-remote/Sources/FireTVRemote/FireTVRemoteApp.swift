import AppKit
import SwiftUI

@main
struct FireTVRemoteApp: App {
    // O ícone da barra e o painel são montados pelo delegate: ver
    // MenuBarController para o porquê de não usar MenuBarExtra.
    @NSApplicationDelegateAdaptor(MenuBarController.self) private var controller

    var body: some Scene {
        // O app vive só na barra de menu; nenhuma janela própria.
        Settings { EmptyView() }
    }
}
