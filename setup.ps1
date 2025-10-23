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

  # Detect CI environment
  $isCI = [bool]($env:CI -eq 'true')

  $script:OnboardState = [ordered]@{
    DryRun         = [bool]$DryRunSwitch
    NonInteractive = [bool]$NonInteractiveSwitch
    NoOptional     = [bool]$NoOptionalSwitch
    Verbose        = [bool]$VerboseSwitch
    Workspace      = $defaultWorkspace
    IsCI           = $isCI
  }

  if ($script:OnboardState.Verbose) {
    Write-VerboseMessage "Verbose logging enabled."
    if ($isCI) {
      Write-VerboseMessage "CI environment detected."
    }
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
        Write-DryRunAction "Would enable optional feature '$($feature.Name)' using dism.exe."
      }
    } catch {
      Write-Warn "Unable to query optional feature '$($feature.Display)': $($_.Exception.Message)"
    }
  }

  return
}

function Enable-WslFeatures {
  Write-Info 'Enabling WSL and Virtual Machine Platform...'

  if ($script:OnboardState.DryRun) {
    Write-DryRunAction 'Would run: dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart'
    Write-DryRunAction 'Would run: dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart'
    return
  }

  try {
    $result1 = & dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    Write-VerboseMessage "dism.exe WSL output: $($result1 -join ' ')"

    $result2 = & dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    Write-VerboseMessage "dism.exe VirtualMachinePlatform output: $($result2 -join ' ')"

    Write-Info 'WSL and Virtual Machine Platform features enabled successfully.'
  } catch {
    throw "Failed to enable WSL features: $($_.Exception.Message)"
  }
}

function Update-WslComponents {
  Write-Info 'Updating WSL components...'

  if ($script:OnboardState.DryRun) {
    Write-DryRunAction 'Would run: wsl --update'
    Write-DryRunAction 'Would run: wsl --set-default-version 2'
    return
  }

  try {
    $updateResult = & wsl.exe --update 2>&1
    Write-VerboseMessage "wsl --update output: $($updateResult -join ' ')"

    $versionResult = & wsl.exe --set-default-version 2 2>&1
    Write-VerboseMessage "wsl --set-default-version output: $($versionResult -join ' ')"

    Write-Info 'WSL components updated successfully.'
  } catch {
    throw "Failed to update WSL components: $($_.Exception.Message)"
  }
}

function Install-UbuntuDistribution {
  Write-Info 'Installing Ubuntu-22.04...'

  if ($script:OnboardState.DryRun) {
    Write-DryRunAction 'Would run: wsl --install -d Ubuntu-22.04 --no-launch'
    return
  }

  try {
    $installResult = & wsl.exe --install -d Ubuntu-22.04 --no-launch 2>&1
    Write-VerboseMessage "wsl --install output: $($installResult -join ' ')"

    Write-Info 'Ubuntu-22.04 installed successfully.'
  } catch {
    throw "Failed to install Ubuntu-22.04: $($_.Exception.Message)"
  }
}

function Install-GitForWindows {
  Write-Info 'Installing Git for Windows via winget...'

  if ($script:OnboardState.DryRun) {
    Write-DryRunAction 'Would run: winget install --id Git.Git -e --source winget'
    return
  }

  try {
    $wingetResult = & winget install --id Git.Git -e --source winget 2>&1
    Write-VerboseMessage "winget install Git output: $($wingetResult -join ' ')"

    Write-Info 'Git for Windows installed successfully.'
  } catch {
    throw "Failed to install Git for Windows: $($_.Exception.Message)"
  }
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
    'Enable WSL and Virtual Machine Platform features',
    'Update WSL components and set default version to 2',
    'Install Ubuntu-22.04 distribution',
    'Install Git for Windows',
    'Detect registered WSL distributions',
    'Outline first-boot guidance for Ubuntu'
  )

  Show-ExecutionPlan -Steps $plan

  # Query feature status before making changes
  Write-OptionalFeatureStatus

  # Enable WSL features (idempotent)
  Enable-WslFeatures

  # Update WSL components
  Update-WslComponents

  # Install Ubuntu distribution
  Install-UbuntuDistribution

  # Install Git for Windows
  Install-GitForWindows

  # Check what distributions are registered
  $distributions = @(Get-WslDistributionData)
  Write-WslDistributionStatus -Distributions $distributions
  Show-FirstBootGuidance -Distributions $distributions

  if ($script:OnboardState.DryRun) {
    Write-Info 'Dry-run mode: no system changes were made.'
  } else {
    Write-Info 'Windows setup complete. WSL features enabled, Ubuntu installed, Git for Windows installed.'
  }
}

if ($MyInvocation.InvocationName -ne '.') {
  Invoke-Onboarding @PSBoundParameters
}
