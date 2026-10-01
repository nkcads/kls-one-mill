# KOM-18 — OneMill delivery: product version, code signing, installer

> **State:** live · **Started:** 2026-09-29 · **Epic:** [KOM-18](https://cads-team.atlassian.net/browse/KOM-18)
> **Scope:** bring OneMill onto the delivery model every other CADS product already uses — a real product
> version from `CreateCadsVersion`, Azure Trusted Signing, a WiX MSI. Superproject only, as far as it goes.

The tickets are the contract; these documents are the workbench. Scope and acceptance criteria live in
KOM-18 … KOM-22 and are **not** restated here ([D7](#decisions)).

## The stories

| Story | What | When | Branch | Work plan |
| --- | --- | --- | --- | --- |
| [KOM-19](https://cads-team.atlassian.net/browse/KOM-19) | Product version: company scheme, stamped into every first-party binary | **now** | `feature/KOM-19-version-scheme` (from `develop` @ `3d14ab2`, no upstream) | [Workplan-Version.md](Workplan-Version.md) |
| [KOM-20](https://cads-team.atlassian.net/browse/KOM-20) | Sign the first-party binaries with Azure Trusted Signing | **now** | `feature/KOM-20-code-signing` (from KOM-19's branch) — not yet created | [Workplan-Signing.md](Workplan-Signing.md) |
| [KOM-21](https://cads-team.atlassian.net/browse/KOM-21) | WiX 6 MSI for KLSOneMill and KLSOneAnalyse | later | — | [Workplan-Installer.md](Workplan-Installer.md) (parked) |
| [KOM-22](https://cads-team.atlassian.net/browse/KOM-22) | Separately deliverable modules | follow-up, no date — questioned by [D2](#decisions) | — | [Workplan-Installer.md §4](Workplan-Installer.md#4-module-delivery-i1i4) |

**Order.** KOM-19 → KOM-20 → KOM-21. Each of KOM-19 and KOM-20 is merged into
`feature/KOM-13-machine-simulation` as soon as it lands, not batched ([D4](#decisions)): KOM-13's internal
testers need signed builds.

## Current state — 2026-10-01

| What | State |
| --- | --- |
| KOM-19 | **V0–V7 done.** Version from git, VERSIONINFO in all 13 binaries, version in `mainAppConfig.json`, first-party manifest — tested on KLSOneMill4 and in pipeline 824 ([run 1900118](https://dev.azure.com/cads-team/KLS%20OneMill/_build/results?buildId=1900118), green, `2.2.0.66-KOM-19-version-scheme`). Branch pushed to `origin/feature/KOM-19-version-scheme`. **Open: V8**, the merge into KOM-13 — [Workplan-Version.md §5](Workplan-Version.md#5-steps-v0v8) |
| KOM-20 | Branch not created. Blocked on [S4](#shared-items-s1s4) for a real signed run; the pipeline block can be written before that |
| Tags `v1.0.1` (`a5ca137`) and `v2.1.0` (`43f8ced`) | Created 2026-09-30 (annotated), **pushed 2026-10-01** |
| Variable group `TrustedSigning-Shared` | Request to IT / an IPS Suite admin **sent**, **no answer yet** (as of 2026-09-30) |
| Questions for Robert | Posted on [KOM-9](https://cads-team.atlassian.net/browse/KOM-9) (comment 92960) on 2026-09-29. RQ9 and RQ3 settled; follow-up posted 2026-09-30 (comment 93179) — see [below](#questions-for-robert-rq1rq9) |
| Robert's answer — 2026-10-01 | Comment 93339: only skimmed it; asks that the decisions take **FixtureX** into account, which is to come into OneMill as a module. Martin replied (93349): KOM-19 and KOM-20 now; KOM-21 and KOM-22 are ideas still to be discussed in detail. Martin also posted the statistics-format note (93347, [VF13](Workplan-Version.md#1-what-onemill-has-today)). **FixtureX is not yet reflected in any decision here** — it matters for D2 and KOM-22 if it has its own team or release cycle. A first survey (2026-10-01) found that `Modules/ModuleFixture` is already the port of FixtureX into OneMill; Martin sees, at first glance, no conflict with the new versioning (KOM-19) or signing (KOM-20) — a ported module gets both automatically |
| Build and deploy trees of this clone | Wiped 2026-09-30, rebuilt fresh on this branch 2026-09-30 / 10-01 (`MODULEWORKS_DIR` → `ModuleWorksSdk-2026-08-3-0`) |

## Shared items (S1–S4)

Things more than one story consumes. Each has one owner story; the others depend on it.

| ID | Item | Owner | Consumed by | State |
| --- | --- | --- | --- | --- |
| **S1** | **Version source** — one product version, computed from git locally and taken from `Build.BuildNumber` in CI | KOM-19 | KOM-20 (VERSIONINFO for publisher rules), KOM-21 (MSI `ProductVersion`) | ✅ 2026-10-01 — `cmake/OneMillVersion.cmake` |
| **S2** | **First-party manifest** — the list of binaries we build, generated where `install_full` stages | KOM-19 | KOM-20 (the signing allowlist), KOM-21 (what the installer must find signed) | ✅ 2026-10-01 — `<build>/first-party/<product>.txt` |
| **S3** | **Pipeline 824 changes** — full fetch + tags, `CreateCadsVersion@3`, `buildSigned`, lane, artifact name | KOM-19 (version half), KOM-20 (signing half) | all | 🟡 version half ✅ 2026-10-01; signing half open |
| **S4** | **Access and agent** — variable-group share and pipeline authorisation; GitVersion on the EC2 agent; later the .NET SDK for WiX | KOM-20 (share), KOM-19 (GitVersion), KOM-21 (.NET) | all | 🟡 GitVersion on the agent ✅ (run 1900118); share requested, unanswered |

## Decisions

| ID | Decision | Why |
| --- | --- | --- |
| **D1** | **OneMill adopts the company version convention**: tags `vX.Y.Z`, branches `release/vX.Y.Z` / `hotfix/vX.Y.Z`, the version from `CreateCadsVersion` (GitVersion, default configuration). The old tags (`Version_*`, `release/*`, `frozen/*`) stay as history; no new ones of that kind. *Decided 2026-09-30.* | Every other CADS product does this ([Workplan-Version.md §2](Workplan-Version.md#2-company-practice)); OneMill is the only outlier. This settles RQ9 |
| **D2** | **One product version for every first-party binary.** No independent component or module versions. *Decided by Martin, 2026-09-30.* | **OneMill is validated as a whole at each KLS Martin site before it may mill real patient implants.** A validated state is one complete build; a separately versioned or updated part is an unvalidated combination. Also company practice — the Suite stamps one version into all its binaries. This settles RQ3, and it narrows RQ1/RQ2/RQ4/RQ5 (updater) and RQ6/RQ7 (KOM-22) — see [Workplan-Installer.md](Workplan-Installer.md) |
| **D3** | **The installer is per-machine**, plus a side-by-side *Preview* product for alpha/beta lanes | Company default (IPS Suite, OSA); per-user only where justified (CloudDrive). Preview lets testers run a release and a KOM-13 build side by side |
| **D4** | **KOM-19 and KOM-20 branch from `develop`, touch the superproject only, and merge into KOM-13 as soon as each lands** | KOM-13's testers need signed builds; small, early merges keep the certain conflicts small ([Workplan-Version.md §4](Workplan-Version.md#4-merge-surface-with-kom-13)) |
| **D5** | **New files only for self-contained topics** (`cmake/OneMillVersion.cmake`, `cmake/VersionInfo.rc.in`); everything else is small edits in existing files. **No pipeline template** — the signing block goes inline | KOM-13 has changed exactly the files this work touches |
| **D6** | **KOM-13 tester builds read `2.2.0.<n>-KOM-13-machine-simulation`.** Machine simulation ships in 2.2.0 at the earliest, probably later. All tester deliveries are internal | Follows from D1 with GitVersion's default feature-branch label |
| **D7** | **The tickets are the authoritative scope. These documents do not restate it** | Two documents that both define scope will disagree, and the one people read is the ticket |
| **D8** | **Only this folder is created on the KOM-19 branch.** `Docs/README.md` and `Docs/Reference/` exist only on the KOM-13 branch; creating them here would be an add/add conflict. The index entry under *Projects — live* and the shared-ModuleWorks-`deps/` open task are added **on the KOM-13 side**, as part of the first merge. *Agreed 2026-09-30* | `develop` has no `Docs/` folder at all |

## Questions for Robert (RQ1–RQ9)

Posted on KOM-9 on 2026-09-29. Status as of 2026-09-30.

| ID | Question | Blocks | Status |
| --- | --- | --- | --- |
| **RQ9** | Agreement to the company scheme (tags, `release/vX.Y.Z`, no install counter, title `2.2.0.<n>-alpha`); it changes his release routine (`KLSOneMillFullVersion_210_Beta4`, `Beta220`) | KOM-19 merge to `develop` | ✅ **settled ([D1](#decisions))** — no longer blocking |
| **RQ3** | Were the component versions in the ModuleUpdater README (`2026.07.20`) meant to be independent of the product version? | KOM-19 | ✅ **settled: one version ([D2](#decisions))** |
| **RQ1** | Is the updater used productively anywhere (server, filled `updateConfig.json`)? | KOM-21 | ⬜ open — **the one updater question that still matters**: if it is live somewhere, disabling it (U1) breaks that |
| **RQ2** | Intended use: code hotfixes or configuration changes? | KOM-21 | ⬜ open — informational after D2; code hotfixes of single components contradict D2 |
| **RQ4** | OK to disable it in MSI builds (U1)? | KOM-21 | ⬜ open — D2 is a strong argument for U1 |
| **RQ5** | Any plan for an update server? | KOM-21 | ⬜ open — informational |
| **RQ6** | Plans to ship single modules? Which, how today? | KOM-22 | ⬜ open — D2 makes independent module delivery questionable |
| **RQ7** | OK with a versioned IID? | KOM-22 | ⬜ open — worthwhile regardless of KOM-22: it turns a crash into a clean refusal |
| **RQ8** | A concrete case for different ModuleWorks versions per module? Aware of one-DLL-per-name? | open task | ⬜ open — moot under D2 in addition to being impossible in one process |

## Conventions that matter

- **Cite findings, steps and decisions by ID** (`VF…`, `V…`, `SF…`, `SG…`, `IF…`, `D…`, `S…`, `RQ…`), do not
  re-derive them. IDs are stable; a retired number is not reused.
- **No ledger IDs in source comments.** They belong here and in commit messages; a comment must stand on
  its own and say *why*.
- **Conversation in German, every artefact in English** — docs, commits, code, Jira.
- **Foreign sources are cited, not copied** — `ips-suite`, `ips-s-installers`, `release-manager`,
  `cads-versionator`, the OSA installer playbook, pipelines 436 / 695 / 738 / 780 / 845.
- Nothing here is authoritative once extracted. Each work plan ends with an extraction map; at merge the
  durable facts move to where they belong and the work plans are deleted.

## Related, but not here

- **Machine simulation** — [KOM-13](https://cads-team.atlassian.net/browse/KOM-13); its documents live on
  `feature/KOM-13-machine-simulation` under `Docs/Projects/KOM-13-machine-simulation/`, not on this branch.
- **The Windows pipeline itself** — [pipelines/onemill-build-windows.yml](../../../pipelines/onemill-build-windows.yml)
  (definition 824), whose header comment records how it came to be.
