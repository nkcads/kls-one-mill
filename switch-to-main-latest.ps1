<#
.SYNOPSIS
  Attach the superproject AND every submodule to an integration branch tip and pull it.
  Defaults to 'develop'. Continues on errors and summarizes at the end.

.DESCRIPTION
  Since the branch reorganisation the integration branch is 'develop' and 'main' is the
  RELEASE branch. This script used to hardcode 'main' everywhere, which is now wrong in two
  ways: it would land the superproject on the last release instead of current work, and it
  would attach all 26 submodules to their own 'main' branches - which are stale and were never
  fast-forwarded (om_MillingBackend's 'main' even holds a commit that is not in the
  integration line). Running it after the migration would silently put everyone on the wrong
  code across the whole tree.

  Note what this script does by design: it moves submodules OFF the superproject-pinned
  commits and onto a branch tip. That is useful for "give me everyone's latest", but the
  result is an untested combination until it builds. It is not a substitute for
  `git submodule update --init --recursive`, which reproduces the pinned - i.e. tested - tree.

.PARAMETER Branch
  Branch to attach to. Default 'develop'.

.PARAMETER AllowMainOnSubmodules
  Required to run the submodule pass with -Branch main. Guard rail: submodule 'main' branches
  are unreliable (see above), so asking for 'main' updates the superproject only unless you
  explicitly opt in.

.EXAMPLE
  .\switch-to-main-latest.ps1                     # everything onto 'develop'
.EXAMPLE
  .\switch-to-main-latest.ps1 -Branch main        # superproject to the last release; submodules skipped
.NOTES
  The Authenticode signature was removed when this file was retargeted from 'main' to
  'develop' - an edited body invalidates it, and a stale signature reads as tampering. Re-sign
  with the CADS certificate if signed scripts are required in your environment.
#>
param(
  [string]$Branch = 'develop',
  [switch]$AllowMainOnSubmodules
)

$ErrorActionPreference = 'Continue'  # keep going

# --- Logging helpers ---
function Log([string]$msg)  { Write-Host $msg -ForegroundColor Cyan }
function Ok([string]$msg)   { Write-Host $msg -ForegroundColor Green }
function Warn([string]$msg) { Write-Warning $msg }
function Err([string]$msg)  { Write-Host $msg -ForegroundColor Red }

$Global:Failures = New-Object System.Collections.Generic.List[string]

function Note-Failure([string]$msg) {
  $Global:Failures.Add($msg)
  Err $msg
}

# --- Git helpers ---
function Get-PrimaryRemote {
  try {
    $remotes = & git remote 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $remotes) { throw "No remotes configured." }
    $names = @($remotes -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    if ($names -contains 'origin') { return 'origin' }
    return $names[0]
  } catch {
    Note-Failure "Top-level: cannot determine primary remote ($($_.Exception.Message))"
    return $null
  }
}

function Run-Git {
  # NOTE: the second parameter must NOT be named $Args. $Args is a PowerShell automatic
  # variable, so it never binds - it is replaced by the (empty) set of unbound arguments.
  # `& git $Cmd @Args` therefore dropped every argument: `git switch main` ran as bare
  # `git switch` (error), `git pull --ff-only origin main` as bare `git pull`, and
  # `git stash push -u -m ...` as bare `git stash`. Renamed to $GitArgs.
  #
  # Second issue, only visible once arguments actually reached git: this function must return
  # the exit code and NOTHING else. `& git ...` writes git's output to the pipeline, so the
  # function returned @(<output lines...>, <exit code>) - and every caller written as
  # `if ((Run-Git 'switch' @($Branch)) -ne 0)` compared that array against 0, which is never
  # equal. Result: successful commands were reported as failures. Piping to Out-Host keeps the
  # output visible to the user while leaving only the exit code on the pipeline.
  param([Parameter(Mandatory=$true)][string]$Cmd, [string[]]$GitArgs)
  & git $Cmd @GitArgs | Out-Host
  return $LASTEXITCODE
}

function Get-SubmodulePaths {
  <#
    .SYNOPSIS
      Recursive list of submodule working-tree paths, relative to the superproject root.
    .NOTES
      Deliberately NOT `git submodule foreach`. That runs the command through sh, and a
      PowerShell string containing sh variables ($name, $sm_path, ...) does not survive
      PowerShell's native-argument quoting: sh received the '$' names literally, so the whole
      foreach body was a silent no-op (it printed "$sm_path" verbatim instead of a path).
      Driving `git -C <path>` per submodule from PowerShell avoids the shell boundary entirely
      and gives per-repo error reporting.
  #>
  $lines = & git submodule status --recursive 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $lines) { return @() }
  $paths = @()
  foreach ($l in $lines) {
    $t = "$l".Trim()
    if ($t -eq '') { continue }
    # format: [-+U]<sha> <path> (<describe>)   -> path is the 2nd whitespace-separated field
    $parts = $t -split '\s+'
    if ($parts.Count -ge 2) { $paths += $parts[1] }
  }
  return $paths
}

function Get-SubmoduleRemote([string]$Path) {
  $remotes = & git -C $Path remote 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $remotes) { return $null }
  $names = @($remotes | ForEach-Object { "$_".Trim() } | Where-Object { $_ -ne '' })
  if ($names -contains 'origin') { return 'origin' }
  return $names[0]
}

function Ensure-LocalBranch([string]$remote, [string]$branch) {
  # If the local branch exists, done.
  & git show-ref --verify --quiet "refs/heads/$branch" *> $null
  if ($LASTEXITCODE -eq 0) { return $true }

  # Else if remote/<branch> exists, create a tracking branch.
  & git ls-remote --exit-code --heads $remote $branch *> $null
  if ($LASTEXITCODE -eq 0) {
    if ((Run-Git 'switch' @('-c',$branch,'--track',"$remote/$branch")) -ne 0) {
      Run-Git 'checkout' @('-b',$branch,'--track',"$remote/$branch") | Out-Null
    }
    & git show-ref --verify --quiet "refs/heads/$branch" *> $null
    return ($LASTEXITCODE -eq 0)
  }

  Note-Failure "Top-level: remote '$remote' has no '$branch' branch."
  return $false
}

# --- Start ---
Log "==> Target branch: '$Branch'"

$doSubmodules = $true
if ($Branch -eq 'main' -and -not $AllowMainOnSubmodules) {
  $doSubmodules = $false
  Warn "Branch 'main' requested: submodules will be SKIPPED."
  Warn "Submodule 'main' branches are stale and were never fast-forwarded, so attaching to them"
  Warn "puts you on the wrong code. Pass -AllowMainOnSubmodules if you really mean it."
}

$remote = Get-PrimaryRemote

Log "==> Stashing local changes (if any)..."
# Same caveat as in the submodule loop: a clean tree still exits 0, so track it explicitly
# instead of trying to pop unconditionally at the end.
$topStashed = $false
if (& git status --porcelain) {
  Run-Git 'stash' @('push','-u','-m',"auto: switch-to-$Branch") | Out-Null
  if ($LASTEXITCODE -eq 0) { $topStashed = $true }
} else {
  Log "    (nothing to stash)"
}

if ($remote) {
  Log "==> Fetching from '$remote'..."
  if ((Run-Git 'fetch' @('--prune',$remote)) -ne 0) {
    Warn "Top-level: fetch from '$remote' failed; continuing."
  }
} else {
  Warn "Top-level: skipping fetch (no remote)."
}

$switchedTop = $false
if ($remote -and (Ensure-LocalBranch -remote $remote -branch $Branch)) {
  Log "==> Switching top-level to '$Branch'..."
  if ((Run-Git 'switch' @($Branch)) -ne 0) {
    if ((Run-Git 'checkout' @($Branch)) -ne 0) {
      Note-Failure "Top-level: failed to switch to '$Branch'."
    } else { $switchedTop = $true }
  } else { $switchedTop = $true }
} else {
  Warn "Top-level: local '$Branch' not ensured; will still attempt submodules."
}

if ($switchedTop) {
  Log "==> Pulling top-level (ff-only)..."
  if ((Run-Git 'pull' @('--ff-only',$remote,$Branch)) -ne 0) {
    Warn "Top-level: pull failed (non-ff or network); continuing."
  }
}

# Ensure submodules are present (may temporarily detach; we reattach below if asked to)
Log "==> Ensuring submodules are cloned..."
if ((Run-Git 'submodule' @('update','--init','--recursive')) -ne 0) {
  Warn "Submodules: init/update reported issues; continuing."
}

if ($doSubmodules) {
  Log "==> Switching submodules to '$Branch' and pulling latest (continuing on errors)..."

  $attached = 0; $skipped = 0; $problems = 0
  foreach ($p in (Get-SubmodulePaths)) {
    $r = Get-SubmoduleRemote -Path $p
    if (-not $r) { Warn "  $p : no remotes - skipped"; $skipped++; continue }

    & git -C $p fetch --prune $r *> $null
    if ($LASTEXITCODE -ne 0) { Warn "  $p : fetch failed; continuing with what is local" }

    # Vendored, SHA-pinned submodules legitimately have no integration branch.
    & git -C $p ls-remote --exit-code --heads $r $Branch *> $null
    if ($LASTEXITCODE -ne 0) {
      Log  "  $p : SKIP - '$r' has no '$Branch' (SHA-pinned? left on the pinned commit)"
      $skipped++; continue
    }

    # Local edits would block the switch, so stash - but only if there is actually something to
    # stash. `git stash push` on a clean tree prints "No local changes to save" and still exits 0,
    # so the exit code must NOT be used to decide whether a stash was created: doing so made the
    # later `stash pop` fail and reported a bogus "stash pop had conflicts" for every clean repo.
    $stashed = $false
    if (& git -C $p status --porcelain) {
      & git -C $p stash push -u -m "auto: submodule switch-to-$Branch" *> $null
      if ($LASTEXITCODE -eq 0) { $stashed = $true }
      else { Warn "  $p : could not stash local changes; switch may fail" }
    }

    & git -C $p show-ref --verify --quiet "refs/heads/$Branch" *> $null
    if ($LASTEXITCODE -ne 0) {
      & git -C $p branch --track $Branch "$r/$Branch" *> $null
      if ($LASTEXITCODE -ne 0) { Warn "  $p : could not create local '$Branch'" }
    }

    & git -C $p switch $Branch *> $null
    if ($LASTEXITCODE -ne 0) { & git -C $p checkout $Branch *> $null }
    if ($LASTEXITCODE -ne 0) {
      Note-Failure "  $p : could not switch to '$Branch'"; $problems++
      if ($stashed) { & git -C $p stash pop *> $null }
      continue
    }

    & git -C $p pull --ff-only $r $Branch *> $null
    if ($LASTEXITCODE -ne 0) { Warn "  $p : pull failed (non-ff or network)" }

    if ($stashed) {
      & git -C $p stash pop *> $null
      if ($LASTEXITCODE -ne 0) { Warn "  $p : stash pop had conflicts - resolve manually (stash kept)" }
    }

    $attached++
  }

  Log "==> Submodules: $attached on '$Branch', $skipped skipped, $problems problem(s)."
} else {
  Log "==> Submodule pass skipped (see warning above). Submodules remain on the pinned commits."
}

if ($topStashed) {
  Log "==> Restoring top-level stash..."
  if ((Run-Git 'stash' @('pop')) -ne 0) {
    Note-Failure "Top-level: stash pop had conflicts - your changes are still in the stash."
  }
}

Ok "Done: repo and submodules attempted. See summary below."

# --- Summary ---
if ($Global:Failures.Count -gt 0) {
  Write-Host "`n=== Summary of issues ===" -ForegroundColor Yellow
  $Global:Failures | ForEach-Object { Write-Host " - $_" -ForegroundColor Yellow }
} else {
  Write-Host "`nNo critical top-level issues detected." -ForegroundColor Green
}

if ($doSubmodules) {
  Write-Host "`nNOTE: Submodules are now on the latest '$Branch', which may differ from the superproject-pinned commits." -ForegroundColor Yellow
  Write-Host "      Build before you commit any gitlink bump - the pinned SHAs are the record of what was tested." -ForegroundColor Yellow
  Write-Host "      To go back to the pinned (tested) tree: git submodule update --init --recursive" -ForegroundColor Yellow
}
