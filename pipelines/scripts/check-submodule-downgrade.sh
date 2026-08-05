#!/usr/bin/env bash
# Fail the build if a submodule gitlink moves backward or diverges relative to the branch
# point (merge-base with the target branch), unless a commit carries an
# "Allow-Submodule-Downgrade: <path>" trailer.
#
# Comparing against the merge-base rather than the target tip means a branch is flagged only
# for a pointer IT moved back, not for merely being behind an advanced target.
#
# Self-contained: fetches its own bounded, blob-filtered history, so the host pipeline's
# checkout depth does not matter and submodules need not be checked out at all.
#
# ADAPTED FROM ips-suite2/pipelines/scripts/check-submodule-downgrade.sh, with one substantive
# change: it RECURSES into nested submodules. OneMill has 17 direct submodules but 26
# recursive, with 9 nested inside 8 module wrappers - including om_MillingBackend, the most
# active repo in the product. A root-only guard is blind to those: moving MillingBackend's
# pointer backwards creates a NEW commit in ModuleMillingKalotte, so the parent gitlink moves
# FORWARD and a root-only check reports "^ forward" and passes. Hence: whenever a parent moves
# forward, we descend into it and compare its nested gitlinks across the same interval.
set -uo pipefail

BASE_DEFAULT="develop"
TRAILER="Allow-Submodule-Downgrade"
DEPTH=50    # recent source commits searched for the override trailer
MAX_LEVELS=4 # OneMill's real depth is 2; the guard is a backstop, not a bomb

# --- Endpoints: PR uses target/source branches; otherwise current branch vs origin/develop ---
if [ -n "${SYSTEM_PULLREQUEST_TARGETBRANCH:-}" ]; then
  target="${SYSTEM_PULLREQUEST_TARGETBRANCH#refs/heads/}"
  source="${SYSTEM_PULLREQUEST_SOURCEBRANCH:-${BUILD_SOURCEBRANCH:-HEAD}}"
else
  target="$BASE_DEFAULT"
  source="${BUILD_SOURCEBRANCH:-HEAD}"
fi
source="${source#refs/heads/}"

# --- Auth: the build token reads every repo in this project ---
auth=()
if [ -n "${SYSTEM_ACCESSTOKEN:-}" ]; then
  # CI: authenticate with the bearer token only. Disable the credential helper so git cannot
  # fall back to an interactive/basic-auth attempt, and forbid terminal prompts so a missing
  # credential fails fast instead of hanging the agent job.
  auth=(-c "http.extraheader=AUTHORIZATION: bearer ${SYSTEM_ACCESSTOKEN}" -c "credential.helper=")
  export GIT_TERMINAL_PROMPT=0
fi
# No token (a developer running this locally): leave git's credential configuration alone.
# Disabling the helper here broke the local path with "could not read Password ...".

# .gitmodules carries the fleet's "https://cads-team@dev.azure.com/..." form. That userinfo is
# a basic-auth USERNAME with no password: git attempts basic auth with it, which conflicts with
# the bearer header above and 401s non-interactively on an agent. Strip it and let the bearer
# token authenticate. (Local clones work either way because a developer has a credential
# manager, which is why this only shows up in CI.)
strip_userinfo() { printf '%s' "$1" | sed -E 's#^(https?://)[^/@]*@#\1#'; }

# --- Fetch target + source (blob-filtered), deepening until their merge-base exists ---
fetch_at() {
  git "${auth[@]}" fetch -q --filter=blob:none --depth "$1" origin \
    "+refs/heads/${target}:refs/guard/target" "+refs/heads/${source}:refs/guard/source"
}
if [ "$source" = "HEAD" ] || [ "$source" = "$target" ]; then
  git "${auth[@]}" fetch -q --filter=blob:none --depth 1 origin "$target" \
    || { echo "ERROR: cannot fetch '$target'"; exit 1; }
  target_tip="$(git rev-parse FETCH_HEAD)"
  head_commit="$(git rev-parse HEAD)"
  base_commit="$(git merge-base "$head_commit" "$target_tip" 2>/dev/null || echo "$target_tip")"
else
  base_commit=""
  for d in "$DEPTH" 250 2000; do
    fetch_at "$d" || { echo "ERROR: cannot fetch '$target'/'$source'"; exit 1; }
    target_tip="$(git rev-parse refs/guard/target)"
    head_commit="$(git rev-parse refs/guard/source)"
    base_commit="$(git merge-base "$head_commit" "$target_tip" 2>/dev/null || true)"
    [ -n "$base_commit" ] && break
  done
  [ -z "$base_commit" ] && { echo "WARN: no merge-base in history; comparing against target tip"; base_commit="$target_tip"; }
fi
echo "Submodule guard: source ${head_commit:0:10} vs branch-point ${base_commit:0:10} (target '$target')"
echo ""

# --- Helpers ---
gitlink_at() { git -C "$1" ls-tree "$2" -- "$3" 2>/dev/null | awk '$2=="commit"{print $3}'; }

# Match a captured string rather than piping: `git log | grep -q` lets grep exit early and
# SIGPIPE git log, which fails the script under `set -o pipefail` even on a match.
has_override() {
  local body esc
  body="$(git log --format='%B' -n "$DEPTH" "$head_commit" 2>/dev/null)"
  esc="$(printf '%s' "$1" | sed 's/[][\\.^$*+?(){}|]/\\&/g')"
  grep -iqE "^${TRAILER}:[[:space:]]*${esc}[[:space:]]*$" <<<"$body"
}

report() {  # $1=display path  $2=kind  $3=base sha  $4=head sha  $5=commits dropped  $6=nested?
  {
    echo ""
    echo "  $1 (drops $5 commit(s)):"
    echo "    branch point: $3"
    echo "    this branch : $4   <-- $2"
    echo "  Restore (copy-paste from the superproject root):"
    echo "    git -C $1 fetch origin && git -C $1 checkout $3"
    if [ "$6" = "nested" ]; then
      echo "    # nested: commit in the PARENT submodule, then bump the superproject gitlink"
      echo "    #   cd \$(dirname $1) && git add \$(basename $1) && git commit -m 'Restore pointer'"
      echo "    #   cd <superproject> && git add <parent path> && git commit"
    else
      echo "    git add $1 && git commit -m \"Restore $1 pointer\""
    fi
    echo "  Intentional? add this trailer to a commit on this branch:"
    echo "    $TRAILER: $1"
  } >&2
  echo "##vso[task.logissue type=error]$1: submodule $2 — restore (see log) or add '$TRAILER: $1' to override."
}

fail=0
summary=()
# Absolute path of the checkout, so a nested display path resolves to a real working copy.
WORKTREE="$(pwd)"

# --- Recursive walk ---
# $1=repo dir  $2=base commit  $3=head commit  $4=display prefix  $5=level
check_level() {
  local repo="$1" base="$2" head="$3" prefix="$4" level="$5"
  [ "$level" -gt "$MAX_LEVELS" ] && return 0

  local gm; gm="$(mktemp)"
  if ! git -C "$repo" show "${head}:.gitmodules" > "$gm" 2>/dev/null; then
    rm -f "$gm"; return 0            # no submodules at this level
  fi

  local key path name url disp bs hs tmp sub curl_url clone_err kind dropped nested
  nested="top"; [ "$level" -gt 1 ] && nested="nested"

  while read -r key path; do
    name="${key#submodule.}"; name="${name%.path}"
    url="$(git config -f "$gm" --get "submodule.${name}.url" 2>/dev/null)"
    disp="${prefix}${path}"

    if [ -z "$url" ]; then
      summary+=("? $disp (no url in .gitmodules)"); continue
    fi
    case "$url" in
      ../*|./*) echo "##vso[task.logissue type=warning]$disp: relative submodule URL not supported by the guard; skipped."
                summary+=("? $disp (relative url)"); continue ;;
    esac

    bs="$(gitlink_at "$repo" "$base" "$path")"
    hs="$(gitlink_at "$repo" "$head" "$path")"
    if [ -z "$bs" ] || [ -z "$hs" ]; then
      summary+=("? $disp (added or removed)"); continue
    fi
    if [ "$bs" = "$hs" ]; then
      summary+=("= $disp"); continue   # identical pointer => whole subtree identical
    fi

    # Obtain a repo that can answer ancestry questions about this submodule.
    #
    # Ancestry needs the commits BETWEEN the two endpoints, not just the endpoints. That rules
    # out a shallow working copy: the agent checks submodules out with --depth=1, and such a
    # clone cannot be repaired afterwards -
    #   - `git fetch --unshallow` exits 0 and silently does nothing once the repo has become a
    #     partial clone (promisor=true), which our own blob-filtered fetch causes
    #   - `git fetch --deepen` is rejected outright: "Server does not support --deepen" (ADO)
    # Both measured, not assumed. So a shallow copy is unusable and we clone full history
    # instead - blob-filtered and --no-checkout, so it stays cheap.
    #
    # A non-shallow local working copy is preferred when present: that is the developer case,
    # where it is both correct and faster than a network clone.
    tmp=""; sub=""
    if git -C "${WORKTREE}/${disp}" rev-parse --git-dir >/dev/null 2>&1 \
       && [ "$(git -C "${WORKTREE}/${disp}" rev-parse --is-shallow-repository 2>/dev/null)" != "true" ]; then
      sub="${WORKTREE}/${disp}"
    else
      tmp="$(mktemp -d)"
      curl_url="$(strip_userinfo "$url")"
      # Capture git's stderr rather than discarding it. The original swallowed it and guessed
      # "token lacks read access?", which sent us hunting a permissions problem that did not
      # exist. An unverifiable gitlink must report WHY it was unverifiable.
      if ! clone_err="$(git "${auth[@]}" clone -q --filter=blob:none --no-checkout --no-tags "$curl_url" "$tmp" 2>&1 </dev/null)"; then
        echo "##vso[task.logissue type=error]$disp: no local working copy, and cannot clone $curl_url to verify the gitlink."
        { echo "  git said:"; printf '%s\n' "$clone_err" | sed 's/^/    /'; } >&2
        fail=1; summary+=("X $disp (unverifiable)"); rm -rf "$tmp"; continue
      fi
      sub="$tmp"
    fi
    # Both endpoints must be present locally to compare them.
    git -C "$sub" "${auth[@]}" fetch -q --filter=blob:none origin "$bs" "$hs" 2>/dev/null </dev/null || true

    if ! git -C "$sub" cat-file -e "${bs}^{commit}" 2>/dev/null || ! git -C "$sub" cat-file -e "${hs}^{commit}" 2>/dev/null; then
      echo "##vso[task.logissue type=error]$disp: cannot resolve both endpoints ($bs, $hs) in $sub."
      fail=1; summary+=("X $disp (endpoints missing)"); [ -n "$tmp" ] && rm -rf "$tmp"; continue
    fi

    if git -C "$sub" merge-base --is-ancestor "$bs" "$hs" 2>/dev/null; then
      summary+=("^ $disp (forward)")
      # Descend: a nested downgrade hides inside a parent that moved forward.
      check_level "$sub" "$bs" "$hs" "${disp}/" $((level + 1)) </dev/null
    else
      if git -C "$sub" merge-base --is-ancestor "$hs" "$bs" 2>/dev/null; then
        kind=BACKWARD
      elif [ "$(git -C "$sub" rev-parse --is-shallow-repository 2>/dev/null)" = "true" ]; then
        # Neither direction resolves AND the history is still truncated: we genuinely cannot
        # tell. Say that instead of accusing the branch of a divergence we have not proven.
        echo "##vso[task.logissue type=error]$disp: history too shallow to relate $bs and $hs - cannot verify (deepen failed)."
        fail=1; summary+=("X $disp (indeterminate: shallow)"); [ -n "$tmp" ] && rm -rf "$tmp"; continue
      else
        kind=DIVERGED
      fi
      dropped="$(git -C "$sub" rev-list --count "${hs}..${bs}" 2>/dev/null || echo '?')"
      if has_override "$disp"; then
        echo "##vso[task.logissue type=warning]$disp: $kind overridden by $TRAILER trailer (drops $dropped commit(s))."
        summary+=("! $disp ($kind, overridden)")
      else
        report "$disp" "$kind" "$bs" "$hs" "$dropped" "$nested"
        fail=1; summary+=("X $disp ($kind)")
      fi
    fi
    # Only ever remove a temp clone WE created. $sub may be the developer's real submodule
    # working copy, and an unguarded rm -rf here would be destructive.
    [ -n "$tmp" ] && rm -rf "$tmp"
  done < <(git config -f "$gm" --get-regexp '\.path$')

  rm -f "$gm"
}

check_level "$(pwd)" "$base_commit" "$head_commit" "" 1

echo ""
echo "guard summary  (= unchanged, ^ forward, ? skipped, ! overridden, X FAILED)"
if [ "${#summary[@]}" -eq 0 ]; then
  echo "  <no submodules found>"
else
  for s in "${summary[@]}"; do echo "  $s"; done
fi
echo ""
if [ "$fail" -eq 0 ]; then echo "OK: no submodule downgrades."; else echo "FAILED: submodule downgrade(s) detected."; fi
exit "$fail"
