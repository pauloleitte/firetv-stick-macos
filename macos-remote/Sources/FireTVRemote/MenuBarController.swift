import AppKit
import SwiftUI

/// Painel sem moldura que aceita foco de teclado.
///
/// Um `NSPanel` com `styleMask` `.borderless` recusa virar janela-chave por
/// padrão, e aí o campo de IP não receberia digitação.
final class RemotePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Ícone da barra de menu e o painel do controle, montados na mão.
///
/// O `MenuBarExtra` do SwiftUI não permite mexer no fundo da janela dele: ela
/// fica transparente e nenhuma `NSView` é opaca, mas o SwiftUI pinta o fundo
/// na árvore de render, acima de qualquer material. Com `NSStatusItem` e
/// `NSPanel` próprios o fundo é nosso, e sai o translúcido de verdade.
@MainActor
final class MenuBarController: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panel: RemotePanel?
    private var outsideClickMonitor: Any?
    private let model = RemoteModel()

    /// Distância entre o ícone da barra e o topo do painel.
    private let gap: CGFloat = 6
    /// Folga mínima até a borda da tela.
    private let margin: CGFloat = 8

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildStatusItem()
        buildPanel()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Deixa rastro no log do sistema: se o app sumir sozinho, dá para
        // saber se foi encerramento normal (`log show --predicate
        // 'process == "FireTVRemote"'`) ou morte abrupta, que não loga nada.
        NSLog("FireTVRemote: encerrando normalmente")
        removeOutsideClickMonitor()
        // Sem isto o servidor do monkey ficaria preso rodando na TV.
        model.shutdown()
    }

    // MARK: - Montagem

    private func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "tv",
            accessibilityDescription: "Fire TV"
        )
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked)
        // Clique direito abre o menu; esquerdo abre o painel.
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
    }

    private func buildPanel() {
        let hosting = NSHostingView(rootView: RemoteView(model: model))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        hosting.wantsLayer = true
        // Sem isto a NSHostingView pinta um fundo opaco sobre o material.
        hosting.layer?.backgroundColor = NSColor.clear.cgColor

        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 14
        effect.layer?.masksToBounds = true
        effect.addSubview(hosting)

        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: effect.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
            hosting.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
        ])

        let panel = RemotePanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 480),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = effect
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.panel = panel
    }

    // MARK: - Abrir e fechar

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        let isRight = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true
        if isRight {
            showContextMenu()
        } else {
            toggle()
        }
    }

    /// Menu do clique direito. "Sair" vive aqui, e não no painel: lá ficava
    /// colado nos botões de uso e era fácil encerrar o app sem querer.
    private func showContextMenu() {
        close()
        guard let button = statusItem?.button else { return }
        let menu = NSMenu()
        let sair = NSMenuItem(
            title: "Sair do Fire TV Remote",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        sair.target = self
        menu.addItem(sair)
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: button.bounds.height + 4),
            in: button
        )
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func toggle() {
        guard let panel else { return }
        if panel.isVisible {
            close()
        } else {
            open()
        }
    }

    private func open() {
        guard let panel, let button = statusItem?.button else { return }

        // Altura real do conteudo do SwiftUI.
        if let content = panel.contentView {
            content.layoutSubtreeIfNeeded()
            panel.setContentSize(content.fittingSize)
        }

        panel.setFrameOrigin(originBelow(button, size: panel.frame.size))
        panel.orderFrontRegardless()
        panel.makeKey()
        addOutsideClickMonitor()
    }

    private func close() {
        panel?.orderOut(nil)
        removeOutsideClickMonitor()
    }

    /// Centraliza o painel sob o ícone, sem deixar vazar da tela.
    private func originBelow(_ button: NSStatusBarButton, size: NSSize) -> NSPoint {
        guard let buttonWindow = button.window else { return .zero }
        let onScreen = buttonWindow.convertToScreen(
            button.convert(button.bounds, to: nil)
        )
        var origin = NSPoint(
            x: onScreen.midX - size.width / 2,
            y: onScreen.minY - size.height - gap
        )
        if let visible = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame {
            origin.x = min(
                max(origin.x, visible.minX + margin),
                visible.maxX - size.width - margin
            )
            origin.y = max(origin.y, visible.minY + margin)
        }
        return origin
    }

    // MARK: - Fechar ao clicar fora

    private func addOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                // Clique no próprio ícone já é tratado por toggle(). Fechar
                // aqui faria o painel reabrir logo em seguida.
                if self.statusItemFrame()?.contains(NSEvent.mouseLocation) == true {
                    return
                }
                self.close()
            }
        }
    }

    /// Retângulo do ícone da barra, em coordenadas de tela.
    private func statusItemFrame() -> NSRect? {
        guard let button = statusItem?.button, let window = button.window else {
            return nil
        }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func removeOutsideClickMonitor() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }
}
