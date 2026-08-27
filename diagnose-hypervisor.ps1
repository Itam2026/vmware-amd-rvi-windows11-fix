<#
.SYNOPSIS
Bilingual read-only troubleshooter for VMware nested AMD-V/RVI issues on Windows 11.

.DESCRIPTION
Analyzes the Windows host when VMware reports:
"Virtualized AMD-V/RVI is not supported on this platform."

The script collects a privacy-conscious system state, applies a rule-based
diagnosis, and recommends only the next relevant step in the repository guide.

READ-ONLY / SOLO LECTURA:
The diagnostic does NOT change Windows, the registry, BCD, BitLocker,
Secure Boot, BIOS/UEFI, VMware, or Windows optional features.

The only optional write is exporting sanitized .txt and .json report files.

Examples:
  .\diagnose-hypervisor.ps1
  .\diagnose-hypervisor.ps1 -Language es
  .\diagnose-hypervisor.ps1 -Language en
  .\diagnose-hypervisor.ps1 -Language es -ExportReport
#>

[CmdletBinding()]
param(
    [ValidateSet("auto", "es", "en")]
    [string]$Language = "auto",

    [switch]$ExportReport,

    [switch]$NoPrompt
)

$ErrorActionPreference = "Continue"
$ScriptVersion = "2.2"

function Select-Language {
    param(
        [string]$RequestedLanguage,
        [switch]$SkipPrompt
    )

    if ($RequestedLanguage -in @("es", "en")) {
        return $RequestedLanguage
    }

    $culture = [System.Globalization.CultureInfo]::CurrentUICulture.Name
    $defaultLanguage = if ($culture -like "es*") { "es" } else { "en" }

    if ($SkipPrompt) {
        return $defaultLanguage
    }

    Write-Host ""
    Write-Host "VMware AMD-V/RVI Troubleshooter / Diagnostico VMware AMD-V/RVI" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Selecciona idioma / Select language:"
    Write-Host "  [1] Espanol"
    Write-Host "  [2] English"

    $defaultChoice = if ($defaultLanguage -eq "es") { "1" } else { "2" }
    $choice = Read-Host "Opcion / Option [$defaultChoice]"

    if ([string]::IsNullOrWhiteSpace($choice)) {
        $choice = $defaultChoice
    }

    if ($choice -eq "2") {
        return "en"
    }

    return "es"
}

$Lang = Select-Language -RequestedLanguage $Language -SkipPrompt:$NoPrompt

$Text = @{
    es = @{
        Title = "Diagnostico VMware AMD-V/RVI v$ScriptVersion"
        ReadOnly = "SOLO LECTURA: el diagnostico no cambiara configuraciones del sistema."
        AdminWarning = "PowerShell no esta ejecutandose como administrador. Algunas comprobaciones pueden quedar incompletas."
        Collecting = "Analizando el equipo..."
        Summary = "RESUMEN"
        Diagnosis = "DIAGNOSTICO"
        NextStep = "SIGUIENTE PASO RECOMENDADO"
        Shareable = "REPORTE SANITIZADO PARA COMPARTIR"
        ShareHelp = "Puedes copiar el bloque de abajo y pegarlo en ChatGPT, GitHub Issues o un foro de soporte. No incluye hostname, usuario, claves de BitLocker, seriales ni claves de producto."
        SaveQuestion = "Guardar tambien el reporte como archivos TXT y JSON? [s/N]"
        Saved = "Reportes guardados en"
        ReadyTitle = "ESTADO OBJETIVO ALCANZADO"
        ReadyBody = "Windows ya no reporta un hipervisor de host. Prueba la VM con 'Virtualize Intel VT-x/EPT or AMD-V/RVI' activado en VMware."
        AdminBody = "Vuelve a ejecutar PowerShell como administrador antes de continuar. Algunas comprobaciones necesarias pueden estar incompletas."
        BiosBody = "AMD-V/SVM parece desactivado en firmware. Habilitalo en BIOS/UEFI antes de continuar."
        HvciBody = "Memory Integrity / HVCI esta habilitado. Revisa el paso 3 de README_ES.md, reinicia y vuelve a ejecutar este diagnostico."
        VbsPolicyBody = "VBS sigue activo o no esta deshabilitado por politica. Revisa el paso 4 de README_ES.md, reinicia y vuelve a ejecutar este diagnostico."
        FeatureBody = "Hay caracteristicas de virtualizacion de Windows activas. Revisa el paso 5 de README_ES.md, reinicia y vuelve a ejecutar este diagnostico."
        BcdBody = "Windows aun puede iniciar el hipervisor desde BCD. Revisa el paso 6 de README_ES.md, reinicia y vuelve a ejecutar este diagnostico."
        SecureBootBody = "VBS sigue activo pese a las comprobaciones anteriores y Secure Boot esta habilitado. Revisa primero BitLocker y luego el paso 8 de README_ES.md."
        HelloBody = "Windows sigue cargando un hipervisor y el escenario WindowsHello de Device Guard esta habilitado. Revisa solamente el paso 9 de README_ES.md, reinicia y vuelve a ejecutar este diagnostico."
        ManualBody = "Windows sigue reportando un hipervisor, pero este conjunto de reglas no encontro una causa unica segura. Comparte el reporte sanitizado para continuar el diagnostico sin aplicar cambios a ciegas."
        None = "Ninguna"
        NotConfigured = "No configurado"
        NotPresent = "No existe"
        QueryFailed = "No se pudo consultar"
        NotSet = "No establecido (valor predeterminado)"
        Enabled = "Habilitado"
        Disabled = "Deshabilitado"
        Unknown = "No determinado"
        HistoricalEvent = "Evento historico; no significa que el hipervisor este activo ahora"
    }
    en = @{
        Title = "VMware AMD-V/RVI Diagnostic v$ScriptVersion"
        ReadOnly = "READ-ONLY: this diagnostic will not change system settings."
        AdminWarning = "PowerShell is not running as Administrator. Some checks may be incomplete."
        Collecting = "Analyzing this computer..."
        Summary = "SUMMARY"
        Diagnosis = "DIAGNOSIS"
        NextStep = "RECOMMENDED NEXT STEP"
        Shareable = "SANITIZED REPORT FOR SUPPORT"
        ShareHelp = "Copy the block below into ChatGPT, GitHub Issues, or a support forum. It intentionally excludes hostname, username, BitLocker recovery keys, serial numbers, and product keys."
        SaveQuestion = "Also save the report as TXT and JSON files? [y/N]"
        Saved = "Reports saved in"
        ReadyTitle = "TARGET STATE REACHED"
        ReadyBody = "Windows no longer reports a host hypervisor. Test the VM with 'Virtualize Intel VT-x/EPT or AMD-V/RVI' enabled in VMware."
        AdminBody = "Run PowerShell as Administrator before continuing. Some required checks may be incomplete."
        BiosBody = "AMD-V/SVM appears disabled in firmware. Enable it in BIOS/UEFI before continuing."
        HvciBody = "Memory Integrity / HVCI is enabled. Review step 3 in README.md, reboot, and run this diagnostic again."
        VbsPolicyBody = "VBS is still active or has not been disabled by policy. Review step 4 in README.md, reboot, and run this diagnostic again."
        FeatureBody = "One or more Windows virtualization features are enabled. Review step 5 in README.md, reboot, and run this diagnostic again."
        BcdBody = "Windows may still launch the hypervisor from BCD. Review step 6 in README.md, reboot, and run this diagnostic again."
        SecureBootBody = "VBS is still active after the previous checks and Secure Boot is enabled. Check BitLocker first, then review step 8 in README.md."
        HelloBody = "Windows still reports a host hypervisor and the Device Guard WindowsHello scenario is enabled. Review only step 9 in README.md, reboot, and run this diagnostic again."
        ManualBody = "Windows still reports a host hypervisor, but this rule set did not find a single safe cause. Share the sanitized report before applying additional changes."
        None = "None"
        NotConfigured = "Not configured"
        NotPresent = "Not present"
        QueryFailed = "Query failed"
        NotSet = "Not set (default)"
        Enabled = "Enabled"
        Disabled = "Disabled"
        Unknown = "Unknown"
        HistoricalEvent = "Historical event; it does not mean the hypervisor is active now"
    }
}

$T = $Text[$Lang]

function Section {
    param([string]$Title)

    Write-Host ""
    Write-Host ("=" * 78) -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host ("=" * 78) -ForegroundColor Cyan
}

function Test-IsAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Get-RegDwordState {
    param(
        [string]$Path,
        [string]$Name
    )

    if (-not (Test-Path $Path)) {
        return [pscustomobject]@{
            Exists = $false
            HasValue = $false
            Value = $null
            State = "NotPresent"
        }
    }

    try {
        $value = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name

        if ([int]$value -eq 1) {
            $state = "Enabled"
        }
        elseif ([int]$value -eq 0) {
            $state = "Disabled"
        }
        else {
            $state = "Value:$value"
        }

        return [pscustomobject]@{
            Exists = $true
            HasValue = $true
            Value = $value
            State = $state
        }
    }
    catch {
        return [pscustomobject]@{
            Exists = $true
            HasValue = $false
            Value = $null
            State = "NotConfigured"
        }
    }
}

function Convert-StateToDisplay {
    param([string]$State)

    switch ($State) {
        "Enabled" { return $T.Enabled }
        "Disabled" { return $T.Disabled }
        "NotConfigured" { return $T.NotConfigured }
        "NotPresent" { return $T.NotPresent }
        "NotSet" { return $T.NotSet }
        "QueryFailed" { return $T.QueryFailed }
        default {
            if ([string]::IsNullOrWhiteSpace($State)) {
                return $T.Unknown
            }
            return $State
        }
    }
}

function Get-WindowsFeatureState {
    param([string]$FeatureName)

    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction Stop
        return [string]$feature.State
    }
    catch {
        return "QueryFailed"
    }
}

function Get-BcdElementState {
    param(
        [string[]]$Lines,
        [string]$ElementName,
        [bool]$QuerySucceeded
    )

    if (-not $QuerySucceeded) {
        return "QueryFailed"
    }

    $escapedName = [regex]::Escape($ElementName)
    $line = $Lines | Where-Object { $_ -match "^\s*$escapedName\s+(.+?)\s*$" } | Select-Object -First 1

    if (-not $line) {
        return "NotSet"
    }

    if ($line -match "^\s*$escapedName\s+(.+?)\s*$") {
        return $Matches[1].Trim()
    }

    return "QueryFailed"
}

function Get-BitLockerProtectionState {
    try {
        if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) {
            $volume = Get-BitLockerVolume -MountPoint "C:" -ErrorAction Stop
            if ($null -ne $volume.ProtectionStatus) {
                return [string]$volume.ProtectionStatus
            }
        }
    }
    catch {}

    try {
        $lines = & manage-bde.exe -status C: 2>$null
        $text = $lines -join "`n"

        if ($text -match "(?im)Protection Status\s*:\s*Protection On") {
            return "On"
        }
        if ($text -match "(?im)Protection Status\s*:\s*Protection Off") {
            return "Off"
        }
        if ($text -match "(?im)Estado de protecci[oó]n\s*:\s*Protecci[oó]n activada") {
            return "On"
        }
        if ($text -match "(?im)Estado de protecci[oó]n\s*:\s*Protecci[oó]n desactivada") {
            return "Off"
        }
    }
    catch {}

    return "Unknown"
}

$isAdmin = Test-IsAdministrator

Section $T.Title
Write-Host $T.ReadOnly -ForegroundColor Green
if (-not $isAdmin) {
    Write-Warning $T.AdminWarning
}
Write-Host $T.Collecting

# -----------------------------------------------------------------------------
# System information
# -----------------------------------------------------------------------------
$cvPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
$cv = Get-ItemProperty -Path $cvPath -ErrorAction SilentlyContinue
$productName = [string]$cv.ProductName
$displayVersion = [string]$cv.DisplayVersion
$currentBuild = 0
[int]::TryParse([string]$cv.CurrentBuildNumber, [ref]$currentBuild) | Out-Null
$ubr = if ($null -ne $cv.UBR) { [int]$cv.UBR } else { 0 }
$buildDisplay = if ($currentBuild -gt 0) { "$currentBuild.$ubr" } else { "Unknown" }

# Some Windows 11 builds still expose "Windows 10" in ProductName.
if (($currentBuild -ge 22000) -and ($productName -match "Windows 10")) {
    $productName = $productName -replace "Windows 10", "Windows 11"
}
if ([string]::IsNullOrWhiteSpace($productName)) {
    $productName = "Unknown"
}
if ([string]::IsNullOrWhiteSpace($displayVersion)) {
    $displayVersion = "Unknown"
}

# CPU / firmware virtualization.
$cpu = $null
try {
    $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
}
catch {}

$cpuName = if ($cpu) { [string]$cpu.Name } else { "Unknown" }
$firmwareVirt = if ($cpu) { $cpu.VirtualizationFirmwareEnabled } else { $null }
$slat = if ($cpu) { $cpu.SecondLevelAddressTranslationExtensions } else { $null }

# HypervisorPresent.
$computerSystem = $null
try {
    $computerSystem = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
}
catch {}
$hypervisorPresent = if ($computerSystem) { $computerSystem.HypervisorPresent } else { $null }

# VMware Workstation version.
$vmwareVersion = "NotDetected"
try {
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $vmware = Get-ItemProperty $uninstallPaths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "VMware Workstation*" } |
        Select-Object -First 1

    if ($vmware -and $vmware.DisplayVersion) {
        $vmwareVersion = [string]$vmware.DisplayVersion
    }
    else {
        $candidatePaths = @(
            "$env:ProgramFiles\VMware\VMware Workstation\vmware.exe",
            "${env:ProgramFiles(x86)}\VMware\VMware Workstation\vmware.exe"
        )

        $candidate = $candidatePaths |
            Where-Object { $_ -and (Test-Path $_) } |
            Select-Object -First 1

        if ($candidate) {
            $vmwareVersion = [string](Get-Item $candidate).VersionInfo.ProductVersion
        }
    }
}
catch {}

# VBS / Device Guard.
$deviceGuard = $null
try {
    $deviceGuard = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction Stop
}
catch {}

$vbsStatus = if ($deviceGuard) { $deviceGuard.VirtualizationBasedSecurityStatus } else { $null }
$securityConfigured = if ($deviceGuard) { ($deviceGuard.SecurityServicesConfigured -join ",") } else { "" }
$securityRunning = if ($deviceGuard) { ($deviceGuard.SecurityServicesRunning -join ",") } else { "" }

# HVCI / Memory Integrity configured state.
$hvci = Get-RegDwordState -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" -Name "Enabled"

# VBS policy state.
$vbsPolicy = Get-RegDwordState -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" -Name "EnableVirtualizationBasedSecurity"

# Optional Windows virtualization features.
$featureNames = @(
    "Microsoft-Hyper-V-All",
    "VirtualMachinePlatform",
    "HypervisorPlatform",
    "Containers-DisposableClientVM",
    "Microsoft-Windows-Subsystem-Linux"
)

$features = [ordered]@{}
foreach ($featureName in $featureNames) {
    $features[$featureName] = Get-WindowsFeatureState -FeatureName $featureName
}

$enabledFeatures = @(
    $features.GetEnumerator() |
        Where-Object { $_.Value -eq "Enabled" } |
        ForEach-Object { $_.Key }
)

# BCD.
$bcdLines = @()
$bcdSucceeded = $false
try {
    $bcdLines = & bcdedit.exe /enum '{current}' 2>$null
    $bcdSucceeded = ($LASTEXITCODE -eq 0)
}
catch {
    $bcdSucceeded = $false
}

$bcdHypervisor = Get-BcdElementState -Lines $bcdLines -ElementName "hypervisorlaunchtype" -QuerySucceeded:$bcdSucceeded
$bcdVsm = Get-BcdElementState -Lines $bcdLines -ElementName "vsmlaunchtype" -QuerySucceeded:$bcdSucceeded

# WindowsHello Device Guard scenario.
$windowsHello = Get-RegDwordState -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello" -Name "Enabled"

# Secure Boot.
$secureBoot = $null
$secureBootState = "QueryFailed"
try {
    $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop
    if ($secureBoot -eq $true) {
        $secureBootState = "Enabled"
    }
    else {
        $secureBootState = "Disabled"
    }
}
catch {}

# BitLocker protection state on C:.
$bitLockerProtection = Get-BitLockerProtectionState

# hvhost service.
$hvHostState = "NotPresent"
try {
    $hvService = Get-Service -Name "hvhost" -ErrorAction Stop
    $hvHostState = [string]$hvService.Status
}
catch {}

# Historical Hyper-V hypervisor Event ID 2.
$event2Found = $false
$latestEvent2Time = ""
try {
    $event2 = Get-WinEvent -FilterHashtable @{
        ProviderName = "Microsoft-Windows-Hyper-V-Hypervisor"
        Id = 2
    } -MaxEvents 1 -ErrorAction Stop

    if ($event2) {
        $event2Found = $true
        $latestEvent2Time = $event2.TimeCreated.ToString("s")
    }
}
catch {}

# -----------------------------------------------------------------------------
# Rule engine - one next step only
# IMPORTANT: HypervisorPresent=False wins immediately unless AMD-V/SVM itself
# is disabled in firmware. Historical events never override current host state.
# -----------------------------------------------------------------------------
$recommendationCode = "MANUAL_REVIEW"
$recommendedStep = "SUPPORT"
$diagnosisTitle = $T.Diagnosis
$recommendationBody = $T.ManualBody

if ($firmwareVirt -eq $false) {
    $recommendationCode = "ENABLE_AMD_V_SVM"
    $recommendedStep = "1"
    $recommendationBody = $T.BiosBody
}
elseif ($hypervisorPresent -eq $false) {
    $recommendationCode = "READY_FOR_VMWARE"
    $recommendedStep = "11"
    $diagnosisTitle = $T.ReadyTitle
    $recommendationBody = $T.ReadyBody
}
elseif (-not $isAdmin) {
    $recommendationCode = "RERUN_AS_ADMIN"
    $recommendedStep = "ADMIN"
    $recommendationBody = $T.AdminBody
}
elseif ($hvci.State -eq "Enabled") {
    $recommendationCode = "DISABLE_MEMORY_INTEGRITY"
    $recommendedStep = "3"
    $recommendationBody = $T.HvciBody
}
elseif (($vbsStatus -eq 2) -and ($vbsPolicy.State -ne "Disabled")) {
    $recommendationCode = "DISABLE_VBS_POLICY"
    $recommendedStep = "4"
    $recommendationBody = $T.VbsPolicyBody
}
elseif ($enabledFeatures.Count -gt 0) {
    $recommendationCode = "DISABLE_WINDOWS_VIRTUALIZATION_FEATURES"
    $recommendedStep = "5"
    $recommendationBody = $T.FeatureBody
}
elseif (($bcdHypervisor -notmatch "^(?i:off)$") -or ($bcdVsm -notmatch "^(?i:off)$")) {
    $recommendationCode = "DISABLE_HYPERVISOR_BCD"
    $recommendedStep = "6"
    $recommendationBody = $T.BcdBody
}
elseif (($vbsStatus -eq 2) -and ($secureBoot -eq $true)) {
    $recommendationCode = "CHECK_SECURE_BOOT_WITH_BITLOCKER"
    $recommendedStep = "8"
    $recommendationBody = $T.SecureBootBody
}
elseif ($windowsHello.State -eq "Enabled") {
    $recommendationCode = "CHECK_WINDOWSHELLO_SCENARIO"
    $recommendedStep = "9"
    $recommendationBody = $T.HelloBody
}

# -----------------------------------------------------------------------------
# Human-readable summary
# -----------------------------------------------------------------------------
Section $T.Summary

$firmwareVirtDisplay = if ($null -eq $firmwareVirt) { $T.Unknown } else { [string]$firmwareVirt }
$slatDisplay = if ($null -eq $slat) { $T.Unknown } else { [string]$slat }
$hypervisorDisplay = if ($null -eq $hypervisorPresent) { $T.Unknown } else { [string]$hypervisorPresent }
$vbsDisplay = if ($null -eq $vbsStatus) { $T.Unknown } else { [string]$vbsStatus }
$vmwareDisplay = if ($vmwareVersion -eq "NotDetected") { $T.NotPresent } else { $vmwareVersion }
$featureDisplay = if ($enabledFeatures.Count -eq 0) { $T.None } else { $enabledFeatures -join ", " }

Write-Host ("Windows                     : {0} {1} (build {2})" -f $productName, $displayVersion, $buildDisplay)
Write-Host ("CPU                         : {0}" -f $cpuName)
Write-Host ("AMD-V / SVM firmware        : {0}" -f $firmwareVirtDisplay)
Write-Host ("SLAT / RVI                  : {0}" -f $slatDisplay)
Write-Host ("VMware Workstation          : {0}" -f $vmwareDisplay)
Write-Host ("HypervisorPresent           : {0}" -f $hypervisorDisplay)
Write-Host ("VBS status                  : {0}" -f $vbsDisplay)
Write-Host ("VBS policy                  : {0}" -f (Convert-StateToDisplay $vbsPolicy.State))
Write-Host ("Memory Integrity/HVCI       : {0}" -f (Convert-StateToDisplay $hvci.State))
Write-Host ("BCD hypervisorlaunchtype    : {0}" -f (Convert-StateToDisplay $bcdHypervisor))
Write-Host ("BCD vsmlaunchtype           : {0}" -f (Convert-StateToDisplay $bcdVsm))
Write-Host ("WindowsHello scenario       : {0}" -f (Convert-StateToDisplay $windowsHello.State))
Write-Host ("Secure Boot                 : {0}" -f (Convert-StateToDisplay $secureBootState))
Write-Host ("BitLocker C: protection     : {0}" -f $bitLockerProtection)
Write-Host ("hvhost                      : {0}" -f $hvHostState)
Write-Host ("Hyper-V Event ID 2 historico: {0}" -f $event2Found)
if ($event2Found) {
    Write-Host ("  {0}: {1}" -f $T.HistoricalEvent, $latestEvent2Time) -ForegroundColor DarkGray
}
Write-Host ("Caracteristicas activas / Enabled features: {0}" -f $featureDisplay)

Section $diagnosisTitle
$diagnosisColor = if ($recommendationCode -eq "READY_FOR_VMWARE") { "Green" } else { "Yellow" }
Write-Host $recommendationBody -ForegroundColor $diagnosisColor

if ($recommendationCode -ne "READY_FOR_VMWARE") {
    Write-Host ""
    Write-Host $T.NextStep -ForegroundColor Cyan
    Write-Host ("Guide step / Paso de la guia: {0}" -f $recommendedStep)
}

# -----------------------------------------------------------------------------
# Sanitized support report
# -----------------------------------------------------------------------------
$report = [ordered]@{
    Schema = "VMWARE_AMD_RVI_DIAGNOSTIC_V2"
    ScriptVersion = $ScriptVersion
    Language = $Lang
    IsAdministrator = $isAdmin
    WindowsProduct = $productName
    WindowsDisplayVersion = $displayVersion
    WindowsBuild = $buildDisplay
    CPU = $cpuName
    FirmwareVirtualization = $firmwareVirt
    SLAT_RVI = $slat
    VMwareWorkstationVersion = $vmwareVersion
    HypervisorPresent = $hypervisorPresent
    VBSStatus = $vbsStatus
    VBSPolicy = $vbsPolicy.State
    SecurityServicesConfigured = $securityConfigured
    SecurityServicesRunning = $securityRunning
    MemoryIntegrityHVCI = $hvci.State
    Feature_Microsoft_Hyper_V_All = $features["Microsoft-Hyper-V-All"]
    Feature_VirtualMachinePlatform = $features["VirtualMachinePlatform"]
    Feature_HypervisorPlatform = $features["HypervisorPlatform"]
    Feature_Containers_DisposableClientVM = $features["Containers-DisposableClientVM"]
    Feature_Microsoft_Windows_Subsystem_Linux = $features["Microsoft-Windows-Subsystem-Linux"]
    BcdHypervisorLaunchType = $bcdHypervisor
    BcdVsmLaunchType = $bcdVsm
    WindowsHelloScenario = $windowsHello.State
    SecureBoot = $secureBootState
    BitLockerProtectionC = $bitLockerProtection
    HvHostState = $hvHostState
    HyperVEventId2Found = $event2Found
    LatestHyperVEventId2Time = $latestEvent2Time
    RecommendationCode = $recommendationCode
    RecommendedGuideStep = $recommendedStep
}

$reportLines = New-Object System.Collections.Generic.List[string]
$reportLines.Add("--- BEGIN VMWARE AMD-V/RVI DIAGNOSTIC REPORT ---")
foreach ($item in $report.GetEnumerator()) {
    $value = if ($null -eq $item.Value) { "" } else { [string]$item.Value }
    $reportLines.Add(("{0}={1}" -f $item.Key, $value))
}
$reportLines.Add("--- END VMWARE AMD-V/RVI DIAGNOSTIC REPORT ---")

Section $T.Shareable
Write-Host $T.ShareHelp
Write-Host ""
$reportLines | ForEach-Object { Write-Host $_ }

$shouldExport = $ExportReport.IsPresent
if ((-not $NoPrompt) -and (-not $ExportReport)) {
    Write-Host ""
    $answer = Read-Host $T.SaveQuestion
    if ($Lang -eq "es") {
        $shouldExport = $answer -match "^(?i:s|si|sí|y|yes)$"
    }
    else {
        $shouldExport = $answer -match "^(?i:y|yes|s|si|sí)$"
    }
}

if ($shouldExport) {
    try {
        $txtPath = Join-Path (Get-Location) "vmware-amd-rvi-report.txt"
        $jsonPath = Join-Path (Get-Location) "vmware-amd-rvi-report.json"

        $reportLines | Set-Content -Path $txtPath -Encoding UTF8
        $report | ConvertTo-Json -Depth 4 | Set-Content -Path $jsonPath -Encoding UTF8

        Write-Host ""
        Write-Host ("{0}: {1}" -f $T.Saved, (Get-Location)) -ForegroundColor Green
        Write-Host "  vmware-amd-rvi-report.txt"
        Write-Host "  vmware-amd-rvi-report.json"
    }
    catch {
        Write-Warning $_.Exception.Message
    }
}

Write-Host ""
Write-Host $T.ReadOnly -ForegroundColor Green
