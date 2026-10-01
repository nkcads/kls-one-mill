# Product version — work plan (KOM-19)

Last updated: **2026-10-01**
Status: **V0–V7 done, merged into `develop`** (PR 34582, `4243a27`; first run on `develop`: `2.2.0.74-alpha`). **V8 open** — the merge into KOM-13, handed to the KLSOneMill3 session on 2026-10-01.

> Scope and acceptance criteria are in **[KOM-19](https://cads-team.atlassian.net/browse/KOM-19)** and are
> not restated here ([D7](README.md#decisions)). Decisions that shape this plan: **[D1](README.md#decisions)**
> (company scheme), **[D2](README.md#decisions)** (one product version), **[D4](README.md#decisions)**
> / **[D5](README.md#decisions)** (superproject only, new files only where self-contained). This plan owns
> shared items **[S1](README.md#shared-items-s1s4)** and **[S2](README.md#shared-items-s1s4)** and the version
> half of **[S3](README.md#shared-items-s1s4)**.

| § | | § | |
| --- | --- | --- | --- |
| [1](#1-what-onemill-has-today) | What OneMill has today (VF*) | [5](#5-steps-v0v8) | Steps V0–V8 |
| [2](#2-company-practice) | Company practice | [6](#6-open-points-vq) | Open points (VQ*) |
| [3](#3-target-scheme) | Target scheme | [7](#7-risks-vr) | Risks (VR*) |
| [4](#4-merge-surface-with-kom-13) | Merge surface with KOM-13 | [8](#8-extraction-map) | Extraction map |

---

## 1. What OneMill has today

Read from `develop` @ `3d14ab2` on 2026-09-30. Reading claims unless marked otherwise; nothing was built.

| ID | Finding | Evidence |
| --- | --- | --- |
| **VF1** | **No tag GitVersion recognises.** GitVersion needs `[vV]?X.Y.Z`; OneMill has `Version_1.0.1` / `release/1.0.1` → `a5ca137` (2025-12-10, RC10), `Version_2.1.0` / `release/2.1.0` → `43f8ced` (2026-07-21, *Version 2.1.0*), `frozen/20Beta` → `43f8ced`, `frozen/Beta220` → `4d36c7f`. `origin/main` is now `43f8ced`; `43f8ced` is an ancestor of `develop`, which is **60 commits** past it | `git tag`, `git rev-list --count 43f8ced..HEAD` = 60, `merge-base --is-ancestor` = 0 (measured) |
| **VF2** | **The "version" is an install counter, per install tree.** `update_version_json()` reads `<INSTALL_DIR>/config/mainAppConfig.json`, increments the *last* integer in the version string and writes it back, on every `install_full` **and** `install_plugins`. Two trees built from the same commit disagree (KLSOneMill3's tree showed `1.0.43`). `install_full`/`install_plugins` share one generated script, `install_fitting` has its own — so KLSOneAnalyse counts separately | [install_app.cmake.in:101-153](../../../cmake/install_app.cmake.in#L101-L153), called at [:279](../../../cmake/install_app.cmake.in#L279); [CMakeLists.txt:252-256, 315-319](../../../CMakeLists.txt#L252-L256) |
| **VF3** | **The version lives in a settings file that MainApp itself rewrites.** `mainAppConfig.json` sits in `<exe>/config/`; MainApp creates it on first start if missing and saves it again whenever a setting changes (screenshot directory, the file-association prompt). The version round-trips, so it is not corrupted — but the only source of the title-bar version is a user-writable file, not the binary. In-code default `0.1.0`, load fallback `1.0.0` | [EnvironmentHandler.cpp:56-75, 130-134](../../../MainApp/src/EnvironmentHandler.cpp#L56-L75); [MainWindow.cpp:406, 450](../../../MainApp/src/MainWindow.cpp#L406); [MainAppConfigDefinition.h:21](../../../MainApp/src/MainAppConfigDefinition.h#L21), [.cpp:47](../../../MainApp/src/MainAppConfigDefinition.cpp#L47) |
| **VF4** | **Consumers of that version**: the OS window title (`applicationName - version - __DATE__`), the in-window title bar, and every module via `setMainSoftwareVersion()` | [MainWindow.cpp:369-381](../../../MainApp/src/MainWindow.cpp#L369-L381), [:759](../../../MainApp/src/MainWindow.cpp#L759), [:946](../../../MainApp/src/MainWindow.cpp#L946) |
| **VF5** | **No binary carries a VERSIONINFO resource.** `MainApp/appicon.rc` is one line — the icon. FileVersion, ProductVersion and CompanyName are empty on `MainApp.exe` (measured on KLSOneMill3's tree, 2026-09-29) | [MainApp/appicon.rc](../../../MainApp/appicon.rc) |
| **VF6** | **One `MainApp.exe`, two products.** `install_fitting` stages the *same* binary as KLSOneAnalyse and only rewrites `applicationName` in `mainAppConfig.json`. A compiled-in `ProductName` therefore cannot say *KLSOneMill* for one and *KLSOneAnalyse* for the other without a second build — see [VQ1](#6-open-points-vq) | [CMakeLists.txt:288-334](../../../CMakeLists.txt#L288-L334) |
| **VF7** | **`install_fitting` looks broken on `develop`.** It runs the install script in `full` mode without `-DUPDATER_EXE`, and `full` mode aborts with *Updater.exe is missing* when that is undefined. Reading claim — not run. KOM-13 changed `install_app.cmake.in`, so check its version at the first merge before fixing it here | [CMakeLists.txt:323-334](../../../CMakeLists.txt#L323-L334), [install_app.cmake.in:186-194](../../../cmake/install_app.cmake.in#L186-L194) |
| **VF8** | **`releaseNotes/moduleInfo.json` is read by nothing.** Nine of ten modules carry one (`{"displayName": "View", "version": "1.0"}`; ModuleUpdater has none). They live in the module submodules | 9 files under `Modules/*/…/releaseNotes/`; no reader in any `.cpp`/`.h` |
| **VF9** | **The in-app updater compares versions as opaque strings, for inequality only.** A product version like `2.2.1.5` works exactly as `2026.07.20` did — the updater is unaffected by this story | [UpdateManifest.h:15](../../../Modules/ModuleUpdater/UpdaterBackend/src/Manifest/UpdateManifest.h#L15) |
| **VF10** | **The pipeline cannot compute a version today.** Checkout is `fetchDepth: 1` (no history, no tags), and the artifact name is scraped from the counter in the staged `mainAppConfig.json` | [onemill-build-windows.yml:292-296](../../../pipelines/onemill-build-windows.yml#L292-L296), [:464-491](../../../pipelines/onemill-build-windows.yml#L464-L491) |
| **VF11** | **First-party binaries on `develop`: 12** — `MainApp.exe`, `Updater.exe`, 10 module DLLs. KOM-13 adds `ModuleMachineSim.dll` → **13**, which is the count KOM-20 quotes. The install-tree scan (507 binaries, 199 unsigned) was taken on KOM-13's tree | [CMakeLists.txt:236-245](../../../CMakeLists.txt#L236-L245), `Modules/` has 10 directories |
| **VF12** | **`FileTransferClient.exe` is built but never shipped.** It is a first-party executable under `Modules/ModuleFileTransfer/`, but `install_app.cmake.in` does not stage it. It gets the version resource (V2), and stays out of the manifest (V5), which lists what is staged | `Modules/ModuleFileTransfer/FileTransferClient/CMakeLists.txt:16` |
| **VF13** | **ModuleStatistics sends the version to the statistics server.** On start it forwards what MainApp passes and reports it as `applicationVersion` with every record. Today that is the install counter (`1.0.43`); after V3 it is `2.2.0.<n>-alpha`. Whatever reads those records — dashboards, queries, a column length — sees a new format from that day on | [ModuleStatistics.cpp:64-69](../../../Modules/ModuleStatistics/ModuleStatisticsFrontend/src/ModuleStatistics.cpp#L64-L69), [StatisticsLogger.cpp:156, 201, 240](../../../Modules/ModuleStatistics/StatisticsBackend/src/StatisticsLogger.cpp#L156) |

## 2. Company practice

Surveyed across all ten ADO projects on 2026-09-29. Written down nowhere; lived everywhere.

| Project | Tags | Release branches | Version |
| --- | --- | --- | --- |
| IPS Suite | `v0.1.0` | `release/v0.2.0`, `release/v0.3.0` | `CreateCadsVersion@3` → `0.4.0.447-alpha` |
| IPS CaseDesigner | `v0.2.0` (7 repos) | `release/v0.1.0` … `v0.3.0` | `CreateCadsVersion@3` → `0.4.0.288-alpha`; feature `0.4.0.285-CD-2509-header-menus` |
| Product Data Storage | `v1.0.7` … `v2.0.2` | `release/vX.Y.Z`, `hotfix/v1.0.7` | `CreateCadsVersion@2` → `2.2.0.51` |
| MIRAGE, NAVIGATOR, Hypervisor, Segmentation WS, 20+ CADS Libraries repos | `vX.Y.Z` | `release/vX.Y.Z` | GitFlow (NAVIGATOR's README states it) |
| inSilico OSA | none | none | own derivation (installer playbook) |
| **KLS OneMill** | `Version_*`, `release/*`, `frozen/*` | none | install counter ([VF2](#1-what-onemill-has-today)) |

**`CreateCadsVersion`** (repo `cads-versionator`, project CADS Libraries, `buildAndReleaseTask/index.ts`)
runs a bundled `GitVersion.exe` with the default configuration and sets `Build.BuildNumber` to
`MajorMinorPatch.CommitsSinceVersionSource[-PreReleaseLabel]`. It also sweeps `**/*.csproj` and `pom.xml`
and stamps them; OneMill has neither, so that hazard does not apply. Suite and CaseDesigner pass a harmless
`csprojfilepathpattern` anyway (CaseDesigner: `'somethingelse'`). It needs full history and tags.

**How the Suite turns the number into binaries** (`ips-suite`, project IPS Suite):

- `project/CMake/git_version.cmake` — local fallback at configure time: latest `vX.Y.Z` tag; `develop` →
  minor+1, patch 0, suffix `alpha`; `release/vX.Y.Z` → that version, `beta`; `master` → the tag exactly;
  any other branch → minor+1 with the branch name as suffix; plus commit count and short hash.
- `pipelines/build-validation-windows.yaml` — the numeric part of `Build.BuildNumber`, padded to four
  fields and each clamped to 65535, becomes the file version; the raw build number becomes the
  informational version; both reach CMake via `-D`. Stamping only on publishable or manual runs.
- `project/suite-app/versioninfo.rc.in`, `project/CMake/BinaryVersionInfo.rc.in` — VERSIONINFO with
  CompanyName `CADS GmbH`, ProductName, FileVersion, ProductVersion, and `Comments` = informational
  version. CaseDesigner passes `-DCD_VERSION_OVERRIDE=$(Build.BuildNumber)`.
- Lanes: `main` → final (no suffix), `release/*` → `-beta`, everything else → `-alpha`. Build tags
  `publishable-app`, the lane and `branch-<sanitized>` let the installer CI find the right app run.

## 3. Target scheme

The next delivery is **2.2.0**: `releaseNotes/v22_0.md` exists on `develop`, and `version/Beta220` is merged
into it.

| Branch | Version (informational) | File version | Lane |
| --- | --- | --- | --- |
| `develop` | `2.2.0.<n>-alpha` — `2.2.0.60-alpha` expected once `v2.1.0` exists | `2.2.0.<n>` | alpha |
| `feature/KOM-13-machine-simulation` | `2.2.0.<n>-KOM-13-machine-simulation` ([D6](README.md#decisions)) | `2.2.0.<n>` | alpha |
| `release/v2.2.0` | `2.2.0.<n>-beta` | `2.2.0.<n>` | beta |
| `main`, tagged `v2.2.0` | `2.2.0.<n>` (no suffix) | `2.2.0.<n>` | final |

`<n>` = commits since the version source. The file version is four numeric fields, each ≤ 65535. MSI
compares only the first three fields; KOM-21 handles that with `AllowSameVersionUpgrades`. The exact
strings are what GitVersion's default configuration produces — **confirmed only by the first pipeline run**
([V6](#5-steps-v0v8)'s exit criterion).

## 4. Merge surface with KOM-13

KOM-13 changed exactly the files this story touches (`git diff develop...feature/KOM-13-machine-simulation`,
2026-09-29): root `CMakeLists.txt` (150 lines, much of it the removal of the `deploy` target that still
exists here at [CMakeLists.txt:208](../../../CMakeLists.txt#L208)), `cmake/install_app.cmake.in` (+44),
`pipelines/onemill-build-windows.yml` (+53). Conflicts on the merge are certain; this layout keeps them small:

| Piece | Where |
| --- | --- |
| Compute the version (git fallback, CI override) | **new** `cmake/OneMillVersion.cmake`, one `include` line in the root — same shape as the existing `include(cmake/ModuleWorksSDK.cmake)` at [CMakeLists.txt:121](../../../CMakeLists.txt#L121) |
| VERSIONINFO template | **new** `cmake/VersionInfo.rc.in` |
| Attach the `.rc` to MainApp, Updater and every module target | in `OneMillVersion.cmake` (`onemill_add_version_info()`), called once from the root after the existing install-dependency walk — the second root line — via `target_sources` (allowed on targets from other directories since CMake 3.13). `appicon.rc` carries no version resource, so no clash. No submodule changes |
| First-party manifest ([S2](README.md#shared-items-s1s4)) | existing `install_app.cmake.in` — it knows what it actually stages. Derived from the enabled `INSTALL_MOD_*`, so KOM-13's `INSTALL_MOD_MACHINESIM` joins automatically after the merge |
| Replace the install counter | existing `install_app.cmake.in`, `update_version_json()` |
| GitVersion step, version into configure, artifact name | existing `onemill-build-windows.yml`, inline |

## 5. Steps V0–V8

Legend: ✅ done · 🟡 in progress · ⬜ not started · 🚫 blocked. Martin builds and tests; exit criteria are
what he checks.

| ID | Step | Exit criterion | Status |
| --- | --- | --- | --- |
| **V0** | **Tags.** `v1.0.1` on `a5ca137`, `v2.1.0` on `43f8ced`, pushed to the superproject only. Annotated or lightweight: [VQ3](#6-open-points-vq) | `git describe --tags --match "v*"` on `origin/develop` yields `v2.1.0-60-g…` | ✅ **created 2026-09-30 (annotated), pushed 2026-10-01** with Martin's V6 approval — `v1.0.1` → `a5ca137`, `v2.1.0` → `43f8ced` on origin. Other clones need `git fetch --tags` before they can configure ([VR4](#7-risks-vr)) |
| **V1** | **`cmake/OneMillVersion.cmake`** — if `ONEMILL_VERSION` is given (CI), use it; otherwise derive it from git with the Suite's branch rules ([§2](#2-company-practice)). Publishes the informational string, the four clamped numeric fields and the short hash. Fails loudly when neither git nor an override yields a version — no silent `0.0.0`. A detached HEAD gets the suffix `-local`. No automatic reconfigure on commit or branch switch ([VR1](#7-risks-vr)). Included once, after `add_subdirectory(Modules)`, so V2 can attach in the same file | Local configure on this branch prints `2.2.0.<n>-KOM-19-version-scheme`; with `-DONEMILL_VERSION=2.2.0.7-alpha` it prints that; with `-DONEMILL_VERSION=banana` it fails | ✅ **done 2026-09-30, configured on KLSOneMill4**: git → `2.2.0.61-KOM-19-version-scheme`; override → `2.2.0.7-alpha`; `banana` → configure fails; `2.2.0.70000-alpha` → numeric `2.2.0.65535` with a warning; detached HEAD → `2.2.0.61-local` |
| **V2** | **`cmake/VersionInfo.rc.in` + `onemill_add_version_info()`** — CompanyName `CADS GmbH`, ProductName `KLSOneMill` ([VQ1](#6-open-points-vq)), the strings of [VQ6](#6-open-points-vq), numeric FILEVERSION/PRODUCTVERSION, `VS_FF_PRERELEASE` for any version with a suffix. Attached to every executable and shared/module library in the existing install-dependency walk ([CMakeLists.txt:416-445](../../../CMakeLists.txt#L416-L445)) — `MainApp`, `Updater`, the 10 modules and `FileTransferClient` ([VF12](#1-what-onemill-has-today)) — not by a hand list. That costs a **second line in the root** beside V1's `include`: the version must exist before the install scripts are configured, the walk comes much later | Explorer → Properties → Details of `MainApp.exe`, `Updater.exe` and one module DLL show version, company, product | ✅ **built and read back 2026-09-30 on KLSOneMill4**: all 13 binaries carry FileVersion `2.2.0.63`, ProductVersion `2.2.0.63-KOM-19-version-scheme`, CADS GmbH / KLSOneMill, pre-release flag set; `MainApp.exe` keeps its icon. Adding it relinked the 13 binaries only (22 s); an unchanged version relinks nothing. Module descriptions read `KLSOneMill Module View` etc. **Explorer → Details checked by Martin, 2026-09-30: description, type, file version, product name, product version, copyright, language, original filename all as intended** |
| **V3** | **`update_version_json()` writes the product version** instead of incrementing. KLSOneAnalyse gets the same version | Two install trees from the same commit show the same version; `install_full` twice in a row does not change it | ✅ **tested 2026-10-01 on KLSOneMill4**: a fresh tree gets `2.2.0.64-KOM-19-version-scheme`, a second `install_full` from the same commit leaves it unchanged. A config without a `version` entry now fails the install instead of being written unchanged. KLSOneAnalyse (`install_fitting`) not run — [VF7](#1-what-onemill-has-today) |
| **V4** | **Title bar and modules** show the product version. **No code of its own** — with no submodule change it follows from V3 ([VQ2](#6-open-points-vq) is the stronger option, deliberately not taken). Consumers: the OS window title and the in-window title bar ([MainWindow.cpp:374, :759](../../../MainApp/src/MainWindow.cpp#L374)), every module via `setMainSoftwareVersion()` ([:946](../../../MainApp/src/MainWindow.cpp#L946)), and through ModuleStatistics the statistics server ([VF13](#1-what-onemill-has-today)). **Install trees only**: a run from the build tree has no `config/mainAppConfig.json`, and MainApp creates one with `0.1.0` ([VF3](#1-what-onemill-has-today)) | The installed app's window title reads `KLSOneMill - 2.2.0.<n>-… - <date>` (readable from the process, no GUI needed); the in-window title bar checked by Martin | ✅ **tested 2026-10-01**: the installed app's window title, read from the running process, is `KLSOneMill - 2.2.0.64-KOM-19-version-scheme - Sep 30 2026` (the date is `__DATE__`, the day `MainWindow.cpp` was compiled), and the app log opens with the same line. After the run MainApp had rewritten `mainAppConfig.json` with the version intact. In-window title bar checked by Martin: correct |
| **V5** | **First-party manifest** ([S2](README.md#shared-items-s1s4)) — written by the install script, one relative path per line, **outside** the install tree so it does not ship ([VQ4](#6-open-points-vq)). One per install target (KLSOneMill, KLSOneAnalyse) | The manifest lists exactly the 12 binaries of [VF11](#1-what-onemill-has-today); disabling one `INSTALL_MOD_*` removes its line | ✅ **tested 2026-10-01**: `<build>/first-party/KLSOneMill.txt` lists the 12, each exists in the tree and carries the version, and no CADS-stamped binary in the tree is missing from it. With `INSTALL_MOD_REPORTER=OFF` into a fresh tree it lists 11, without `ModuleReporter.dll`, which is not staged either; switched back on, 12 again. **Note:** the manifest is what *this run* staged — a disabled module's DLL left in a *reused* tree from an earlier run is not listed. CI stages into a fresh tree, so signing is unaffected |
| **V6** | **Pipeline ([S3](README.md#shared-items-s1s4), version half)** — checkout with full history and tags; `CreateCadsVersion@3` with a harmless `csprojfilepathpattern`; `-DONEMILL_VERSION=$(Build.BuildNumber)` into configure; artifact name from the build number rather than scraped from `mainAppConfig.json`. The verify step fails the run unless the build number, `MainApp.exe`, the installed `mainAppConfig.json` and every binary in the first-party manifest carry the same version | A manual run on this branch is numbered `2.2.0.<n>-KOM-19-version-scheme`, and the staged `MainApp.exe` carries that version. **This is where [§3](#3-target-scheme)'s strings are confirmed** | ✅ **first run green, 2026-10-01** — [run 1900118](https://dev.azure.com/cads-team/KLS%20OneMill/_build/results?buildId=1900118), 16 min, on `37308db`. GitVersion runs on the EC2 agent (bundled `GitVersion.exe` of CreateCadsVersion 3.0.0): `CommitsSinceVersionSource` 66, version source `43f8ced` (= `v2.1.0`), build number **`2.2.0.66-KOM-19-version-scheme`** — exactly what V1's local fallback computes for the same commit. The verify step found that version in `MainApp.exe`, in `mainAppConfig.json` and in all 12 manifest entries; artifact `KLSOneMill-2.2.0.66-KOM-19-version-scheme-relwithdebinfo.zip`, 701 MB |
| **V7** | **`moduleInfo.json`** ([VF8](#1-what-onemill-has-today)) — the ticket leaves *retire or generate* to this story. **Left untouched here** (removing them is a submodule change, [D4](README.md#decisions)) and retired in a later submodule sweep; under [D2](README.md#decisions) they have no role | Decision recorded here | ✅ **decided 2026-09-30** — nothing to implement. Checked 2026-10-01: they are staged into the install tree, and the help dialog reads only the `*.md` beside them. Asked Robert what they are for ([RQ10](README.md#questions-for-robert-rq1rq9)) |
| **V8** | **Merge into KOM-13** — resolve the three conflicted files, re-check [VF7](#1-what-onemill-has-today) against KOM-13's install script, confirm `INSTALL_MOD_MACHINESIM` lands in the manifest | A KOM-13 build reads `2.2.0.<n>-KOM-13-machine-simulation` and its manifest has 13 lines | 🟡 **handed over 2026-10-01** to the KLSOneMill3 session (KOM-13 lives there), via an untracked `HANDOFF-KOM-19-into-KOM-13.md`: merge `origin/develop`, three conflicts with their resolution, D8 on the KOM-13 side, tests. A trial merge found that KOM-13 had already fixed VF7 (`INSTALL_APP_UPDATER`) and the `./` zip entries (its Open-Tasks C2) |

## 6. Open points (VQ)

| ID | Question | Proposal |
| --- | --- | --- |
| **VQ1** | **ProductName for a binary that ships as two products** ([VF6](#1-what-onemill-has-today)). AppLocker publisher rules can match on ProductName | ✅ **Decided 2026-09-30: `KLSOneMill`** for all first-party binaries, including in the KLSOneAnalyse install; KLSOneAnalyse remains a separate *installer* product (KOM-21). Building `MainApp` twice only for the resource is not worth it |
| **VQ2** | **Should the title bar read the version from the binary rather than from `mainAppConfig.json`** ([VF3](#1-what-onemill-has-today))? That is a change in the `MainApp` submodule, which [D4](README.md#decisions) keeps out of this story | Not in KOM-19. The VERSIONINFO is authoritative; the JSON is display. Record as a follow-up for when `MainApp` is touched anyway |
| **VQ3** | **Annotated or lightweight tags?** OneMill has both today: `Version_*` are lightweight (no tagger, no date, no message); `release/*` and `frozen/*` are annotated (created 2026-08-04 at the `develop` switch). GitVersion accepts both. Note that plain `git describe` sees annotated tags only | ✅ **Decided 2026-09-30: annotated** (`git tag -a v2.1.0 43f8ced -m "OneMill 2.1.0"`): they carry tagger, date and message, are pushed by `--follow-tags` and can be signed. For the version itself the choice makes no difference |
| **VQ4** | **Where the manifest file lives.** Options: (A) inside the install tree — ships, becomes part of the MSI and the validated state, and `install_plugins` can leave stale entries; (B) in the build directory, one file per product; (C) generated at configure time from `INSTALL_MOD_*` — lists what *should* be staged, not what *was* | ✅ **Decided 2026-09-30: B** — `<build>/first-party/KLSOneMill.txt` and `KLSOneAnalyse.txt`, one path per line relative to the install root, rewritten (not appended) by every install run at the moment each file is copied. Does not ship. In CI: build dir `out/build/win-msvc-x64-relwithdebinfo`, staged tree `out/install/win-msvc-x64-relwithdebinfo` |
| **VQ5** | **Jira fixVersions** — the KOM project has only `1.0.1` and `2.0` | ✅ **Decided 2026-09-30: create `2.2.0`** so tickets can be assigned to the release the version scheme names. Created by hand in Jira (project KOM → Releases → *Create version*); the Jira connector cannot create versions. **Martin lacks the *Manage versions* permission on KOM (2026-09-30)** — noted, and closed for this work; a project admin creates it when fixVersions are next needed |
| **VQ6** | **The VERSIONINFO strings** — (a) ProductVersion text full or numeric? Explorer shows it as *Product version*, and does not show `Comments`; (b) FileDescription; (c) LegalCopyright; (d) `VS_FF_PRERELEASE` for suffixed versions? | ✅ **Decided 2026-09-30:** (a) **full** informational string — the only place Explorer shows alpha/beta/branch; FILEVERSION and FileVersion stay numeric. (b) `KLSOneMill` (MainApp), `KLSOneMill Updater`, `KLSOneMill FileTransferClient`, `KLSOneMill Module <name>` — the target name without its `Module` prefix (`ModuleView` → `KLSOneMill Module View`), because every plugin target carries it. (c) `Copyright (C) CADS GmbH`, no year, so a new year does not change every binary. (d) yes |

## 7. Risks (VR)

| ID | Risk | Mitigation |
| --- | --- | --- |
| **VR1** | **The local version is computed at configure time**, so a local tree that is not reconfigured after new commits shows a stale `<n>` | Accepted — **decided 2026-09-30: no automatic reconfigure on commit**, as in the Suite; this project's configure is too expensive to rerun per commit. CI always configures fresh, and only CI artifacts are delivered |
| **VR2** | **GitVersion's output on OneMill differs from [§3](#3-target-scheme)** — e.g. because `main` sat at RC10 for months, or because of how `version/*` branches are classified | V6 is the measurement; adjust the local fallback to match what CI produces, never the other way round. **2026-10-01: measured for a feature branch — CI and local fallback agree exactly** (run 1900118). **`develop` measured too**: run 1900282 on `4243a27`, `CommitsSinceVersionSource` 74, `2.2.0.74-alpha`. `release/*` and `main` are confirmed only when they first run |
| **VR3** | **Robert's release routine keeps producing hand-named zips** (`KLSOneMillFullVersion_210_Beta4`) | D1 is decided; tell him with the KOM-9 follow-up. The pipeline artifact becomes the delivery |
| **VR4** | **From V1 until V6, pipeline 824 cannot configure this branch**: it checks out with `fetchDepth: 1` (no tags) and passes no `ONEMILL_VERSION`, and V1 refuses to invent a version. The same holds for any clone that has not fetched the `v*` tags — until V0's push, that is every clone but KLSOneMill4 | Deliberate. **Resolved for CI on 2026-10-01**: V6 is in and the tags are pushed. Still true for a local clone that has not fetched them — `git fetch --tags` fixes it, and the configure error says so |

## 8. Extraction map

| From | To |
| --- | --- |
| [§3](#3-target-scheme) target scheme + the tag convention | Root `README.md`, a short *Versioning* section — the one thing every contributor needs. ✅ **Done 2026-10-01** |
| `OneMillVersion.cmake` behaviour | Its own header comment |
| [VF3](#1-what-onemill-has-today) (version in a runtime-written file) and [VQ2](#6-open-points-vq) | A follow-up ticket if VQ2 is taken up; otherwise one comment in `update_version_json()` |
| [VF7](#1-what-onemill-has-today) (`install_fitting` without `Updater.exe`) | Fixed in the merge or its own ticket |
| Everything else | Stays here; deleted at merge |
