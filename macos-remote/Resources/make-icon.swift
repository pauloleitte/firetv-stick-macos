// Gera o AppIcon.iconset a partir do símbolo "tv" do SF Symbols.
// Uso: swift make-icon.swift <pasta-de-saida.iconset>
//
// Evita versionar PNGs binários: o ícone é desenhado na hora do build, com
// as ferramentas que já vêm no macOS.

import AppKit

let destino = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon.iconset"

try? FileManager.default.createDirectory(
    atPath: destino, withIntermediateDirectories: true
)

/// Símbolo pintado de branco. Símbolos do sistema vêm com cor própria, então
/// o truque é desenhar e preencher por cima com `.sourceAtop`.
func simboloBranco(lado: CGFloat) -> NSImage? {
    let config = NSImage.SymbolConfiguration(pointSize: lado, weight: .medium)
    guard let base = NSImage(systemSymbolName: "tv", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) else { return nil }

    let tamanho = base.size
    let pintado = NSImage(size: tamanho)
    pintado.lockFocus()
    let rect = NSRect(origin: .zero, size: tamanho)
    base.draw(in: rect)
    NSColor.white.set()
    rect.fill(using: .sourceAtop)
    pintado.unlockFocus()
    return pintado
}

func desenha(lado px: Int) -> Data? {
    let lado = CGFloat(px)
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )
    guard let bitmap else { return nil }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    // Fundo arredondado, no formato que o macOS 26 usa para ícones.
    let margem = lado * 0.06
    let caixa = NSRect(x: margem, y: margem,
                       width: lado - margem * 2, height: lado - margem * 2)
    let forma = NSBezierPath(roundedRect: caixa,
                             xRadius: caixa.width * 0.225,
                             yRadius: caixa.width * 0.225)
    let degrade = NSGradient(colors: [
        NSColor(calibratedRed: 0.22, green: 0.24, blue: 0.30, alpha: 1),
        NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.11, alpha: 1),
    ])
    degrade?.draw(in: forma, angle: -90)

    if let simbolo = simboloBranco(lado: lado * 0.44) {
        let s = simbolo.size
        simbolo.draw(
            at: NSPoint(x: (lado - s.width) / 2, y: (lado - s.height) / 2),
            from: .zero, operation: .sourceOver, fraction: 1
        )
    }

    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])
}

// Nomes exigidos pelo iconutil.
let variantes: [(nome: String, px: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for v in variantes {
    guard let dados = desenha(lado: v.px) else {
        FileHandle.standardError.write(Data("falhou em \(v.nome)\n".utf8))
        exit(1)
    }
    try? dados.write(to: URL(fileURLWithPath: "\(destino)/\(v.nome).png"))
}

print("iconset gerado em \(destino)")
