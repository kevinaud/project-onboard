#!/usr/bin/env pwsh

[CmdletBinding()]
param(
  [switch]$DryRun,
  [switch]$NonInteractive,
  [switch]$NoOptional,
  [switch]$VerboseMode,
  [string]$Workspace,
  [string]$Branch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:IsDotSourced = $MyInvocation.InvocationName -eq '.'
$script:ProjectOnboardScriptPath = $PSCommandPath

$script:ScriptBoundParameters = @{}
if ($PSBoundParameters) {
  foreach ($entry in $PSBoundParameters.GetEnumerator()) {
    $script:ScriptBoundParameters[$entry.Key] = $entry.Value
  }
}
if (-not $script:ScriptBoundParameters.ContainsKey('Branch') -and -not [string]::IsNullOrWhiteSpace($env:PROJECT_ONBOARD_BRANCH)) {
  $script:ScriptBoundParameters['Branch'] = $env:PROJECT_ONBOARD_BRANCH
}

$script:OnboardState = $null

function Ensure-ExecutionPolicyRelaxed {
  if ($env:PROJECT_ONBOARD_EXECUTION_POLICY_ESCALATED -eq '1') {
    Remove-Item Env:PROJECT_ONBOARD_EXECUTION_POLICY_ESCALATED -ErrorAction SilentlyContinue
    return
  }

  if ($script:IsDotSourced) {
    return
  }

  $scriptPath = $script:ProjectOnboardScriptPath
  if (-not $scriptPath) {
    return
  }

  try {
    $effectivePolicy = Get-ExecutionPolicy -Scope Process
  } catch {
    return
  }

  if ($effectivePolicy -in @('Bypass', 'RemoteSigned')) {
    return
  }

  Set-Item -Path Env:PROJECT_ONBOARD_EXECUTION_POLICY_ESCALATED -Value '1'

  $argumentList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath)

  foreach ($entry in $script:ScriptBoundParameters.GetEnumerator()) {
    $name = "-{0}" -f $entry.Key
    $value = $entry.Value

    if ($value -is [System.Management.Automation.SwitchParameter]) {
      if ($value.IsPresent) {
        $argumentList += $name
      }
      continue
    }

    if ($null -ne $value) {
      $argumentList += $name
      $argumentList += [string]$value
    }
  }

  & powershell.exe @argumentList
  $exitCode = $LASTEXITCODE
  exit $exitCode
}

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

function Remove-JsonComments {
  param([string]$Content)

  if ([string]::IsNullOrWhiteSpace($Content)) {
    return $Content
  }

  $pattern = '(?s)//.*?$|/\*.*?\*/'
  return [System.Text.RegularExpressions.Regex]::Replace($Content, $pattern, [string]::Empty)
}

function ConvertTo-Hashtable {
  param([psobject]$Object)

  $result = @{}
  if ($null -eq $Object) {
    return $result
  }

  if ($Object -is [hashtable]) {
    return $Object
  }

  foreach ($property in $Object.PSObject.Properties) {
    $result[$property.Name] = $property.Value
  }

  return $result
}

function Convert-WorkspacePathForWsl {
  param([string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path)) {
    return $Path
  }

  if ($Path.StartsWith('/')) {
    return $Path
  }

  if ($Path -match '^[A-Za-z]:[\\/].*') {
    $driveLetter = $Path.Substring(0, 1).ToLowerInvariant()
    $remaining = $Path.Substring(2)
    $remaining = $remaining.TrimStart('\\', '/')
    $remaining = $remaining -replace '\\', '/'
    return "/mnt/$driveLetter/$remaining"
  }

  return $Path
}

function Convert-ToBashArgument {
  param([string]$Value)

  if ($null -eq $Value) {
    return "''"
  }

  $escaped = $Value -replace "'", "'\"'\"'"
  return "'$escaped'"
}

function Get-VSCodeSettingsPath {
  if (-not $env:APPDATA) {
    return $null
  }

  return Join-Path -Path $env:APPDATA -ChildPath 'Code\User\settings.json'
}

function Ensure-VSCodeDotfileSettings {
  param([string]$SettingsPath)

  $defaults = [ordered]@{
    'dotfiles.repository'     = 'kevinaud/dotfiles'
    'dotfiles.targetPath'     = '~/dotfiles'
    'dotfiles.installCommand' = 'install.sh'
  }

  if (-not $PSBoundParameters.ContainsKey('SettingsPath')) {
    $SettingsPath = Get-VSCodeSettingsPath
  }

  if ([string]::IsNullOrWhiteSpace($SettingsPath)) {
    Write-Warn 'Unable to determine VS Code settings path; skipping dotfiles configuration.'
    return
  }

  if ($script:OnboardState.DryRun) {
    Write-DryRunAction "Ensure VS Code settings at $SettingsPath configure kevinaud/dotfiles as the dev container dotfiles repository."
    return
  }

  $settings = @{}

  try {
    if (Test-Path -Path $SettingsPath) {
      $raw = Get-Content -Path $SettingsPath -Raw -ErrorAction Stop
      if (-not [string]::IsNullOrWhiteSpace($raw)) {
        try {
          $settings = ConvertTo-Hashtable (ConvertFrom-Json -InputObject $raw -ErrorAction Stop)
        } catch {
          $stripped = Remove-JsonComments -Content $raw
          $settings = ConvertTo-Hashtable (ConvertFrom-Json -InputObject $stripped -ErrorAction Stop)
        }
      }
    }
  } catch {
    Write-Warn "Failed to read existing VS Code settings at ${SettingsPath}: $($_.Exception.Message)"
    $settings = @{}
  }

  $changed = $false
  foreach ($key in $defaults.Keys) {
    if (-not $settings.ContainsKey($key)) {
      $settings[$key] = $defaults[$key]
      $changed = $true
    }
  }

  if (-not $changed) {
    Write-Info 'VS Code settings already specify kevinaud/dotfiles for dev container configuration.'
    return
  }

  try {
    $settingsDirectory = Split-Path -Path $SettingsPath -Parent
    if (-not (Test-Path -Path $settingsDirectory)) {
      New-Item -Path $settingsDirectory -ItemType Directory -Force | Out-Null
    }

    $json = ($settings | ConvertTo-Json -Depth 8)
    Set-Content -Path $SettingsPath -Value ($json + [Environment]::NewLine)
    Write-Info "Updated VS Code settings at ${SettingsPath} to configure kevinaud/dotfiles."
  } catch {
    Write-Warn "Failed to update VS Code settings at ${SettingsPath}: $($_.Exception.Message)"
  }
}

function Get-VSCodeCliCommand {
  $command = Get-Command -Name code -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Path
  }

  $defaultPath = Join-Path -Path $env:ProgramFiles -ChildPath 'Microsoft VS Code\bin\code.cmd'
  if ($defaultPath -and (Test-Path -Path $defaultPath)) {
    return $defaultPath
  }

  $userInstallPath = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Programs\Microsoft VS Code\bin\code.cmd'
  if ($userInstallPath -and (Test-Path -Path $userInstallPath)) {
    return $userInstallPath
  }

  return $null
}

function Ensure-VSCodeInstalled {
  Write-Info 'Ensuring Visual Studio Code is installed...'

  $existingCli = Get-VSCodeCliCommand
  if ($existingCli) {
    Write-VerboseMessage "Detected VS Code CLI at $existingCli."
    return
  }

  if ($script:OnboardState.DryRun) {
    Write-DryRunAction 'Would run: winget install --id Microsoft.VisualStudioCode -e --source winget'
    return
  }

  try {
    $wingetResult = & winget install --id Microsoft.VisualStudioCode -e --source winget 2>&1
    Write-VerboseMessage "winget install Visual Studio Code output: $($wingetResult -join ' ')"
  } catch {
    throw "Failed to install Visual Studio Code: $($_.Exception.Message)"
  }
}

function Ensure-VSCodeRemoteExtensionPack {
  Write-Info 'Ensuring VS Code Remote Development extension pack is installed...'

  $codeCli = Get-VSCodeCliCommand

  if (-not $codeCli) {
    if ($script:OnboardState.DryRun) {
      Write-DryRunAction 'Would run: code --install-extension ms-vscode-remote.vscode-remote-extensionpack --force'
    } else {
      Write-Warn 'Visual Studio Code CLI not found. Skipping extension installation.'
    }
    return
  }

  if ($script:OnboardState.DryRun) {
    Write-DryRunAction "Would run: $codeCli --install-extension ms-vscode-remote.vscode-remote-extensionpack --force"
    return
  }

  try {
    $extensionResult = & $codeCli --install-extension ms-vscode-remote.vscode-remote-extensionpack --force 2>&1
    Write-VerboseMessage "code --install-extension output: $($extensionResult -join ' ')"
  } catch {
    Write-Warn "Failed to install VS Code Remote Development extension pack: $($_.Exception.Message)"
  }
}

function Initialize-OnboardState {
  param(
    [switch]$DryRunSwitch,
    [switch]$NonInteractiveSwitch,
    [switch]$NoOptionalSwitch,
    [switch]$VerboseSwitch,
    [string]$WorkspacePath,
    [string]$BranchName
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

  $branchValue = if ([string]::IsNullOrWhiteSpace($BranchName)) {
    if ([string]::IsNullOrWhiteSpace($env:PROJECT_ONBOARD_BRANCH)) {
      'main'
    } else {
      $env:PROJECT_ONBOARD_BRANCH
    }
  } else {
    $BranchName
  }

  $script:OnboardState = [ordered]@{
    DryRun         = [bool]$DryRunSwitch
    NonInteractive = [bool]$NonInteractiveSwitch
    NoOptional     = [bool]$NoOptionalSwitch
    Verbose        = [bool]$VerboseSwitch
    Workspace      = $defaultWorkspace
    IsCI           = $isCI
    UbuntuDistribution = $null
    Branch        = $branchValue
    RequiresReboot = $false
    EnabledWslFeatures = $false
  }

  if ($script:OnboardState.Verbose) {
    Write-VerboseMessage "Verbose logging enabled."
    if ($isCI) {
      Write-VerboseMessage "CI environment detected."
    }
    Write-VerboseMessage "Operating against project-onboard branch '$branchValue'."
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

  $features = @(
    [pscustomobject]@{ Name = 'Microsoft-Windows-Subsystem-Linux'; Display = 'Windows Subsystem for Linux' },
    [pscustomobject]@{ Name = 'VirtualMachinePlatform'; Display = 'Virtual Machine Platform' }
  )

  $preStates = @()
  foreach ($feature in $features) {
    try {
      $preStates += Get-OptionalFeatureRecord -FeatureName $feature.Name
    } catch {
      Write-VerboseMessage "Unable to query optional feature state before enable for $($feature.Name): $($_.Exception.Message)"
    }
  }

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

  if ($preStates) {
    $allEnabledBefore = $true
    foreach ($state in $preStates) {
      if ($null -eq $state) {
        $allEnabledBefore = $false
        continue
      }

      if ($state.State -ne 'Enabled') {
        $allEnabledBefore = $false
      }
    }

    if (-not $allEnabledBefore) {
      $script:OnboardState.EnabledWslFeatures = $true
    }
  } else {
    # If we cannot determine the existing state, assume changes were required
    $script:OnboardState.EnabledWslFeatures = $true
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

    $tarGzItem = Get-ChildItem -Path $extractPath -Recurse -File |
      Where-Object { $_.Name -ieq 'install.tar.gz' } |
      Select-Object -First 1

    if (-not $tarGzItem) {
      Write-VerboseMessage 'install.tar.gz not found after initial extraction; searching nested architecture package.'

      $nestedAppx = Get-ChildItem -Path $extractPath -Recurse -File |
        Where-Object { $_.Extension -ieq '.appx' -and $_.Name -match '_x64\.appx$' } |
        Select-Object -First 1

      if (-not $nestedAppx) {
        $nestedAppx = Get-ChildItem -Path $extractPath -Recurse -File |
          Where-Object { $_.Extension -ieq '.appx' } |
          Select-Object -First 1
      }

      if (-not $nestedAppx) {
        throw 'Unable to locate architecture-specific appx inside the downloaded Ubuntu bundle.'
      }

      Write-VerboseMessage "Expanding nested architecture package: $($nestedAppx.FullName)"
      $nestedExtractPath = Join-Path -Path $extractPath -ChildPath 'nested-appx'
      Expand-Archive -Path $nestedAppx.FullName -DestinationPath $nestedExtractPath -Force

      $tarGzItem = Get-ChildItem -Path $nestedExtractPath -Recurse -File |
        Where-Object { $_.Name -ieq 'install.tar.gz' -or $_.Name -like '*.tar.gz' } |
        Select-Object -First 1
    }

    if (-not $tarGzItem) {
      throw 'Unable to locate install.tar.gz after extracting the Ubuntu package.'
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

    Write-Info "Setting $DistributionName as the default WSL distribution..."
    Set-WslDefaultDistribution -DistributionName $DistributionName

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

  $allDistributions = @(Get-WslDistributionData)
  $ubuntuDistributions = @($allDistributions | Where-Object { $_ -like 'Ubuntu-22.04*' })

  if ($ubuntuDistributions.Count -gt 0) {
    Write-Info "Detected existing Ubuntu-22.04 distributions: $($ubuntuDistributions -join ', ')"

    if ($script:OnboardState.DryRun) {
      Write-DryRunAction 'Would prompt to select an existing Ubuntu-22.04 distribution or install a new one'
      $script:OnboardState.UbuntuDistribution = $ubuntuDistributions[0]
      return
    }

    $autoSelection = $null
    if ($script:OnboardState.NonInteractive) {
      $autoSelection = if ($ubuntuDistributions -contains 'Ubuntu-22.04') {
        'Ubuntu-22.04'
      } else {
        $ubuntuDistributions[0]
      }

      Write-Warn "Non-interactive mode: automatically selecting existing distribution '$autoSelection'."
      $script:OnboardState.UbuntuDistribution = $autoSelection
      Set-WslDefaultDistribution -DistributionName $autoSelection
      return
    }

    $selection = Get-UbuntuDistributionSelection -ExistingUbuntuDistributions $ubuntuDistributions -AllDistributions $allDistributions

    if ($selection.Action -eq 'UseExisting') {
      $selected = [string]$selection.Name
      Write-Info "Using existing distribution '$selected'."
      $script:OnboardState.UbuntuDistribution = $selected
      Set-WslDefaultDistribution -DistributionName $selected
      return
    }

    if ($selection.Action -eq 'InstallNew') {
      $newName = [string]$selection.Name
      Write-Info "Installing new Ubuntu-22.04 distribution named '$newName'."

      if ($script:OnboardState.DryRun) {
        Write-DryRunAction "Would import new Ubuntu-22.04 distribution named '$newName' via manual appx download"
        $script:OnboardState.UbuntuDistribution = $newName
        return
      }

      Import-UbuntuDistributionFromAppx -DistributionName $newName
      $script:OnboardState.UbuntuDistribution = $newName
      return
    }

    throw 'Unexpected selection response when choosing Ubuntu distribution.'
  }

  if ($script:OnboardState.DryRun) {
    Write-DryRunAction 'Would install Ubuntu-22.04 via wsl --install and fall back to manual import if needed'
    $script:OnboardState.UbuntuDistribution = 'Ubuntu-22.04'
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
      if (-not $script:OnboardState.IsCI -and $script:OnboardState.EnabledWslFeatures) {
        Write-Warn "wsl --install exited with code $installExitCode."
        Write-Warn 'The Windows features required for WSL were just enabled. A system restart is needed before installing Ubuntu.'
        $script:OnboardState.RequiresReboot = $true
        return
      } else {
        Write-Warn "wsl --install exited with code $installExitCode. Will attempt manual import."
      }
    } else {
      Start-Sleep -Seconds 5
    }

    $allDistributions = @(Get-WslDistributionData)
    if ($allDistributions -contains 'Ubuntu-22.04') {
      Write-Info 'Ubuntu distribution detected after wsl --install.'
      $script:OnboardState.UbuntuDistribution = 'Ubuntu-22.04'
      Set-WslDefaultDistribution -DistributionName 'Ubuntu-22.04'
      return
    }

    if (-not $script:OnboardState.IsCI -and $script:OnboardState.EnabledWslFeatures) {
      Write-Warn 'Ubuntu distribution not detected after wsl --install. Windows must restart to complete the installation before continuing.'
      $script:OnboardState.RequiresReboot = $true
      return
    }

    Write-Warn 'Ubuntu distribution not detected after wsl --install. Falling back to manual import.'
    Import-UbuntuDistributionFromAppx -DistributionName 'Ubuntu-22.04'

    $allDistributions = @(Get-WslDistributionData)
    if (-not ($allDistributions -contains 'Ubuntu-22.04')) {
      throw 'Ubuntu distribution is still not registered after manual import attempt.'
    }

    Write-Info 'Ubuntu distribution registered successfully after manual import.'
    $script:OnboardState.UbuntuDistribution = 'Ubuntu-22.04'
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

function Set-WslDefaultDistribution {
  param([string]$DistributionName)

  if ([string]::IsNullOrWhiteSpace($DistributionName)) {
    return
  }

  if ($script:OnboardState.DryRun) {
    Write-DryRunAction "Would run: wsl --set-default $DistributionName"
    return
  }

  try {
    $setDefaultResult = & wsl.exe --set-default $DistributionName 2>&1
    Write-VerboseMessage "wsl --set-default output: $($setDefaultResult -join ' ')"
  } catch {
    throw "Failed to set default WSL distribution to '$DistributionName': $($_.Exception.Message)"
  }
}

function Get-UbuntuDistributionSelection {
  param(
    [string[]]$ExistingUbuntuDistributions,
    [string[]]$AllDistributions
  )

  Write-Info ''
  Write-Info 'Ubuntu-22.04 distributions already registered:'

  for ($i = 0; $i -lt $ExistingUbuntuDistributions.Count; $i++) {
    $displayIndex = $i + 1
    Write-Info "  [$displayIndex] Use '$($ExistingUbuntuDistributions[$i])'"
  }

  Write-Info '  [N] Install a new Ubuntu-22.04 distribution'
  Write-Info ''

  while ($true) {
    $selection = Read-Host 'Enter selection (number or N)'

    if ([string]::IsNullOrWhiteSpace($selection)) {
      Write-Warn 'Please enter a value.'
      continue
    }

    if ($selection -match '^[Nn]$') {
      while ($true) {
        $newName = Read-Host 'Enter a name for the new distribution (letters, numbers, hyphen, underscore)'

        if ([string]::IsNullOrWhiteSpace($newName)) {
          Write-Warn 'Distribution name cannot be empty.'
          continue
        }

        if ($newName -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]{0,31}$') {
          Write-Warn 'Name must start with a letter or number and contain only letters, numbers, hyphen, or underscore (max 32 characters).'
          continue
        }

        if ($AllDistributions -contains $newName) {
          Write-Warn "A distribution named '$newName' already exists. Choose a different name."
          continue
        }

        return [pscustomobject]@{
          Action = 'InstallNew'
          Name   = $newName
        }
      }
    }

    if ($selection -match '^[0-9]+$') {
      $index = [int]$selection
      if ($index -ge 1 -and $index -le $ExistingUbuntuDistributions.Count) {
        return [pscustomobject]@{
          Action = 'UseExisting'
          Name   = $ExistingUbuntuDistributions[$index - 1]
        }
      }
    }

    Write-Warn 'Invalid selection. Please choose a listed option.'
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
    Write-Info ''
    Write-Info '========== WSL First-Boot Complete =========='
    Write-Info ''
    return
  }

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

function Configure-WslGitCredentialManager {
  <#
  .SYNOPSIS
    Ensure WSL Git delegates credential storage to the Windows Git Credential Manager.
  #>

  Write-Info 'Configuring WSL Git to use Windows Git Credential Manager...'

  $gcmWindowsPath = 'C:\Program Files\Git\mingw64\bin\git-credential-manager.exe'
  $gcmWslPath = '/mnt/c/Program Files/Git/mingw64/bin/git-credential-manager.exe'
  $gcmWslEscaped = $gcmWslPath -replace ' ', '\\ '

  if ($script:OnboardState.DryRun) {
    Write-DryRunAction "Would run: wsl -e bash -lc \"git config --global credential.helper '$gcmWslEscaped'\""
    Write-DryRunAction "Would run: wsl -e bash -lc \"git config --global credential.https://dev.azure.com.useHttpPath true\""
    return
  }

  if (-not (Test-Path -Path $gcmWindowsPath)) {
    Write-Warn 'Git Credential Manager executable not found at C:\Program Files\Git\mingw64\bin. Skipping WSL Git credential helper configuration.'
    return
  }

  $commands = @(
    "git config --global credential.helper '$gcmWslEscaped'"
    "git config --global credential.https://dev.azure.com.useHttpPath true"
  )

  foreach ($command in $commands) {
    try {
      $result = wsl -e bash -lc $command 2>&1
      if ($LASTEXITCODE -ne 0) {
        Write-Warn "WSL command failed with exit code $LASTEXITCODE while running '$command'. Output: $($result -join ' ')"
      } else {
        Write-VerboseMessage "WSL git configuration command succeeded: $command"
      }
    } catch {
      Write-Warn "Failed to execute '$command' inside WSL: $($_.Exception.Message)"
    }
  }
}

function Invoke-WslHandoff {
  <#
  .SYNOPSIS
    Hand off to setup.sh inside WSL with flag passthrough.
  #>

  Write-Info ''
  Write-Info '========== Handing off to setup.sh inside WSL =========='
  Write-Info ''

  $branch = $script:OnboardState.Branch
  if ([string]::IsNullOrWhiteSpace($branch)) {
    $branch = 'main'
  }

  $flagSegments = New-Object System.Collections.Generic.List[string]
  if ($script:OnboardState.NonInteractive) {
    $flagSegments.Add('--non-interactive') | Out-Null
  }
  if ($script:OnboardState.Verbose) {
    $flagSegments.Add('--verbose') | Out-Null
  }
  if ($script:OnboardState.NoOptional) {
    $flagSegments.Add('--no-optional') | Out-Null
  }
  if ($script:OnboardState.Workspace) {
    $workspaceForWsl = Convert-WorkspacePathForWsl -Path $script:OnboardState.Workspace
    $flagSegments.Add('--workspace') | Out-Null
    $flagSegments.Add((Convert-ToBashArgument -Value $workspaceForWsl)) | Out-Null
  }
  if ($branch) {
    $flagSegments.Add('--branch') | Out-Null
    $flagSegments.Add((Convert-ToBashArgument -Value $branch)) | Out-Null
  }

  $flagString = if ($flagSegments.Count -gt 0) {
    [string]::Join(' ', $flagSegments)
  } else {
    ''
  }

  $setupUrl = "https://raw.githubusercontent.com/kevinaud/project-onboard/$branch/setup.sh"
  $envPrefix = "PROJECT_ONBOARD_BRANCH=$branch "
  if ([string]::IsNullOrWhiteSpace($flagString)) {
    $handoffCommand = "${envPrefix}curl -fsSL $setupUrl | bash"
  } else {
    $handoffCommand = "${envPrefix}curl -fsSL $setupUrl | bash -s -- $flagString"
  }

  Write-Info "Executing: wsl -e bash -lc `"$handoffCommand`""

  if ($script:OnboardState.DryRun) {
    Write-DryRunAction "Would execute: wsl -e bash -lc `"$handoffCommand`""
    Write-Info ''
    Write-Info '========== WSL Handoff Complete =========='
    Write-Info ''
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
    [string]$Workspace,
    [string]$Branch
  )

  Initialize-OnboardState -DryRunSwitch:$DryRun -NonInteractiveSwitch:$NonInteractive -NoOptionalSwitch:$NoOptional -VerboseSwitch:$VerboseMode -WorkspacePath $Workspace -BranchName $Branch
  $env:PROJECT_ONBOARD_BRANCH = $script:OnboardState.Branch

  $plan = @(
    'Check required Windows optional features for WSL',
    'Enable WSL and Virtual Machine Platform features',
    'Update WSL components and set default version to 2',
    'Install Ubuntu-22.04 distribution',
    'Install Git for Windows',
    'Install Visual Studio Code and configure remote development tooling'
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
  Write-Info "Using project-onboard branch '$($script:OnboardState.Branch)'."

  # Query feature status before making changes
  Write-OptionalFeatureStatus

  # Enable WSL features (idempotent)
  Enable-WslFeature

  # Update WSL components
  Update-WslComponent

  # Install Ubuntu distribution
  Install-UbuntuDistribution

  if ($script:OnboardState.RequiresReboot -and -not $script:OnboardState.IsCI) {
    Write-Warn 'A system restart is required to finish enabling WSL and installing Ubuntu.'
    Write-Info 'Please reboot Windows, then re-run setup.ps1 to continue the onboarding process. No further actions were taken.'
    return
  }

  # Install Git for Windows
  Install-GitForWindows

  # Install and configure Visual Studio Code
  Ensure-VSCodeInstalled
  Ensure-VSCodeRemoteExtensionPack
  Ensure-VSCodeDotfileSettings

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
    Configure-WslGitCredentialManager
  }

  # Handoff to setup.sh inside WSL (manual mode only)
  # In CI mode, the GitHub Actions workflow handles all subsequent steps
  if (-not $script:OnboardState.IsCI) {
    Invoke-WslHandoff
  } else {
    Write-Info 'CI mode: Skipping setup.sh handoff. The GitHub Actions workflow will handle subsequent steps.'
  }

  if ($script:OnboardState.DryRun) {
    Write-Info 'Dry-run mode: no host changes were made.'
  } else {
    if ($script:OnboardState.IsCI) {
      Write-Info 'Windows setup complete (CI mode). WSL features enabled, Ubuntu installed, Git for Windows installed.'
    } else {
      Write-Info 'Windows setup complete. WSL, Ubuntu, Git for Windows, Docker Desktop installed and configured.'
    }
  }
}

if (-not $script:IsDotSourced) {
  Ensure-ExecutionPolicyRelaxed
  Invoke-Onboarding @PSBoundParameters
}
