# Enters the Visual Studio x64 Developer environment for the integrated terminal.
#
# Primary use: the `VS Dev PowerShell (x64)` DEFAULT terminal profile in the .code-workspace
# (powershell -NoExit -File dev-shell.ps1, NO extra args) — sets cl/ninja env and stays interactive.
#
# NOTE: VS Code *tasks* do NOT use this script. They run via .vscode/dev-run.cmd (a cmd wrapper),
# because a -File profile does not reliably receive an injected task command and `powershell -File`
# mangles dotted `-D...=a.b.c` args. The command-runner branch below is kept only as a manual
# fallback (`dev-shell.ps1 <exe> [args...]`).
#
# FLEET-SHARED FILE. Canonical copy: SuperbuildEngine/templates/dev-shell.ps1. Every product's
# .vscode/dev-shell.ps1 must stay byte-identical to it -- fix the template first, then re-copy
# into each product (crosscheck D8). Do not fork it per product.
$ErrorActionPreference = 'Stop'
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) { throw "vswhere not found: $vswhere" }
$vs = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace($vs)) { throw "Visual Studio with the C++ x64 toolset not found." }
$env:Path = (Split-Path $vswhere) + ';' + $env:Path   # let Enter-VsDevShell find vswhere.exe by name
Import-Module (Join-Path $vs 'Common7\Tools\Microsoft.VisualStudio.DevShell.dll')
Enter-VsDevShell -VsInstallPath $vs -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64' | Out-Null
# Cap build parallelism at (logical cores - 2), floor 1, so a heavy build launched from this
# terminal never saturates every core and freezes the machine. Honor a pre-set value (override).
# Do NOT pass a bare `--parallel` on the command line -- it overrides this and makes Ninja
# oversubscribe at cores+2. (Tasks get the cap plus /belownormal priority via dev-run.cmd.)
if (-not $env:CMAKE_BUILD_PARALLEL_LEVEL) {
    $env:CMAKE_BUILD_PARALLEL_LEVEL = [Math]::Max(1, [Environment]::ProcessorCount - 2)
}
if ($args.Count -ge 1) {
    & $args[0] @($args | Select-Object -Skip 1)
    exit $LASTEXITCODE
}
Write-Host '[VS Dev PowerShell (x64) ready]' -ForegroundColor DarkCyan
