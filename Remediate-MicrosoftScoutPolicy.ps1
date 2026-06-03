<#
.SYNOPSIS
    Remediates Microsoft Scout policy settings for Intune-managed Windows devices.

.DESCRIPTION
    This script creates, updates, or removes Microsoft Scout policy registry values
    under HKLM\SOFTWARE\Policies\Scout.

    It is designed to be used as the remediation script in Microsoft Intune Remediations,
    or as a one-time Intune Platform Script during pilot deployment.

.AUTHOR
    Mathieu Leroy - ROXYS

.VERSION
    1.0.0

.DATE
    2026-06-03

.USAGE
    Intune Remediation remediation script:
        - Run using logged-on credentials: No
        - Run script in 64-bit PowerShell: Yes

    Intune Platform Script:
        - Can be used for initial deployment
        - Not recommended as the only long-term enforcement mechanism

    Expected exit code:
        0 = Remediation successful
        1 = Remediation failed

.EXAMPLE
    .\Remediate-MicrosoftScoutPolicy.ps1

.LOGGING
    Log file:
        C:\ProgramData\ROXYS\MicrosoftScout\MicrosoftScoutPolicyRemediation.log

.NOTES
    Registry path:
        HKLM\SOFTWARE\Policies\Scout
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$RegistrySubKey = "SOFTWARE\Policies\Scout"
$LogFolder = "C:\ProgramData\ROXYS\MicrosoftScout"
$LogFile = Join-Path -Path $LogFolder -ChildPath "MicrosoftScoutPolicyRemediation.log"

# Desired Microsoft Scout policy baseline
# State = Present -> create or update value
# State = Absent  -> remove value if present
$DesiredScoutPolicy = @(
    @{
        Name  = "PolicyVersion"
        Type  = "DWord"
        Value = 1
        State = "Present"
    },
    @{
        Name  = "AllowScoutFrontierAccess"
        Type  = "DWord"
        Value = 1
        State = "Present"
    }

    # Optional examples - uncomment and adapt when required

    # @{
    #     Name  = "ForcePrompt"
    #     Type  = "DWord"
    #     Value = 1
    #     State = "Present"
    # },
    # @{
    #     Name  = "RestrictToWorkspace"
    #     Type  = "DWord"
    #     Value = 1
    #     State = "Present"
    # },
    # @{
    #     Name  = "DisableHeartbeat"
    #     Type  = "DWord"
    #     Value = 0
    #     State = "Present"
    # },
    # @{
    #     Name  = "DisableWorkflows"
    #     Type  = "DWord"
    #     Value = 0
    #     State = "Present"
    # },
    # @{
    #     Name  = "DisabledServers"
    #     Type  = "String"
    #     Value = "server1,server2"
    #     State = "Present"
    # },
    # @{
    #     Name  = "DisabledPermissions"
    #     Type  = "String"
    #     Value = "permission1,permission2"
    #     State = "Present"
    # },
    # @{
    #     Name  = "DisabledModels"
    #     Type  = "String"
    #     Value = "model1,model2"
    #     State = "Present"
    # },
    # @{
    #     Name  = "DisabledProviders"
    #     Type  = "String"
    #     Value = "provider1,provider2"
    #     State = "Present"
    # },
    # @{
    #     Name  = "BrowserEgressBlockedOrigins"
    #     Type  = "String"
    #     Value = "example.com,contoso.com"
    #     State = "Present"
    # }
)

function Initialize-LogFolder {
    if (-not (Test-Path -Path $LogFolder)) {
        New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
    }
}

function Write-Log {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Line = "$Timestamp - $Message"

    Write-Output $Line
    Add-Content -Path $LogFile -Value $Line -Encoding UTF8
}

function Get-RegistryBaseKey {
    try {
        return [Microsoft.Win32.RegistryKey]::OpenBaseKey(
            [Microsoft.Win32.RegistryHive]::LocalMachine,
            [Microsoft.Win32.RegistryView]::Registry64
        )
    }
    catch {
        return [Microsoft.Win32.RegistryKey]::OpenBaseKey(
            [Microsoft.Win32.RegistryHive]::LocalMachine,
            [Microsoft.Win32.RegistryView]::Default
        )
    }
}

function Get-ExpectedRegistryValueKind {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Type
    )

    switch ($Type.ToUpperInvariant()) {
        "DWORD" {
            return [Microsoft.Win32.RegistryValueKind]::DWord
        }

        "STRING" {
            return [Microsoft.Win32.RegistryValueKind]::String
        }

        default {
            throw "Unsupported registry value type: $Type"
        }
    }
}

function Test-RegistryValueExists {
    param (
        [Parameter(Mandatory = $true)]
        [Microsoft.Win32.RegistryKey]$Key,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return ($Key.GetValueNames() -contains $Name)
}

$BaseKey = $null
$ScoutKey = $null

try {
    Initialize-LogFolder

    Write-Log "Starting Microsoft Scout policy remediation."
    Write-Log "Target registry key: HKLM\$RegistrySubKey"

    $BaseKey = Get-RegistryBaseKey
    $ScoutKey = $BaseKey.CreateSubKey($RegistrySubKey)

    if ($null -eq $ScoutKey) {
        throw "Unable to create or open HKLM\$RegistrySubKey"
    }

    foreach ($Policy in $DesiredScoutPolicy) {
        $Name  = [string]$Policy.Name
        $Type  = [string]$Policy.Type
        $Value = $Policy.Value
        $State = [string]$Policy.State

        if ([string]::IsNullOrWhiteSpace($Name)) {
            throw "A policy entry has an empty Name."
        }

        if ([string]::IsNullOrWhiteSpace($State)) {
            throw "$Name has an empty State."
        }

        $StateUpper = $State.ToUpperInvariant()

        switch ($StateUpper) {
            "ABSENT" {
                if (Test-RegistryValueExists -Key $ScoutKey -Name $Name) {
                    Write-Log "Removing value: $Name"
                    $ScoutKey.DeleteValue($Name, $false)
                }
                else {
                    Write-Log "Value already absent: $Name"
                }

                continue
            }

            "PRESENT" {
                $ExpectedKind = Get-ExpectedRegistryValueKind -Type $Type

                switch ($Type.ToUpperInvariant()) {
                    "DWORD" {
                        $ValueToWrite = [int]$Value
                    }

                    "STRING" {
                        $ValueToWrite = [string]$Value
                    }

                    default {
                        throw "Unsupported registry value type: $Type"
                    }
                }

                Write-Log "Setting value: $Name = $ValueToWrite [$ExpectedKind]"
                $ScoutKey.SetValue($Name, $ValueToWrite, $ExpectedKind)

                continue
            }

            default {
                throw "$Name has unsupported State [$State]. Use Present or Absent."
            }
        }
    }

    $ScoutKey.Flush()

    Write-Log "Microsoft Scout policy remediation completed successfully."
    exit 0
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}
finally {
    if ($null -ne $ScoutKey) {
        $ScoutKey.Close()
    }

    if ($null -ne $BaseKey) {
        $BaseKey.Close()
    }
}