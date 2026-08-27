# VMware Workstation: Fix `Virtualized AMD-V/RVI is not supported on this platform` on Windows 11 + AMD

[**English**](./README.md) | [**Español**](./README_ES.md) | [**Support / Soporte**](./SUPPORT.md)

A practical guide and **bilingual read-only troubleshooter** for VMware Workstation nested virtualization on AMD Windows 11 hosts.

Useful for workloads such as:

- PNETLab
- EVE-NG
- GNS3 VM
- Nested ESXi
- Other VMs that require AMD-V/RVI inside VMware

---

## Start here: bilingual troubleshooter v2

Before changing Windows settings, download and run [`diagnose-hypervisor.ps1`](./diagnose-hypervisor.ps1) from **PowerShell as Administrator**.

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\diagnose-hypervisor.ps1
```

The script lets the user choose:

```text
[1] Espanol
[2] English
```

You can also force a language:

```powershell
.\diagnose-hypervisor.ps1 -Language es
.\diagnose-hypervisor.ps1 -Language en
```

### What v2 does

The troubleshooter checks the host, applies a small **rule engine**, and recommends **only the next relevant step** instead of telling everyone to disable every Windows security feature.

It checks:

- AMD-V / SVM firmware virtualization
- SLAT / RVI
- `HypervisorPresent`
- VBS / Device Guard
- Memory Integrity / HVCI configuration
- Hyper-V-related optional Windows features
- `hypervisorlaunchtype` and `vsmlaunchtype`
- the Device Guard `WindowsHello` scenario
- Secure Boot
- BitLocker protection state on `C:`
- `hvhost`
- recent Hyper-V hypervisor Event ID 2 presence
- VMware Workstation version when detectable

Example logic:

```text
HypervisorPresent = TRUE
VBS               = 0
Hyper-V features  = Disabled
BCD                = Off
WindowsHello       = Enabled

Recommendation:
Review guide Step 9 only.
```

Then reboot, run the troubleshooter again, and continue only if necessary.

### Read-only by design

The diagnostic **does not change**:

- Windows settings
- Registry values
- BCD
- BitLocker
- Secure Boot
- BIOS/UEFI
- Windows optional features
- VMware

It can optionally save a **sanitized TXT and JSON report**, but it never applies the fixes automatically.

### Shareable support report

At the end, the script prints a block like:

```text
--- BEGIN VMWARE AMD-V/RVI DIAGNOSTIC REPORT ---
...
RecommendationCode=...
RecommendedGuideStep=...
--- END VMWARE AMD-V/RVI DIAGNOSTIC REPORT ---
```

It intentionally excludes hostname, username, BitLocker recovery keys, product keys, and serial numbers. Review any information before publishing it.

See [SUPPORT.md](./SUPPORT.md) for instructions on pasting the report into GitHub Issues, ChatGPT, Broadcom Community, or another support channel.

To save the sanitized report directly:

```powershell
.\diagnose-hypervisor.ps1 -Language en -ExportReport
```

This creates:

```text
vmware-amd-rvi-report.txt
vmware-amd-rvi-report.json
```

---

## The VMware error

VMware may show:

```text
Virtualized AMD-V/RVI is not supported on this platform.
Continue without virtualized AMD-V/RVI?
```

or:

```text
Feature 'hv.capable' was 0, but must be at least 0x1.
Module 'FeatureCompatLate' power on failed.
Failed to start the virtual machine.
```

## The key diagnostic

Do **not** rely only on Hyper-V being unchecked or VBS reporting `0`.

Run:

```powershell
Get-CimInstance Win32_ComputerSystem |
Select-Object HypervisorPresent
```

For this troubleshooting path, the target state is:

```text
HypervisorPresent
-----------------
False
```

If it is still `True`, Windows is still reporting a host hypervisor.

> **Stop changing settings as soon as `HypervisorPresent` becomes `False`.**
> Not every PC needs every step below.

---

## Tested environment

The procedure was validated on:

- ASUS TUF Gaming A16 FA607NUG
- AMD Ryzen 7 7445HS
- Windows 11 Pro 25H2, build 26200.9168
- VMware Workstation 26.0.0.25388281
- PNETLab v6

A second AMD Windows 11 Pro system where nested virtualization already worked was used as a comparison host.

In the affected system, the final remaining cause was a Device Guard `WindowsHello` scenario that kept the Microsoft hypervisor loaded even after VBS had reached `0`.

That registry finding is **not claimed to be a universal cause or universal fix**.

---

# Manual troubleshooting guide

The v2 troubleshooter will normally tell you which section to use next. The manual procedure remains here for transparency and for systems where the automatic checks are incomplete.

## Step 1 — Verify AMD-V / SVM in firmware

Open **PowerShell as Administrator**:

```powershell
Get-CimInstance Win32_Processor |
Select-Object Name,VirtualizationFirmwareEnabled,SecondLevelAddressTranslationExtensions
```

Expected:

```text
VirtualizationFirmwareEnabled           True
SecondLevelAddressTranslationExtensions True
```

If firmware virtualization is `False`, enter BIOS/UEFI and enable the vendor equivalent of:

```text
SVM Mode
AMD-V
CPU Virtualization
```

**Keep SVM / AMD-V enabled throughout this guide.**

---

## Step 2 — Confirm whether the Windows hypervisor is present

```powershell
Get-CimInstance Win32_ComputerSystem |
Select-Object HypervisorPresent
```

Also run:

```cmd
systeminfo
```

If `systeminfo` says:

```text
A hypervisor has been detected.
```

Windows is still loading/reporting one.

If `HypervisorPresent` is already `False`, skip to **Step 11**.

---

## Step 3 — Disable Memory Integrity when it is part of the blocker

Go to:

```text
Settings
→ Privacy & security
→ Windows Security
→ Device security
→ Core isolation
```

Turn off:

```text
Memory integrity
```

Reboot when required and re-run the diagnostic.

---

## Step 4 — Disable VBS through Group Policy

On Windows 11 Pro, press `Win + R` and run:

```text
gpedit.msc
```

Go to:

```text
Computer Configuration
→ Administrative Templates
→ System
→ Device Guard
```

Open:

```text
Turn On Virtualization Based Security
```

Set it to:

```text
Disabled
```

Apply, reboot if required, and re-run the diagnostic.

---

## Step 5 — Disable conflicting Windows virtualization features

Press `Win + R` and run:

```text
optionalfeatures
```

For this VMware nested-virtualization troubleshooting path, disable conflicting features if they are enabled:

```text
Hyper-V
Virtual Machine Platform
Windows Hypervisor Platform
Windows Sandbox
Windows Subsystem for Linux
```

You can verify the state with PowerShell:

```powershell
Get-WindowsOptionalFeature -Online |
Where-Object {$_.FeatureName -match "Hyper-V|VirtualMachinePlatform|HypervisorPlatform|Containers-DisposableClientVM|Subsystem-Linux"} |
Select-Object FeatureName,State
```

Reboot and re-run the diagnostic.

---

## Step 6 — Stop Windows from launching the hypervisor through BCD

Open **Command Prompt as Administrator**:

```cmd
bcdedit /set {current} hypervisorlaunchtype off
bcdedit /set {current} vsmlaunchtype off
```

Verify:

```cmd
bcdedit /enum {current}
```

When explicitly configured, the target is:

```text
hypervisorlaunchtype    Off
vsmlaunchtype           Off
```

Restart Windows, then re-check:

```powershell
Get-CimInstance Win32_ComputerSystem |
Select-Object HypervisorPresent
```

If it is now `False`, skip to **Step 11**.

---

## Step 7 — Check VBS directly

```powershell
Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard |
Format-List VirtualizationBasedSecurityStatus,CodeIntegrityPolicyEnforcementStatus,SecurityServicesConfigured,SecurityServicesRunning
```

A disabled VBS state normally includes:

```text
VirtualizationBasedSecurityStatus : 0
```

If it is still:

```text
VirtualizationBasedSecurityStatus : 2
```

VBS is still running.

---

## Step 8 — If VBS refuses to stop, investigate Secure Boot carefully

> **Do not change Secure Boot before checking BitLocker.**

Check BitLocker:

```cmd
manage-bde -status C:
```

If protection is active, make sure you have access to your **BitLocker recovery key** before continuing. Never post that key publicly.

To temporarily suspend protectors for two reboots:

```cmd
manage-bde -protectors -disable C: -RebootCount 2
```

Verify:

```cmd
manage-bde -status C:
```

The drive remains encrypted while the protectors are temporarily suspended.

In BIOS/UEFI, keep:

```text
SVM / AMD-V = Enabled
```

As a troubleshooting test only, Secure Boot can be disabled on systems where VBS refuses to turn off.

Verify after boot:

```powershell
Confirm-SecureBootUEFI
```

Then re-check VBS and `HypervisorPresent`.

> Secure Boot is **not universally incompatible with VMware**. Do not disable it unless the diagnostic state actually points to this branch.

---

## Step 9 — Windows 11 24H2 / 25H2: Device Guard `WindowsHello` scenario

This was the final missing piece in the tested system.

Check:

```cmd
reg query "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello"
```

If the key does not exist, **do not create it just because this guide mentions it**.

If it exists and shows:

```text
Enabled    REG_DWORD    0x1
```

and the previous blockers are already cleared while `HypervisorPresent` remains `True`, this scenario can be investigated.

Before changing it, go to:

```text
Settings
→ Accounts
→ Sign-in options
→ Additional settings
```

Turn off the option similar to:

```text
For improved security, only allow Windows Hello sign-in
for Microsoft accounts on this device
```

Do **not** delete your PIN. Make sure you know the password for your Windows/Microsoft account.

Then, from **Command Prompt as Administrator**:

```cmd
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello" /v Enabled /t REG_DWORD /d 0 /f
```

Verify:

```cmd
reg query "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello"
```

Expected for this tested branch:

```text
Enabled    REG_DWORD    0x0
```

Restart Windows and run the troubleshooter again.

In the tested system, this was the change that finally produced:

```text
HypervisorPresent = False
```

Again: this was the cause **in this case**, not a universal Windows 11 fix.

---

## Step 10 — Final host verification

```powershell
Get-CimInstance Win32_ComputerSystem |
Select-Object HypervisorPresent
```

Target:

```text
False
```

Then:

```cmd
systeminfo
```

Instead of the hypervisor-detected message, the normal capability checks should be visible, such as:

```text
VM Monitor Mode Extensions: Yes
Virtualization Enabled In Firmware: Yes
Second Level Address Translation: Yes
Data Execution Prevention Available: Yes
```

Optional service check:

```powershell
sc.exe query hvhost
```

---

## Step 11 — Enable nested virtualization in VMware

Fully power off the VM.

Go to:

```text
VM
→ Settings
→ Processors
```

Enable:

```text
Virtualize Intel VT-x/EPT or AMD-V/RVI
```

Start the VM.

If the host state is correct, the AMD-V/RVI error should no longer appear.

---

## Step 12 — Re-enable BitLocker protection if you suspended it

```cmd
manage-bde -status C:
```

If protection is still suspended:

```cmd
manage-bde -protectors -enable C:
```

Verify again:

```cmd
manage-bde -status C:
```

---

## Why `HypervisorPresent` matters

The important state observed during the original troubleshooting was:

```text
Hyper-V feature            Off
VBS                        0
Memory Integrity           Off
hypervisorlaunchtype       Off

BUT

HypervisorPresent          True
```

VMware nested AMD-V/RVI still failed.

Only after Windows reported:

```text
HypervisorPresent = False
```

did the nested PNETLab VM start successfully with AMD-V/RVI enabled.

---

## Security warning

This guide can lead to disabling meaningful Windows protections, including:

- Virtualization-Based Security (VBS)
- Memory Integrity / HVCI
- Secure Boot in specific troubleshooting cases
- a Windows Hello / Device Guard scenario in a specific edge case

Do not apply every step blindly, especially on corporate, managed, production, or security-sensitive systems.

The v2 troubleshooter exists specifically to reduce unnecessary changes: **diagnose → apply one relevant step → reboot → diagnose again**.

---

## References

- [Microsoft Learn — Win32_ComputerSystem / HypervisorPresent](https://learn.microsoft.com/windows/win32/cimwin32prov/win32-computersystem)
- [Microsoft Learn — BCDEdit /set](https://learn.microsoft.com/windows-hardware/drivers/devtest/bcdedit--set)
- [Microsoft Learn — manage-bde protectors](https://learn.microsoft.com/windows-server/administration/windows-commands/manage-bde-protectors)
- [Microsoft Learn — Windows Hello Enhanced Sign-in Security](https://learn.microsoft.com/windows-hardware/design/device-experiences/windows-hello-enhanced-sign-in-security)
- [Broadcom VMware Community — Virtualized AMD-V/RVI is not supported on this platform](https://community.broadcom.com/vmware-cloud-foundation/discussion/virtualized-amd-vrvi-is-not-supported-on-this-platform)

---

## Contributing / requesting help

Run the v2 troubleshooter and paste its sanitized report into the repository's **AMD-V/RVI diagnostic** Issue template.

See [SUPPORT.md](./SUPPORT.md) for the recommended workflow.

Please **never post BitLocker recovery keys, passwords, product keys, serial numbers, email addresses, or other sensitive information**.
