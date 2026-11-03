#Requires -Version 7.4
<#
.SYNOPSIS
Checks rotate -1 with both compression modes against the built executable.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ExecutablePath)
$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetTempPath()) ('keep-archives-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $root
try {
    foreach ($mode in @('compress', 'nocompress')) {
        $directory = Join-Path $root $mode
        $null = New-Item -ItemType Directory -Path $directory
        $log = Join-Path $directory 'app.log'
        $old = Join-Path $directory 'app.20000101.log'
        [IO.File]::WriteAllText($log, 'current fixture')
        [IO.File]::WriteAllText($old, 'preserve fixture')
        $configuration = Join-Path $directory 'engine.conf'
        $normalized = $log.Replace('\', '/')
        [IO.File]::WriteAllText($configuration, "`"$normalized`" {`n daily`n rotate -1`n dateext`n dateformat .%Y%m%d`n extension .log`n $mode`n copytruncate`n}`n")
        & $ExecutablePath -f -s (Join-Path $directory 'state') $configuration
        if ($LASTEXITCODE -or [IO.File]::ReadAllText($old) -ne 'preserve fixture') {
            throw 'rotate -1 deleted an archive or failed.'
        }
        $suffix = if ($mode -eq 'compress') {
            '.log.gz'
        } else {
            '.log'
        }
        $archive = Join-Path $directory ('app.' + [datetime]::Now.ToString('yyyyMMdd') + $suffix)
        if (!(Test-Path $archive) -or [IO.File]::ReadAllText($log) -ne '') {
            throw 'Expected archive/active file missing.'
        }
    }
    'PASS rotate -1 preserves existing archives with compression enabled and disabled.'
} finally {
    Remove-Item -LiteralPath $root -Recurse -Force
}
