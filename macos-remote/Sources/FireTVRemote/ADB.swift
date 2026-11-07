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

    func launch(package: String, target: String) {
        run([
            "-s", target, "shell", "monkey",
            "-p", package,
            "-c", "android.intent.category.LAUNCHER", "1",
        ])
    }
}
