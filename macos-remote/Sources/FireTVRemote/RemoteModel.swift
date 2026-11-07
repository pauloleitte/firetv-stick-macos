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
    case volumeUp = "KEYCODE_VOLUME_UP"
    case volumeDown = "KEYCODE_VOLUME_DOWN"
    case mute = "KEYCODE_VOLUME_MUTE"
}

enum RemoteApp: String, CaseIterable, Identifiable {
    case netflix
    case youtube
    case primeVideo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .netflix: return "Netflix"
        case .youtube: return "YouTube"
        case .primeVideo: return "Prime"
        }
    }

    /// Nome do pacote Android. Confira no seu Fire TV se algum não abrir.
    var package: String {
        switch self {
        case .netflix: return "com.netflix.ninja"
        case .youtube: return "com.amazon.firetv.youtube"
        case .primeVideo: return "com.amazon.avod.thirdpartyclient"
        }
    }

    var color: Color {
        switch self {
        case .netflix: return Color(red: 0.70, green: 0.05, blue: 0.08)
        case .youtube: return Color(red: 0.80, green: 0.10, blue: 0.10)
        case .primeVideo: return Color(red: 0.10, green: 0.45, blue: 0.70)
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

    func send(_ key: RemoteKey) {
        let target = target
        Task.detached {
            ADB.shared.keyEvent(key.rawValue, target: target)
        }
    }

    func launch(_ app: RemoteApp) {
        let target = target
        Task.detached {
            ADB.shared.launch(package: app.package, target: target)
        }
    }
}
