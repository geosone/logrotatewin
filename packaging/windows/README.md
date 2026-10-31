# Windows Installer packaging

Build on Linux with PowerShell 7.4+, Git, `wixl` and the pinned upstream ZIP:

```powershell
./New-WindowsMsi.ps1 -ArchivePath /downloads/logrotatewin-0.0.59.zip -OutputDirectory /build/logrotatewin-x64 -Architecture x64
./New-WindowsMsi.ps1 -ArchivePath /downloads/logrotatewin-0.0.59.zip -OutputDirectory /build/logrotatewin-x86 -Architecture x86
```

Commit changes before building; corresponding-source archives are made from
HEAD. Outputs must be outside the checkout. Publish each MSI together with
`SHA256SUMS` and its source archive. The upstream ZIP SHA-256 is verified before
extraction. The payload is unchanged AnyCPU; package architecture selects the
MSI context and Program Files location.

`tests/Test-WindowsMsi.ps1` installs, repairs, exercises actual rotation and
uninstalls on a disposable Windows VM. It refuses an already installed package
or an existing default installation directory. No scheduling is installed.

Mystic-specific configuration, event integration and platform dependencies belong
to mysticd, not this program repository. A passing package test does not qualify
native Mystic midnight log handling.
