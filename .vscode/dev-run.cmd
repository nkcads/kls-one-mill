@echo off
REM Enters the VS x64 Developer environment, then runs the command passed as arguments (verbatim).
REM Used by VS Code tasks (type:process): cmd /c .vscode\dev-run.cmd <exe> [args...]
REM A cmd wrapper passes -D...=value.with.dots args verbatim (PowerShell -File mangles them).
REM
REM FLEET-SHARED FILE. Canonical copy: SuperbuildEngine/templates/dev-run.cmd. Every product's
REM .vscode/dev-run.cmd must stay byte-identical to it -- fix the template first, then re-copy
REM into each product (crosscheck D8). Do not fork it per product.
REM
REM vswhere lives under "Program Files (x86)"; the "(x86)" parens break a for /f (...) block,
REM so we pushd into the installer dir and call vswhere by bare name.
setlocal EnableExtensions
set "VSINSTALLER=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer"
if not exist "%VSINSTALLER%\vswhere.exe" (echo [dev-run] vswhere not found under "%VSINSTALLER%".& exit /b 1)
set "VSPATH="
pushd "%VSINSTALLER%"
for /f "usebackq tokens=*" %%i in (`.\vswhere.exe -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSPATH=%%i"
popd
if not defined VSPATH (echo [dev-run] Visual Studio with the C++ x64 toolset not found.& exit /b 1)
call "%VSPATH%\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64 >nul 2>nul || (echo [dev-run] VsDevCmd failed.& exit /b 1)

REM Cap build parallelism at (logical cores - 2), floor 1, so a heavy build never
REM saturates every core and freezes the machine. Portable across dev PCs -- derived
REM from NUMBER_OF_PROCESSORS at runtime. Honor a pre-set value so it can be overridden.
REM cmake --build only consults CMAKE_BUILD_PARALLEL_LEVEL when no --parallel is on the
REM command line (see .vscode/tasks.json -- the build tasks intentionally omit --parallel).
REM Compute SB_JOBS UNCONDITIONALLY (overwriting any inherited value), then apply it only
REM as a default. Do NOT guard the computation with `if not defined CMAKE_BUILD_PARALLEL_LEVEL`
REM and then test %SB_JOBS%: cmd expands %SB_JOBS% while PARSING the line, before any
REM `if defined SB_JOBS` guard on it runs, so an empty SB_JOBS turns the next line into
REM `if  LSS 1 ...` -> "1 was unexpected at this time." That is exactly what happens when the
REM caller already exports CMAKE_BUILD_PARALLEL_LEVEL (the VS Dev PowerShell profile does).
set /a "SB_JOBS=%NUMBER_OF_PROCESSORS%-2"
if %SB_JOBS% LSS 1 set "SB_JOBS=1"
if not defined CMAKE_BUILD_PARALLEL_LEVEL set "CMAKE_BUILD_PARALLEL_LEVEL=%SB_JOBS%"

REM Run the command at below-normal CPU priority so the OS scheduler always keeps the
REM UI responsive without starving the build; /wait propagates the exit code into ERRORLEVEL.
REM (/belownormal yields to foreground apps; use /low for idle priority if you need more.)
start "dev-run" /belownormal /b /wait %*
exit /b %ERRORLEVEL%
