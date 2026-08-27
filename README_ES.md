# VMware Workstation: solución a `Virtualized AMD-V/RVI is not supported on this platform` en Windows 11 + AMD

[**English**](./README.md) | [**Español**](./README_ES.md)

Guía paso a paso para recuperar la **virtualización anidada AMD-V/RVI** en VMware Workstation.

Útil para:

- PNETLab
- EVE-NG
- GNS3 VM
- ESXi anidado
- Otras VMs que necesiten AMD-V/RVI dentro de VMware

## 🩺 Empieza por aquí: script de diagnóstico de solo lectura

Antes de cambiar configuraciones de Windows, ejecuta el archivo incluido [`diagnose-hypervisor.ps1`](./diagnose-hypervisor.ps1).

Comprueba automáticamente:

- disponibilidad de AMD-V / SVM
- `HypervisorPresent`
- estado de VBS / Device Guard
- características opcionales relacionadas con Hyper-V
- configuración BCD del hipervisor
- escenario `WindowsHello` de Device Guard
- Secure Boot
- estado de BitLocker
- servicio `hvhost`
- eventos recientes ID 2 del hipervisor de Hyper-V

El script es **solo de lectura**. **No modifica** Windows, Registro, BCD, BitLocker, BIOS/UEFI ni VMware.

Ejecútalo desde **PowerShell como administrador**:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\diagnose-hypervisor.ps1
```

El cambio de directiva anterior solo dura mientras esa ventana de PowerShell esté abierta.

Si el script muestra:

```text
HypervisorPresent = FALSE
```

Windows ya no está reportando un hipervisor de host y normalmente puedes ir directamente al paso de VMware.

---

## Error típico

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

## La comprobación más importante

No basta con mirar si Hyper-V está desmarcado o si VBS dice `0`.

Ejecuta en PowerShell como administrador:

```powershell
Get-CimInstance Win32_ComputerSystem |
Select-Object HypervisorPresent
```

Para VMware con AMD-V/RVI anidado queremos:

```text
HypervisorPresent
-----------------
False
```

Si sigue en `True`, Windows todavía está cargando un hipervisor.

> **Detente en cuanto `HypervisorPresent` cambie a `False`.**
> No todos los equipos necesitan todos los pasos.

---

## Entorno validado

El procedimiento se validó con:

- ASUS TUF Gaming A16 FA607NUG
- AMD Ryzen 7 7445HS
- Windows 11 Pro 25H2, compilación 26200.9168
- VMware Workstation 26.0.0.25388281
- PNETLab v6

Durante el diagnóstico se utilizó como comparación un segundo equipo AMD con Windows 11 Pro donde la virtualización anidada ya funcionaba correctamente.

El último elemento que mantenía cargado el hipervisor en el equipo afectado fue el escenario `WindowsHello` de Device Guard, incluso después de que VBS ya había llegado a `0`.

Ese paso final **no se presenta como una causa universal**.

---

# 1. Verificar AMD-V / SVM

```powershell
Get-CimInstance Win32_Processor |
Select-Object Name,VirtualizationFirmwareEnabled,SecondLevelAddressTranslationExtensions
```

Queremos:

```text
VirtualizationFirmwareEnabled           True
SecondLevelAddressTranslationExtensions True
```

Si aparece `False`, entra al BIOS/UEFI y habilita:

```text
SVM Mode
AMD-V
CPU Virtualization
```

**No desactives SVM/AMD-V durante este procedimiento.**

---

# 2. Comprobar si Windows está ejecutando un hipervisor

```powershell
Get-CimInstance Win32_ComputerSystem |
Select-Object HypervisorPresent
```

También:

```cmd
systeminfo
```

Si al final aparece:

```text
Se detectó un hipervisor.
```

Windows todavía lo está cargando.

Si `HypervisorPresent` ya es `False`, pasa directamente al **paso 10**.

---

# 3. Desactivar Integridad de memoria

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

---

# 4. Desactivar VBS por directiva de grupo

En Windows 11 Pro:

```text
Win + R
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

---

# 5. Desactivar características de virtualización de Windows

Ejecuta:

```text
optionalfeatures
```

Desmarca si aparecen:

```text
Hyper-V
Plataforma de máquina virtual
Plataforma del hipervisor de Windows
Espacio aislado de Windows / Windows Sandbox
Subsistema de Windows para Linux
```

Comprueba el estado real con:

```powershell
Get-WindowsOptionalFeature -Online |
Where-Object {$_.FeatureName -match "Hyper-V|VirtualMachinePlatform|HypervisorPlatform|Containers-DisposableClientVM|Subsystem-Linux"} |
Select-Object FeatureName,State
```

Las relevantes deberían decir:

```text
Disabled
```

---

# 6. Impedir el arranque del hipervisor

CMD como administrador:

```cmd
bcdedit /set {current} hypervisorlaunchtype off
bcdedit /set {current} vsmlaunchtype off
```

Comprueba:

```cmd
bcdedit /enum {current}
```

Queremos:

```text
hypervisorlaunchtype    Off
vsmlaunchtype           Off
```

Reinicia y vuelve a comprobar:

```powershell
Get-CimInstance Win32_ComputerSystem |
Select-Object HypervisorPresent
```

Si ya es `False`, pasa al **paso 10**.

---

# 7. Comprobar VBS

```powershell
Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard |
Format-List VirtualizationBasedSecurityStatus,CodeIntegrityPolicyEnforcementStatus,SecurityServicesConfigured,SecurityServicesRunning
```

VBS desactivado debería mostrar:

```text
VirtualizationBasedSecurityStatus : 0
```

Si aparece:

```text
VirtualizationBasedSecurityStatus : 2
```

VBS todavía se está ejecutando.

---

# 8. Si VBS sigue activo: revisar Secure Boot

> **Antes de tocar Secure Boot, revisa BitLocker.**

```cmd
manage-bde -status C:
```

Si BitLocker está activo, asegúrate primero de tener acceso a tu **clave de recuperación**.

Puedes suspender temporalmente sus protectores por dos reinicios:

```cmd
manage-bde -protectors -disable C: -RebootCount 2
```

Comprueba:

```cmd
manage-bde -status C:
```

El disco seguirá cifrado, pero los protectores estarán suspendidos temporalmente.

En BIOS/UEFI mantén:

```text
SVM / AMD-V = Enabled
```

Como prueba de diagnóstico, desactiva:

```text
Secure Boot
```

Guarda y reinicia.

Comprueba:

```powershell
Confirm-SecureBootUEFI
```

Para esta prueba debería devolver:

```text
False
```

Vuelve a comprobar VBS y:

```powershell
Get-CimInstance Win32_ComputerSystem |
Select-Object HypervisorPresent
```

Si ya es `False`, pasa al **paso 10**.

> Secure Boot no es universalmente incompatible con VMware.
> Este paso solo tiene sentido si VBS se niega a apagarse.

---

# 9. Windows 11 24H2 / 25H2: escenario `WindowsHello` de Device Guard

Este fue el último elemento que mantenía el hipervisor cargado en el equipo donde se probó esta guía.

Consulta:

```cmd
reg query "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello"
```

Si la clave no existe, **no la crees únicamente porque aparece en esta guía**.

Si existe y muestra:

```text
Enabled    REG_DWORD    0x1
```

y ya completaste los pasos anteriores pero `HypervisorPresent` sigue en `True`, puedes probar a deshabilitar el escenario.

Antes:

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

No elimines tu PIN.

Asegúrate de conocer la contraseña de tu cuenta Windows/Microsoft.

Después, CMD como administrador:

```cmd
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello" /v Enabled /t REG_DWORD /d 0 /f
```

Comprueba:

```cmd
reg query "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello"
```

Queremos:

```text
Enabled    REG_DWORD    0x0
```

Reinicia.

Después:

```powershell
Get-CimInstance Win32_ComputerSystem |
Select-Object HypervisorPresent
```

En el caso probado, este cambio finalmente produjo:

```text
HypervisorPresent
-----------------
False
```

---

# 10. Comprobación final

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

En vez de:

```text
Se detectó un hipervisor.
```

deberías ver:

```text
Extensiones de modo de monitor de VM: Sí
Se habilitó la virtualización en el firmware: Sí
Traducción de direcciones de segundo nivel: Sí
La prevención de ejecución de datos está disponible: Sí
```

Opcional:

```powershell
sc.exe query hvhost
```

Y VBS:

```powershell
Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard |
Format-List VirtualizationBasedSecurityStatus,SecurityServicesConfigured,SecurityServicesRunning
```

Esperado:

```text
VirtualizationBasedSecurityStatus : 0
SecurityServicesConfigured        : {0}
SecurityServicesRunning           : {0}
```

---

# 11. Activar AMD-V/RVI anidado en VMware

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

La misma casilla de VMware sirve para AMD-V/RVI.

Inicia la VM.

---

# 12. Reactivar BitLocker

Si lo suspendiste:

```cmd
manage-bde -status C:
```

Si sigue suspendido:

```cmd
manage-bde -protectors -enable C:
```

Comprueba nuevamente:

```cmd
manage-bde -status C:
```

---

# Diagnóstico rápido

El dato decisivo es:

```powershell
Get-CimInstance Win32_ComputerSystem |
Select-Object HypervisorPresent
```

En el caso probado llegamos a tener:

```text
Hyper-V                   Off
VBS                       0
Integridad de memoria     Off
hypervisorlaunchtype      Off

PERO

HypervisorPresent         True
```

VMware seguía fallando.

Solo cuando Windows pasó a:

```text
HypervisorPresent = False
```

PNETLab pudo arrancar correctamente con AMD-V/RVI anidado.

---

# Advertencia de seguridad

Este procedimiento puede desactivar protecciones como:

- VBS
- Integridad de memoria / HVCI
- Secure Boot en algunos casos
- Un escenario Windows Hello / Device Guard en un caso específico

No lo apliques indiscriminadamente en equipos corporativos, administrados o sensibles.

Haz los cambios de forma incremental y **detente en cuanto `HypervisorPresent` sea `False`**.

---

# Referencias

- [Microsoft Learn — Win32_ComputerSystem / HypervisorPresent](https://learn.microsoft.com/windows/win32/cimwin32prov/win32-computersystem)
- [Microsoft Learn — BCDEdit /set](https://learn.microsoft.com/windows-hardware/drivers/devtest/bcdedit--set)
- [Microsoft Learn — manage-bde protectors](https://learn.microsoft.com/windows-server/administration/windows-commands/manage-bde-protectors)
- [Microsoft Learn — Windows Hello Enhanced Sign-in Security](https://learn.microsoft.com/windows-hardware/design/device-experiences/windows-hello-enhanced-sign-in-security)
- [Broadcom VMware Community — Virtualized AMD-V/RVI is not supported on this platform](https://community.broadcom.com/vmware-cloud-foundation/discussion/virtualized-amd-vrvi-is-not-supported-on-this-platform)

---

## Contribuciones

Si funciona en otro AMD, versión de Windows o versión de VMware, abre un Issue/Discussion indicando los datos siguientes. Si puedes, adjunta también la salida de `diagnose-hypervisor.ps1` **después de revisar que no contiene información que no quieras publicar**:

```text
CPU:
Versión/build de Windows:
Versión de VMware Workstation:
HypervisorPresent antes:
HypervisorPresent después:
Paso que lo resolvió:
```

No publiques claves de BitLocker, claves de producto, números de serie, correos u otros datos sensibles.
