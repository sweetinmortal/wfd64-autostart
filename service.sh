#!/system/bin/sh
# Anyview Cast / Miracast fix for LineageOS (apollo)
#
# This ROM ships only /system_ext/bin/wfdservice64, but the Qualcomm WfdService
# app requests the missing 32-bit service (vendor.wfdservice=enable), so the
# native WFD service never starts and casting fails.
#
# This script starts the 64-bit service at boot and keeps it alive.
# It lives in /data/adb/modules, so it survives LineageOS OTA updates.

# Nothing to do if this ROM does not ship the 64-bit WFD service.
[ -x /system_ext/bin/wfdservice64 ] || exit 0

# Wait until Android has finished booting.
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
done

start_wfd64() {
    setprop vendor.wfdservice64 disable
    sleep 1
    setprop vendor.wfdservice64 enable
}

# Initial start.
if [ "$(getprop init.svc.wfdservice64)" != "running" ]; then
    start_wfd64
fi

# Watchdog: wfdservice64 is a 'oneshot' service, restart it if it stops.
while true; do
    sleep 60
    if [ "$(getprop init.svc.wfdservice64)" != "running" ]; then
        start_wfd64
    fi
done
