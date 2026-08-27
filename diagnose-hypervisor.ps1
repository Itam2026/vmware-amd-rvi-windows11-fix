<#
.SYNOPSIS
Bilingual read-only troubleshooter for VMware nested AMD-V/RVI issues on Windows 11.

.DESCRIPTION
Analyzes the Windows host when VMware reports:
"Virtualized AMD-V/RVI is not supported on this platform."

It collects a privacy-conscious system state, applies a rule-based diagnosis,
and recommends only the next relevant step in the repository guide.

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
$ScriptVersion = "2.0"

function Select-Language {
    param([string]$RequestedLanguage, [switch]$SkipPrompt)

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
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = $defaultChoice }

    if ($choice -eq "2") { return "en" }
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
        NotSaved = "No se guardaron archivos."
        NoChanges = "El diagnostico termino. No se cambio ninguna configuracion del sistema."
        Unknown = "No determinado"
        Enabled = "Habilitado"
        Disabled = "Deshabilitado"
        Running = "En ejecucion"
        Stopped = "Detenido"
        NotInstalled = "No instalado"
        ReadyTitle = "ESTADO OBJETIVO ALCANZADO"
        Ready = "Windows ya no reporta un hipervisor de host. Prueba la VM con 'Virtualize Intel VT-x/EPT or AMD-V/RVI' activado en VMware."
        RunAdmin = "Vuelve a ejecutar PowerShell como administrador para obtener un diagnostico completo."
        EnableSvm = "AMD-V/SVM parece deshabilitado en firmware. Habilita SVM/AMD-V en BIOS/UEFI y vuelve a ejecutar el diagnostico."
        DisableVbs = "VBS, Memory Integrity/HVCI o un servicio de seguridad basado en virtualizacion sigue configurado/activo. Sigue los pasos 3 y 4 de README_ES.md, reinicia y vuelve a ejecutar el script."
        DisableFeatures = "Hay caracteristicas de virtualizacion de Windows habilitadas. Sigue el paso 5 de README_ES.md, reinicia y vuelve a ejecutar el script."
        DisableBcd = "Windows aun puede iniciar el hipervisor desde BCD. Sigue el paso 6 de README_ES.md, reinicia y vuelve a ejecutar el script."
        CheckVbs = "VBS sigue activo aunque los bloqueos mas comunes no aparecen habilitados. Revisa el paso 7 de README_ES.md y vuelve a ejecutar el diagnostico despues de reiniciar."
        CheckSecureBoot = "VBS sigue activo con los bloqueos comunes ya desactivados. Revisa el paso 8 de README_ES.md. Si BitLocker esta activo, guarda tu clave de recuperacion y suspende sus protectores antes de probar cambios de Secure Boot."
        CheckHello = "HypervisorPresent sigue en TRUE aunque VBS, caracteristicas opcionales y BCD ya no explican el problema. El escenario WindowsHello de Device Guard esta habilitado. Revisa el paso 9 de README_ES.md. Este paso no es una solucion universal."
        UnknownNext = "Windows sigue reportando un hipervisor, pero el motor de reglas no encontro una causa segura. Comparte el reporte sanitizado antes de hacer mas cambios."
        Step = "Paso de la guia"
        Feature = "Caracteristicas activas"
        BitLockerCaution = "No compartas tu clave de recuperacion de BitLocker."
        SaveFailed = "No se pudo guardar el reporte"
    }
    en = @{
        Title = "VMware AMD-V/RVI Troubleshooter v$ScriptVersion"
        ReadOnly = "READ-ONLY: the diagnostic will not change system settings."
        AdminWarning = "PowerShell is not running as Administrator. Some checks may be incomplete."
        Collecting = "Analyzing this host..."
        Summary = "SUMMARY"
        Diagnosis = "DIAGNOSIS"
        NextStep = "RECOMMENDED NEXT STEP"
        Shareable = "SANITIZED SHAREABLE REPORT"
        ShareHelp = "Copy the block below into ChatGPT, GitHub Issues, or a support forum. It does not include hostname, username, BitLocker recovery keys, serial numbers, or product keys."
        SaveQuestion = "Also save the report as TXT and JSON files? [y/N]"
        Saved = "Reports saved in"
        NotSaved = "No files were saved."
        NoChanges = "Diagnostic finished. No system settings were changed."
        Unknown = "Unknown"
        Enabled = "Enabled"
        Disabled = "Disabled"
        Running = "Running"
        Stopped = "Stopped"
        NotInstalled = "Not installed"
        ReadyTitle = "TARGET STATE REACHED"
        Ready = "Windows is no longer reporting a host hypervisor. Test the VM with 'Virtualize Intel VT-x/EPT or AMD-V/RVI' enabled in VMware."
        RunAdmin = "Run PowerShell as Administrator and execute the diagnostic again for complete results."
        EnableSvm = "AMD-V/SVM appears disabled in firmware. Enable SVM/AMD-V in BIOS/UEFI, then run the diagnostic again."
        DisableVbs = "VBS, Memory Integrity/HVCI, or a virtualization-based security service is still configured/running. Follow steps 3 and 4 in README.md, reboot, and run the script again."
        DisableFeatures = "Windows virtualization features are enabled. Follow step 5 in README.md, reboot, and run the script again."
        DisableBcd = "Windows may still launch the hypervisor through BCD. Follow step 6 in README.md, reboot, and run the script again."
        CheckVbs = "VBS is still active even though the most common blockers are not enabled. Review step 7 in README.md and run the diagnostic again after rebooting."
        CheckSecureBoot = "VBS is still active after the common blockers were disabled. Review step 8 in README.md. If BitLocker is enabled, save your recovery key and suspend protectors before testing Secure Boot changes."
        CheckHello = "HypervisorPresent is still TRUE even though VBS, optional features, and BCD no longer explain it. The Device Guard WindowsHello scenario is enabled. Review step 9 in README.md. This is not a universal fix."
        UnknownNext = "Windows still reports a hypervisor, but the rule engine did not identify a safe next cause. Share the sanitized report before making more changes."
        Step = "Guide step"
        Feature = "Enabled features"
        BitLockerCaution = "Never share your BitLocker recovery key."
        SaveFailed = "Could not save the report"
    }
}

function T([string]$Key) {
    return $Text[$Lang][$Key]
}

function Section([string]$Title) {
    Write-Host ""
    Write-Host ("=" * 78) -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host ("=" * 78) -ForegroundColor Cyan
}

function To-DisplayValue($Value) {
    if ($null -eq $Value -or "$Value" -eq "") { return (T "Unknown") }
    if ($Value -is [bool]) { return "$Value" }
    return "$Value"
}

function Get-BcdValue {
    param([string]$BcdText, [string]$Name)
    if ([string]::IsNullOrWhiteSpace($BcdText)) { return $null }
    $pattern = "(?im)^\s*" + [regex]::Escape($Name) + "\s+(\S+)\s*$"
    $match = [regex]::Match($BcdText, $pattern)
    if ($match.Success) { return $match.Groups[1].Value }
    return $null
}

function Get-FeatureState {
    param([string]$Name)
    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName $Name -ErrorAction Stop
        return "$($feature.State)"
    }
    catch {
        return "Unknown"
    }
}

function Test-NonZeroCollection($Value) {
    if ($null -eq $Value) { return $false }
    foreach ($item in @($Value)) {
        if ($null -ne $item -and "$item" -ne "" -and [int]$item -ne 0) { return $true }
    }
    return $false
}

# Informational administrator check.
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Section (T "Title")
Write-Host (T "ReadOnly") -ForegroundColor Green
Write-Host (T "Collecting")
if (-not $isAdmin) { Write-Warning (T "AdminWarning") }

# -------------------------
# Collect privacy-conscious state
# -------------------------

$windowsProduct = $null
$windowsDisplayVersion = $null
$windowsBuild = $null
try {
    $cv = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction Stop
    $windowsProduct = $cv.ProductName
    $windowsDisplayVersion = $cv.DisplayVersion
    $windowsBuild = if ($null -ne $cv.UBR) { "$($cv.CurrentBuildNumber).$($cv.UBR)" } else { "$($cv.CurrentBuildNumber)" }
}
catch {}

$cpuName = $null
$firmwareVirt = $null
$slat = $null
try {
    $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
    $cpuName = $cpu.Name.Trim()
    $firmwareVirt = $cpu.VirtualizationFirmwareEnabled
    $slat = $cpu.SecondLevelAddressTranslationExtensions
}
catch {}

$manufacturer = $null
$model = $null
$hypervisorPresent = $null
try {
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $manufacturer = $cs.Manufacturer
    $model = $cs.Model
    $hypervisorPresent = $cs.HypervisorPresent
}
catch {}

$vbsStatus = $null
$securityConfigured = $null
$securityRunning = $null
try {
    $dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace "root\Microsoft\Windows\DeviceGuard" -ErrorAction Stop
    $vbsStatus = $dg.VirtualizationBasedSecurityStatus
    $securityConfigured = @($dg.SecurityServicesConfigured)
    $securityRunning = @($dg.SecurityServicesRunning)
}
catch {}

$hvciEnabled = $null
$hvciPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
if (Test-Path $hvciPath) {
    try { $hvciEnabled = (Get-ItemProperty $hvciPath -Name Enabled -ErrorAction Stop).Enabled } catch {}
}

$featureNames = @(
    "Microsoft-Hyper-V-All",
    "VirtualMachinePlatform",
    "HypervisorPlatform",
    "Containers-DisposableClientVM",
    "Microsoft-Windows-Subsystem-Linux"
)
$featureStates = [ordered]@{}
foreach ($featureName in $featureNames) {
    $featureStates[$featureName] = Get-FeatureState $featureName
}
$enabledFeatures = @($featureStates.GetEnumerator() | Where-Object { $_.Value -eq "Enabled" } | ForEach-Object { $_.Key })

$bcdText = $null
$bcdHypervisorLaunchType = $null
$bcdVsmLaunchType = $null
try {
    $bcdText = (& bcdedit.exe /enum '{current}' 2>&1 | Out-String)
    $bcdHypervisorLaunchType = Get-BcdValue -BcdText $bcdText -Name "hypervisorlaunchtype"
    $bcdVsmLaunchType = Get-BcdValue -BcdText $bcdText -Name "vsmlaunchtype"
}
catch {}

$windowsHelloExists = $false
$windowsHelloEnabled = $null
$windowsHelloPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello"
if (Test-Path $windowsHelloPath) {
    $windowsHelloExists = $true
    try { $windowsHelloEnabled = (Get-ItemProperty $windowsHelloPath -Name Enabled -ErrorAction Stop).Enabled } catch {}
}

$secureBoot = $null
try { $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop } catch {}

$bitLockerProtection = $null
try {
    if (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue) {
        $bl = Get-BitLockerVolume -MountPoint "C:" -ErrorAction Stop
        $bitLockerProtection = "$($bl.ProtectionStatus)"
    }
}
catch {}

$hvhostState = "NotInstalled"
try {
    $svc = Get-Service -Name "hvhost" -ErrorAction Stop
    $hvhostState = "$($svc.Status)"
}
catch {}

$recentHvEvent2 = $false
$latestHvEventTime = $null
try {
    $event = Get-WinEvent -FilterHashtable @{
        ProviderName = "Microsoft-Windows-Hyper-V-Hypervisor"
        Id = 2
    } -MaxEvents 1 -ErrorAction Stop
    if ($event) {
        $recentHvEvent2 = $true
        $latestHvEventTime = $event.TimeCreated.ToString("s")
    }
}
catch {}

$vmwareVersion = $null
$vmwarePaths = @(
    "$env:ProgramFiles\VMware\VMware Workstation\vmware.exe",
    "${env:ProgramFiles(x86)}\VMware\VMware Workstation\vmware.exe"
)
foreach ($path in $vmwarePaths) {
    if ($path -and (Test-Path $path)) {
        try {
            $vmwareVersion = (Get-Item $path).VersionInfo.ProductVersion
            if (-not $vmwareVersion) { $vmwareVersion = (Get-Item $path).VersionInfo.FileVersion }
            break
        }
        catch {}
    }
}

# -------------------------
# Rule-based recommendation
# -------------------------

$recommendationCode = "UNKNOWN"
$recommendedStep = "Support"
$recommendation = T "UnknownNext"

$securityServiceActive = (Test-NonZeroCollection $securityRunning)
$securityServiceConfigured = (Test-NonZeroCollection $securityConfigured)
$hvciConfigured = ($hvciEnabled -eq 1)
$featureBlocker = ($enabledFeatures.Count -gt 0)
$bcdHypervisorOff = ($bcdHypervisorLaunchType -and $bcdHypervisorLaunchType.ToLowerInvariant() -eq "off")
$bcdVsmOff = ($bcdVsmLaunchType -and $bcdVsmLaunchType.ToLowerInvariant() -eq "off")

if (-not $isAdmin) {
    $recommendationCode = "RUN_AS_ADMIN"
    $recommendedStep = "0"
    $recommendation = T "RunAdmin"
}
elseif ($firmwareVirt -eq $false) {
    $recommendationCode = "ENABLE_SVM_AMDV"
    $recommendedStep = "1"
    $recommendation = T "EnableSvm"
}
elseif ($hypervisorPresent -eq $false) {
    $recommendationCode = "READY_FOR_VMWARE"
    $recommendedStep = "11"
    $recommendation = T "Ready"
}
elseif ($featureBlocker) {
    $recommendationCode = "DISABLE_WINDOWS_VIRTUALIZATION_FEATURES"
    $recommendedStep = "5"
    $recommendation = T "DisableFeatures"
}
elseif ($hvciConfigured -or $securityServiceActive -or ($securityServiceConfigured -and $vbsStatus -ne 0)) {
    $recommendationCode = "DISABLE_VBS_HVCI"
    $recommendedStep = "3-4"
    $recommendation = T "DisableVbs"
}
elseif (-not $bcdHypervisorOff -or -not $bcdVsmOff) {
    $recommendationCode = "DISABLE_HYPERVISOR_BCD"
    $recommendedStep = "6"
    $recommendation = T "DisableBcd"
}
elseif ($vbsStatus -eq 2 -and $secureBoot -eq $true) {
    $recommendationCode = "INVESTIGATE_SECURE_BOOT"
    $recommendedStep = "8"
    $recommendation = T "CheckSecureBoot"
}
elseif ($vbsStatus -eq 2) {
    $recommendationCode = "VBS_STILL_RUNNING"
    $recommendedStep = "7"
    $recommendation = T "CheckVbs"
}
elseif ($hypervisorPresent -eq $true -and $vbsStatus -eq 0 -and $windowsHelloEnabled -eq 1) {
    $recommendationCode = "CHECK_WINDOWSHELLO_SCENARIO"
    $recommendedStep = "9"
    $recommendation = T "CheckHello"
}

# -------------------------
# Human-friendly console summary
# -------------------------

Section (T "Summary")
Write-Host ("Windows                     : {0} {1} (build {2})" -f (To-DisplayValue $windowsProduct), (To-DisplayValue $windowsDisplayVersion), (To-DisplayValue $windowsBuild))
Write-Host ("CPU                         : {0}" -f (To-DisplayValue $cpuName))
Write-Host ("AMD-V / SVM firmware        : {0}" -f (To-DisplayValue $firmwareVirt))
Write-Host ("SLAT / RVI                  : {0}" -f (To-DisplayValue $slat))
Write-Host ("VMware Workstation          : {0}" -f (To-DisplayValue $vmwareVersion))
Write-Host ("HypervisorPresent           : {0}" -f (To-DisplayValue $hypervisorPresent))
Write-Host ("VBS status                  : {0}" -f (To-DisplayValue $vbsStatus))
Write-Host ("Memory Integrity/HVCI config: {0}" -f (To-DisplayValue $hvciEnabled))
Write-Host ("BCD hypervisorlaunchtype    : {0}" -f (To-DisplayValue $bcdHypervisorLaunchType))
Write-Host ("BCD vsmlaunchtype           : {0}" -f (To-DisplayValue $bcdVsmLaunchType))
Write-Host ("WindowsHello scenario       : {0}" -f (To-DisplayValue $windowsHelloEnabled))
Write-Host ("Secure Boot                 : {0}" -f (To-DisplayValue $secureBoot))
Write-Host ("BitLocker C: protection     : {0}" -f (To-DisplayValue $bitLockerProtection))
Write-Host ("hvhost                      : {0}" -f (To-DisplayValue $hvhostState))
if ($enabledFeatures.Count -gt 0) {
    Write-Host ((T "Feature") + "            : " + ($enabledFeatures -join ", ")) -ForegroundColor Yellow
}
else {
    Write-Host ((T "Feature") + "            : none / ninguna")
}

Section (T "Diagnosis")
if ($recommendationCode -eq "READY_FOR_VMWARE") {
    Write-Host (T "ReadyTitle") -ForegroundColor Green
    Write-Host $recommendation -ForegroundColor Green
}
else {
    Write-Host ("Code: {0}" -f $recommendationCode) -ForegroundColor Yellow
    Write-Host ((T "Step") + ": " + $recommendedStep)
    Write-Host ""
    Write-Host $recommendation -ForegroundColor Yellow
}

if ($recommendationCode -eq "INVESTIGATE_SECURE_BOOT") {
    Write-Host ""
    Write-Host (T "BitLockerCaution") -ForegroundColor Red
}

# -------------------------
# Sanitized support report
# -------------------------

$reportObject = [ordered]@{
    Schema = "VMWARE_AMD_RVI_DIAGNOSTIC_V2"
    ScriptVersion = $ScriptVersion
    Language = $Lang
    IsAdministrator = $isAdmin
    WindowsProduct = $windowsProduct
    WindowsDisplayVersion = $windowsDisplayVersion
    WindowsBuild = $windowsBuild
    CPU = $cpuName
    FirmwareVirtualization = $firmwareVirt
    SLAT_RVI = $slat
    VMwareWorkstationVersion = $vmwareVersion
    HypervisorPresent = $hypervisorPresent
    VBSStatus = $vbsStatus
    SecurityServicesConfigured = @($securityConfigured)
    SecurityServicesRunning = @($securityRunning)
    MemoryIntegrityHVCIConfigured = $hvciEnabled
    OptionalFeatures = $featureStates
    BcdHypervisorLaunchType = $bcdHypervisorLaunchType
    BcdVsmLaunchType = $bcdVsmLaunchType
    WindowsHelloScenarioExists = $windowsHelloExists
    WindowsHelloScenarioEnabled = $windowsHelloEnabled
    SecureBoot = $secureBoot
    BitLockerProtectionC = $bitLockerProtection
    HvHostState = $hvhostState
    HyperVEventId2Found = $recentHvEvent2
    LatestHyperVEventId2Time = $latestHvEventTime
    RecommendationCode = $recommendationCode
    RecommendedGuideStep = $recommendedStep
}

$reportLines = New-Object System.Collections.Generic.List[string]
$reportLines.Add("--- BEGIN VMWARE AMD-V/RVI DIAGNOSTIC REPORT ---")
$reportLines.Add("Schema=VMWARE_AMD_RVI_DIAGNOSTIC_V2")
$reportLines.Add("ScriptVersion=$ScriptVersion")
$reportLines.Add("Language=$Lang")
$reportLines.Add("IsAdministrator=$isAdmin")
$reportLines.Add("WindowsProduct=$windowsProduct")
$reportLines.Add("WindowsDisplayVersion=$windowsDisplayVersion")
$reportLines.Add("WindowsBuild=$windowsBuild")
$reportLines.Add("CPU=$cpuName")
$reportLines.Add("FirmwareVirtualization=$firmwareVirt")
$reportLines.Add("SLAT_RVI=$slat")
$reportLines.Add("VMwareWorkstationVersion=$vmwareVersion")
$reportLines.Add("HypervisorPresent=$hypervisorPresent")
$reportLines.Add("VBSStatus=$vbsStatus")
$reportLines.Add("SecurityServicesConfigured=$(@($securityConfigured) -join ',')")
$reportLines.Add("SecurityServicesRunning=$(@($securityRunning) -join ',')")
$reportLines.Add("MemoryIntegrityHVCIConfigured=$hvciEnabled")
foreach ($entry in $featureStates.GetEnumerator()) {
    $reportLines.Add("Feature.$($entry.Key)=$($entry.Value)")
}
$reportLines.Add("BcdHypervisorLaunchType=$bcdHypervisorLaunchType")
$reportLines.Add("BcdVsmLaunchType=$bcdVsmLaunchType")
$reportLines.Add("WindowsHelloScenarioExists=$windowsHelloExists")
$reportLines.Add("WindowsHelloScenarioEnabled=$windowsHelloEnabled")
$reportLines.Add("SecureBoot=$secureBoot")
$reportLines.Add("BitLockerProtectionC=$bitLockerProtection")
$reportLines.Add("HvHostState=$hvhostState")
$reportLines.Add("HyperVEventId2Found=$recentHvEvent2")
$reportLines.Add("LatestHyperVEventId2Time=$latestHvEventTime")
$reportLines.Add("RecommendationCode=$recommendationCode")
$reportLines.Add("RecommendedGuideStep=$recommendedStep")
$reportLines.Add("--- END VMWARE AMD-V/RVI DIAGNOSTIC REPORT ---")
$reportText = $reportLines -join [Environment]::NewLine

Section (T "Shareable")
Write-Host (T "ShareHelp")
Write-Host ""
Write-Host $reportText

$shouldExport = $ExportReport.IsPresent
if (-not $shouldExport -and -not $NoPrompt) {
    $answer = Read-Host (T "SaveQuestion")
    if ($Lang -eq "es") {
        $shouldExport = ($answer -match "^(s|si|sí|y|yes)$")
    }
    else {
        $shouldExport = ($answer -match "^(y|yes|s|si|sí)$")
    }
}

if ($shouldExport) {
    try {
        $outputDir = (Get-Location).Path
        $txtPath = Join-Path $outputDir "vmware-amd-rvi-report.txt"
        $jsonPath = Join-Path $outputDir "vmware-amd-rvi-report.json"
        $reportText | Set-Content -Path $txtPath -Encoding UTF8
        $reportObject | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPath -Encoding UTF8
        Write-Host ""
        Write-Host ((T "Saved") + ":") -ForegroundColor Green
        Write-Host "  $txtPath"
        Write-Host "  $jsonPath"
    }
    catch {
        Write-Warning ((T "SaveFailed") + ": " + $_.Exception.Message)
    }
}
elseif (-not $NoPrompt) {
    Write-Host (T "NotSaved")
}

Write-Host ""
Write-Host (T "NoChanges") -ForegroundColor Green
