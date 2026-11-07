#!/bin/bash
# Monta o FireTVRemote.app a partir do binário do SwiftPM.
#
# Uso:  ./build-app.sh [pasta-de-destino]
# Sem argumento, o .app sai nesta pasta.
set -euo pipefail
cd "$(dirname "$0")"

NOME="FireTVRemote"
DESTINO="${1:-$PWD}"
APP="$DESTINO/$NOME.app"

echo "==> compilando em release"
swift build -c release

echo "==> montando $NOME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/$NOME" "$APP/Contents/MacOS/$NOME"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"

echo "==> gerando o ícone"
ICONSET="$(mktemp -d)/AppIcon.iconset"
swift "Resources/make-icon.swift" "$ICONSET" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$(dirname "$ICONSET")"

# Assinatura ad-hoc: sem ela o macOS trata o app como código não assinado e
# pode recusar abrir. Não substitui uma assinatura de desenvolvedor, mas
# basta para rodar na própria máquina.
echo "==> assinando (ad-hoc)"
codesign --force --sign - "$APP" >/dev/null 2>&1

echo
echo "pronto: $APP"
echo "abra com:  open \"$APP\""
echo "para ter no Launchpad, mova para /Applications"
