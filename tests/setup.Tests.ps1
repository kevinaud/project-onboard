Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'setup.ps1' {
  BeforeAll {
    $repoRoot = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath '..')
    . (Join-Path -Path $repoRoot -ChildPath 'setup.ps1')
  }

  Context 'optional feature reporting' {
    It 'reports when required optional features are already enabled' {
      $featureStates = @{
        'Microsoft-Windows-Subsystem-Linux' = 'Enabled'
        'VirtualMachinePlatform'           = 'Enabled'
      }

      Mock Get-WindowsOptionalFeature {
        param(
          [string]$FeatureName,
          [switch]$Online,
          [string]$ErrorAction
        )

        [pscustomobject]@{
          FeatureName = $FeatureName
          State       = $featureStates[$FeatureName]
        }
      }

      Mock Invoke-WslCommand { 'Ubuntu' }

      $output = Invoke-Onboarding

  $output | Should -Contain "[INFO] Optional feature 'Windows Subsystem for Linux' is already enabled."
  $output | Should -Contain "[INFO] Optional feature 'Virtual Machine Platform' is already enabled."
  $output | Should -Contain "[INFO] Detected WSL distributions: Ubuntu"
  $output | Should -Contain '[INFO] Dry-run enforced; Windows installers and configuration changes were skipped.'

      Assert-MockCalled Get-WindowsOptionalFeature -Times 2 -Exactly
      Assert-MockCalled Invoke-WslCommand -Times 1 -Exactly
    }

    It 'highlights when optional features are disabled and simulates enablement in dry-run' {
      $featureStates = @{
        'Microsoft-Windows-Subsystem-Linux' = 'Disabled'
        'VirtualMachinePlatform'           = 'Enabled'
      }

      Mock Get-WindowsOptionalFeature {
        param(
          [string]$FeatureName,
          [switch]$Online,
          [string]$ErrorAction
        )

        [pscustomobject]@{
          FeatureName = $FeatureName
          State       = $featureStates[$FeatureName]
        }
      }

      Mock Invoke-WslCommand { @() }

      $output = Invoke-Onboarding

  $output | Should -Contain "[WARN] Optional feature 'Windows Subsystem for Linux' is not enabled (state: Disabled)."
  $output | Should -Contain "[INFO] DRY-RUN: Would enable optional feature 'Microsoft-Windows-Subsystem-Linux' using Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart."
  $output | Should -Contain "[WARN] No WSL distributions are currently registered."
  $output | Should -Contain '[INFO] Ubuntu distribution not detected. After enabling optional features, install it with: wsl --install -d Ubuntu'

      Assert-MockCalled Get-WindowsOptionalFeature -Times 2 -Exactly
      Assert-MockCalled Invoke-WslCommand -Times 1 -Exactly
    }
  }

  Context 'first boot guidance' {
    It 'encourages first launch when Ubuntu is registered' {
      $featureStates = @{
        'Microsoft-Windows-Subsystem-Linux' = 'Enabled'
        'VirtualMachinePlatform'           = 'Enabled'
      }

      Mock Get-WindowsOptionalFeature {
        param(
          [string]$FeatureName,
          [switch]$Online,
          [string]$ErrorAction
        )

        [pscustomobject]@{
          FeatureName = $FeatureName
          State       = $featureStates[$FeatureName]
        }
      }

      Mock Invoke-WslCommand { @('Ubuntu', 'docker-desktop') }

      $output = Invoke-Onboarding

  $output | Should -Contain '[INFO] Ubuntu distribution detected. Launch it at least once to complete first-boot user creation before continuing.'
    }
  }
}