import Darwin
import Foundation

/// Canal rápido de teclas, por cima do servidor de socket do `monkey`.
///
/// `adb shell input keyevent` sobe uma VM no Fire TV a cada chamada e custa
/// ~1,3s. O `monkey` sabe rodar como servidor (`--port`) e fica residente:
/// cada tecla vira uma linha de texto num socket já aberto. Medido num Fire
/// TV Stick 4K (AFTMM, Fire OS 7.1.2): **1300ms → 42ms**.
///
/// O `monkey` é ferramenta de teste e o processo pode morrer. Por isso
/// `send` devolve `false` em qualquer falha, e quem chama deve cair no
/// `input keyevent`, que é lento mas sempre funciona.
final class InputChannel {
    /// Porta usada na TV e no encaminhamento local. Nada de 1080/8080, que
    /// costumam estar ocupados.
    private let port = 8787

    private var server: Process?
    private var fd: Int32 = -1

    private let adbPath: String
    private let target: String

    init(adbPath: String, target: String) {
        self.adbPath = adbPath
        self.target = target
    }

    deinit { stop() }

    var isOpen: Bool { fd >= 0 }

    // MARK: - Ciclo de vida

    /// Sobe o servidor na TV e abre o socket. Devolve `false` se não deu —
    /// aí o app segue no caminho lento, sem quebrar.
    @discardableResult
    func start() -> Bool {
        stop()

        // Um servidor preso de uma execução anterior seguraria a porta.
        runAdb(["-s", target, "shell", "pkill -f 'monkey --port'"])
        runAdb(["-s", target, "forward", "--remove", "tcp:\(port)"])
        guard runAdb(["-s", target, "forward", "tcp:\(port)", "tcp:\(port)"]) else {
            return false
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: adbPath)
        process.arguments = ["-s", target, "shell", "monkey", "--port", "\(port)"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return false
        }
        server = process

        // O monkey leva alguns segundos para abrir a porta.
        for _ in 0..<20 {
            Thread.sleep(forTimeInterval: 0.25)
            if connect() { return true }
        }
        stop()
        return false
    }

    func stop() {
        if fd >= 0 {
            close(fd)
            fd = -1
        }
        if let server, server.isRunning {
            server.terminate()
        }
        server = nil
        runAdb(["-s", target, "forward", "--remove", "tcp:\(port)"])
    }

    // MARK: - Envio

    /// Envia as teclas pelo socket. `false` = use o caminho lento.
    func send(_ keycodes: [String]) -> Bool {
        guard !keycodes.isEmpty else { return true }
        guard isOpen || connect() else { return false }

        let comandos = keycodes.map { "press \($0)\n" }.joined()
        guard write(comandos) else {
            dropSocket()
            return false
        }
        // O monkey responde "OK" por comando. Sem resposta = servidor morto.
        guard let resposta = read(), resposta.contains("OK") else {
            dropSocket()
            return false
        }
        return true
    }

    // MARK: - Socket

    private func connect() -> Bool {
        dropSocket()
        let s = socket(AF_INET, SOCK_STREAM, 0)
        guard s >= 0 else { return false }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let ok = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(s, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
            }
        }
        guard ok else {
            close(s)
            return false
        }

        // Sem timeout, um servidor morto travaria a thread de envio.
        var tv = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(s, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(s, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        fd = s
        return true
    }

    private func dropSocket() {
        if fd >= 0 {
            close(fd)
            fd = -1
        }
    }

    private func write(_ texto: String) -> Bool {
        let bytes = Array(texto.utf8)
        var enviados = 0
        while enviados < bytes.count {
            let n = bytes.withUnsafeBufferPointer {
                Darwin.send(fd, $0.baseAddress! + enviados, bytes.count - enviados, 0)
            }
            if n <= 0 { return false }
            enviados += n
        }
        return true
    }

    private func read() -> String? {
        var buffer = [UInt8](repeating: 0, count: 256)
        let n = recv(fd, &buffer, buffer.count, 0)
        guard n > 0 else { return nil }
        return String(decoding: buffer[0..<n], as: UTF8.self)
    }

    // MARK: - adb

    @discardableResult
    private func runAdb(_ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: adbPath)
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return false
        }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
