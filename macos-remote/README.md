# Fire TV Remote (macOS, SwiftUI)

Versão nativa do controle da barra de menu. Clique no ícone 📺 e aparece um controle remoto com direcional, volume, Voltar, Home, Play/Pause e atalhos para apps.

## Pré-requisitos

1. Xcode 15 ou superior, instalado pela App Store.
2. ADB instalado: `brew install android-platform-tools`
3. Na TV: Configurações → Meu Fire TV → Sobre, aperte OK ~7 vezes no nome do aparelho, depois ative **ADB debugging** em Opções do desenvolvedor.

## Como rodar

1. Abra `macos-remote/Package.swift` no Xcode.
2. Aperte Run (⌘R). O ícone aparece na barra de menu.
3. Clique no ícone, abra a engrenagem e digite o IP da TV (ex: `192.168.0.5`). O IP fica salvo no Mac.
4. Aceite o pedido de autorização que aparece na TV e marque a opção de sempre permitir.

## Estrutura

- `ADB.swift`: chama o `adb` do Mac com `Process`.
- `RemoteModel.swift`: estado da conexão, mapa de teclas (keycodes) e lista de apps.
- `RemoteView.swift`: o layout do controle.
- `FireTVRemoteApp.swift`: ponto de entrada com `MenuBarExtra`.

## Observações

- O app não tem ícone no Dock.
- Para trocar os apps, edite o `enum RemoteApp` em `RemoteModel.swift`.
- Se a interface não for atualizada, é só rodar de novo pelo Xcode.
