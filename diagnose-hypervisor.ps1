<#
.SYNOPSIS
Read-only diagnostic for VMware nested AMD-V/RVI issues on Windows 11.

.DESCRIPTION
Collects the Windows host state most commonly involved when VMware reports:
"Virtualized AMD-V/RVI is not supported on this platform."

READ-ONLY / SOLO LECTURA:
This script does NOT modify Windows, the registry, BCD, BitLocker, BIOS/UEFI,
Secure Boot, VMware, or any Windows optional feature.

Recommended: run from PowerShell as Administrator.
#>

$ErrorActionPreference = "Continue"

function Section([string]$Title) {
    Write-Host ""
    Write-Host ("=" * 76) -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host ("=" * 76) -ForegroundColor Cyan
}

function ValueOrUnknown($Value) {
    if ($null -eq $Value -or "$Value" -eq "") { return "<unknown>" }
    return $Value
}

# Administrator check — informational only.
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host "VMware AMD-V/RVI Host Diagnostic v1.1" -ForegroundColor Cyan
Write-Host "READ-ONLY / SOLO LECTURA - no settings will be changed." -ForegroundColor Green
if (-not $isAdmin) {
    Write-Warning "PowerShell is not running as Administrator. Some checks may be incomplete."
}

Section "SYSTEM"
try {
    Get-ComputerInfo |
        Select-Object WindowsProductName, WindowsVersion, OsBuildNumber, OsArchitecture
}
catch {
    Write-Warning "Could not read complete Windows information: $($_.Exception.Message)"
}

Section "CPU / AMD-V / FIRMWARE VIRTUALIZATION"
$cpu = $null
try {
    $cpu = Get-CimInstance Win32_Processor
    $cpu |
        Select-Object Name, VirtualizationFirmwareEnabled, SecondLevelAddressTranslationExtensions
}
catch {
    Write-Warning "Could not query CPU virtualization state: $($_.Exception.Message)"
}

Section "WINDOWS HYPERVISOR"
$computerSystem = $null
try {
    $computerSystem = Get-CimInstance Win32_ComputerSystem
    $computerSystem |
        Select-Object Manufacturer, Model, HypervisorPresent
}
catch {
    Write-Warning "Could not query HypervisorPresent: $($_.Exception.Message)"
}

Section "VBS / DEVICE GUARD"
$deviceGuard = $null
try {
    $deviceGuard = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard
    $deviceGuard |
        Format-List VirtualizationBasedSecurityStatus,
                    CodeIntegrityPolicyEnforcementStatus,
                    SecurityServicesConfigured,
                    SecurityServicesRunning
}
catch {
    Write-Warning "Could not query Win32_DeviceGuard: $($_.Exception.Message)"
}

Section "WINDOWS OPTIONAL FEATURES"
$virtualizationFeatures = $null
try {
    $virtualizationFeatures = Get-WindowsOptionalFeature -Online |
        Where-Object {
            $_.FeatureName -match "Hyper-V|VirtualMachinePlatform|HypervisorPlatform|Containers-DisposableClientVM|Subsystem-Linux"
        } |
        Select-Object FeatureName, State

    $virtualizationFeatures | Format-Table -AutoSize
}
catch {
    Write-Warning "Could not query optional features. Try running PowerShell as Administrator."
}

Section "BCD - CURRENT WINDOWS LOADER"
try {
    cmd.exe /c 'bcdedit /enum {current}'
}
catch {
    Write-Warning "Could not query BCD."
}

Section "DEVICE GUARD WINDOWSHELLO SCENARIO"
$windowsHelloPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello"
$windowsHelloEnabled = $null
if (Test-Path $windowsHelloPath) {
    try {
        $windowsHelloEnabled = (Get-ItemProperty -Path $windowsHelloPath -Name Enabled -ErrorAction Stop).Enabled
        Write-Host "Registry path exists."
        Write-Host "Enabled: $windowsHelloEnabled"
    }
    catch {
        Write-Host "Registry path exists, but the Enabled value was not found."
    }
}
else {
    Write-Host "Registry path does not exist."
}

Section "SECURE BOOT"
$secureBoot = $null
try {
    $secureBoot = Confirm-SecureBootUEFI
    Write-Host "SecureBootEnabled: $secureBoot"
}
catch {
    Write-Host "Could not query Secure Boot: $($_.Exception.Message)"
}

Section "BITLOCKER STATUS - C:"
try {
    manage-bde.exe -status C:
}
catch {
    Write-Warning "Could not query BitLocker status."
}

Section "HVHOST SERVICE"
try {
    sc.exe query hvhost
}
catch {
    Write-Warning "Could not query hvhost."
}

Section "LATEST HYPER-V HYPERVISOR EVENT ID 2"
$latestHvEvent = $null
try {
    $latestHvEvent = Get-WinEvent -FilterHashtable @{
        ProviderName = "Microsoft-Windows-Hyper-V-Hypervisor"
        Id = 2
    } -MaxEvents 3 -ErrorAction Stop

    $latestHvEvent |
        Format-List TimeCreated, Id, Message
}
catch {
    Write-Host "No matching Hyper-V hypervisor Event ID 2 was found."
}

Section "QUICK RESULT"

$hypervisorPresent = if ($null -ne $computerSystem) { $computerSystem.HypervisorPresent } else { $null }
$vbsStatus = if ($null -ne $deviceGuard) { $deviceGuard.VirtualizationBasedSecurityStatus } else { $null }
$firmwareVirt = if ($null -ne $cpu) { ($cpu | Select-Object -First 1).VirtualizationFirmwareEnabled } else { $null }
$slat = if ($null -ne $cpu) { ($cpu | Select-Object -First 1).SecondLevelAddressTranslationExtensions } else { $null }

Write-Host ("AMD-V / firmware virtualization : {0}" -f (ValueOrUnknown $firmwareVirt))
Write-Host ("SLAT / RVI support              : {0}" -f (ValueOrUnknown $slat))
Write-Host ("HypervisorPresent               : {0}" -f (ValueOrUnknown $hypervisorPresent))
Write-Host ("VBS status                       : {0}" -f (ValueOrUnknown $vbsStatus))
Write-Host ("WindowsHello scenario Enabled    : {0}" -f (ValueOrUnknown $windowsHelloEnabled))
Write-Host ("Secure Boot                      : {0}" -f (ValueOrUnknown $secureBoot))

if ($hypervisorPresent -eq $false) {
    Write-Host ""
    Write-Host "TARGET STATE REACHED: HypervisorPresent = FALSE" -ForegroundColor Green
    Write-Host "Windows is not reporting a host hypervisor."
    Write-Host "VMware nested AMD-V/RVI can now be tested."
}
elseif ($hypervisorPresent -eq $true) {
    Write-Host ""
    Write-Host "HypervisorPresent = TRUE" -ForegroundColor Yellow
    Write-Host "Windows is still reporting a host hypervisor."
    Write-Host "Follow the README incrementally and re-run this script after each reboot."
}
else {
    Write-Host ""
    Write-Warning "HypervisorPresent could not be determined."
}

if ($firmwareVirt -eq $false) {
    Write-Host "AMD-V/SVM appears disabled in firmware. Enable SVM/AMD-V in BIOS/UEFI." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "No settings were changed by this script." -ForegroundColor Green
