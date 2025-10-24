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

function Enable-WslFeature {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param()

  Write-Info 'Enabling WSL and Virtual Machine Platform...'

  if ($script:OnboardState.DryRun) {
    Write-DryRunAction 'Would run: dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart'
    Write-DryRunAction 'Would run: dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart'
    return
  }

  if (-not $PSCmdlet.ShouldProcess('Windows optional features for WSL', 'Enable required optional features')) {
    Write-VerboseMessage 'Enable-WslFeature skipped by ShouldProcess.'
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

function Update-WslComponent {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param()

  Write-Info 'Updating WSL components...'

  if ($script:OnboardState.DryRun) {
    Write-DryRunAction 'Would run: wsl --update'
    Write-DryRunAction 'Would run: wsl --set-default-version 2'
    return
  }

  if (-not $PSCmdlet.ShouldProcess('WSL components', 'Update WSL and configure default version')) {
    Write-VerboseMessage 'Update-WslComponent skipped by ShouldProcess.'
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

function Import-UbuntuDistributionFromAppx {
  param(
    [string]$DistributionName = 'Ubuntu-22.04'
  )

  $downloadUrl = 'https://aka.ms/wslubuntu2204'
  $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'project-onboard-ubuntu-2204'
  $appxPath = Join-Path -Path $tempRoot -ChildPath 'ubuntu-2204.appx'
  $extractPath = Join-Path -Path $tempRoot -ChildPath 'extracted'
  $installLocation = Join-Path -Path 'C:\wsl' -ChildPath $DistributionName

  Write-Info 'Attempting manual Ubuntu import using official rootfs package...'
  Write-VerboseMessage "Ubuntu manual import temp directory: $tempRoot"

  if ($script:OnboardState.DryRun) {
    Write-DryRunAction "Would download Ubuntu rootfs from $downloadUrl"
    Write-DryRunAction "Would extract appx to $extractPath and import into $installLocation via wsl --import"
    return
  }

  try {
    if (Test-Path $tempRoot) {
      Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction Stop
    }

    New-Item -Path $tempRoot -ItemType Directory -Force | Out-Null

    Write-Info 'Downloading Ubuntu rootfs package...'
  Invoke-WebRequest -Uri $downloadUrl -OutFile $appxPath -ErrorAction Stop

    Write-VerboseMessage "Downloaded appx to $appxPath"

    Write-Info 'Expanding Ubuntu package contents...'
    Expand-Archive -Path $appxPath -DestinationPath $extractPath -Force

    $tarGzItem = Get-ChildItem -Path $extractPath -Filter 'install.tar.gz' -Recurse | Select-Object -First 1
    if (-not $tarGzItem) {
      throw 'Unable to locate install.tar.gz inside the downloaded Ubuntu package.'
    }

    Write-VerboseMessage "Found install.tar.gz at $($tarGzItem.FullName)"

    if (Test-Path $installLocation) {
      Write-VerboseMessage "Removing existing install directory at $installLocation"
      Remove-Item -Path $installLocation -Recurse -Force -ErrorAction Stop
    }

    $installRoot = Split-Path -Path $installLocation -Parent
    if (-not (Test-Path $installRoot)) {
      Write-VerboseMessage "Creating WSL install root at $installRoot"
      New-Item -Path $installRoot -ItemType Directory -Force | Out-Null
    }

    New-Item -Path $installLocation -ItemType Directory -Force | Out-Null

    Write-Info 'Importing Ubuntu distribution via wsl --import...'
    $importArgs = @('--import', $DistributionName, $installLocation, $tarGzItem.FullName, '--version', '2')
    $importResult = & wsl.exe @importArgs 2>&1
    $importExitCode = $LASTEXITCODE
    Write-VerboseMessage "wsl --import output: $($importResult -join ' ')"

    if ($importExitCode -ne 0) {
      throw "wsl --import exited with code $importExitCode"
    }

    Write-Info 'Setting Ubuntu-22.04 as the default WSL distribution...'
    $setDefaultResult = & wsl.exe --set-default $DistributionName 2>&1
    $setDefaultExit = $LASTEXITCODE
    Write-VerboseMessage "wsl --set-default output: $($setDefaultResult -join ' ')"

    if ($setDefaultExit -ne 0) {
      throw "wsl --set-default exited with code $setDefaultExit"
    }

    Write-Info 'Ubuntu distribution imported successfully.'
  } catch {
    throw "Manual import of Ubuntu distribution failed: $($_.Exception.Message)"
  } finally {
    try {
      if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force
      }
    } catch {
      Write-VerboseMessage "Cleanup of temp directory $tempRoot failed: $($_.Exception.Message)"
    }
  }
}

function Install-UbuntuDistribution {
  Write-Info 'Ensuring Ubuntu-22.04 distribution is installed...'

  $existingDistros = @(Get-WslDistributionData)
  if ($existingDistros -contains 'Ubuntu-22.04') {
    Write-Info 'Ubuntu-22.04 is already registered. Skipping installation.'
    return
  }

  if ($script:OnboardState.DryRun) {
    Write-DryRunAction 'Would install Ubuntu-22.04 via wsl --install and fall back to manual import if needed'
    return
  }

  try {
    Write-Info 'Attempting installation via wsl --install...'
    $installArgs = @('--install', '-d', 'Ubuntu-22.04', '--no-launch')
    $installOutput = & wsl.exe @installArgs 2>&1
    $installExitCode = $LASTEXITCODE
    Write-VerboseMessage "wsl --install output: $($installOutput -join ' ')"
    Write-VerboseMessage "wsl --install exit code: $installExitCode"

    if ($installExitCode -ne 0) {
      Write-Warn "wsl --install exited with code $installExitCode. Will attempt manual import."
    } else {
      Start-Sleep -Seconds 5
    }

    $existingDistros = @(Get-WslDistributionData)
    if ($existingDistros -contains 'Ubuntu-22.04') {
      Write-Info 'Ubuntu distribution detected after wsl --install.'
      return
    }

    Write-Warn 'Ubuntu distribution not detected after wsl --install. Falling back to manual import.'
    Import-UbuntuDistributionFromAppx -DistributionName 'Ubuntu-22.04'

    $existingDistros = @(Get-WslDistributionData)
    if (-not ($existingDistros -contains 'Ubuntu-22.04')) {
      throw 'Ubuntu distribution is still not registered after manual import attempt.'
    }

    Write-Info 'Ubuntu distribution registered successfully after manual import.'

    Write-VerboseMessage 'Verifying distribution registration with wsl -l -v'
    $verifyResult = & wsl.exe -l -v 2>&1
    Write-VerboseMessage "wsl -l -v output: $($verifyResult -join "`n")"
  } catch {
    throw "Failed to install Ubuntu: $($_.Exception.Message)"
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

function Install-DockerDesktop {
  Write-Info 'Installing Docker Desktop via winget...'

  if ($script:OnboardState.DryRun) {
    Write-DryRunAction 'Would run: winget install --id Docker.DockerDesktop -e --source winget'
    return
  }

  try {
    $wingetResult = & winget install --id Docker.DockerDesktop -e --source winget 2>&1
    Write-VerboseMessage "winget install Docker Desktop output: $($wingetResult -join ' ')"
    Write-Info 'Docker Desktop installed successfully.'
  } catch {
    throw "Failed to install Docker Desktop: $($_.Exception.Message)"
  }
}

function Show-DockerDesktopGuidance {
  Write-Info ''
  Write-Info '==========================================='
  Write-Info 'Docker Desktop Manual Configuration'
  Write-Info '==========================================='
  Write-Info 'Docker Desktop is installed. You must NOW manually:'
  Write-Info '  1. Start Docker Desktop from the Start Menu.'
  Write-Info '  2. Accept the terms of service.'
  Write-Info '  3. In Docker Desktop Settings > Resources > WSL Integration,'
  Write-Info '     enable integration for ''Ubuntu-22.04''.'
  Write-Info '  4. Click ''Apply & Restart''.'
  Write-Info '==========================================='
  Write-Info ''

  if ($script:OnboardState.DryRun -or $script:OnboardState.NonInteractive) {
    Write-Warn 'Dry-run or non-interactive mode: Skipping Docker Desktop confirmation prompt.'
  } else {
    Read-Host 'Press ENTER to continue once Docker Desktop is running and WSL integration is enabled'
  }
}

function Invoke-GitCredentialManagerAuth {
  Write-Info ''
  Write-Info '==========================================='
  Write-Info 'Git Credential Manager Authentication'
  Write-Info '==========================================='
  Write-Info 'We will now authenticate Git with GitHub. A browser window will open...'
  Write-Info '==========================================='
  Write-Info ''

  $gcmPath = 'C:\Program Files\Git\mingw64\bin\git-credential-manager.exe'

  if ($script:OnboardState.DryRun) {
    Write-DryRunAction "Would run: & '$gcmPath' configure"
    Write-DryRunAction "Would trigger browser authentication for GitHub"
    return
  }

  if (-not (Test-Path $gcmPath)) {
    Write-Warn "Git Credential Manager not found at expected path: $gcmPath"
    Write-Warn 'Skipping GCM authentication. Please ensure Git for Windows is installed correctly.'
    return
  }

  try {
    # Configure GCM
    $configResult = & $gcmPath configure 2>&1
    Write-VerboseMessage "GCM configure output: $($configResult -join ' ')"

    # Trigger authentication (this will open browser)
    Write-Info 'Triggering GitHub authentication...'
    $authInput = "protocol=https`nhost=github.com`n`n"
    $authResult = $authInput | & $gcmPath get 2>&1
    Write-VerboseMessage "GCM get output: $($authResult -join ' ')"

    Write-Info 'Git Credential Manager authentication initiated.'
  } catch {
    Write-Warn "GCM authentication encountered an issue: $($_.Exception.Message)"
    Write-Info 'You may need to authenticate manually later.'
  }

  if (-not $script:OnboardState.NonInteractive) {
    Read-Host 'Press ENTER to continue once you have successfully logged in via your browser'
  } else {
    Write-Warn 'Non-interactive mode: Skipping authentication confirmation prompt.'
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

function Invoke-WslFirstBootSetup {
  <#
  .SYNOPSIS
    Check if WSL user exists and guide through first-boot setup if needed.
  #>

  Write-Info ''
  Write-Info '========== WSL First-Boot User Setup =========='
  Write-Info ''

  if ($script:OnboardState.DryRun) {
    Write-DryRunAction 'Would check WSL user existence with: wsl -e id -u'
    Write-DryRunAction 'Would launch interactive WSL setup if needed: Start-Process wsl.exe'
    return
  }

  # Try to run id -u inside WSL to check if a user exists
  $wslUserCheck = $null
  try {
    $wslUserCheck = wsl -e id -u 2>&1
    $wslUserExists = $LASTEXITCODE -eq 0
  } catch {
    $wslUserExists = $false
  }

  if (-not $wslUserExists) {
    Write-Info 'WSL is installed but needs its initial user setup.'
    Write-Info 'A new Ubuntu terminal will open. Please create your default username and password.'
    Write-Info 'When complete, close the Ubuntu window and return here.'
    Write-Info ''

    # Launch WSL interactively
    Start-Process 'wsl.exe' -Wait:$false

    Write-Info 'Waiting for WSL user creation...'
    Read-Host 'Press ENTER to continue once your WSL user is created and the Ubuntu window is closed'
  } else {
    Write-Info "WSL user already exists (UID: $wslUserCheck). Skipping first-boot setup."
  }

  Write-Info ''
  Write-Info '========== WSL First-Boot Complete =========='
  Write-Info ''
}

function Invoke-WslHandoff {
  <#
  .SYNOPSIS
    Hand off to setup.sh inside WSL with flag passthrough.
  #>

  Write-Info ''
  Write-Info '========== Handing off to setup.sh inside WSL =========='
  Write-Info ''

  # Build flag string for setup.sh
  $wslFlags = ''
  if ($script:OnboardState.NonInteractive) {
    $wslFlags += ' --non-interactive'
  }
  if ($script:OnboardState.Verbose) {
    $wslFlags += ' --verbose'
  }
  if ($script:OnboardState.NoOptional) {
    $wslFlags += ' --no-optional'
  }
  if ($script:OnboardState.Workspace) {
    $wslFlags += " --workspace $($script:OnboardState.Workspace)"
  }

  $setupUrl = 'https://raw.githubusercontent.com/kevinaud/project-onboard/main/setup.sh'
  $handoffCommand = "curl -fsSL $setupUrl | bash -s -- $wslFlags"

  Write-Info "Executing: wsl -e bash -lc `"$handoffCommand`""

  if ($script:OnboardState.DryRun) {
    Write-DryRunAction "Would execute: wsl -e bash -lc `"$handoffCommand`""
    return
  }

  try {
    wsl -e bash -lc $handoffCommand
    if ($LASTEXITCODE -ne 0) {
      Write-Warn "setup.sh exited with code $LASTEXITCODE"
    }
  } catch {
    Write-Warn "Failed to execute setup.sh inside WSL: $_"
  }

  Write-Info ''
  Write-Info '========== WSL Handoff Complete =========='
  Write-Info ''
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
    'Install Git for Windows'
  )

  # Add manual-only steps to plan if not in CI
  if (-not $script:OnboardState.IsCI) {
    $plan += 'Install Docker Desktop (manual only)'
    $plan += 'Configure Docker Desktop WSL integration (manual guidance)'
    $plan += 'Authenticate Git Credential Manager with GitHub (manual only)'
    $plan += 'Verify WSL user setup and guide through first-boot if needed'
  }

  $plan += @(
    'Detect registered WSL distributions',
    'Hand off to setup.sh inside WSL for platform-specific configuration'
  )

  Show-ExecutionPlan -Steps $plan

  # Query feature status before making changes
  Write-OptionalFeatureStatus

  # Enable WSL features (idempotent)
  Enable-WslFeature

  # Update WSL components
  Update-WslComponent

  # Install Ubuntu distribution
  Install-UbuntuDistribution

  # Install Git for Windows
  Install-GitForWindows

  # Manual-only block: Docker Desktop and GCM authentication
  if (-not $script:OnboardState.IsCI) {
    Write-Info ''
    Write-Info '========== Manual Configuration Steps =========='
    Write-Info ''

    # Install Docker Desktop
    Install-DockerDesktop

    # Guide user through Docker Desktop setup
    Show-DockerDesktopGuidance

    # Authenticate with GitHub using GCM
    Invoke-GitCredentialManagerAuth

    Write-Info ''
    Write-Info '========== Manual Configuration Complete =========='
    Write-Info ''
  } else {
    Write-Info 'CI mode detected: Skipping manual-only steps (Docker Desktop, GCM authentication).'
  }

  # Check what distributions are registered
  $distributions = @(Get-WslDistributionData)
  Write-WslDistributionStatus -Distributions $distributions

  # Manual-only: WSL first-boot user creation
  if (-not $script:OnboardState.IsCI) {
    Invoke-WslFirstBootSetup
  }

  # Handoff to setup.sh inside WSL (manual mode only)
  # In CI mode, the GitHub Actions workflow handles all subsequent steps
  if (-not $script:OnboardState.IsCI) {
    Invoke-WslHandoff
  } else {
    Write-Info 'CI mode: Skipping setup.sh handoff. The GitHub Actions workflow will handle subsequent steps.'
  }

  if ($script:OnboardState.DryRun) {
    Write-Info 'Dry-run mode: no system changes were made.'
  } else {
    if ($script:OnboardState.IsCI) {
      Write-Info 'Windows setup complete (CI mode). WSL features enabled, Ubuntu installed, Git for Windows installed.'
    } else {
      Write-Info 'Windows setup complete. WSL, Ubuntu, Git for Windows, Docker Desktop installed and configured.'
    }
  }
}

if ($MyInvocation.InvocationName -ne '.') {
  Invoke-Onboarding @PSBoundParameters
}
