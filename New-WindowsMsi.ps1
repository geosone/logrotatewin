#Requires -Version 7.4
<#
.SYNOPSIS
Builds x86 or x64 Windows Installer packaging for the pinned upstream release.
.DESCRIPTION
Runs on Linux with wixl. The AnyCPU upstream executable is unchanged. Architecture
selects the MSI installation context and Program Files directory, not a rebuild
of the application. No service, task, firewall rule or global PATH is installed.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ArchivePath,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateSet('x86', 'x64')][string]$Architecture = 'x64'
)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'powershell/linux/all/New-WindowsMsi.ps1') @PSBoundParameters
