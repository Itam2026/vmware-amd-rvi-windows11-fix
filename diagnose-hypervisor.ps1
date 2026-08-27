# Read-only diagnostic for VMware nested AMD-V/RVI issues on Windows 11.
# Run from an elevated PowerShell window.
# This script DOES NOT modify Windows, BCD, registry, BitLocker or firmware.

$ErrorActionPreference = "Continue"

function Section($title) {
    Write-Host ""
    Write-Host ("=" * 72) -ForegroundColor Cyan
    Write-Host $title -ForegroundColor Cyan
    Write-Host ("=" * 72) -ForegroundColor Cyan
}

Section "SYSTEM"
Get-ComputerInfo |
    Select-Object WindowsProductName, WindowsVersion, OsBuildNumber, OsArchitecture

Section "CPU / FIRMWARE VIRTUALIZATION"
Get-CimInstance Win32_Processor |
    Select-Object Name, VirtualizationFirmwareEnabled, SecondLevelAddressTranslationExtensions

Section "WINDOWS HYPERVISOR"
Get-CimInstance Win32_ComputerSystem |
    Select-Object Manufacturer, Model, HypervisorPresent

Section "VBS / DEVICE GUARD"
Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard |
    Format-List VirtualizationBasedSecurityStatus,
                CodeIntegrityPolicyEnforcementStatus,
                SecurityServicesConfigured,
                SecurityServicesRunning

Section "WINDOWS OPTIONAL FEATURES"
Get-WindowsOptionalFeature -Online |
    Where-Object {
        $_.FeatureName -match "Hyper-V|VirtualMachinePlatform|HypervisorPlatform|Containers-DisposableClientVM|Subsystem-Linux"
    } |
    Select-Object FeatureName, State

Section "BCD"
cmd /c 'bcdedit /enum {current}'

Section "WINDOWS HELLO DEVICE GUARD SCENARIO"
cmd /c 'reg query "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello"'

Section "SECURE BOOT"
try {
    $sb = Confirm-SecureBootUEFI
    Write-Host "SecureBootEnabled: $sb"
}
catch {
    Write-Host "Could not query Secure Boot: $($_.Exception.Message)"
}

Section "BITLOCKER STATUS"
cmd /c 'manage-bde -status C:'

Section "HVHOST SERVICE"
cmd /c 'sc query hvhost'

Section "LATEST HYPER-V HYPERVISOR EVENT ID 2"
try {
    Get-WinEvent -FilterHashtable @{
        ProviderName = "Microsoft-Windows-Hyper-V-Hypervisor"
        Id = 2
    } -MaxEvents 3 |
    Format-List TimeCreated, Id, Message
}
catch {
    Write-Host "No matching Hyper-V hypervisor Event ID 2 was found."
}

Section "QUICK RESULT"
$cs = Get-CimInstance Win32_ComputerSystem
if ($cs.HypervisorPresent) {
    Write-Host "HypervisorPresent = TRUE" -ForegroundColor Yellow
    Write-Host "Windows is still reporting a hypervisor. VMware nested AMD-V/RVI may still fail."
}
else {
    Write-Host "HypervisorPresent = FALSE" -ForegroundColor Green
    Write-Host "Windows is not reporting a hypervisor. This is the target state for this troubleshooting guide."
}
