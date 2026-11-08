# WFD 64-bit Autostart (Anyview Cast / Miracast fix)

Módulo de Magisk que arranca automáticamente el servicio nativo **`wfdservice64`**
de Qualcomm, para que **Anyview Cast / Miracast** funcione en equipos donde la ROM
solo incluye el servicio de 64 bits.

Probado en un **Xiaomi Mi 10T Pro (`apollo`)** con **LineageOS (Android 17)**.

---

## El problema

En esta compilación de LineageOS existe únicamente:

```
/system_ext/bin/wfdservice64
```

pero la app `com.qualcomm.wfd.service` (WfdService) arranca el servicio de 32 bits
con la propiedad `vendor.wfdservice=enable`, apuntando a:

```
/system_ext/bin/wfdservice   <-- NO EXISTE
```

Como el binario no existe, el servicio `wfdservice` nunca se registra en
servicemanager y el stack Wi-Fi Display no puede iniciar sesión. En logcat se ve:

```text
E init    : Control message: Could not find 'aidl/wfdservice' for ctl.interface_start
W libbinder.ServiceManagerCppClient: Waited one second for wfdservice
D ExtendedRemoteDisplay: Failed to start RTSP Server!
```

El HAL `-/vendor/bin/wifidisplayhalservice` y los blobs de Qualcomm están bien; el
único problema es que nadie arranca el servicio nativo de 64 bits.

## La solución

Este módulo agrega un `service.sh` que:

1. Espera a que Android termine de arrancar (`sys.boot_completed=1`).
2. Si `wfdservice64` no está corriendo, dispara su arranque con
   `vendor.wfdservice64=enable` (definido en `/system_ext/etc/init/wfdservice.rc`).
3. Lo vigila cada 60 s: si el servicio se detiene (es `oneshot`), lo vuelve a
   arrancar.

El módulo vive en `/data/adb/modules/wfd64_autostart`, así que **sobrevive a las
actualizaciones OTA de LineageOS** (el OTA reemplaza system/vendor, no `/data`).

## Probado en

| Componente | Valor |
|---|---|
| Dispositivo | Xiaomi Mi 10T Pro (`apollo` / M2007J3SG) |
| ROM | LineageOS basada en Android 17 |
| Build | CP2A.260605.016 |
| Root | Magisk 31.1 |
| Resultado | Anyview Cast → Smart TV funcionando |

## Requisitos

- Root con **Magisk** (probado con 31.1). También debería funcionar en
  KernelSU/APatch con soporte de módulos.
- ROM que incluya `/system_ext/bin/wfdservice64`.
- `adb` para la instalación manual (opcional).

## Instalación

### Opción A: script

```bash
git clone https://github.com/sweetinmortal/wfd64-autostart.git
cd wfd64-autostart
bash install.sh            # usa el único dispositivo conectado
# o: bash install.sh <serial>
```

El script copia el módulo, ajusta permisos/contexto y arranca el servicio. Para
que quede activo desde el arranque, reinicia el teléfono.

### Opción B: manual con adb

```bash
adb shell 'mkdir -p /data/local/tmp/wfd64_autostart'
adb push module.prop service.sh /data/local/tmp/wfd64_autostart/

adb shell 'su -c "mkdir -p /data/adb/modules/wfd64_autostart; cp /data/local/tmp/wfd64_autostart/module.prop /data/local/tmp/wfd64_autostart/service.sh /data/adb/modules/wfd64_autostart/; chmod 644 /data/adb/modules/wfd64_autostart/module.prop; chmod 755 /data/adb/modules/wfd64_autostart/service.sh; chcon -R u:object_r:system_file:s0 /data/adb/modules/wfd64_autostart"'

adb shell 'su -c "setprop vendor.wfdservice64 enable"'
```

Reinicia para que el módulo lo arranque solo en cada boot.

## Verificar

```bash
adb shell 'su -c "getprop init.svc.wfdservice64; getprop vendor.wfdservice64; service list | grep -i wfd"'
```

Salida esperada:

```text
running
enable
291  wfdservice: [com.qti.IWiFiDisplayService]
```

## Desinstalar

```bash
adb shell 'su -c "rm -rf /data/adb/modules/wfd64_autostart; setprop vendor.wfdservice64 disable"'
adb reboot
```

## Actualizaciones de LineageOS

- El módulo está en `/data/adb/modules` y **no se borra** con el OTA.
- El OTA puede reemplazar la imagen de boot y quitar Magisk. Para conservar root:
  instala la actualización y, **antes de reiniciar**, usa
  *Magisk → Instalar → Instalar en la ranura inactiva (después del OTA)*.
- Si pierdes root, reinstala Magisk. El módulo sigue en `/data` y se activa solo
  en el siguiente arranque.

## Nota importante para castear

En la prueba exitosa el **punto de acceso (hotspot) estaba apagado** y el Wi-Fi
encendido. Tener el SoftAP activo (`wlan2`) mientras se usa Wi-Fi Direct provoca:

```text
p2p0: ... Association request to the driver failed
P2P-GROUP-FORMATION-FAILURE
```

Si te falla la conexión, apaga el hotspot y vuelve a intentar. También confirma:

```bash
adb shell 'settings get global wifi_display_on'   # debe ser 1
```

## Cómo funciona

```text
service.sh
 ├─ espera sys.boot_completed=1
 ├─ si wfdservice64 no está running:
 │    setprop vendor.wfdservice64 disable   (stop, sin efecto si no corre)
 │    setprop vendor.wfdservice64 enable    (start)
 └─ bucle cada 60 s: si se detuvo, lo reinicia
```

El script no modifica ninguna partición de sistema: solo usa propiedades de init
y el mecanismo de módulos de Magisk.

## Seguridad

- No recolecta ni envía datos.
- No incluye binarios de terceros: solo un script de shell y metadatos del módulo.
- No toca Wallet, Play Integrity ni otras particiones.

## English summary

Some LineageOS builds for `apollo` ship only the 64-bit Qualcomm WFD service
(`/system_ext/bin/wfdservice64`), while the WFD app starts the missing 32-bit one
(`vendor.wfdservice=enable`). As a result, Anyview Cast / Miracast fails
(`Could not find 'aidl/wfdservice'`, `Failed to start RTSP Server!`).

This Magisk module starts `wfdservice64` on boot and keeps it alive with a 60 s
watchdog. It lives in `/data/adb/modules`, so it survives LineageOS OTA updates.
Tested on Xiaomi Mi 10T Pro (`apollo`), LineageOS Android 17, Magisk 31.1.

**Tip:** turn the hotspot off while casting; the SoftAP conflicts with Wi-Fi
Direct and causes `P2P-GROUP-FORMATION-FAILURE`.

## Licencia

MIT. Ver [LICENSE](LICENSE).
