import SwiftUI

struct RemoteView: View {
    @ObservedObject var model: RemoteModel
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 16) {
            header

            if showSettings {
                settings
            }

            // Um container so para todo o bloco de controles: o SwiftUI
            // renderiza o vidro em conjunto, em vez de camada sobre camada.
            GlassEffectContainer {
                VStack(spacing: 16) {
                    dPad
                    controlRow
                    appsRow
                }
            }

            Divider()

            footer
        }
        .padding(18)
        .frame(width: 320)
        .onAppear {
            if !model.isConnected && !model.ip.isEmpty {
                model.connect()
            }
        }
    }

    // MARK: - Cabeçalho e configurações

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(model.isConnected ? Color.green : Color.orange)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text("Fire TV")
                    .font(.headline)
                Text(model.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            Button {
                showSettings.toggle()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.glass)
            .help("Configurações")
        }
    }

    private var settings: some View {
        HStack(spacing: 8) {
            TextField("IP da TV, ex: 192.168.0.5", text: $model.ip)
                .textFieldStyle(.roundedBorder)
            Button("Conectar") {
                model.connect()
            }
            .buttonStyle(.glassProminent)
        }
    }

    // MARK: - Direcional

    private var dPad: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                Color.clear.frame(width: 72, height: 72)
                directionButton("chevron.up", key: .up)
                Color.clear.frame(width: 72, height: 72)
            }
            GridRow {
                directionButton("chevron.left", key: .left)
                okButton
                directionButton("chevron.right", key: .right)
            }
            GridRow {
                Color.clear.frame(width: 72, height: 72)
                directionButton("chevron.down", key: .down)
                Color.clear.frame(width: 72, height: 72)
            }
        }
    }

    private func directionButton(_ systemImage: String, key: RemoteKey) -> some View {
        Button {
            model.send(key)
        } label: {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .frame(width: 72, height: 72)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
    }

    private var okButton: some View {
        Button {
            model.send(.ok)
        } label: {
            Text("OK")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .glassEffect(.regular.tint(.accentColor).interactive(), in: .circle)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Controles

    private var controlRow: some View {
        HStack(spacing: 10) {
            RemoteButton(title: "Voltar", systemImage: "arrow.uturn.backward") {
                model.send(.back)
            }
            RemoteButton(title: "Home", systemImage: "house.fill") {
                model.send(.home)
            }
            RemoteButton(title: "Play/Pause", systemImage: "playpause.fill") {
                model.send(.playPause)
            }
        }
    }

    // MARK: - Apps

    private var appsRow: some View {
        HStack(spacing: 8) {
            ForEach(RemoteApp.allCases) { app in
                Button {
                    model.launch(app)
                } label: {
                    Text(app.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .glassEffect(
                            .regular.tint(app.color).interactive(),
                            in: .rect(cornerRadius: 12)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Rodapé

    private var footer: some View {
        HStack {
            Button("Reconectar") {
                model.connect()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button("Sair") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .font(.caption)
    }
}

/// Botão retangular com ícone e legenda, usado na linha de controles.
struct RemoteButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.body)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
