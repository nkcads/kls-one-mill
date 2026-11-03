#!/usr/bin/env python3
"""Generate the complete KLS OneMill CycloneDX SBOM + analysis files from a vcpkg *plan*.

Inputs (produced with the vcpkg checkout pinned in vcpkgPackages.txt, no build needed):
  inputs/plan.txt    vcpkg install --dry-run --triplet x64-windows-static <14 ports>
  inputs/depend.dot  vcpkg depend-info --format=dot <every planned x64-windows-static port>
Port metadata (license/homepage/description) is read from <vcpkg>/ports/<name>/vcpkg.json.

Usage: gen_complete_sbom.py <repo_root> <vcpkg_root> <out_dir>
"""
import datetime, json, re, sys, uuid
from pathlib import Path

repo, vcpkg, out = (Path(a) for a in sys.argv[1:4])
inp = out / "inputs"
TRIPLET, HOST = "x64-windows-static", "x64-windows"
DIRECT = ["boost-asio", "boost-geometry", "boost-system", "clipper2", "cpr", "eigen3", "flann",
          "inja", "libigl", "libzippp", "nlohmann-json", "opencv", "pugixml", "spdlog"]

# ---- 1. plan -------------------------------------------------------------------------------
pkgs = {}  # ref -> dict
for line in (inp / "plan.txt").read_text(encoding="utf-8-sig").splitlines():
    m = re.match(r"^\s+(\*)?\s*([a-z0-9\-]+)(?:\[([^\]]*)\])?:([a-z0-9\-]+)@(\S+)$", line)
    if not m:
        continue
    _, name, feats, trip, ver = m.groups()
    ver, _, pv = ver.partition("#")
    ref = f"vcpkg:{name}" + (":host" if trip == HOST else "")
    pkgs[ref] = dict(name=name, version=ver, portVersion=pv or "0", triplet=trip,
                     features=feats.split(",") if feats else [], host=trip == HOST)

# ---- 2. edges ------------------------------------------------------------------------------
def node(s):
    n, _, h = s.partition(":")
    return f"vcpkg:{n}" + (":host" if h == "host" else "")
edges = {r: set() for r in pkgs}
for a, b in re.findall(r'^"([^"]+)" -> "([^"]+)"', (inp / "depend.dot").read_text(encoding="utf-8-sig"), re.M):
    a, b = node(a), node(b)
    if a in edges and b in pkgs:
        edges[a].add(b)

# ---- 3. port metadata ----------------------------------------------------------------------
def meta(name):
    p = vcpkg / "ports" / name / "vcpkg.json"
    try:
        j = json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return {}
    d = j.get("description", "")
    return dict(license=j.get("license"), homepage=j.get("homepage"),
                description=" ".join(d) if isinstance(d, list) else d)

# vcpkg manifests that declare "license": null; filled from the upstream projects' published licenses.
UPSTREAM_LICENSE = {"opencv": "Apache-2.0", "opencv4": "Apache-2.0", "quirc": "ISC", "liblzma": "0BSD"}

def lic(expr):
    if not expr:
        return None
    if re.fullmatch(r"[A-Za-z0-9.\-+]+", expr):
        return [{"license": {"id": expr}}]
    return [{"expression": expr}]

def component(ref, p):
    md = meta(p["name"])
    c = {"bom-ref": ref, "type": "library", "name": p["name"], "version": p["version"],
         "scope": "excluded" if p["host"] else "required",
         "purl": f"pkg:generic/{p['name']}@{p['version']}",
         "properties": [{"name": "cads:source", "value": "vcpkg"},
                        {"name": "vcpkg:triplet", "value": p["triplet"]},
                        {"name": "vcpkg:port-version", "value": p["portVersion"]},
                        {"name": "cads:role", "value": "direct" if p["name"] in DIRECT and not p["host"] else
                         ("build-tool (host)" if p["host"] else "transitive")}]}
    if p["features"]:
        c["properties"].append({"name": "vcpkg:features", "value": ",".join(p["features"])})
    if md.get("description"):
        c["description"] = md["description"]
    l = lic(md.get("license"))
    if not l and p["name"] in UPSTREAM_LICENSE:
        l = lic(UPSTREAM_LICENSE[p["name"]])
        c["properties"].append({"name": "cads:license-source", "value": "upstream project (vcpkg manifest declares null) - confirm"})
    if l:
        c["licenses"] = l
    else:
        c["properties"].append({"name": "cads:license", "value": "not declared in vcpkg port manifest"})
    if md.get("homepage"):
        c["externalReferences"] = [{"type": "website", "url": md["homepage"]}]
    return c

components = [component(r, p) for r, p in sorted(pkgs.items(), key=lambda kv: (kv[1]["host"], kv[0]))]

# ---- 4. non-vcpkg components ---------------------------------------------------------------
old = json.loads((repo / "one-mill-sbom-1.6.cdx.json").read_text(encoding="utf-8"))
overlay = json.loads((repo / "sbom/overlay.cdx.json").read_text(encoding="utf-8"))
ext_comps, ext_deps = [], {}
for c in old["components"]:
    if c["name"] in ("Qt", "VTK"):
        c = dict(c); c["bom-ref"] = f"ext:{c['name'].lower()}@{c['version']}"
        ext_comps.append(c)
ext_comps += [c for c in overlay["components"] if c["name"] != "OpenXLSX"]
for d in overlay.get("dependencies", []):
    ext_deps[d["ref"]] = list(d["dependsOn"])
ext_deps.setdefault("ext:vtk@9.5", [])

def vend(ref, name, ver, lic_id, url, note):
    return {"bom-ref": ref, "type": "library", "name": name, "version": ver, "scope": "required",
            "licenses": [{"license": {"id": lic_id}}] if lic_id else [],
            "purl": f"pkg:generic/{name}@{ver}" if ver else f"pkg:generic/{name}",
            "externalReferences": [{"type": "website", "url": url}],
            "properties": [{"name": "cads:source", "value": "vendored in GeneralUtils/OpenXLSX submodule"},
                           {"name": "cads:note", "value": note}]}
vendored = [
    {"bom-ref": "sub:openxlsx", "type": "library", "name": "OpenXLSX", "scope": "required",
     "purl": "pkg:github/troldal/OpenXLSX", "licenses": [{"license": {"id": "BSD-3-Clause"}}],
     "externalReferences": [{"type": "vcs", "url": "https://github.com/troldal/OpenXLSX"}],
     "properties": [{"name": "cads:source", "value": "git submodule GeneralUtils/OpenXLSX (om_OpenXLSX, commit 7d589ab)"}]},
    vend("vendored:pugixml-1.14", "pugixml (bundled in OpenXLSX)", "1.14", "MIT", "https://pugixml.org",
         "Separate copy from the vcpkg pugixml 1.16 port; version from PUGIXML_VERSION in the bundled header."),
    vend("vendored:zippy", "zippy", "", "MIT", "https://github.com/troldal/Zippy", "Header-only zip wrapper bundled in OpenXLSX."),
    vend("vendored:miniz-2.0.8", "miniz (embedded in zippy)", "2.0.8", "MIT", "https://github.com/richgel999/miniz",
         "ns_miniz inside zippy.hpp; version from the embedded header comment."),
    vend("vendored:nowide", "nowide (bundled in OpenXLSX)", "", "BSL-1.0", "https://github.com/boostorg/nowide",
         "Boost.Nowide derivative; version not recorded in the tree."),
]
ext_comps = vendored + ext_comps
ext_deps["sub:openxlsx"] = ["vendored:pugixml-1.14", "vendored:zippy", "vendored:nowide"]
ext_deps["vendored:zippy"] = ["vendored:miniz-2.0.8"]

# ---- 5. dependency graph -------------------------------------------------------------------
APP = "app:kls-onemill"
direct_refs = [f"vcpkg:{d}" for d in DIRECT]
missing = [r for r in direct_refs if r not in pkgs]
assert not missing, missing
ext_top = ["ext:qt@6.10.2", "ext:vtk@9.5", "ext:moduleworks-sdk", "ext:polygonica", "sub:openxlsx"]
deps = [{"ref": APP, "dependsOn": sorted(direct_refs + ext_top)}]
for r in pkgs:
    deps.append({"ref": r, "dependsOn": sorted(edges[r])})
all_ext = {c["bom-ref"] for c in ext_comps}
for r in sorted(all_ext):
    deps.append({"ref": r, "dependsOn": ext_deps.get(r, [])})
components += ext_comps

bom = {"bomFormat": "CycloneDX", "specVersion": "1.6", "serialNumber": f"urn:uuid:{uuid.uuid4()}", "version": 1,
       "metadata": {"timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
                    "tools": {"components": [{"type": "application", "name": "gen_complete_sbom.py"},
                                             {"type": "application", "name": "vcpkg", "version": "2026-07-13"}]},
                    "component": {"bom-ref": APP, "type": "application", "name": "KLS OneMill",
                                  "description": "Dependency graph resolved by vcpkg (classic mode) at commit "
                                                 "b81cab76a175645e047601da8f982ad86bff1cc3, triplet x64-windows-static."}},
       "components": components, "dependencies": deps}
(out / "kls-onemill-complete-sbom.cdx.json").write_text(json.dumps(bom, indent=2, ensure_ascii=False), encoding="utf-8")

# ---- 6. text deliverables ------------------------------------------------------------------
tgt = {r: p for r, p in pkgs.items() if not p["host"]}
host = {r: p for r, p in pkgs.items() if p["host"]}
direct_set = set(direct_refs)
trans = sorted(r for r in tgt if r not in direct_set)
fmt = lambda r: f"{pkgs[r]['name']} {pkgs[r]['version']}" + (f"#{pkgs[r]['portVersion']}" if pkgs[r]['portVersion'] != "0" else "")
(out / "direct-dependencies.txt").write_text(
    "# Direct vcpkg dependencies (vcpkgPackages.txt, verified against find_package()/#include)\n" +
    "\n".join(fmt(r) for r in direct_refs) +
    "\n\n# Direct non-vcpkg dependencies (external toolchain / submodule)\n" +
    "\n".join(f"{c['name']} {c.get('version','')}".strip() for c in ext_comps if c["bom-ref"] in ext_top) + "\n", encoding="utf-8")
(out / "transitive-dependencies.txt").write_text(
    f"# Transitive vcpkg packages, x64-windows-static ({len(trans)})\n" +
    "\n".join(fmt(r) for r in trans) +
    f"\n\n# Host-triplet (x64-windows) build tools - not linked into the product ({len(host)})\n" +
    "\n".join(fmt(r) for r in sorted(host)) + "\n", encoding="utf-8")

lines, seen = [], set()
def walk(r, prefix, last):
    lines.append(prefix + ("└── " if last else "├── ") + fmt(r) + (" (*)" if r in seen and edges[r] else ""))
    if r in seen:
        return
    seen.add(r)
    ch = sorted(c for c in edges[r] if c not in host)
    for i, c in enumerate(ch):
        walk(c, prefix + ("    " if last else "│   "), i == len(ch) - 1)
lines.append("KLS OneMill (target dependencies only; (*) = subtree shown earlier; host build tools omitted)")
for i, r in enumerate(direct_refs):
    walk(r, "", i == len(direct_refs) - 1)
(out / "dependency-tree.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")

old_names = {c["name"].lower() for c in old["components"]}
alias = {"opencv": "opencv4"}
missing_comps = [r for r in sorted(tgt) if pkgs[r]["name"] not in old_names and not (pkgs[r]["name"] == "opencv" and "opencv4" in old_names)]
host_missing = sorted(host)
(out / "missing-components.txt").write_text(
    f"# vcpkg packages (x64-windows-static) in the resolved graph but ABSENT from one-mill-sbom-1.6.cdx.json: {len(missing_comps)}\n" +
    "\n".join(fmt(r) for r in missing_comps) +
    f"\n\n# Host-triplet build tools absent from the 1.6 SBOM: {len(host_missing)}\n" +
    "\n".join(fmt(r) for r in host_missing) +
    f"\n\n# Non-vcpkg components absent from the 1.6 SBOM (vendored / installer / VTK-bundled / submodule): "
    f"{len([c for c in ext_comps if c['name'].lower() not in old_names])}\n" +
    "\n".join(f"{c['name']} {c.get('version','')}".strip() for c in ext_comps if c["name"].lower() not in old_names) + "\n",
    encoding="utf-8")

nolic = sorted(pkgs[r]["name"] for r in pkgs if "licenses" not in next(c for c in components if c["bom-ref"] == r))
stats = dict(direct=len(direct_refs), transitive=len(trans), host=len(host), ext=len(ext_comps),
             total=len(components), old=len(old["components"]), missing=len(missing_comps), nolic=nolic)
(out / "stats.json").write_text(json.dumps(stats, indent=1), encoding="utf-8")
print(json.dumps(stats, indent=1))
