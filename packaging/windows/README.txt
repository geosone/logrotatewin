LogRotateWin 0.0.60 Windows Installer packaging

Original application by Ken Salter and upstream contributors:
https://github.com/plecos/logrotatewin
Packaging maintained at https://github.com/geosone/logrotatewin

The application is licensed GPL-3.0-or-later. This MSI contains the qualified
0.0.60-retain.2 AnyCPU .NET Framework 4.8 runtime, including the rotate -1 fix.
The x86/x64 designation selects the installer context and installation folder.
It does not claim a separately compiled native executable.

Default installation: Program Files/LogRotateWin (architecture-specific).
Requirements: Windows 10, .NET Framework 4.8. Packages are unsigned.
No service, task, PATH change, Mystic configuration or automatic rotation is
installed. Mutable configuration and state belong outside Program Files.
Uninstall removes packaged files only; external logs/configuration remain.

Use logrotate.exe -d -s STATE CONFIG to preview a configuration.
The full corresponding source archive is supplied alongside the MSI; see
SOURCE-NOTICE.txt for the exact source and packaging commits.
