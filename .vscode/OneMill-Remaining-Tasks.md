# OneMill — what is still outstanding

**Rewritten 2026-08-13, after KOM-12 (CI) shipped. This is the live list — the single place to look
for "what is left".** Superseded content about the 2026-08 reorganisation is in
[`OneMill-Migration-2026-08.md`](OneMill-Migration-2026-08.md); that work is done.

This file is **tracked** deliberately. An earlier version lived only in one laptop's gitignored
`.vscode/`, which meant the project's outstanding-work list was invisible to everyone else and one
disk failure from gone.

Ordered by **who has to act**, because the blocker is usually a person and not effort.

---

## A. Waiting on Robert — nothing else can close these

| # | | Why it needs him |
|---|---|---|
| **A1** | **Branch policies on `develop`** | Requiring a PR + reviewer on the superproject's `develop` stops him pushing directly, so it cannot be switched on unilaterally. Note the ADO mechanic: **any** enabled branch policy makes a branch PR-only, so squash-protection and PR-enforcement are one decision, not two. Message was sent 2026-08-05; unanswered. |
| **A2** | **ModuleWorks licence rotation** | `mwSupport.lic` expires and nothing tracks it. The SDK holds `mwSupport.lic` beside `mwSupport.lic_OLD`, so renewal replaces in place. When it lapses, **every build silently produces an artifact that fails at runtime** — configure only checks `EXISTS`, never validity. Ask how he manages this and whether an expiry check belongs in CI. |
| **A3** | **Attach both pipelines as build validation on `develop`** | Blocked by A1: attaching a policy *is* making `develop` PR-only. Both pipelines are ready and green. |

## B. Waiting on other people

| # | | Owner |
|---|---|---|
| **B1** | **~71 unmerged commits across 9 feature branches.** Wladislaw authored 7 of 9 and nothing since 2025-12-04; if he is off the project that work has no owner. Pia's `undercutChecker` (2026-01-22) and `CenterSplineLogic` are the most recent and most likely still wanted. Full audit, including which branches span two repos and would orphan each other: [`OneMill-Unmerged-Work.md`](OneMill-Unmerged-Work.md) | Martin to raise; Pia + whoever owns Wladislaw's work to decide |
| **B2** | **Bake an AMI from the provisioned agent.** Provisioning was done by hand over RDP and is currently reproducible only from documentation. If the instance is lost, it is a manual redo. Note a cloned agent registers under the same name and will collide — ask Julian how `suite-aws-pool` handles that. | Julian |

## C. Mine, small, no dependencies

| # | | Note |
|---|---|---|
| **C1** | **Retire pipeline 822 `KLS OneMill`** | Orphaned: its `azure-pipelines.yml` went with the deleted branch. Deleting the definition also deletes its run history, including build 1859871 — the first successful EC2 start/stop test. That is the only reason to hesitate. |
| **C2** | **Zip entries carry a `./` prefix** | From `tar -C <staged> .`. Harmless — Explorer, 7-Zip and .NET all normalise it, verified by extracting and launching — but Robert's zips have clean entries. One-line fix, fold into the next pipeline change rather than spending an EC2 cycle on cosmetics. |
| **C3** | **Retire `KLSOneMillRepoCleanup` and `C:/DATA/sandbox/onemill/`** | The rehearsal clone. Points at a dead local bare remote; the rehearsal it existed for succeeded. |
| **C4** | **Resolve the staged-tree count differences** | CI stages **6601 files / 1771 MB / 58 files per `deps/`**; the dev box has **6626 / 1994 MB / 72**. The ledger says **58 is correct** (57 ModuleWorks DLLs + `mwSupport.lic`), so the dev box is likely carrying drift from months of incremental installs — but that is inference. Related: configure reports **40** install targets on the agent vs **41** locally, and 166 vs 171 runtime DLLs. The CI tree launched and ran, so nothing is broken; worth understanding before trusting counts as a regression signal. |

## D. Next real CI work

| # | | Note |
|---|---|---|
| **D1** | **Wire `om_integrationtest_highlevel` into the build** | This is the whole of the **D7** conformance gap. The suite already exists and is written to be `add_subdirectory()`'d from a superproject — dispatcher routing, the `ModuleInterface` plugin contract, deployment integrity. Turns CI from "it compiles and installs" into "the plugin contract holds". Needs coordinating with Shpetim, whose repo it is. |
| **D2** | **Decide whether the Windows build should gate `develop`** | It currently has `trigger: none` because it starts a billable EC2 instance. Options: leave manual, trigger on PR only, or nightly. Depends on A1/A3. |
| **D3** | **VS toolset alignment** | Agent MSVC `14.50.35717` vs dev box `14.51.36231`. Builds fine on both. Not worth acting on until it actually causes a difference — noted so nobody rediscovers it as a mystery. |

## E. Deferred by decision — not forgotten, just not now

| # | | Note |
|---|---|---|
| **E1** | **§12 submodule absorb** — collapse 26 submodules, starting with the 8 nested `*Backend` repos | The three-level gitlink chain is a genuine recurring cost; it cost three ordered commits during KOM-12 alone. §12.9 of [`OneMill-Repo-Landscape.md`](OneMill-Repo-Landscape.md) proves the round trip is reversible on real history. §12.10 says do it as the first real change *on* `develop` if revisited. |
| **E2** | **Delete `version/Beta220` and `version/20Beta`** | Frozen and tagged `frozen/*`, so nothing is lost. Wait until nobody misses them; needs `ForcePush`, which is granted-then-revoked per use. |
| **E3** | **Normalise the `main` reviewer policy across repos** | Only 9 of 30 have it. Since §15.4 says never fast-forward submodule `main`, those are inert markers — tidiness, not safety. |
| **E4** | **The 4 remaining untracked docs** | `OneMill-Migration-Plan.md`, `OneMill-Sandbox-Rehearsal.md` (both superseded by the migration archive — candidates for deletion), `VHF-Machine-Research.md` and `KOM-MachineSim-Ticket-Draft.md` (in KLSOneMill3). Each exists on one laptop only. Decide per document: promote to tracked, or accept as scratch. |
| **E5** | **`.gitattributes` per submodule** | The superproject's does not apply inside submodules and none of the 26 has one. A 26-repo change; own decision. The encoding hazard that caused the one real merge conflict (an editor writing CP1252 into a UTF-8 file) is a charset problem `.gitattributes` does **not** solve — `.editorconfig charset = utf-8` would. |

## F. Separate workstream — KOM-13 (machine simulation, `KLSOneMill3`)

| # | | Note |
|---|---|---|
| **F1** | **`DesignRules.md` placement** | An in-flight rename files it under `KOM-13-MachineSimulation/`. It is **not** KOM-13 content: 276 lines of general engineering rules extracted from the CADS Superbuild corpus, with stable IDs `A1`…`J5` meant to be cited from commit messages and reviews across the product, and only 5 mentions of simulation/machine/KOM-13 in the whole file. Burying it inside one ticket's folder breaks the citation premise and makes it read as retired when KOM-13 closes. Proposal: root or a `docs/` folder. Its relationship to [`OneMill-Fleet-Conformance.md`](OneMill-Fleet-Conformance.md) also needs deciding — both answer "which CADS rules do we follow", one by extracting rules and one by recording verdicts. |
| **F2** | **Rebase KOM-13 onto the new `develop`** | Trivial in principle — KOM-13 only *adds* two files, so there is no content conflict with KOM-12. But `KLSOneMill3` has three uncommitted changes including F1's rename, so its own work has to be settled first. |

---

## Closed since the previous version of this file

Everything under the old headings A (branch/tag reorg), B (ADO settings) and C (CI) is done:
`develop` live and default in 27 repos, `main` fast-forwarded and protected with merge-commit-only,
`release/*` tags reconstructed, 60 stale branches deleted, guard pipeline green and its failure path
proven, Windows build pipeline producing a downloadable artifact that has been launched and run, and
the agent provisioned with all five external dependencies. Details and the findings that cost time:
[`OneMill-Migration-2026-08.md`](OneMill-Migration-2026-08.md).
