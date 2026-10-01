# Code signing — work plan (KOM-20)

Last updated: **2026-10-01**
Status: **Nothing implemented.** Branch `feature/KOM-20-code-signing` created 2026-10-01 from `develop` @ `4243a27`,
which contains KOM-19 and with it the allowlist, KOM-19's first-party manifest ([S2](README.md#shared-items-s1s4)).

> Scope and acceptance criteria are in **[KOM-20](https://cads-team.atlassian.net/browse/KOM-20)**
> ([D7](README.md#decisions)). This plan owns the signing half of **[S3](README.md#shared-items-s1s4)** and the
> access half of **[S4](README.md#shared-items-s1s4)**.

| § | | § | |
| --- | --- | --- | --- |
| [1](#1-findings-sf) | Findings (SF*) | [4](#4-steps-sg0sg7) | Steps SG0–SG7 |
| [2](#2-company-rule) | Company rule | [5](#5-questions-for-kls-martin-it-kq) | Questions for KLS Martin IT (KQ*) |
| [3](#3-the-pipeline-block) | The pipeline block | [6](#6-risks-sr) · [7](#7-extraction-map) | Risks · Extraction map |

---

## 1. Findings (SF)

| ID | Finding | Evidence |
| --- | --- | --- |
| **SF1** | **CADS signs through Azure Trusted Signing**: account `TrustedSigningCads`, certificate profile `CADSGmbH`, endpoint `https://weu.codesigning.azure.net/`, task `TrustedSigning@0` (extension installed org-wide, v0.5.13) | ADO extension list; IPS Suite pipeline 695 |
| **SF2** | **The credentials are in variable group `TrustedSigning-Shared`** (id 145, project IPS Suite, created 2026-07-15 by Markus Hörlendsberger): tenant id, app id, app secret. Shared with IPS Suite only. Same service principal as PDS pipeline 436. **The ids are deliberately not copied here** — the group is the single source | ADO library, 2026-09-29 |
| **SF3** | **It works in production.** `ips-suite-installer-ci` (IPS Suite, definition 695): 58 signed runs, all succeeded, last 2026-09-28. For contrast: PDS `windows-client` (436) 0 signed runs in 111 retained; OSA installer (inSilico, 780) 1; OSP (845) 2 | ADO run history, 2026-09-29 |
| **SF4** | **What is unsigned today.** Install-tree scan (KLSOneMill3, KOM-13, RelWithDebInfo): 507 binaries, 308 signed (ModuleWorks 248, Actipro 33, Qt 19, Microsoft 6, Python 2), **199 unsigned**: 2 OneMill exes, 11 module DLLs, 160 VTK 9.5, 26 PyPy stubs and `.pyd`. First-party allowlist: **13 on KOM-13, 12 on `develop`** ([VF11](Workplan-Version.md#1-what-onemill-has-today)), plus the MSI later | `Get-AuthenticodeSignature` over the tree, 2026-09-29 (measured) |
| **SF5** | **Certificates live about three days.** Every signature must be timestamped, and allow rules at KLS Martin must target the **publisher** (or, for WDAC, Trusted Signing's durable identity EKU) — **never the certificate thumbprint**, which changes every few days | Trusted Signing documentation; OSA playbook |
| **SF6** | **Pipeline 436's `signCertFile` / `signContainerName` / `signTokenPassword` / `signToolPath` are leftovers** of the old hardware-token signing, unused by its YAML. Do not copy them | 436's YAML vs its variables |
| **SF7** | **Signing is quota-bound**: roughly 14 signatures per signed run (13 binaries + MSI later). Signing only on demand (`buildSigned`) keeps within the account's quota | KOM-20 notes |
| **SF8** | **Still unknown: what KLS Martin colleagues actually see** — SmartScreen, AppLocker with exe rules only, or AppLocker/WDAC with DLL rules. It decides whether the first-party allowlist is enough or third-party DLLs (VTK, PyPy) must be signed too — [KQ1](#5-questions-for-kls-martin-it-kq) | — |

## 2. Company rule

From the OSA installer playbook (`docs/installer-and-pipeline-playbook.md` §7.3.3 / §10):

- **Explicit allowlist, no wildcard signing.** IPS signs exactly three files (`suite-app.exe`,
  `cads_qml_lib.dll`, `CADSQmlLib\cads_qml_libplugin.dll`).
- **Order:** resolve files → validate secrets → sign binaries → build MSI → sign MSI.

OneMill's allowlist is KOM-19's manifest, so a new module joins it by being staged, not by editing a list here.

## 3. The pipeline block

Inline in [onemill-build-windows.yml](../../../pipelines/onemill-build-windows.yml), one contiguous block
between *Verify the staged tree is complete* ([:408-462](../../../pipelines/onemill-build-windows.yml#L408-L462))
and *Package the staged tree* ([:464-491](../../../pipelines/onemill-build-windows.yml#L464-L491)) — no
template ([D5](README.md#decisions)). Every step is conditional on `buildSigned`.

```
Verify staged tree           (exists)
  ├─ Resolve files           manifest → absolute paths; fail on a missing or empty list
  ├─ Validate secrets        the three group variables are set; fail with the variable name
  ├─ Sign                    TrustedSigning@0, the resolved list, SHA256, RFC 3161 timestamp
  └─ Verify signatures       every manifest entry: Valid, signer CADS GmbH, timestamped
Package                      (exists)
```

Inputs for `TrustedSigning@0` are taken from pipeline 695, the one with the track record ([SF3](#1-findings-sf)),
not written from the task documentation.

## 4. Steps SG0–SG7

| ID | Step | Exit criterion | Status |
| --- | --- | --- | --- |
| **SG0** | **Access** ([S4](README.md#shared-items-s1s4)) — `TrustedSigning-Shared` shared with project KLS OneMill and authorised for pipeline 824 | The group appears in KLS OneMill's library and 824 may use it | 🟡 **request sent to IT, no answer yet** (2026-09-30) |
| **SG1** | **`buildSigned` parameter**, default `false`, following IPS | An unsigned run is byte-for-byte the pipeline it was | 🟡 **implemented 2026-10-01, not yet run.** The variable group is referenced only inside `${{ if eq(parameters.buildSigned, true) }}` at job level, so an unsigned run never needs access to it. Pipeline preview (expansion only): the unsigned expansion differs from `develop` only by the parameter declaration and the artifact-name line, whose `iif` yields an empty string |
| **SG2** | **Resolve files + validate secrets** | A signed run with an empty manifest or an unset secret fails with a message naming it | 🟡 **implemented 2026-10-01, not yet run** — `SIGN 1/4` resolves the manifest against the staged tree and fails on an empty or missing manifest or a listed file that is absent; `SIGN 2/4` fails naming each missing credential (an undefined variable arrives as its literal macro text and counts as missing) |
| **SG3** | **Sign** with `TrustedSigning@0` | The run log lists exactly the manifest's files, nothing else | ⬜ needs SG0, and the task inputs from a pipeline that already signs (IPS Suite installer CI, definition 695). A placeholder comment marks the slot between `SIGN 2/4` and `SIGN 4/4` |
| **SG4** | **Verify** — any unsigned first-party binary fails the build; `MainApp.exe` must be signed by *CADS GmbH* and timestamped | A deliberately skipped file fails the run | 🟡 **implemented 2026-10-01, not yet run** — `SIGN 4/4` checks every manifest file: status `Valid`, signer subject `CN=CADS GmbH`, timestamp present. **The subject is an assumption** until a CADS Trusted Signing signature has been read (none installed on this PC) |
| **SG5** | **Artifact identity** — a signed artifact is distinguishable from an unsigned one by name | Name carries the version from KOM-19 and a signed marker | 🟡 **implemented 2026-10-01** — `KLSOneMill-<version>-relwithdebinfo-signed.zip` in a signed run, unchanged otherwise |
| **SG6** | **Field test at KLS Martin** — a colleague starts a signed build on a managed machine; the error before and after is recorded here verbatim ([KQ1](#5-questions-for-kls-martin-it-kq)) | OneMill starts, every module loads | ⬜ |
| **SG7** | **KLSOneAnalyse** — the same block for its deployment, once CI builds it. Depends on [VF7](Workplan-Version.md#1-what-onemill-has-today) (`install_fitting` broken on `develop`; already fixed on KOM-13, arrives with V8) | A signed KLSOneAnalyse artifact | ⬜ |

## 5. Questions for KLS Martin IT (KQ)

| ID | Question | Why it matters |
| --- | --- | --- |
| **KQ1** | **What exactly blocks OneMill today** — SmartScreen, AppLocker, WDAC? The exact message or event log entry | Decides whether [SF4](#1-findings-sf)'s first-party allowlist suffices |
| **KQ2** | Are **DLL rules** enforced, or only executables? | If DLLs are checked, the 160 VTK and 26 PyPy binaries become our problem |
| **KQ3** | Can the rule be a **publisher rule** on *CADS GmbH* (and ProductName `KLSOneMill`, [VQ1](Workplan-Version.md#6-open-points-vq))? | A thumbprint rule would break within three days ([SF5](#1-findings-sf)) |
| **KQ4** | **Who owns the policy** at KLS Martin, and how is a rule change requested? | So SG6 is not the first time they hear of it |

## 6. Risks (SR)

| ID | Risk | Mitigation |
| --- | --- | --- |
| **SR1** | **KLS Martin enforces DLL rules** ([KQ2](#5-questions-for-kls-martin-it-kq)) and first-party signing is not enough | Ask before SG6. Signing VTK/PyPy ourselves is possible (Authenticode is per file) but means signing third-party code as CADS — a decision, not a default |
| **SR2** | **The variable-group share stalls** ([SG0](#4-steps-sg0sg7)) | Everything except SG3 and SG6 can be built and tested without it |
| **SR3** | **Quota** — signing on every run would burn it | `buildSigned` defaults to `false`; sign only runs meant for delivery |

## 7. Extraction map

| From | To |
| --- | --- |
| [SF5](#1-findings-sf) (publisher rule, never the thumbprint) | The delivery notes handed to KLS Martin IT, and one comment at the verification step |
| [§2](#2-company-rule) (allowlist, order) | A comment at the signing block, citing the playbook |
| KQ answers | This plan until SG6 closes; then the delivery notes |
| Everything else | Stays here; deleted at merge |
