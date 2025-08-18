param (
    [string]$BranchName = "feature/my-branch",
    [string]$CommitMessage = "Consistent commit",
    [switch]$DoInit,
    [switch]$DoPull,
    [switch]$DoSwitch,
    [switch]$DoCommit,
    [switch]$DoPush,
    [switch]$DoResetMain  # NEW: switch back to main/master and pull
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
        .PARAMETER Args
            Array of arguments, e.g. @('status', '--porcelain')
        .RETURN
            [pscustomobject] @{ ExitCode = <int>; StdOut = <string> }
    #>
    param([string[]]$Args)

    $stdout = & git @Args 2>&1
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
        [string[]]$Args,
        [string]$ErrorMessage
    )
    $res = Invoke-Git -Args $Args
    if ($res.ExitCode -ne 0) {
        Write-Warning "$ErrorMessage (Exit code: $($res.ExitCode))"
    }
    return $res
}

function Test-BranchLocal {
    param([string]$BranchName)
    $res = Invoke-Git -Args @('show-ref', '--verify', '--quiet', "refs/heads/$BranchName")
    return ($res.ExitCode -eq 0)
}

function Test-BranchRemote {
    param([string]$BranchName)
    # Check on origin only
    $res = Invoke-Git -Args @('ls-remote', '--exit-code', '--heads', 'origin', $BranchName)
    return ($res.ExitCode -eq 0)
}

function Ensure-FetchedBranch {
    param([string]$BranchName)
    # Try to fetch only the specified branch quietly; ignore errors (e.g., missing on remote)
    Invoke-Git -Args @('fetch', 'origin', $BranchName, '--quiet') | Out-Null
}

function Switch-GitBranch {
    param([string]$BranchName)

    Ensure-FetchedBranch -BranchName $BranchName

	$res = Run-GitCommand -Args @('switch', $BranchName) -ErrorMessage "Failed to switch local tracking branch"
    if($res.ExitCode -eq 0)
	{
		return $res.ExitCode
	}

    if (Test-BranchLocal -BranchName $BranchName) {
        Write-Host "Branch '$BranchName' exists locally. Switching..."
        $res = Run-GitCommand -Args @('checkout', $BranchName) -ErrorMessage "Failed to switch to existing branch"
        return $res.ExitCode
    }

    if (Test-BranchRemote -BranchName $BranchName) {
        Write-Host "Branch '$BranchName' exists on origin. Creating local tracking branch..."
        $res = Run-GitCommand -Args @('checkout', '-b', $BranchName, "origin/$BranchName") -ErrorMessage "Failed to create local tracking branch"
        return $res.ExitCode
    }
	
	

    Write-Host "Branch '$BranchName' not found locally or on origin. Creating new branch from current HEAD..."
    $resNew = Run-GitCommand -Args @('checkout', '-b', $BranchName) -ErrorMessage "Failed to create new branch"
    return $resNew.ExitCode
}

function Switch-ToMain {
    <#
        .SYNOPSIS
            Switches to main (or master) and pulls latest with --ff-only.
    #>
    $candidates = @('main','master')

    foreach ($b in $candidates) {
        if (Test-BranchLocal -BranchName $b) {
            Write-Host "Switching to branch: $b"
            $rc = Switch-GitBranch -BranchName $b
            if ($rc -ne 0) {
                Write-Warning "Failed to switch to $b (exit code $rc)"
                return $rc
            }
            Write-Host "Pulling latest on $b (fast-forward only)..."
            Run-GitCommand -Args @('pull', '--ff-only') -ErrorMessage "Failed to pull latest changes" | Out-Null
            return 0
        }
    }

    Write-Warning "Neither 'main' nor 'master' branch found in this repo."
    return 1
}

function Has-StagedChanges {
    # Returns $true if there are staged changes
    Invoke-Git -Args @('diff', '--cached', '--quiet') | Out-Null
    return ($LASTEXITCODE -ne 0)
}

function Has-UnstagedChanges {
    # Returns $true if there are unstaged changes
    Invoke-Git -Args @('diff', '--quiet') | Out-Null
    return ($LASTEXITCODE -ne 0)
}

function Has-Upstream {
    # Returns $true if the current branch has an upstream set
    Invoke-Git -Args @('rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}') | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Process-Repo {
    param (
        [string]$RepoPath,
        [string]$BranchName,
        [string]$CommitMessage,
        [switch]$DoInit,
        [switch]$DoPull,
        [switch]$DoSwitch,
        [switch]$DoCommit,
        [switch]$DoPush,
        [switch]$DoResetMain
    )

    Write-Host "`nProcessing: $RepoPath"
    Push-Location $RepoPath

    try {
        if ($DoInit -and (Test-Path ".gitmodules")) {
            Write-Host "Initializing submodules..."
            Run-GitCommand -Args @('submodule', 'update', '--init', '--recursive') -ErrorMessage "Failed to initialize submodules" | Out-Null
        }

        if ($DoPull) {
            Write-Host "Pulling latest changes..."
            # Prefer fast-forward only to avoid accidental merges
            Run-GitCommand -Args @('pull', '--ff-only') -ErrorMessage "Failed to pull changes" | Out-Null
        }

        if ($DoResetMain) {
            $rc = Switch-ToMain
            if ($rc -ne 0) {
                Write-Warning "Reset to main/master failed."
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
            Run-GitCommand -Args @('add', '.') -ErrorMessage "Failed to stage changes" | Out-Null

            $hasStagedChanges   = Has-StagedChanges
            $hasUnstagedChanges = Has-UnstagedChanges

            if ($hasStagedChanges -or $hasUnstagedChanges) {
                $msg = $CommitMessage.Replace('"', '\"')
                Run-GitCommand -Args @('commit', '-m', $msg) -ErrorMessage "Failed to commit changes" | Out-Null
                Write-Host "Committed changes."
            } else {
                Write-Host "No changes to commit."
            }
        }

        if ($DoPush) {
            Write-Host "Pushing changes..."
            if (Has-Upstream) {
                Run-GitCommand -Args @('push') -ErrorMessage "Failed to push changes" | Out-Null
            } else {
                Run-GitCommand -Args @('push', '--set-upstream', 'origin', $BranchName) -ErrorMessage "Failed to push changes" | Out-Null
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
foreach ($repo in $repositories) {
    Process-Repo -RepoPath $repo -BranchName $BranchName -CommitMessage $CommitMessage `
        -DoInit:$DoInit -DoPull:$DoPull -DoSwitch:$DoSwitch -DoCommit:$DoCommit -DoPush:$DoPush -DoResetMain:$DoResetMain
}

# PowerShell 7+ parallel example (optional):
# $jobs = $repositories | ForEach-Object {
#     Start-Job -ScriptBlock {
#         param($r, $b, $m, $i, $p, $s, $c, $u, $rm)
#         Process-Repo -RepoPath $r -BranchName $b -CommitMessage $m `
#             -DoInit:$i -DoPull:$p -DoSwitch:$s -DoCommit:$c -DoPush:$u -DoResetMain:$rm
#     } -ArgumentList $_, $BranchName, $CommitMessage, $DoInit, $DoPull, $DoSwitch, $DoCommit, $DoPush, $DoResetMain
# }
# $jobs | Wait-Job | Receive-Job
