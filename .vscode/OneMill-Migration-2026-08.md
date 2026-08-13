# OneMill — the 2026-08 reorganisation, as executed

**Status: DONE. This is a record, not a plan. Nothing here needs maintaining.**

Covers the branch/tag reorganisation and the CI integration carried out 2026-08-04 → 2026-08-13
(KOM-12). It replaces the planning material that used to live in
[`OneMill-Repo-Landscape.md`](OneMill-Repo-Landscape.md) §11, §13, §14 and §15, plus the
working documents `OneMill-Migration-Plan.md` and `OneMill-Sandbox-Rehearsal.md`.

It deliberately records **outcomes and hard-won findings**, not the plans that produced them. The
plans were right often enough not to be interesting; the surprises are what cost time.

---

## 1. What the product looks like now

| | Before | After |
|---|---|---|
Integration branch | `version/Beta220`, with `main` 33 commits stale but still the ADO default on all 30 repos | **`develop`** in all 27 code repos, and the **ADO default** in all 27 |
Release branch | `main` = `a5ca137` (RC10, 2025-12) | **`main` = `43f8ced`** = *Version 2.1.0*, fast-forwarded 2026-08-04 |
`main` protection | 9 repos had a reviewer policy; no merge-strategy policy anywhere | superproject `main`: **1 reviewer** (self-approval off) **+ merge-commit only** |
Release tags | `Version_*` tags wrong in 9 of 11 submodules for 1.0.1 | **`release/1.0.1` and `release/2.1.0`** reconstructed and reachable from `main` |
Stale branches | 60 fully-merged branches across the fleet | deleted |
`.gitmodules` | SSH URLs, `branch =` entries | HTTPS fleet form, no `branch =` |
Automated verification | none | **guard + Windows build pipelines**, both green |

Frozen for reference, deletable once nobody misses them: `version/Beta220` and `version/20Beta`,
tagged `frozen/Beta220` and `frozen/20Beta` so deleting the branches loses nothing.

## 2. Findings that cost real time — read these before touching the same areas

### Azure DevOps mechanics

- **The branch-policy toggle in the ADO UI DELETES the configuration, it does not disable it.**
  After switching one off, the policy object is gone from `_apis/policy/configurations`. So
  *"toggle off, push, toggle on"* is not a usable recipe — there is nothing to toggle back on and
  the UI makes you re-enter every field. **Always capture the policy JSON first** and recreate via
  `POST _apis/policy/configurations`. Baseline for the superproject is
  `main-policy-before.json` in the 2026-08-04 backup.
- **A branch carrying policies cannot be deleted** (`Cannot delete a branch which has policies`).
  Relevant to any future `release/*` branch.
- **ANY enabled branch policy makes ADO refuse direct pushes** (`TF402455`) — not only reviewer
  policies. Proven with a merge-strategy-only policy on a throwaway branch. So squash-protection on
  `develop` cannot be separated from requiring PRs there; it is one decision.
- **`git push --dry-run` does NOT test policies.** No server-side evaluation happens, so it reports
  the ref update it *would* attempt regardless of whether the server would refuse. Only the policy
  API state tells you anything.
- **`enforceReferencedRepoScopedToken` blocks every route to a sibling repo.** With it on, ad-hoc
  `git clone`, `submodules: recursive`, *and* per-repo pipeline permissions were all refused with
  `TF401019`, even though the build identity holds `GenericRead` on all 26 repos. OneMill was one of
  only 2 of 10 CADS projects with it enabled; it is now **off**, matching the other 8.
  `enforceJobAuthScope` remains on.
- **The ADO Branches page defaults to a "Mine" filter** that hides branches you did not push. That
  made `om_documentation`'s `develop` look absent.
- **A queued run can hold a parallel-job slot without ever starting.** One sat in `notStarted` for
  21 minutes while 4 of 6 slots were free. Cancel and requeue; it is not a capacity problem.

### Merge strategy — a deliberate fleet divergence

Every other CADS project sets `allowSquash=True` on `develop` (verified across 8 projects).
**OneMill must not**: a squash on the superproject collapses the merge, so the submodule commits its
gitlinks reference become unreachable from any branch — the unresolvable-gitlink failure,
self-inflicted. OneMill uses **merge-commit on both `main` and `develop`**. Recorded in
[`OneMill-Fleet-Conformance.md`](OneMill-Fleet-Conformance.md) under *Deliberately not adopted*.

### Gitlink ordering — the rule that matters

**Always push the deepest submodule first, then work outward.** A superproject commit whose gitlink
points at a commit reachable only from an unpushed submodule branch is precisely the dangling
gitlink the guard exists to catch. This bit twice:

- KOM-12: `om_MainApp`'s `develop` had to be fast-forwarded before the superproject merge
- the POLYGONICA_DIR warning needed **three** commits deepest-first, because `MillingBackend` is
  nested inside `Modules/ModuleMillingKalotte` — `om_MillingBackend` → `om_ModuleMillingKalotte`'s
  gitlink → superproject

Two intermediate repos also carried a stale upstream of `origin/version/Beta220`, so a bare
`git push` there would have gone to the wrong branch. Corrected to `origin/develop`.

### The tag reconstruction

The existing `Version_*` tags in the submodules were **wrong, not merely inconsistent**: for 1.0.1,
9 of 11 repos pointed at the wrong commit, because the tags were applied in a later sweep at
then-current tips. `BackendUtils`' `Version_1.0.1` actually marks 2.1.0 content. The new
`release/*` tags are derived from the superproject tag tree and agree everywhere; the old tags were
left untouched rather than moved.

### Method note: `git cherry` is a shortlist, not a verdict

It compares patch-ids, so a reworded comment, a rebase, or a pure gitlink bump all report
"not upstream" with no missing work. All 8 commits on `SetupBuildEnvOnMain` reported as unmerged;
every one was checked individually and **none** was work `develop` lacked. Conversely a `-` is
trustworthy. See [`OneMill-Unmerged-Work.md`](OneMill-Unmerged-Work.md) for the full audit.

## 3. The sandbox rehearsal — what it was worth

The whole reorganisation was rehearsed against a local mirror farm before touching production, with
URL rewriting so no operation could reach the network. It caught real defects, including a guard
that truncated its own host repository, and the safety trap was the important part:

> A catch-all `insteadOf` rule must come **first** so anything not explicitly mapped resolves to a
> path that does not exist and fails hard, rather than silently reaching the real remote.

The rehearsal clone `KLSOneMillRepoCleanup` and `C:/DATA/sandbox/onemill/` are leftovers and can be
retired.

## 4. CI, as built (KOM-12)

Two pipelines, both on `develop`:

**819 `onemill-guard`** — Microsoft-hosted Linux, no toolchain, ~50 s. Fails the build if any
submodule gitlink moves backwards. Verified in **both** directions: green on a clean branch, and
correctly rejecting a deliberately constructed *nested* downgrade where the parent moved forward —
the case a root-only guard passes. Adapted from ips-suite2 with two substantive fixes, both fed back
to `ips-suite2/TODO.md`.

**824 `onemill-build-windows`** — self-hosted EC2 (`onemill-aws-windows-pool`), stopped until
needed. Warmup → 26-submodule checkout → configure → 564 targets → `install_full` → verify → zip →
publish. **~14 minutes**, instance auto-released by a `condition: always()` Shutdown stage.
`trigger: none` deliberately, because it starts a billable instance.

Output: a **627.6 MB** artifact, `KLSOneMill-<version>-<buildnumber>-relwithdebinfo.zip`, against
Robert's hand-built `KLSOneMillFullVersion_210_Beta4.zip` at 630.4 MB. **Launched and run
successfully on 2026-08-13.** It carries 10 modules where the shipped Beta4 has 5, plus
`Updater.exe`, plus the current licence.

### The five external dependencies — two of them were undocumented

Configure resolving is the honest test of provisioning; a filesystem inventory is not. An earlier
inventory stage produced two false negatives from its own arbitrary limits (`-Depth 5`, then
`-First 6`) and was replaced.

| | Where | Note |
|---|---|---|
Qt 6.10.2 `msvc2022_64` | `ONEMILL_QTDIR` | was already on the forked AMI |
VTK 9.5, Qt-enabled | `ONEMILL_VTK_DIR` | shipped OneMill's own install tree, not the agent's MIRAGE build tree |
ModuleWorks SDK + `mwSupport.lic` | `ONEMILL_MODULEWORKS_DIR` | licence in `quickstart/`; a configure-time `FATAL_ERROR` if absent |
vcpkg @ `b81cab76…`, 146 static packages | `ONEMILL_VCPKG_ROOT` | **plus a manual `raytri.c` fix — see below** |
**Polygonica** | `ONEMILL_POLYGONICA_DIR` | **the one that was missing from every list** |

**Polygonica** hid because `MillingBackend/CMakeLists.txt` reads `$ENV{POLYGONICA_DIR}` as a
fallback and the reference dev box has it set at USER scope — so it never appeared in
`CMakeUserPresets.json.example` and no developer had to think about it. A clean CI agent found it in
seconds. All three environment fallbacks (`VTK_DIR`, `VCPKG_ROOT`, `POLYGONICA_DIR`) now **warn**
when used instead of a preset; the silence was the defect, not the fallback.

**libigl's `raytri.c`** — a *successful* `vcpkg install libigl` still yields a tree OneMill cannot
compile, because the port installs `*.h`/`*.cpp` and not the one `.c` file its own
`ray_mesh_intersect.cpp` includes. Reinstalling does not help. Third-party packaging bug, recorded
as a post-install step in `vcpkgPackages.txt` and asserted in the pipeline pre-flight.

**The PyPy interpreter** needs `deploy_ppf.exe` run once per machine. `install_full` hard-fails with
the remediation if it is missing — the fail-fast rework from fix 8 of the setup ledger, which is
what stopped a broken artifact from being published.

### Agent facts worth knowing

`EC2AMAZ-MBFQCNU`, Windows Server 2025, 8 cores, 15.6 GB RAM, **C: only**. The agent runs as a
machine account in **session 0** with a **bare PATH** — `cmake`, `ninja` and `cl` exist only under
VS's `Common7\IDE\CommonExtensions`, so **`VsDevCmd.bat` is required**, not decorative. VS is
`18.3.11520.95` / MSVC `14.50.35717`, slightly older than the dev box's `18.6` / `14.51`; builds
fine, not worth pinning until it bites.

**ADO wraps a PipelineArtifact in a second zip**, so a browser download of a 627 MB artifact streams
657 MB with no resume — which is why it kept failing partway. Use `curl -C -` with a bearer token.

---

## 5. Where the detail lives

| | |
|---|---|
Topology, tag inventory, branch audit, gitlink resolution | [`OneMill-Repo-Landscape.md`](OneMill-Repo-Landscape.md) §0–10 |
The deferred submodule-absorb proposal | [`OneMill-Repo-Landscape.md`](OneMill-Repo-Landscape.md) §12 |
Toolchain, the eight build fixes, gotchas, change log | [`OneMill-Setup-Ledger.md`](OneMill-Setup-Ledger.md) |
Fleet rule verdicts and deliberate divergences | [`OneMill-Fleet-Conformance.md`](OneMill-Fleet-Conformance.md) |
Branches with unmerged work, and who owns each decision | [`OneMill-Unmerged-Work.md`](OneMill-Unmerged-Work.md) |
What is still outstanding | [`OneMill-Remaining-Tasks.md`](OneMill-Remaining-Tasks.md) |
Backup of the pre-migration state | `C:\DATA\backup\onemill-20260804-1351` |
