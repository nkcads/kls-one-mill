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

- **Visual Studio 2022 or newer** with the C++ x64 toolset (verified on VS 2022 and VS 18),
  **CMake ≥ 3.25** (workflow presets), **Ninja**
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

Do this once, whichever IDE you use:

```bash
git clone --recurse-submodules <url> KLSOneMill
cd KLSOneMill
cp CMakeUserPresets.json.example CMakeUserPresets.json   # then edit the machine paths
```

`CMakeUserPresets.json` is gitignored on purpose: OneMill cannot configure without machine-specific
paths (`QTDIR`, `Qt6_DIR`, `VCPKG_ROOT`, `VTK_DIR`, `MODULEWORKS_DIR`). Until you copy the example,
your IDE's preset list will be **empty** — the checked-in `CMakePresets.json` holds only hidden base
presets.

Then follow the walkthrough for your IDE. Both drive the *same* presets, so one checkout serves both
and they can share a build directory — there is no VS-specific or VS Code-specific configuration.

### Cold start in VS Code (recommended)

1. Open **`KLSOneMill.code-workspace`** — *File → Open Workspace from File…*, **not** a plain folder
   open. Only the workspace file ships the `VS Dev PowerShell (x64)` terminal profile
   (`.vscode/dev-shell.ps1`), which puts `cl`/`ninja` on `PATH`.
2. *Terminal → Run Task…* → **`Cold start | Win | MSVC | x64 | RelWithDebInfo`**. That is the whole
   cold start: configure → build `all` → `install_full`.
3. Check it runs: **Run & Debug** sidebar → *OneMill (installed folder, RelWithDebInfo)*. The cold
   start just installed, so the install tree is current.
4. For the day-to-day loop, first decide **which tree you debug** — it determines whether you rebuild
   with `Build | …` or `Install | …`. See
   [Which tree are you running?](#which-tree-are-you-running) before you settle into a habit.

Prefer the tasks over pasting commands: they route through `.vscode/dev-run.cmd`, so they get the
MSVC environment, the parallelism cap and below-normal priority regardless of how VS Code was
launched.

### Cold start in Visual Studio

Verified with Visual Studio 18. No solution file exists — this is folder-open CMake mode.

> **Disable the Qt Visual Studio Tools extension first.** It rewrites `CMakePresets.json` *and*
> `CMakeUserPresets.json` behind your back — adding a hidden `Qt` preset plus a
> `Qt-Default` → `msvc2022_64` chain, and appending `"Qt-Default"` to the `inherits` of your configure
> presets. It then removed its own `Qt` preset from `CMakePresets.json` on a later pass while leaving
> the dependents in the user file, which left `msvc2022_64` inheriting a preset that no longer existed:
>
> ```
> CMake Error: Could not read presets ... Invalid preset: "msvc2022_64"
> ```
>
> With the preset files unreadable, Visual Studio silently falls back to its built-in `x64-debug`
> configuration. That has no `VCPKG_ROOT` cache variable, so `CMakeLists.txt` falls back to
> `$ENV{VCPKG_ROOT}` — which `VsDevCmd.bat` points at **Visual Studio's own bundled vcpkg** — and the
> configure dies on `find_package(cpr)`. One extension write, and the whole toolchain silently
> switches.
>
> *Extensions → Manage Extensions → Qt Visual Studio Tools → Disable*, then restart. Nothing here
> needs it: Qt is located via `Qt6_DIR` in the presets, and OneMill has no `.pro` files or Qt MSBuild
> projects.
>
> **If it already happened:** delete the `Qt-Default` and `msvc2022_64` presets from
> `CMakeUserPresets.json`, remove `"Qt-Default"` from both configure presets' `inherits`, drop the
> trailing `qt-project.org/Presets` vendor block, and check `cmake --list-presets` succeeds. Also
> delete the stale `out/build/x64-debug` tree the fallback configure left behind.
>
> `CMakePresets.json` is **committed**, so this is not only a local problem — an injected or removed
> preset there breaks the build environment for everyone who pulls it.

1. *File → Open → Folder…* on the repository root.
2. *Tools → Options → CMake → General* → enable **“Always use CMakePresets.json”**, then **close and
   reopen the folder**. Without this, Visual Studio ignores the presets, the dropdowns stay empty,
   and it looks exactly like the "you forgot to copy `CMakeUserPresets.json`" failure.
3. **You do not configure manually — Visual Studio does it for you** on folder open, on preset change,
   and whenever the cache goes stale. So there is no Cold start button to look for, and the
   `<dir> is not a directory` trap that VS Code has does not exist here. Even after wiping the build
   directory, reopening the folder reconfigures.

   Pick the configuration you want in the toolbar. On VS 18 the dropdowns are *Target System* (`Local
   Machine`), the **build preset** (`Build | …` or `Install (target only) | …`), the startup item, and a
   short configuration selector (`RelWithDebInfo` / `Release`) — note there is **no dropdown labelled
   "Configure"**; the configure preset follows from the build preset's `configurePreset` field.

   If it ever does not configure by itself: *Project → Configure `<project>`*, or
   *Project → Delete Cache and Reconfigure*. From a terminal it is
   `.vscode\dev-run.cmd cmake --preset onemill-config-win-msvc-x64-relwithdebinfo`.
4. **Add the launch configuration now, before you build.** Do this once per checkout — until you do,
   the startup-item dropdown offers only the build-tree targets Visual Studio discovered by itself
   (`MainApp.exe (bin\RelWithDebInfo\MainApp.exe)`), there is **no `OneMill` entry**, and those
   auto-discovered entries fail on a missing VTK DLL because they carry no `PATH`. Use
   *Debug → Debug and Launch Settings → MainApp* to have Visual Studio create
   `.vs/launch.vs.json`, then paste the entry from the **note below**.
5. *Build → Build All* — equivalent to the `Build | …` preset, target `all`.
6. **Install — optional, only if you want the install tree.** Switch to **CMake Targets View** in
   Solution Explorer, right-click **`install_full`** → *Build*. From a terminal,
   `.vscode\dev-run.cmd cmake --build --preset onemill-install-target-win-msvc-x64-relwithdebinfo`
   does the same with the parallelism cap applied.

   > **Do not install by picking `Install (target only)` in the Build Preset dropdown.** Observed on
   > Visual Studio 18: selecting that preset and running *Build All* rebuilds `all`, reports success,
   > and **never runs `install_full`** — the install tree is not even created. Microsoft documents
   > `buildPresets.targets` as unsupported by the Visual Studio CMake integration, so the `targets`
   > list in that preset is ignored. Use Targets View or a terminal.
7. **Run/Debug:** startup-item dropdown → *OneMill (build tree, `<config>`)* → `F5`. Visual Studio
   debugs the **build tree** — never the install tree, see the note below. Daily loop is therefore
   *edit → Build All → F5*, and step 6 is only needed when the install tree itself is the point. To
   exercise the *installed* artifact, run it outside Visual Studio or from VS Code.

> **Do not use Visual Studio's `Install` command (or `cmake --install`).** OneMill defines **no
> `install()` rules**; the only ones anywhere in the tree belong to the vendored OpenXLSX submodule.
> So that command installs OpenXLSX headers and libraries, reports success, and installs none of the
> application. `install_full` is the install.

> **The launch entry for step 4 — put Qt and VTK on `PATH`.** The build tree holds no Qt/VTK DLLs next
> to `MainApp.exe`, so a bare F5 on one of Visual Studio's auto-discovered targets fails with
> `vtkRenderingCellGrid-9.5.dll was not found`, or starts and then cannot load
> `ModuleMillingKalotte.dll` (the module with the largest dependency closure). `.vs/launch.vs.json` is
> gitignored, so this stays per-developer. **Add one entry per configuration** — `projectTarget`
> embeds the configuration, so an entry bound to RelWithDebInfo simply does not appear in the dropdown
> under Release, and it looks as if your launch configuration vanished:
>
> ```jsonc
> "configurations": [
>   {
>     "type": "default",
>     "project": "CMakeLists.txt",
>     "projectTarget": "MainApp.exe (bin\\RelWithDebInfo\\MainApp.exe)",
>     "name": "OneMill (build tree, RelWithDebInfo)",
>     "currentDir": "D:\\BuildDirectory\\KLSOneMill\\win-msvc-x64-relwithdebinfo\\bin\\RelWithDebInfo",
>     "env": {
>       "PATH": "D:\\DevTools\\Qt\\6.10.2\\msvc2022_64\\bin;D:\\DevTools\\vtk\\install\\bin;${env.PATH}"
>     }
>   },
>   {
>     "type": "default",
>     "project": "CMakeLists.txt",
>     "projectTarget": "MainApp.exe (bin\\Release\\MainApp.exe)",
>     "name": "OneMill (build tree, Release)",
>     "currentDir": "D:\\BuildDirectory\\KLSOneMill\\win-msvc-x64-release\\bin\\Release",
>     "env": {
>       "PATH": "D:\\DevTools\\Qt\\6.10.2\\msvc2022_64\\bin;D:\\DevTools\\vtk\\install\\bin;${env.PATH}"
>     }
>   }
> ]
> ```
>
> Visual Studio shows whichever entry matches the active configuration, so you never see both at once.
> Use *your* Qt, VTK and build-tree paths — the same ones your `CMakeUserPresets.json` points at.
> Verified working on Visual Studio 18: the app starts from the build tree and all ten modules load,
> milling included. Developers whose machine `PATH` already carries both directories never notice this
> and need no launch configuration at all — which is exactly why it works on one PC and not another.
>
> **Match the Qt on `PATH` to the Qt you build against.** If a *different* Qt installation is on the
> system `PATH` (e.g. `C:\Qt\...` while the build uses `D:\DevTools\Qt\...`), the build-tree exe loads
> Qt from that other install. It works while the versions happen to match and produces inexplicable
> behaviour when they stop matching. Listing your build's Qt `bin` first, as above, closes that gap.
>
> **Visual Studio cannot launch the installed tree.** A configuration bound to a CMake target
> (`project` + `projectTarget`) ignores `program`, even with a literal absolute path — and without
> `projectTarget` the entry does not appear in the startup dropdown at all. So there is no way to
> point Visual Studio's debugger at `INSTALL_DIR`. Debug the build tree; to exercise the installed
> artifact, launch it outside Visual Studio, or use VS Code's *OneMill (installed folder, …)* entry.

> **Do not mix in `startCmake.bat`.** It launches `cmake-gui`, which defaults to the **Visual Studio
> generator** — multi-config, ignores `CMAKE_BUILD_TYPE`, re-exposes a Debug configuration that
> cannot run, and writes to `D:/BuildDirectory/KLSOneMill` with no config suffix. It is left untouched
> for whoever still relies on it, but it is a different build tree from the presets.

## Day-to-day builds

### Which tree are you running?

There are **two** runnable copies of OneMill, and knowing which one your debugger launches decides
what you have to rebuild. Get this wrong and you debug yesterday's code while your change appears to
do nothing.

| | Build tree | Install tree |
| --- | --- | --- |
| Where | `binaryDir`/`bin/<config>/` | `INSTALL_DIR` |
| Produced by | **`all`** | **`install_full`** |
| Contains | both exes, 10 module DLLs, each module's `config/` + `releaseNotes/`, ModuleWorks `deps/` | the same **plus** 171 staged Qt/VTK/runtime DLLs |
| Qt/VTK next to the exe | **no** — needs them on `PATH` | yes — self-contained |
| After changing a file, rebuild | **`all`** | **`install_full`** |

**The rule: rebuild whatever produced the tree you launch.**

- Debugging the **build tree** → `all` is enough, for *any* change. The per-module `Copy*ConfigData`
  and `Copy*ReleaseNotes` targets are `ALL` targets and re-copy on every build, so edited `config/`
  JSON and machine files land there too — no staleness.
- Debugging the **install tree** → you must run `install_full`. Building `all` and pressing F5 runs
  the *previously installed* binaries.

**Recommendation for the edit-build-debug loop: use the build tree.** It is the only thing Visual
Studio can debug at all, so both IDEs then behave identically, and it avoids `install_full`'s cost —
`install_app.cmake` uses plain `file(COPY …)` rather than copy-if-different and re-runs `windeployqt`
every time, so each install unconditionally rewrites a ~1.8 GB tree. It also bumps the title-bar
version counter on every run (see the ledger).

**Use `install_full` when the install tree is the point:** verifying the shipped layout, checking the
Qt/VTK staging, handing a build to someone, or testing the app as deployed. It depends on every
buildable target, so run it *alone* — it builds what is out of date first, and `all` beforehand is
redundant. It stages both exes, all ten module DLLs, 171 top-level DLLs, every module's `config/` and
`releaseNotes/`, and the 57 ModuleWorks DLLs plus `mwSupport.lic` into `deps/` for
`ModuleMillingKalotte` and `ModulePostProcessor` — and **fails hard** with a remediation hint if any
of it is missing, see [When the install fails](#when-the-install-fails).

### In VS Code (recommended)

VS Code can debug **either** tree — `launch.json` ships entries for both, so check which one you
picked:

| Run & Debug entry | Tree | Rebuild with |
| --- | --- | --- |
| *OneMill (build tree, follows selected preset)* | build | **`Build \| …`** (`all`) |
| *OneMill (installed folder, `<config>`)* | install | **`Install \| …`** (`install_full`) |
| *OneMill Updater (installed folder, …)* | install | `Install \| …` |

The build-tree entry already prepends Qt and VTK `bin` to `PATH` — nothing to set up. It follows the
CMake sidebar's **launch target**, so select `MainApp` there once. (Selecting a launch target is fine;
it is only the sidebar's *Build/Install buttons* that are off-limits.)

| Action | How |
| --- | --- |
| Build `all` | `Ctrl+Shift+B`, or *Run Task* → `Build \| Win \| MSVC \| x64 \| <config>` |
| Install | *Run Task* → `Install \| Win \| MSVC \| x64 \| <config>` |
| Both, from scratch | *Run Task* → `Cold start \| Win \| MSVC \| x64 \| <config>` |

> **`Build`/`Install` need an already-configured build directory.** `cmake --build --preset` never
> configures one itself, so on a fresh clone — or after deleting the build directory — they fail with
> `<dir> is not a directory`. Run **`Cold start | …`** instead. That is the only recovery action there
> is; deliberately no separate Configure task exists, so there is never a question of which one to
> run.

> **Do not use the CMake sidebar's Build/Install buttons.** CMake Tools substitutes its own status-bar
> target into *every* build step, including each step of a workflow preset — so "Workflow → Install"
> builds only that one target and installs nothing, while reporting success. This is a CMake Tools
> behaviour, not a preset bug. Use the tasks or the CLI.

### In Visual Studio

Visual Studio can only debug the **build tree**, so the loop is always *edit → `all` → F5* — you never
need `install_full` unless you specifically want the install tree.

| Action | How |
| --- | --- |
| Configure | automatic — on folder open, on preset change, and whenever the cache goes stale |
| Build `all` | *Build → Build All* |
| Install | **CMake Targets View** → `Install` folder → right-click **`install_full`** → *Build* |
| Run | startup-item dropdown (next to the green ▶) → *OneMill (build tree, `<config>`)* → `F5`, with `PATH` set once in `.vs/launch.vs.json` (see the Cold start note) |

Switch Solution Explorer to CMake Targets View with its view-selector button; the project's
`assign_solution_folder` calls group the install targets under **`Install`**, next to
`install_plugins`, `install_fitting` and `deploy`.

> **`install_full` cannot be run from the Build Preset dropdown.** Picking `Install (target only)` and
> pressing *Build All* rebuilds `all`, reports success, and never installs — Visual Studio ignores
> `buildPresets.targets`. Use Targets View, or a terminal.

### From a terminal

```bash
cmake --build --preset onemill-build-win-msvc-x64-relwithdebinfo            # all
cmake --build --preset onemill-install-target-win-msvc-x64-relwithdebinfo   # install_full
```

Prefix `.vscode\dev-run.cmd` on either to get the MSVC environment plus the parallelism cap and
below-normal priority — it works from any shell. The two targets not wired to presets are run the
same way: `cmake --build <dir> --target install_plugins` (modules only) and
`--target install_fitting` (the standalone KLSOneAnalyse deployment into `INSTALL_DIR_FITTING`).

### Build responsiveness — don't freeze your PC

A OneMill build can pin every core. Where you start it decides what protects you:

| Where you build | Parallelism cap (cores−2) | Below-normal priority |
| --- | --- | --- |
| VS Code task / `.vscode\dev-run.cmd <cmd>` | yes | **yes** |
| `VS Dev PowerShell (x64)` integrated terminal | yes | no |
| **Visual Studio** (Build All, Targets View) | **no** | no |
| Plain terminal / raw CLI | no | no |

`dev-run.cmd` works from *any* terminal — prefix it on any `cmake --build` to get the full effect.
Visual Studio invokes `cmake --build --preset` itself and never routes through the wrapper, so it
builds uncapped: Ninja defaults to **cores + 2**, which is 18 jobs on a 16-core machine. That is
accepted rather than fixed — pinning `jobs` in the build presets would also override the cap for
VS Code and the CLI.

**Never add a bare `--parallel`** to `cmake --build`: CMake only consults `CMAKE_BUILD_PARALLEL_LEVEL`
when `--parallel` is absent, so passing it defeats the cap and oversubscribes.

## Full reset

After editing `CMakeUserPresets.json` — a new Qt, VTK, vcpkg or ModuleWorks path — the existing
CMake cache still holds the old values and wins over the preset. Rather than reaching for
`--fresh`, wipe and cold start:

1. Delete the build directory and the install directory. **Both paths are in your own
   `CMakeUserPresets.json`** (`binaryDir` and `INSTALL_DIR`; also `INSTALL_DIR_FITTING` if you use
   `install_fitting`).
2. **VS Code:** run the **`Cold start | …`** task for that configuration.

   **Visual Studio:** reopen the folder, or *Project → Configure* — it reconfigures on its own, then
   *Build All* and `install_full`. If the cache looks stuck, *Project → Delete Cache and Reconfigure*.

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
