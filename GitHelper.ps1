param (
    [string]$BranchName = "feature/my-branch",
    [string]$CommitMessage = "Consistent commit",
    # The integration branch every repo should sit on. 'develop' since the branch
    # reorganisation: 'main' is now the RELEASE branch and submodule 'main' branches
    # are stale/unreliable, so resetting to it across the tree is wrong.
    [string]$DefaultBranch = "develop",
    [switch]$DoInit,
    [switch]$DoPull,
    [switch]$DoSwitch,
    [switch]$DoCommit,
    [switch]$DoPush,
    # Switch back to $DefaultBranch and pull. -DoResetMain kept as an alias so existing
    # invocations keep working, but it now resets to $DefaultBranch, not to 'main'.
    [Alias('DoResetMain')][switch]$DoResetDefault
)

# --- Helpers ---------------------------------------------------------------

function Get-GitRepositories {
    param ([string]$StartPath)

    # Include the start path itself (if it's a repo) and recurse for others
    (Get-ChildItem -Path $StartPath -Recurse -Directory -Force -ErrorAction SilentlyContinue) + (Get-Item -Path $StartPath) |
        Where-Object { Test-Path -Path (Join-Path $_.FullName ".git") } |
        Select-Object -ExpandProperty FullName
}

function Invoke-Git {
    <#
        .SYNOPSIS
            Safely invoke git with array arguments (no Invoke-Expression).
        .PARAMETER GitArgs
            Array of arguments, e.g. @('status', '--porcelain')
        .RETURN
            [pscustomobject] @{ ExitCode = <int>; StdOut = <string> }
        .NOTES
            The parameter MUST NOT be called $Args. $Args is a PowerShell automatic variable:
            declaring it as a parameter does not bind, it is overwritten with the (empty) set of
            unbound arguments. `& git @Args` then ran bare `git`, which printed the usage text and
            exited 1 - so Test-BranchLocal / Test-BranchRemote / Run-GitCommand always reported
            failure and this script performed no git operations at all, only warnings.
            Renamed to $GitArgs. Keep it that way.
    #>
    param([string[]]$GitArgs)

    $stdout = & git @GitArgs 2>&1
    $code = $LASTEXITCODE
    [pscustomobject]@{
        ExitCode = $code
        StdOut   = ($stdout -join [Environment]::NewLine)
    }
}

function Run-GitCommand {
    <#
        .SYNOPSIS
            Wrapper that logs warnings on non-zero exit codes.
    #>
    param (
        [string[]]$GitArgs,      # NOT $Args - see the note in Invoke-Git
        [string]$ErrorMessage
    )
    $res = Invoke-Git -GitArgs $GitArgs
    if ($res.ExitCode -ne 0) {
        Write-Warning "$ErrorMessage (Exit code: $($res.ExitCode))"
    }
    return $res
}

function Test-BranchLocal {
    param([string]$BranchName)
    $res = Invoke-Git -GitArgs @('show-ref', '--verify', '--quiet', "refs/heads/$BranchName")
    return ($res.ExitCode -eq 0)
}

function Test-BranchRemote {
    param([string]$BranchName)
    # Check on origin only
    $res = Invoke-Git -GitArgs @('ls-remote', '--exit-code', '--heads', 'origin', $BranchName)
    return ($res.ExitCode -eq 0)
}

function Ensure-FetchedBranch {
    param([string]$BranchName)
    # Try to fetch only the specified branch quietly; ignore errors (e.g., missing on remote)
    Invoke-Git -GitArgs @('fetch', 'origin', $BranchName, '--quiet') | Out-Null
}

function Switch-GitBranch {
    param([string]$BranchName)

    Ensure-FetchedBranch -BranchName $BranchName

	$res = Run-GitCommand -GitArgs @('switch', $BranchName) -ErrorMessage "Failed to switch local tracking branch"
    if($res.ExitCode -eq 0)
	{
		return $res.ExitCode
	}

    if (Test-BranchLocal -BranchName $BranchName) {
        Write-Host "Branch '$BranchName' exists locally. Switching..."
        $res = Run-GitCommand -GitArgs @('checkout', $BranchName) -ErrorMessage "Failed to switch to existing branch"
        return $res.ExitCode
    }

    if (Test-BranchRemote -BranchName $BranchName) {
        Write-Host "Branch '$BranchName' exists on origin. Creating local tracking branch..."
        $res = Run-GitCommand -GitArgs @('checkout', '-b', $BranchName, "origin/$BranchName") -ErrorMessage "Failed to create local tracking branch"
        return $res.ExitCode
    }
	
	

    Write-Host "Branch '$BranchName' not found locally or on origin. Creating new branch from current HEAD..."
    $resNew = Run-GitCommand -GitArgs @('checkout', '-b', $BranchName) -ErrorMessage "Failed to create new branch"
    return $resNew.ExitCode
}

function Switch-ToDefaultBranch {
    <#
        .SYNOPSIS
            Switches to the integration branch ($DefaultBranch, normally 'develop') and
            pulls latest with --ff-only.
        .NOTES
            Two deliberate differences from the old Switch-ToMain:

            1. It targets $DefaultBranch, not 'main'/'master'. 'main' is the release branch
               now, and submodule 'main' branches are stale (om_MillingBackend's 'main' holds
               a commit that is not even in the integration line), so resetting the tree to
               'main' put developers on the wrong code.

            2. It accepts a branch that exists only on 'origin'. The old version tested
               Test-BranchLocal only, so in a fresh clone - where 'develop' exists on origin
               but not yet locally - it reported "Neither 'main' nor 'master' found" and did
               nothing. That is the state every clone is in right after the migration.

            It never *creates* the branch: a reset should land on something that exists, so a
            repo legitimately without it (e.g. the vendored GeneralUtils/OpenXLSX, which is
            SHA-pinned and has no 'develop') is skipped with a warning instead of sprouting a
            bogus local branch.
    #>
    param([string]$Branch)

    Ensure-FetchedBranch -BranchName $Branch

    $haveLocal  = Test-BranchLocal  -BranchName $Branch
    $haveRemote = Test-BranchRemote -BranchName $Branch
    if (-not $haveLocal -and -not $haveRemote) {
        Write-Warning "Branch '$Branch' not found locally or on origin - skipping this repo."
        return 1
    }

    Write-Host "Switching to branch: $Branch"
    $rc = Switch-GitBranch -BranchName $Branch
    if ($rc -ne 0) {
        Write-Warning "Failed to switch to $Branch (exit code $rc)"
        return $rc
    }

    Write-Host "Pulling latest on $Branch (fast-forward only)..."
    Run-GitCommand -GitArgs @('pull', '--ff-only') -ErrorMessage "Failed to pull latest changes" | Out-Null
    return 0
}

function Has-StagedChanges {
    # Returns $true if there are staged changes
    Invoke-Git -GitArgs @('diff', '--cached', '--quiet') | Out-Null
    return ($LASTEXITCODE -ne 0)
}

function Has-UnstagedChanges {
    # Returns $true if there are unstaged changes
    Invoke-Git -GitArgs @('diff', '--quiet') | Out-Null
    return ($LASTEXITCODE -ne 0)
}

function Has-Upstream {
    # Returns $true if the current branch has an upstream set
    Invoke-Git -GitArgs @('rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}') | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Process-Repo {
    param (
        [string]$RepoPath,
        [string]$BranchName,
        [string]$CommitMessage,
        [string]$DefaultBranch,
        [switch]$DoInit,
        [switch]$DoPull,
        [switch]$DoSwitch,
        [switch]$DoCommit,
        [switch]$DoPush,
        [switch]$DoResetDefault
    )

    Write-Host "`nProcessing: $RepoPath"
    Push-Location $RepoPath

    try {
        if ($DoInit -and (Test-Path ".gitmodules")) {
            Write-Host "Initializing submodules..."
            Run-GitCommand -GitArgs @('submodule', 'update', '--init', '--recursive') -ErrorMessage "Failed to initialize submodules" | Out-Null
        }

        if ($DoPull) {
            Write-Host "Pulling latest changes..."
            # Prefer fast-forward only to avoid accidental merges
            Run-GitCommand -GitArgs @('pull', '--ff-only') -ErrorMessage "Failed to pull changes" | Out-Null
        }

        if ($DoResetDefault) {
            $rc = Switch-ToDefaultBranch -Branch $DefaultBranch
            if ($rc -ne 0) {
                Write-Warning "Reset to '$DefaultBranch' did not complete for this repo."
            }
        }

        if ($DoSwitch) {
            Write-Host "Switching to branch: $BranchName"
            $rc = Switch-GitBranch -BranchName $BranchName
            if ($rc -ne 0) {
                Write-Warning "Switch/create branch failed with exit code $rc"
            }
        }

        if ($DoCommit) {
            # Stage everything
            Run-GitCommand -GitArgs @('add', '.') -ErrorMessage "Failed to stage changes" | Out-Null

            $hasStagedChanges   = Has-StagedChanges
            $hasUnstagedChanges = Has-UnstagedChanges

            if ($hasStagedChanges -or $hasUnstagedChanges) {
                $msg = $CommitMessage.Replace('"', '\"')
                Run-GitCommand -GitArgs @('commit', '-m', $msg) -ErrorMessage "Failed to commit changes" | Out-Null
                Write-Host "Committed changes."
            } else {
                Write-Host "No changes to commit."
            }
        }

        if ($DoPush) {
            Write-Host "Pushing changes..."
            if (Has-Upstream) {
                Run-GitCommand -GitArgs @('push') -ErrorMessage "Failed to push changes" | Out-Null
            } else {
                Run-GitCommand -GitArgs @('push', '--set-upstream', 'origin', $BranchName) -ErrorMessage "Failed to push changes" | Out-Null
            }
        }
    }
    finally {
        Pop-Location
    }
}

# --- Main ------------------------------------------------------------------

$currentPath  = Get-Location
$repositories = Get-GitRepositories -StartPath $currentPath

if (-not $repositories -or $repositories.Count -eq 0) {
    Write-Host "No Git repositories found in $currentPath or its subdirectories."
    return
}

Write-Host "Found $($repositories.Count) repos."
if ($DoResetDefault) { Write-Host "Reset target branch: '$DefaultBranch'" }
foreach ($repo in $repositories) {
    Process-Repo -RepoPath $repo -BranchName $BranchName -CommitMessage $CommitMessage `
        -DefaultBranch $DefaultBranch `
        -DoInit:$DoInit -DoPull:$DoPull -DoSwitch:$DoSwitch -DoCommit:$DoCommit -DoPush:$DoPush `
        -DoResetDefault:$DoResetDefault
}

# PowerShell 7+ parallel example (optional):
# $jobs = $repositories | ForEach-Object {
#     Start-Job -ScriptBlock {
#         param($r, $b, $m, $d, $i, $p, $s, $c, $u, $rd)
#         Process-Repo -RepoPath $r -BranchName $b -CommitMessage $m -DefaultBranch $d `
#             -DoInit:$i -DoPull:$p -DoSwitch:$s -DoCommit:$c -DoPush:$u -DoResetDefault:$rd
#     } -ArgumentList $_, $BranchName, $CommitMessage, $DefaultBranch, $DoInit, $DoPull, $DoSwitch, $DoCommit, $DoPush, $DoResetDefault
# }
# $jobs | Wait-Job | Receive-Job
