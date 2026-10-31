#Requires -Version 7.4
# Run only on an explicitly selected disposable Windows test VM.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PackagePath,
    [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$ExpectedSHA256,
    [Parameter(Mandatory)][string]$TestDirectory,
    [Parameter(Mandatory)][ValidateSet('x86', 'x64')][string]$Architecture
)
$ErrorActionPreference = 'Stop'
if (!$IsWindows) {
    throw 'A disposable Windows test VM is required.'
}
if ((Get-FileHash -LiteralPath $PackagePath).Hash -ine $ExpectedSHA256) {
    throw 'MSI checksum mismatch.'
}
$programs = if ($Architecture -eq 'x64') {
    $env:ProgramW6432
} elseif ($env:ProgramW6432) {
    ${env:ProgramFiles(x86)}
} else {
    $env:ProgramFiles
}
if (!$programs) {
    throw 'The requested package architecture is unavailable.'
}
$installed = Join-Path $programs 'LogRotateWin'
if ((Test-Path $installed) -or (Test-Path $TestDirectory)) {
    throw 'Refusing existing installation or test directory.'
}
$framework = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full'
if ($framework.Release -lt 528040) {
    throw '.NET Framework 4.8 is required.'
}
$null = New-Item -ItemType Directory $TestDirectory
$msi = [IO.Path]::GetFullPath($PackagePath)
function Invoke-Msi([string]$Mode, [string]$LogName) {
    $arguments = @($Mode, ('"' + $msi + '"'), '/qn', '/norestart', '/L*v', ('"' + (Join-Path $TestDirectory $LogName) + '"'))
    $process = Start-Process msiexec.exe -ArgumentList $arguments -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "Windows Installer failed ($($process.ExitCode)); inspect $LogName."
    }
}
$active = $false
try {
    Invoke-Msi '/i' 'install.log'
    $active = $true
    $exe = Join-Path $installed 'logrotate.exe'
    foreach ($file in 'logrotate.exe', 'logrotate.exe.config', 'LICENSE.txt', 'SOURCE-NOTICE.txt', 'PACKAGING.txt', 'Content/logrotate.conf') {
        if (!(Test-Path (Join-Path $installed $file))) {
            throw "Installed payload missing: $file"
        }
    }
    $originalHash = (Get-FileHash $exe).Hash
    Remove-Item -LiteralPath $exe
    Invoke-Msi '/fa' 'repair.log'
    if ((Get-FileHash $exe).Hash -ne $originalHash) {
        throw 'Repair did not restore the original runtime.'
    }
    $log = Join-Path $TestDirectory 'active.log'
    $state = Join-Path $TestDirectory 'rotation.state'
    $config = Join-Path $TestDirectory 'logrotate.conf'
    [IO.File]::WriteAllText($log, "fixture-before`n")
    $path = $log.Replace('\', '/')
    $configuration = @"
"$path" {
    size 1
    rotate 3
    missingok
    notifempty
    dateext
    dateformat .%Y%m%d
    extension .log
    compress
    copytruncate
}
"@
    [IO.File]::WriteAllText($config, $configuration)
    & $exe -f -s $state $config
    if ($LASTEXITCODE) {
        throw 'Installed runtime rotation failed.'
    }
    $archives = @(Get-ChildItem $TestDirectory -Filter '*.gz')
    if ($archives.Count -ne 1) {
        throw 'Expected exactly one compressed archive.'
    }
    $input = [IO.File]::OpenRead($archives[0].FullName)
    $gzip = [IO.Compression.GZipStream]::new($input, [IO.Compression.CompressionMode]::Decompress)
    $reader = [IO.StreamReader]::new($gzip)
    try {
        $content = $reader.ReadToEnd()
    } finally {
        $reader.Dispose()
        $gzip.Dispose()
        $input.Dispose()
    }
    if ($content -ne "fixture-before`n" -or [IO.File]::ReadAllText($log) -ne '') {
        throw 'Compressed contents or truncation differ.'
    }
    [IO.File]::AppendAllText($log, "fixture-after`n")
    Invoke-Msi '/x' 'uninstall.log'
    $active = $false
    if ((Test-Path $exe) -or [IO.File]::ReadAllText($log) -ne "fixture-after`n" -or !(Test-Path $config)) {
        throw 'Uninstall left runtime files or damaged external log/configuration.'
    }
    "PASS $Architecture MSI install, repair, gzip rotation, continued logging and uninstall; external configuration preserved."
} finally {
    if ($active) {
        Invoke-Msi '/x' 'cleanup-uninstall.log'
    }
}
