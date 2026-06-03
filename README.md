# Microsoft Scout Intune Policy Remediation

This repository provides Intune-ready PowerShell scripts to configure and enforce Microsoft Scout policy settings while native Settings Catalog support is not yet available.

The scripts are based on the Microsoft Scout ADMX policy definition, which stores machine-level settings under:

```text
HKLM\SOFTWARE\Policies\Scout
