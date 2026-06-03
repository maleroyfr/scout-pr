# Microsoft Scout Intune Policy Remediation

This repository provides Intune-ready PowerShell scripts to configure and enforce Microsoft Scout policy settings while native Intune Settings Catalog support is not yet available.

The configuration is based on the Microsoft Scout ADMX policy model, where all settings are machine-level policies stored under:

```text
HKLM\SOFTWARE\Policies\Scout
```

## Purpose

Microsoft Scout policy settings may not be immediately available in the Intune Settings Catalog.

Until native support is available, this repository provides a pragmatic way to manage Microsoft Scout configuration using:

- Intune Remediations
- Intune Platform Scripts
- Manual PowerShell execution for pilot validation

The recommended deployment method is **Intune Remediations**, because it allows continuous compliance detection and automatic correction of configuration drift.

## Repository structure

```text
Microsoft-Scout-Intune-Remediation/
│
├── README.md
├── Detect-MicrosoftScoutPolicy.ps1
└── Remediate-MicrosoftScoutPolicy.ps1
```

## Scripts

| Script | Purpose |
|---|---|
| `Detect-MicrosoftScoutPolicy.ps1` | Detects whether Microsoft Scout policy values are compliant |
| `Remediate-MicrosoftScoutPolicy.ps1` | Creates or updates Microsoft Scout policy registry values |

## Recommended deployment

Use **Intune Remediations** for long-term enforcement.

A simple Intune Platform Script can be used for an initial pilot, but it does not provide the same continuous compliance model.

## Recommended Intune Remediation settings

Go to:

```text
Intune admin center > Devices > Scripts and remediations > Remediations
```

Recommended configuration:

| Setting | Recommended value |
|---|---|
| Run script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | Yes |
| Enforce script signature check | No, unless internally signed |
| Schedule | Daily |
| Assignment | Pilot device group first |

## Default baseline

The default baseline applies the minimum Microsoft Scout policy configuration required for the intended deployment scenario.

Example baseline:

```text
PolicyVersion = 1
AllowScoutFrontierAccess = 1
```

Additional Microsoft Scout policy settings can be added later by updating the desired policy configuration inside the scripts.

## Registry path

All Microsoft Scout policy values are stored under:

```text
HKLM\SOFTWARE\Policies\Scout
```

The scripts must run in the device context, ideally as SYSTEM through Intune.

## Supported policy values

| Value name | Type | Description |
|---|---|---|
| `PolicyVersion` | DWORD | Defines the Microsoft Scout policy version |
| `AllowScoutFrontierAccess` | DWORD | Allows Microsoft Scout Frontier access |
| `ForcePrompt` | DWORD | Forces prompting behavior |
| `RestrictToWorkspace` | DWORD | Restricts Scout to workspace scope |
| `DisableHeartbeat` | DWORD | Disables heartbeat functionality |
| `DisableWorkflows` | DWORD | Disables workflows |
| `DisabledServers` | REG_SZ | Comma-separated list of disabled servers |
| `DisabledPermissions` | REG_SZ | Comma-separated list of disabled permissions |
| `DisabledModels` | REG_SZ | Comma-separated list of disabled models |
| `DisabledProviders` | REG_SZ | Comma-separated list of disabled providers |
| `BrowserEgressBlockedOrigins` | REG_SZ | Comma-separated list of blocked browser egress origins |

## Detection behavior

The detection script checks whether the configured Microsoft Scout policy values are compliant.

| Exit code | Meaning |
|---:|---|
| `0` | Device is compliant |
| `1` | Device is not compliant and remediation is required |

## Remediation behavior

The remediation script creates, updates, or removes Microsoft Scout policy registry values according to the desired configuration.

| Exit code | Meaning |
|---:|---|
| `0` | Remediation completed successfully |
| `1` | Remediation failed |

## Logging

The remediation script writes logs to:

```text
C:\ProgramData\ROXYS\MicrosoftScout\MicrosoftScoutPolicyRemediation.log
```

The log includes:

- Start of remediation
- Registry path creation
- Registry values created or updated
- Registry values removed
- Errors, if any

## Manual testing

Run PowerShell as Administrator.

Detection:

```powershell
.\Detect-MicrosoftScoutPolicy.ps1
```

Remediation:

```powershell
.\Remediate-MicrosoftScoutPolicy.ps1
```

Check registry values:

```powershell
Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Scout"
```

## Intune Platform Script usage

The remediation script can also be deployed as an Intune Platform Script for initial deployment.

Go to:

```text
Intune admin center > Devices > Scripts and remediations > Platform scripts
```

Recommended configuration:

| Setting | Recommended value |
|---|---|
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell host | Yes |
| Enforce script signature check | No, unless internally signed |

This method is useful for pilots or one-time deployment, but Intune Remediations are recommended for ongoing compliance.

## Important notes

- These settings are machine-level policies.
- Scripts should run as SYSTEM or with local administrator rights.
- Use 64-bit PowerShell to avoid registry redirection issues.
- Validate Microsoft Scout behavior in a pilot group before broad deployment.
- Avoid managing the same values through multiple mechanisms at the same time.
- When Microsoft Scout settings become available in the Intune Settings Catalog, consider migrating to native policy management.

## Suggested Intune naming

Detection and remediation package:

```text
WIN - GLB - ALL - Remediation - Microsoft Scout - Policy Baseline
```

Pilot package:

```text
WIN - PILOT - ALL - Remediation - Microsoft Scout - Frontier Access
```

Platform script:

```text
WIN - GLB - ALL - Script - Microsoft Scout - Baseline
```

## Author

Mathieu Leroy  
ROXYS

## Version

```text
1.0.0
```

## License

No license has been defined yet.

Add a license file before public distribution if required.

## Disclaimer

This repository provides helper scripts to manage Microsoft Scout policy registry values through Intune.

Use at your own risk and validate all settings in a pilot group before deploying to production devices.
