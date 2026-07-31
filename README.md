# KLSOneMill

Qt/VTK desktop application for milling preparation. A thin `MainApp` host plus ten plugin DLLs
loaded at runtime from `modulesBert/`.

This file is the front door: how to get from a fresh clone to a running install. Depth lives
elsewhere — see [Where to look next](#where-to-look-next).

## This product

| | |
| --- | --- |
| Live branch | `version/Beta220` — **`main` is dead** (33 commits behind, do not target it) |
| Structure | superproject + 26 git submodules; use `GitHelper.ps1` for recursive operations |
| Deliverable | `MainApp.exe` + `Updater.exe` + 10 plugin DLLs under `modulesBert/` |
| Generator | Ninja, MSVC x64, C++20, static runtime (`x64-windows-static`) |
| Build tree | `D:/BuildDirectory/KLSOneMill/win-msvc-x64-<config>` (set by your `CMakeUserPresets.json`) |
| Install tree | `D:/deployData/KLSOneMill/win-msvc-x64-<config>` (likewise) |
| Build targets | `all`, `install_full`, `install_plugins`, `install_fitting`, `deploy` |
| Configurations | `relwithdebinfo` (default), `release`. There is **no `debug`** — it builds and installs but cannot run (see ledger open item 5); debug the RelWithDebInfo build, it has full PDBs |

## Prerequisites

Machine-level, none of it fetched by the build:

- **Visual Studio 2022** with the C++ x64 toolset, **CMake ≥ 3.25** (workflow presets), **Ninja**
- **Qt 6.10.2** `msvc2022_64` · **VTK 9.5** built with Qt support · **vcpkg**
- **ModuleWorks SDK**, including a valid `mwSupport.lic` (a placeholder license fails at toolpath
  generation with *"License file marker is missing!"*)
- A **`D:` drive** — build and install paths are `D:`-rooted by the presets
- **The PyPy interpreter for the PostProcessor.** It is *not* shipped unpacked in the SDK. Run the
  bundled deployer once per machine, offline:

  ```
  cd <MODULEWORKS_DIR>/PPFramework/PPFramework
  deploy_ppf.exe --no-Config.GUI --Config.OFFLINE --Config.PYPY_TO_INSTALL PyPy310 --Config.DEFAULT_INSTALL_DIR .
  ```

  Run it *from* that folder — it writes a `deploy_ppf.ini` next to itself pinning the interpreter
  path, so a second run elsewhere upgrades the first install instead of creating a new one.

## Cold start

```bash
git clone --recurse-submodules <url> KLSOneMill
cd KLSOneMill
cp CMakeUserPresets.json.example CMakeUserPresets.json   # then edit the machine paths
cmake --workflow --preset onemill-install-win-msvc-x64-relwithdebinfo
```

`CMakeUserPresets.json` is gitignored on purpose: OneMill cannot configure without machine-specific
paths (`QTDIR`, `Qt6_DIR`, `VCPKG_ROOT`, `VTK_DIR`, `MODULEWORKS_DIR`). Until you copy the example,
your IDE's preset list will be **empty** — the checked-in `CMakePresets.json` holds only hidden base
presets.

The workflow runs configure → build `all` → `install_full`. Add `--fresh` to wipe the cache; it is
**not** the default.

## Day-to-day builds

**From VS Code:** `Ctrl+Shift+B`, or *Terminal → Run Task* and pick a
`Build | …` / `Install | …` entry. These route through `.vscode/dev-run.cmd`, which enters the VS
developer environment, caps parallelism at cores−2 and runs at below-normal priority so a build
never freezes the machine.

> **`Build`/`Install` need an already-configured build directory.** `cmake --build --preset` never
> configures one itself, so on a fresh clone — or after deleting the build directory — they fail with
> `<dir> is not a directory`. Run **`Cold start | Win | MSVC | x64 | <config>`** instead: it is the
> workflow preset, so it configures, builds `all` and runs `install_full` in one step. That is the
> only recovery action there is; deliberately no separate Configure task exists, so there is never a
> question of which one to run.

> **Do not use the CMake sidebar's Build/Install buttons.** CMake Tools substitutes its own
> status-bar target into *every* build step, including each step of a workflow preset — so
> "Workflow → Install" builds only that one target and installs nothing, while reporting success.
> This is a CMake Tools behaviour, not a preset bug. Use the tasks or the CLI.

**From a terminal:**

```bash
cmake --build --preset onemill-build-win-msvc-x64-relwithdebinfo            # all
cmake --build --preset onemill-install-target-win-msvc-x64-relwithdebinfo   # install_full
```

`install_full` builds every prerequisite itself, so it is safe to run on its own.

Open `KLSOneMill.code-workspace` (not the bare folder) — it ships the VS Dev PowerShell profile that
puts `cl`/`ninja` on `PATH` in the integrated terminal.

## Full reset

After editing `CMakeUserPresets.json` — a new Qt, VTK, vcpkg or ModuleWorks path — the existing
CMake cache still holds the old values and wins over the preset. Rather than reaching for
`--fresh`, wipe and cold start:

1. Delete the build directory and the install directory. **Both paths are in your own
   `CMakeUserPresets.json`** (`binaryDir` and `INSTALL_DIR`; also `INSTALL_DIR_FITTING` if you use
   `install_fitting`).
2. Run the **`Cold start | …`** task for that configuration.

There is deliberately **no Clean task**. `cmake --build --target clean` would not clean what
matters: the per-module `add_custom_target(... ALL)` steps copy `config/`, `releaseNotes/` and the
ModuleWorks `deps/` folders into `bin/<config>/modulesBert/`, and Ninja does not track those as
outputs, so they would survive. A half-clean that leaves stale plugin data behind is worse than
none — it produces bugs that look like code bugs.

## Adding a module

See the "Adding a New Module" section of [CLAUDE.md](CLAUDE.md). Nothing extra is needed to make it
install: `install_full` depends on every buildable target in the tree, so a new module and its copy
targets are picked up automatically.

## When the install fails

`install_full` **fails hard** on a missing module DLL, `deps/` or `interpreter/`, with the
remediation in the message. That is deliberate: it used to warn and exit 0, which is how a
PostProcessor without a Python interpreter shipped unnoticed.

## Where to look next

| Document | For |
| --- | --- |
| [.vscode/OneMill-Setup-Ledger.md](.vscode/OneMill-Setup-Ledger.md) | The toolchain setup, the eight fixes this branch needs, hard-won gotchas, and the open questions for the dev lead |
| [.vscode/OneMill-Repo-Landscape.md](.vscode/OneMill-Repo-Landscape.md) | Branch/submodule topology and proposals for the repository workflow |
| [.vscode/OneMill-Fleet-Conformance.md](.vscode/OneMill-Fleet-Conformance.md) | Which CADS fleet build rules OneMill follows, which it deliberately does not, and why |
| [CLAUDE.md](CLAUDE.md) | Architecture: plugin model, render context, cross-module communication |
