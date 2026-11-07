# Fire TV Remote (macOS)

Controle o Fire TV Stick pela barra de menu do macOS, via ADB na rede Wi-Fi.
Clique no ícone 📺 e aparece um controle com direcional, Voltar, Home,
Play/Pause e atalhos para apps.

App nativo em SwiftUI, em `macos-remote/`.

## Pré-requisitos

1. **macOS 26+ e Xcode 26+** — a interface usa Liquid Glass
   (`.glassEffect`, `GlassEffectContainer`), disponível só a partir do
   macOS 26.
2. **ADB**: `brew install android-platform-tools`
3. **Depuração ADB na TV**: Configurações → Meu Fire TV → Sobre, aperte OK
   ~7 vezes no nome do aparelho; depois ative **Depuração ADB** em
   Opções do desenvolvedor.

## Como rodar

```bash
cd macos-remote && swift build && .build/debug/FireTVRemote
```

Ou abra `macos-remote/Package.swift` no Xcode e aperte ⌘R.

Na primeira execução, clique na engrenagem e digite o IP da TV. Ele fica
salvo no Mac (`UserDefaults`, chave `tvIP`). Aceite o pedido de autorização
que aparece na TV e marque "sempre permitir".

> Reserve um IP fixo para o stick no roteador. Se o IP mudar, o app perde a
> conexão e é preciso digitar o novo.

## Estrutura

| Arquivo | Papel |
|---|---|
| `ADB.swift` | Chama o `adb` do Mac via `Process` |
| `RemoteModel.swift` | Conexão, keycodes e lista de apps |
| `RemoteView.swift` | Layout do controle |
| `FireTVRemoteApp.swift` | Entrada, com `MenuBarExtra` |

Para trocar os apps dos atalhos, edite o `enum RemoteApp` em
`RemoteModel.swift`. Descubra o nome do pacote com:

```bash
adb -s <ip>:5555 shell pm list packages -3
```

## Por que não há controle de volume

**O app não tem botões de volume de propósito.** Eles existiam, não tinham
como funcionar e foram removidos. Em Fire TV Stick com saída HDMI não há
caminho via ADB:

- O Android trata o HDMI como saída de volume fixo: o `STREAM_MUSIC` fica
  travado no máximo e `input keyevent KEYCODE_VOLUME_UP` não tem efeito.
- O CEC direto exige a permissão `android.permission.HDMI_CEC`, que o shell
  do ADB não tem (`Neither user 2000 nor current process has ...`).
- `cmd media_session volume` responde "No shell command implementation" e o
  `media` do Fire OS não tem subcomando de volume.

O controle físico do Fire TV muda o volume por IR/CEC em hardware, fora do
Android — por isso ele funciona e o ADB não. Para volume pelo Mac seria
preciso um emissor IR na rede (ex.: um blaster Tuya).

## Problemas comuns

**`adb devices` mostra `offline` e o popup não aparece na TV.** O `adbd`
trava quando o stick troca de rede: ele aceita o TCP na porta 5555 e fecha
a conexão na hora, sem nunca mandar o pacote `AUTH` que gera o popup.
Ligar e desligar a Depuração ADB não resolve. **Reinicie o stick** (tire da
tomada por 10s), e depois:

```bash
adb kill-server && adb connect <ip>:5555 && adb devices
```

**Não sabe o IP do stick?** Procure a porta 5555 aberta na rede:

```bash
for i in $(seq 1 254); do (nc -z -G 1 192.168.0.$i 5555 2>/dev/null && echo "192.168.0.$i") & done; wait
```

## Observações

- O app não tem ícone no Dock — vive só na barra de menu.
- O ADB fica aberto na rede local. Desative a depuração na TV quando não
  estiver usando.
