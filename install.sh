#!/usr/bin/env bash
# Instala el módulo wfd64_autostart en un dispositivo con Magisk.
# Uso:
#   bash install.sh            # único dispositivo conectado
#   bash install.sh <serial>   # dispositivo específico
set -euo pipefail

# Git Bash / MSYS converts POSIX paths like /data/... into Windows paths.
# Disable that so adb receives the real device paths.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL='*'

ADB="${ADB:-adb}"
SERIAL="${1:-}"

if [ -n "$SERIAL" ]; then
    ADB="$ADB -s $SERIAL"
fi

echo "[1/4] Copiando archivos a /data/local/tmp..."
$ADB shell 'mkdir -p /data/local/tmp/wfd64_autostart'
$ADB push module.prop service.sh /data/local/tmp/wfd64_autostart/

echo "[2/4] Instalando módulo en /data/adb/modules/wfd64_autostart..."
$ADB shell 'su -c "mkdir -p /data/adb/modules/wfd64_autostart; cp /data/local/tmp/wfd64_autostart/module.prop /data/local/tmp/wfd64_autostart/service.sh /data/adb/modules/wfd64_autostart/; chmod 644 /data/adb/modules/wfd64_autostart/module.prop; chmod 755 /data/adb/modules/wfd64_autostart/service.sh; chcon -R u:object_r:system_file:s0 /data/adb/modules/wfd64_autostart"'

echo "[3/4] Arrancando wfdservice64 ahora..."
$ADB shell 'su -c "setprop vendor.wfdservice64 enable"'
sleep 2

echo "[4/4] Verificando..."
$ADB shell 'su -c "getprop init.svc.wfdservice64; getprop vendor.wfdservice64; service list | grep -i wfd"'

echo
echo "Listo. Reinicia el teléfono para confirmar el arranque automático."
