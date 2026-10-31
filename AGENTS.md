# Maintainer rules

Keep public PowerShell commands at repository root; implementations belong under
`powershell/` in platform/architecture or `all` directories. Use four-space
indentation, one statement per line and readable expanded control flow. Explain
non-obvious packaging assumptions in English. Do not minify scripts.

Keep application packaging here. Mystic-specific setup/configuration belongs in
the separate mysticd repository; BBS theme assets belong in mystic-theme.
Do not change live BBS installations or schedules without explicit approval.
Preserve upstream license notices and provide corresponding source with binaries.
