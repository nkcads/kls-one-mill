# KLS OneMill — Repo / Branch / Tag Landscape

**Snapshot 2026-07-30**, re-pulled live from Azure DevOps (`cads-team` / `KLS OneMill`, 30 repos,
all branches + tags) and cross-checked against the local clone. Supersedes the 2026-07-29 snapshot;
what changed is listed in §0.

**§1–§10 are observed facts. §11–§13 are proposals, not agreed with anyone yet** — §11 a concrete
`develop`-branch plan meant to be executed, §12 a draft on removing the 26-submodule overhead,
§13 a minimal CI pipeline modelled on `ips-suite2`.

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
`--recursive` gives the right SHAs automatically. `.gitmodules` has **no `branch =` entries**, so
`git submodule update --remote` is meaningless here; the tree is SHA-pinned only.

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
| `git submodule update --remote` is meaningless | no `branch =` in any `.gitmodules` (§1) |
| Tags don't identify anything (`Version_1.0.1` on RC10) | no release branch, so nothing to tag (§4) |
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
  this", which is the only meaning anybody wanted from `Version_2.1.0`.
- **Do *not* fast-forward `main` now.** Switching the ADO *default branch* to `develop` removes the
  misleading-default problem without touching `main`, and `main` keeps its honest meaning ("RC10 is
  the last thing that shipped") until the next real release.
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

**(c) Add `branch = develop` to every `.gitmodules`** — the superproject's *and* the 8 wrapper
modules with a nested backend. This makes `git submodule update --remote` meaningful for the first
time. Follow with `git submodule sync --recursive` on every clone.

**(d) Rewrite `.gitmodules` URLs from SSH to HTTPS** (§2). Removes the local `insteadOf` workaround
every new machine needs, and is a hard prerequisite for CI (§13.4). Same commit as (c).

> **Rule about `--remote`:** use it as a deliberate "pull everyone's latest" action, *then build*,
> *then* commit the gitlink bumps. Never as part of a scripted commit. The pinned SHA stays the record
> of what was tested (§4).

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
- **Pia's 9 live branches** are the only real in-flight work. Decide per branch: land into `develop`
  now, or let her rebase onto `develop` (all but one are in a single repo, so this is cheap). Do
  **not** leave them branched off dead `main` — that is how they got to `-1` behind.

### 11.6 How the three of us work — no PRs, but Robert sees it first

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

### 11.7 Migration order

1. Robert pushes everything outstanding to `version/*` and agrees to stop pushing there. **Blocking.**
2. Run §11.3 step 1+2 — `develop` exists in ~27 places.
3. First `develop` commit: strays removed, `branch = develop` + HTTPS URLs in all 9 `.gitmodules`,
   `.claude/worktrees/` ignored.
4. Merge `SetupBuildEnvOnBeta220` into `develop` — now `develop` builds from a clean clone.
5. ADO defaults → `develop` (§11.4). Everyone: `git submodule sync --recursive`, then re-clone once.
6. Branch hygiene (§11.5), including a decision on each of Pia's 9 live branches.
7. Tag `frozen/Beta220` + `frozen/20Beta`; delete those branches after a month.
8. The three §6 questions are then answered, except "revive or retire `main`", which becomes "keep it
   as the release branch, ff at next release".

Everything except step 1 is reversible. **Do not couple this to §12** — this is the cheap half.

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
Full history preserved, paths rewritten to match, build untouched. Archive the old repos read-only;
tag the last superproject commit first so deployed-build traceability (§4) survives.

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
| 4 | In-flight work | ⚠️ **The only real cost.** Pia's 9 live branches (§7) — `subtree add` does not carry them. Land or close first; a §11.5 task anyway. |

Technical blockers are gone. What remains is #4 (sequencing) and Robert's agreement.

Side effect of #2: with no CI, *"`develop` always builds"* rests entirely on the build-before-you-bump
rule (§11.6). If that keeps getting skipped, the answer is §13 — far easier to write against one repo
than 26.

### 12.8 The one-sentence version

*Repositories are the weakest way to enforce an architecture and the most expensive way to lose
atomicity; the backend/GUI cut and the plugin concept both live in CMake targets and output
directories, and both survive a path-preserving monorepo conversion completely intact — so the
boundaries can be kept, and enforced better, while the 26-repo overhead goes away.*

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
| Preset naming | `<product>-config-<tuple>-<lane>-<config>` | `onemill-config-<tuple>-<config>` (no lane) | `<product>-{config,build,test}-<tuple>[-<lane>]-<config>` |
| Dev-env entry | `.vscode/dev-run.cmd` (fleet-shared) | ✅ byte-identical copy | same, one canonical source |
| Version stamp | `CreateCadsVersion@3` | — | same |
| Triggers | `develop`, `main`, `release/*` | — | same |
| Branch→flavour | main=final, release/\*=beta, develop=alpha | — | same |
| Submodule guard | `check-submodule-downgrade.sh` | — | same script, verbatim |
| Cheap PR gate | separate hosted-agent pipeline | — | same |

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
