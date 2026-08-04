# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build System

CMake 3.16+ with vcpkg for dependency management. Windows x64, C++20, MSVC with static runtime.

Use the presets — see [README.md](README.md). `Cold start` (the workflow preset) configures, builds
and installs; `Build`/`Install` require an already-configured build directory.

```bash
cmake --workflow --preset onemill-install-win-msvc-x64-relwithdebinfo   # configure + build + install
cmake --build --preset onemill-build-win-msvc-x64-relwithdebinfo        # all
cmake --build <dir> --target deploy   # runs windeployqt, copies to D:/deployData/KLSOneMill
```

Configurations are **RelWithDebInfo (default) and Release only**. There is deliberately no Debug: it
builds and installs but cannot run — static CRT gives `MainApp` and each of the ten plugin DLLs its
own heap, and the debug heap asserts on the first allocation crossing a module boundary. Debug the
RelWithDebInfo build instead.

Dependencies are declared in `vcpkgPackages.txt` (clipper2, spdlog) plus Qt6, VTK 9.4, nlohmann_json, libzippp, pugixml, cpr, Boost resolved via vcpkg.

**Compiling and testing is done manually by the user.** Do not run `cmake`/build commands, invoke a compiler directly (`cl.exe`, `g++`, etc.), or search the filesystem for a compiler in order to verify C++ changes. Review edits by reading the code instead; leave build verification to the user.

## Repository Structure

Every top-level directory is a **separate Git submodule**. Use `GitHelper.ps1` for recursive operations (init, pull, branch, commit, push) across all submodules.

Key components:
- `MainApp/` — Qt main window, module loader, singleton data handler, render context implementation
- `ModuleInterface/` — Header-only abstract base class all plugins must implement
- `ModuleUtils/` — Shared UI utilities: TransformWidget (interactive 3D transform), VTKDrawItems, color/matrix helpers
- `BackendUtils/` — Pure utility library: StringHelper, DirectoryHelper, UUIdHelper, ElapsedTimer, ScopedTempDir
- `GeneralUtils/MeshUtils/` — Mesh/geometry utilities
- `GeneralUtils/OpenXLSX/` — Excel read/write
- `Modules/` — 8 plugin DLLs (each a submodule)

## Plugin Architecture

The application loads modules at runtime from `bin/{CONFIG}/modulesBert/*.dll` using `QPluginLoader`. All modules inherit `ModuleInterface` (declared with `Q_PLUGIN_METADATA` and `Q_DECLARE_INTERFACE`).

**Shared context passed to each module at initialization:**
- `RenderContext` — register/remove VTK render props, request redraws, manage transform widgets
- `FunctionDispatcher` — type-erased function registry for cross-module calls
- `UIParentContext` — Qt parent widgets for embedding module UI

**Module lifecycle virtual methods:** `initialize()`, `onActivate()`, `onDeactivate()`, `onRender()`, file save/load hooks, mouse/keyboard event callbacks.

`ModuleType` is either `Passive` (always active) or `Exclusive` (only one active at a time, managed by `ToolManager`).

## Adding a New Module

1. Create a new Git submodule under `Modules/`.
2. Inherit `ModuleInterface`, annotate with `Q_PLUGIN_METADATA`.
3. In the module's `CMakeLists.txt`, set output to `${CMAKE_SOURCE_DIR}/bin/${CMAKE_BUILD_TYPE}/modulesBert/`.
4. Link against `ModuleInterface`, `ModuleUtils`, `BackendUtils`, Qt6, VTK, spdlog.
5. Use the `MODULE_API` macro (`Q_DECL_EXPORT` when `BUILD_<MODULE>_LIB` is defined, else `Q_DECL_IMPORT`).
6. Add the module subdirectory to the root `CMakeLists.txt`.

## Cross-Module Communication

Modules communicate via `FunctionDispatcher` (not direct includes). Register a named callable during `initialize()`; other modules retrieve and invoke it by name. This keeps modules fully decoupled at the binary level.

## Rendering

VTK-based. Two renderer layers: default and overlay. Modules add `RenderProp`-derived objects via `RenderContext::registerRenderProp()` and call `requestRender()` to trigger a redraw. `TransformWidget` (in `ModuleUtils`) provides interactive 3D translation/rotation handles.

## Singleton Data Access

`MainDataHandler::getInstance()` returns the singleton holding `MainData`, which contains `ToolManager` and `ModuleContext`. Modules receive `ModuleContext` at init and should not call `MainDataHandler` directly.
