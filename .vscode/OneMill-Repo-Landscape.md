# KLS OneMill — Repo / Branch / Tag Landscape

**Snapshot 2026-07-30**, re-pulled live from Azure DevOps (`cads-team` / `KLS OneMill`, 30 repos,
all branches + tags) and cross-checked against the local clone. Supersedes the 2026-07-29 snapshot;
what changed is listed in §0.

**§1–§10 are observed facts. §11–§14 are proposals, not agreed with anyone yet** — §11 a concrete
`develop`-branch plan meant to be executed, §12 a draft on removing the 26-submodule overhead,
§13 a minimal CI pipeline modelled on `ips-suite2`, §14 how to rehearse all of it in a fail-closed
local sandbox. **§12.9 and §15 are measured results, not proposals** — §12.9 an executed
absorb/extract round trip, §15 a tag audit that **corrects §11.2**.

> Context: the dev lead's own summary was *"it's a bit of a mess at the moment"*. The history is
> actually clean and linear. What's messy is that `main` is the ADO default on all 30 repos while
> being long dead, plus inconsistent tagging and two stray gitlinks.

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

## 11. Proposal — `develop` as the real root development branch

**Status: proposal. Needs Robert's ack on §11.6 before any push.**

### 11.1 What it solves

Three pains, one root cause — *there is no single branch name that means "current work"*:

| Pain | Cause |
|---|---|
| `origin/HEAD` and the ADO default point at a dead branch in 28 of 30 repos | nobody switched the default (§3) |
| ~~`git submodule update --remote` is meaningless~~ | **Not a problem — see §11.3(c).** `--remote` follows the remote's `HEAD`, so switching the ADO default to `develop` is enough. No `branch =` needed, which is also the fleet rule. |
| Tags don't identify anything (`Version_1.0.1` on RC10) | no release branch, so nothing to tag (§4); **and where submodule tags exist, most point at the wrong commit — §15.2** |
| Two live `version/*` names to keep straight | historical; **as of 2026-07-29 largely self-resolved** (§0) |

History is strictly linear, so this is pure bookkeeping — **no merge work, no conflicts.**

### 11.2 Target model — two branches, nothing else

```
develop   ← integration. Everyone pushes here. Always configures + builds.
main      ← last thing actually shipped. Fast-forwarded only at release. Tagged there.
```

No `release/*`, no `version/*`, no gitflow. Rationale:

- **`develop` = integration** because that is what `version/Beta220` already is in practice.
- **`main` = release** gives tags a home and makes §4 fixable: a tag on `main` means "we shipped
  this", which is the only meaning anybody wanted from `Version_2.1.0`. But note the limit: this
  gives a tag a *home*, not a *meaning across the tree* — a release still means tagging 26 repos, and
  a superproject tag still captures only gitlink SHAs. **Only §12's absorb makes one tag mean the
  whole product** (§12.10.3).
- ~~**Do *not* fast-forward `main` now.**~~ **Superseded by §15.1 — this was wrong.** `Version_2.1.0`
  sits on `43f8ced` (2026-07-21) and was a real delivery, so "last thing shipped" means `main` belongs
  at `43f8ced` *now*, not at RC10. It is a 29-commit fast-forward on linear history, and it makes both
  release tags reachable from `main` as a side effect. Switching the ADO *default branch* to `develop`
  is still separate and still needed.
- `version/Beta220` / `version/20Beta` become frozen markers. Don't delete yet — deployed builds are
  traceable only via gitlink SHA (§4). Tag the final tips (`frozen/Beta220`, `frozen/20Beta`) and
  delete the branches in a month.

### 11.3 Creating it — one scripted pass, ~5 minutes

`develop` starts at each repo's **`version/Beta220` tip**, which per §8 is exactly the SHA the
superproject already pins. So `develop` is buildable-as-pinned from the first second. Since 2026-07-29
every code repo has that branch, so **no `version/20Beta` fallback is needed** — but the loop keeps
one as a safety net in case a repo is missed.

Run from a fresh, fully-initialised superproject checkout:

```sh
# 1) submodules (and nested submodules)
git submodule foreach --recursive '
  git fetch --quiet origin
  for b in version/Beta220 version/20Beta; do
    if git rev-parse --verify --quiet "refs/remotes/origin/$b" >/dev/null; then
      git push origin "refs/remotes/origin/$b:refs/heads/develop" && echo "OK   $displaypath  <- $b"
      break
    fi
  done'

# 2) superproject
git fetch origin
git push origin refs/remotes/origin/version/Beta220:refs/heads/develop
```

`git push <remote-tracking-ref>:refs/heads/develop` creates the branch server-side with no local
checkout — it cannot lose work and cannot fast-forward anything. `om_OpenXLSX` will be skipped
(vendored, no `version/*` branch); give it `develop` from `main` or leave it out.

Then, in the same sitting, four things that make `develop` genuinely *root* rather than a new name:

**(a) Land the build-env work.** `SetupBuildEnvOnBeta220` (13 repos, §7) is what makes a clean
checkout configure, build and install. Merge it into `develop` immediately. Until that lands,
`develop` is not "working" in the sense asked for.

**(b) Remove the two stray gitlinks (§5)** in the first `develop` commit —
`git rm --cached .claude/worktrees/upbeat-blackwell Modules/ModuleTemplate` — and add
`.claude/worktrees/` to `.gitignore`.

**(c) ~~Add `branch = develop` to every `.gitmodules`~~ — DROPPED 2026-08-04. Do not do this.**

Two independent reasons, and the second one makes the first free:

1. **The fleet forbids it.** `ips-suite2/.gitmodules` has **no `branch =` entry on any of its four
   submodules**, nor on the nested MIRAGE tree — the convention across the company's projects is
   SHA-pinned only. OneMill should not be the exception.
2. **It is redundant — verified empirically.** `git submodule update --remote` **works without it**:
   with no `branch =` set, git follows the submodule remote's **`HEAD`**. Tested in a scratch repo —
   the pin moved from `6649f8a` to `46e0ea4`, exactly the submodule's `develop` tip, with
   `.gitmodules` carrying no `branch` key at all.

So `--remote` follows `develop` automatically **as a consequence of §11.4 item 1** (switching the ADO
default branch to `develop`) plus item 2 (`git remote set-head origin -a` to refresh `origin/HEAD`).
The convenience arrives for free, and no `.gitmodules` entry is needed to get it.

Nothing else consumes `submodule.<name>.branch`. It has **zero** effect on
`clone --recurse-submodules`, `submodule update --init --recursive`, `submodule sync`, gitlink
resolution, the CMake build, or Azure Pipelines' `checkout: submodules: recursive` — all of which use
the pinned SHA. The tree stays fully functional without it.

**(d) Rewrite `.gitmodules` URLs from SSH to HTTPS** (§2) — the one `.gitmodules` change that *is*
needed. Removes the local `insteadOf` workaround every new machine needs, and is a hard prerequisite
for CI (§13.4). Use the **fleet form, with the org as user**, matching `ips-suite2/.gitmodules`:

```
url = https://cads-team@dev.azure.com/cads-team/KLS%20OneMill/_git/om_MainApp
```

Follow with `git submodule sync --recursive` on every clone.

> **Rule about `--remote`:** it is available but never automatic. Use it as a deliberate "pull
> everyone's latest" action, *then build*, *then* commit the gitlink bumps — never inside a script. The
> pinned SHA stays the record of what was tested (§4). If you want it fully explicit instead, skip
> `--remote` and use `git submodule foreach --recursive 'git checkout develop && git pull --ff-only'`,
> which shows exactly what moved. **This is the reason the fleet rule is right:** `--remote` silently
> retargets gitlinks to whatever a branch tip is *now*, which is precisely how an untested combination
> gets committed as though it were deliberate.

### 11.4 ADO settings + git config

1. **Default branch → `develop`** on the 26 code repos. Fixes the biggest source of the mess (§3).
2. Locally after that: `git submodule foreach --recursive 'git remote set-head origin -a'` plus the
   same in the superproject, so `origin/HEAD` stops pointing at `main`.
3. **No branch policies on `develop`** — direct push is the agreed model (§11.6). One exception worth
   considering: a *"require merge strategy → merge commit only"* policy, which adds no approval step
   and defuses the squash-habit risk if anyone ever completes a PR in the ADO UI (the project has no
   merge-strategy policy anywhere, and ADO remembers each user's last choice).
4. Skip `om_documentation` (already on `develop`) and `om_integrationtest_highlevel` (genuinely on
   `main`, PR-based, different team).

Recommended global git config for all three of us — removes most day-to-day submodule pain with zero
process:

```sh
git config --global submodule.recurse true            # checkout/pull update submodules automatically
git config --global push.recurseSubmodules on-demand  # refuse to push a gitlink whose commit isn't pushed
git config --global status.submoduleSummary true       # git status shows *what* changed in a submodule
git config --global diff.submodule log                # gitlink diffs read as commit lists, not SHAs
```

`push.recurseSubmodules on-demand` alone prevents the classic "works on my machine, gitlink points at
a commit only I have" failure.

### 11.5 Branch hygiene at switch time

Do it in the same sitting; it will never be cheaper. Full inventory in §7.

- **Delete the fully-merged branches** — `feature/usa` and `feature/ncSequence` everywhere, plus
  om_MillingBackend's 14 merged branches. Pure noise, all relative to dead `main`.
- **Delete `SetupBuildEnvOnMain`** (7 repos) — dead line, superseded by `SetupBuildEnvOnBeta220`.
- **`SelfcontainedSuperbuild`** (7 repos) — land into `develop` or tag and delete. It should not
  survive as a third long-lived line.
- ~~**Pia's 9 live branches** are the only real in-flight work.~~ **Resolved 2026-08-04 — see §7.1.
  Robert merged them locally and pushed; they are all already contained in `version/Beta220`.**
  They are pure deletion candidates, not decisions. Original text kept for context: decide per branch:
  land into `develop`
  now, or let her rebase onto `develop` (all but one are in a single repo, so this is cheap). Do
  **not** leave them branched off dead `main` — that is how they got to `-1` behind.

### 11.6 How the three of us work

> **Partly superseded 2026-08-04 by the decision in §11.6a: no direct push to `main` or `develop` in
> the final repo.** In Azure DevOps that necessarily means PRs. Read **§11.6a first** — it sets the
> gate; the mechanics below (the `review/<topic>` branches and the combined-diff script) remain
> valuable, but as the way a reviewer *sees* a cross-repo change that ADO's PR UI cannot render,
> not as a replacement for PRs.

PRs died on 2026-01-30 for a structural reason, not a cultural one: **a typical change touches 3–6
repos, and Azure DevOps cannot show a cross-repo diff.** Five PRs plus a superproject PR, reviewed
separately with no combined view, is worse than no review. Don't fight it.

**The insight: the superproject commit *is* the pull request.** One SHA already describes an atomic
cross-repo change, and it can be checked out and built — strictly more than an ADO PR can represent
here.

#### The contract

| | Rule |
|---|---|
| **Push target** | Direct push to `develop`. No approval for routine work. |
| **`develop` is append-only** | Never force-push, never rebase `develop`. Rebase only your own *unpushed* commits. |
| **Ordering** | Push submodule commits **before** the superproject gitlink bump, always. `push.recurseSubmodules on-demand` enforces it. |
| **Gitlink ownership** | Announce in Teams before bumping superproject gitlinks. Two people bumping concurrently *always* conflicts — a gitlink is one line. Resolution is trivial (take theirs → `git submodule update` → re-bump) but needs saying out loud. |
| **Build before you bump** | Whoever bumps the gitlink builds first. With no CI (§6) this is the *entire* quality gate, and what keeps "`develop` always builds" true. |
| **Pia** | Works almost only in `om_MillingBackend`. Branch off `develop`, merge back to `develop`, ping whoever owns the gitlink bump. Never needs the superproject. |

#### Showing Robert a change before it lands: `review/<topic>` branches

**This already works** — `SetupBuildEnvOnBeta220` exists as the same branch name in the superproject
plus the 12 submodules it touches (§7). Formalise that:

```sh
# --- my side: publish the whole cross-repo change under one name ---
topic=review/vhf-holemilling

git submodule foreach --recursive '
  if [ -n "$(git log --oneline origin/develop..HEAD 2>/dev/null)" ]; then
    git push origin HEAD:refs/heads/'"$topic"'
  fi'
git push origin HEAD:refs/heads/$topic     # superproject last — it pins the submodule commits
```

```sh
# --- Robert's side: get the exact tree, build it, read it ---
git fetch origin && git checkout $topic
git submodule update --init --recursive    # lands on my submodule commits, pinned by the superproject
```

Because the superproject branch pins the submodule review commits, `submodule update --recursive`
reconstructs the *complete* change. Robert reviews by building and running it — the review that
actually matters for this codebase.

For reading rather than running, generate one combined diff file:

```sh
{ echo "# $topic vs develop"
  echo; echo "## == superproject =="
  git diff --submodule=log origin/develop...HEAD
  git submodule foreach --recursive --quiet '
    d=$(git diff origin/develop...HEAD)
    if [ -n "$d" ]; then echo; echo "## == $displaypath =="; echo "$d"; fi'
} > review-$topic.diff
```

`--submodule=log` makes the superproject part read as per-submodule commit lists instead of SHA
noise. One file, whole change, any editor — the thing ADO cannot give you.

**Landing it** after Robert's ok — a real merge commit, never a squash (a squash would orphan the
submodule commits the gitlinks point at):

```sh
git checkout develop && git pull
git merge --no-ff $topic -m "Merge '<topic>' into develop"
```

Then delete the `review/*` branches everywhere. Worth adding as `GitHelper.ps1` verbs:
`review-push`, `review-diff`, `review-land`, `stale-branches`.

**When to use an ADO PR anyway:** only when Robert wants *line-level comments* on a change confined
to **one** repo. Open it plain (no policies, no required reviewers), let him thread comments, merge
**locally** with `--no-ff` — ADO auto-closes it. Never press *Complete* in the UI (see §11.4 item 3).

### 11.6a Branch protection — "no direct push to `main`/`develop`"

**Decision taken 2026-08-04:** in the final repo, direct pushes to `main` and `develop` must not be
permitted.

**Yes — in Azure DevOps that means pull requests. There is no other mechanism.** ADO has no
"protected branch, but push allowed for some" middle setting: the moment a branch carries **any**
branch policy, direct pushes are rejected (`TF402455: Pushes to this branch are not permitted; you
must use a pull request`). So "no direct push" and "PR required" are the same switch. Adding
*Minimum number of reviewers = 1* is what additionally guarantees a human looked.

#### The tension to resolve first

§11.6's core finding still holds: **ADO cannot show a cross-repo diff**, and a typical change touches
3–6 repos. So *where* you apply the policy decides whether this is one PR or six.

| Scope of policy | PRs per typical change | Verdict |
|---|---|---|
| Every repo's `develop` + `main` (26 repos) | **3–6 + 1** | Recreates exactly the friction that killed PRs in Jan 2026. Will be worked around. |
| **Superproject `develop` + `main` only** | **1** | ⭐ **Recommended.** |
| `main` only, `develop` left open | 1, at release time only | Lowest friction, but no per-change review — probably not what's wanted. |

**Recommended shape:** policies on the **superproject's** `develop` and `main`. Submodules keep
`develop` push-open; optionally protect submodule `main` (they are release markers/archives).

The justification is the §11.6 insight, unchanged: **the superproject commit is the reviewable unit.**
It is the only place a cross-repo change is atomic, and it is the commit that defines what the product
*is*. Gate that, and you gate everything — a submodule commit that no superproject gitlink references
is not part of the product. With `diff.submodule log` (§11.4) the PR's gitlink diff reads as the list
of submodule commits being pulled in, so the reviewer sees *what* changed even though ADO won't diff
the content. For the actual content review, the reviewer uses §11.6's `review/<topic>` checkout or the
combined-diff file — which is why that machinery is still worth building.

#### Three settings that are mandatory, not optional, once PRs are required

1. **"Require a merge strategy" → merge commit (no squash).** Previously listed as optional in §11.4.
   With PRs mandatory it becomes **critical**: completing a superproject PR as a *squash* would orphan
   the submodule commits the gitlinks point at, producing exactly the unresolvable-gitlink breakage of
   §5. The setup ledger already notes there is no such policy anywhere in the project and that ADO
   remembers each user's last-used strategy — so the default is actively dangerous here.
2. **"Allow requestors to approve their own changes" → OFF.** Otherwise a 1-reviewer policy is
   theatre. But be deliberate: with 3 people and Robert authoring most changes, this means **Robert
   cannot land anything without Martin or Pia approving.** That is a real workflow commitment and
   should be agreed explicitly, not discovered.
3. **Decide who holds "Bypass policies when completing pull requests".** Someone needs it for a
   production emergency. Grant it consciously to a named person; ADO logs its use.

#### Why this raises the priority of §13

A PR policy with no automated check is a human rubber-stamp. ADO's **build validation** policy attaches
a pipeline to the PR so `develop` cannot receive a change that doesn't build — which is precisely the
guarantee §11.6's "build before you bump" rule was trying to achieve by convention, and §12.7 noted
had *zero* automation behind it. So: **§13's build pipeline plus the `check-submodule-downgrade.sh`
guard should become build-validation policies on the superproject's `develop`.** That combination —
1 reviewer + builds + no gitlink downgrade — is a genuinely strong gate for about a day's setup.

**Not rehearsable locally.** Branch policies are an ADO feature, not a git one, so §14's sandbox cannot
test any of this. Verifying it needs the stage-two throwaway ADO project (§14.5).

### 11.7 Migration order

1. Robert pushes everything outstanding to `version/*` and agrees to stop pushing there. **Blocking.**
2. Run §11.3 step 1+2 — `develop` exists in ~27 places.
3. First `develop` commit: strays removed (**already done on the build-env branch** — §5 verified
   2026-08-04), HTTPS URLs in the `.gitmodules` files that need them (**no `branch =`** — §11.3c),
   `.claude/worktrees/` ignored.
4. Merge `SetupBuildEnvOnBeta220` into `develop` — now `develop` builds from a clean clone.
5. ADO defaults → `develop` (§11.4). Everyone: `git submodule sync --recursive`, then re-clone once.
   *If §12.6 phase 1 is already agreed, skip this for the 8 nested `*Backend` repos — they are about
   to become read-only archives. See §12.10.2; it is the only work the two plans duplicate.*
5a. **Fast-forward `main` to `Version_2.1.0^{commit}` (`43f8ced`) — superproject only** (§15.1/§15.4).
   `git push origin Version_2.1.0^{commit}:refs/heads/main`. Both release tags become reachable from
   `main`; `develop` then sits 4 commits ahead, the correct steady state. Do **not** do this in the
   submodules — their own `main` branches and tags are unreliable (§15.2).
6. Branch hygiene (§11.5), including a decision on each of Pia's 9 live branches.
7. Tag `frozen/Beta220` + `frozen/20Beta`; delete those branches after a month.
8. The three §6 questions are then answered, except "revive or retire `main`", which becomes "keep it
   as the release branch, ff at next release".

Everything except step 1 is reversible. **Do not couple this to §12** — this is the cheap half.

**Do not reorder §12's absorb before this.** `git subtree add` would have to land its merge on
`version/Beta220` / `version/20Beta`, i.e. on the very branches step 7 freezes as the only record of
what shipped (§4). Absorbing wants `develop` to exist first — the two plans converge rather than
compete. Worked through in **§12.10**, including why the absorb is the ideal *first* change to land on
`develop` (step 3 there), and why it must come **after** step 4 above.

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

## 13. A pipeline for OneMill — modelled on ips-suite2, kept minimal

**Status: proposal.** Based on reading `C:\DATA\repos\intern\ips-suite2` (Suite + MIRAGE) as the
reference for the intended company-wide standard. Nothing committed yet.

### 13.1 What ips-suite2 has

| File | Lines | Agent | What it is |
|---|---|---|---|
| `pipelines/format-check.yaml` | 62 | hosted `ubuntu-latest` | PR gate: submodule-downgrade guard + clang-format 20 |
| `pipelines/build-validation-windows.yaml` | ~1300 | self-hosted `suite-aws-pool` | The real Windows build. **~1 100 lines are AWS EC2 fleet management, version stamping, artifact flavoring, tagging and `build-info.json`.** |
| `pipelines/build-validation-linux.yaml` | 40 | self-hosted Linux GPU | Docker build + tests |
| `pipelines/templates/superbuild-build.yml` | 159 | — | **Shared steps template.** The standardization unit. |
| `project/MIRAGE/azure-pipelines-*.yml` | 5 files | self-hosted GPU pool | Per-component, same EC2 warmup/shutdown shape |
| `pipelines/scripts/check-submodule-downgrade.sh` | 130 | — | **Directly reusable by OneMill** (§13.3) |
| `pipelines/scripts/*orchestrator*.ps1` | ~80 k | — | Release / auto-deploy orchestration |
| `PipelineRefactorSteps.md` | 913 | — | Their spec + findings ledger. §6.1 states the goal: *one shared CI template + per-product parameters, so product pipelines stay thin.* |

**The honest read:** the intent is exactly right and worth adopting. The current state is a 1 300-line
file in which the build is ~30 lines and the rest is infrastructure. That accretion is what not to
propagate — OneMill is the chance to define the thin version *before* it happens.

### 13.2 What to take, what to leave

**Take (all cheap, all standardizable):**

- **Directory convention** — `pipelines/`, `pipelines/templates/*.yml`, `pipelines/scripts/`.
- **Split by purpose:** a cheap PR gate on a free hosted agent, a separate real build on the
  expensive agent. ips-suite2 got this right.
- **`check-submodule-downgrade.sh` verbatim** — `BASE_DEFAULT` is already `develop` (§13.3).
- **`CreateCadsVersion@3`** — the in-house ADO task that sets `Build.BuildNumber`. Already the org
  standard, free to reuse.
- **Branch → flavour:** `main` = final, `release/*` = beta, `develop` = alpha. Adopt the vocabulary
  now, even before publishing, so artifact names never have to be renamed.
- **Trigger set** `develop` / `main` / `release/*` — matches §11's model exactly.
- **Output grammar** `out/build/<tuple>-<config>`, `out/install/<tuple>-<config>`. **OneMill already
  complies.**

**Leave (for now, or forever):**

- **AWS EC2 warmup/shutdown/failsafe stages** (~600 lines solving "Windows agents are expensive").
  With 3 developers, one always-on agent is enough. Don't build fleet management for a 3-person team.
- **Docker** — static-CRT MSVC desktop build; containers buy nothing.
- **The superbuild engine + `-DSWITCH=` passthrough** — OneMill is plain vcpkg + `find_package`.
  Adopting the engine is a much bigger conversation than a pipeline.
- **Publish / auto-deploy / release orchestrators** (~80 k of PowerShell).
- **`Cache@2` dependency caching** — OneMill's heavy deps (Qt, VTK, ModuleWorks) are *pre-installed
  on the agent*, not built by CI. Nothing to cache. A genuine simplification, not a shortcut.
- **clang-format check** — OneMill has **no `.clang-format`**, so this would flag every file. Needs a
  "format the whole tree in one commit" decision first.

### 13.3 The submodule-downgrade guard is the point

The script fails the build when a gitlink moves **backward or diverges** relative to the merge-base
with the target branch, unless a commit carries an `Allow-Submodule-Downgrade: <path>` trailer. It is
self-contained (fetches its own bounded, blob-filtered history), needs no toolchain, and runs on a
**free hosted Linux agent in about a minute**.

For OneMill this is worth more than the build pipeline. Rewinding a gitlink is *the* characteristic
failure of this layout — §5's strays are a milder case — and with three people direct-pushing to
`develop` it will happen. Nothing else in this proposal catches it.

**One gap:** the script enumerates `git config -f .gitmodules --get-regexp '\.path$'`, i.e.
**top-level gitlinks only**. On OneMill it covers the 17 superproject gitlinks but not the 9 nested
ones. Either wrap it in a recursion over the 8 wrapper modules, or accept partial coverage —
or note that §12.6 phase 1 makes the problem disappear.

### 13.4 Four blockers to fix before any pipeline can run

Prerequisites, not pipeline work. All four are worth fixing regardless.

**1. No committed, CI-usable preset.** `CMakePresets.json` deliberately contains only *hidden* base
presets — the selectable ones live in `CMakeUserPresets.json`, which is machine-specific and **not
committed** (only `.example`). A CI agent has no selectable preset at all. Fix: a committed CI preset
family taking the five machine paths from the environment, so CI and local use the identical code path
(their spec's "parity with local" principle):

```jsonc
// CMakePresets.json — new, committed
{
  "name": "onemill-config-ci-win-msvc-x64-relwithdebinfo",
  "inherits": "onemill-base-win-msvc-x64-relwithdebinfo",
  "environment": { "QTDIR": "$env{ONEMILL_QTDIR}" },
  "cacheVariables": {
    "Qt6_DIR":         "$env{ONEMILL_QTDIR}/lib/cmake/Qt6",
    "VCPKG_ROOT":      "$env{ONEMILL_VCPKG_ROOT}",
    "VTK_DIR":         "$env{ONEMILL_VTK_DIR}",
    "MODULEWORKS_DIR": "$env{ONEMILL_MODULEWORKS_DIR}",
    "INSTALL_DIR":     "$env{ONEMILL_INSTALL_DIR}"
  }
}
```

Plus a matching `onemill-build-ci-...` build preset inheriting `onemill-build-base` — whose comment
already explains why the default `all` target is mandatory (`MainApp` does not depend on the ten
plugin DLLs, so pinning a target list silently yields an app with no modules).

The agent carries `ONEMILL_*` as machine environment variables — that *is* the agent contract, and
`.vscode/OneMill-Setup-Ledger.md` already documents it. An unset `$env{}` expands to empty and
produces a confusing configure error, so assert all five before configuring.

**2. `.gitmodules` uses SSH URLs** (§2). `checkout: submodules: recursive` authenticates over
**HTTPS** with the build token and cannot resolve SSH URLs — CI fails at checkout. Rewrite to HTTPS
in the §11.3(d) commit.

**3. A self-hosted Windows agent is mandatory.** OneMill needs MSVC, Qt 6.10.2, a **custom Qt-enabled
VTK 9.5**, vcpkg with `x64-windows-static` pre-populated, and the licensed **ModuleWorks SDK**. A
hosted agent has none of it, and building VTK+Qt per run is hours.
   - *(a)* Register a new agent (dev box or small always-on VM) into a new pool `onemill-pool`,
     provisioned per the setup ledger. **Recommended** — the ledger is already the provisioning spec.
   - *(b)* Borrow `suite-aws-pool` (pools are org-level and shareable). But those EC2 images have no
     VTK-with-Qt and no ModuleWorks SDK, so they'd need provisioning anyway — and OneMill inherits the
     EC2 start/stop dance. Not worth it initially.

   Because vcpkg packages are pre-installed rather than resolved per run, **agent drift is the real
   risk**. Cheap mitigation: print `cmake --version`, `vcpkg list`, the resolved `VTK_DIR` and Qt
   version at the top of every run, so drift shows up in the log before it shows up as a mystery.

**4. `D:/deployData` is baked in.** `INSTALL_DIR` is a `CACHE` variable so a preset overrides it —
point it at `$(Build.ArtifactStagingDirectory)`; CI must never write to a fixed machine path. Note the
asymmetry: the **`deploy` target's `DEPLOY_DIR` is a plain `set()`, not `CACHE`, so it cannot be
overridden.** Use `install_full`, not `deploy`. (Worth changing that `set()` to `CACHE` while in there.)

### 13.5 Phase 1 — two pipelines, ~90 lines total

**A — `pipelines/onemill-guard.yml`** (PR + push; free hosted Linux agent):

```yaml
trigger:
  branches: { include: [develop, main, 'release/*'] }
pr:
  branches: { include: [develop, main] }

pool: { vmImage: 'ubuntu-latest' }

steps:
  - checkout: self
    fetchDepth: 1              # the guard fetches its own base/source history
    persistCredentials: true
  - script: bash pipelines/scripts/check-submodule-downgrade.sh
    displayName: 'Guard: submodule pointer downgrade'
    env:
      SYSTEM_ACCESSTOKEN: $(System.AccessToken)
```

**B — `pipelines/onemill-build-windows.yml`** (self-hosted; the actual build):

```yaml
trigger:
  branches: { include: [develop, main, 'release/*', 'review/*'] }
pr: none                        # PRs are not the model here (§11.6)

pool: { name: 'onemill-pool' }

variables:
  SB_PRESET:  onemill-config-ci-win-msvc-x64-relwithdebinfo
  SB_BUILD:   onemill-build-ci-win-msvc-x64-relwithdebinfo
  SB_OUT:     out/build/win-msvc-x64-relwithdebinfo
  VS_DEV_CMD: 'C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\Tools\VsDevCmd.bat'

jobs:
  - job: BuildAndInstall
    timeoutInMinutes: 120
    workspace: { clean: outputs }
    steps:
      - checkout: self
        submodules: recursive   # requires HTTPS .gitmodules — blocker #2
        persistCredentials: true

      - task: CreateCadsVersion@3     # org-standard version stamp -> Build.BuildNumber

      - powershell: |
          $required = 'ONEMILL_QTDIR','ONEMILL_VCPKG_ROOT','ONEMILL_VTK_DIR','ONEMILL_MODULEWORKS_DIR'
          $missing = $required | Where-Object { -not (Test-Path "env:$_") }
          if ($missing) { throw "Agent is missing required env: $($missing -join ', ')" }
          cmake --version
          Write-Host "QTDIR=$env:ONEMILL_QTDIR  VTK_DIR=$env:ONEMILL_VTK_DIR"
        displayName: 'Agent contract + toolchain versions'

      # cl / ninja on PATH for the rest of the job. Do NOT reuse .vscode/dev-run.cmd here: it uses
      # `setlocal`, so its environment never escapes to the following steps — and its below-normal
      # priority + (cores-2) job cap exist to keep a *dev PC* responsive, the opposite of what a
      # dedicated agent should do.
      - task: BatchScript@1
        displayName: 'Initialize Visual Studio environment'
        inputs:
          filename: '$(VS_DEV_CMD)'
          arguments: '-arch=amd64 -host_arch=amd64'
          modifyEnvironment: true

      - script: cmake --preset $(SB_PRESET)
        displayName: 'Configure'
        env: { ONEMILL_INSTALL_DIR: '$(Build.ArtifactStagingDirectory)/install' }

      - script: cmake --build --preset $(SB_BUILD)
        displayName: 'Build'

      - script: cmake --build $(SB_OUT) --target install_full
        displayName: 'Install (install_full)'

      - task: PublishPipelineArtifact@1
        displayName: 'Publish install tree'
        inputs:
          targetPath: '$(Build.ArtifactStagingDirectory)/install'
          artifact: 'KLSOneMill-$(Build.BuildNumber)'
```

No stages, no AWS, no cache, no matrix, no publish chain. Two deliberate choices:

- **`review/*` is in the trigger.** Under §11.6 Robert reviews by building a `review/*` branch. If CI
  builds it automatically, "it compiles and installs" arrives before he even looks — the review
  becomes about the code, not the build. The cheapest possible payoff from having CI at all.
- **RelWithDebInfo only.** Per the setup ledger, Debug builds but cannot run (static CRT, one heap per
  plugin DLL). Building a configuration nobody can run is wasted agent time.

### 13.6 Phase 2 and 3 — once phase 1 has been green for a while

**Phase 2 — make it say something about correctness.** `om_integrationtest_highlevel` already has a
GoogleTest/CTest suite *designed* to be `add_subdirectory()`'d from the superproject (mode A,
§12.3.1), covering dispatcher routing, the `ModuleInterface` plugin contract, and deployment
integrity of the shipped plugin DLLs. Wiring it in is a few lines — `resources.repositories` plus one
`add_subdirectory` behind an option — and it turns the pipeline from "it compiles" into "the plugin
contract holds". **Highest-value phase-2 item by a wide margin, and the work already exists.**

**Phase 3 — the standardization.** Extract `pipelines/templates/cmake-preset-build.yml`, a steps
template parameterized by `product`, `tuple`, `config`, `runTests`, `installTarget`,
`stageInstallToArtifact`. OneMill's pipeline B then shrinks to a ~15-line caller. That template is
what ips-suite2's spec §6.1 describes and what their 1 300-line file has not yet been reduced to —
and OneMill, being simple, is the better place to get its shape right first.

### 13.7 Proposed company-wide vocabulary

| Convention | ips-suite2 today | OneMill today | Standard |
|---|---|---|---|
| Pipeline dir | `pipelines/` | — | `pipelines/` |
| Steps templates | `pipelines/templates/*.yml` | — | same |
| Scripts | `pipelines/scripts/` | — | same |
| Build output | `out/build/<tuple>-<config>` | ✅ same | same |
| Install output | `out/install/<tuple>-<config>` | install → `INSTALL_DIR` | `out/install/<tuple>-<config>` |
| Preset naming | `<product>-config-<tuple>-<lane>-<config>` | `onemill-config-<tuple>-<config>` — **no lane, deliberately** | `<product>-{config,build,test}-<tuple>[-<lane>]-<config>`, lane **optional** |
| Dev-env entry | `.vscode/dev-run.cmd` (fleet-shared) | ✅ byte-identical copy | same, one canonical source |
| Version stamp | `CreateCadsVersion@3` | — | same |
| Triggers | `develop`, `main`, `release/*` | — | same |
| Branch→flavour | main=final, release/\*=beta, develop=alpha | — | same |
| Submodule guard | `check-submodule-downgrade.sh` | — | same script, verbatim |
| Cheap PR gate | separate hosted-agent pipeline | — | same |

**Correction 2026-08-04:** the "no lane" cell is **not a gap.** `OneMill-Fleet-Conformance.md` records
the `{lane}` token (upstream **A6/B5**) as *deliberately not adopted* — "OneMill has a single lane;
renaming every preset buys conformance only, and costs muscle memory plus any script that names a
preset." The org standard should therefore make the lane segment **optional**, not required.

That file is the authority on OneMill's fleet position and should be consulted before any further
standardization claim here. Three of its verdicts bear directly on this section: **D2** (pinned
submodules) is recorded as already satisfied — the basis for the no-`branch =` rule in §11.3(c);
**D5** (local/CI parity) is *deferred pending exactly the CI work proposed here*, so parity is a
requirement **on** §13, not a claim; and **D7** (no automated tests at all) is an open gap that §13.6
phase 2 closes by wiring in `om_integrationtest_highlevel`.

**OneMill already complies with more of this than ips-suite2's own pipelines do** — the output
grammar, the preset families and the shared `dev-run.cmd` (whose header names
`SuperbuildEngine/templates/dev-run.cmd` as canonical) all landed with the build-env work. The only
gap is that it has no pipeline. That makes OneMill a good second consumer of the shared template:
small enough that getting it wrong is cheap, real enough to prove the template.

### 13.8 Open questions

1. **Which agent?** New `onemill-pool` on an always-on box (recommended), or provision an existing
   pool? Who owns the machine and its Qt/VTK/vcpkg/ModuleWorks state?
2. **Is `CreateCadsVersion@3` usable in the KLS OneMill project**, or only in IPS Suite? (ADO
   extensions are org-level, so it should be — but this project has never used it.)
3. **Publishing** — should phase 1 publish an artifact, or just prove the build? Publishing costs
   nothing and immediately gives Robert a downloadable build per `develop` commit, possibly the most
   visible benefit.
4. **Formatting** — is a one-commit `clang-format` pass over the tree acceptable? Precondition for
   adopting ips-suite2's format gate, and it will produce an enormous diff.

---

## 14. Rehearsing the whole reorg in a sandbox, without touching production

> **The executable runbook derived from this section is
> [`OneMill-Sandbox-Rehearsal.md`](OneMill-Sandbox-Rehearsal.md)** (created 2026-08-04). This section is
> the *why*; that file is the step-by-step *how*. Its scope excludes §12's submodule absorb by decision
> — the submodule structure stays as-is for now.

**Verified mechanism, 2026-08-04.** The entire §11 + §12 plan can be rehearsed locally against a
**fail-closed mirror farm** — a set of local bare repos that stand in for the ADO remotes, wired up so
the sandbox is *structurally incapable* of reaching Azure DevOps.

### 14.1 Why a mirror farm rather than branches in the real clone

Rehearsing on branches in `KLSOneMill4` without pushing tests almost nothing that matters: the risky
part of §11 is **multi-repo push ordering**, `push.recurseSubmodules`, `submodule update --remote` with
`branch = develop`, and gitlink consistency across 27 repos. All of that needs real remotes you are
allowed to push to. And it carries a live risk of an accidental push to production.

Size makes this easy: the **entire 26-repo tree with full history is 29 MB** (`.git`, measured). A
complete mirror of all 30 repos is a rounding error on disk.

### 14.2 The mechanism — URL rewriting, no content changes

Do **not** edit `.gitmodules` to point at local paths; that would be a commit in the sandbox and would
pollute exactly the thing you are testing. Instead redirect the *existing* URLs with `insteadOf` in a
sandbox-only config selected by `GIT_CONFIG_GLOBAL` (supported since git 2.32; this PC has **2.53.0**).

**Verified behaviour:**

```
$ GIT_CONFIG_GLOBAL=$SB/gitconfig git ls-remote --get-url \
      git@ssh.dev.azure.com:v3/cads-team/KLS%20OneMill/om_ModuleStatistics
  → …/scratchpad/redirect-test/srv/om_ModuleStatistics.git     # per-repo rule wins
$ … git clone git@ssh.dev.azure.com:v3/…/om_ModuleStatistics
  → CLONE OK, 12 commits, no network used
```

`insteadOf` resolves by **longest match**, so a per-repo rule beats the broad SSH→HTTPS prefix rule
already configured on this PC (`url.https://cads-team@dev.azure.com/…/_git/.insteadOf =
git@ssh.dev.azure.com:v3/cads-team/KLS%20OneMill/`). Content stays byte-identical to production.

### 14.3 ⚠ The safety trap, and the fix

Testing revealed the one thing that could actually hurt you:

```
$ … git ls-remote --get-url git@ssh…/om_MainApp     # no per-repo rule defined
  → https://cads-team@dev.azure.com/cads-team/KLS%20OneMill/_git/om_MainApp
```

**A repo you forget to map silently resolves to the real ADO.** Harmless for a fetch — but the whole
point of the rehearsal is running `git push`, and an unmapped repo would push to **production**.

So build the config **fail-closed**: do *not* `[include]` the real `~/.gitconfig`; instead map the
whole ADO namespace to a dead local path *first*, then add the 30 specific rules on top.

```ini
# $SB/gitconfig  — sandbox only, selected via GIT_CONFIG_GLOBAL
[user]
	name = Martin Schachinger
	email = martin.schachinger@cads.at

# CATCH-ALL FIRST: anything not explicitly mapped resolves to a path that does not
# exist -> hard failure, never the network. Shorter match, so per-repo rules win.
[url "C:/DATA/sandbox/onemill/srv/UNMAPPED--"]
	insteadOf = git@ssh.dev.azure.com:v3/cads-team/KLS%20OneMill/
	insteadOf = https://dev.azure.com/cads-team/KLS%20OneMill/_git/
	insteadOf = https://cads-team@dev.azure.com/cads-team/KLS%20OneMill/_git/

# then one longer, winning rule per repo (generated — 30 of these)
[url "C:/DATA/sandbox/onemill/srv/om_MainApp.git"]
	insteadOf = git@ssh.dev.azure.com:v3/cads-team/KLS%20OneMill/om_MainApp
```

**Pre-flight gate before running anything:** assert that every one of the 30 URLs resolves inside the
sandbox and that *none* resolves to `dev.azure.com`. Refuse to start otherwise.

```sh
for r in $REPOS; do
  u=$(GIT_CONFIG_GLOBAL=$SB/gitconfig git ls-remote --get-url \
        "git@ssh.dev.azure.com:v3/cads-team/KLS%20OneMill/$r")
  case "$u" in "$SB"/*) ;; *) echo "UNSAFE: $r -> $u"; exit 1 ;; esac
done
```

Belt and braces: `export GIT_TERMINAL_PROMPT=0` so nothing can interactively authenticate.

### 14.4 Bootstrap

```sh
SB=/c/DATA/sandbox/onemill          # deliberately NOT under the real clone
ORG='https://dev.azure.com/cads-team/KLS%20OneMill/_git'
mkdir -p "$SB/srv"
# --mirror gets ALL refs — every branch AND every tag. Essential: §11.5 and §15 test both.
for r in 'KLS%20OneMill' om_MainApp om_ModuleInterface om_ModuleUtils om_BackendUtils …; do
  git clone --mirror "$ORG/$r" "$SB/srv/${r//%20/}.git"
done
```

Then generate the config, run the pre-flight gate, clone the superproject **through the redirect**,
and execute §11.3 / §11.7 / §12.6 **verbatim** — the commands need no modification, which is the point:
what you rehearse is exactly what you will later run.

Bare mirrors accept pushes to any ref, which is faithful here — §11.4 item 3 confirms no branch
policies exist on any target branch today. Don't run `git remote update` on a mirror after you have
pushed to it; `--mirror` sets `fetch = +refs/*:refs/*` and would clobber your rehearsal.

### 14.5 What the sandbox proves — and what it cannot

| Testable locally | Not testable — needs ADO |
|---|---|
| §11.3 create `develop` in 27 repos | ADO **default-branch** switch (§11.4) |
| §11.3(c) `.gitmodules` edits (`branch=`, HTTPS URLs) | Branch policies, PR UI/threads |
| Stray-gitlink removal (§5) | `CreateCadsVersion@3`, agent pool, **any pipeline run** (§13) |
| Merging `SetupBuildEnvOnBeta220` | Permissions, tag-protection rules |
| §11.5 branch deletions, §11.7 `frozen/*` tags | How ADO renders a cross-repo review |
| `push.recurseSubmodules`, `submodule update --remote` | |
| **All of §12.6** absorb phases + `subtree split` reversal | |
| §15 tag reconstruction | |
| §13's `check-submodule-downgrade.sh` (pure git) | |
| **Does it still build?** (see the trap in §14.6) | |

For the right-hand column, stage two is a **throwaway ADO project** ("KLS OneMill Sandbox"): ADO's
*Import repository* pulls a full mirror including tags, and 30 imports are scriptable via REST. That is
the only way to rehearse §13's pipeline and the default-branch switch. Do it only after the git
mechanics are green locally — it costs project-creation rights and org-admin goodwill.

A local Gitea/Forgejo container is a third option if PR-flow ergonomics matter, but it won't match
ADO's behaviour and is not worth the setup for this.

### 14.6 ⚠ Build trap in the sandbox

`CMakeUserPresets.json` hardcodes **absolute** paths — `binaryDir: D:/BuildDirectory/KLSOneMill/…` and
`INSTALL_DIR: D:/deployData/KLSOneMill/…`. A sandbox clone using the same presets would **build into
and install over the real build and deploy trees**. Write a sandbox-only `CMakeUserPresets.json`
pointing at e.g. `D:/BuildDirectory/onemill-sandbox/…` before building anything. (This is also an
argument for the env-var-driven CI preset in §13.4 item 1 — one mechanism for CI *and* sandbox.)

### 14.7 Verification harness — give the rehearsal a pass/fail

A rehearsal without assertions is a vibe. Worth scripting:

1. `develop` exists in all N mirrors, tip == the pre-migration `version/Beta220` tip.
2. `git submodule update --init --recursive` exits 0 with **no** `No url found for submodule path`.
3. No `160000` entry whose path is absent from `.gitmodules` (catches §5-class strays, including the
   one §12.9.4 showed a top-down absorb creates).
4. **Content invariance:** `git diff` between the old `version/Beta220` tree and the new `develop` tree
   is limited to *exactly* the intended paths (`.gitmodules`, the two strays). The reorg must change
   no source.
5. The build configures, builds and `install_full`s from a clean sandbox clone.
6. `check-submodule-downgrade.sh` passes on the result.

### 14.8 Do this even for the real run

`git clone --mirror` of all 30 repos into a dated folder is a complete, restorable backup of the
entire project — **29 MB**. Take one immediately before touching production, regardless of how much
rehearsing happened. It makes every step in §11 recoverable, not just the reversible ones.

---

## 15. Release tags and reactivating `main` — what's actually possible

**Analysis, 2026-08-04. Amends §11.2 — see §15.4.** Question: `main` is to be the release branch, so
can `Version_1.0.1` and `Version_2.1.0` be placed on it, since those were the real past deliveries?

### 15.1 The superproject: nothing to move, just fast-forward

Measured facts:

| | Target commit | Subject | Reachable from `origin/main`? |
|---|---|---|---|
| `Version_1.0.1` | `a5ca1373` | Merged PR 25596: Merge RC10 (2025-12-10) | ✅ **YES — it *is* main's tip** |
| `Version_2.1.0` | `43f8ced3` | Version 2.1.0 (2026-07-21) | ❌ no — 29 commits ahead |

And `origin/main` **is an ancestor of** `Version_2.1.0` (history is linear, §1). Therefore:

> **No tag surgery is needed at all.** The tags already point at the right commits. `Version_2.1.0`
> simply isn't *reachable* from `main` yet. Fast-forward `main` onto it and both tags are on the
> release branch, permanently and truthfully.

```sh
git push origin Version_2.1.0^{commit}:refs/heads/main    # plain fast-forward, a5ca137..43f8ced
```

Result: `main` = "Version 2.1.0", both release tags in its history, and `develop` sits **4 commits**
ahead carrying the unreleased Beta220 work. That is the §11.2 two-branch model correct on day one,
with real history behind it rather than a declaration.

### 15.2 The submodules: the existing tags are wrong, not just inconsistent

§4 called the tags "inconsistently applied". The truth is worse, and it is now measured. Using the
superproject's tag tree (`git ls-tree -r <tag>`) as the reference for what each submodule actually
contained at that release:

| | agrees with the release | **WRONG commit** | no tag |
|---|---|---|---|
| `Version_1.0.1` | 2 | **9** | 0 |
| `Version_2.1.0` | 12 | **3** | 2 |

And the errors are systematic, not random: **all 9 wrong `Version_1.0.1` tags point 1–5 commits
*ahead* of the real release point** (`ModuleUtils` +5, `ModulePostProcessor` +3, `BackendUtils` +2,
`ModuleInterface` +2, `ModuleMillingKalotte` +2, `ModuleOverlayCritter` +2, `MainApp` +1,
`ModuleReporter` +1, `ModuleView` +1).

That is the signature of a **later batch sweep**: somebody tagged the repos at whatever their tips were
at tagging time, rather than going back to the released commit. The clincher — `BackendUtils`'
`Version_1.0.1` tag points at `e31c0c9c2`, which is *precisely what `Version_2.1.0` pins for
BackendUtils*. Its "1.0.1" tag marks 2.1.0 content.

**So the per-submodule tags are not a weaker record than the superproject tag — they are a false one.**
§4's conclusion ("do not use tags to identify a release across the tree") is now proven per repo, and
it holds for a stronger reason than assumed.

Both tags are also **lightweight** (`git cat-file -t Version_2.1.0` → `commit`, not `tag`): no tagger,
no date, no message. The only timestamp is the commit's own.

### 15.3 Options for the submodule side

The superproject tag tree **is** authoritative and complete — it yields the exact per-submodule SHA for
every component of both releases. So correct tags are *reconstructible*, which gives three options:

- **(a) Force-move the 9 + 3 wrong tags to the correct commits.** Technically easy
  (`git tag -f` + `git push --force origin refs/tags/…`). But moving a **published** tag is the one
  git operation with no clean client story: git does not update an existing tag on fetch, so anyone who
  already has the old one keeps it silently, forever. **Not recommended.**
- **(b) Generate a fresh, correctly-placed set under a new name** — `release/1.0.1`, `release/2.1.0` —
  derived from the superproject tree, as **annotated** tags. Leave the old ones untouched and record in
  this file that `Version_*` in submodules is untrustworthy. Non-destructive, and the historical record
  becomes accurate for the first time.
- **(c) Stop tagging submodules entirely.** Declare the superproject tag the single release record —
  which §4 already established is the only thing that ever worked. Tag one repo per release.

**Recommended: (c), optionally with (b) once** as a one-off historical cleanup. Maintaining 26
consistent tags by hand is precisely the process that has now failed twice; a third attempt will fail
the same way. And per §12.10.3, after the absorb this whole class of problem stops existing: one repo,
one tag, nothing to reconcile and nothing to reconstruct.

For **future** releases: use **annotated** tags (`git tag -a`) so the release carries a tagger, date and
message, and `git describe` prefers them. Note the naming stays odd regardless — `Version_1.0.1` labels
*release candidate 10* (§4) — so a consistent scheme from 2.2.0 onward is worth agreeing separately.

### 15.4 Correction to §11.2

§11.2 recommended leaving `main` at RC10 and fast-forwarding it "at the next real release". Given
§15.1, that was **wrong**: `Version_2.1.0` was a real delivery on `43f8ced`, so "main = last thing
shipped" means `main` belongs at `43f8ced` **now**, not at RC10. Fast-forwarding it is a 29-commit
fast-forward on strictly linear history — no merge, no risk, and it makes both release tags reachable
as a side effect rather than as a task.

Slot this into §11.7 as a step of its own, after the `develop` branches exist:

> **Fast-forward `main` to `Version_2.1.0^{commit}` (`43f8ced`).** Superproject only — do not attempt
> it in the submodules, whose own `main` branches and tags are unreliable (§15.2). `develop` then sits
> 4 commits ahead of `main`, which is the correct steady state.
