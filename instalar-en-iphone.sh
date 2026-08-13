#!/bin/bash
# Instala Andén en un iPhone conectado por cable.
#
# Requisitos previos (una sola vez):
#   1. Xcode > Ajustes > Cuentas: iniciá sesión con tu Apple ID.
#   2. En project.yml, poné tu DEVELOPMENT_TEAM (o exportá TEAM=XXXXXXXXXX).
#   3. Conectá el iPhone por cable, desbloquealo y tocá "Confiar".
#
# Uso:  ./instalar-en-iphone.sh

set -e
cd "$(dirname "$0")"

TEAM="${TEAM:-2TBBTAN27Z}"

echo "==> Detectando iPhone conectado"
DEVICE_ID=$(xcrun devicectl list devices 2>/dev/null | awk '/iPhone|iPad/ {print $(NF-2); exit}')
if [ -z "$DEVICE_ID" ]; then
  echo "No encontré ningún dispositivo. Conectá el iPhone por cable y desbloquealo."
  exit 1
fi
echo "    dispositivo: $DEVICE_ID"

echo "==> Regenerando proyecto"
xcodegen generate >/dev/null

echo "==> Compilando y firmando (provisioning automático)"
xcodebuild -project Anden.xcodeproj -scheme Anden \
  -destination "id=${DEVICE_ID}" \
  -configuration Debug \
  -derivedDataPath build-device \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="${TEAM}" \
  build

APP="build-device/Build/Products/Debug-iphoneos/Anden.app"
echo "==> Instalando ${APP}"
xcrun devicectl device install app --device "${DEVICE_ID}" "${APP}"

echo ""
echo "✅ Listo. Andén está en tu iPhone."
echo "   Primer uso: Ajustes > General > VPN y gestión de dispositivos > confiá en tu perfil."
echo "   Nota: con cuenta gratuita el perfil dura 7 días; después reinstalá."
