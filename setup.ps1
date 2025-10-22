[CmdletBinding(PositionalBinding = $false)]
param(
    [switch]$NonInteractive,
    [switch]$NoOptional,
    [switch]$DryRun,
    [switch]$Verbose,
    [string]$Workspace = $(Join-Path -Path $HOME -ChildPath 'projects')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $PSBoundParameters.ContainsKey('Workspace') -and $env:PROJECT_ONBOARD_WORKSPACE) {
    $Workspace = $env:PROJECT_ONBOARD_WORKSPACE
}

$dryRunRequested = [bool]$DryRun
if (-not $dryRunRequested) {
    Write-Warning 'Iteration 0 treats all runs as dry runs. Forcing dry-run mode.'
    $dryRunRequested = $true
}

$verboseSnapshot = [ordered]@{
    OSDescription       = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
    OSArchitecture      = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
    ProcessArchitecture = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
}

Write-Output 'project-onboard iteration 0 scaffold'
Write-Output ("Flags: dry_run={0}, non_interactive={1}, no_optional={2}, verbose={3}" -f `
    $dryRunRequested,
    [bool]$NonInteractive,
    [bool]$NoOptional,
    [bool]$Verbose)
Write-Output ("Workspace: {0}" -f $Workspace)

Write-Verbose ("Environment snapshot: {0}" -f (ConvertTo-Json -InputObject $verboseSnapshot -Compress))

$plan = @(
    'Capture environment details for future iterations',
    ("Respect workspace override: {0}" -f $Workspace),
    'Skip optional installs until later iterations',
    'Exit after printing this plan'
)

Write-Output ''
Write-Output 'Plan:'
foreach ($step in $plan) {
    Write-Output ("  - {0}" -f $step)
}
Write-Output ''
Write-Output 'Nothing to do yet. Follow upcoming iterations for real actions.'
