#!/usr/bin/env pwsh
<#!
.SYNOPSIS
  Windows onboarding entrypoint placeholder.

.DESCRIPTION
  Iteration 1 focuses on Bash tooling. This PowerShell stub preserves CLI shape so that
  future work can add parity without breaking documentation or users who discover the
  script early.
#>

[CmdletBinding()]
param(
  [switch]$DryRun,
  [switch]$NonInteractive,
  [switch]$NoOptional,
  [switch]$Verbose,
  [string]$Workspace
)

# Touch parameters so PSScriptAnalyzer knows they are intentionally accepted for parity.
$null = $DryRun
$null = $NonInteractive
$null = $NoOptional
$null = $Verbose
$null = $Workspace

Write-Output "[INFO] Windows onboarding is not yet implemented."
Write-Output "[INFO] Iteration 1 delivers platform detection and logging helpers for Bash."
Write-Output "[INFO] Please rerun in WSL or macOS using ./setup.sh for the current iteration."