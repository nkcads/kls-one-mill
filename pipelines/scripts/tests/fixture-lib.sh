#!/usr/bin/env bash
# Fixture helpers for the guard's offline test suite.
#
# Builds throwaway git repositories under a temp root and publishes them to bare "remotes" reachable
# by file:// URL, so the guard runs against them exactly as it would against ADO - it fetches, it
# clones by URL, it resolves ancestry - with no network, no credentials and no ADO.
#
# Everything here is deterministic: fixed identity, fixed dates, core.autocrlf off. Two runs of the
# same case produce the same SHAs, which is what makes failures readable.

set -uo pipefail

FIXTURE_DATE="2026-01-01T00:00:00 +0000"

_git() { git -c core.autocrlf=false -c commit.gpgsign=false "$@"; }

# new_repo <dir> [branch]   - create a repo with one initial commit on <branch> (default develop)
new_repo() {
  local dir="$1" br="${2:-develop}"
  mkdir -p "$dir"
  _git init -q -b "$br" "$dir"
  _git -C "$dir" config user.name  "Fixture"
  _git -C "$dir" config user.email "fixture@example.invalid"
  _git -C "$dir" config core.autocrlf false
  printf 'base\n' > "$dir/file.txt"
  _git -C "$dir" add file.txt
  commit_in "$dir" "initial"
}

# commit_in <repo> <message>  - commit whatever is staged, with a fixed date
commit_in() {
  local dir="$1" msg="$2"
  GIT_AUTHOR_DATE="$FIXTURE_DATE" GIT_COMMITTER_DATE="$FIXTURE_DATE" \
    _git -C "$dir" commit -q -m "$msg"
}

# write_commit <repo> <file> <content> <message>
write_commit() {
  local dir="$1" f="$2" c="$3" msg="$4"
  printf '%s\n' "$c" > "$dir/$f"
  _git -C "$dir" add "$f"
  commit_in "$dir" "$msg"
}

# squash_onto <repo> <target-branch> <source-branch> [message]
#   Reproduces an ADO "Squash commit" PR completion: one new commit on <target-branch> carrying the
#   source branch's tree, with a single parent and a merge-looking message. The source commits are
#   NOT ancestors of the result - that is the whole point.
squash_onto() {
  local dir="$1" target="$2" source="$3" msg="${4:-Merge pull request 1 from $3 into $2}"
  _git -C "$dir" checkout -q "$target"
  _git -C "$dir" merge -q --squash "$source" >/dev/null 2>&1
  commit_in "$dir" "$msg"
}

# set_gitlink <superproject> <path> <sha>   - record a gitlink without needing the submodule present
set_gitlink() {
  _git -C "$1" update-index --add --cacheinfo "160000,$3,$2"
}

# add_gitmodules <superproject> <path> <url> [more path url pairs...]
add_gitmodules() {
  local dir="$1"; shift
  : > "$dir/.gitmodules"
  while [ "$#" -ge 2 ]; do
    printf '[submodule "%s"]\n\tpath = %s\n\turl = %s\n' "$1" "$1" "$2" >> "$dir/.gitmodules"
    shift 2
  done
  _git -C "$dir" add .gitmodules
}

# publish <repo>   - create <repo>.git as a bare remote, push every branch, echo the file:// URL
publish() {
  local dir="$1" bare="$1.git"
  if [ ! -d "$bare" ]; then
    _git init -q --bare "$bare"
    _git -C "$dir" remote add origin "file://$(cd "$bare" && pwd)"
  fi
  _git -C "$dir" push -q --all origin
  # Point the bare HEAD at develop. Without this it still names the init-time default, which
  # does not exist here, and every clone comes back with NO checkout and NO index - silently.
  _git -C "$bare" symbolic-ref HEAD refs/heads/develop 2>/dev/null || true
  printf 'file://%s\n' "$(cd "$bare" && pwd)"
}

# clone_super <url> <dest>   - a plain clone, submodules NOT initialised.
#
# git clone leaves an EMPTY directory at each gitlink path. That state is its own defect case - an
# empty directory makes `git -C <path> rev-parse --git-dir` walk UP and answer with the parent
# repository, which the guard then mistakes for the submodule's working copy (case
# uninitialised_dir, KOM-16 G7). CI is spared only because its checkout is shallow, so the guard's
# second condition fails and the clone-by-URL path is taken instead.
#
# Every other case wants that clone-by-URL path - the one CI exercises - so the empty directories
# are removed here. Do NOT "simplify" this away: without it every case fails as "endpoints missing"
# and the suite tests nothing.
clone_super() {
  _git clone -q "$1" "$2"
  _git -C "$2" config core.autocrlf false
  drop_empty_gitlink_dirs "$2"
}

# drop_empty_gitlink_dirs <repo> - remove the empty directory git leaves at each gitlink path.
# Must run after EVERY checkout, not only after a clone: a checkout recreates them.
drop_empty_gitlink_dirs() {
  local p
  while read -r p; do
    [ -n "$p" ] && rmdir "$1/$p" 2>/dev/null
  done < <(_git -C "$1" ls-files --stage | awk '$1=="160000"{ $1=$2=$3=""; sub(/^ +/,""); print }')
}

# sha <repo> <rev>
sha() { _git -C "$1" rev-parse "$2"; }
