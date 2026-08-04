# OneMill ↔ CADS fleet build rules

Which rules from the CADS Superbuild specification OneMill follows, which it deliberately does not,
and where each adopted rule is enforced in this repository.

## Upstream and pin

| | |
| --- | --- |
| Repository | `https://dev.azure.com/cads-team/CADS Libraries/_git/SuperbuildEngine` |
| Reviewed at | **`d6b4a31363d88c0ca644e80f056d02c932e613b0`** (2026-07-27, *"Fix dev-run.cmd cmd.exe parsing bug and standardize local dev setup"*) |
| Reviewed on | 2026-07-30 |

Commit-pinned deep links resolve to the text actually reviewed, not to a moving HEAD — e.g.
[`OnboardingCrosscheck.md@d6b4a31`](https://dev.azure.com/cads-team/CADS%20Libraries/_git/SuperbuildEngine?path=/specification/OnboardingCrosscheck.md&version=GCd6b4a31363d88c0ca644e80f056d02c932e613b0).

## How to read this file

**It records verdicts, never rule content.** The moment it restates what a rule says, this repo owns
a second copy that drifts silently. Each row is: rule ID → verdict → why → where it is enforced
*here*. When upstream moves, bump the SHA above and re-review only the rows whose rule text changed.

## Scope: which part of the specification applies

OneMill is **not** a superbuild. It is a single CMake project with submodules, not a chain of
separately-built-and-installed layers. The upstream document already carries the seam this needs:
`OnboardingCrosscheck.md` section **D is titled "Universal invariants"**, while sections **A, B and
C are engine onboarding** (adding a layer, porting a product, fleet-wide engine changes).

**OneMill claims conformance to section D plus specification §2 (Principles) and §10 (Error-handling
policy), with the exceptions below. It claims nothing about A/B/C.** Concretely, OneMill does not
mount `SuperbuildEngine/`, has no `SuperbuildManifest*.cmake`, no layers, no markers, no
`PROVIDER=prebuilt`. There is intentionally no `SuperbuildEngine/` submodule here: upstream **B1**
defines that mount as the marker that a product *is* onboarded onto the engine, so mounting it
without a manifest would signal something false.

## Verdicts — section D

| Rule | Verdict | Rationale and enforcement point |
| --- | --- | --- |
| **D1** no ad-hoc orchestration | **Adapted** | For a single project the non-ad-hoc place for build order is the CMake graph, not a manifest or a script. Enforced by the `install_full` dependency walk at the end of [`CMakeLists.txt`](../CMakeLists.txt); `.vscode/tasks.json` stays a thin launcher and encodes no ordering. |
| **D2** pinned submodules · no vcpkg | **Split** | Pinning: already satisfied — 26 submodules at explicit gitlink SHAs. No-vcpkg: **rejected**. vcpkg is load-bearing (clipper2, spdlog, boost, cpr, nlohmann_json, libzippp, pugixml, Eigen3) and purging it means re-sourcing all of them as pinned submodules. Deliberate, documented divergence; revisit only as its own project. |
| **D3** fail fast, no silent defaults | **Adopted** | `install_full` hard-fails on a missing module DLL, `deps/` or `interpreter/` with a payload-specific remediation — [`cmake/install_app.cmake.in`](../cmake/install_app.cmake.in). Previously it warned and exited 0, which is exactly how an interpreter-less PostProcessor shipped unnoticed. Configure emits a warning-with-remediation for a missing PyPy source rather than a hard stop, so a developer touching an unrelated module is not blocked. |
| **D4** layered ownership via `find_package` | **N/A** | No installed-package boundary between layers. The nearest analogue is the plugin boundary: modules talk through `ModuleInterface` and `FunctionDispatcher`, never by including each other. |
| **D5** local/CI parity | **Deferred** | No CI exists yet. See the CI proposal in [`OneMill-Repo-Landscape.md`](OneMill-Repo-Landscape.md); parity is a requirement *on* that work, not a claim today. |
| **D6** short output key everywhere | **Adopted, verified** | `win-msvc-x64-<config>` in `binaryDir`/`installDir`; `.vscode/launch.json` uses the same short keys. Checked 2026-07-30: zero occurrences of the long `{project}-{operation}-…` shape in any hand-written path. |
| **D7** tests opt-in locally, always in CI | **N/A — gap** | OneMill has no automated tests at all, so there is nothing to gate. Recorded as a gap, not a conformance claim. |
| **D8** one shared responsiveness wrapper | **Adopted, verified** | `.vscode/dev-run.cmd` and `.vscode/dev-shell.ps1` are byte-identical to `templates/` at the pinned SHA (verified 2026-07-30). All build/install tasks route through the wrapper and **omit a bare `--parallel`**, per the documented Ninja cores+2 oversubscription trap. |

## Specification §2 / §10

- **§2 single source of truth** — adopted: policy lives in presets, build order in the CMake graph.
- **§2 version-safe** — adopted for submodules; see D2 for the vcpkg exception.
- **§2 fail fast** — see D3.
- **§2 local/CI parity** — see D5.
- **§10 error-handling policy** — adopted for the install path; one actionable message plus
  remediation, no fallback acquisition.

## Adapted concepts, not copied mechanisms

- **Marker / stamp discipline (A5).** The rule that an aggregate's stamp must be written only after
  *all* members complete — never one member's file — is sound outside superbuilds. Applied to
  `pypy_interpreter.stamp`, which is touched after `copy_directory` finishes, not before.
  Worth applying if the other `Copy*` targets ever get stamps.

## Deliberately not adopted

| | Why |
| --- | --- |
| Engine, manifest, `sb_add_layer`, nested delegation, `PROVIDER=prebuilt` | Solve orchestration *between* separately-built products. OneMill has one build graph. |
| `{lane}` token in the preset grammar (**A6/B5**) | OneMill has a single lane; renaming every preset buys conformance only, and costs muscle memory plus any script that names a preset. |
| Row in `FleetTracker.md` / `fleet.json` (**B8**) | Only meaningful for products on the engine. |
| `.clang-format` | Product-owned upstream too, and OneMill has no formatting policy yet. |

## Template provenance

Copied verbatim from `SuperbuildEngine@d6b4a31`; do not edit in place. Upstream **D8** requires the
first two to stay byte-identical across every product — fix the template first, then re-copy.

| File | Source |
| --- | --- |
| `.vscode/dev-run.cmd` | `templates/dev-run.cmd` |
| `.vscode/dev-shell.ps1` | `templates/dev-shell.ps1` |
| `.editorconfig` | `templates/.editorconfig` |

To re-verify without mounting the submodule, clone the engine at the pinned SHA and diff:

```bash
git clone https://dev.azure.com/cads-team/CADS%20Libraries/_git/SuperbuildEngine /tmp/sbe
git -C /tmp/sbe checkout d6b4a31
git diff --no-index /tmp/sbe/templates/dev-run.cmd .vscode/dev-run.cmd    # expect empty
```

> Observed 2026-07-30: `ips-suite2`'s own root `.editorconfig` has drifted from
> `templates/.editorconfig` (one comment word). OneMill took the **template** version, per B10.

## Open items to raise with the fleet

1. **Formalise the seam.** The spec's own structure already separates universal invariants (D)
   from engine onboarding (A/B/C). Naming that split — a *Universal Profile* that non-superbuild
   products can declare conformance to — would fix this for every product not on the engine, rather
   than each one inventing its own subset as OneMill has here.
2. **Feed back the CMake Tools finding.** Upstream **D7** notes that a build preset may pin its
   default `targets` "to keep the Build picker focused". CMake Tools **silently overrides preset
   `targets` with the status-bar target in every workflow step**, so any product relying on that
   through the GUI shares this latent failure. Belongs in `ProblemsAndLessons.md`; evidence in
   `.vscode/out.log` and the gotchas section of [`OneMill-Setup-Ledger.md`](OneMill-Setup-Ledger.md).
