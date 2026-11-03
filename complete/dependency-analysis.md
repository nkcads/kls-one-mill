# KLS OneMill – dependency analysis

Resolved from the pinned vcpkg checkout `b81cab76a175645e047601da8f982ad86bff1cc3`, triplet `x64-windows-static`, classic mode.

## 1. Summary

| Metric | Count |
|---|---|
| Direct vcpkg dependencies (documented in `vcpkgPackages.txt`) | **14** |
| Transitive vcpkg dependencies (x64-windows-static) | **99** |
| **vcpkg packages linked into the product** | **113** |
| Host-triplet build tools (x64-windows: protoc/flatc toolchain, vcpkg helper ports) – scope `excluded` | 8 |
| Non-vcpkg components (Qt, VTK, ModuleWorks, Polygonica, OpenXLSX + vendored libs, PyPy, installer binaries, VTK-bundled libs) | 34 |
| **Total components in the new SBOM** | **155** |
| Components in existing `one-mill-sbom-1.6.cdx.json` | 20 |

The new SBOM has 155 components (113 shipped vcpkg packages) against 20 – 7.75× overall, 5.65× on vcpkg packages alone.

## 2. Method

1. Read `vcpkgPackages.txt`, `CMakeLists.txt`, `CMakePresets.json`, `.gitmodules`, `cmake/*.cmake`, and every submodule `CMakeLists.txt`.
2. The existing `vcpkg/` checkout was already at the pinned commit but had **nothing installed** and a `vcpkg.exe` newer than the checkout's scripts (it refused `vcpkg-tools.json`). I re-ran `bootstrap-vcpkg.bat` (downloads vcpkg-tool 2026-07-13), which replaced `vcpkg.exe`.
3. **I did not install/build the packages.** `vcpkg install --dry-run --triplet x64-windows-static <the 14 ports>` yields the exact resolved plan (versions, features, host/target split) without compiling OpenCV, Boost, etc. `vcpkg depend-info --format=dot` on every planned port gives the per-feature direct edges. Both outputs are kept in `inputs/`. Versions and edges come from the same resolver an install would use; what a dry run cannot show is the installed `share/*/vcpkg.spdx.json` per-package files (see gaps).
4. License/homepage/description were read from each `ports/<name>/vcpkg.json`.
5. Compared against `one-mill-sbom-1.6.cdx.json` by component name.

Regenerate: `python -I sbom/complete/gen_complete_sbom.py <repo> <vcpkg_root> sbom/complete`.

## 3. Is the documented list complete?

**For vcpkg ports: yes.** Every `find_package()` in the root and all submodule `CMakeLists.txt` files maps to one of the 14 documented ports (cpr, libzippp, pugixml, spdlog, Clipper2, nlohmann_json, Boost::system, OpenCV, flann, libigl, Eigen3, inja). No direct `#include` of any transitive library was found (curl, zlib, fmt, libzip, png/tiff/jpeg, protobuf, flatbuffers, lz4, lzma, openssl, stb, extra Boost modules: 0 files). No `FetchContent`, `CPM`, or `ExternalProject_Add` exists outside the unbuilt `OpenXLSX/Benchmarks|Documentation` subfolders.

**For the product as a whole: no** – `vcpkgPackages.txt` intentionally covers vcpkg only. Direct dependencies outside it:

| Component | How introduced |
|---|---|
| Qt 6.10.2 (Core, Gui, Widgets, OpenGL, OpenGLWidgets, Network, Svg) | `find_package(Qt6)`, `QTDIR` |
| VTK (9.5 per 1.6 SBOM; `CLAUDE.md` says 9.4 – **discrepancy, please confirm**) | `find_package(VTK)`, `VTK_DIR` |
| ModuleWorks SDK 2026.08, Polygonica | `MODULEWORKS_DIR`, `POLYGONICA_DIR` (commercial) |
| OpenXLSX (submodule `GeneralUtils/OpenXLSX`) | git submodule, with **vendored** pugixml 1.14, zippy, miniz 2.0.8, nowide (`OpenXLSX/external/`) |
| PyPy 3.10 (via ModuleWorks PPFramework), Actipro WPF (Updater) | from `sbom/overlay.cdx.json` |
| Installer-only binaries (OpenSSL 1.1, Tcl/Tk, SQLite, zlib, Embree, DXC, Mesa) and VTK-vendored libs (15) | from `sbom/overlay.cdx.json` – hand-maintained, **not re-verified here** |

Note the vendored pugixml 1.14 inside OpenXLSX is a *second* copy next to the vcpkg `pugixml` 1.16 port; the existing SBOM did not distinguish them.

## 4. Direct dependencies (14)

See `direct-dependencies.txt`. boost-asio 1.91.0, boost-geometry 1.91.0, boost-system 1.91.0, clipper2 2.0.1, cpr 1.14.2, eigen3 5.0.1, flann 2022-10-28, inja 3.5.0#1, libigl 2.6.0#2, libzippp 7.1-1.10.1, nlohmann-json 3.12.0#2, opencv 4.12.0 (metaport), pugixml 1.16, spdlog 1.17.0#1. These match the versions pinned in `vcpkgPackages.txt` exactly.

## 5. Transitive dependencies (99)

See `transitive-dependencies.txt` and `dependency-tree.txt`. 81 of the 99 are Boost modules (boost-asio and boost-geometry pull in a large closure that was not individually documented). The rest:

- **cpr →** curl 8.21.0#1 (features ssl, sspi, non-http) → zlib
- **libzippp →** libzip 1.11.4 (bzip2, default-aes) → bzip2, zlib
- **opencv → opencv4 4.12.0#7 →** protobuf 6.33.4#2 (→ abseil 20260107.1#3, utf8-range), flatbuffers 25.12.19, libpng, libjpeg-turbo 3.2.0, tiff 4.7.2 (→ liblzma, jpeg, zlib), libwebp 1.6.0#2, quirc 1.2, zlib
- **spdlog →** fmt 12.2.0#1
- **libigl →** stb 2024-07-29#1 (and eigen3, already direct); **flann →** lz4 1.10.0
- **boost-asio / boost-geometry →** the 81 transitive Boost libraries, including boost-math, -spirit, -graph, -thread and -serialization.

Security-relevant ones the 1.6 SBOM was blind to: curl, zlib, libpng, libjpeg-turbo, tiff, libwebp, protobuf, libzip, bzip2, liblzma, lz4, abseil.

## 6. Missing-component analysis vs. `one-mill-sbom-1.6.cdx.json`

The 1.6 SBOM lists the 14 direct ports (opencv shown as `opencv4`), Qt, VTK, ModuleWorks, Polygonica, PyPy, OpenXLSX = 20 components and a flat `dependsOn` from the app. Compared to the resolved graph:

- **98 vcpkg target packages missing** (all transitive; `missing-components.txt`)
- **8 host build tools missing** (protobuf, flatbuffers, abseil, utf8-range host builds + 4 vcpkg helper ports)
- **Dependency edges missing:** 1.6 contains 2 `dependencies` entries; the new SBOM has 156.
- **Not in 1.6 but now present:** the vendored OpenXLSX libs (pugixml 1.14, zippy, miniz 2.0.8, nowide), the installer-only binaries, and the VTK-bundled third-party set (these come from the repo's `sbom/overlay.cdx.json`, which the 1.6 file did not merge).

Everything in 1.6 is retained, though its `pkg:generic` purls are unchanged in style.

## 7. Remaining gaps and caveats (please read)

1. **Plan, not an installed tree.** Nothing was compiled or installed, per `CLAUDE.md` guidance against running builds and because OpenCV/Boost would take hours. If you need absolute proof, `vcpkg install` and compare `vcpkg list` to the SBOM; the pipeline script `pipelines/scripts/vcpkg_to_cyclonedx.py` does this on an agent and also reads the per-port SPDX files (suppliers, download URLs, SHA512s), which this SBOM lacks.
2. **Host-vs-target.** The 8 host-triplet tools are marked `scope: excluded`; they do not ship but do matter for build-supply-chain scans.
3. **Port-level, not source-level.** vcpkg ports pin a tarball; any code a port itself vendors (e.g. OpenCV's bundled 3rdparty, libigl's optional deps) is not enumerated.
4. **Licenses:** 135 of 155 components have licenses. Four vcpkg manifests declare `license: null` (opencv, opencv4, quirc, liblzma); I filled Apache-2.0, Apache-2.0, ISC, 0BSD from upstream knowledge and tagged each `cads:license-source` – please confirm. Components without a license: ModuleWorks and Polygonica carry free-text proprietary entries; other overlay entries (versions/licences blank) are inherited unverified. Licenses are copied verbatim from port manifests, so SPDX validity is not independently checked.
5. **PURLs** use `pkg:generic/<name>@<version>` as in the 1.6 SBOM; vcpkg has no registered purl type, and `pkg:generic` matches poorly in Grype/Trivy/Snyk. CPE or upstream (`pkg:github/…`) purls would improve CVE matching but need per-package curation.
6. **Qt/VTK versions** are inherited from the 1.6 SBOM (originally from CMakeCache); no build tree exists here to re-derive them. The VTK 9.4 (`CLAUDE.md`) vs 9.5 (SBOM) discrepancy is unresolved.
7. **Not included:** the 17 first-party git submodules as components (only OpenXLSX, which is third-party), the Updater's .NET/WPF NuGet tree beyond the Actipro overlay entry, and installed-binary content (a Syft scan of the staged install tree remains the right complement).
8. **Side effects in the workspace:** `vcpkg/vcpkg.exe` was replaced by the matching version and vcpkg downloaded cmake 4.4.0/7-zip into `vcpkg/downloads` (untracked). `bootstrap-vcpkg.bat` was run with `-disableMetrics`.
9. Schema: the file is CycloneDX **1.6** (like the existing 1.6 file) and was checked for structural integrity (unique refs, no dangling `dependsOn`) with a script, **not** with `cyclonedx validate` (CLI not installed here).
