# VMware Workstation: solución a `Virtualized AMD-V/RVI is not supported on this platform` en Windows 11 + AMD

[**English**](./README.md) | [**Español**](./README_ES.md) | [**Support / Soporte**](./SUPPORT.md)

Guía práctica y **troubleshooter bilingüe de solo lectura** para problemas de virtualización anidada AMD-V/RVI en VMware Workstation sobre Windows 11.

Útil para:

- PNETLab
- EVE-NG
- GNS3 VM
- ESXi anidado
- Otras VMs que necesiten AMD-V/RVI dentro de VMware

---

## Empieza por aquí: troubleshooter bilingüe v2

Antes de cambiar configuraciones de Windows, descarga y ejecuta [`diagnose-hypervisor.ps1`](./diagnose-hypervisor.ps1) desde **PowerShell como administrador**.

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\diagnose-hypervisor.ps1
```

El script permite elegir idioma al iniciar:

```text
[1] Espanol
[2] English
```

También puedes indicarlo directamente:

```powershell
.\diagnose-hypervisor.ps1 -Language es
.\diagnose-hypervisor.ps1 -Language en
```

### Qué hace la versión 2

El troubleshooter analiza el equipo, aplica un pequeño **motor de reglas** y trata de recomendar **solo el siguiente paso relevante**, en vez de pedir a todo el mundo que desactive todas las protecciones de Windows.

Comprueba:

- AMD-V / SVM en firmware
- SLAT / RVI
- `HypervisorPresent`
- VBS / Device Guard
- configuración de Memory Integrity / HVCI
- características opcionales de Windows relacionadas con Hyper-V
- `hypervisorlaunchtype` y `vsmlaunchtype`
- escenario `WindowsHello` de Device Guard
- Secure Boot
- estado de protección de BitLocker en `C:`
- servicio `hvhost`
- presencia de eventos recientes ID 2 del hipervisor de Hyper-V
- versión de VMware Workstation cuando puede detectarla

Ejemplo de la lógica:

```text
HypervisorPresent = TRUE
VBS               = 0
Hyper-V features  = Disabled
BCD                = Off
WindowsHello       = Enabled

Recomendación:
Revisar solamente el paso 9.
```

Después reinicias, vuelves a ejecutar el troubleshooter y solo continúas si sigue siendo necesario.

### Diseñado como solo lectura

El diagnóstico **no modifica**:

- configuraciones de Windows
- Registro
- BCD
- BitLocker
- Secure Boot
- BIOS/UEFI
- características opcionales de Windows
- VMware

Puede guardar opcionalmente un **reporte sanitizado TXT y JSON**, pero nunca aplica las correcciones automáticamente.

### Reporte para compartir

Al terminar, el script muestra un bloque parecido a este:

```text
--- BEGIN VMWARE AMD-V/RVI DIAGNOSTIC REPORT ---
...
RecommendationCode=...
RecommendedGuideStep=...
--- END VMWARE AMD-V/RVI DIAGNOSTIC REPORT ---
```

El reporte excluye intencionalmente hostname, nombre de usuario, claves de recuperación de BitLocker, claves de producto y números de serie. Aun así, revisa siempre lo que vas a publicar.

Consulta [SUPPORT.md](./SUPPORT.md) para ver cómo pegar ese reporte en GitHub Issues, ChatGPT, Broadcom Community u otro canal de soporte.

Para guardarlo directamente:

```powershell
.\diagnose-hypervisor.ps1 -Language es -ExportReport
```

Crea:

```text
vmware-amd-rvi-report.txt
vmware-amd-rvi-report.json
```

---

## Error de VMware

VMware puede mostrar:

```text
Virtualized AMD-V/RVI is not supported on this platform.
Continue without virtualized AMD-V/RVI?
```

o:

```text
Feature 'hv.capable' was 0, but must be at least 0x1.
Module 'FeatureCompatLate' power on failed.
Failed to start the virtual machine.
```

## La comprobación clave

No basta con mirar si Hyper-V está desmarcado o si VBS informa `0`.

Ejecuta:

```powershell
Get-CimInstance Win32_ComputerSystem |
Select-Object HypervisorPresent
```

Para esta ruta de diagnóstico queremos llegar a:

```text
HypervisorPresent
-----------------
False
```

Si sigue en `True`, Windows todavía está reportando un hipervisor de host.

> **Deja de cambiar configuraciones en cuanto `HypervisorPresent` pase a `False`.**
> No todos los equipos necesitan todos los pasos siguientes.

---

## Entorno validado

El procedimiento se validó con:

- ASUS TUF Gaming A16 FA607NUG
- AMD Ryzen 7 7445HS
- Windows 11 Pro 25H2, compilación 26200.9168
- VMware Workstation 26.0.0.25388281
- PNETLab v6

Durante el diagnóstico se utilizó como comparación un segundo equipo AMD con Windows 11 Pro donde la virtualización anidada ya funcionaba correctamente.

En el equipo afectado, el último elemento que mantenía cargado el hipervisor fue un escenario `WindowsHello` de Device Guard, incluso después de que VBS ya había llegado a `0`.

Ese hallazgo del Registro **no se presenta como una causa ni solución universal**.

---

# Guía manual de diagnóstico

Normalmente el troubleshooter v2 te indicará qué sección corresponde revisar. La guía manual se mantiene para que el procedimiento sea transparente y para equipos donde alguna comprobación automática quede incompleta.

## Paso 1 — Verificar AMD-V / SVM en firmware

Abre **PowerShell como administrador**:

```powershell
Get-CimInstance Win32_Processor |
Select-Object Name,VirtualizationFirmwareEnabled,SecondLevelAddressTranslationExtensions
```

Esperado:

```text
VirtualizationFirmwareEnabled           True
SecondLevelAddressTranslationExtensions True
```

Si la virtualización de firmware aparece en `False`, entra al BIOS/UEFI y habilita la opción equivalente a:

```text
SVM Mode
AMD-V
CPU Virtualization
```

**Mantén SVM / AMD-V habilitado durante todo este procedimiento.**

---

## Paso 2 — Comprobar si Windows reporta un hipervisor

```powershell
Get-CimInstance Win32_ComputerSystem |
Select-Object HypervisorPresent
```

También:

```cmd
systeminfo
```

Si `systeminfo` muestra:

```text
Se detectó un hipervisor.
```

Windows todavía lo está cargando o reportando.

Si `HypervisorPresent` ya es `False`, pasa directamente al **paso 11**.

---

## Paso 3 — Desactivar Integridad de memoria cuando sea parte del bloqueo

Ruta:

```text
Configuración
→ Privacidad y seguridad
→ Seguridad de Windows
→ Seguridad del dispositivo
→ Aislamiento del núcleo
```

Desactiva:

```text
Integridad de memoria
```

Reinicia cuando corresponda y vuelve a ejecutar el diagnóstico.

---

## Paso 4 — Desactivar VBS mediante directiva de grupo

En Windows 11 Pro, pulsa `Win + R` y ejecuta:

```text
gpedit.msc
```

Ruta:

```text
Configuración del equipo
→ Plantillas administrativas
→ Sistema
→ Device Guard
```

Abre:

```text
Activar la seguridad basada en la virtualización
```

Selecciona:

```text
Deshabilitada
```

Aplica los cambios, reinicia si corresponde y vuelve a ejecutar el diagnóstico.

---

## Paso 5 — Desactivar características de virtualización de Windows que estén interfiriendo

Pulsa `Win + R` y ejecuta:

```text
optionalfeatures
```

Para esta ruta de virtualización anidada en VMware, desactiva estas características si están habilitadas:

```text
Hyper-V
Plataforma de máquina virtual
Plataforma del hipervisor de Windows
Espacio aislado de Windows / Windows Sandbox
Subsistema de Windows para Linux
```

Puedes verificar el estado real con PowerShell:

```powershell
Get-WindowsOptionalFeature -Online |
Where-Object {$_.FeatureName -match "Hyper-V|VirtualMachinePlatform|HypervisorPlatform|Containers-DisposableClientVM|Subsystem-Linux"} |
Select-Object FeatureName,State
```

Reinicia y vuelve a ejecutar el diagnóstico.

---

## Paso 6 — Impedir el arranque del hipervisor desde BCD

Abre **CMD como administrador**:

```cmd
bcdedit /set {current} hypervisorlaunchtype off
bcdedit /set {current} vsmlaunchtype off
```

Comprueba:

```cmd
bcdedit /enum {current}
```

Cuando estos valores están definidos explícitamente, el objetivo es:

```text
hypervisorlaunchtype    Off
vsmlaunchtype           Off
```

Reinicia y comprueba nuevamente:

```powershell
Get-CimInstance Win32_ComputerSystem |
Select-Object HypervisorPresent
```

Si ya es `False`, pasa al **paso 11**.

---

## Paso 7 — Comprobar VBS directamente

```powershell
Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard |
Format-List VirtualizationBasedSecurityStatus,CodeIntegrityPolicyEnforcementStatus,SecurityServicesConfigured,SecurityServicesRunning
```

Un estado con VBS desactivado normalmente incluye:

```text
VirtualizationBasedSecurityStatus : 0
```

Si sigue apareciendo:

```text
VirtualizationBasedSecurityStatus : 2
```

VBS continúa en ejecución.

---

## Paso 8 — Si VBS se niega a apagarse, investigar Secure Boot con cuidado

> **No cambies Secure Boot sin revisar BitLocker primero.**

Comprueba BitLocker:

```cmd
manage-bde -status C:
```

Si la protección está activa, asegúrate de tener acceso a tu **clave de recuperación de BitLocker** antes de continuar. Nunca publiques esa clave.

Para suspender temporalmente los protectores durante dos reinicios:

```cmd
manage-bde -protectors -disable C: -RebootCount 2
```

Comprueba:

```cmd
manage-bde -status C:
```

El disco seguirá cifrado mientras los protectores están suspendidos temporalmente.

En BIOS/UEFI mantén:

```text
SVM / AMD-V = Enabled
```

Solo como prueba de diagnóstico, Secure Boot puede desactivarse en sistemas donde VBS se niega a apagarse.

Después comprueba:

```powershell
Confirm-SecureBootUEFI
```

Y vuelve a revisar VBS y `HypervisorPresent`.

> Secure Boot **no es universalmente incompatible con VMware**. No lo desactives si el estado del diagnóstico no apunta realmente a esta rama.

---

## Paso 9 — Windows 11 24H2 / 25H2: escenario `WindowsHello` de Device Guard

Este fue el último elemento encontrado en el equipo donde se validó la solución.

Consulta:

```cmd
reg query "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello"
```

Si la clave no existe, **no la crees únicamente porque aparece en esta guía**.

Si existe y muestra:

```text
Enabled    REG_DWORD    0x1
```

y los bloqueos anteriores ya están resueltos mientras `HypervisorPresent` sigue en `True`, este escenario puede investigarse.

Antes de modificarlo, ve a:

```text
Configuración
→ Cuentas
→ Opciones de inicio de sesión
→ Configuración adicional
```

Desactiva la opción similar a:

```text
Para mejorar la seguridad, solo permitir el inicio
de sesión de Windows Hello para las cuentas de Microsoft
en este dispositivo
```

No elimines tu PIN y asegúrate de conocer la contraseña de tu cuenta Windows/Microsoft.

Después, desde **CMD como administrador**:

```cmd
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello" /v Enabled /t REG_DWORD /d 0 /f
```

Comprueba:

```cmd
reg query "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello"
```

Para esta rama concreta buscamos:

```text
Enabled    REG_DWORD    0x0
```

Reinicia y vuelve a ejecutar el troubleshooter.

En el equipo probado, este fue el cambio que finalmente produjo:

```text
HypervisorPresent = False
```

De nuevo: fue la causa **en este caso**, no una solución universal para Windows 11.

---

## Paso 10 — Comprobación final del host

```powershell
Get-CimInstance Win32_ComputerSystem |
Select-Object HypervisorPresent
```

Objetivo:

```text
False
```

Después:

```cmd
systeminfo
```

En lugar del mensaje de hipervisor detectado deberían volver a aparecer las comprobaciones normales de capacidades, por ejemplo:

```text
Extensiones de modo de monitor de VM: Sí
Se habilitó la virtualización en el firmware: Sí
Traducción de direcciones de segundo nivel: Sí
La prevención de ejecución de datos está disponible: Sí
```

Comprobación opcional del servicio:

```powershell
sc.exe query hvhost
```

---

## Paso 11 — Activar virtualización anidada en VMware

Apaga completamente la VM.

Ruta:

```text
VM
→ Settings
→ Processors
```

Activa:

```text
Virtualize Intel VT-x/EPT or AMD-V/RVI
```

Inicia la VM.

Si el estado del host ya es correcto, el error AMD-V/RVI no debería volver a aparecer.

---

## Paso 12 — Reactivar BitLocker si lo suspendiste

```cmd
manage-bde -status C:
```

Si la protección sigue suspendida:

```cmd
manage-bde -protectors -enable C:
```

Comprueba de nuevo:

```cmd
manage-bde -status C:
```

---

## Por qué `HypervisorPresent` importa

Durante el diagnóstico original llegamos a tener este estado:

```text
Hyper-V                   Off
VBS                       0
Integridad de memoria     Off
hypervisorlaunchtype      Off

PERO

HypervisorPresent         True
```

VMware seguía fallando con AMD-V/RVI anidado.

Solo cuando Windows pasó a:

```text
HypervisorPresent = False
```

PNETLab pudo arrancar correctamente con AMD-V/RVI habilitado.

---

## Advertencia de seguridad

Esta guía puede llevar a desactivar protecciones importantes de Windows, entre ellas:

- Virtualization-Based Security (VBS)
- Integridad de memoria / HVCI
- Secure Boot en casos concretos de diagnóstico
- un escenario Windows Hello / Device Guard en un caso específico

No ejecutes todos los pasos a ciegas, especialmente en equipos corporativos, administrados, de producción o sensibles.

Precisamente por eso existe el troubleshooter v2: **diagnosticar → aplicar un solo paso relevante → reiniciar → diagnosticar otra vez**.

---

## Referencias

- [Microsoft Learn — Win32_ComputerSystem / HypervisorPresent](https://learn.microsoft.com/windows/win32/cimwin32prov/win32-computersystem)
- [Microsoft Learn — BCDEdit /set](https://learn.microsoft.com/windows-hardware/drivers/devtest/bcdedit--set)
- [Microsoft Learn — manage-bde protectors](https://learn.microsoft.com/windows-server/administration/windows-commands/manage-bde-protectors)
- [Microsoft Learn — Windows Hello Enhanced Sign-in Security](https://learn.microsoft.com/windows-hardware/design/device-experiences/windows-hello-enhanced-sign-in-security)
- [Broadcom VMware Community — Virtualized AMD-V/RVI is not supported on this platform](https://community.broadcom.com/vmware-cloud-foundation/discussion/virtualized-amd-vrvi-is-not-supported-on-this-platform)

---

## Contribuciones / pedir ayuda

Ejecuta el troubleshooter v2 y pega su reporte sanitizado usando la plantilla **AMD-V/RVI diagnostic** de Issues del repositorio.

Consulta [SUPPORT.md](./SUPPORT.md) para seguir el flujo recomendado.

**Nunca publiques claves de recuperación de BitLocker, contraseñas, claves de producto, números de serie, correos electrónicos ni otros datos sensibles.**
