#!/usr/bin/env pwsh
<#!
.SYNOPSIS
  Windows onboarding entrypoint placeholder.

.DESCRIPTION
  Iteration 1 focuses on Bash tooling. This PowerShell stub preserves CLI shape so that
  future work can add parity without breaking documentation or users who discover the
  script early.
#>

param(
    [switch]$DryRun,
    [switch]$NonInteractive,
    [switch]$NoOptional,
    [switch]$Verbose,
    [string]$Workspace
)

Write-Host "[INFO] Windows onboarding is not yet implemented."
Write-Host "[INFO] Iteration 1 delivers platform detection and logging helpers for Bash."
Write-Host "[INFO] Please rerun in WSL or macOS using ./setup.sh for the current iteration."