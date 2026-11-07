import Foundation
import SwiftUI

enum RemoteKey: String {
    case up = "KEYCODE_DPAD_UP"
    case down = "KEYCODE_DPAD_DOWN"
    case left = "KEYCODE_DPAD_LEFT"
    case right = "KEYCODE_DPAD_RIGHT"
    case ok = "KEYCODE_DPAD_CENTER"
    case back = "KEYCODE_BACK"
    case home = "KEYCODE_HOME"
    case playPause = "KEYCODE_MEDIA_PLAY_PAUSE"
}

enum RemoteApp: String, CaseIterable, Identifiable {
    case uniplay
    case youtube
    case spotify

    var id: String { rawValue }

    var title: String {
        switch self {
        case .uniplay: return "Uniplay"
        case .youtube: return "YouTube"
        case .spotify: return "Spotify"
        }
    }

    /// Nome do pacote Android. Confira no seu Fire TV se algum não abrir.
    var package: String {
        switch self {
        case .uniplay: return "com.uplay.android.one"
        case .youtube: return "com.amazon.firetv.youtube"
        case .spotify: return "com.spotify.tv.android"
        }
    }

    var color: Color {
        switch self {
        case .uniplay: return Color(red: 0.35, green: 0.25, blue: 0.70)
        case .youtube: return Color(red: 0.80, green: 0.10, blue: 0.10)
        case .spotify: return Color(red: 0.11, green: 0.73, blue: 0.33)
        }
    }
}

@MainActor
final class RemoteModel: ObservableObject {
    private static let ipKey = "tvIP"

    @Published var ip: String {
        didSet { UserDefaults.standard.set(ip, forKey: Self.ipKey) }
    }
    @Published private(set) var isConnected = false
    @Published private(set) var status = "Desconectado"

    init() {
        ip = UserDefaults.standard.string(forKey: Self.ipKey) ?? ""
    }

    private var target: String { "\(ip):5555" }

    func connect() {
        guard !ip.isEmpty else {
            status = "Informe o IP da TV"
            return
        }
        guard ADB.shared.isInstalled else {
            status = "adb não instalado"
            return
        }

        status = "Conectando..."
        let target = target
        Task.detached {
            let result = ADB.shared.connect(to: target)
            await MainActor.run {
                self.isConnected = result.ok
                self.status = result.ok
                    ? "Conectado a \(self.ip)"
                    : "Sem conexão: \(result.message)"
            }
        }
    }

    /// Teclas aguardando envio, acumuladas enquanto uma chamada está em voo.
    private var pending: [RemoteKey] = []
    private var isSending = false

    /// Teto por chamada, para o comando não crescer sem limite se alguém
    /// segurar o botão. O resto vai na leva seguinte.
    private static let maxPerBatch = 12

    func send(_ key: RemoteKey) {
        pending.append(key)
        sendNextBatch()
    }

    private func sendNextBatch() {
        guard !isSending, !pending.isEmpty else { return }
        let batch = Array(pending.prefix(Self.maxPerBatch))
        pending.removeFirst(batch.count)
        isSending = true

        let target = target
        let codes = batch.map(\.rawValue)
        Task.detached {
            ADB.shared.keyEvents(codes, target: target)
            await MainActor.run {
                self.isSending = false
                // O que chegou durante o envio sai agora, junto.
                self.sendNextBatch()
            }
        }
    }

    func launch(_ app: RemoteApp) {
        let target = target
        Task.detached {
            let result = ADB.shared.launch(package: app.package, target: target)
            if !result.ok {
                await MainActor.run {
                    self.status = "\(app.title): \(result.message)"
                }
            }
        }
    }
}
