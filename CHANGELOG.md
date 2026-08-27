# Changelog / Historial de cambios

## v2.0

### Español

- `diagnose-hypervisor.ps1` pasa de recolector de datos a **troubleshooter basado en reglas**.
- Selector de idioma Español / English al iniciar.
- Parámetros `-Language es`, `-Language en`, `-ExportReport` y `-NoPrompt`.
- Recomendación adaptativa de **un siguiente paso** en vez de aplicar toda la guía.
- Detección de AMD-V/SVM, SLAT/RVI, `HypervisorPresent`, VBS, HVCI, características opcionales, BCD, `WindowsHello`, Secure Boot, BitLocker, `hvhost`, eventos Hyper-V y VMware Workstation.
- Reporte sanitizado para copiar/pegar en soporte.
- Exportación opcional a TXT y JSON.
- El reporte omite intencionalmente hostname, usuario, claves de BitLocker, claves de producto y números de serie.
- Nueva guía bilingüe `SUPPORT.md`.
- Nueva plantilla bilingüe de GitHub Issue para reportes diagnósticos.
- `.gitignore` evita agregar por accidente los reportes locales generados.

### English

- `diagnose-hypervisor.ps1` upgraded from a state collector to a **rule-based troubleshooter**.
- Spanish / English language selection at startup.
- Added `-Language es`, `-Language en`, `-ExportReport`, and `-NoPrompt`.
- Adaptive **single next-step** recommendation instead of applying the whole guide.
- Detects AMD-V/SVM, SLAT/RVI, `HypervisorPresent`, VBS, HVCI, optional features, BCD, `WindowsHello`, Secure Boot, BitLocker, `hvhost`, Hyper-V events, and VMware Workstation.
- Sanitized copy/paste support report.
- Optional TXT and JSON export.
- Report intentionally omits hostname, username, BitLocker recovery keys, product keys, and serial numbers.
- Added bilingual `SUPPORT.md`.
- Added a bilingual GitHub Issue template for diagnostic reports.
- Added `.gitignore` entries for locally generated reports.

## v1.1

- Expanded the original read-only system checks.
- Added clearer `HypervisorPresent` summary and safety messaging.

## v1.0

- Initial Windows 11 + AMD VMware nested-virtualization troubleshooting guide and diagnostic script.
