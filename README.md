# VMware Workstation: Fix `Virtualized AMD-V/RVI is not supported on this platform` on Windows 11 + AMD

A step-by-step troubleshooting guide for **nested virtualization** on AMD hosts running VMware Workstation.

This is useful for workloads such as:

- PNETLab
- EVE-NG
- GNS3 VM
- Nested ESXi
- Other VMs that need AMD-V/RVI exposed to the guest

## The error

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

## Key idea

Do **not** rely only on Hyper-V being unchecked or VBS reporting `0`.

The most useful check is:

```powershell
Get-CimInstance Win32_ComputerSystem |
Select-Object HypervisorPresent
```

For VMware nested AMD-V/RVI, the target state is:

```text
HypervisorPresent
-----------------
False
```

If it is still `True`, Windows is still loading a hypervisor.

> **Stop as soon as `HypervisorPresent` becomes `False`.**
> You do not need to apply every step on every PC.

---

## Tested environment

This procedure was validated on a Windows 11 Pro 25H2 AMD laptop using VMware Workstation 26 and PNETLab v6.

The final cause in that specific system was a Device Guard `WindowsHello` scenario that kept the Microsoft hypervisor loaded even after VBS had already reached `0`.

That final registry step is **not claimed to be universal**.

---

# Step 1 — Verify AMD-V / SVM in firmware

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

If `VirtualizationFirmwareEnabled` is `False`, enter BIOS/UEFI and enable one of the following, depending on your vendor:

```text
SVM Mode
AMD-V
CPU Virtualization
```

**Keep SVM / AMD-V enabled throughout this guide.**

---

# Step 2 — Check whether the Windows hypervisor is actually running

Run:

```powershell
Get-CimInstance Win32_ComputerSystem |
Select-Object HypervisorPresent
```

Also run:

```cmd
systeminfo
```

If the end of `systeminfo` says:

```text
A hypervisor has been detected.
```

Windows is still loading its hypervisor.

If `HypervisorPresent` is already `False`, skip to **Step 10**.

---

# Step 3 — Disable Memory Integrity

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

---

# Step 4 — Disable VBS in Group Policy

> This is easiest on Windows 11 Pro.

Press `Win + R`, run:

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

Apply and close.

---

# Step 5 — Disable Windows virtualization features

Press `Win + R` and run:

```text
optionalfeatures
```

Make sure these are disabled if present:

```text
Hyper-V
Virtual Machine Platform
Windows Hypervisor Platform
Windows Sandbox
Windows Subsystem for Linux
```

You can verify the actual feature state with PowerShell:

```powershell
Get-WindowsOptionalFeature -Online |
Where-Object {$_.FeatureName -match "Hyper-V|VirtualMachinePlatform|HypervisorPlatform|Containers-DisposableClientVM|Subsystem-Linux"} |
Select-Object FeatureName,State
```

The relevant entries should report:

```text
Disabled
```

---

# Step 6 — Stop Windows from launching the hypervisor

Open **Command Prompt as Administrator**:

```cmd
bcdedit /set {current} hypervisorlaunchtype off
bcdedit /set {current} vsmlaunchtype off
```

Verify:

```cmd
bcdedit /enum {current}
```

Expected:

```text
hypervisorlaunchtype    Off
vsmlaunchtype           Off
```

Restart Windows.

Then re-check:

```powershell
Get-CimInstance Win32_ComputerSystem |
Select-Object HypervisorPresent
```

If it is now `False`, skip to **Step 10**.

---

# Step 7 — Check VBS directly

Open **PowerShell as Administrator**:

```powershell
Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard |
Format-List VirtualizationBasedSecurityStatus,CodeIntegrityPolicyEnforcementStatus,SecurityServicesConfigured,SecurityServicesRunning
```

A fully disabled VBS state should normally include:

```text
VirtualizationBasedSecurityStatus : 0
```

If it is still:

```text
VirtualizationBasedSecurityStatus : 2
```

VBS is still running.

---

# Step 8 — If VBS is still running, investigate Secure Boot

> **Do not change Secure Boot without checking BitLocker first.**

Check BitLocker:

```cmd
manage-bde -status C:
```

If protection is active, make sure you have access to your **BitLocker recovery key** before continuing.

To temporarily suspend BitLocker protectors for two reboots:

```cmd
manage-bde -protectors -disable C: -RebootCount 2
```

Verify:

```cmd
manage-bde -status C:
```

The drive should remain encrypted, while protection is temporarily suspended.

Now enter BIOS/UEFI.

Keep:

```text
SVM / AMD-V = Enabled
```

As a troubleshooting test, disable:

```text
Secure Boot
```

Save and reboot.

Verify from PowerShell:

```powershell
Confirm-SecureBootUEFI
```

Expected for this test:

```text
False
```

Check VBS again:

```powershell
Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard |
Format-List VirtualizationBasedSecurityStatus,SecurityServicesConfigured,SecurityServicesRunning
```

Then re-check:

```powershell
Get-CimInstance Win32_ComputerSystem |
Select-Object HypervisorPresent
```

If `False`, skip to **Step 10**.

> Secure Boot is **not universally incompatible with VMware**.
> This is only a troubleshooting branch for systems where VBS refuses to turn off.

---

# Step 9 — Windows 11 24H2 / 25H2: check the Device Guard `WindowsHello` scenario

This was the final missing piece in the tested system.

Check:

```cmd
reg query "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello"
```

If the key does not exist, do not create it just because this guide mentions it.

If it exists and shows:

```text
Enabled    REG_DWORD    0x1
```

and **all previous steps have already been completed but `HypervisorPresent` is still `True`**, you can test disabling this scenario.

### Before changing it

Go to:

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

Do **not** delete your PIN.

Make sure you know the password for your Windows/Microsoft account so you have a fallback sign-in method.

Then open **Command Prompt as Administrator**:

```cmd
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello" /v Enabled /t REG_DWORD /d 0 /f
```

Verify:

```cmd
reg query "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello"
```

Expected:

```text
Enabled    REG_DWORD    0x0
```

Restart Windows.

Now run:

```powershell
Get-CimInstance Win32_ComputerSystem |
Select-Object HypervisorPresent
```

In the tested system, this was the change that finally produced:

```text
HypervisorPresent
-----------------
False
```

---

# Step 10 — Final verification

Run:

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

Instead of:

```text
A hypervisor has been detected.
```

you should see the normal virtualization capability checks, such as:

```text
VM Monitor Mode Extensions: Yes
Virtualization Enabled In Firmware: Yes
Second Level Address Translation: Yes
Data Execution Prevention Available: Yes
```

Optional service check from PowerShell:

```powershell
sc.exe query hvhost
```

On a host where the Microsoft hypervisor is not running, `hvhost` should normally be stopped.

You can also re-check VBS:

```powershell
Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard |
Format-List VirtualizationBasedSecurityStatus,SecurityServicesConfigured,SecurityServicesRunning
```

Expected:

```text
VirtualizationBasedSecurityStatus : 0
SecurityServicesConfigured        : {0}
SecurityServicesRunning           : {0}
```

---

# Step 11 — Enable nested virtualization in VMware

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

The same VMware checkbox is used for AMD-V/RVI.

Start the VM.

The error should no longer appear.

---

# Step 12 — Re-enable BitLocker protection

If you suspended BitLocker:

```cmd
manage-bde -status C:
```

If protection is still suspended:

```cmd
manage-bde -protectors -enable C:
```

Verify:

```cmd
manage-bde -status C:
```

Expected:

```text
Protection Status: Protection On
```

---

# Quick diagnostic script

This repository also includes `diagnose-hypervisor.ps1`.

Run it from an elevated PowerShell window:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\diagnose-hypervisor.ps1
```

It only **reads** system state. It does not modify Windows, the registry, BCD, BitLocker, or firmware.

---

# Why `HypervisorPresent` matters

The most important lesson from this troubleshooting case was:

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

did VMware successfully start the nested PNETLab VM with AMD-V/RVI enabled.

Microsoft documents `Win32_ComputerSystem.HypervisorPresent` as a Boolean indicating whether a hypervisor is present.

---

# Security warning

This guide can involve disabling security features such as:

- Virtualization-Based Security (VBS)
- Memory Integrity / HVCI
- Secure Boot in some troubleshooting cases
- A Windows Hello / Device Guard scenario in a specific edge case

Those changes reduce some Windows security protections.

Do not apply them blindly to corporate, managed, production, or security-sensitive systems.

Use the guide incrementally and **stop as soon as `HypervisorPresent` becomes `False`**.

---

# References

- Microsoft Learn — `Win32_ComputerSystem` / `HypervisorPresent`
- Microsoft Learn — BCDEdit hypervisor launch settings
- Microsoft Learn — BitLocker `manage-bde -protectors`
- Microsoft Learn — Windows Hello Enhanced Sign-in Security
- Broadcom VMware Community — “Virtualized AMD-V/RVI is not supported on this platform”

---

## Contributing

If this guide works on a different AMD CPU, Windows build, laptop model, or VMware Workstation version, please open an Issue or Discussion and include:

```text
CPU:
Windows version/build:
VMware Workstation version:
HypervisorPresent before:
HypervisorPresent after:
Which step fixed it:
```

Please **do not post BitLocker recovery keys, product keys, serial numbers, email addresses, or other sensitive information**.
