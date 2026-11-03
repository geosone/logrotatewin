#Requires -Version 7.4
# Runs only on a disposable elevated Windows host, with no existing installation.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$OldPackage,
    [Parameter(Mandatory)][string]$NewPackage,
    [Parameter(Mandatory)][ValidateSet('x86', 'x64')][string]$Architecture,
    [Parameter(Mandatory)][string]$TestDirectory
)
$ErrorActionPreference = 'Stop'
$programs = if ($Architecture -eq 'x64') {
    $env:ProgramW6432
} elseif ($env:ProgramW6432) {
    ${env:ProgramFiles(x86)}
} else {
    $env:ProgramFiles
}
$installed = Join-Path $programs 'LogRotateWin'
if ((Test-Path $installed) -or (Test-Path $TestDirectory)) {
    throw 'Use a fresh disposable installation/test directory.'
}
$null = New-Item -ItemType Directory $TestDirectory
$oldCode = if ($Architecture -eq 'x64') {
    '{9C96788E-4AE6-5EDC-84EA-0B6087A7C257}'
} else {
    '{7EE100F6-E851-5096-9270-6DE4F39398C4}'
}
function Invoke-Package {
    param([string]$Mode, [string]$Path, [string]$Name)
    $arguments = @($Mode, ('"' + $Path + '"'), '/qn', '/norestart', '/L*v', ('"' + (Join-Path $TestDirectory $Name) + '"'))
    $process = Start-Process msiexec.exe -ArgumentList $arguments -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw ('MSI operation failed: ' + $Name + '; exit=' + $process.ExitCode)
    }
}
$oldActive = $false
$newActive = $false
try {
    Invoke-Package /i $OldPackage old-install.log
    $oldActive = $true
    $external = Join-Path $TestDirectory 'operator.ini'
    [IO.File]::WriteAllText($external, 'preserve fixture')
    Invoke-Package /i $NewPackage upgrade.log
    $newActive = $true
    # Query MSI registration without Win32_Product, which can trigger repairs.
    $installer = New-Object -ComObject WindowsInstaller.Installer
    try {
        $state = $installer.GetType().InvokeMember('ProductState', [Reflection.BindingFlags]::GetProperty, $null, $installer, @($oldCode))
        if ($state -ne -1) {
            throw 'Old MSI remained registered after major upgrade.'
        }
        $oldActive = $false
    } finally {
        $null = [Runtime.InteropServices.Marshal]::ReleaseComObject($installer)
    }
    & (Join-Path $PSScriptRoot 'Test-KeepArchives.ps1') -ExecutablePath (Join-Path $installed 'logrotate.exe')
    if ([IO.File]::ReadAllText($external) -ne 'preserve fixture') {
        throw 'Upgrade changed external operator configuration.'
    }
    'PASS old-to-retention MSI major upgrade, old-product removal and retained external configuration.'
} finally {
    if ($newActive) {
        Invoke-Package /x $NewPackage new-uninstall.log
    } elseif ($oldActive) {
        Invoke-Package /x $OldPackage old-uninstall.log
    }
}
