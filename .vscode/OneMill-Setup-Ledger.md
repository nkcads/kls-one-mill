# KLSOneMill — build environment on `version/Beta220`

**This checkout: `C:\DATA\repos\intern\KLSOneMill4`, branch `version/Beta220`, created 2026-07-29.**

## Why this clone exists

An earlier attempt built the same environment on `main`. `main` is **dead** in the whole C++ tree:
superproject `main` = `a5ca137` ("Merged PR 25596: Merge RC10", 2025-12-10), **33 commits behind**
`version/Beta220`. It is still the Azure DevOps default branch on all 30 repos, which is what makes
it look alive. History is strictly linear — `main` → `version/20Beta` → `version/Beta220`, nothing
diverged — so `main` was simply never fast-forwarded. See
[OneMill-Repo-Landscape.md](OneMill-Repo-Landscape.md) next to this file for the full
branch/tag/gitlink survey.

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
| Release | ~2 s / ~1 s | 556 steps | 171 | 10 | 0 | **yes** |
| ~~Debug~~ | 1.9 s / 1.2 s | 556 steps | 171 | 10 | 0 | **no — asserted at startup; configuration removed 2026-07-30, see open item 5** |

Per config, `install_full` stages `MainApp.exe`, `Updater.exe`, all 10 modules, and gives
`ModuleMillingKalotte` and `ModulePostProcessor` **57 ModuleWorks DLLs + `mwSupport.lic`
(58 files)** each in their own `deps/`. The three `deps/` file lists are identical across configs —
the ModuleWorks SDK ships release-only binaries, so Debug links release ModuleWorks DLLs. That is
inherent to the SDK and is also how the shipping config has always been built.

Those two `deps/` folders are also the **only** correct home for `mwSupport.lic` — ModuleWorks
resolves the license from the calling DLL's own folder, never from the `MainApp.exe` folder. The
shipping `KLSOneMillFullVersion_210_Beta4` deployment does exactly the same. Every copy in the tree
originates from `$MODULEWORKS_DIR/quickstart/mwSupport.lic`, hardcoded in
`ModuleWorksSetup.cmake` (MillingBackend + PostProcessorBackend, plus a stale third copy in
MillingBackend's `ModuleDeploy.cmake`). That CMake gate only tests `EXISTS`, **not** validity — an
invalid or placeholder license passes configure silently and blows up much later inside a toolpath
generation. Keep a real license in the quickstart folder; `*.lic` is not in `.gitignore`, so never
park one inside a working tree.

Debug correctly stages the `d`-suffixed Qt and VTK binaries (`Qt6Cored.dll`,
`vtkCommonCore-9.5d.dll`, …) — both kits ship debug alongside release, so there is no
debug/release runtime mix in the staged tree, and no `*d.dll` leaks into the Release install.

**RelWithDebInfo and Release both launch and run. Debug builds and installs but does not run** —
see the CRT section below. Both working configurations were started from the `.vscode/launch.json`
"installed folder" entries, i.e. against the staged install tree, not the build tree.

> **The merged tree was re-verified and re-launched.** After the 2026-07-30 merge of Robert's VHF
> work all three configurations were rebuilt (build, install, staging, imports all green) and
> RelWithDebInfo and Release were both launched successfully from the installed-folder entries.
> Debug still asserts at startup on the pre-existing CRT problem, open item 5.

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

**This is pre-existing on `version/Beta220`, not a consequence of the eight fixes.** Our binaries
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

## The eight fixes this branch needs

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
| 8 | `ModulePostProcessorWidget` | runtime + machine | run `deploy_ppf.exe` once to create `PYPY_SOURCE`; give `CopyPostProcessorData` an `EXISTS` guard, `ALL`, a stamp file and a full-tree copy | `install_full` warned `! ModulePostProcessor/interpreter not found`. Interpreter verified: `import ppframework` succeeds, root tree identical to the shipped `KLSOneMillFullVersion_210_Beta4` install |

Only #1, #2 (for StatisticsBackend) and #7 also existed on `main`. #3 recurs; #4, #5, #6 are new
to Beta220. The MillingKalotte `SessionHandler.cpp` patch from the `main` attempt was
**deliberately not applied**: `RevolveItem.h`/`LabelItem.h` exist on Beta220 and are actively used
(`RevolveItem` at line 1009, `LabelItem` at 1371/1384), so that patch would delete working features.

## The branch: `SetupBuildEnvOnBeta220`

13 repositories, committed locally 2026-07-29, **not pushed** (no upstream on any of them).
Committed deepest-first so no gitlink ever referenced a commit that did not exist yet.

| | repo | commit | parent | content |
| --- | --- | --- | --- | --- |
| L2 | `FileTransferBackend` | `7e35773` | `63fba41` | `config/.gitkeep` |
| L2 | `FittingAnalysisBackend` | `a85b4f1` | `d1a8ab2` | `config/.gitkeep` |
| L2 | `FixtureBackend` | `f638a61` | `12b71eb` | `config/.gitkeep` |
| L2 | `StatisticsBackend` | `5f001bd` | `b7c4c21` | `config/.gitkeep` |
| L2 | `PostProcessorBackend` | `fcb462e` | `2f8fc05` | fixes 4 + 7 |
| L1 | `MainApp` | `4c8789d` | `ca920f9` | fix 6 |
| L1 | `ModuleUtils` | `9652fe4` | `b178231` | fix 3 |
| L1 | `Modules/ModuleFileTransfer` | `c699339` | `ff2caea` | gitlink only |
| L1 | `Modules/ModuleFittingAnalysis` | `ad08a46` | `2d35966` | gitlink only |
| L1 | `Modules/ModuleFixture` | `fe58c67` | `4625984` | gitlink only |
| L1 | `Modules/ModuleStatistics` | `c2fc263` | `229c326` | gitlink only |
| L1 | `Modules/ModulePostProcessor` | `c640962` | `be55836` | gitlink only |
| L0 | superproject | `e9a4d86` | `141c8b7` | fix 1, presets, pin, `.vscode`, 7 gitlink bumps |

**The branch name describes the reason, not the parent.** Only 5 of the 13 repos have a
`version/Beta220` at all (superproject, `MainApp`, `ModuleUtils`, `ModulePostProcessor`,
`PostProcessorBackend`); the other 8 are cut from their `version/20Beta` tip, which is what the
superproject pins. Say so explicitly in the PR descriptions.

**Fix 5 (`boost-asio`) is in no commit.** It is a vcpkg install action, recorded only as a line in
`vcpkgPackages.txt`. Anyone reproducing this environment has to run it by hand:
`vcpkg install boost-asio:x64-windows-static`.

### Merge 2026-07-30: Robert's "VHF HoleMilling Showcase / PP Bugfix"

Robert pushed one commit per repository (`6c04455` in the superproject, 2026-07-29) touching 16
gitlinks. Merged into this branch — **merged, not rebased**, because the branch was already pushed.
Resolved bottom-up: each submodule merged first, then its gitlink pointed at the resulting merge
commit. Superproject merge commit `2cad38c`.

| repo | merge commit | his commit |
| --- | --- | --- |
| `FileTransferBackend` | `1ccd2da` | `c9f2280` |
| `FittingAnalysisBackend` | `17d198c` | `06ec88d` |
| `FixtureBackend` | `fee099a` | `75fad5b` |
| `StatisticsBackend` | `9ac7a4e` | `3317c82` |
| `PostProcessorBackend` | `93f6e04` | `b229347` |
| `MainApp` | `4a48d1c` | `367748b` |
| `ModuleUtils` | `593fce2` | `1017174` |
| `Modules/ModuleFileTransfer` | `3a86a19` | `037be5c` |
| `Modules/ModuleFittingAnalysis` | `7a1caba` | `17dac99` |
| `Modules/ModuleFixture` | `b3ebe44` | `585210d` |
| `Modules/ModuleStatistics` | `b035d1b` | `8f415bd` |
| `Modules/ModulePostProcessor` | `58d1336` | `f9e9f13` |
| superproject | `2cad38c` | `6c04455` |

Only two files overlapped textually and both auto-merged: he added `source_group(TREE ...)` to
`ModuleUtils/CMakeLists.txt` and `PostProcessorBackend/CMakeLists.txt`, we added the Eigen3 lines.
Both changes are present in both files. His eight other gitlink bumps (`BackendUtils`,
`GeneralUtils/MeshUtils`, `ModuleMillingKalotte`, `ModuleOverlayCritter`, `ModuleReporter`,
`ModuleUpdater`, `ModuleView`, `Updater`) never overlapped this branch and merged clean.

**Re-verified after the merge**: all three configurations configure, build and install with 171
top-level DLLs, 10 module DLLs, 57 ModuleWorks DLLs + `mwSupport.lic`, and **zero unresolved
imports**. His new `MillingProgramValidatorVHF.cpp` compiles in all three and his VHF machine config
(`vhf_post.py`, `vhf5axR_v2.xml`) is staged in all three. The merge cost the build nothing.

### Decision 2026-07-30: pushed, but no pull requests yet

After a team discussion the branch is **not** being proposed for merge for now — `version/Beta220`
stays as it is. The 13 branches are pushed to their remotes so the work is backed up and visible,
but **no PRs are open** and none should be opened without revisiting the two points below.

**When PRs do get opened: merge commits only, never squash or rebase.** The parent repositories'
gitlinks point at exact commit SHAs on the child branches. A squash or rebase merge rewrites those
SHAs, so the parent's gitlink would reference a commit unreachable from the target branch and
`git submodule update --init --recursive` would break for everyone — the exact failure this branch
exists to fix (see fix 1). Either complete every PR with a real merge commit, or re-point and
re-push every gitlink after each child merge.

**Nothing in Azure DevOps enforces that.** The whole `KLS OneMill` project has 9 policy
configurations, all of them "Minimum number of reviewers" (1 approver), all scoped to
`refs/heads/main` only, on: `KLS OneMill`, `om_MainApp`, `om_ModuleUtils`, `om_ModuleView`,
`om_ModuleInterface`, `om_ModuleOverlayCritter`, `om_ModuleMillingKalotte`, `om_MillingBackend`,
`om_PostProcessorBackend`. There is **no "Require a merge strategy" policy anywhere in the
project**, so squash is not blocked — whoever completes a PR picks the strategy in the completion
dialog, and Azure DevOps remembers each user's last choice. Other projects here are squash-only, so
the habit is a real risk. If these PRs are ever opened, consider adding a temporary
"Require a merge strategy → merge commit only" policy to the target branches first.

Also note the PR targets would **not** be the default branch: `origin/HEAD` is `main` on all 30
repos, and `main` is dead (see the top of this file). Targets are `version/Beta220` for the
superproject, `om_MainApp`, `om_ModuleUtils`, `om_ModulePostProcessor` and
`om_PostProcessorBackend`, and `version/20Beta` for the other 8, which have no `version/Beta220`.
Neither target branch carries any policy today.

## Open — needs the dev lead

1. ~~**The PostProcessor Python interpreter is missing.**~~ **Resolved 2026-07-30 — see fix #8.**
   PyPy comes from `deploy_ppf.exe`, which sits in that same SDK folder and is not a leftover: it is
   a 64 MB PyInstaller deployer whose embedded payload is `data\pypy3.10-v7.3.16-win64.zip` plus
   `ppframework-2.17.0.dev3-pp310-none-any.whl`, msgpack, semver, typing_extensions and pip. Run it
   once per machine, fully offline, and `PYPY_SOURCE` resolves. **pypy.org is a dead end** — the
   stock interpreter would satisfy the CMake glob and then fail at post time with
   `ModuleNotFoundError: ppframework`, because that wheel is licensed ModuleWorks code, is not on
   PyPI, and its `pp310` ABI tag pins it to PyPy 3.10 exactly (hence the hardcoded `v7.3.16` path).
   A git submodule was considered and rejected: submodules need a git remote, PyPy ships release
   zips, and the upstream repo is *source* that would have to be built.
2. **Is Ninja an acceptable generator?** Fix #6 exists only because `startCmake.bat` launches
   `cmake-gui`, which defaults to the Visual Studio generator, where MSBuild handles manifests
   natively. If VS-generator-only is the rule, the presets should switch and #6 be reverted.
3. **Is the `.gitkeep` approach right for #2?** With 4 of 7 modules affected, guarding the copy
   target with `if(EXISTS ...)` is arguably the honest fix — an empty `config/` means nothing.
   `.gitkeep` was chosen to keep the change minimal and behaviour identical.
4. **`main` and the ADO default branch** — revive `main` or retire it? 28 of 30 repos have a
   misleading default.
5. **Is a working Debug configuration wanted at all?** **Debug was removed on 2026-07-30** — presets,
   tasks and launch entry are gone. It built and installed cleanly but could not run: static CRT
   (`/MT`) in `MainApp` and all ten plugins means one CRT heap per binary, and the debug heap asserts
   on the first allocation that crosses a module boundary (details above). Reviving it means picking
   one of these first — re-adding the presets alone just recreates a configuration nobody can run:
   - **Leave it removed.** Debug the RelWithDebInfo build — it has full PDBs and it works. Costs
     nothing. **This is what the branch does**, and it is my recommendation unless somebody actually
     needs Debug.
   - **Switch the CRT to dynamic** so every binary shares one heap. The vcpkg triplet designed for
     this is `x64-windows-static-md` (static libs, dynamic CRT). It means rebuilding every vcpkg
     dependency and re-pinning `vcpkgPackages.txt`, and vcpkg has no clean per-config triplet, so
     it changes Release and RelWithDebInfo too. This is the real fix if Debug must work.
   - **Stop passing heap-owning objects across module boundaries.** Correct, and a large refactor
     of `ModuleInterface`. Not a build-environment task.
6. **Feature visibility depends on hardcoded computer names — worth retiring.** Whether a developer
   sees the VHF machine, or gets debug geometry dumps, is decided by their `COMPUTERNAME` appearing
   in one of two unrelated source-level whitelists (details in Gotchas). Consequences: a correct
   build looks broken next to a colleague's, new machines silently lack features, and every new PC
   needs a commit in shared code. Both flags already have Config-window checkboxes, so the
   whitelists only decide the *initial* state. Reading that initial state from
   `mainAppConfig.json` instead would remove the need for anyone's name to be in the source.
   **Deliberately not changed on this branch** — it is app behaviour in shared code, not build
   environment.
7. **The version in the title bar is an install counter.** `update_version_json()` in
   `cmake/install_app.cmake.in` increments it on every install, so it reports `1.0.3` — meaning
   "installed three times here" — while the repository is at `2.1.0` and `releaseNotes/v22_0.md`
   implies 22.0 (details in Gotchas). It is per-developer and per-install-tree, so it can never
   identify a build, and it will keep climbing forever. Either wire it to the real project version or
   drop it from the title bar; the auto-increment is worse than showing nothing.
8. **The stray `Modules/ModuleTemplate` gitlink keeps coming back — fix it at the source.**
   Fix 1 removed it; Robert's `6c04455` re-added it a day later, and the 2026-07-30 merge dropped it
   again. It is not a template repository: its before and after SHAs are **byte-identical to
   `Modules/ModuleFixture`**, so the gitlink points at `om_ModuleFixture`. Someone created
   `Modules/ModuleTemplate` by copying the `ModuleFixture` directory *including its `.git`*, so
   `git commit -a` keeps picking the nested repository up as a gitlink. Because it has no
   `.gitmodules` entry, its mere presence makes `git submodule update --init --recursive` abort with
   `fatal: No url found for submodule path` and clone **nothing at all** — this is the single change
   that most reliably breaks a clean checkout for everybody. Removing it from the superproject is
   only a symptom fix; whoever has that directory locally has to delete it, or add it to
   `.gitignore`, otherwise it returns on the next `git commit -a`.

## IDE integration

`CMakePresets.json` is committed and contains **policy only — every preset is hidden**. The
selectable presets live in `CMakeUserPresets.json`, which is gitignored;
`CMakeUserPresets.json.example` is the committed template and differs only in using neutral
`D:/BuildDirectory/KLSOneMill` paths. `startCmake.bat` is **untouched** and behaves exactly as
before.

Presets, **RelWithDebInfo and Release only** (no Debug — open item 5): 2 configure, 4 build
(2 × `all`, 2 × `install_full`), 2 workflow (configure → build → install). Deviation from the fleet
convention: the build presets build the default target **`all`**, because `MainApp` links only
`ModuleInterface` and `ModuleUtils` — the ten plugin DLLs and every `add_custom_target(... ALL)` copy
step are unreachable from it, so a pinned target list would silently produce an app with no modules
and no config data.

`install_plugins` and `install_fitting` are deliberately not wired to presets; run them with
`cmake --build <dir> --target <name>`. **`install_fitting`** deploys a *second product* from the same
build — **KLSOneAnalyse** — into `INSTALL_DIR_FITTING` (`CACHE PATH`, `CMakeLists.txt:247`): the same
`MainApp.exe` with only `ModuleView`, `ModuleStatistics` and `ModuleFittingAnalysis` enabled, no
ModuleWorks `deps/`, and `applicationName` rewritten to `KLSOneAnalyse` by `update_version_json()`.
It works by configuring `install_app.cmake.in` a *second* time with overridden `INSTALL_MOD_*`
options, which is why `INSTALL_DIR` is reassigned at line 252 — that reassignment does not affect the
already-configured `install_full` script. The bare CMakeLists default
(`D:/deployData/KLSOneAnalyse`) has **no config suffix**, so all configurations would overwrite each
other; `CMakeUserPresets.json.example` overrides it per config, so preset users are fine.

### Tasks (`.vscode/tasks.json`, committed)

6 tasks: `Build | …` and `Install | …` for RelWithDebInfo and Release, plus
**`Cold start | … | <config>`** for each, which runs the *workflow* preset.

`Cold start` exists because `cmake --build --preset` **never configures**: on a fresh clone, or after
deleting the build directory, `Build`/`Install` fail with `<dir> is not a directory`. Cold start is
the **only** recovery action — there is deliberately no separate Configure task, so the question
"which one do I run" cannot arise, and no `--fresh` variant either: a changed toolchain path in
`CMakeUserPresets.json` is handled by wiping the build and install directories and cold-starting,
which is one concept instead of two.

There is deliberately **no Clean task**. `cmake --build --target clean` would not clean what matters:
the per-module `add_custom_target(... ALL)` steps copy `config/`, `releaseNotes/` and the ModuleWorks
`deps/` folders into `bin/<config>/modulesBert/`, and Ninja does not track those as outputs, so they
would survive. A half-clean that leaves stale plugin data behind produces bugs that look like code
bugs. A wipe task was also rejected: it would have to resolve `binaryDir` out of the gitignored
`CMakeUserPresets.json` (parse the preset JSON, walk `inherits`, expand `${sourceDir}`) because the
paths are machine-specific and cannot be hardcoded in a committed file — and a path-resolution bug
there deletes the wrong directory. Deleting two folders by hand is rare, unambiguous, and now
recoverable via Cold start. Both decisions are documented in `README.md` and in the `tasks.json`
header so nobody re-litigates them.

`.vscode/launch.json` (gitignored, `.example` committed) has entries for the installed folder per
config, for `Updater.exe`, and one that follows the CMake sidebar's launch target — the last needs
Qt and VTK on `PATH` because the build tree has no DLLs next to the exe.

## Gotchas (hard-won, don't re-learn)

- **The CMake sidebar cannot run this project's install.** CMake Tools substitutes its own
  status-bar target into **every** build step, including each step of a `workflowPresets` chain.
  Clicking *Workflow → Install | Win | MSVC | x64 | RelWithDebInfo* produced
  `--build … --target MainApp --` **twice** — once where the preset says `all`, once where it says
  `install_full` — then reported success having installed nothing (evidence: `.vscode/out.log`,
  2026-07-30). There is no chip value that satisfies both steps, so the sidebar is structurally
  unable to do it. Use `.vscode/tasks.json` (Ctrl+Shift+B) or
  `cmake --workflow --preset onemill-install-win-msvc-x64-relwithdebinfo`. Note `--fresh` is
  opt-in, so the workflow reuses the existing build tree. Two mitigations landed with fix #8:
  `install_full` now depends on every buildable target, and the install script fails hard instead
  of warning — so this failure mode can no longer be silent.
- **Two Qt 6.10.2 installations exist on this box.** The presets pin
  `D:/DevTools/Qt/6.10.2/msvc2022_64` via `Qt6_DIR`/`QTDIR`, but `C:/Qt/6.10.2/msvc2022_64` also
  exists (and carries `Src/`, which the `D:` one does not). Harmless while `Qt6_DIR` is explicit —
  dangerous the moment something resolves Qt via `PATH` or a hint-less `find_package`.
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
- **No VHF machine in the dropdowns? Tick "Test Mode" in the Config window.** `VHF-R5.json` is the
  only machine with `"isTest": true`, and `MachineDataConfiguration.cpp` (lines 297 and 315) filters
  test-only machines out of the region and material combo boxes whenever the app is in
  `MillingApplicationMode::Common`, which is the default. The checkbox
  (`ConfigWindow::onCheckBoxTestMode` → `ToolManager::setApplicationMode`) is always available and
  never hidden. `ConfigWindow::InitSettings()` pre-ticks it **only on `COMPUTERNAME == "CADS11"`**,
  so a developer on that machine has it on permanently and never discovers the switch — which is
  exactly why a build can look "wrong" next to theirs when it is identical.
- **Two unrelated machine-name whitelists, and both have a checkbox that does the same job.**
  `ConfigWindow::InitSettings()` pre-ticks Test Mode on `CADS11`. Separately
  `ConfigHandler.h`'s `AppConfig` ctor sets `isTestComputer` on `CADS-5384`, `CADS11` and
  `CADS-5479`; that one feeds `IsDebugComputer()`, used in ~16 places in `ContourBuilder`,
  `ContourBuilderUV`, `LinkGenerator*`, `GeometricCurveExpander` and `RawPartEdgePlaneGenerator` to
  dump debug geometry during milling generation. **It has nothing to do with the machine list.**
  Adding a computer there is a bad trade: the dump target `D:/devData/KLS/KLSOneMill/debugData` is
  hardcoded and the `CheckOrCreateDirectory` call that would create it is commented out, and
  `IsDebugComputer()` returns `false` outright when `RELEASE_VERSION` is defined
  (`MainApp/CMakeLists.txt` sets it for Release). Use the Config window's **Debug Mode** checkbox
  instead — `SetDebugMode()` sets the same flag at runtime *and* prompts for a directory that
  actually exists.
- **The version in the title bar is an install counter, not a version.** `update_version_json()` in
  `cmake/install_app.cmake.in` (line 101) reads `config/mainAppConfig.json` from the *install*
  folder, seeds it with `"version": "1.0.0"` if absent, and then **increments the last integer
  component on every single install**, logging `[+] config/mainAppConfig.json (1.0.2 → 1.0.3)`. The
  same function patches `applicationName`, which is how `install_fitting` rebrands the identical
  `MainApp.exe` as `KLSOneAnalyse`. So `1.0.3` means "`install_full` has run three times in this
  tree" — it is per-install-tree and per-developer, and the number appears nowhere in the source
  because it is generated. That is why the three install trees on this machine disagreed
  (RelWithDebInfo `1.0.3`, Release and Debug `1.0.2`) despite identical source built minutes apart.
  The title bar therefore reads `1.0.3` while the repository is at `2.1.0`. **Never use it to
  identify a build**; use the build date, which `BuildTitleBarContent()` appends from `__DATE__`, or
  the superproject gitlink SHA.
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
| 2026-07-29 | **Debug and Release build and install cleanly too** — both workflow presets exit 0, 10 modules, 171 DLLs, 0 unresolved imports each. The build-environment fixes are therefore config-independent. Corrected the ModuleWorks `deps/` count in this ledger: **57 DLLs + `mwSupport.lic`, not 67** — the old number was never right (both configs were checked and are identical, so nothing regressed). Added the `%TEMP%`-cleanup/`C1069` gotcha after losing one Debug run to it |
| 2026-07-29 | **Release launches and runs** from the installed folder — 2 of 3 configurations fully verified end to end |
| 2026-07-30 | **Debug configuration removed** (presets, tasks, launch entry, docs, and the local gitignored copies) — it built and installed but could never run, so keeping it only invited the assertion again. The CRT analysis stays as open item 5, rewritten as what reviving it would require. **Added `Cold start` tasks** for both remaining configurations, after `cmake --build --preset` failed with `<dir> is not a directory` on a wiped build tree — that error had no recovery entry in the task list. Deliberately **no Configure task, no Clean task, no wipe task and no `--fresh` variant**; reasoning recorded under IDE integration, in `README.md` and in the `tasks.json` header. **Corrected this ledger**: the title-bar version is not round-tripped runtime state — it is an install counter that `update_version_json()` increments on every install (open item 7). Documented `INSTALL_DIR_FITTING` / `install_fitting` (the KLSOneAnalyse deployment) |
| 2026-07-29 | Branch `SetupBuildEnvOnBeta220` created and committed across **13 repositories** (not 11 — 5 wrapper repos exist only to carry a gitlink bump upward). All 26 gitlinks in sync afterwards, every working tree clean |
| 2026-07-30 | Team decision: **no pull requests for now**, `version/Beta220` stays as it is. All 13 branches pushed to their remotes for backup and visibility. Recorded the ADO policy survey and the merge-commit-only constraint above, since nothing in Azure DevOps enforces it |
| 2026-07-30 | **Merged Robert's `6c04455`** ("VHF HoleMilling Showcase / PP Bugfix") into the branch, bottom-up, 13 merge commits, superproject `2cad38c`. 8 gitlink conflicts + 1 modify/delete, no textual conflicts survived. All three configurations re-built and re-verified green. `Modules/ModuleTemplate` deletion kept — recurrence recorded as open item 8. Merge commits kept **local** pending a launch check |
| 2026-07-30 | **The ModuleWorks license was my own 16-byte placeholder** ("DUMMY by SCHACHI"), which is why toolpath generation died with "License file marker is missing!" (KOM-8). Placement was never wrong — the shipping `KLSOneMillFullVersion_210_Beta4` deployment keeps `mwSupport.lic` in the same two `modulesBert/<Module>/deps/` folders our build produces, and nothing next to `MainApp.exe`. Took the real 6096-byte license (CADS GmbH, BuildVersion 2025.12.1.3, no hardware key, perpetual) out of that deployment into `$MODULEWORKS_DIR/quickstart/` plus all 12 live `deps/` folders. Versions match: Beta4's MW DLLs are the identical build to our SDK (2025.12.1.2 / 2025.12.A6.2511200753). Repro retest still open |
| 2026-07-30 | **The missing PostProcessor interpreter is solved** (open item 1 → fix #8). `deploy_ppf.exe` in the SDK turned out to be the source: an offline PyInstaller deployer bundling `pypy3.10-v7.3.16-win64.zip` + the licensed `ppframework` PyPy wheel. Ran it in place (`--no-Config.GUI --Config.OFFLINE --Config.PYPY_TO_INSTALL PyPy310`); the resulting tree imports `ppframework` 2.17.0-dev3 and its root is **identical** to the interpreter in Robert's shipped `KLSOneMillFullVersion_210_Beta4`. Note the deployer writes a `deploy_ppf.ini` next to itself pinning `INTERPRETER`, so a second run upgrades that install instead of creating a new one — run it from the target folder. `CopyPostProcessorData` reworked: `EXISTS` guard with an actionable warning, `ALL`, a stamp file (a bare `ALL` custom target would re-copy 153 MB every build) and a full-tree copy instead of the old `*.dll` + `pypy3.exe` + `Lib/` subset. The subset was measured to work (141 MB, `import ppframework` fine) but omits `tcl/`, `Scripts/`, `include/`, `libs/`, `shared/` — 12 MB to match what actually ships. **Not yet rebuilt/installed** |
| 2026-07-30 | **Install made self-sufficient and fail-fast; VS Code entry points added.** All three install targets declared only `DEPENDS MainApp Updater` (`install_fitting`: just MainApp), and MainApp links neither the plugin DLLs nor the `ALL` copy targets — so an install target staged whatever was left in `bin/`. `install_full`, `install_plugins` and `install_fitting` now each depend on every buildable target under `Modules/` (walk, not a hand list, so new modules are covered; scoped to `Modules/` deliberately — a whole-tree walk would drag in OpenXLSX's Doxygen `Documentation` target and its `EXCLUDE_FROM_ALL` benchmarks). `install_app.cmake.in` now **fails hard** on a missing module DLL, `Updater.exe`, `deps/` or `interpreter/` with a payload-specific remediation, instead of warning and exiting 0 — the mechanism that let the interpreter gap survive. Added `.vscode/tasks.json` (6 tasks through `dev-run.cmd`, `$msCompile` matcher, **no bare `--parallel`**), a root `README.md`, the fleet `.editorconfig`, and `.vscode/OneMill-Fleet-Conformance.md` recording which CADS Superbuild rules apply here and which are deliberately rejected (vcpkg above all). Fleet spec reviewed at `SuperbuildEngine@d6b4a31`. **Not yet reconfigured or rebuilt** |
| 2026-07-29 | **Debug turns out not to run**: `__acrt_first_block == header` at startup. Root cause is pre-existing — static CRT in `MainApp` + 10 plugins = 12 CRT heaps, and the debug heap catches the first cross-boundary free that Release silently tolerates. Not caused by the build-environment fixes, not narrowly fixable; recorded as open item 5 with three options. Debug's "0 unresolved imports" also downgraded to a this-box-only claim, since the debug CRT is non-redistributable |
