#!/usr/bin/env pwsh

[CmdletBinding()]
param(
  [switch]$DryRun,
  [switch]$NonInteractive,
  [switch]$NoOptional,
  [switch]$VerboseMode,
  [string]$Workspace
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:OnboardState = $null

function Write-Info {
  param([string]$Message)
  Write-Output "[INFO] $Message"
}

function Write-Warn {
  param([string]$Message)
  Write-Output "[WARN] $Message"
}

function Write-VerboseMessage {
  param([string]$Message)
  if ($script:OnboardState -and $script:OnboardState.Verbose) {
    Write-Output "[VERBOSE] $Message"
  }
}

function Write-DryRunAction {
  param([string]$Message)
  if ($script:OnboardState -and $script:OnboardState.DryRun) {
    Write-Info "DRY-RUN: $Message"
  }
}

function Initialize-OnboardState {
  param(
    [switch]$DryRunSwitch,
    [switch]$NonInteractiveSwitch,
    [switch]$NoOptionalSwitch,
    [switch]$VerboseSwitch,
    [string]$WorkspacePath
  )

  $defaultWorkspace = if ([string]::IsNullOrWhiteSpace($WorkspacePath)) {
    if ($env:USERPROFILE) {
      Join-Path -Path $env:USERPROFILE -ChildPath 'projects'
    } else {
      'projects'
    }
  } else {
    $WorkspacePath
  }

  $script:OnboardState = [ordered]@{
    DryRun         = $true
    NonInteractive = [bool]$NonInteractiveSwitch
    NoOptional     = [bool]$NoOptionalSwitch
    Verbose        = [bool]$VerboseSwitch
    Workspace      = $defaultWorkspace
  }

  if ($DryRunSwitch) {
    Write-VerboseMessage 'Dry-run parameter supplied; dry-run remains enforced for early iterations.'
  }

  if (-not $DryRunSwitch) {
    Write-VerboseMessage 'Dry-run parameter omitted; dry-run enforced to protect early iterations.'
  }

  if ($script:OnboardState.Verbose) {
    Write-VerboseMessage "Verbose logging enabled."
  }
}

function Show-ExecutionPlan {
  param([string[]]$Steps)

  if (-not $Steps -or $Steps.Count -eq 0) {
    return
  }

  Write-Info 'Execution plan:'
  foreach ($step in $Steps) {
    Write-Output "  - $step"
  }
}

function Get-OptionalFeatureRecord {
  param([string]$FeatureName)

  Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction Stop
}

function Write-OptionalFeatureStatus {
  $features = @(
    [pscustomobject]@{ Name = 'Microsoft-Windows-Subsystem-Linux'; Display = 'Windows Subsystem for Linux' },
    [pscustomobject]@{ Name = 'VirtualMachinePlatform'; Display = 'Virtual Machine Platform' }
  )

  foreach ($feature in $features) {
    try {
      $record = Get-OptionalFeatureRecord -FeatureName $feature.Name
      $state = $record.State

      if ($state -eq 'Enabled') {
        Write-Info "Optional feature '$($feature.Display)' is already enabled."
      } else {
        Write-Warn "Optional feature '$($feature.Display)' is not enabled (state: $state)."
        Write-DryRunAction "Would enable optional feature '$($feature.Name)' using Enable-WindowsOptionalFeature -Online -FeatureName $($feature.Name) -NoRestart."
      }
    } catch {
      Write-Warn "Unable to query optional feature '$($feature.Display)': $($_.Exception.Message)"
    }
  }

  return
}

function Invoke-WslCommand {
  param([string[]]$Arguments)

  & wsl.exe @Arguments
}

function Get-WslDistributionData {
  try {
    $output = Invoke-WslCommand -Arguments @('-l', '-q')
    if (-not $output) {
      return @()
    }

    $trimmed = @()
    foreach ($line in $output) {
      $item = $line.Trim()
      if (-not [string]::IsNullOrWhiteSpace($item)) {
        $trimmed += $item
      }
    }

    return $trimmed
  } catch {
    Write-VerboseMessage "Failed to enumerate WSL distributions: $($_.Exception.Message)"
    return @()
  }
}

function Write-WslDistributionStatus {
  param([string[]]$Distributions)

  if (-not $PSBoundParameters.ContainsKey('Distributions')) {
    $Distributions = @(Get-WslDistributionData)
  } else {
    $Distributions = @($Distributions)
  }

  if ($Distributions.Count -gt 0) {
    Write-Info "Detected WSL distributions: $($Distributions -join ', ')"
  } else {
    Write-Warn 'No WSL distributions are currently registered.'
  }

  return $Distributions
}

function Show-FirstBootGuidance {
  param([string[]]$Distributions)

  $ubuntu = @($Distributions | Where-Object { $_ -like 'Ubuntu*' })

  if ($ubuntu.Count -gt 0) {
    Write-Info 'Ubuntu distribution detected. Launch it at least once to complete first-boot user creation before continuing.'
    Write-Info 'Future iterations will automate the WSL hand-off once installers are wired in.'
  } else {
    Write-Info 'Ubuntu distribution not detected. After enabling optional features, install it with: wsl --install -d Ubuntu'
    Write-Info 'Once installation finishes, launch Ubuntu once to create your Linux user before rerunning this script.'
  }
}

function Invoke-Onboarding {
  param(
    [switch]$DryRun,
    [switch]$NonInteractive,
    [switch]$NoOptional,
    [switch]$VerboseMode,
    [string]$Workspace
  )

  Initialize-OnboardState -DryRunSwitch:$DryRun -NonInteractiveSwitch:$NonInteractive -NoOptionalSwitch:$NoOptional -VerboseSwitch:$VerboseMode -WorkspacePath $Workspace

  $plan = @(
    'Check required Windows optional features for WSL',
    'Detect registered WSL distributions',
    'Outline first-boot guidance for Ubuntu',
    'Keep dry-run guardrails in place (no system changes yet)'
  )

  Show-ExecutionPlan -Steps $plan

  Write-OptionalFeatureStatus
  $distributions = @(Get-WslDistributionData)
  Write-WslDistributionStatus -Distributions $distributions
  Show-FirstBootGuidance -Distributions $distributions

  Write-Info 'Dry-run enforced; Windows installers and configuration changes were skipped.'
}

if ($MyInvocation.InvocationName -ne '.') {
  Invoke-Onboarding @PSBoundParameters
}
