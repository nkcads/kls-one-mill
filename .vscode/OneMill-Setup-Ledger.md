# KLSOneMill — build environment on `version/Beta220`

**This checkout: `C:\DATA\repos\intern\KLSOneMill4`, created 2026-07-29 from `version/Beta220`,
now on branch `SetupBuildEnvOnBeta220`.**

## Why this clone exists

An earlier attempt built the same environment on `main`. `main` is **dead** in the whole C++ tree:
superproject `main` = `a5ca137` ("Merged PR 25596: Merge RC10", 2025-12-10), **33 commits behind**
`version/Beta220`. It is still the Azure DevOps default branch on all 30 repos, which is what makes
it look alive. History is strictly linear — `main` → `version/20Beta` → `version/Beta220`, nothing
diverged — so `main` was simply never fast-forwarded. See
[OneMill-Repo-Landscape.md](OneMill-Repo-Landscape.md) next to this file for the full
branch/tag/gitlink survey.

`version/Beta220` is the live branch, and as of 2026-07-31 **every** repo in the branch set has one
(see the branch section — this changed under us).

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

## Status

**Both IDEs are verified working paths** as of 2026-07-31 — VS Code and Visual Studio, same
checkout, same presets, same build directory. See [IDE integration](#ide-integration).

**Both configurations green and current**, each rebuilt from a wiped tree through its `Cold start`
workflow preset on 2026-07-31, after the KOM-10 warning fixes. Every workflow step exit 0, zero
compiler and linker errors.

| | configure / generate | build steps | build tree | install tree | warnings | app launched |
| --- | --- | --- | --- | --- | --- | --- |
| RelWithDebInfo | 8.1 s / 1.2 s | 564 | 7437 files, 5.20 GB | 6594 files, 1.73 GB | see below | **yes** |
| Release | 14.4 s / 2.7 s | 564 | 7333 files, 2.30 GB | 6594 files, 1.66 GB | **10 + 4** | **yes** |

Both install trees carry 171 top-level DLLs, 10 module DLLs, 58 files in each ModuleWorks `deps/`,
`MainApp.exe` + `Updater.exe`, the PyPy interpreter, and no debug-CRT DLL leakage. 564 steps rather
than the 556 of 2026-07-29 because fix #8 wired the install targets to every buildable target under
`Modules/`. Release is smaller purely for lack of PDBs.

**The post-fix warning count is measured, not estimated: 99 → 14.** The Release cold start was a
clean build, so its 10 compiler + 4 CMake warnings are the real remaining set, and every one is
already tracked — 5 third-party (4 from `flann` via `ConcaveHullHelper.cpp:420/546`, 1 from vendored
`XLCellReference.cpp:385`), 5 ours and parked in KOM-11 (3 × `wchar_t`→`char` in
`StringHelper.cpp:329`, `ModuleWorksCreator.cpp:1257`, `ModuleWorksHolder.cpp:1217`; 2 × C4834 in
`EnvironmentHandler.cpp:24` and `MillingGenerator.cpp:1674`), plus the 3 × CMP0167 and the OpenXLSX
false alarm. **C4828, C4838 and C4005 are gone entirely.** Nothing unexpected survived the fixes.

Both configurations were also **launched and exercised from their installed folders** after this
rebuild, not just built — so the KOM-10 changes are verified end to end in the configuration that
ships, not only at compile time.

Historical, 2026-07-29, all three configurations then existing, every workflow step exit 0:

| | configure+generate | build | top-level DLLs | module DLLs | unresolved imports | app launched |
| --- | --- | --- | --- | --- | --- | --- |
| RelWithDebInfo | 1.9 s / 1.3 s | 556 | 171 | 10 | 0 | **yes** |
| Release | ~2 s / ~1 s | 556 | 171 | 10 | 0 | **yes** |
| ~~Debug~~ | 1.9 s / 1.2 s | 556 | 171 | 10 | 0 | **no — asserted at startup; removed 2026-07-30, open item 5** |

Per config, `install_full` stages `MainApp.exe`, `Updater.exe`, all 10 modules, and gives
`ModuleMillingKalotte` and `ModulePostProcessor` **57 ModuleWorks DLLs + `mwSupport.lic`
(58 files)** each in their own `deps/`. The lists were identical across configs — the ModuleWorks SDK
ships release-only binaries, so even Debug linked release ModuleWorks DLLs. That is inherent to the
SDK and is how the shipping config has always been built.

Those two `deps/` folders are also the **only** correct home for `mwSupport.lic` — ModuleWorks
resolves the license from the calling DLL's own folder, never from the `MainApp.exe` folder, and the
shipping `KLSOneMillFullVersion_210_Beta4` deployment does the same. Every copy originates from
`$MODULEWORKS_DIR/quickstart/mwSupport.lic`, hardcoded in `ModuleWorksSetup.cmake` (MillingBackend +
PostProcessorBackend, plus a stale third copy in MillingBackend's `ModuleDeploy.cmake`). That CMake
gate only tests `EXISTS`, **not** validity — an invalid or placeholder license passes configure
silently and blows up much later inside a toolpath generation. Keep a real license in the quickstart
folder; `*.lic` is not in `.gitignore`, so never park one inside a working tree.

Dependency-walk method, for repeating it: recursive `dumpbin /dependents` over each installed
module, resolving against install root + `modulesBert\` + that module's `deps\` + `System32`, with
**System32 DLLs treated as terminal**. Recursing *into* OS DLLs instead reports 5 phantom misses per
module (`AzureAttestManager`, `AzureAttestNormal`, `HvsiFileTrust`, `PdmUtilities`, `wpaxholder`) —
delay-load imports of Windows' own components, absent from every Windows box, bound only if actually
called. Not ours, not a problem.

### Debug does not run: static CRT vs. the plugin architecture

Kept because it is the whole content of open item 5. Launching the installed Debug build died
immediately in `debug_heap.cpp:996`, `Expression: __acrt_first_block == header` — a heap block
allocated by one CRT instance freed by a different one. `dumpbin /dependents` showed why:

| binary | CRT |
| --- | --- |
| `MainApp.exe` + all 10 module DLLs | **static** — zero CRT imports (`/MTd` there, `/MT` elsewhere) |
| `Qt6Cored.dll`, `vtkCommonCore-9.5d.dll` | **dynamic debug** — `ucrtbased`, `MSVCP140D`, `VCRUNTIME140D` |
| ModuleWorks `mwgeolib.dll` and siblings | **dynamic release** — `MSVCP140`, `VCRUNTIME140` |

With `/MT` the CRT is linked *into each binary*, so the process holds **12 independent CRT heaps**:
one in `MainApp.exe`, one per plugin, plus the dynamic one Qt and VTK share. Release and
RelWithDebInfo survive only by luck — since the VS2015 UCRT refactor both static and dynamic UCRT
allocate from the *process default heap*, so a cross-heap free usually happens to work. The debug
heap adds per-instance bookkeeping, so the first cross-boundary free asserts.

**Pre-existing on `version/Beta220`, not caused by the eight fixes** — our binaries are static-CRT in
every configuration including the RelWithDebInfo that runs fine, and the static-runtime choice is the
project's own (see `CLAUDE.md`). The fixes merely made Debug *reachable*, which is how a latent
problem became visible. Not narrowly fixable either: it is `/MT` plus a plugin architecture that
passes heap objects across DLL boundaries.

Also, **the Debug install was never deployable off this machine**: `ucrtbased.dll`, `msvcp140d.dll`
and `vcruntime140d.dll` are the non-redistributable debug CRT and resolved only because VS and the
Windows SDK are installed here. Its "0 unresolved imports" was a statement about this box only.

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

Only #1, #2 (for StatisticsBackend) and #7 also existed on `main`. #3 recurs; #4, #5, #6 are new to
Beta220. The MillingKalotte `SessionHandler.cpp` patch from the `main` attempt was **deliberately not
applied**: `RevolveItem.h`/`LabelItem.h` exist on Beta220 and are actively used (`RevolveItem` at
line 1009, `LabelItem` at 1371/1384), so that patch would delete working features.

**Fix 1 is only half-done.** `.claude/` is in `.gitignore`, but `.gitignore` does not untrack, and
**`.claude/settings.local.json` is still tracked** in the superproject. A file whose name says
machine-local is committed and will keep travelling between developers. Either `git rm --cached` it
or accept it deliberately.

**Fix 5 (`boost-asio`) is in no commit.** It is a vcpkg install action, recorded only as a line in
`vcpkgPackages.txt`. Anyone reproducing this environment runs it by hand:
`vcpkg install boost-asio:x64-windows-static`.

## The branch: `SetupBuildEnvOnBeta220`

Created 2026-07-29 across 13 repositories, committed deepest-first so no gitlink ever referenced a
commit that did not exist yet. Pushed 2026-07-30 (see the decision below); every repo now has an
`origin/SetupBuildEnvOnBeta220` upstream. The 2026-07-31 warning sweep added three more repos, so
**the branch now spans 16 repositories**.

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

**The branch name describes the reason, not the parent.** When it was cut, only 5 repos had a
`version/Beta220` (superproject, `MainApp`, `ModuleUtils`, `ModulePostProcessor`,
`PostProcessorBackend`) and the other 8 were cut from their `version/20Beta` tip — which is exactly
what the parent column above shows.

> **That is no longer true, and it changes the PR targets.** Re-checked 2026-07-31 with `ls-remote`:
> **all 16 repos now have a `version/Beta220`**, and in the 8 that lacked one its tip is precisely
> Robert's VHF commit (`037be5c`, `c9f2280`, `17dac99`, `06ec88d`, `585210d`, `75fad5b`, `8f415bd`,
> `3317c82`) — his 2026-07-29 push created it there. So **every PR would target `version/Beta220`**,
> not `version/20Beta`. Their `version/20Beta` branches still exist and still point at the parent
> SHAs above, so the history in this table stays valid. None of our commits have reached
> `version/Beta220` in any repo — verified with `branch --contains`.

### Merge 2026-07-30: Robert's "VHF HoleMilling Showcase / PP Bugfix"

Robert pushed one commit per repository (`6c04455` in the superproject, 2026-07-29) touching 16
gitlinks. **Merged, not rebased**, because the branch was already pushed. Resolved bottom-up: each
submodule merged first, then its gitlink pointed at the resulting merge commit. 13 merge commits,
8 gitlink conflicts + 1 modify/delete, no textual conflict survived.

| repo | merge | his | repo | merge | his |
| --- | --- | --- | --- | --- | --- |
| `FileTransferBackend` | `1ccd2da` | `c9f2280` | `ModuleUtils` | `593fce2` | `1017174` |
| `FittingAnalysisBackend` | `17d198c` | `06ec88d` | `Modules/ModuleFileTransfer` | `3a86a19` | `037be5c` |
| `FixtureBackend` | `fee099a` | `75fad5b` | `Modules/ModuleFittingAnalysis` | `7a1caba` | `17dac99` |
| `StatisticsBackend` | `9ac7a4e` | `3317c82` | `Modules/ModuleFixture` | `b3ebe44` | `585210d` |
| `PostProcessorBackend` | `93f6e04` | `b229347` | `Modules/ModuleStatistics` | `b035d1b` | `8f415bd` |
| `MainApp` | `4a48d1c` | `367748b` | `Modules/ModulePostProcessor` | `58d1336` | `f9e9f13` |
| | | | superproject | `2cad38c` | `6c04455` |

Only two files overlapped textually and both auto-merged: he added `source_group(TREE ...)` to
`ModuleUtils/CMakeLists.txt` and `PostProcessorBackend/CMakeLists.txt`, we added the Eigen3 lines;
both changes are present in both files. His eight other gitlink bumps (`BackendUtils`,
`GeneralUtils/MeshUtils`, `ModuleMillingKalotte`, `ModuleOverlayCritter`, `ModuleReporter`,
`ModuleUpdater`, `ModuleView`, `Updater`) never overlapped and merged clean. `Modules/ModuleTemplate`
was re-added by him and dropped again — open item 9.

Re-verified after the merge: all three configurations built and installed with 171 top-level DLLs,
10 module DLLs, 57 MW DLLs + `mwSupport.lic`, zero unresolved imports; his
`MillingProgramValidatorVHF.cpp` compiled and his VHF machine config (`vhf_post.py`,
`vhf5axR_v2.xml`) staged. The merge cost the build nothing.

### Decision 2026-07-30: pushed, but no pull requests yet

After a team discussion the branch is **not** being proposed for merge for now — `version/Beta220`
stays as it is. The branches are pushed so the work is backed up and visible, but **no PRs are open**
and none should be opened without revisiting the two points below.

**When PRs do get opened: merge commits only, never squash or rebase.** Parent gitlinks point at
exact commit SHAs on the child branches. A squash or rebase rewrites those SHAs, so the parent's
gitlink would reference a commit unreachable from the target branch and
`git submodule update --init --recursive` would break for everyone — the exact failure fix 1 exists
to repair. Either complete every PR with a real merge commit, or re-point and re-push every gitlink
after each child merge.

**Nothing in Azure DevOps enforces that.** The whole `KLS OneMill` project has 9 policy
configurations, all "Minimum number of reviewers" (1 approver), all scoped to `refs/heads/main` only,
on `KLS OneMill`, `om_MainApp`, `om_ModuleUtils`, `om_ModuleView`, `om_ModuleInterface`,
`om_ModuleOverlayCritter`, `om_ModuleMillingKalotte`, `om_MillingBackend`, `om_PostProcessorBackend`.
There is **no "Require a merge strategy" policy anywhere in the project**, so squash is not blocked —
whoever completes a PR picks the strategy, and ADO remembers each user's last choice. Other projects
here are squash-only, so the habit is a real risk. Consider adding a temporary "Require a merge
strategy → merge commit only" policy to the target branches first.

Note the targets would **not** be the default branch: `origin/HEAD` is `main` on all 30 repos and
`main` is dead. Every target is `version/Beta220` (see the correction above), and none of those
branches carries any policy today.

### Warning sweep 2026-07-31 (KOM-10 done, KOM-11 open)

A clean RelWithDebInfo cold start produced **99 warnings** — 95 compiler across 72 distinct
locations, plus 4 from CMake. No linker warnings. Every compiler warning was attributed to an owning
file by following MSVC's instantiation-context notes, not the header line it is reported at.

| code | n | verdict |
| --- | --- | --- |
| C4828 | 55 | 14 Windows-1252 files; **all 48 bad bytes in comments, none in a string literal** |
| C4267 | 16 | 15 from `MeshTriangle`'s `int` ctor params vs its `size_t triIndex[3]`; 1 from `flann` |
| C4838 | 12 | 4 braced inits in the binary-STL writer (3 elements each) — intentional narrowing |
| C4244 | 9 | 2 `ContourBuilder` arg types, 3 `wchar_t`→`char` truncations, 4 third-party |
| C4834 | 2 | **two real defects** — `std::runtime_error(...)` built and discarded, no `throw` |
| C4005 | 1 | `_USE_MATH_DEFINES` redefined in a file whose target already defines it |

**KOM-10 fixed 85 of the 95** with no behaviour change: the encoding pass, `MeshTriangle` indices
`int`→`size_t` (the members were already `size_t`, so the old code narrowed and immediately widened
back), explicit `static_cast<float>` in the STL writer, `hullValue` `double`→`int` at all three call
sites, and the duplicate macro removed. **Verified in both configurations** — RelWithDebInfo rebuilt
and launched, Release rebuilt from a wiped tree afterwards, which is where the **measured** 99 → 14
result comes from (see Status). The 10 surviving compiler warnings are exactly the 5 third-party ones
and the 5 in KOM-11; C4828, C4838 and C4005 are gone entirely.

Encoding conversions were byte-surgical — valid UTF-8 and ASCII including line endings copied
verbatim, only invalid bytes decoded as CP1252 — and each file was checked twice before writing:
valid UTF-8 afterwards, *and* decoding to text identical to the CP1252 reading. Before widening the
`MeshTriangle` parameters all 26 construction sites were checked for three literal zeros (would have
gone ambiguous against the `int*` overload, since `0` is a null pointer constant), for brace-init and
for negative literals. None existed.

**KOM-11 holds what was left out**, because each item changes runtime behaviour: the two missing
`throw`s and the three `wchar_t`→`char` truncations (open item 10). Also parked there: `CMP0167`, the
OpenXLSX false alarm and the third-party suppressions.

**Do not add project-wide `/wd4267 /wd4244 /wd4838`, and no `/WX` until KOM-11 is settled.** Those
three codes are exactly what surfaced the two genuine type bugs.

Branched, committed and pushed as `KOM-10-fixing-warnings` across 8 repositories, then
fast-forwarded into `SetupBuildEnvOnBeta220` and the remote topic branches deleted, the way a
completed PR would.

| | repo | commit | parent | content |
| --- | --- | --- | --- | --- |
| L2 | `MillingBackend` | `630890f` | `418dfc0` | 7 encodings + `ContourBuilder` + `_USE_MATH_DEFINES` |
| L2 | `PostProcessorBackend` | `c894921` | `93f6e04` | 1 encoding |
| L1 | `GeneralUtils/MeshUtils` | `21695bc` | `2aed334` | 3 encodings + `Mesh.h` + `Mesh.cpp` |
| L1 | `Modules/ModuleMillingKalotte` | `115f321` | `4db7cc8` | gitlink only |
| L1 | `Modules/ModulePostProcessor` | `cdc13e4` | `dd94621` | 1 encoding + gitlink |
| L1 | `Modules/ModuleFixture` | `0418bb3` | `b3ebe44` | 1 encoding |
| L1 | `Modules/ModuleFileTransfer` | `4dd6a29` | `3a86a19` | 1 encoding |
| L0 | superproject | `322651b` | `a1f70ad` | 5 gitlink bumps |

**Fast-forward, not `--no-ff`, on purpose.** A merge commit in a child gives that child a new SHA,
which forces every parent gitlink to be re-bumped and produces a second round of commits in the
parents. FF keeps each child's tip identical to the SHA its parent already records, so the chain
stays valid with zero extra commits — and no SHA is rewritten either way, which is what the
merge-commit-only rule actually protects.

**Three of the eight had no `SetupBuildEnvOnBeta220`** — `GeneralUtils/MeshUtils`,
`Modules/ModuleMillingKalotte` and `MillingBackend` were untouched by the original branch and sat at
the detached SHA the superproject pins. They were branched from that SHA (each verified to be on
`origin/version/Beta220` first, so nothing was built on an orphan) and now carry the branch for the
first time. **Before deleting any topic branch, confirm its commits are reachable from a *pushed*
`SetupBuildEnvOnBeta220`** — that ordering was verified here before any delete, because an
unreachable gitlink target is exactly the fix-1 failure that breaks a clean checkout for everybody.

## Open — needs the dev lead

1. ~~**The PostProcessor Python interpreter is missing.**~~ **Resolved 2026-07-30 — see fix #8.**
   PyPy comes from `deploy_ppf.exe`, in that same SDK folder and not a leftover: a 64 MB PyInstaller
   deployer whose embedded payload is `data\pypy3.10-v7.3.16-win64.zip` plus
   `ppframework-2.17.0.dev3-pp310-none-any.whl`, msgpack, semver, typing_extensions and pip. Run once
   per machine, fully offline, and `PYPY_SOURCE` resolves. **pypy.org is a dead end** — the stock
   interpreter satisfies the CMake glob and then fails at post time with
   `ModuleNotFoundError: ppframework`, because that wheel is licensed ModuleWorks code, is not on
   PyPI, and its `pp310` ABI tag pins it to PyPy 3.10 exactly (hence the hardcoded `v7.3.16` path). A
   git submodule was considered and rejected: submodules need a git remote, PyPy ships release zips,
   and the upstream repo is *source* that would have to be built.
2. **Is Ninja an acceptable generator?** Fix #6 exists only because `startCmake.bat` launches
   `cmake-gui`, which defaults to the Visual Studio generator, where MSBuild handles manifests
   natively. If VS-generator-only is the rule, the presets should switch and #6 be reverted.
3. **Is the `.gitkeep` approach right for #2?** With 4 of 7 modules affected, guarding the copy
   target with `if(EXISTS ...)` is arguably the honest fix — an empty `config/` means nothing.
   `.gitkeep` was chosen to keep the change minimal and behaviour identical.
4. **`main` and the ADO default branch** — revive `main` or retire it? 28 of 30 repos have a
   misleading default.
5. **Is a working Debug configuration wanted at all?** **Removed 2026-07-30** — presets, tasks and
   launch entry are gone. It built and installed cleanly but could not run (details above). Reviving
   it means picking one of these first; re-adding the presets alone just recreates a configuration
   nobody can run:
   - **Leave it removed.** Debug the RelWithDebInfo build — full PDBs, and it works. Costs nothing.
     **This is what the branch does**, and it is my recommendation unless somebody needs Debug.
   - **Switch the CRT to dynamic** so every binary shares one heap. The vcpkg triplet designed for
     this is `x64-windows-static-md` (static libs, dynamic CRT). It means rebuilding every vcpkg
     dependency and re-pinning `vcpkgPackages.txt`, and vcpkg has no clean per-config triplet, so it
     changes Release and RelWithDebInfo too. This is the real fix if Debug must work.
   - **Stop passing heap-owning objects across module boundaries.** Correct, and a large refactor of
     `ModuleInterface`. Not a build-environment task.
6. **Feature visibility depends on hardcoded computer names — worth retiring.** Whether a developer
   sees the VHF machine, gets debug geometry dumps, or reports statistics at all is decided by their
   `COMPUTERNAME` appearing in one of **three** unrelated source-level whitelists (details in
   Gotchas). Consequences: a correct build looks broken next to a colleague's, new machines silently
   lack features, and every new PC needs a commit in shared code. Two of the three flags already have
   Config-window checkboxes, so those whitelists only decide the *initial* state; the statistics one
   has no switch at all. Reading the initial state from `mainAppConfig.json` instead would remove the
   need for anyone's name to be in the source. **Deliberately not changed on this branch** — it is
   app behaviour in shared code, not build environment.
7. **The version in the title bar is an install counter.** `update_version_json()` in
   `cmake/install_app.cmake.in` increments it on every install (details in Gotchas), while the
   repository is at `2.1.0` and `releaseNotes/v22_0.md` implies 22.0. It is per-developer and
   per-install-tree, so it can never identify a build, and it climbs forever. Either wire it to the
   real project version or drop it from the title bar; the auto-increment is worse than nothing.
8. **Does anyone actually need the Qt Visual Studio Tools extension?** It rewrites the **committed**
   `CMakePresets.json` as well as the local user file, and on 2026-07-31 left the two out of sync
   badly enough that the presets became unreadable and the configure silently switched to Visual
   Studio's bundled vcpkg (details in Gotchas). Nothing in OneMill needs it — Qt comes from `Qt6_DIR`,
   and there are no `.pro` or Qt-MSBuild projects. Ask everyone to disable it; if somebody needs it
   for another product, the shared file needs protecting some other way, because one bad write there
   breaks the build environment for whoever pulls it next.
9. **The stray `Modules/ModuleTemplate` gitlink keeps coming back — fix it at the source.** Fix 1
   removed it; Robert's `6c04455` re-added it a day later, and the 2026-07-30 merge dropped it again
   (currently absent from both index and disk). It is not a template repository: its before and after
   SHAs are **byte-identical to `Modules/ModuleFixture`**, so the gitlink points at `om_ModuleFixture`.
   Someone created it by copying the `ModuleFixture` directory *including its `.git`*, so
   `git commit -a` keeps picking the nested repository up as a gitlink. Because it has no
   `.gitmodules` entry, its mere presence makes `git submodule update --init --recursive` abort with
   `fatal: No url found for submodule path` and clone **nothing at all** — the single change that
   most reliably breaks a clean checkout for everybody. Removing it from the superproject is only a
   symptom fix; whoever has that directory locally has to delete it or ignore it, otherwise it
   returns on their next `git commit -a`.
10. **Two swallowed exceptions and a string truncation — KOM-11, assigned to Robert.** Real defects
    that change runtime behaviour, so they were not fixed with the rest of the warning sweep:
    `std::runtime_error(...)` constructed without `throw` in `EnvironmentHandler::GetInstance()`
    (`MainApp/src/EnvironmentHandler.cpp:24`) and in `MillingGenerator.cpp:1674`, and
    `wchar_t`→`char` truncation in `StringHelper::WStringToString` plus the two ModuleWorks `catch`
    blocks that log through the same pattern. The `MillingGenerator` one is the real decision:
    `AssignFixture()` already handles `rawData == nullptr` by calling `GrabBestFittingRawPart()`, so
    adding the `throw` turns a case that today finishes with a silently guessed raw part into a hard
    failure. Somebody has to say whether that fallback is load-bearing.
11. **Should Release stay a second-class configuration?** The immediate gap is **closed** — Release
    was cold-started on 2026-07-31 and is current. But it only got there because a crosscheck caught
    it: the configuration that actually ships had gone stale for hours after a change that touched
    shared headers, with no install tree at all, and nothing flagged it. The habit is the problem, not
    that one build. Either make Release part of what "done" means for a change, or write down
    explicitly that only RelWithDebInfo is continuously verified and Release is built on demand
    before a release. A cheap middle option: `Cold start` both configurations whenever a change
    touches a widely-included header such as `Mesh.h`.

## IDE integration

`CMakePresets.json` is committed and contains **policy only — all 5 presets are hidden**. The
selectable presets live in `CMakeUserPresets.json`, which is gitignored;
`CMakeUserPresets.json.example` is the committed template and differs only in using neutral
`D:/BuildDirectory/KLSOneMill` paths. `startCmake.bat` is **untouched**.

Presets, **RelWithDebInfo and Release only** (no Debug — open item 5): 2 configure, 4 build
(2 × `all`, 2 × `install_full`), 2 workflow (configure → build → install). Deviation from the fleet
convention: the build presets build the default target **`all`**, because `MainApp` links only
`ModuleInterface` and `ModuleUtils` — the ten plugin DLLs and every `add_custom_target(... ALL)` copy
step are unreachable from it, so a pinned target list would silently produce an app with no modules
and no config data.

**Preset order is load-bearing: RelWithDebInfo is listed first in every array.** IDEs preselect the
first non-hidden preset, and while `release` came first, Visual Studio silently configured Release on
a fresh open — the IDE default disagreed with the documented default. Both the `.example` and the
local file now list `relwithdebinfo` first in `configurePresets`, `buildPresets` and
`workflowPresets`, and the reason is in the preset's own `description` so nobody re-alphabetises it.

`install_plugins` and `install_fitting` are deliberately not wired to presets; run them with
`cmake --build <dir> --target <name>`. **`install_fitting`** deploys a *second product* from the same
build — **KLSOneAnalyse** — into `INSTALL_DIR_FITTING` (`CACHE PATH`, `CMakeLists.txt:247`): the same
`MainApp.exe` with only `ModuleView`, `ModuleStatistics` and `ModuleFittingAnalysis` enabled, no
ModuleWorks `deps/`, and `applicationName` rewritten to `KLSOneAnalyse` by `update_version_json()`.
It works by configuring `install_app.cmake.in` a *second* time with overridden `INSTALL_MOD_*`
options, which is why `INSTALL_DIR` is reassigned at line 252 — that reassignment does not affect the
already-configured `install_full` script. The bare CMakeLists default (`D:/deployData/KLSOneAnalyse`)
has **no config suffix**, so all configurations would overwrite each other;
`CMakeUserPresets.json.example` overrides it per config, so preset users are fine.

### Tasks (`.vscode/tasks.json`, committed)

6 tasks: `Build | …` and `Install | …` for RelWithDebInfo and Release, plus
**`Cold start | … | <config>`** for each, which runs the *workflow* preset.

`Cold start` exists because `cmake --build --preset` **never configures**. Two different errors mean
"not configured": `<dir> is not a directory` when the build directory is absent, and
`Error: not a CMake build directory (missing CMakeCache.txt)` when it exists but the configure never
finished — an abandoned configure leaves a stub behind, which is exactly what VS did for Release.
Cold start cures both, and is the **only** recovery action: deliberately no separate Configure task,
so "which one do I run" cannot arise, and no `--fresh` variant either — a changed toolchain path in
`CMakeUserPresets.json` is handled by wiping build + install and cold-starting, one concept instead
of two.

There is deliberately **no Clean task**. `cmake --build --target clean` would not clean what matters:
the per-module `add_custom_target(... ALL)` steps copy `config/`, `releaseNotes/` and the ModuleWorks
`deps/` folders into `bin/<config>/modulesBert/`, and Ninja does not track those as outputs, so they
would survive. A half-clean leaving stale plugin data behind produces bugs that look like code bugs.
A wipe task was also rejected: it would have to resolve `binaryDir` out of the gitignored
`CMakeUserPresets.json` (parse the JSON, walk `inherits`, expand `${sourceDir}`) because the paths
are machine-specific and cannot be hardcoded in a committed file — and a path-resolution bug there
deletes the wrong directory. Deleting two folders by hand is rare, unambiguous, and recoverable via
Cold start. Both decisions are repeated in `README.md` and the `tasks.json` header so nobody
re-litigates them.

`.vscode/launch.json` (gitignored, `.example` committed) has entries for the installed folder per
config, for `Updater.exe`, and one that follows the CMake sidebar's launch target — the last needs Qt
and VTK on `PATH` because the build tree has no DLLs next to the exe.

### Visual Studio (verified 2026-07-31, VS 18)

Both IDEs drive the *same* presets from one checkout, sharing the build directory. The flow:
*File → Open → Folder*, enable **Tools → Options → CMake → General → "Always use
CMakePresets.json"** (**off by default**; without it VS ignores the presets and the dropdowns look
empty exactly like a missing `CMakeUserPresets.json`), then VS **configures by itself** on folder
open, on preset change and whenever the cache goes stale — so the `<dir> is not a directory` trap
does not exist there and no Cold start equivalent is needed. Verified: it configures into the
preset's `binaryDir` with `VCPKG_ROOT=D:/DevTools/vcpkg`, triplet `x64-windows-static`, Ninja, and
Qt/VTK from `D:`.

Three limitations of VS's CMake integration, all found the hard way:

1. **`install_full` cannot be run from the Build Preset dropdown.** Selecting
   `Install (target only) | …` and running *Build All* rebuilds `all`, reports success and never
   installs — the install tree is not even created. Microsoft documents `buildPresets.targets` as
   unsupported. Use **CMake Targets View → `install_full` → Build**, or a terminal. (Same shape as
   the CMake Tools sidebar problem in VS Code: builds the wrong thing, reports success.)
2. **VS cannot debug the install tree.** A launch configuration bound to a CMake target
   (`project` + `projectTarget`) **ignores `program`**, even with a literal absolute path; drop
   `projectTarget` and the entry disappears from the startup dropdown entirely. So there is no way to
   aim VS's debugger at `INSTALL_DIR` — debug the build tree, and check the installed artifact from
   VS Code or outside the IDE.
3. **`projectTarget` embeds the configuration**, so one launch entry per configuration is required:
   `MainApp.exe (bin\RelWithDebInfo\MainApp.exe)` vs `…(bin\Release\MainApp.exe)`. An entry bound to
   one config does not appear under the other, which reads as "my launch config vanished".

VS also **never routes through `dev-run.cmd`**, so its builds are uncapped — Ninja defaults to
cores + 2. Accepted rather than fixed: pinning `jobs` in the build presets would also override the
cap for VS Code and the CLI. A terminal inside VS prefixed with `.vscode\dev-run.cmd` is therefore
*better behaved* than *Build All*.

## Gotchas (hard-won, don't re-learn)

- **The Qt Visual Studio Tools extension rewrites both preset files and can brick the toolchain.**
  Rewriting presets is a designed feature of it — see `HKCU\SOFTWARE\QtProject\QtVsTools\Versions\msvc2022_64`
  (`InstallDir = C:\Qt\6.10.2\msvc2022_64`, the key name matching the injected preset name exactly)
  and its `Notifications_CMake_Presets_Modified` setting. In two passes it injected a hidden `Qt`
  preset into **committed** `CMakePresets.json` plus a `Qt-Default` → `msvc2022_64` → `Qt` chain into
  `CMakeUserPresets.json` and appended `"Qt-Default"` to both configure presets' `inherits`; then it
  **removed its own `Qt` preset while leaving the dependents in the user file**. Result:
  `CMake Error: Could not read presets ... Invalid preset: "msvc2022_64"` — *both* files unreadable.
  From there the failure is silent and total: VS falls back to its built-in `x64-debug` → no
  `VCPKG_ROOT` cache variable → `CMakeLists.txt:39` falls back to `$ENV{VCPKG_ROOT}`, which
  `VsDevCmd.bat` points at **VS's own bundled vcpkg** → configure dies on `find_package(cpr)`, into
  `out/build/x64-debug` with the wrong triplet. The `VCPKG_ROOT`-as-cache-variable protection in
  `onemill-local-toolchain` exists precisely for the `VsDevCmd.bat` overwrite, but only works while
  the presets are readable at all. Because `CMakePresets.json` is committed this is a **shared-file**
  risk. Open item 8.
- **Qt/VTK on `PATH`: three related traps.** (a) *Debugging the build tree needs Qt **and** VTK on
  `PATH`; the install tree does not* — the build tree has no Qt/VTK DLLs next to `MainApp.exe`. On
  this machine the persistent `PATH` had `C:\Qt\6.10.2\msvc2022_64\bin` but **no VTK**, so a
  build-tree launch found Qt and then failed with `vtkRenderingCellGrid-9.5.dll was not found`, and
  `ModuleMillingKalotte` (largest dependency closure of the ten) was the module that failed to load
  while the others succeeded. Colleagues whose `PATH` carries both never see any of it — that
  difference, nothing else, is why the same commit "works for Robert". (b) *Match the Qt on `PATH` to
  the Qt the build links against* — `C:\Qt\...` on `PATH` while the build uses `D:\DevTools\Qt\...`
  means the exe loads Qt from a *different installation* than it compiled against; it works while the
  versions coincide and turns inexplicable when they stop. (c) **Two Qt 6.10.2 installations exist on
  this box** — the presets pin `D:\DevTools\Qt\6.10.2\msvc2022_64` via `Qt6_DIR`/`QTDIR`, but
  `C:\Qt\6.10.2\msvc2022_64` also exists and carries `Src/`, which the `D:` one does not. Harmless
  while `Qt6_DIR` is explicit, dangerous the moment something resolves Qt via `PATH` or a hint-less
  `find_package`. `launch.json` (VS Code) and `.vs/launch.vs.json` (VS) both inject the build's Qt
  `bin` first, then VTK.
- **The CMake sidebar cannot run this project's install.** CMake Tools substitutes its own status-bar
  target into **every** build step, including each step of a `workflowPresets` chain. Clicking
  *Workflow → Install | Win | MSVC | x64 | RelWithDebInfo* produced `--build … --target MainApp --`
  **twice** — once where the preset says `all`, once where it says `install_full` — then reported
  success having installed nothing (evidence: `.vscode/out.log`, 2026-07-30). No chip value satisfies
  both steps, so the sidebar is structurally unable to do it. Use `.vscode/tasks.json`
  (Ctrl+Shift+B) or `cmake --workflow --preset onemill-install-win-msvc-x64-relwithdebinfo`. Note
  `--fresh` is opt-in, so the workflow reuses the existing build tree. Two mitigations landed with
  fix #8: `install_full` now depends on every buildable target, and the install script fails hard
  instead of warning, so this failure mode can no longer be silent.
- **`VCPKG_TARGET_TRIPLET` must be on the command line.** `CMakeLists.txt` sets it at line 58,
  *after* including the vcpkg toolchain at line 52, so vcpkg has already resolved the default dynamic
  `x64-windows` prefix and `find_package(cpr)` fails. `cmake-gui` users never see this — the triplet
  is already in their cache. `CMakePresets.json` sets it.
- **Derive the vcpkg port list from `#include`s, not from `find_package`.** `boost-asio` is the
  cautionary example: nothing `find_package()`s it, but the build fails without it. An earlier audit
  based only on `find_package` calls wrongly concluded "no new ports needed".
- **Never assume a fix from `main` still applies.** One of the four would have deleted working
  features. Build first, fix what breaks.
- **`install_full` is not fully self-contained** — it passes `--no-compiler-runtime`, so the target
  machine needs the VC redistributable.
- **The app registers the `.klso` file association to whichever build ran last.**
- **No VHF machine in the dropdowns? Tick "Test Mode" in the Config window.** `VHF-R5.json` is the
  only machine with `"isTest": true`, and `MachineDataConfiguration.cpp` (lines 297 and 315) filters
  test-only machines out of the region and material combo boxes whenever the app is in
  `MillingApplicationMode::Common`, the default. The checkbox (`ConfigWindow::onCheckBoxTestMode` →
  `ToolManager::setApplicationMode`) is always available and never hidden.
  `ConfigWindow::InitSettings()` pre-ticks it **only on `COMPUTERNAME == "CADS11"`**
  (`MainApp/src/ConfigWindow.cpp:99`), so a developer on that machine has it on permanently and never
  discovers the switch — which is exactly why a build can look "wrong" next to theirs when it is
  identical.
- **Three unrelated machine-name whitelists, and only two have a checkbox that does the same job.**
  Open item 6. They have nothing to do with each other:
  1. `ConfigWindow.cpp:99` pre-ticks **Test Mode** on `CADS11` (the machine list, above).
  2. `MillingBackend/.../Config/ConfigHandler.h:46/50/54` sets `isTestComputer` on `CADS-5384`,
     `CADS11` and `CADS-5479`; that feeds `IsDebugComputer()`, used at **141 call sites across 37
     files** — heaviest in `HardcodedStrategieCreator.cpp` (33), `ModuleWorksHolder.cpp` (24),
     `MillingGenerator.cpp` (23) and `ModuleWorksCreator.cpp` (18) — to dump debug geometry during
     milling generation. Adding a computer there is a bad trade: the dump target
     `D:/devData/KLS/KLSOneMill/debugData` is hardcoded, the `CheckOrCreateDirectory` call that would
     create it is commented out, and `IsDebugComputer()` returns `false` outright when
     `RELEASE_VERSION` is defined (`MainApp/CMakeLists.txt:70`, set for Release). Use the Config
     window's **Debug Mode** checkbox instead — `SetDebugMode()` sets the same flag at runtime *and*
     prompts for a directory that actually exists.
  3. `ModuleStatistics/.../BackendWorkerStatistics.cpp:26` does `mConstantData = nullptr; return;` on
     `CADS11`, i.e. **statistics collection is silently disabled on that machine**, with no checkbox
     and no other way to tell. Least visible of the three and the easiest to mistake for a bug
     elsewhere.
- **The version in the title bar is an install counter, not a version.** `update_version_json()` in
  `cmake/install_app.cmake.in` (line 101) reads `config/mainAppConfig.json` from the *install*
  folder, seeds it with `"version": "1.0.0"` if absent, then **increments the last integer component
  on every single install**, logging `[+] config/mainAppConfig.json (1.0.2 → 1.0.3)`. The same
  function patches `applicationName`, which is how `install_fitting` rebrands the identical
  `MainApp.exe` as `KLSOneAnalyse`. So `1.0.3` means "`install_full` has run three times in this
  tree" — per-install-tree and per-developer, and the number appears nowhere in the source because it
  is generated. That is why install trees built minutes apart from identical source disagreed, and
  why the freshly wiped tree of 2026-07-31 reports `1.0.1` having previously read `1.0.3`. **Never
  use it to identify a build**; use the build date, which `BuildTitleBarContent()` appends from
  `__DATE__`, or the superproject gitlink SHA. Open item 7.
- **Heavy builds go through `.vscode/dev-run.cmd`** (VS x64 env + parallelism capped at cores−2 +
  below-normal priority). `dumpbin` is only on `PATH` inside that environment — a dependency check
  run outside it silently reports everything as OK.
- **Piped commands hide exit codes.** The harness reports `tee`'s status, so a failing command looks
  like exit 0. Always echo the real code inside the pipeline.
- **`git fetch` + `FETCH_HEAD` is not a reliable way to read a remote branch.** If the fetch fails
  for one repo, `FETCH_HEAD` silently still holds the *previous* fetch's SHA, so a loop over
  submodules reports confident nonsense. Use `git ls-remote --heads origin <branch>` for existence
  and tip, and `git branch -r --contains <sha>` for reachability. This produced one wrong conclusion
  during the 2026-07-31 crosscheck before being caught.
- **Never run a disk/temp cleanup while a build is in flight.** A `C:` cleanup wiped
  `%LOCALAPPDATA%\Temp` mid-build and produced 11 × `fatal error C1069: cannot read compiler command
  line` — MSVC could no longer read its own temp command files. It looks exactly like a source
  defect, and because it hits whatever happens to be compiling at that moment, the failing file set
  changes every run. Tells that it is environmental: the failures cluster in one short time window,
  files that *started later* compile fine, and `C:` free space jumps. A plain re-run fixes it; the
  build tree on `D:` is never damaged.
- **`/utf-8` is imposed by our dependencies, so source files must be UTF-8.** The `C4828`
  ("character not valid in the current source character set (codepage 65001)") warnings were *not* a
  project setting: nothing in our CMake sets `/utf-8`. It arrives twice from outside —
  `Qt6::Platform` adds `-utf-8` (gated by the `QT_NO_UTF8_SOURCE` target property) and `fmt`, via
  spdlog, adds `/utf-8`. **Do not "fix" C4828 by setting `QT_NO_UTF8_SOURCE`**: that also changes the
  *execution* charset, trading cosmetic warnings for real mojibake in string literals. The only
  correct fix is to keep sources UTF-8, which the committed `.editorconfig` already requires. All 14
  offending files were re-encoded 2026-07-31 (KOM-10).
- **A warning reported inside an MSVC STL header is usually still ours.** `C4244`/`C4267` point at
  `xutility`, `memory`, `vector` lines, which reads like toolchain noise. It is not — MSVC appends a
  `note: the template instantiation context` block, and following it to the last frame in our tree is
  what found the `MeshTriangle` index-type mismatch and the `ContourBuilder` argument-order problem.
  Read the notes before dismissing or suppressing.
- **MSVC emits such a warning only once per header line per translation unit.** Two call sites in one
  `.cpp` that trigger the same warning at the same STL line produce *one* message, so fixing the
  reported site can simply re-surface it from the other. `ContourBuilder` had three `hullValue` call
  sites and warned about one; all three had to change. Never assume the warning count equals the
  defect count.
- The `CMP0167`/FindBoost warnings come from vcpkg's own wrapper (3×), and
  `FittingAnalysisBackend: OpenXLSX not found via find_package` is a false alarm — OpenXLSX comes
  from the vendored submodule target and the module links fine. Root cause of the false alarm, for
  whoever fixes it: `FittingAnalysisBackend/CMakeLists.txt:44` tests `OpenXLSX_FOUND`, but the
  vendored `add_subdirectory` only defines the `OpenXLSX::OpenXLSX` alias and never sets that
  variable, so the test can never pass; line 61 already links the target unconditionally and lines
  64-65 link it a second time. Both tracked in KOM-11.

## Change log

| When | What |
| --- | --- |
| 2026-07-29 | Clone created at `version/Beta220`; 26 submodules verified at pinned SHAs. Baseline built untouched, then the fixes applied one failure at a time. RelWithDebInfo builds, installs and **runs** with all 10 modules. Presets, `.gitattributes`, `.gitignore`, `.vscode` IDE files and the `vcpkgPackages.txt` pin added. `D:` cleanup reclaimed 41 GB; `D:` VHDX confirmed to survive a reboot |
| 2026-07-29 | **Debug and Release build and install cleanly too** — 10 modules, 171 DLLs, 0 unresolved imports each, so the fixes are config-independent. Corrected the ModuleWorks `deps/` count here: **57 DLLs + `mwSupport.lic`, not 67** — the old number was never right. Added the `%TEMP%`-cleanup/`C1069` gotcha after losing a run to it. **Release launches and runs** from the installed folder |
| 2026-07-29 | Branch `SetupBuildEnvOnBeta220` created and committed across **13 repositories** (not 11 — 5 wrapper repos exist only to carry a gitlink bump upward). All 26 gitlinks in sync, every working tree clean |
| 2026-07-29 | **Debug turns out not to run**: `__acrt_first_block == header` at startup. Pre-existing — static CRT in `MainApp` + 10 plugins = 12 CRT heaps, and the debug heap catches the first cross-boundary free that Release silently tolerates. Not narrowly fixable; open item 5. Debug's "0 unresolved imports" downgraded to a this-box-only claim, since the debug CRT is non-redistributable |
| 2026-07-30 | Team decision: **no pull requests for now**, `version/Beta220` stays as it is. All branches pushed for backup and visibility. Recorded the ADO policy survey and the merge-commit-only constraint, since nothing in Azure DevOps enforces it |
| 2026-07-30 | **Merged Robert's `6c04455`** ("VHF HoleMilling Showcase / PP Bugfix") bottom-up, 13 merge commits, superproject `2cad38c`. 8 gitlink conflicts + 1 modify/delete, no textual conflicts survived. All three configurations re-built and re-verified green. `Modules/ModuleTemplate` deletion kept — open item 9 |
| 2026-07-30 | **Debug configuration removed** (presets, tasks, launch entry, docs) — it built and installed but could never run, so keeping it only invited the assertion again. **Added `Cold start` tasks**, after `cmake --build --preset` failed with `<dir> is not a directory` on a wiped build tree — that error had no recovery entry. Deliberately **no Configure, Clean, wipe or `--fresh` variant**; reasoning in IDE integration, `README.md` and the `tasks.json` header. **Corrected this ledger**: the title-bar version is an install counter (open item 7). Documented `INSTALL_DIR_FITTING` / `install_fitting` |
| 2026-07-30 | **The ModuleWorks license was my own 16-byte placeholder** ("DUMMY by SCHACHI"), which is why toolpath generation died with "License file marker is missing!" (KOM-8). Placement was never wrong — the shipping Beta4 deployment keeps `mwSupport.lic` in the same two `modulesBert/<Module>/deps/` folders and nothing next to `MainApp.exe`. Took the real 6096-byte license (CADS GmbH, BuildVersion 2025.12.1.3, no hardware key, perpetual) out of that deployment into `$MODULEWORKS_DIR/quickstart/` plus all 12 live `deps/` folders. Beta4's MW DLLs are the identical build to our SDK. Repro retest still open |
| 2026-07-30 | **The missing PostProcessor interpreter is solved** (open item 1 → fix #8). `deploy_ppf.exe` is the source: an offline PyInstaller deployer bundling `pypy3.10-v7.3.16-win64.zip` + the licensed `ppframework` wheel. Ran it in place; the tree imports `ppframework` 2.17.0-dev3 and its root is **identical** to Robert's shipped Beta4 interpreter. Note it writes a `deploy_ppf.ini` next to itself pinning `INTERPRETER`, so a second run upgrades that install instead of creating a new one — run it from the target folder. `CopyPostProcessorData` reworked: `EXISTS` guard with an actionable warning, `ALL`, a stamp file (a bare `ALL` target would re-copy 153 MB every build) and a full-tree copy instead of the old `*.dll` + `pypy3.exe` + `Lib/` subset (which worked at 141 MB but omitted `tcl/`, `Scripts/`, `include/`, `libs/`, `shared/` — 12 MB to match what ships) |
| 2026-07-30 | **Install made self-sufficient and fail-fast; VS Code entry points added.** All three install targets declared only `DEPENDS MainApp Updater`, and MainApp links neither the plugin DLLs nor the `ALL` copy targets — so an install target staged whatever was left in `bin/`. `install_full`, `install_plugins` and `install_fitting` now each depend on every buildable target under `Modules/` (a walk, so new modules are covered; scoped to `Modules/` deliberately — a whole-tree walk would drag in OpenXLSX's Doxygen target and its `EXCLUDE_FROM_ALL` benchmarks). `install_app.cmake.in` now **fails hard** on a missing module DLL, `Updater.exe`, `deps/` or `interpreter/` — the mechanism that let the interpreter gap survive. Added `.vscode/tasks.json`, a root `README.md`, the fleet `.editorconfig`, and `.vscode/OneMill-Fleet-Conformance.md`. Fleet spec reviewed at `SuperbuildEngine@d6b4a31` |
| 2026-07-31 | **Visual Studio verified as a supported path** (VS 18), so both IDEs work from one checkout. Recorded its three CMake-integration limits and that VS builds bypass `dev-run.cmd`. **Qt VS Tools broke the toolchain** — open item 8. Build-tree debugging documented as needing Qt **and** VTK on `PATH` (the whole "works on his PC" difference). **RelWithDebInfo moved first in every preset array** after VS silently picked Release. README restructured around *which tree are you running?* |
| 2026-07-31 | **Warning sweep: 99 → ~10.** Wiped both RelWithDebInfo trees, cold-started clean, and attributed all 95 compiler warnings to an owning file via MSVC's instantiation-context notes rather than the header line — which is what turned up two genuine type bugs and two swallowed exceptions behind apparent toolchain noise. **KOM-10 fixed 85 with no behaviour change**; **KOM-11 opened** for the four behaviour-changing items (open item 10). Branched/committed/pushed across 8 repos, fast-forwarded into `SetupBuildEnvOnBeta220`, remote topic branches deleted — **the branch now spans 16 repositories**. Three new gotchas: `/utf-8` is imposed by Qt and fmt, an STL-header warning is usually still ours, and MSVC emits one such warning per header line per TU |
| 2026-07-31 | **Ledger crosschecked against reality** — ~60 claims verified against the toolchain, install tree, source and remotes. Corrected: **all 16 repos now have a `version/Beta220`** (Robert's push created it in the 8 that lacked one), so **every PR target is `version/Beta220`**, not `version/20Beta`; the branch is pushed, not unpushed; **a third machine-name whitelist exists** (statistics disabled on `CADS11`, no checkbox); `IsDebugComputer()` is **141 call sites in 37 files**, not ~16 in 5; two drifted line numbers (52/58, not 47/53); stale disk figures dropped. Found that **Release had not been rebuilt since KOM-10** and had no install tree (open item 11), that `.claude/settings.local.json` is still tracked despite fix 1, and added the `FETCH_HEAD` gotcha that produced one wrong conclusion mid-crosscheck. Compacted throughout: merged three overlapping Qt/`PATH` gotchas into one, folded duplicated Cold-start reasoning together, condensed the Debug/CRT and merge sections, and sorted this log chronologically |
| 2026-07-31 | **Release cold-started from a wiped tree, closing the gap the crosscheck found** — 564 steps, exit 0, install staged with 171 top-level DLLs, 10 modules, 58 files per `deps/`, interpreter present, no debug-CRT leakage. Because it was a clean build it also gives the **measured** post-fix warning count: **99 → 14** (10 compiler + 4 CMake), every survivor accounted for — 5 third-party, 5 in KOM-11, 3 × CMP0167, 1 OpenXLSX false alarm. **C4828, C4838 and C4005 eliminated.** Release then **launched and ran** from its installed folder, so both configurations are verified end to end. Open item 11 narrowed to the process question |
