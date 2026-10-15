# Installer — work plan (KOM-21, parked)

Last updated: **2026-09-30**
Status: **Parked.** KOM-19 and KOM-20 come first. This file holds what was found while scoping them, so
KOM-21 does not start from zero. Also carries the KOM-22 material (module delivery), because under
[D2](README.md#decisions) the two questions have become one.

> Scope and acceptance criteria are in **[KOM-21](https://cads-team.atlassian.net/browse/KOM-21)** and
> **[KOM-22](https://cads-team.atlassian.net/browse/KOM-22)** ([D7](README.md#decisions)). Decisions that
> shape this plan: **[D2](README.md#decisions)** (one version — OneMill is validated as a whole) and
> **[D3](README.md#decisions)** (per-machine, plus a Preview product).

| § | | § | |
| --- | --- | --- | --- |
| [1](#1-what-validation-as-a-whole-means-here) | What validation as a whole means here | [5](#5-the-in-app-updater-u1u3) | The in-app updater (U1–U3) |
| [2](#2-installers-elsewhere-in-the-company) | Installers elsewhere in the company | [6](#6-moduleworks-deps) | ModuleWorks `deps/` |
| [3](#3-runtime-writes-into-the-install-directory-if) | Runtime writes into the install directory (IF*) | [7](#7-extraction-map) | Extraction map |
| [4](#4-module-delivery-i1i4) | Module delivery (I1–I4) | | |

---

## 1. What validation as a whole means here

Stated by Martin on 2026-09-30 as the reason for [D2](README.md#decisions): **every KLS Martin site validates
OneMill as a complete build before it may mill real patient implants.** Three consequences for this plan,
recorded so they are not re-argued per option:

- **The unit of delivery is the whole installation.** An installer that replaces the installation is
  consistent with that; anything that swaps a single component in place is not.
- **The version on the title bar must describe every file on disk.** That is what KOM-19 delivers, and it is
  what a validation record will cite. A mixed installation makes the record wrong without anyone noticing.
- **Choice is still possible — at install time.** A site may install fewer modules (MSI features, [I1](#4-module-delivery-i1i4)),
  as long as each combination it runs is one it validated.

## 2. Installers elsewhere in the company

| Product | Technology | Scope | Notes |
| --- | --- | --- | --- |
| IPS Suite (`ips-s-installers`) | WiX 6.0.2 SDK project | per-machine (`ProgramFiles64Folder`) | `MajorUpgrade AllowSameVersionUpgrades="yes"`; payload harvested with `<Files Include="!(bindpath.PublishDir)\**">`, `config` harvested separately; non-advertised HKCR file association; stage products (Dev / Qual / Test) side by side, each with its own UpgradeCode and `deployment.json` |
| IPS distribution (`release-manager`) | Release Manager + Endpoint Agent | — | Windows service runs `msiexec /i … /qn` with a SHA256 check; docs under `docs/` |
| inSilico OSA | WiX | per-machine | Installer playbook: `docs/installer-and-pipeline-playbook.md` |
| NAVIGATOR xRSComposer | `.vdproj` | per-machine | |
| CloudDrive | WiX 4 | per-user | a sync client — per-user is justified there |
| IPS CaseDesigner | none | — | zip via `releasetool.exe deploy`, unsigned |

OneMill today ships a ~630 MB zip, 2.7 GB installed.

## 3. Runtime writes into the install directory (IF)

A per-machine install under Program Files is read-only for a normal user. OneMill writes into its own
directory in at least these places. Reading claims; the list is not proven complete.

| ID | Where | What | Evidence |
| --- | --- | --- | --- |
| **IF1** | ModuleFixture | JSON sidecars under `modulesBert/ModuleFixture/config/fixtures/` | `Modules/ModuleFixture/FixtureBackend/src/Config/ConfigHandler.cpp` (~160, ~236, ~355) |
| **IF2** | ModuleUpdater | writes an `updateConfig.json` template on first start; `Updater.exe` swaps files in place and writes `config/versions.json` | [ModuleUpdater/README.md §3, §5](../../../Modules/ModuleUpdater/README.md) |
| **IF3** | PostProcessor | resolves its paths from the **working directory**, not the executable — already wrong when OneMill is started by double-clicking a `.klso` file | [PostProcessorConfig.cpp:60](../../../Modules/ModulePostProcessor/PostProcessorBackend/src/DataDefinition/PostProcessorConfig.cpp#L60) |
| **IF4** | **MainApp itself** | creates `config/mainAppConfig.json` on first start and rewrites it whenever a setting changes (screenshot directory, file-association prompt). *New 2026-09-30*, found while scoping KOM-19 ([VF3](Workplan-Version.md#1-what-onemill-has-today)) | [EnvironmentHandler.cpp:56-75, 130-134](../../../MainApp/src/EnvironmentHandler.cpp#L56-L75) |

Pre-work for KOM-21: move user and machine state to `%APPDATA%` / `%PROGRAMDATA%`, resolve paths from the
executable. IF1–IF3 need submodule branches in ModuleFixture, ModulePostProcessor and ModuleUpdater; IF4 in
MainApp. Not yet checked: the log and crash-dump directory (`EnvironmentHandler::GetLogDirectory()`).

## 4. Module delivery (I1–I4)

**How modules load today.** The loader scans `modulesBert/*.dll` alphabetically and calls
`SetDllDirectoryW(<module>/deps)` per module — a process-global setting
([MainWindow.cpp:916-927](../../../MainApp/src/MainWindow.cpp#L916-L927)). The interface IID
`com.cads.ModuleInterface` carries no version ([ModuleInterface.h:133](../../../ModuleInterface/ModuleInterface.h#L133));
`ModuleInterface.h` has 45 virtuals, 16 commits, the last on 2026-09-11 — a module built against another
revision loads, `qobject_cast` succeeds, and it crashes on the first call. Qt itself rejects plugins built
against a newer Qt; VTK DLL names are versioned, so that mismatch fails cleanly. `FunctionDispatcher` is
string names plus `std::any`, with no compile-time contract. `ModuleUtils`, `BackendUtils` and `MeshLogic`
are static.

| ID | Option | Under [D2](README.md#decisions) |
| --- | --- | --- |
| **I1** | **Modules as MSI features** of the one product (KOM-21) | ✅ **consistent** — the choice is made at install time, and every installed file carries the product version |
| **I2** | Add-on MSI per module, own UpgradeCode, launch condition on the host version (KOM-22) | ⚠️ **questionable** — an add-on that can be installed or upgraded on its own produces combinations nobody validated. Only defensible if every add-on is released and validated *with* a host version |
| **I3** | Copy a module directory into an installation | dev only, never a delivery |
| **I4** | Via the in-app updater | ❌ **contradicts D2** — see [§5](#5-the-in-app-updater-u1u3) |

Signing is no obstacle to any of them: Authenticode is per file. **The versioned IID (RQ7) is worth doing
regardless** — it turns a crash on a stale module into a logged refusal, which matters for I3 on developer
machines as much as for any delivery.

## 5. The in-app updater (U1–U3)

**What exists** (Robert, 2026-07-20 … 29; `Modules/ModuleUpdater`, `Updater/`): a manifest over HTTPS with an
`X-Api-Key` header; per-component zips (a DLL, an exe, a config directory); staging in
`%LOCALAPPDATA%\KLSOneMill\UpdateStaging`; `Updater.exe` swaps files in place with `.bak` rollback and writes
`config/versions.json`. `manifestUrl` is empty by default; the example host `updates.cads.at` does not
resolve; there is no manifest, server or publishing pipeline in the repository.

**Where it collides with an MSI:** writes under Program Files ([IF2](#3-runtime-writes-into-the-install-directory-if));
MSI and updater owning the same files (a repair reverts the update, `.bak` files are left behind, a
higher-version DLL is not overwritten by the next MSI); mixed component states against traceability; every
component zip it ships would need signing.

| ID | Option | Assessment |
| --- | --- | --- |
| **U1** | **Disable it in MSI builds** via the existing `INSTALL_MOD_UPDATER` / `INSTALL_APP_UPDATER` options; the code stays; updates arrive as a new MSI | **Recommended.** Since [D2](README.md#decisions) it is the only option consistent with validation as a whole ([§1](#1-what-validation-as-a-whole-means-here)) |
| **U2** | Elevate `Updater.exe` so it can write under Program Files | Solves the permission problem only; the validation and MSI-ownership problems remain |
| **U3** | The updater downloads a full MSI and runs `msiexec` | Consistent with D2 — it delivers the whole product — but duplicates what Release Manager / Endpoint Agent already do for the Suite |

**What is still needed from Robert:** RQ1 — whether the updater is live anywhere. If it is, U1 breaks
that installation, and it needs a migration path rather than a switch.

## 6. ModuleWorks `deps/`

MillingKalotte, PostProcessor and (on KOM-13) MachineSim each carry the same 91 files — SHA256
byte-identical, `mwCNCSim.dll` 2026.08.3.0, ~750 MB each, ~2.2 GB of 2.7 GB. The DLL names carry no version,
and Windows reuses an already-loaded module name regardless of directory, so **per-module SDK versions
cannot work in one process**: the first module loaded (alphabetically — MachineSim) wins for all of them.
Robert's stated intent was different SDK versions per module (RQ8); under [D2](README.md#decisions) that is
moot as well.

**Open-task candidate** (to be recorded on the KOM-13 side, [D8](README.md#decisions)): one shared ModuleWorks
`deps/` — ~1.5 GB smaller, and the basis for fixing the process-global `SetDllDirectoryW` problem.

## 7. Extraction map

| From | To |
| --- | --- |
| [§1](#1-what-validation-as-a-whole-means-here) (validation as a whole) | KOM-21 and KOM-22 descriptions — **Martin's edit** — and the root `README.md` beside the versioning section, because it is the constraint any future delivery mechanism must meet |
| [IF1](#3-runtime-writes-into-the-install-directory-if)–[IF4](#3-runtime-writes-into-the-install-directory-if) | KOM-21's pre-work list, one sub-task per submodule |
| [§5](#5-the-in-app-updater-u1u3) decision | `Modules/ModuleUpdater/README.md`, once RQ1 is answered and U1 is taken |
| [§6](#6-moduleworks-deps) | Open task on the KOM-13 side |
| Everything else | Stays here until KOM-21 starts |
