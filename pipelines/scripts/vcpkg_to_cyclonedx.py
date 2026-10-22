#!/usr/bin/env python3
# vcpkg_to_cyclonedx.py - assemble the AUTHORITATIVE CycloneDX 1.7 SBOM for KLS OneMill.
#
# OneMill uses vcpkg in CLASSIC mode (no vcpkg.json manifest), so the version lock is the
# vcpkg checkout commit and the installed tree. This script turns the machine-readable records
# vcpkg already writes - plus the external toolchain versions CMake resolved and the git
# submodule pins - into one CycloneDX 1.7 document, with correct versions, SPDX-concluded
# licenses, suppliers, and the real port-to-port dependency graph.
#
# It is deliberately the "inventory of record": it does NOT look at built binaries. The runtime
# SBOM (Syft on the staged install tree) is produced separately and merged with cyclonedx-cli.
# See pipelines/onemill-build-windows.yml, the "SBOM" stage.
#
# INPUTS (all optional except --vcpkg-json; the SBOM degrades gracefully if a source is absent):
#
#   --vcpkg-json        out of `vcpkg list --x-json`           -> component set + exact versions
#   --vcpkg-share       <VCPKG_ROOT>/installed/<triplet>/share -> per-port vcpkg.spdx.json:
#                                                                 license, homepage, download URL,
#                                                                 supplier
#   --depend-info-json  out of `vcpkg depend-info --x-json ...`-> port-to-port dependency edges
#                                                                 (the ONLY reliable edge source;
#                                                                  without it the graph is flat)
#   --cmake-cache       out/build/.../CMakeCache.txt           -> Qt / VTK versions (external,
#                                                                 not vcpkg ports)
#   --submodules-root   repo root                              -> git submodules as components
#   --overlay           a CycloneDX json fragment              -> what tooling cannot derive:
#                                                                 ModuleWorks, Polygonica, PyPy,
#                                                                 VTK's vendored third-party set
#
# OUTPUT: a CycloneDX 1.7 JSON BOM at --out.  With --validate it is then checked with the
# CycloneDX CLI (`cyclonedx validate`) and a non-zero validation result fails the script.
#
# Stdlib only - runs under the agent's bare Python with no pip step.  Produce the inputs with:
#
#   vcpkg list --x-json > vcpkg-installed.json
#   vcpkg depend-info --x-json $(vcpkg list | awk -F: '{print $1}' | sort -u) > vcpkg-depend.json
#
from __future__ import annotations

import argparse
import datetime as _dt
import json
import os
import re
import subprocess
import sys
import uuid
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple

TRIPLET_DEFAULT = "x64-windows-static"

# OneMill's DIRECT vcpkg dependencies - the ports the repository #includes or find_package()s,
# from vcpkgPackages.txt. Everything else vcpkg installs is transitive. Used only to attach the
# direct set to the application node when no depend-info graph is supplied (flat fallback).
DIRECT_PORTS = {
    "boost-asio", "boost-geometry", "boost-system", "clipper2", "cpr", "eigen3", "flann",
    "inja", "libigl", "libzippp", "nlohmann-json", "opencv", "opencv4", "pugixml", "spdlog",
}

# Port -> upstream GitHub "owner/repo". A GitHub purl (pkg:github/owner/repo@ver) is matchable
# by OSV/GHSA, unlike pkg:generic. Extend as new ports enter the closure; an unmapped port
# falls back to pkg:generic and still carries its CPE (below) for NVD matching.
PORT_TO_GITHUB = {
    "boost-asio": "boostorg/asio", "boost-geometry": "boostorg/geometry",
    "boost-system": "boostorg/system", "clipper2": "AngusJohnson/Clipper2",
    "cpr": "libcpr/cpr", "eigen3": "libeigen/eigen", "flann": "flann-lib/flann",
    "inja": "pantor/inja", "libigl": "libigl/libigl", "libzippp": "ctabin/libzippp",
    "nlohmann-json": "nlohmann/json", "opencv": "opencv/opencv", "opencv4": "opencv/opencv",
    "pugixml": "zeux/pugixml", "spdlog": "gabime/spdlog", "fmt": "fmtlib/fmt",
    "zlib": "madler/zlib", "curl": "curl/curl", "libpng": "pnggroup/libpng",
    "libjpeg-turbo": "libjpeg-turbo/libjpeg-turbo", "tiff": "libsdl-org/libtiff",
    "libwebp": "webmproject/libwebp", "protobuf": "protocolbuffers/protobuf",
    "abseil": "abseil/abseil-cpp", "libzip": "nih-at/libzip", "bzip2": "libarchive/bzip2",
    "zstd": "facebook/zstd", "brotli": "google/brotli", "openjpeg": "uclouvain/openjpeg",
    "quirc": "dlbeer/quirc", "freetype": "freetype/freetype", "harfbuzz": "harfbuzz/harfbuzz",
    "pcre2": "PCRE2Project/pcre2", "double-conversion": "google/double-conversion",
    "liblzma": "tukaani-project/xz", "nghttp2": "nghttp2/nghttp2", "lz4": "lz4/lz4",
    "expat": "libexpat/libexpat", "libxml2": "GNOME/libxml2",
}

# High-confidence NVD CPE 2.3 vendor:product pairs. Only ports whose CPE is stable in the NVD
# dictionary - an invented CPE matches nothing AND hides the gap, so leave a port out rather
# than guess. The version is filled in per component. {v} is the placeholder.
PORT_TO_CPE = {
    "boost-asio": "cpe:2.3:a:boost:boost:{v}:*:*:*:*:*:*:*",
    "boost-geometry": "cpe:2.3:a:boost:boost:{v}:*:*:*:*:*:*:*",
    "boost-system": "cpe:2.3:a:boost:boost:{v}:*:*:*:*:*:*:*",
    "opencv": "cpe:2.3:a:opencv:opencv:{v}:*:*:*:*:*:*:*",
    "opencv4": "cpe:2.3:a:opencv:opencv:{v}:*:*:*:*:*:*:*",
    "nlohmann-json": "cpe:2.3:a:nlohmann:json:{v}:*:*:*:*:*:*:*",
    "pugixml": "cpe:2.3:a:pugixml_project:pugixml:{v}:*:*:*:*:*:*:*",
    "zlib": "cpe:2.3:a:zlib:zlib:{v}:*:*:*:*:*:*:*",
    "curl": "cpe:2.3:a:curl:curl:{v}:*:*:*:*:*:*:*",
    "libpng": "cpe:2.3:a:libpng:libpng:{v}:*:*:*:*:*:*:*",
    "tiff": "cpe:2.3:a:libtiff:libtiff:{v}:*:*:*:*:*:*:*",
    "libjpeg-turbo": "cpe:2.3:a:libjpeg-turbo:libjpeg-turbo:{v}:*:*:*:*:*:*:*",
    "protobuf": "cpe:2.3:a:google:protobuf:{v}:*:*:*:*:*:*:*",
    "freetype": "cpe:2.3:a:freetype:freetype:{v}:*:*:*:*:*:*:*",
    "libxml2": "cpe:2.3:a:xmlsoft:libxml2:{v}:*:*:*:*:*:*:*",
    "expat": "cpe:2.3:a:libexpat_project:libexpat:{v}:*:*:*:*:*:*:*",
}

# Fallback licenses for ports whose spdx licenseConcluded is NOASSERTION. Best-effort, SPDX ids.
KNOWN_LICENSE = {
    "boost-asio": "BSL-1.0", "boost-geometry": "BSL-1.0", "boost-system": "BSL-1.0",
    "clipper2": "BSL-1.0", "cpr": "MIT", "eigen3": "MPL-2.0 AND BSD-3-Clause AND Apache-2.0",
    "flann": "BSD-3-Clause", "inja": "MIT", "libigl": "MPL-2.0", "libzippp": "BSD-3-Clause",
    "nlohmann-json": "MIT", "opencv": "Apache-2.0", "opencv4": "Apache-2.0", "pugixml": "MIT",
    "spdlog": "MIT", "fmt": "MIT", "zlib": "Zlib", "curl": "curl", "libpng": "Libpng",
    "libjpeg-turbo": "BSD-3-Clause AND IJG AND Zlib", "tiff": "libtiff", "libwebp": "BSD-3-Clause",
    "protobuf": "BSD-3-Clause", "abseil": "Apache-2.0", "libzip": "BSD-3-Clause",
    "bzip2": "bzip2-1.0.6", "zstd": "BSD-3-Clause AND GPL-2.0-only", "brotli": "MIT",
    "freetype": "FTL AND GPL-2.0-only", "harfbuzz": "MIT", "pcre2": "BSD-3-Clause",
}

SPDX_LICENSE_RE = re.compile(r"^[A-Za-z0-9.\-+]+$")


# --------------------------------------------------------------------------------------------
# small helpers
# --------------------------------------------------------------------------------------------
def _log(msg: str) -> None:
    print(f"[vcpkg-sbom] {msg}", file=sys.stderr)


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8-sig") as fh:
        return json.load(fh)


def make_license(expr: Optional[str], acknowledgement: str) -> List[Dict[str, Any]]:
    """A CycloneDX license array from an SPDX string. Compound expressions use `expression`,
    a bare id uses `id`, anything else uses `name`. NOASSERTION/empty -> [] (omit)."""
    if not expr:
        return []
    expr = expr.strip()
    if expr.upper() in ("NOASSERTION", "NONE", ""):
        return []
    compound = any(tok in f" {expr} " for tok in (" AND ", " OR ", " WITH ")) or "(" in expr
    if compound:
        return [{"expression": expr, "acknowledgement": acknowledgement}]
    if SPDX_LICENSE_RE.match(expr):
        return [{"license": {"id": expr, "acknowledgement": acknowledgement}}]
    return [{"license": {"name": expr, "acknowledgement": acknowledgement}}]


def purl_for(port: str, version: str) -> str:
    gh = PORT_TO_GITHUB.get(port)
    ver = f"@{version}" if version else ""
    if gh:
        return f"pkg:github/{gh}{ver}"
    return f"pkg:generic/{port}{ver}"


def cpe_for(port: str, version: str) -> Optional[str]:
    tmpl = PORT_TO_CPE.get(port)
    return tmpl.format(v=version or "*") if tmpl else None


def supplier_from(homepage: str, download: str) -> Optional[Dict[str, Any]]:
    url = homepage or download or ""
    m = re.search(r"https?://(?:www\.)?([^/]+)", url)
    if not m:
        return None
    host = m.group(1)
    return {"name": host, "url": [f"https://{host}"]}


# --------------------------------------------------------------------------------------------
# vcpkg list --x-json  ->  {port: {version, port_version, features, triplet}}
# --------------------------------------------------------------------------------------------
def parse_vcpkg_list(path: Path, triplet: str) -> Dict[str, Dict[str, Any]]:
    data = load_json(path)
    out: Dict[str, Dict[str, Any]] = {}
    # Keys look like "name:triplet" or "name[feature]:triplet". We fold feature rows into the
    # base port and keep the union of features. Only rows for our triplet are kept.
    for key, val in data.items():
        pkg = (val or {}).get("package_name") or key.split(":", 1)[0].split("[", 1)[0]
        trip = (val or {}).get("triplet") or (key.rsplit(":", 1)[1] if ":" in key else "")
        if trip and triplet and trip != triplet:
            continue
        entry = out.setdefault(pkg, {"version": "", "port_version": 0, "features": set(),
                                     "triplet": trip or triplet})
        ver = (val or {}).get("version")
        if ver and not entry["version"]:
            entry["version"] = str(ver)
        pv = (val or {}).get("port_version")
        if isinstance(pv, int) and pv > entry["port_version"]:
            entry["port_version"] = pv
        feat = key.split("[", 1)[1].rstrip("]").rsplit(":", 1)[0] if "[" in key else None
        if feat:
            entry["features"].add(feat)
        for f in (val or {}).get("features", []) or []:
            entry["features"].add(f)
    for e in out.values():
        e["features"] = sorted(e["features"])
    _log(f"vcpkg list: {len(out)} installed ports for triplet {triplet}")
    return out


# --------------------------------------------------------------------------------------------
# per-port vcpkg.spdx.json  ->  license / homepage / download / supplier
# --------------------------------------------------------------------------------------------
def read_spdx(share_dir: Path) -> Dict[str, Dict[str, Any]]:
    out: Dict[str, Dict[str, Any]] = {}
    if not share_dir.is_dir():
        _log(f"spdx share dir not found: {share_dir} (licenses fall back to the built-in map)")
        return out
    for spdx in share_dir.glob("*/vcpkg.spdx.json"):
        try:
            doc = load_json(spdx)
        except (OSError, json.JSONDecodeError) as exc:
            _log(f"skip {spdx}: {exc}")
            continue
        pkgs = doc.get("packages", []) or []
        port_pkg = next((p for p in pkgs if p.get("SPDXID") == "SPDXRef-port"), None)
        if port_pkg is None:
            port_pkg = pkgs[0] if pkgs else {}
        name = port_pkg.get("name") or spdx.parent.name
        lic = port_pkg.get("licenseConcluded") or port_pkg.get("licenseDeclared") or ""
        out[name] = {
            "license": lic,
            "homepage": port_pkg.get("homepage", "") or "",
            "download": port_pkg.get("downloadLocation", "") or "",
            "supplier": port_pkg.get("supplier", "") or "",
            "description": (port_pkg.get("description", "") or "").strip()[:240],
        }
    _log(f"spdx: enriched {len(out)} ports from {share_dir}")
    return out


# --------------------------------------------------------------------------------------------
# vcpkg depend-info --x-json  ->  {port: [dep, dep, ...]}   (the real edges)
# --------------------------------------------------------------------------------------------
def parse_depend_info(path: Optional[Path]) -> Dict[str, List[str]]:
    if not path:
        return {}
    try:
        data = load_json(path)
    except (OSError, json.JSONDecodeError) as exc:
        _log(f"depend-info unreadable ({exc}); graph will be flat")
        return {}
    edges: Dict[str, List[str]] = {}
    # Tolerant of the two shapes vcpkg has shipped: {port: {"dependencies": [...]}} and
    # {port: [...]}. Feature-suffixed names ("opencv[dnn]") are folded to the base port.
    def base(n: str) -> str:
        return n.split("[", 1)[0].split(":", 1)[0]
    if isinstance(data, dict):
        for port, val in data.items():
            deps = val.get("dependencies", []) if isinstance(val, dict) else (val or [])
            edges.setdefault(base(port), [])
            for d in deps:
                dn = base(d if isinstance(d, str) else d.get("name", ""))
                if dn and dn != base(port):
                    edges[base(port)].append(dn)
    for k in edges:
        edges[k] = sorted(set(edges[k]))
    _log(f"depend-info: edges for {len(edges)} ports")
    return edges


# --------------------------------------------------------------------------------------------
# CMakeCache.txt  ->  external Qt / VTK components (not vcpkg ports)
# --------------------------------------------------------------------------------------------
def parse_cmake_cache(path: Optional[Path]) -> List[Dict[str, Any]]:
    if not path or not path.is_file():
        return []
    text = path.read_text(encoding="utf-8", errors="replace")
    cache: Dict[str, str] = {}
    for line in text.splitlines():
        m = re.match(r"^([A-Za-z0-9_]+):[A-Z]+=(.*)$", line)
        if m:
            cache[m.group(1)] = m.group(2).strip()

    def first(*keys: str) -> str:
        for k in keys:
            if cache.get(k):
                return cache[k]
        return ""

    comps: List[Dict[str, Any]] = []

    # Qt: prefer a resolved *_VERSION, else read it out of the Qt6_DIR path (.../Qt/6.10.2/...)
    qt_ver = first("Qt6_VERSION", "Qt6Core_VERSION", "QT_VERSION")
    if not qt_ver:
        m = re.search(r"[/\\]Qt[/\\](\d+\.\d+\.\d+)", first("Qt6_DIR", "QTDIR", "Qt6Core_DIR"))
        qt_ver = m.group(1) if m else ""
    if qt_ver:
        comps.append({
            "bom-ref": f"ext:qt@{qt_ver}", "type": "framework", "name": "Qt", "version": qt_ver,
            "supplier": {"name": "The Qt Company", "url": ["https://www.qt.io"]},
            "scope": "required",
            "licenses": [{"license": {"id": "LGPL-3.0-only", "acknowledgement": "declared"}}],
            "purl": f"pkg:generic/qt@{qt_ver}",
            "cpe": f"cpe:2.3:a:qt:qt:{qt_ver}:*:*:*:*:*:*:*",
            "externalReferences": [{"type": "website", "url": "https://www.qt.io"}],
            "properties": [
                {"name": "cads:source", "value": "external-toolchain (CMakeCache)"},
                {"name": "cads:note",
                 "value": "Qt is dual-licensed (LGPL-3.0-only or commercial); confirm which the "
                          "deployed build uses."},
            ],
        })

    # VTK: resolved VTK_VERSION, else the vtk-9.5 suffix of VTK_DIR
    vtk_ver = first("VTK_VERSION")
    if not vtk_ver:
        m = re.search(r"vtk-(\d+\.\d+(?:\.\d+)?)", first("VTK_DIR"))
        vtk_ver = m.group(1) if m else ""
    if vtk_ver:
        comps.append({
            "bom-ref": f"ext:vtk@{vtk_ver}", "type": "library", "name": "VTK", "version": vtk_ver,
            "supplier": {"name": "Kitware", "url": ["https://vtk.org"]},
            "scope": "required",
            "licenses": [{"license": {"id": "BSD-3-Clause", "acknowledgement": "declared"}}],
            "purl": f"pkg:github/Kitware/VTK@v{vtk_ver}",
            "externalReferences": [{"type": "website", "url": "https://vtk.org"}],
            "properties": [
                {"name": "cads:source", "value": "external-toolchain (CMakeCache)"},
                {"name": "cads:note",
                 "value": "Prebuilt external install; its vendored ThirdParty set is not visible "
                          "to vcpkg or Syft - supply it via --overlay."},
            ],
        })
    _log(f"cmake cache: {len(comps)} external components (Qt/VTK)")
    return comps


# --------------------------------------------------------------------------------------------
# git submodules  ->  components (first-party om_* as applications, OpenXLSX as a library)
# --------------------------------------------------------------------------------------------
def _git(root: Path, *args: str) -> str:
    try:
        return subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True,
                              check=False, timeout=60).stdout.strip()
    except (OSError, subprocess.SubprocessError) as exc:
        _log(f"git {' '.join(args)} failed: {exc}")
        return ""


def parse_submodules(root: Optional[Path]) -> Tuple[List[Dict[str, Any]], List[str]]:
    """Returns (components, bom-refs-to-attach-to-app)."""
    if not root:
        return [], []
    gm = root / ".gitmodules"
    if not gm.is_file():
        _log(f"no .gitmodules at {root}")
        return [], []
    text = gm.read_text(encoding="utf-8", errors="replace")
    # Block parse: path and url appear in the same [submodule] block, order not guaranteed.
    sub_url: Dict[str, str] = {}
    cur_path = None
    for line in text.splitlines():
        p = re.match(r'^\s*path\s*=\s*(.+?)\s*$', line)
        u = re.match(r'^\s*url\s*=\s*(.+?)\s*$', line)
        if re.match(r'^\s*\[submodule', line):
            cur_path = None
        elif p:
            cur_path = p.group(1)
            sub_url.setdefault(cur_path, "")
        elif u and cur_path is not None:
            sub_url[cur_path] = u.group(1)

    # path -> commit sha, from `git submodule status --recursive`
    sha_by_path: Dict[str, str] = {}
    for line in _git(root, "submodule", "status", "--recursive").splitlines():
        m = re.match(r'^[\s+\-U]?([0-9a-f]{40})\s+(\S+)', line)
        if m:
            sha_by_path[m.group(2)] = m.group(1)

    comps: List[Dict[str, Any]] = []
    app_refs: List[str] = []
    for path, url in sorted(sub_url.items()):
        sha = sha_by_path.get(path) or _git(root / path, "rev-parse", "HEAD")
        name = Path(path).name
        third_party = "openxlsx" in (url + path).lower()
        if third_party:
            ref = f"pkg:github/troldal/OpenXLSX@{sha}" if sha else "pkg:generic/openxlsx"
            comps.append({
                "bom-ref": ref, "type": "library", "name": "OpenXLSX",
                "version": sha[:12] if sha else "",
                "supplier": {"name": "troldal (upstream); CADS fork"},
                "scope": "required",
                "licenses": [{"license": {"id": "BSD-3-Clause", "acknowledgement": "declared"}}],
                "purl": f"pkg:github/troldal/OpenXLSX@{sha}" if sha else "pkg:generic/openxlsx",
                "externalReferences": [
                    {"type": "vcs", "url": "https://github.com/troldal/OpenXLSX"},
                    {"type": "distribution", "url": url},
                ],
                "properties": [
                    {"name": "cads:source", "value": "git-submodule (CADS fork)"},
                    {"name": "cads:submodulePath", "value": path},
                    {"name": "cads:commit", "value": sha},
                ],
            })
            app_refs.append(ref)
        else:
            ref = f"cads:{name}@{sha[:12]}" if sha else f"cads:{name}"
            comps.append({
                "bom-ref": ref, "type": "application", "name": name,
                "version": sha[:12] if sha else "",
                "supplier": {"name": "CADS GmbH", "url": ["https://www.cads.at"]},
                "group": "at.cads", "scope": "required",
                "externalReferences": [{"type": "vcs", "url": url}],
                "properties": [
                    {"name": "cads:source", "value": "git-submodule (first-party)"},
                    {"name": "cads:internal", "value": "true"},
                    {"name": "cads:submodulePath", "value": path},
                    {"name": "cads:commit", "value": sha},
                ],
            })
            app_refs.append(ref)
    _log(f"submodules: {len(comps)} components ({sum(1 for c in comps if c['name']=='OpenXLSX')} third-party)")
    return comps, app_refs


# --------------------------------------------------------------------------------------------
# overlay (manual CycloneDX fragment for what tooling cannot derive)
# --------------------------------------------------------------------------------------------
def load_overlay(path: Optional[Path]) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    if not path or not path.is_file():
        return [], []
    doc = load_json(path)
    comps = doc.get("components", []) or []
    deps = doc.get("dependencies", []) or []
    _log(f"overlay: {len(comps)} components, {len(deps)} dependency rows")
    return comps, deps


# --------------------------------------------------------------------------------------------
# assembly
# --------------------------------------------------------------------------------------------
def build_vcpkg_component(port: str, info: Dict[str, Any], spdx: Dict[str, Any],
                          triplet: str) -> Dict[str, Any]:
    version = info.get("version", "")
    pv = info.get("port_version", 0)
    port_version = f"{version}#{pv}" if pv else version
    sx = spdx.get(port, {})
    lic = sx.get("license") or KNOWN_LICENSE.get(port, "")
    ack = "concluded" if sx.get("license") else "declared"
    ref = f"pkg:vcpkg/{port}@{port_version}?triplet={triplet}"
    comp: Dict[str, Any] = {
        "bom-ref": ref,
        "type": "library",
        "name": port,
        "version": version,
        "scope": "required",
        "purl": purl_for(port, version),
        "properties": [
            {"name": "cads:source", "value": "vcpkg"},
            {"name": "vcpkg:port", "value": port},
            {"name": "vcpkg:triplet", "value": triplet},
        ],
    }
    if pv:
        comp["properties"].append({"name": "vcpkg:portVersion", "value": port_version})
    if info.get("features"):
        comp["properties"].append({"name": "vcpkg:features", "value": ",".join(info["features"])})
    lic_arr = make_license(lic, ack)
    if lic_arr:
        comp["licenses"] = lic_arr
    cpe = cpe_for(port, version)
    if cpe:
        comp["cpe"] = cpe
    sup = supplier_from(sx.get("homepage", ""), sx.get("download", ""))
    if sup:
        comp["supplier"] = sup
    if sx.get("description"):
        comp["description"] = sx["description"]
    refs = []
    if sx.get("homepage"):
        refs.append({"type": "website", "url": sx["homepage"]})
    if sx.get("download"):
        refs.append({"type": "vcs", "url": sx["download"]})
    if refs:
        comp["externalReferences"] = refs
    return comp


def assemble(args: argparse.Namespace) -> Dict[str, Any]:
    triplet = args.triplet
    installed = parse_vcpkg_list(Path(args.vcpkg_json), triplet)
    spdx = read_spdx(Path(args.vcpkg_share)) if args.vcpkg_share else {}
    edges = parse_depend_info(Path(args.depend_info_json) if args.depend_info_json else None)
    external = parse_cmake_cache(Path(args.cmake_cache) if args.cmake_cache else None)
    submods, submod_app_refs = parse_submodules(Path(args.submodules_root)
                                                 if args.submodules_root else None)
    overlay_comps, overlay_deps = load_overlay(Path(args.overlay) if args.overlay else None)

    # vcpkg components, and a port -> bom-ref index for wiring the graph
    vcpkg_comps: List[Dict[str, Any]] = []
    ref_by_port: Dict[str, str] = {}
    for port in sorted(installed):
        comp = build_vcpkg_component(port, installed[port], spdx, triplet)
        vcpkg_comps.append(comp)
        ref_by_port[port] = comp["bom-ref"]

    components = vcpkg_comps + external + submods + overlay_comps

    # ---- dependency graph -------------------------------------------------------------------
    app_ref = "app:kls-onemill"
    deps_index: Dict[str, List[str]] = {c["bom-ref"]: [] for c in components}
    deps_index[app_ref] = []

    if edges:
        # Real port-to-port edges from depend-info.
        for port, dep_ports in edges.items():
            src = ref_by_port.get(port)
            if not src:
                continue
            for dp in dep_ports:
                dst = ref_by_port.get(dp)
                if dst and dst not in deps_index[src]:
                    deps_index[src].append(dst)
        # App depends on the direct set (those present in the installed tree).
        for port in sorted(DIRECT_PORTS):
            r = ref_by_port.get(port)
            if r and r not in deps_index[app_ref]:
                deps_index[app_ref].append(r)
    else:
        # No edge source: attach every vcpkg component directly to the app (flat but valid).
        _log("no depend-info: emitting a flat graph (app -> every port)")
        for comp in vcpkg_comps:
            deps_index[app_ref].append(comp["bom-ref"])

    # External toolchain + submodules hang off the app.
    for comp in external:
        deps_index[app_ref].append(comp["bom-ref"])
    for r in submod_app_refs:
        if r not in deps_index[app_ref]:
            deps_index[app_ref].append(r)

    # Fold in overlay edges (e.g. moduleworks -> pypy), creating refs if the overlay introduced them.
    # A row whose parent ref matches no component is almost always a drifted reference - e.g. the
    # overlay parents the VTK third-party set under 'ext:vtk@9.5' but --cmake-cache derived
    # 'ext:vtk@9.5.1', or --cmake-cache was not passed at all. Left alone, those children become
    # orphans: present as components but reachable only through a phantom node, so Dependency-Track
    # silently drops them from the graph. We warn loudly AND re-home the children on the app so they
    # stay reachable and scannable.
    known_refs = {c["bom-ref"] for c in components} | {app_ref}
    orphaned_children: List[str] = []
    for row in overlay_deps:
        ref = row.get("ref")
        if ref is None:
            continue
        children = [d for d in (row.get("dependsOn", []) or [])]
        if ref not in known_refs:
            _log(f"WARNING: overlay parent '{ref}' matches no component - its {len(children)} "
                 f"child(ren) will be re-homed on the application. Keep the overlay ref in sync "
                 f"with what --cmake-cache derives (and pass --cmake-cache).")
            orphaned_children.extend(children)
            continue
        deps_index.setdefault(ref, [])
        for d in children:
            if d not in deps_index[ref]:
                deps_index[ref].append(d)

    # Attach overlay roots (and any re-homed orphans) to the app unless already parented elsewhere.
    parented = {d for row in overlay_deps
                if row.get("ref") in known_refs
                for d in (row.get("dependsOn", []) or [])}
    for r in [c["bom-ref"] for c in overlay_comps] + orphaned_children:
        if r not in parented and r not in deps_index[app_ref]:
            deps_index[app_ref].append(r)

    dependencies = [{"ref": app_ref, "dependsOn": sorted(set(deps_index.pop(app_ref)))}]
    for ref in sorted(deps_index):
        dependencies.append({"ref": ref, "dependsOn": sorted(set(deps_index[ref]))})

    bom = {
        "$schema": "http://cyclonedx.org/schema/bom-1.7.schema.json",
        "bomFormat": "CycloneDX",
        "specVersion": "1.7",
        "serialNumber": f"urn:uuid:{uuid.uuid4()}",
        "version": 1,
        "metadata": {
            "timestamp": _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "lifecycles": [{"phase": "build"}],
            "authors": [{"name": "CADS GmbH - Product Security"}],
            "manufacturer": {"name": "CADS GmbH", "url": ["https://www.cads.at"]},
            "tools": {"components": [
                {"type": "application", "name": "vcpkg_to_cyclonedx.py",
                 "description": "Authoritative OneMill SBOM from vcpkg list/spdx + depend-info + "
                                "CMakeCache + git submodules + overlay."}
            ]},
            "component": {
                "bom-ref": app_ref,
                "type": "application",
                "group": "at.cads",
                "name": "KLS OneMill",
                "version": args.app_version or "0.0.0-local",
                "supplier": {"name": "CADS GmbH", "url": ["https://www.cads.at"]},
                "properties": [
                    {"name": "cads:triplet", "value": triplet},
                    {"name": "cads:buildSystem", "value": "CMake + Ninja, MSVC 2022"},
                ],
            },
        },
        "components": components,
        "dependencies": dependencies,
    }
    _log(f"assembled: {len(components)} components, {len(dependencies)} dependency rows")
    return bom


def validate_with_cli(out: Path) -> int:
    exe = "cyclonedx.exe" if os.name == "nt" else "cyclonedx"
    try:
        proc = subprocess.run([exe, "validate", "--input-file", str(out)],
                              capture_output=True, text=True, check=False, timeout=120)
    except FileNotFoundError:
        _log("cyclonedx CLI not found on PATH; skipping validation "
             "(install from github.com/CycloneDX/cyclonedx-cli)")
        return 0
    sys.stderr.write(proc.stdout + proc.stderr)
    if proc.returncode == 0:
        _log("cyclonedx validate: OK")
    else:
        _log(f"cyclonedx validate FAILED (exit {proc.returncode})")
    return proc.returncode


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(description="Assemble the authoritative OneMill CycloneDX 1.7 SBOM.")
    ap.add_argument("--vcpkg-json", required=True, help="output of `vcpkg list --x-json`")
    ap.add_argument("--vcpkg-share", help="<VCPKG_ROOT>/installed/<triplet>/share (per-port spdx)")
    ap.add_argument("--depend-info-json", help="output of `vcpkg depend-info --x-json ...`")
    ap.add_argument("--cmake-cache", help="out/build/.../CMakeCache.txt (Qt/VTK versions)")
    ap.add_argument("--submodules-root", help="repo root, to enumerate git submodules")
    ap.add_argument("--overlay", help="CycloneDX fragment for commercial/VTK-thirdparty components")
    ap.add_argument("--app-version", default="", help="product version, e.g. 2.2.0.60-alpha")
    ap.add_argument("--triplet", default=TRIPLET_DEFAULT)
    ap.add_argument("--out", required=True, help="output CycloneDX 1.7 JSON path")
    ap.add_argument("--validate", action="store_true", help="run `cyclonedx validate` on the result")
    args = ap.parse_args(argv)

    bom = assemble(args)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(bom, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    _log(f"wrote {out}")

    if args.validate:
        return validate_with_cli(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
