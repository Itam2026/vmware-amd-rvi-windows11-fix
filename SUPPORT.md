# Support / Soporte

[**Español**](#español) | [**English**](#english)

---

## Español

### La forma recomendada de pedir ayuda

Antes de cambiar configuraciones de Windows, ejecuta [`diagnose-hypervisor.ps1`](./diagnose-hypervisor.ps1) desde **PowerShell como administrador**.

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\diagnose-hypervisor.ps1
```

El script v2 permite elegir idioma al iniciar:

```text
[1] Espanol
[2] English
```

También puedes indicarlo directamente:

```powershell
.\diagnose-hypervisor.ps1 -Language es
```

El diagnóstico es **solo de lectura**. No cambia Windows, Registro, BCD, BitLocker, Secure Boot, BIOS/UEFI, características opcionales ni VMware.

### Qué hace

El script analiza el estado del host y aplica un pequeño motor de reglas. En vez de recomendar todos los cambios posibles, intenta indicar **solo el siguiente paso relevante**.

Entre otras cosas comprueba:

- AMD-V / SVM en firmware
- SLAT / RVI
- `HypervisorPresent`
- VBS / Device Guard
- Memory Integrity / HVCI
- Hyper-V, Virtual Machine Platform, Windows Hypervisor Platform, Sandbox y WSL
- `hypervisorlaunchtype` y `vsmlaunchtype`
- escenario `WindowsHello` de Device Guard
- Secure Boot
- estado de protección de BitLocker en C:
- servicio `hvhost`
- presencia de eventos ID 2 del hipervisor de Hyper-V
- versión de VMware Workstation, cuando puede detectarla

### Reporte para compartir

Al terminar, el script muestra un bloque llamado:

```text
--- BEGIN VMWARE AMD-V/RVI DIAGNOSTIC REPORT ---
...
--- END VMWARE AMD-V/RVI DIAGNOSTIC REPORT ---
```

Ese bloque está pensado para copiar y pegar en:

- un Issue de este repositorio
- ChatGPT
- Broadcom VMware Community
- otro foro o sistema de soporte

Ejemplo de mensaje para acompañarlo:

> Analiza este reporte de VMware AMD-V/RVI. Indícame primero qué está correcto, qué sigue manteniendo el hipervisor activo y cuál es el siguiente paso más seguro. No me des pasos posteriores hasta que vuelva a ejecutar el diagnóstico.

El reporte **no incluye intencionalmente** hostname, usuario, clave de recuperación de BitLocker, claves de producto ni números de serie.

Aun así, revisa siempre cualquier información antes de publicarla.

### Guardar TXT y JSON

Al finalizar, el script puede preguntarte si quieres guardar el reporte. También puedes forzarlo con:

```powershell
.\diagnose-hypervisor.ps1 -Language es -ExportReport
```

Esto crea en la carpeta actual:

```text
vmware-amd-rvi-report.txt
vmware-amd-rvi-report.json
```

El TXT es cómodo para soporte humano. El JSON está pensado para futuras herramientas, interfaces o análisis automatizados.

### Regla de seguridad

El troubleshooter **no realiza la corrección automáticamente**. Solo diagnostica y recomienda el siguiente paso. Algunas soluciones pueden desactivar protecciones importantes de Windows, por lo que el usuario debe revisar y aplicar cada cambio conscientemente.

---

## English

### Recommended way to request help

Before changing Windows settings, run [`diagnose-hypervisor.ps1`](./diagnose-hypervisor.ps1) from **PowerShell as Administrator**.

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\diagnose-hypervisor.ps1
```

Version 2 lets you select the language when it starts:

```text
[1] Espanol
[2] English
```

Or select it directly:

```powershell
.\diagnose-hypervisor.ps1 -Language en
```

The diagnostic is **read-only**. It does not change Windows, the registry, BCD, BitLocker, Secure Boot, BIOS/UEFI, optional features, or VMware.

### What it does

The script analyzes the host and applies a small rule engine. Instead of recommending every possible change, it tries to identify **only the next relevant step**.

It checks, among other items:

- AMD-V / SVM firmware virtualization
- SLAT / RVI
- `HypervisorPresent`
- VBS / Device Guard
- Memory Integrity / HVCI
- Hyper-V, Virtual Machine Platform, Windows Hypervisor Platform, Sandbox, and WSL
- `hypervisorlaunchtype` and `vsmlaunchtype`
- the Device Guard `WindowsHello` scenario
- Secure Boot
- BitLocker protection state on C:
- the `hvhost` service
- Hyper-V hypervisor Event ID 2 presence
- VMware Workstation version when it can be detected

### Shareable report

At the end, the script displays a block like:

```text
--- BEGIN VMWARE AMD-V/RVI DIAGNOSTIC REPORT ---
...
--- END VMWARE AMD-V/RVI DIAGNOSTIC REPORT ---
```

It is designed to be pasted into:

- an Issue in this repository
- ChatGPT
- Broadcom VMware Community
- another support forum or system

Suggested prompt:

> Analyze this VMware AMD-V/RVI diagnostic report. Tell me what is already correct, what is still keeping the hypervisor active, and the safest next step. Do not give later steps until I run the diagnostic again.

The report intentionally excludes hostname, username, BitLocker recovery keys, Windows product keys, and serial numbers.

Always review information before publishing it.

### Save TXT and JSON

The script can ask whether to save the report, or you can force export with:

```powershell
.\diagnose-hypervisor.ps1 -Language en -ExportReport
```

It creates in the current directory:

```text
vmware-amd-rvi-report.txt
vmware-amd-rvi-report.json
```

TXT is convenient for human support. JSON is intended for future tooling, user interfaces, or automated analysis.

### Safety rule

The troubleshooter **does not automatically apply fixes**. It diagnoses and recommends the next step only. Some possible fixes disable meaningful Windows security protections, so the user should review and apply each change deliberately.
