# OneMill — KOM-16, the guard's blind spots

**Status: planned, not started.** Workplan for
[KOM-16](https://cads-team.atlassian.net/browse/KOM-16). Six changes to
`pipelines/scripts/check-submodule-downgrade.sh` (pipeline **819**, `onemill-guard`).

**How to read this file.** The per-item symptom, evidence and patch live in the ticket and are not
repeated here — one copy, and it is the one people work from. This file records what outlives the
ticket: the order the changes should land in, the constraints measured while designing them, and the
repo-side work that is not in the script.

---

## 1. Why — the 2026-09-11 squash incident

Submodule PRs 33394–33398 and 33443–33446 were completed with **squash**. Each squash is a new
commit with a new SHA, so the gitlinks the superproject recorded stopped being ancestors of their
submodules' `develop`. The pointers moved sideways on **two levels**, and 11 submodule commits ended
up reachable from no branch at all — the §5 stray-gitlink class, exactly as
[`OneMill-Setup-Ledger.md`](OneMill-Setup-Ledger.md) predicted on 2026-07-30.

| | |
|---|---|
| Content lost | **none** — every affected pair had byte-identical trees |
| Repaired | 2026-09-15, `develop` `85d99b7` → `10ba0f4` (`c84c493`, `726127e`, `10ba0f4`) |
| Rescued | `archive/VHFTitanMilling-preSquash` in 11 submodule repos |
| Caught by | a **local** guard run, four days late |
| Caught by CI | no — and it could not have been |

The last row is the reason this ticket exists. On a push to `develop` the guard compares HEAD against
itself, so every pointer matches and the run always passes. Three places in these docs cite a green
guard as evidence of health; on `develop` that evidence is vacuous.

## 2. Order to land them

Priority by **damage prevented** is G3 → G1 → G2 → G5 → G4 → G6. Priority by **what makes the work
tractable** is close to the reverse, so the plan starts with the cheap enabler.

| Step | Items | Why here |
|---|---|---|
| **0** | Offline test suite — **done 2026-09-16** | `pipelines/scripts/tests/`. Every later step now has a failing case waiting for it, so "implemented" means something |
| **1** | G6 — `GUARD_BASE` / `GUARD_HEAD` replay — **done 2026-09-16** | No behaviour change. The four rows in the ticket are now executable: `0f3b0f8`→`85d99b7` reproduces the incident as 11 × DIVERGED, `85d99b7`→`c84c493` as 4 forward + 4 nested, `85d99b7`→`10ba0f4` as `OK` |
| **2** | G2 — `REWRITTEN` vs `DIVERGED`, G5 — trailer scope bug — **done 2026-09-16** | The incident replay now reads 11 × `REWRITTEN` instead of 11 × `DIVERGED`, and the remedy printed is the merge that restores ancestry rather than a checkout that would move the pointer backwards |
| **3** | G7 — empty submodule dir, G8 — never pass having inspected nothing — **done 2026-09-16** | Both found by the suite on its first run, see §3. G7 now probes with `--show-prefix`, which is empty only at a repository root; G8 compares the number of gitlinks inspected against the count declared in the root `.gitmodules` |
| **4** | G3 — reject pins on no branch | Run **warn-only across all branches once** before it may block, so the size of the existing problem is known before it starts failing builds |
| **5** | G1 — real base on `develop` | Changes when the guard runs meaningfully. Needs the Build-API route below, not a marker ref |
| **6** | G4 — hard fail for pins off `develop` | Depends on G1: without a real base there is no develop run to fail. Needs the exemption below |

Verification is the suite in §3, not the replay table in the ticket. That table stays useful as a
record of the incident, but it reads live ADO state and one of its rows has already stopped
reproducing: the rescue branches made the orphaned commits reachable again.

## 3. The test suite

`pipelines/scripts/tests/run-guard-tests.sh`, 13 cases, no network, no credentials, no ADO — seconds
per run. Each case builds throwaway repositories under a temp dir, publishes them to bare remotes
reachable by `file://`, and runs the **unmodified** guard against them, so it exercises the real
fetch, the real clone-by-URL and the real ancestry questions.

A case may carry `PENDING=<item>`, meaning *this is the behaviour that item introduces and the guard
is expected to fail it today*. The suite therefore stays green while the work is outstanding, and
landing an item is "delete one `PENDING` line and watch it go green". A `PENDING` case that starts
passing is reported as **UNEXPECTED PASS** and fails the run, so a marker cannot rot.

Current state: **10 passed, 3 pending, 0 failed**. The three remaining encode G1, G3 and G4.

Two things the suite established on its first run, neither of which anyone was looking for:

| | |
|---|---|
| **G7** | `git -C <empty-dir> rev-parse --git-dir` **walks up** and answers with the parent repository, so an uninitialised submodule directory passes the guard's local-working-copy probe. It then compares the superproject against itself and reports `endpoints missing`. CI is spared only by accident: `fetchDepth: 1` makes the checkout shallow, the second half of the condition fails, and the clone path is taken. Any developer cloning without `--recursive` gets a false failure |
| **G8** | `<no submodules found>` leaves `fail=0`, so the guard **exits 0 having inspected nothing**. With `set -uo pipefail` and no `-e`, an unexpected mid-run failure does the same. A guard's worst outcome is not a false alarm — it is a green light it did not earn |

It also demonstrates the blind spot rather than asserting it. `push_to_develop_is_checked` prints
`source a8759d57 vs branch-point a8759d57` and then `OK`, and `orphan_pin` prints `^ sub (forward)`
for a pin that exists on no branch anywhere.

The suite runs as a step in `onemill-guard.yml` ahead of the real check, currently with
`continueOnError: true` because it has not yet run on a hosted Linux agent. Delete that line once it
has passed there once.

## 4. Constraints measured 2026-09-15

Read-only against `cads-team/KLS OneMill`, with a user token. **Measured, not inferred** — but not yet
with `SYSTEM_ACCESSTOKEN`; one CI run settles that.

| | |
|---|---|
| **The build identity cannot push** | `effectiveAllow=34` = `GenericRead`(2) + `CreateTag`(32). No `GenericContribute`(4), no `ForcePush`(8). CI can persist **no state in git** — no marker refs, no bookkeeping branches. Measured on the 26 submodule repos; the superproject repo's ACL was not part of that measurement |
| Containment without cloning | `diffs/commits` → `aheadCount == 0` ⟺ contained. **26 pins in 2.3 s** (8 parallel) |
| Gitlinks without cloning | `trees/{treeId}?recursive=true` → every gitlink with path and objectId. Full two-level walk **26/26 identical to `git ls-tree`, 1.9 s, 35 calls**. No truncation at 807 entries |
| Tree identity without cloning | `commits/{sha}` → `treeId` and `parents[]` |
| **Trap** | `changes` in the diffs response is anchored at `commonCommit`, **not** a base→target diff: it reports 53 changed files for two commits whose tree is identically `a22cb8d6`. Use `treeId` |
| **Exemption, mandatory** | `GeneralUtils/OpenXLSX` is vendored, pinned on `main` at release 2.1.0, and has **no `develop` branch**. G4 fails every run without an explicit exemption list |

This makes a clone-free `develop` path possible. It also sidesteps every shallow-clone problem the
script's header documents at length, because there is no clone to be shallow.

## 5. Repo-side work that is not in the script

| | |
|---|---|
| Qualify the "guard green" claims | [`OneMill-Migration-2026-08.md`](OneMill-Migration-2026-08.md) §1, [`OneMill-Repo-Landscape.md`](OneMill-Repo-Landscape.md) §13, [`OneMill-Remaining-Tasks.md`](OneMill-Remaining-Tasks.md) *Closed since the previous version* — all three read as a guarantee that does not hold on `develop` |
| Record what the guard **cannot** detect | in the script header, beside the design rationale it already carries |
| Record the `archive/*` convention | 11 branches named `archive/VHFTitanMilling-preSquash`. The last stale-branch sweep deleted 60 fully-merged branches; the next one would delete these |
| Record the incident | as a dated entry in [`OneMill-Setup-Ledger.md`](OneMill-Setup-Ledger.md), alongside the 2026-07-30 decision that predicted it |
| Strengthen the squash verdict | [`OneMill-Fleet-Conformance.md`](OneMill-Fleet-Conformance.md) row *Squash as the `develop` merge strategy* argues theoretically; it can now cite a dated incident with numbers |

## 6. Relationship to A1

[`OneMill-Remaining-Tasks.md`](OneMill-Remaining-Tasks.md) **A1** — a merge-strategy policy on
`develop` — prevents the **cause**. KOM-16 catches it when prevention is absent or bypassed. Neither
replaces the other, and A1 has been unanswered since 2026-08-05. Note that a policy constrains the
ADO completion dialog only: a local `git merge --squash` followed by a direct push produces the same
damage and nothing server-side can refuse it. That half is the guard's job permanently.

## 7. Do not change

Submodules are deliberately **not** checked out — a `--depth=1` checkout cannot answer ancestry, ADO
refuses `--deepen`, and `--unshallow` no-ops once a blob-filtered fetch has made the clone partial.
The recursion into parents that moved forward is what caught the four nested backends on 2026-09-15;
a root-only guard reports them as `^ forward` and passes.
