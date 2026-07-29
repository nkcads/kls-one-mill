# KLSOneMill — build environment on `version/Beta220`

**This checkout: `C:\DATA\repos\intern\KLSOneMill4`, branch `version/Beta220`, created 2026-07-29.**

## Why this clone exists

An earlier attempt built the same environment on `main`. `main` is **dead** in the whole C++ tree:
superproject `main` = `a5ca137` ("Merged PR 25596: Merge RC10", 2025-12-10), **32 commits behind**
`version/Beta220`. It is still the Azure DevOps default branch on all 30 repos, which is what makes
it look alive. History is strictly linear — `main` → `version/20Beta` → `version/Beta220`, nothing
diverged — so `main` was simply never fast-forwarded. See `.vscode/OneMill-Repo-Landscape.md` in
the KLSOneMill3 checkout for the full branch/tag/gitlink survey.

`version/Beta220` is the live branch. Where a submodule has no `version/Beta220`, its pinned SHA is
the tip of `version/20Beta`; the pinning is correct, so `--recursive` gives the right SHAs.

## Toolchain (unchanged from the earlier setup, nothing reinstalled)

| Var | Value |
| --- | --- |
| `QTDIR` | `D:\DevTools\Qt\6.10.2\msvc2022_64` (base kit only; includes Qt6Network, which Beta220 needs) |
| `Qt6_DIR` | `D:\DevTools\Qt\6.10.2\msvc2022_64\lib\cmake\Qt6` |
| `VCPKG_ROOT` | `D:\DevTools\vcpkg` @ commit `b81cab76a175645e047601da8f982ad86bff1cc3` |
| `VTK_DIR` | `D:\DevTools\vtk\install\lib\cmake\vtk-9.5` (v9.5.2, Qt-enabled, shared) |
| `MODULEWORKS_DIR` | `C:\DATA\install\ModuleWorksSdk` |

Build tree `D:\BuildDirectory\KLSOneMill4\win-msvc-x64-<config>`,
install tree `D:\deployData\KLSOneMill4\win-msvc-x64-<config>`.

**One new port was required:** `boost-asio`. See `vcpkgPackages.txt`, which is now a real pin
(commit + triplet + every explicit port with its version).

## Status: green — all three configurations

Verified 2026-07-29 with all three `Install | Win | MSVC | x64 | <config>` workflow presets.
Every step of every workflow exits 0.

| | configure+generate | build | top-level DLLs | module DLLs | unresolved imports | app launched |
| --- | --- | --- | --- | --- | --- | --- |
| RelWithDebInfo | 1.9 s / 1.3 s | 556 steps | 171 | 10 | 0 | **yes** |
| Debug | 1.9 s / 1.2 s | 556 steps | 171 | 10 | 0 | **no — asserts at startup, see below** |
| Release | ~2 s / ~1 s | 556 steps | 171 | 10 | 0 | **yes** |

Per config, `install_full` stages `MainApp.exe`, `Updater.exe`, all 10 modules, and gives
`ModuleMillingKalotte` and `ModulePostProcessor` **57 ModuleWorks DLLs + `mwSupport.lic`
(58 files)** each in their own `deps/`. The three `deps/` file lists are identical across configs —
the ModuleWorks SDK ships release-only binaries, so Debug links release ModuleWorks DLLs. That is
inherent to the SDK and is also how the shipping config has always been built.

Debug correctly stages the `d`-suffixed Qt and VTK binaries (`Qt6Cored.dll`,
`vtkCommonCore-9.5d.dll`, …) — both kits ship debug alongside release, so there is no
debug/release runtime mix in the staged tree, and no `*d.dll` leaks into the Release install.

**RelWithDebInfo and Release both launch and run. Debug builds and installs but does not run** —
see the CRT section below. Both working configurations were started from the `.vscode/launch.json`
"installed folder" entries, i.e. against the staged install tree, not the build tree.

### Debug does not run: static CRT vs. the plugin architecture

Launching the installed Debug build dies immediately in a CRT dialog:

```
Debug Assertion Failed!
Program: D:\deployData\KLSOneMill4\win-msvc-x64-debug\MainApp.exe
File: minkernel\crts\ucrt\src\appcrt\heap\debug_heap.cpp   Line: 996
Expression: __acrt_first_block == header
```

That expression fires when a heap block allocated by one CRT instance is freed by a different one.
`dumpbin /dependents` shows why:

| binary | CRT |
| --- | --- |
| `MainApp.exe` + all 10 module DLLs | **static** — zero CRT imports (`/MTd` here, `/MT` in the other configs) |
| `Qt6Cored.dll`, `vtkCommonCore-9.5d.dll` | **dynamic debug** — `ucrtbased.dll`, `MSVCP140D.dll`, `VCRUNTIME140D.dll` |
| ModuleWorks `mwgeolib.dll` and siblings | **dynamic release** — `MSVCP140.dll`, `VCRUNTIME140.dll` |

With `/MT` the CRT is linked *into each binary*, so the process holds **12 independent CRT heaps**:
one in `MainApp.exe`, one in each of the ten plugins, plus the dynamic one Qt and VTK share. Any
heap block that crosses a module boundary and is freed on the other side is undefined behaviour.

Release and RelWithDebInfo survive it only by luck: since the VS2015 UCRT refactor, static and
dynamic UCRT both allocate from the *process default heap*, so a cross-heap free usually happens to
work. The debug heap adds per-instance bookkeeping, so the very first cross-boundary free asserts.

**This is pre-existing on `version/Beta220`, not a consequence of the seven fixes.** Our binaries
are static-CRT in every configuration, including the RelWithDebInfo that runs fine, and the
static-runtime choice is the project's own (see `CLAUDE.md`). The fixes simply made Debug
*reachable* for the first time, which is how a latent problem became visible. It is not narrowly
fixable either — it is not one bad call site but `/MT` plus a plugin architecture that passes heap
objects across DLL boundaries. See open item 5.

Related: **the Debug install is not deployable off this machine.** `ucrtbased.dll`,
`msvcp140d.dll` and `vcruntime140d.dll` are the non-redistributable debug CRT; they resolve here
only because Visual Studio and the Windows SDK are installed. The dependency walk reporting
"0 unresolved" for Debug is therefore a statement about *this box*, not about a clean target.

Dependency walk method: recursive `dumpbin /dependents` over each installed module, resolving
against install root + `modulesBert\` + that module's `deps\` + `System32`, with **System32 DLLs
treated as terminal**. Recursing *into* OS DLLs instead reports 5 phantom misses per module
(`AzureAttestManager`, `AzureAttestNormal`, `HvsiFileTrust`, `PdmUtilities`, `wpaxholder`) — these
are delay-load imports of Windows' own components, absent from every Windows box, bound only if
the function is actually called. They are not ours and not a problem.

Disk after all three: build trees 5.4 / 2.2 / 5.0 GB, install trees 2.1 / 1.6 / 1.6 GB,
`D:` at 52 GB free.

## The seven fixes this branch needs

Each was found by building the untouched baseline and letting it fail — none were ported on
assumption. All are clean-checkout blockers on `version/Beta220` as it stands today.

| # | Where | Kind | Change | Proven by |
| --- | --- | --- | --- | --- |
| 1 | superproject | checkout | `git rm --cached` the stray gitlinks `.claude/worktrees/upbeat-blackwell` and `Modules/ModuleTemplate`; add `.claude/` to `.gitignore` | `git submodule update --init --recursive` aborted with `fatal: No url found for submodule path`, rc=128, **zero** submodules cloned. Even `git submodule status` was fatal. Now rc=0, 26 entries in sync |
| 2 | `StatisticsBackend`, `FileTransferBackend`, `FittingAnalysisBackend`, `FixtureBackend` | build | add `config/.gitkeep` | `Error copying directory from ".../config"` — build stopped at 9/555. 4 of the 7 modules that copy a `config/` dir do not have one |
| 3 | `ModuleUtils` | build | `find_package(Eigen3 CONFIG REQUIRED)` + `Eigen3::Eigen` | `VTKMatrixHelper.h(6): fatal error C1083: Cannot open include file: 'Eigen/Dense'` — stopped at 257/544 |
| 4 | `PostProcessorBackend` | build | `find_package(Eigen3 CONFIG REQUIRED)` + `Eigen3::Eigen` | `SubProgramRotator.h(3): fatal error C1083: Cannot open include file: 'Eigen/Core'` |
| 5 | vcpkg | toolchain | `vcpkg install boost-asio:x64-windows-static` | `FileTransferServer.h(3): Cannot open include file: 'boost/asio.hpp'` |
| 6 | `MainApp` | build (Ninja only) | list `app.manifest` in `add_executable()` instead of passing it via `target_link_options("/MANIFEST:EMBED" "/MANIFESTINPUT:...")` | `mt.exe : command line error c10100a7: No manifest inputs were specified` |
| 7 | `PostProcessorBackend` | runtime | add `ALL` to the ModuleWorks DLL copy target in `CMakeHelp/ModuleWorksSetup.cmake` | `modulesBert/ModulePostProcessor/deps` was never created, so the module could not load. MillingBackend's copy of the same file already has `ALL` |

Only #1, #2 (for StatisticsBackend) and #7 also existed on `main`. #3 recurs; #4, #5, #6 are new
to Beta220. The MillingKalotte `SessionHandler.cpp` patch from the `main` attempt was
**deliberately not applied**: `RevolveItem.h`/`LabelItem.h` exist on Beta220 and are actively used
(`RevolveItem` at line 1009, `LabelItem` at 1371/1384), so that patch would delete working features.

## Open — needs the dev lead

1. **The PostProcessor Python interpreter is missing.** `install_full` warns
   `! ModulePostProcessor/interpreter not found`. Two causes at once: `CopyPostProcessorData` in
   `ModulePostProcessorWidget/CMakeLists.txt` is **also** missing `ALL`, *and* its source
   `${MODULEWORKS_DIR}/PPFramework/PPFramework/pypy3.10-v7.3.16-win64` does not exist in our SDK
   copy (that folder holds only `deploy_ppf.exe`). **`ALL` was deliberately not added** — with the
   source absent it would turn a silent gap into a hard build failure. Where does PyPy come from?
2. **Is Ninja an acceptable generator?** Fix #6 exists only because `startCmake.bat` launches
   `cmake-gui`, which defaults to the Visual Studio generator, where MSBuild handles manifests
   natively. If VS-generator-only is the rule, the presets should switch and #6 be reverted.
3. **Is the `.gitkeep` approach right for #2?** With 4 of 7 modules affected, guarding the copy
   target with `if(EXISTS ...)` is arguably the honest fix — an empty `config/` means nothing.
   `.gitkeep` was chosen to keep the change minimal and behaviour identical.
4. **`main` and the ADO default branch** — revive `main` or retire it? 28 of 30 repos have a
   misleading default.
5. **Is a working Debug configuration wanted at all?** Debug builds and installs cleanly but
   cannot run: static CRT (`/MT`) in `MainApp` and all ten plugins means one CRT heap per binary,
   and the debug heap asserts on the first allocation that crosses a module boundary (details
   above). Three ways out, in increasing cost:
   - **Do nothing.** Debug the RelWithDebInfo build — it has full PDBs and it works. Costs
     nothing, keeps this branch minimal. **This is what the branch currently does**, and it is my
     recommendation unless somebody actually needs Debug.
   - **Switch the CRT to dynamic** so every binary shares one heap. The vcpkg triplet designed for
     this is `x64-windows-static-md` (static libs, dynamic CRT). It means rebuilding every vcpkg
     dependency and re-pinning `vcpkgPackages.txt`, and vcpkg has no clean per-config triplet, so
     it changes Release and RelWithDebInfo too. This is the real fix if Debug must work.
   - **Stop passing heap-owning objects across module boundaries.** Correct, and a large refactor
     of `ModuleInterface`. Not a build-environment task.

## IDE integration

`CMakePresets.json` is committed and contains **policy only — every preset is hidden**. The
selectable presets live in `CMakeUserPresets.json`, which is gitignored;
`CMakeUserPresets.json.example` is the committed template and differs only in using neutral
`D:/BuildDirectory/KLSOneMill` paths. `startCmake.bat` is **untouched** and behaves exactly as
before.

Presets: 3 configure, 6 build (3 × `all`, 3 × `install_full`), 3 workflow
(configure → build → install). Deviation from the fleet convention: the build presets build the
default target **`all`**, because `MainApp` links only `ModuleInterface` and `ModuleUtils` — the ten
plugin DLLs and every `add_custom_target(... ALL)` copy step are unreachable from it, so a pinned
target list would silently produce an app with no modules and no config data.

`install_plugins` and `install_fitting` (standalone KLSOneAnalyse) are deliberately not wired to
presets; run them with `cmake --build <dir> --target <name>`.

`.vscode/launch.json` (gitignored, `.example` committed) has entries for the installed folder per
config, for `Updater.exe`, and one that follows the CMake sidebar's launch target — the last needs
Qt and VTK on `PATH` because the build tree has no DLLs next to the exe.

## Gotchas (hard-won, don't re-learn)

- **`VCPKG_TARGET_TRIPLET` must be on the command line.** `CMakeLists.txt` sets it at line 53,
  *after* including the vcpkg toolchain at line 47, so vcpkg has already resolved the default
  dynamic `x64-windows` prefix and `find_package(cpr)` fails. `cmake-gui` users never see this —
  the triplet is already in their cache. `CMakePresets.json` sets it.
- **Derive the vcpkg port list from `#include`s, not from `find_package`.** `boost-asio` is the
  cautionary example: nothing find_package()s it, but the build fails without it. An earlier
  audit based only on `find_package` calls wrongly concluded "no new ports needed".
- **Never assume a fix from `main` still applies.** One of the four would have deleted working
  features. Build first, fix what breaks.
- **`install_full` is not fully self-contained** — it passes `--no-compiler-runtime`, so the target
  machine needs the VC redistributable.
- **The app registers the `.klso` file association to whichever build ran last.**
- **Heavy builds go through `.vscode/dev-run.cmd`** (VS x64 env + parallelism capped at cores−2 +
  below-normal priority). `dumpbin` is only on `PATH` inside that environment — a dependency check
  run outside it silently reports everything as OK.
- **Piped commands hide exit codes.** The harness reports `tee`'s status, so a failing command
  looks like exit 0. Always echo the real code inside the pipeline.
- **Never run a disk/temp cleanup while a build is in flight.** A `C:` cleanup wiped
  `%LOCALAPPDATA%\Temp` mid-build and produced 11 × `fatal error C1069: cannot read compiler
  command line` — MSVC could no longer read its own temp command files. It looks exactly like a
  source defect, and because it hits whatever happens to be compiling at that moment, the failing
  file set changes every run. Tells that it is environmental, not a code bug: the failures cluster
  in one short time window, files that *started later* compile fine, and `C:` free space jumps.
  A plain re-run fixes it; the build tree on `D:` is never damaged.
- `SubProgramRotator.cpp` emits `warning C4828` (invalid characters for codepage 65001) —
  pre-existing, harmless, not ours to fix on a minimal-change branch.
- The `CMP0167`/FindBoost warnings come from vcpkg's own wrapper, and
  `FittingAnalysisBackend: OpenXLSX not found via find_package` is a false alarm — OpenXLSX comes
  from the vendored submodule target and the module links fine.

## Change log

| When | What |
| --- | --- |
| 2026-07-29 | Clone created at `version/Beta220`; 26 submodules verified at pinned SHAs. Baseline built untouched, then 7 fixes applied one failure at a time. RelWithDebInfo builds, installs and **runs** with all 10 modules. Presets, `.gitattributes`, `.gitignore`, `.vscode` IDE files and the `vcpkgPackages.txt` pin added. `D:` cleanup reclaimed 41 GB (68.9 GB free); `D:` VHDX confirmed to survive a reboot |
| 2026-07-29 | **Debug and Release build and install cleanly too** — both workflow presets exit 0, 10 modules, 171 DLLs, 0 unresolved imports each. The 7 fixes are therefore config-independent. Corrected the ModuleWorks `deps/` count in this ledger: **57 DLLs + `mwSupport.lic`, not 67** — the old number was never right (both configs were checked and are identical, so nothing regressed). Added the `%TEMP%`-cleanup/`C1069` gotcha after losing one Debug run to it |
| 2026-07-29 | **Release launches and runs** from the installed folder — 2 of 3 configurations fully verified end to end |
| 2026-07-29 | **Debug turns out not to run**: `__acrt_first_block == header` at startup. Root cause is pre-existing — static CRT in `MainApp` + 10 plugins = 12 CRT heaps, and the debug heap catches the first cross-boundary free that Release silently tolerates. Not caused by the 7 fixes, not narrowly fixable; recorded as open item 5 with three options. Debug's "0 unresolved imports" also downgraded to a this-box-only claim, since the debug CRT is non-redistributable |
