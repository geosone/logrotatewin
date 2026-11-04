#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ArchivePath,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateSet('x86', 'x64')][string]$Architecture = 'x64'
)
$ErrorActionPreference = 'Stop'
if (!$IsLinux) {
    throw 'This packaging recipe requires Linux wixl (msitools).'
}
$null = Get-Command wixl -ErrorAction Stop
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$expected = '965ec8573eddf43533d83d817f5a827a685424b0d9adf3454e69ff053d427fc8'
if ((Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) {
    throw 'The input must be the pinned LogRotateWin 0.0.60-retain.2 runtime ZIP.'
}
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) {
    throw 'Choose a fresh output directory.'
}
$null = New-Item -ItemType Directory $output
$payload = Join-Path $output 'payload'
Expand-Archive -LiteralPath $ArchivePath -DestinationPath $payload
Copy-Item (Join-Path $root 'LICENSE') (Join-Path $payload 'LICENSE.txt')
Copy-Item (Join-Path $root 'packaging/windows/README.txt') (Join-Path $payload 'PACKAGING.txt')
# Bundle the exact source and packaging instructions beside the binary packages.
# A dirty checkout would make a HEAD-only source archive incomplete.
$dirty = & git -C $root status --porcelain --untracked-files=all
if ($LASTEXITCODE -or $dirty) {
    throw 'Commit packaging changes before building the corresponding source bundle.'
}
$sourceName = 'logrotatewin-0.0.60-msi-source.tar.gz'
& git -C $root archive --format=tar.gz --prefix=logrotatewin/ "--output=$(Join-Path $output $sourceName)" HEAD
if ($LASTEXITCODE) {
    throw 'Source archive creation failed.'
}
$sourceCommit = (& git -C $root rev-parse HEAD).Trim()
$notice = @"
LogRotateWin runtime: 0.0.60-retain.2 (AnyCPU .NET Framework 4.8, rotate -1 fix)
Runtime source commit: 296416d; application code matches that qualified release.
Qualified runtime ZIP SHA256: $expected
Packaging source commit: $sourceCommit
License: GPL-3.0-or-later. See LICENSE.txt and upstream notices.
Corresponding source: $sourceName, supplied alongside the MSI.
Fork: https://github.com/geosone/logrotatewin
MSI package version: 0.0.61; package architecture: $Architecture
Unsigned package. Installs files only; no rotation schedule is activated.
"@
[IO.File]::WriteAllText((Join-Path $payload 'SOURCE-NOTICE.txt'), $notice)
$msi = Join-Path $output "logrotatewin-0.0.61-windows-$Architecture.msi"
$template = Join-Path $root "packaging/windows/$Architecture/logrotatewin.wxs"
& wixl -a $Architecture -D "PayloadDirectory=$payload" -o $msi $template
if ($LASTEXITCODE) {
    throw 'wixl failed.'
}
& (Join-Path $root 'packaging/finalize_msi_path.ps1') -Package $msi -Component Runtime
$artifactHash = (Get-FileHash $msi -Algorithm SHA256).Hash.ToLowerInvariant()
$sourceHash = (Get-FileHash (Join-Path $output $sourceName) -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText((Join-Path $output 'SHA256SUMS'), "$artifactHash  $([IO.Path]::GetFileName($msi))`n$sourceHash  $sourceName`n")
[pscustomobject]@{
    Package      = $msi
    Architecture = $Architecture
    SHA256       = $artifactHash
    Source       = (Join-Path $output $sourceName)
}
