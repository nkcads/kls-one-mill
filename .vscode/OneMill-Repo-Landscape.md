# KLS OneMill — Repo / Branch / Tag Landscape

**Original snapshot 2026-07-30**, pulled live from Azure DevOps (`cads-team` / `KLS OneMill`,
30 repos, all branches + tags) and cross-checked against the local clone.

**⚠ Read this first: §1–§10 below describe the state BEFORE the 2026-08 reorganisation.** They are
kept because the topology, the tag audit and the branch inventory are still the reference material
for how this product is put together — but the specific branch facts are a historical snapshot, not
current. In particular `main` is no longer the ADO default anywhere, `develop` now exists in all 27
code repos, and the tag inconsistency described in §4 has been addressed with the `release/*` set.

**For the current state and what was actually done, see
[`OneMill-Migration-2026-08.md`](OneMill-Migration-2026-08.md).**

What remains genuinely forward-looking here is **§12** — the deferred proposal to collapse the
26-submodule structure. It was never executed; §12.9 is a measured absorb/extract round trip
proving the change is reversible.

> Context, from when this was written: the dev lead's own summary was *"it's a bit of a mess at the
> moment"*. The history was in fact clean and linear. What was messy was that `main` was the ADO
> default on all 30 repos while being long dead, plus inconsistent tagging and two stray gitlinks —
> all three now resolved.

---

## 0. What changed since 2026-07-29

| | Then | Now |
|---|---|---|
| `version/Beta220` exists in | 12 repos; 14 were still on `version/20Beta` | **all 26 code repos** (only `om_OpenXLSX` lacks it — vendored). Robert pushed the rest on 2026-07-29. |
| Superproject `version/Beta220` | `141c8b7`, +32 vs `main` | `6c04455`, **+33** vs `main` |
| Gitlink → branch mapping | mixed Beta220 / 20Beta; nested ones *inferred* | **all 25 real gitlinks verified at their `version/Beta220` tip**, nested included |
| `SetupBuildEnvOnBeta220` | local only | **pushed in 13 repos** (superproject + 12 submodules) |
| `SetupBuildEnvOnMain` | not recorded | pushed in **7 repos**, on the dead `main` line |
| Tag counts | "16 / 1 / 13" | corrected: **17 / 1 / 12** (the old figures were off by one) |
| `om_MillingBackend` stale branches | "~19 fully merged" | corrected: **14 fully merged** (`+0/-N`) + 4 stale-with-commits |

Consequence for §11: the `version/20Beta` fallback in the `develop`-creation script is **no longer
needed** — one branch name now covers everything.

---

## 1. The answer: which branch is "real"

**`version/Beta220`**, in the superproject and in all 25 submodule repos that have code.
`main` is dead in the whole C++ tree: superproject `main` = `a5ca137` *"Merged PR 25596: Merge RC10"*,
**2025-12-10**, **33 commits behind** `version/Beta220`.

History is **strictly linear — nothing diverged, nothing is stranded** (re-verified 2026-07-30 with
`git merge-base --is-ancestor`):

```
main (a5ca137, RC10, 2025-12-10)
  └─→ version/20Beta  (43f8ced, "Version 2.1.0", 2026-07-21, +29)
        └─→ version/Beta220 (6c04455, "VHF HoleMilling Showcase / PP Bugfix", 2026-07-29, +33)
```

- `main` → `version/20Beta` → `version/Beta220`: each an ancestor of the next → YES
- commits on `main` not in `version/Beta220` → **0**

So `main` was simply never fast-forwarded after RC10. No merge work is pending.

### Getting the live, buildable tree

```bash
git checkout version/Beta220
git submodule update --init --recursive   # ignore the 2 stray-gitlink errors, see §5
```

Do **not** check out branch names inside each submodule by hand — the pinning is correct (§8), so
`--recursive` gives the right SHAs automatically. `.gitmodules` has **no `branch =` entries** — the
tree is SHA-pinned only, which matches the fleet convention (`ips-suite2` has none either) and is
deliberately kept that way (§11.3c). `git submodule update --remote` still works: it follows each
submodule remote's `HEAD`.

---

## 2. Repo topology — two-level submodule nesting

This is why many repos don't appear in the superproject's `.gitmodules`: the `*Backend` repos are
nested one level deeper, inside their `Module*` wrapper.

```
KLS OneMill  (superproject, 17 gitlinks + 2 strays)
├─ MainApp                    → om_MainApp
├─ ModuleInterface            → om_ModuleInterface
├─ ModuleUtils                → om_ModuleUtils
├─ BackendUtils               → om_BackendUtils
├─ Updater                    → om_Updater
├─ GeneralUtils/MeshUtils     → om_MeshUtils
├─ GeneralUtils/OpenXLSX      → om_OpenXLSX          (vendored 3rd party)
└─ Modules/
   ├─ ModuleView             → om_ModuleView
   ├─ ModuleOverlayCritter   → om_ModuleOverlayCritter
   ├─ ModuleMillingKalotte   → om_ModuleMillingKalotte   └─ MillingBackend        (nested)
   ├─ ModulePostProcessor    → om_ModulePostProcessor    └─ PostProcessorBackend  (nested)
   ├─ ModuleStatistics       → om_ModuleStatistics       └─ StatisticsBackend     (nested)
   ├─ ModuleReporter         → om_ModuleReporter         └─ ReporterBackend       (nested)
   ├─ ModuleFixture          → om_ModuleFixture          └─ FixtureBackend        (nested)
   ├─ ModuleFileTransfer     → om_ModuleFileTransfer     └─ FileTransfer{Backend,Client}
   ├─ ModuleFittingAnalysis  → om_ModuleFittingAnalysis  └─ FittingAnalysisBackend
   └─ ModuleUpdater          → om_ModuleUpdater          └─ UpdaterBackend        (nested)
```

All 9 nested placements **verified 2026-07-30** (previously partly inferred from naming symmetry).

**Standalone, not in the submodule tree at all:** `om_documentation`,
`om_integrationtest_highlevel`, `om_MillingBackendTest`.

All `.gitmodules` URLs are **SSH** (`git@ssh.dev.azure.com:v3/...`). This needs the SSH→HTTPS
`insteadOf` rewrite locally (see setup ledger) and **blocks CI checkout entirely** (§13.4).

---

## 3. Live branch per repo

| Live tip | Repos |
|---|---|
| **`version/Beta220`** | **all 26 code repos** — KLS OneMill + om_{MainApp, ModuleInterface, ModuleUtils, BackendUtils, MeshUtils, Updater, ModuleUpdater, UpdaterBackend, ModuleView, ModuleOverlayCritter, ModuleMillingKalotte, MillingBackend, ModulePostProcessor, PostProcessorBackend, ModuleStatistics, StatisticsBackend, ModuleReporter, ReporterBackend, ModuleFixture, FixtureBackend, ModuleFileTransfer, FileTransferBackend, FileTransferClient, ModuleFittingAnalysis, FittingAnalysisBackend} |
| `SelfcontainedSuperbuild` only | om_OpenXLSX (vendored; `main` otherwise) |
| **`develop`** | om_documentation — the *only* repo using `develop` today |
| **`main`** (genuinely current) | om_integrationtest_highlevel — 2026-06-26, Shpetim Malici, PR-based, `KOMDCRM-*` Jira keys |
| dead | om_MillingBackendTest (nothing since 2025-12) |

**All 30 repos have `defaultBranch = refs/heads/main` in ADO.** That default is misleading for 28 of
them — the single biggest source of the "mess" impression.

`version/20Beta` still exists in 24 repos but is now strictly behind `version/Beta220` everywhere.

---

## 4. Tags — genuinely inconsistent

Only **two tag names exist project-wide**, applied unevenly (counts corrected 2026-07-30):

| Tags present | Count | Repos |
|---|---|---|
| `Version_1.0.1` + `Version_2.1.0` | **17** | KLS OneMill, om_{BackendUtils, MainApp, MeshUtils, MillingBackend, ModuleFileTransfer, ModuleFittingAnalysis, ModuleFixture, ModuleInterface, ModuleMillingKalotte, ModuleOverlayCritter, ModulePostProcessor, ModuleReporter, ModuleStatistics, ModuleUtils, ModuleView, OpenXLSX} |
| `Version_2.1.0` only | 1 | om_PostProcessorBackend |
| **none** | **12** | om_{documentation, FileTransferBackend, FileTransferClient, FittingAnalysisBackend, FixtureBackend, integrationtest_highlevel, MillingBackendTest, ModuleUpdater, ReporterBackend, StatisticsBackend, Updater, UpdaterBackend} |

And the names don't line up with anything:

- `Version_1.0.1` sits on **RC10** (= superproject `main` tip) → "1.0.1" labels release candidate 10
- `Version_2.1.0` sits on the **`version/20Beta`** tip
- branch `20Beta` ↔ tag `2.1.0`; branch `Beta220` ↔ presumably 2.2.0, currently **untagged**

**Consequence: do not use tags to identify a release across the tree.** The superproject gitlink SHA
is the only reliable "what was in this build" record.

---

## 5. Two stray gitlinks on `version/Beta220`

Still present as of 2026-07-30. Committed as submodules but **absent from `.gitmodules`**, so no URL
resolves:

```
160000 ddfacea96763f55e51ee0c5227c6b9bdd26534fa  .claude/worktrees/upbeat-blackwell
160000 4625984b38843615b387be1693c286a75cd815b3  Modules/ModuleTemplate
```

- `.claude/worktrees/upbeat-blackwell` — a **Claude Code worktree committed by accident**. Points at
  the superproject's *own* commit `ddfacea` (= `feature/fixture` tip).
- `Modules/ModuleTemplate` — same SHA as `Modules/ModuleFixture`; **no `om_ModuleTemplate` repo
  exists**. Copy-paste leftover.

Effect: `git submodule update --init --recursive` complains (`No url found for submodule path …`) or
leaves empty directories. Harmless to the build but noisy. Both accidental — remove in §11.3(b).

---

## 6. Workflow reality

- **Zero active PRs** project-wide (re-checked 2026-07-30).
- Last PR into a **code** repo: **2026-01-30** (`bugfix/KOM-4` → `main`, om_MillingBackend and
  om_PostProcessorBackend).
- All `version/*` work since then is **direct-push**, almost entirely by Robert Haider
  (`robert.haider@cads.at`, author name shows as `Robert`).
- Only repos still using PRs: `om_documentation` (→ `develop`) and `om_integrationtest_highlevel`
  (→ `main`).
- **No CI on any code repo.** The whole ADO project has exactly **one** build definition —
  `om_documentation` (id 655), last run 2025-10-10 (§13).

**Don't plan on opening a PR into `main`.** §11.6 proposes what to do instead.

### Open questions for the dev lead
1. Is `main` meant to be revived (fast-forwarded) or formally retired?
2. Is `version/Beta220` the branch that becomes 2.2.0, or a throwaway integration branch?
3. Should the ADO default branch be switched off `main` on the active repos?

**§11 proposes one coherent answer to all three** (`develop` = integration, `main` = release,
ADO default → `develop`).

---

## 7. Branch inventory

Format `+ahead/-behind` is relative to each repo's own `main`. Regenerate with §9.

### Our branches

| Branch | Repos | Notable | Verdict |
|---|---|---|---|
| `SetupBuildEnvOnBeta220` | **13** (superproject + 12 submodules) | superproject +37, PostProcessorBackend +31, MainApp +23, ModulePostProcessor +18, ModuleUtils +17, ModuleFittingAnalysis +10, FittingAnalysisBackend +7, ModuleFixture +5, {FileTransferBackend, FixtureBackend, ModuleFileTransfer, ModuleStatistics, StatisticsBackend} +4 | **Land into `develop` at creation** (§11.3a) — this is what makes a clean checkout build |
| `SetupBuildEnvOnMain` | 7 | superproject +2; ModuleUtils +1/-5, PostProcessorBackend +1/-7, ModulePostProcessor +1/-3, ModuleMillingKalotte +1/-2, ModuleStatistics +1, StatisticsBackend +1 | On the dead `main` line — **delete** |
| `SelfcontainedSuperbuild` | 7 | superproject +17 (2026-05-13); om_OpenXLSX's only live branch | Land or tag+delete; should not survive as a third line |

### Still-open work by others

| Repo | Branch | Last commit | Ahead/behind | Who |
|---|---|---|---|---|
| om_MillingBackend | `strongUshapedContour` | 2026-06-25 | +59/-1 | Pia Weindlmayr |
| om_MillingBackend | `bugfixUShapeContourSpline` | 2026-05-07 | +34/-1 | Pia Weindlmayr |
| om_MillingBackend | `feature/innerHoles` | 2026-04-28 | +32/-1 | Pia Weindlmayr |
| om_MillingBackend | `feature/dynamicStrats` | 2026-04-21 | +24/-1 | Robert |
| om_MillingBackend | `feature/footprints` | 2026-04-10 | +10/-1 | Pia Weindlmayr |
| om_MillingBackend | `feature/manualStruts` | 2026-03-17 | +9/-1 | Pia Weindlmayr |
| om_MillingBackend | `feature/contourBuilderUV` | 2026-03-05 | +6/-1 | Pia Weindlmayr |
| om_MillingBackend | `feature/orientatedItems` | 2026-02-25 | +5/-1 | Pia Weindlmayr |
| om_MillingBackend | `undercutCheckerV2` | 2026-02-12 | +2/-2 | Pia Weindlmayr |
| om_MeshUtils | `refactorSpline` | 2026-04-13 | +1/-3 | Pia Weindlmayr |
| KLS OneMill | `feature/fixture` | 2026-03-06 | +3/-0 | Robert |
| om_MillingBackendTest | `feature/TestHandler` | 2025-12-04 | +17/-0 | Wladislaw Lysenko |

`feature/orientatedItems` also exists in om_ModuleMillingKalotte (+6), om_ModulePostProcessor (+2),
om_ModuleUtils (+2), om_ModuleReporter (+1), om_PostProcessorBackend (+3) — Robert's, 2026-02…04.
`feature/quickMenu` in om_MainApp (+1) and om_ModuleInterface (+1).

### Deletion candidates — fully merged (`+0/-N`)

- **`feature/usa`** — superproject, om_MainApp, om_ModuleInterface, om_ModuleMillingKalotte,
  om_ModulePostProcessor, om_MillingBackend. Merged everywhere.
- **`feature/ncSequence`** — superproject, om_ModuleMillingKalotte, om_ModuleUtils, om_ModuleView,
  om_MillingBackend. Merged everywhere.
- **om_MillingBackend, 14 fully-merged branches** back to 2025-07: `feature/CenterSpline` (-17),
  `feature/orientationfinder` (-20), `feature/variableLoft` (-38), `feature/ContourSimplifier` (-40),
  `feature/ShapeClassifier` (-41), `feature/newTools` (-48), `feature/initialOrientation` (-58),
  `feature/implantContour` (-94), `struts` (-95), `innerSurface` (-96), `feature/undercutChecker`
  (-97), `feature/contour` (-98), plus `feature/usa` and `feature/ncSequence` above.
  4 more are stale but not merged: `feature/result-comparison` (+2/-11),
  `feature/CenterSplineLogic` (+3/-13), `feature/tool-handling` (+1/-45),
  `feature/post-processor` (+11/-102).
- Others: `feature/toolsHandling` (om_ModuleMillingKalotte, -22), `feature/Chiron` (om_ModuleView, -3),
  `feature/ppUpdate` (om_PostProcessorBackend, -16), `feature/ToolXlsx` (superproject, +1/-21),
  `feature/MillingBackendTest` (superproject, +5/-8), `feature/rawpart-generation`
  (om_ModuleMillingKalotte, +3/-69), `feature/pprefactor` (om_ModulePostProcessor +15/-24,
  om_PostProcessorBackend +13/-31), `feature/updated-heidanhain-post` (om_PostProcessorBackend +1/-18).

om_MillingBackend carries 31 branches total — by far the bulk of the project's branch noise.

---

### 7.1 VERIFIED 2026-08-04 — the "still-open work" is already merged

Robert states he merged all outstanding work from others locally on his PC and pushed it. **Checked in
`om_MillingBackend`** (the repo carrying 31 of the project's branches, i.e. the bulk of §7's inventory),
against its `version/Beta220` tip `418dfc0a` — `git rev-list --count <tip>..<branch>`:

**Fully merged (0 commits outside `version/Beta220`)** — every branch §7 listed as live work:
`strongUshapedContour` (§7 said +59), `bugfixUShapeContourSpline` (+34), `feature/innerHoles` (+32),
`feature/dynamicStrats` (+24), `feature/footprints` (+10), `feature/manualStruts`,
`feature/contourBuilderUV`, `feature/orientatedItems`, `undercutCheckerV2`, plus all ~19 older ones.

**Genuinely still outside `Beta220`** — all stale, none of it recent work:

| Branch | Not in Beta220 | Owner / era |
|---|---|---|
| `feature/post-processor` | +11 | Wladislaw, 2025-07 |
| `feature/CenterSplineLogic` | +3 | Pia, 2025-11 |
| `feature/result-comparison` | +2 | Wladislaw, 2025-12 |
| `feature/tool-handling` | +1 | Wladislaw |
| `SelfcontainedSuperbuild` | +1 | ours |
| `SetupBuildEnvOnBeta220` | +1 | ours — expected, it *is* our work |

**Consequences:** §11.5's "decide per branch" collapses to "delete them", and §12.7 blocker #4 — the last
real cost of the monorepo option — **evaporates**. The four stale branches above are abandonment
candidates (8+ months old), not migration blockers.

Two incidental findings worth knowing:

- **`om_MillingBackend`'s `main` has 1 commit not reachable from `version/Beta220`.** §1's strict-linearity
  finding was verified for the *superproject*, not per submodule. Harmless — but it confirms §15.4's rule:
  fast-forward `main` in the **superproject only**, never in submodules.
- ~~There is a stray remote branch literally named **`origin`** in `om_MillingBackend`.~~
  **RETRACTED 2026-08-04 — this was my error, there is no such branch.** `git for-each-ref` renders
  `refs/remotes/origin/HEAD` with `%(refname:short)` = **`origin`** (git's shorthand for the remote's
  default branch), and my survey script mistook that for a branch name. Verified against both the
  mirror's `refs/heads` and the live production repo: **no `origin` branch exists in any repo.** The
  same bug briefly put 25 bogus `origin` entries in the rehearsal's delete list — the fix is to filter
  on the **full** refname, never the short form:
  `git for-each-ref --format='%(refname)' refs/remotes/origin | grep -v '^refs/remotes/origin/HEAD$'`.

**Scope of this check:** `om_MillingBackend` only, because it holds the overwhelming majority of
branches. Re-run across the tree before the migration:

```sh
git submodule foreach --recursive --quiet '
  base=$(git rev-parse --verify --quiet origin/version/Beta220 || git rev-parse origin/version/20Beta)
  git for-each-ref --format="%(refname:short)" refs/remotes/origin | grep -v "origin/HEAD" | while read b; do
    n=$(git rev-list --count "$base..$b" 2>/dev/null)
    [ "$n" != "0" ] && echo "$displaypath  $b  +$n"
  done' | sort
```

---

## 8. Gitlink resolution on `version/Beta220` (verified 2026-07-30)

Superproject `origin/version/Beta220` = `6c04455`. **All 25 real gitlinks resolve exactly to their
own repo's `version/Beta220` tip** — 16 top-level plus 9 nested, checked by comparing each pinned SHA
against `git ls-remote origin version/Beta220`:

```
top-level (16): BackendUtils, GeneralUtils/MeshUtils, MainApp, ModuleInterface, ModuleUtils,
                Updater, Modules/{ModuleView, ModuleOverlayCritter, ModuleMillingKalotte,
                ModulePostProcessor, ModuleStatistics, ModuleReporter, ModuleFixture,
                ModuleFileTransfer, ModuleFittingAnalysis, ModuleUpdater}
nested (9):     MillingBackend, PostProcessorBackend, StatisticsBackend, ReporterBackend,
                FixtureBackend, FittingAnalysisBackend, FileTransferBackend, FileTransferClient,
                UpdaterBackend
exceptions:     GeneralUtils/OpenXLSX  — vendored, not a branch tip (expected)
                + the 2 stray gitlinks from §5
```

The pinning is correct and uniform. Nothing to reconcile.

---

## 9. Regenerating this data

Requires a valid `az login` (this PC's ADO MCP server needs `-a azcli`; see memory note
`azure-devops-mcp-azcli-auth.md`). Project GUID `f9465962-c0f1-4dac-af66-6c5ebf45ab2b`, superproject
repo GUID `12de026b-1276-47fc-b489-fb54152a2f65`.

Use the ADO `stats/branches` REST endpoint, not the MCP `repo_list_branches_by_repo` tool — the
latter returns names without dates. One bearer token via `Invoke-RestMethod`, not 60× `az rest`
(which takes minutes).

```powershell
$tok  = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv
$h    = @{ Authorization = "Bearer $tok" }
$base = 'https://dev.azure.com/cads-team/f9465962-c0f1-4dac-af66-6c5ebf45ab2b/_apis/git/repositories'
# NOTE: use ${base} — bare "$base?..." makes PowerShell choke on the '?'
$repos = (Invoke-RestMethod -Uri "${base}?api-version=7.1" -Headers $h).value
foreach ($r in ($repos | Sort-Object name)) {
  $st   = (Invoke-RestMethod -Uri "${base}/$($r.id)/stats/branches?api-version=7.1" -Headers $h).value
  $tags = (Invoke-RestMethod -Uri "${base}/$($r.id)/refs?filter=tags&api-version=7.1" -Headers $h).value
  "== $($r.name)  [default: $($r.defaultBranch)]  tags=$(($tags.name -replace '^refs/tags/','') -join ',')"
  $st | Sort-Object {$_.commit.committer.date} -Descending | ForEach-Object {
    "   {0}  +{1}/-{2}  {3}  [{4}]" -f ([datetime]$_.commit.committer.date).ToString('yyyy-MM-dd'),
      $_.aheadCount, $_.behindCount, $_.name, $_.commit.committer.name
  }
}
```

To verify gitlinks → branch tips (this is what produced §8):

```bash
git ls-tree -r origin/version/Beta220 | awk '$2=="commit"{print $3, $4}' | while read sha path; do
  remote=$(git -C "$path" ls-remote origin version/Beta220 | cut -f1)
  [ "$sha" = "$remote" ] && echo "OK   $path" || echo "DIFF $path"
done
```

PowerShell 5.1 gotchas hit while producing this: no `&&`/`||`, no ternary, and
`git ... ; if($?){...}` inside a `+=` expression is a parse error — wrap it in a function.

---

## 10. State of the local clone (2026-07-30)

`c:\DATA\repos\intern\KLSOneMill4` — **the clone that matters.** On branch
`SetupBuildEnvOnBeta220`, HEAD `dc9fb50`, **4 ahead of / 0 behind `origin/version/Beta220`**.
Working tree **clean**, **no dirty submodules**. Builds, installs and runs;
`.vscode/OneMill-Setup-Ledger.md` is the authoritative record of the setup.

`c:\DATA\repos\intern\KLSOneMill3` — on dead `main`. Its build-env work is real and pushed
(`SetupBuildEnvOnMain`, 7 repos) but sits on a dead end. **Do not assume a fix that worked on `main`
still applies to Beta220** — one of the four source fixes from that attempt would have *deleted
working features* (`RevolveItem`/`LabelItem` exist and are used on Beta220).

---

## 11, 13, 14, 15 — moved: this work is done

Those four sections were proposals and rehearsal notes, and all four were **executed** between
2026-08-04 and 2026-08-13. They described the future in future tense; keeping them here made this
document read as though the work were still pending.

| Was | Now |
|---|---|
| §11 `develop` as the root development branch | done — `develop` live in 27 repos and the ADO default |
| §13 A pipeline for OneMill | done — pipelines 819 (guard) and 824 (Windows build), both green |
| §14 Rehearsing the reorg in a sandbox | done — the rehearsal ran and caught real defects |
| §15 Release tags and reactivating `main` | done — `main` = `43f8ced`, `release/*` tags reconstructed |

**The outcome, and the findings that cost time, are in
[`OneMill-Migration-2026-08.md`](OneMill-Migration-2026-08.md).** Read that instead. The original
planning text is in git history if it is ever wanted; it is not worth carrying forward.

What remains in *this* document is the part that is still reference material rather than history:
the topology and inventory above (§0–10), and the one proposal that was **not** executed (§12).

---

## 12. DRAFT — killing the submodule crux

**Status: thinking out loud. Nothing decided. Do §11 first, independently.**

### 12.1 The size argument

| Component group | Repos | Tracked files |
|---|---|---|
| Shared libs (MainApp, ModuleInterface, ModuleUtils, BackendUtils, MeshUtils, Updater) | 6 | 244 |
| Module frontends (10 × `Module*`) | 10 | 384 |
| Backends (8 × `*Backend` + FileTransferClient) | 9 | 846 |
| Vendored (OpenXLSX) | 1 | 207 |
| **Total** | **26** | **~1 680** |

Largest single repo is `om_MillingBackend` at 594 files. **The whole product is smaller than many
single-repo projects.** No scale here justifies 26 repositories — and 8 are nested a *second* level
deep, so a change in `MillingBackend` needs a three-step gitlink chain to become visible.

### 12.2 What the submodules cost

- **No atomic change.** Backend + widget + superproject = 3 commits, in order, 3 pushes. Wrong order
  publishes a gitlink nobody can resolve.
- **No cross-repo diff → no reviewable unit → no PRs.** Not a side effect; *the* reason review
  stopped (§6). §11.6 works around it; it does not fix it.
- **Bisect is effectively impossible** across a regression spanning repos.
- **26 branch namespaces to keep in sync.** All of §3 and all of §11.3 exist *only* because of this.
- **Failure modes that can't otherwise exist:** the two stray gitlinks (§5); an unpushed submodule
  commit pinned by a pushed superproject; forgetting `--init --recursive` and reporting "it doesn't
  build".
- Tag chaos (§4) is 26× harder to fix than in one repo.

### 12.3 What they buy — honestly

1. **Independent consumption by another product.** ✅ **Checked 2026-07-30 — nothing consumes them.**
   Neither `om_MillingBackendTest` nor `om_integrationtest_highlevel` has a `.gitmodules` at all.
   See §12.3.1 — the test repo's actual mechanism *argues for* consolidation.
2. **Per-repo access control.** Only if an external contractor must see one part. ❓ Ask Robert.
3. **Partial clone.** Pia only needs `MillingBackend` — but the full tree is 1 680 files. Non-issue.
4. **Clean per-component history.** A monorepo gives the same with
   `git log -- Modules/ModuleMillingKalotte/MillingBackend`.

Items 3 and 4 are illusory at this size. Item 2 doesn't apply today. Item 1 — the one argument that
could have blocked this — **is verified false.**

#### 12.3.1 How the test repo consumes the sources

`om_integrationtest_highlevel/tests/CMakeLists.txt` documents two modes:

- **(A) Integrated — "preferred"**: `add_subdirectory()` from the OneMill superproject, "reuses the
  real module targets & toolchain". Links `ModuleInterface`, `ModuleReporter`, `ReporterBackend`
  **by target name**.
- **(B) Standalone**: overridable `CACHE PATH` variables pointing into `<repo>/src/om_MainApp/src`,
  `<repo>/src/om_ModuleReporter/ModuleReporterFrontend/src`, `<repo>/src/om_ReporterBackend/src` —
  a **flat `src/om_*` layout of "extracted om_* sources"** that exists nowhere in the real tree.

Both survive consolidation untouched: (A) uses target names, which don't change; (B) uses cache paths
that already don't match the submodule layout and are overridable anyway. And (B) exists precisely
*because* there is no single tree to point a harness at — somebody hand-extracted 26 repos into a
flat folder. **A monorepo makes (A) trivially the only mode needed.**

This repo also already tests dispatcher routing and the `ModuleInterface` plugin contract
(`test_dispatcher_routing.cpp`, `test_module_contract.cpp`, and `deployment/test_deployment.py`
validating shipped plugin DLLs via PE exports + IID) — the natural home for the §12.5 boundary
checks, and the healthiest repo in the project (Shpetim's, on `main`, PR-based).

### 12.4 The two boundaries that *do* matter — and why repos are the wrong tool for both

#### Boundary A: backend ↔ frontend (GUI)

**Real and currently perfect.** Verified across all 8 `*Backend` repos plus `BackendUtils` and
`MeshUtils`: **zero files include any Qt header.** Backends are pure C++ + VTK/Clipper2/spdlog; Qt
lives only in `MainApp`, `ModuleUtils` and the `*Widget` frontends.

But what enforces it? **Nothing.** Not the build — backend targets are `add_subdirectory`'d from a
root `CMakeLists.txt` that already called `find_package(Qt6 ...)`, so Qt is on their path. Not the
repo split either: a repo boundary cannot stop an `#include`. It holds purely on Robert's discipline.

A build-level rule *would* enforce it, in ~10 lines:

```cmake
function(assert_qt_free)
  foreach(t IN LISTS ARGN)
    if(TARGET ${t})
      get_target_property(_libs ${t} LINK_LIBRARIES)
      if(_libs MATCHES "Qt6::")
        message(FATAL_ERROR "${t} is a backend target and must not link Qt: ${_libs}")
      endif()
    endif()
  endforeach()
endfunction()
assert_qt_free(MillingBackend PostProcessorBackend StatisticsBackend ReporterBackend
               FixtureBackend FittingAnalysisBackend FileTransferBackend UpdaterBackend
               BackendUtils MeshLogic)
```

**The repo split is the weakest possible enforcement of the boundary you care most about, and it costs
you atomicity. A 10-line CMake assert is strictly stronger and costs nothing.**

#### Boundary B: the plugin concept

The load order — MainApp links first, modules load after — is the thing people assume blocks
consolidation, so be precise:

```
ModuleInterface (header-only)  ─┐
BackendUtils, MeshLogic        ─┼─→  MainApp.exe        (built first)
ModuleUtils (Qt)               ─┘
                                └─→  Module*.dll  →  bin/$<CONFIG>/modulesBert/
                                     (QPluginLoader at runtime; FunctionDispatcher for
                                      cross-module calls; no module includes another)
```

Modules are **leaves** in the build graph. MainApp never links them; they link back to the shared libs
and get discovered at runtime from `modulesBert/`. Cross-module calls go through `FunctionDispatcher`
by name — zero compile-time coupling between modules.

**That entire structure lives in CMake targets and output directories, not in repositories.** A
monorepo keeps every bit of it: same targets, same link order, same DLLs in the same folder, same
discovery. And the mechanical key:

> **The submodule paths *are* the source paths.** `Modules/ModuleMillingKalotte/MillingBackend` is
> both a gitlink and an `add_subdirectory` argument. Absorbing a submodule in place leaves the
> directory layout byte-identical, so **the build system needs no changes whatsoever.**

This is a git operation, not a build refactor.

### 12.5 Options

**A — full monorepo, path-preserving.** All 26 absorbed in place; keep `OpenXLSX` as the one
legitimate submodule. Per repo:
`git subtree add --prefix=Modules/ModuleMillingKalotte/MillingBackend <url> develop`.
History preserved, build untouched. Archive the old repos read-only; tag the last superproject commit
first so deployed-build traceability (§4) survives. **§12.9 tests this on real OneMill history** —
read it before quoting this option, because "history preserved" means something more specific than it
sounds, and there are two variants with a real trade-off.

**B — three repos along the backend/frontend seam.** `onemill-backend` + `onemill-app` +
2-submodule superproject. Buys a fast Qt-free backend CI. But *"add a backend API and call it from the
widget"* — the most common change shape here — still spans two repos plus a gitlink bump. **Trades 26
pains for 2 while keeping the worst one.** Not recommended.

**C — monorepo + build-enforced boundaries.** ⭐ Recommended. A, plus:
- `assert_qt_free(...)` from §12.4 → the backend/GUI cut becomes *stronger* than today.
- A check that no `Modules/X` source includes a header from `Modules/Y` (a grep test suffices) → the
  plugin decoupling becomes enforced rather than conventional.
- Plugin boundary otherwise untouched: separate DLLs, `modulesBert/`, header-only `ModuleInterface`,
  `FunctionDispatcher` as the only cross-module channel.
- Later, optionally: a backend-only CMake entry point that never calls `find_package(Qt6)`, so
  "backend builds without Qt" is continuously proven rather than asserted.

### 12.6 Phasing

| Phase | Action | Repos | Biggest win |
|---|---|---|---|
| **1** | Absorb the 8 nested `*Backend` into their `Module*` wrapper | 26 → 18 | Kills **level-2 nesting** — the 3-step gitlink chain. Worst pain, smallest change. Also fixes the §13.3 guard's blind spot. |
| **2** | Absorb the 10 `Module*` into the superproject | 18 → 8 | A module change becomes one commit. |
| **3** | Absorb the 6 shared libs | 8 → 2 | Cross-cutting API changes become atomic. `OpenXLSX` stays a submodule. |

Phase 1 alone removes most daily friction. If it feels wrong afterwards, stop there.

### 12.7 Blockers — checked 2026-07-30

| # | Question | Answer |
|---|---|---|
| 1 | Anything outside the superproject consuming these repos? | ✅ **No.** Neither standalone test repo has a `.gitmodules` (§12.3.1). |
| 2 | Any ADO pipeline building a single submodule repo? | ✅ **No.** One build definition project-wide — `om_documentation` (id 655), last run 2025-10-10. **Zero CI on any code repo.** |
| 3 | Per-repo access control needed? | ❓ Ask Robert. Assumed no. |
| 4 | In-flight work | ✅ **Resolved 2026-08-04 (§7.1).** Robert merged all outstanding work locally and pushed it; verified — every one of Pia's branches is fully contained in `version/Beta220`. There is no in-flight work to carry. **This was the last real cost, and it is gone.** |

Technical blockers are gone. What remains is #4 (sequencing) and Robert's agreement.

Side effect of #2: with no CI, *"`develop` always builds"* rests entirely on the build-before-you-bump
rule (§11.6). If that keeps getting skipped, the answer is §13 — far easier to write against one repo
than 26.

### 12.8 The one-sentence version

*Repositories are the weakest way to enforce an architecture and the most expensive way to lose
atomicity; the backend/GUI cut and the plugin concept both live in CMake targets and output
directories, and both survive a path-preserving monorepo conversion completely intact — so the
boundaries can be kept, and enforced better, while the 26-repo overhead goes away.*

### 12.9 VERIFIED — the absorb/extract round trip, tested on real OneMill history

**Tested 2026-08-04.** Robert is not convinced by the monorepo, so the claim "you can absorb a
submodule into its parent, and it is reversible with history preserved" was **actually executed** on
real OneMill submodules rather than asserted. Lab: `scratchpad/subtree-lab`, bare clones of
`om_ModuleStatistics` (12 commits) and `om_StatisticsBackend` (9 commits) taken from the local working
tree to stand in for the ADO remotes. **No network, nothing pushed to Azure DevOps, nothing in the
real clone touched.**

`om_ModuleStatistics` was chosen because it is the *nested* case (wrapper + backend) in miniature —
i.e. OneMill's hard shape, not the easy one.

#### 12.9.1 Headline answer

**Yes, it is possible, and yes, it is genuinely reversible.** But "history preserved" splits into two
variants with a real trade-off, and only one of them gives you working `git log` on a file.

| | **Variant A** — `git subtree add` | **Variant B** — re-root, then merge |
|---|---|---|
| Original commit SHAs | ✅ **kept byte-identical** | ❌ rewritten |
| Original commits reachable from HEAD | ✅ yes | ✅ yes (as rewrites) |
| `git blame <file>` reaches original commits | ✅ **yes — all of them** | ✅ yes |
| `git log -- <file>` traverses pre-absorb history | ❌ **no — stops at the merge** | ✅ **yes** |
| `git log --follow -- <file>` | ❌ returns nothing | ✅ yes |
| `git log -- <dir>` | ✅ shows the gitlink-bump history | ✅ shows content history |
| Extra tooling needed | none (`git subtree` ships with git) | `git filter-repo` **or** `filter-branch` |
| Reversible via `git subtree split` | ✅ **yes, fast-forward** | ⚠️ split works, but SHAs already diverged |

Measured on `StatisticsBackend/src/StatisticsLogger.cpp` (4 commits in its original history):

- **Variant A**: `git log -- <file>` returned exactly **1** commit (the absorb merge).
  `git log --follow` returned **0**. But `git blame` correctly named **all four** original commits —
  `157bd71 RC10`, `5095db1 Statistics`, `535833f rc statistics`, `1781fa2 inital commit` — with the
  right author on every line. So **per-line archaeology survives; per-file `git log` does not.**
- **Variant B**: `git log`, `git log --follow` and `git blame` all returned all four commits.

That is the honest trade-off to put in front of Robert: **A keeps the SHAs (so every existing
reference, build record and gitlink still resolves), B keeps `git log <file>`.** Both keep `blame`,
which is what people actually reach for.

#### 12.9.2 Reversibility — proven, not argued

The round trip was executed end to end in variant A:

1. Absorbed `StatisticsBackend` into the wrapper (`subtree add`) → 23 commits, 14 files.
2. Made two commits in the absorbed layout, including **one atomic commit touching wrapper *and*
   backend at once** — the exact thing submodules make impossible.
3. `git subtree split --prefix=StatisticsBackend -b extracted` → an 11-commit branch.
4. Verified `git merge-base --is-ancestor 9ac7a4e extracted` → **YES**. The split branch sits directly
   on top of the *original* component tip, with the original 9 SHAs intact underneath.
5. `git push <component-repo> extracted:SetupBuildEnvOnBeta220` → `9ac7a4e..59fc425`,
   **a plain fast-forward. No force push.**
6. Tree comparison: monorepo `HEAD:StatisticsBackend` and `extracted^{tree}` were the **same tree SHA**
   (`4dd55d4c…`) — content round-trips byte-identically.

So the un-do is not "restore from backup". It is a normal fast-forward push that leaves the component
repo a strict superset of what it was. Note step 2's atomic commit came back out as a backend-only
commit, with its wrapper half left behind in the monorepo — the split is lossless *per component*.

#### 12.9.3 The argument that should actually persuade Robert: they can coexist

The migration does **not** have to be a big bang, and does not require everyone to agree at once.
`git subtree pull` / `git subtree push` sync a prefix against the still-live component repo in both
directions. Tested: a commit pushed straight to `om_StatisticsBackend` (simulating Pia working the old
way) was pulled into the absorbed layout with `subtree pull`, and her **original commit SHA `c374e3b`
is reachable in the monorepo history**.

Meaning: you could absorb `MillingBackend` into the monorepo *while Pia keeps working in
`om_MillingBackend` exactly as she does today*, and neither of you is blocked. That turns the decision
from "bet the repo" into "try it on one component for two weeks".

**The honest caveat — and it is a real one.** `subtree pull` is an ordinary merge and conflicts like
one: the test hit a genuine content conflict when both sides edited the same line, resolved with
ordinary conflict resolution. More importantly, coexistence means **dual maintenance** — two places a
change can land, and someone has to remember to sync. That is a transitional state to spend weeks in,
not months. Do not sell it as free.

#### 12.9.4 Nested ordering — the requirement is real, and now demonstrated

Absorbing a wrapper **top-down while it still contains its own submodule** was tested directly. The
result at the absorbed path:

```
100644 blob …  Modules/ModuleStatistics/.gitmodules        <-- orphaned, path= now wrong
100644 blob …  Modules/ModuleStatistics/CMakeLists.txt
040000 tree …  Modules/ModuleStatistics/ModuleStatisticsFrontend
100644 blob …  Modules/ModuleStatistics/README.md
160000 commit 9ac7a4e…  Modules/ModuleStatistics/StatisticsBackend   <-- GITLINK, unresolvable
```

The superproject `.gitmodules` correctly loses its own entry, but you inherit a `160000` gitlink that
**nothing references** — precisely the §5 stray-gitlink failure class, manufactured on purpose. So:

> **Absorb bottom-up.** Backend into wrapper first (push that), then wrapper into superproject.
> Or absorb top-down and remove the inner gitlink + orphaned nested `.gitmodules` in a follow-up
> commit. This is exactly why §12.6 phase 1 is phase 1.

#### 12.9.5 Scale — this is a seconds-long operation, not a weekend

Commit counts, measured:

| | Commits |
|---|---|
| Superproject | 83 |
| Largest first-party submodule (`om_MillingBackend`) | 192 |
| All 25 first-party submodules combined | **737** |
| `om_OpenXLSX` (vendored 3rd party) | 881 |

The entire lab — two absorbs, a history rewrite, a split, and a round-trip push — ran in **seconds**.
"Rewriting history is risky and slow" is a legitimate concern at 500 000 commits. At 737 it is not a
factor. The whole 26-repo conversion is minutes of machine time; the cost is entirely in coordination
(§12.7 #4), not compute.

#### 12.9.6 Gotchas found by actually running it

These cost time if you hit them cold:

1. **`git subtree add` fails with `prefix '<path>' already exists`** if the directory is still on disk
   — and an uninitialised submodule leaves an **empty directory** behind. `git rm --cached` is not
   enough; `rm -rf <path>` as well. The check is filesystem-based, not index-based.
2. **`git subtree add <repo> <ref>` needs a fetchable ref name, not a SHA.** Passing a commit SHA
   fails with `couldn't find remote ref <sha>`. Pass the branch name.
3. **`git filter-repo` is not installed on this PC, and neither is Python** (`python --version` →
   the Microsoft Store stub). Variant B therefore currently needs the deprecated
   `git filter-branch --index-filter` recipe — which worked fine here, but installing `filter-repo`
   is the better answer if variant B is chosen.
4. Git in use is **2.53.0.windows.2**; `git subtree` ships with it at
   `/mingw64/libexec/git-core/git-subtree`. No install needed for variant A.
5. Line endings: every commit in the lab produced `LF will be replaced by CRLF` warnings.
   **Correction (2026-08-04): the claim "OneMill has none" was wrong** — `SetupBuildEnvOnBeta220`
   already tracks a `.gitattributes` (`* text=auto eol=lf`, `*.bat`/`*.cmd` → CRLF, binaries marked)
   plus an `.editorconfig`. The real gap is narrower and worth knowing: **a superproject
   `.gitattributes` does not apply inside submodules** — each submodule needs its own, and none of the
   26 has one. That is exactly why the lab's submodule clones still warned. Adding it per submodule is
   a 26-repo change and therefore its own decision, not a side effect of any plan here.

#### 12.9.7 What to propose to Robert

Given all of the above, the pitch is **not** "let's do a monorepo". It is:

> Take the smallest nested pair — `ModuleUpdater` + `UpdaterBackend` (3 + 3 commits) or
> `ModuleReporter` + `ReporterBackend` (8 + 7) — absorb it bottom-up on a branch, and look at the
> result. If it's worse, `subtree split` it back out with a fast-forward push and delete the branch.
> Total exposure: one afternoon, one branch, zero irreversible steps.

That reframes the disagreement from a philosophical one into an experiment with a bounded cost — and
§12.9.2 means the "what if we hate it" answer is a demonstrated command, not a promise.

Two things worth conceding to him up front, because they are true: `git log -- <file>` really does
break under variant A (§12.9.1), and coexistence really does mean dual maintenance (§12.9.3). Leading
with those is more persuasive than being talked into them later.

### 12.10 Sequencing — absorb *before* the `develop`/`main` reorg?

Short answer: **no, and for a sharper reason than "§11 is the cheap half".** The absorb does not
really want to happen before or after the reorg — **it wants `develop` to already exist**, because
`develop` is the only branch you can safely absorb *into*.

#### 12.10.1 Why absorbing first actively hurts

`git subtree add` writes a merge commit onto whatever branch you are on. Today that branch would have
to be `version/Beta220` or `version/20Beta` (§3). But §11.2 keeps exactly those branches as **frozen
historical markers**, because per §4 the gitlink SHA on them is *the only reliable record of what went
into a deployed build*. Absorbing into them **moves the markers** and mixes a structural conversion
into the one traceability record you have.

Two further frictions, both of which are just §11's problems arriving early:

- **You'd have to pick the source ref per repo.** `git subtree add <url> <ref>` needs a real ref, and
  it's `version/Beta220` in some repos, `version/20Beta` in others. That per-repo probing is precisely
  what §11.3's script exists to eliminate. Absorb after, and every command is uniformly
  `git subtree add --prefix=<path> <url> develop`.
- **The superproject gitlink bump has nowhere clean to land.** Absorbing the 8 backends into their
  wrappers creates new wrapper commits, so the superproject must bump those gitlinks. Onto
  `version/Beta220`? Same pollution problem again.

The escape hatch collapses into the same answer: to absorb cleanly you'd create a fresh integration
branch first — and that branch **is** `develop`. So the two steps converge rather than compete.

#### 12.10.2 What absorbing first would actually save — and it's small

If phase 1 (8 nested backends) landed first, §11 would operate on 18 repos instead of 26. Saved work:

| §11 item on the 8 absorbed repos | Genuinely saved? |
|---|---|
| Create `develop` (§11.3) | **No** — one scripted pass either way, and you *want* `develop` in an archived component repo; it's better archival hygiene than leaving it on `version/20Beta`. |
| `branch = develop` in `.gitmodules` (§11.3) | **Partly** — the 8 wrapper `.gitmodules` files disappear entirely, so 9 files → 1. Nice, but it's 9 files. |
| ADO default-branch switch (§11.4) | **Yes** — 8 manual switches on repos about to become read-only archives. The one real duplication. |
| `frozen/*` tags + branch hygiene (§11.5, §11.7) | **No** — you want the archive tagged regardless. |

So the entire saving is *eight ADO default-branch switches*. Not a reason to reorder anything.

**Cheap optimization worth taking, though:** if Robert has already green-lit phase 1, simply **skip
step 5's ADO default switch for those 8 backend repos** in §11.7. Costs nothing to decide, saves the
only duplicated work.

#### 12.10.3 Where absorbing genuinely transforms the reorg — the release tags

This is the part of the question that has a real "yes" in it, and it's the half about `main` and
release tags. It is **not order-dependent** — you get it whenever you absorb — but it is the strongest
argument that absorbing should happen *soon after* the reorg rather than someday.

Today, cutting a release means: fast-forward `main` in 26 repos, then tag 26 repos, consistently.
**§4 is the evidence that this has never once worked** — 16 repos carry the two tags, 13 carry none,
one carries only the second, and the names don't correspond to anything (`Version_1.0.1` sits on RC10).
The doc's own conclusion is *"do not use tags to identify a release across the tree."*

That conclusion is a **consequence of the repo count, not of anything about tagging.** After phase 3:

- Fast-forward `main` in **1** repo. Tag **1** repo. **One tag = one release = the whole product.**
- `git describe` becomes meaningful. Today it is per-repo noise.
- **The decisive one:** today a superproject release tag captures only *gitlink SHAs*, so
  reconstructing a shipped release requires all 26 component repos to still exist and still contain
  those commits. After absorbing, the tag captures the **actual content**. A release becomes
  self-contained and reconstructible from one ref.

That last point is worth raising with Robert separately from any developer-convenience argument. It is
a traceability property, not an ergonomics one — for a dental-implant milling product, "one ref
reproduces exactly what we shipped" is a different category of argument, and it is the thing §11 alone
*cannot* deliver. §11 gives tags a home; only the absorb makes a tag mean the whole product.

#### 12.10.4 Recommended order

1. **§11 as written** — `develop` everywhere, `main` left at RC10, ADO defaults switched
   (skipping the 8 backend repos if phase 1 is already agreed, per §12.10.2).
2. **§11.7 step 4 first: land `SetupBuildEnvOnBeta220` into `develop` before absorbing anything.**
   That branch exists in 13 repos — including 5 of the nested backends (`StatisticsBackend`,
   `PostProcessorBackend`, `FixtureBackend`, `FittingAnalysisBackend`, `FileTransferBackend`). Absorb
   first and those build-env commits have to arrive through the absorbed path instead. Avoidable
   tangle; just do it in this order.
3. **Absorb phase 1 as the first real change on `develop`.** This is a genuinely nice alignment: it
   *is* the §12.9.7 pilot, and landing it through a `review/<topic>` branch simultaneously
   demonstrates the §11.6 workflow on a real change. One change, three purposes.
4. **Phases 2 and 3 before the first release off `main`** — so that the first time anyone tags a
   release under the new model, there are 2 repos to tag instead of 26, and §4 never repeats.

The one situation that would justify reordering is political, not technical: **if the absorb pilot is
what Robert will say yes to first, don't block it on the branch reorg.** Do it — but do it onto a new
branch named `develop` in those few repos, which is just §11 executed early for that subtree. Same
destination, no wasted motion.

---

---

*(§13–15 removed — see the pointer above. This document ends with the deferred §12 proposal.)*
