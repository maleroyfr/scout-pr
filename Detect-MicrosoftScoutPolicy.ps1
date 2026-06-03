<#
.SYNOPSIS
    Detects Microsoft Scout policy compliance for Intune Remediations.

.DESCRIPTION
    This script checks whether the expected Microsoft Scout policy registry values
    are present and correctly configured under HKLM\SOFTWARE\Policies\Scout.

    It is designed to be used as the detection script in Microsoft Intune Remediations.

.AUTHOR
    Mathieu Leroy - ROXYS

.VERSION
    1.0.0

.DATE
    2026-06-03

.USAGE
    Intune Remediation detection script:
        - Run using logged-on credentials: No
        - Run script in 64-bit PowerShell: Yes

    Expected exit code:
        0 = Compliant
        1 = Non-compliant

.EXAMPLE
    .\Detect-MicrosoftScoutPolicy.ps1

.NOTES
    Registry path:
        HKLM\SOFTWARE\Policies\Scout
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$RegistrySubKey = "SOFTWARE\Policies\Scout"

# Desired Microsoft Scout policy baseline
# State = Present -> value must exist and match
# State = Absent  -> value must not exist
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
        [Parameter(Mandatory = $false)]
        [Microsoft.Win32.RegistryKey]$Key,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $Key) {
        return $false
    }

    return ($Key.GetValueNames() -contains $Name)
}

$BaseKey = $null
$ScoutKey = $null
$NonCompliantItems = New-Object System.Collections.Generic.List[string]

try {
    $BaseKey = Get-RegistryBaseKey
    $ScoutKey = $BaseKey.OpenSubKey($RegistrySubKey, $false)

    foreach ($Policy in $DesiredScoutPolicy) {
        $Name  = [string]$Policy.Name
        $Type  = [string]$Policy.Type
        $Value = $Policy.Value
        $State = [string]$Policy.State

        if ([string]::IsNullOrWhiteSpace($Name)) {
            $NonCompliantItems.Add("A policy entry has an empty Name.")
            continue
        }

        if ([string]::IsNullOrWhiteSpace($State)) {
            $NonCompliantItems.Add("$Name has an empty State.")
            continue
        }

        $StateUpper = $State.ToUpperInvariant()
        $Exists = Test-RegistryValueExists -Key $ScoutKey -Name $Name

        switch ($StateUpper) {
            "ABSENT" {
                if ($Exists) {
                    $NonCompliantItems.Add("$Name should be absent but exists.")
                }

                continue
            }

            "PRESENT" {
                if (-not $Exists) {
                    $NonCompliantItems.Add("$Name is missing.")
                    continue
                }

                $ExpectedKind = Get-ExpectedRegistryValueKind -Type $Type
                $CurrentKind = $ScoutKey.GetValueKind($Name)

                if ($CurrentKind -ne $ExpectedKind) {
                    $NonCompliantItems.Add("$Name has type [$CurrentKind], expected [$ExpectedKind].")
                    continue
                }

                $CurrentValue = $ScoutKey.GetValue(
                    $Name,
                    $null,
                    [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
                )

                switch ($Type.ToUpperInvariant()) {
                    "DWORD" {
                        if ([int]$CurrentValue -ne [int]$Value) {
                            $NonCompliantItems.Add("$Name expected [$Value], current [$CurrentValue].")
                        }
                    }

                    "STRING" {
                        if ([string]$CurrentValue -ne [string]$Value) {
                            $NonCompliantItems.Add("$Name expected [$Value], current [$CurrentValue].")
                        }
                    }
                }

                continue
            }

            default {
                $NonCompliantItems.Add("$Name has unsupported State [$State]. Use Present or Absent.")
                continue
            }
        }
    }

    if ($NonCompliantItems.Count -gt 0) {
        Write-Output "Microsoft Scout policy is not compliant:"
        foreach ($Item in $NonCompliantItems) {
            Write-Output "- $Item"
        }

        exit 1
    }

    Write-Output "Microsoft Scout policy is compliant."
    exit 0
}
catch {
    Write-Output "Microsoft Scout policy detection failed: $($_.Exception.Message)"
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