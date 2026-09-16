#!/usr/bin/env bash
# Offline test suite for pipelines/scripts/check-submodule-downgrade.sh
#
# WHY THIS EXISTS
# The guard's job is to refuse a bad submodule pointer. Nothing proved that it does, and a guard that
# silently passes is worse than no guard - it turns "unverified" into "verified" on the dashboard.
# The 2026-09-11 squash incident reached develop through a green pipeline. Background:
# .vscode/OneMill-KOM-16-OneMillGuard.md
#
# HOW IT WORKS
# Each case builds throwaway repositories under a temp dir and publishes them to bare remotes reached
# by file:// URL. The guard then runs UNMODIFIED against them - same fetches, same clone-by-URL, same
# ancestry questions - with no network, no credentials and no ADO. A full run takes seconds.
#
# PENDING CASES
# A case may declare PENDING=<item>. That means: this is the behaviour KOM-16 item <item> introduces,
# and the guard is EXPECTED to fail it today. The suite therefore stays green while those are
# outstanding, and reports:
#   PASS             behaviour is correct
#   PENDING          expected failure, item not implemented yet        -> not an error
#   UNEXPECTED PASS  a PENDING case now passes: remove the marker      -> error
#   FAIL             a regression                                      -> error
# Landing a KOM-16 item is therefore "delete one PENDING line and watch the suite go green".
#
# Usage:  bash run-guard-tests.sh [case-name ...]      (no arguments = every case)

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD="${GUARD_SCRIPT:-$HERE/../check-submodule-downgrade.sh}"
[ -f "$GUARD" ] || { echo "guard script not found: $GUARD" >&2; exit 2; }
# shellcheck source=fixture-lib.sh
. "$HERE/fixture-lib.sh"

ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
pass=0; pend=0; err=0; results=()

# ------------------------------------------------------------------ fixture shorthands

# mk_sub - a submodule repo on develop; sets $SUB
mk_sub() { SUB="$W/sub"; new_repo "$SUB" develop; }

# mk_super <develop-pin> <feat-pin> [path] - superproject with two branches, published, then cloned.
#   Sets $WORK. The feat branch always touches a file as well, so its commit is real even when both
#   pins are identical.
mk_super() {
  local dpin="$1" fpin="$2" path="${3:-sub}"
  SUPER="$W/super"; new_repo "$SUPER" develop
  add_gitmodules "$SUPER" "$path" "$SUBURL"
  set_gitlink "$SUPER" "$path" "$dpin"
  commit_in "$SUPER" "pin $path"
  git -C "$SUPER" checkout -q -b feat
  printf 'branch work\n' > "$SUPER/work.txt"; git -C "$SUPER" add work.txt
  set_gitlink "$SUPER" "$path" "$fpin"
  commit_in "$SUPER" "re-point $path"
  SUPERURL="$(publish "$SUPER")"
  WORK="$W/work"; clone_super "$SUPERURL" "$WORK"
}

# run_guard <pr|push> - run the guard inside $WORK; sets $OUT and $RC
run_guard() {
  local mode="$1"
  (
    cd "$WORK" || exit 9
    if [ "$mode" = pr ]; then git checkout -q feat; else git checkout -q develop; fi
    # The checkout recreates an empty directory at every gitlink, and an empty directory makes the
    # guard's local-working-copy probe answer with the PARENT repo (KOM-16 G7). Every case except
    # uninitialised_dir wants the clone-by-URL path that CI takes, so clear them here - after the
    # checkout, which is the only place it sticks.
    [ -z "${KEEP_EMPTY_DIRS:-}" ] && drop_empty_gitlink_dirs .
    if [ "$mode" = pr ]; then
      SYSTEM_PULLREQUEST_TARGETBRANCH=refs/heads/develop \
      SYSTEM_PULLREQUEST_SOURCEBRANCH=refs/heads/feat \
        bash "$GUARD"
    else
      BUILD_SOURCEBRANCH=refs/heads/develop bash "$GUARD"
    fi
  ) > "$W/out.txt" 2>&1
  RC=$?
  OUT="$(cat "$W/out.txt")"
}

# ------------------------------------------------------------------ cases
# Each sets DESC, EXPECT_EXIT, EXPECT_LINE (ERE, matched against the summary block), optionally
# PENDING, and finishes by calling run_guard.

case_unchanged() {
  DESC="pointer untouched by the branch"
  EXPECT_EXIT=0; EXPECT_LINE="^= sub$"
  mk_sub; local c0; c0="$(sha "$SUB" HEAD)"
  SUBURL="$(publish "$SUB")"
  mk_super "$c0" "$c0"; run_guard pr
}

case_forward() {
  DESC="pointer moves forward"
  EXPECT_EXIT=0; EXPECT_LINE="^\^ sub \(forward\)$"
  mk_sub; local c0 c1; c0="$(sha "$SUB" HEAD)"
  write_commit "$SUB" file.txt v1 "c1"; c1="$(sha "$SUB" HEAD)"
  SUBURL="$(publish "$SUB")"; mk_super "$c0" "$c1"; run_guard pr
}

case_backward() {
  DESC="pointer moves backward - the original reason the guard exists"
  EXPECT_EXIT=1; EXPECT_LINE="^X sub \(BACKWARD\)$"
  mk_sub; local c0 c1; c0="$(sha "$SUB" HEAD)"
  write_commit "$SUB" file.txt v1 "c1"; c1="$(sha "$SUB" HEAD)"
  SUBURL="$(publish "$SUB")"; mk_super "$c1" "$c0"; run_guard pr
}

case_rewritten() {
  DESC="squash merge: identical trees, ancestry cut"
  EXPECT_EXIT=1; EXPECT_LINE="^X sub \(REWRITTEN\)$"
  mk_sub
  git -C "$SUB" checkout -q -b feat
  write_commit "$SUB" file.txt v1 "feature work"
  local c1; c1="$(sha "$SUB" HEAD)"
  squash_onto "$SUB" develop feat
  local c2; c2="$(sha "$SUB" HEAD)"
  SUBURL="$(publish "$SUB")"; mk_super "$c1" "$c2"; run_guard pr
}

case_diverged_content() {
  DESC="genuine divergence, different trees - must NOT be reported as a rewrite"
  EXPECT_EXIT=1; EXPECT_LINE="^X sub \(DIVERGED\)$"
  mk_sub
  git -C "$SUB" checkout -q -b left
  write_commit "$SUB" left.txt L "left"
  local cl; cl="$(sha "$SUB" HEAD)"
  git -C "$SUB" checkout -q develop
  write_commit "$SUB" right.txt R "right"
  local cr; cr="$(sha "$SUB" HEAD)"
  SUBURL="$(publish "$SUB")"; mk_super "$cl" "$cr"; run_guard pr
}

case_orphan_pin() {
  DESC="new pin is forward but lives on no branch - the 2026-09-11 failure"
  EXPECT_EXIT=1; EXPECT_LINE="^X sub \(ORPHANED PIN\)$"
  mk_sub
  write_commit "$SUB" file.txt v1 "c1"
  local c0; c0="$(sha "$SUB" HEAD)"
  git -C "$SUB" checkout -q -b doomed
  write_commit "$SUB" file.txt v2 "c2 - will be left on no branch"
  local c1; c1="$(sha "$SUB" HEAD)"
  SUBURL="$(publish "$SUB")"
  git -C "$SUB" checkout -q develop
  git -C "$SUB" push -q origin --delete doomed
  git -C "$SUB" branch -q -D doomed
  mk_super "$c0" "$c1"; run_guard pr
}

case_override_in_range() {
  DESC="override trailer on a commit of THIS branch - honoured"
  EXPECT_EXIT=0; EXPECT_LINE="^! sub "
  mk_sub; local c0 c1; c0="$(sha "$SUB" HEAD)"
  write_commit "$SUB" file.txt v1 "c1"; c1="$(sha "$SUB" HEAD)"
  SUBURL="$(publish "$SUB")"; mk_super "$c1" "$c0"
  git -C "$WORK" checkout -q feat
  printf 'note\n' > "$WORK/note.txt"; git -C "$WORK" add note.txt
  git -C "$WORK" config user.name Fixture
  git -C "$WORK" config user.email fixture@example.invalid
  commit_in "$WORK" "Deliberate downgrade

Allow-Submodule-Downgrade: sub"
  git -C "$WORK" push -q origin feat
  run_guard pr
}

case_override_inherited() {
  DESC="override trailer inherited from target history - must NOT apply"
  EXPECT_EXIT=1; EXPECT_LINE="^X sub \(BACKWARD\)$"
  mk_sub; local c0 c1; c0="$(sha "$SUB" HEAD)"
  write_commit "$SUB" file.txt v1 "c1"; c1="$(sha "$SUB" HEAD)"
  SUBURL="$(publish "$SUB")"
  SUPER="$W/super"; new_repo "$SUPER" develop
  add_gitmodules "$SUPER" sub "$SUBURL"
  set_gitlink "$SUPER" sub "$c1"; commit_in "$SUPER" "pin sub"
  printf 'x\n' > "$SUPER/old.txt"; git -C "$SUPER" add old.txt
  commit_in "$SUPER" "An older, unrelated commit on develop

Allow-Submodule-Downgrade: sub"
  git -C "$SUPER" checkout -q -b feat
  printf 'y\n' > "$SUPER/work.txt"; git -C "$SUPER" add work.txt
  set_gitlink "$SUPER" sub "$c0"; commit_in "$SUPER" "downgrade sub, no trailer on this branch"
  SUPERURL="$(publish "$SUPER")"; WORK="$W/work"; clone_super "$SUPERURL" "$WORK"
  run_guard pr
}

case_nested_rewritten() {
  DESC="parent moves forward, nested backend was squashed - the recursion must see it"
  EXPECT_EXIT=1; EXPECT_LINE="^X sub/inner \(REWRITTEN\)$"
  local INNER="$W/inner"; new_repo "$INNER" develop
  git -C "$INNER" checkout -q -b feat
  write_commit "$INNER" file.txt v1 "inner feature"
  local i1; i1="$(sha "$INNER" HEAD)"
  squash_onto "$INNER" develop feat
  local i2; i2="$(sha "$INNER" HEAD)"
  local INNERURL; INNERURL="$(publish "$INNER")"
  SUB="$W/sub"; new_repo "$SUB" develop
  add_gitmodules "$SUB" inner "$INNERURL"
  set_gitlink "$SUB" inner "$i1"; commit_in "$SUB" "pin inner at the feature commit"
  local s0; s0="$(sha "$SUB" HEAD)"
  set_gitlink "$SUB" inner "$i2"; commit_in "$SUB" "re-point inner at the squash"
  local s1; s1="$(sha "$SUB" HEAD)"
  SUBURL="$(publish "$SUB")"; mk_super "$s0" "$s1"; run_guard pr
}

case_uninitialised_dir() {
  DESC="empty submodule dir must not pass as a working copy (rev-parse walks up to the parent)"
  EXPECT_EXIT=0; EXPECT_LINE="^\^ sub \(forward\)$"
  KEEP_EMPTY_DIRS=1          # this case is ABOUT the empty directory - see run_guard
  mk_sub; local c0 c1; c0="$(sha "$SUB" HEAD)"
  write_commit "$SUB" file.txt v1 "c1"; c1="$(sha "$SUB" HEAD)"
  SUBURL="$(publish "$SUB")"; mk_super "$c0" "$c1"
  run_guard pr
}

case_nothing_inspected() {
  DESC="a run that inspects zero submodules must NOT report success"
  EXPECT_EXIT=1; EXPECT_LINE=""
  mk_sub; local c0; c0="$(sha "$SUB" HEAD)"
  SUBURL="$(publish "$SUB")"
  SUPER="$W/super"; new_repo "$SUPER" develop
  add_gitmodules "$SUPER" sub "$SUBURL"
  set_gitlink "$SUPER" sub "$c0"; commit_in "$SUPER" "with submodules"
  git -C "$SUPER" checkout -q -b feat
  git -C "$SUPER" rm -q --cached .gitmodules > /dev/null
  git -C "$SUPER" rm -q --cached sub > /dev/null
  rm -f "$SUPER/.gitmodules"
  commit_in "$SUPER" "a commit with no .gitmodules at all"
  SUPERURL="$(publish "$SUPER")"; WORK="$W/work"; clone_super "$SUPERURL" "$WORK"
  run_guard pr
}

case_off_develop_on_push() {
  DESC="on a develop run, a pin that is not on the submodule's develop must fail hard"
  EXPECT_EXIT=1; EXPECT_LINE="^X sub \(OFF-DEVELOP\)$"
  mk_sub
  git -C "$SUB" checkout -q -b sidetrack
  write_commit "$SUB" file.txt side "only on sidetrack"
  local cs; cs="$(sha "$SUB" HEAD)"
  git -C "$SUB" checkout -q develop
  SUBURL="$(publish "$SUB")"
  SUPER="$W/super"; new_repo "$SUPER" develop
  add_gitmodules "$SUPER" sub "$SUBURL"
  set_gitlink "$SUPER" sub "$cs"
  commit_in "$SUPER" "pin sub at a commit that is not on its develop"
  # One more commit that leaves the pin alone: the pointer must be caught even though THIS push did
  # not touch it. That is the ModuleStatistics shape - it sat wrong for two weeks without moving.
  printf 'unrelated\n' > "$SUPER/more.txt"; git -C "$SUPER" add more.txt
  commit_in "$SUPER" "unrelated work, the pin has not moved"
  SUPERURL="$(publish "$SUPER")"; WORK="$W/work"; clone_super "$SUPERURL" "$WORK"
  run_guard push
}

case_push_to_develop_is_checked() {
  DESC="a push to develop must be compared against something other than itself"
  EXPECT_EXIT=1; EXPECT_LINE="^X sub \(BACKWARD\)$"
  mk_sub; local c0 c1; c0="$(sha "$SUB" HEAD)"
  write_commit "$SUB" file.txt v1 "c1"; c1="$(sha "$SUB" HEAD)"
  SUBURL="$(publish "$SUB")"
  SUPER="$W/super"; new_repo "$SUPER" develop
  add_gitmodules "$SUPER" sub "$SUBURL"
  set_gitlink "$SUPER" sub "$c1"; commit_in "$SUPER" "pin sub at c1"
  set_gitlink "$SUPER" sub "$c0"; commit_in "$SUPER" "downgrade sub, straight onto develop"
  SUPERURL="$(publish "$SUPER")"; WORK="$W/work"; clone_super "$SUPERURL" "$WORK"
  run_guard push
}

CASES=(unchanged forward backward rewritten diverged_content orphan_pin
       override_in_range override_inherited nested_rewritten uninitialised_dir
       nothing_inspected off_develop_on_push push_to_develop_is_checked)

# ------------------------------------------------------------------ runner

want=("$@")
[ "${#want[@]}" -eq 0 ] && want=("${CASES[@]}")

for name in "${want[@]}"; do
  W="$ROOT/$name"; mkdir -p "$W"
  DESC=""; PENDING=""; EXPECT_EXIT=0; EXPECT_LINE=""; OUT=""; RC=0; KEEP_EMPTY_DIRS=""
  "case_$name"
  summary="$(printf '%s\n' "$OUT" | sed -n '/^guard summary/,$p' | sed '1d' | sed 's/^  //' | grep -v '^$')"
  ok=1
  [ "$RC" = "$EXPECT_EXIT" ] || ok=0
  if [ -n "$EXPECT_LINE" ] && ! printf '%s\n' "$summary" | grep -qE "$EXPECT_LINE"; then ok=0; fi

  if [ -n "$PENDING" ]; then
    if [ "$ok" = 1 ]; then
      results+=("UNEXPECTED PASS|$name|$PENDING looks implemented - remove the PENDING marker")
      err=$((err + 1))
    else
      results+=("PENDING|$name|awaiting $PENDING")
      pend=$((pend + 1))
    fi
  elif [ "$ok" = 1 ]; then
    results+=("PASS|$name|")
    pass=$((pass + 1))
  else
    got="$(printf '%s' "$summary" | tr '\n' ';')"
    results+=("FAIL|$name|exit $RC want $EXPECT_EXIT; summary: $got")
    err=$((err + 1))
  fi
  # Full guard output per case, on request. Useful for PENDING cases too: it is worth checking that
  # they fail for the stated reason and not by accident.
  [ -n "${GUARD_TEST_LOGDIR:-}" ] && printf '%s\n' "$OUT" > "$GUARD_TEST_LOGDIR/$name.log"
done

printf '\n%-16s %-30s %s\n' RESULT CASE NOTE
printf '%s\n' "---------------------------------------------------------------------------------"
for r in "${results[@]}"; do
  IFS='|' read -r s n note <<< "$r"
  printf '%-16s %-30s %s\n' "$s" "$n" "$note"
done
printf '\n  %d passed, %d pending, %d failed\n\n' "$pass" "$pend" "$err"
if [ "$err" -eq 0 ]; then
  echo "OK: the guard behaves as specified (pending items excluded)."
else
  echo "FAILED: see the rows above. Set GUARD_TEST_LOGDIR to keep full output."
fi
[ "$err" -eq 0 ]
