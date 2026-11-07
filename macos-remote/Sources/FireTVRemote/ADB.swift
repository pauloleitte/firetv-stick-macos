import Foundation

/// Executa comandos do adb. Todos os métodos são bloqueantes:
/// chame-os sempre fora da thread principal.
final class ADB {
    static let shared = ADB()

    private let candidatePaths = [
        "/opt/homebrew/bin/adb",
        "/usr/local/bin/adb",
        "\(NSHomeDirectory())/Library/Android/sdk/platform-tools/adb",
    ]

    var isInstalled: Bool { adbPath != nil }

    private var adbPath: String? {
        candidatePaths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    @discardableResult
    func run(_ arguments: [String]) -> (status: Int32, output: String) {
        guard let path = adbPath else {
            return (-1, "adb não encontrado. Instale com: brew install android-platform-tools")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return (-1, error.localizedDescription)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let text = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (process.terminationStatus, text)
    }

    func connect(to target: String) -> (ok: Bool, message: String) {
        let result = run(["connect", target])
        let text = result.output
        let ok = result.status == 0
            && (text.contains("connected to") || text.contains("already connected"))
            && !text.contains("failed")
            && !text.contains("cannot")
        return (ok, text)
    }

    func keyEvent(_ keycode: String, target: String) {
        run(["-s", target, "shell", "input", "keyevent", keycode])
    }

    /// Descobre a activity de launcher do pacote. Vazio = app nao instalado.
    private func resolveActivity(package: String, target: String) -> String {
        let result = run([
            "-s", target, "shell", "cmd", "package", "resolve-activity",
            "--brief", "-c", "android.intent.category.LAUNCHER", package,
        ])
        let last = result.output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .last { !$0.isEmpty } ?? ""
        return last.contains("/") ? last : ""
    }

    /// `monkey` deixa de injetar em algumas versoes do Fire OS; `am start` e o
    /// caminho correto e ainda deixa distinguir "app ausente" de "falha ao abrir".
    func launch(package: String, target: String) -> (ok: Bool, message: String) {
        let activity = resolveActivity(package: package, target: target)
        guard !activity.isEmpty else {
            return (false, "\(package) nao esta instalado na TV")
        }
        let result = run([
            "-s", target, "shell", "am", "start",
            "-a", "android.intent.action.MAIN",
            "-c", "android.intent.category.LAUNCHER",
            "-n", activity,
        ])
        let ok = result.status == 0 && !result.output.contains("Error")
        return (ok, result.output)
    }
}
