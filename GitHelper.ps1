param (
    [string]$BranchName = "feature/my-branch",
    [string]$CommitMessage = "Consistent commit",
    [switch]$DoInit,
    [switch]$DoPull,
    [switch]$DoSwitch,
    [switch]$DoCommit,
    [switch]$DoPush
)

function Get-GitRepositories {
    param ([string]$StartPath)
    (Get-ChildItem -Path $StartPath -Recurse -Directory -Force -ErrorAction SilentlyContinue) + (Get-Item -Path $StartPath) |
        Where-Object { Test-Path -Path (Join-Path $_.FullName ".git") } |
        Select-Object -ExpandProperty FullName
}

function Run-GitCommand {
    param (
        [string]$Command,
        [string]$ErrorMessage
    )
    try {
        Invoke-Expression $Command
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "$ErrorMessage (Exit code: $LASTEXITCODE)"
        }
    } catch {
        Write-Warning "$ErrorMessage - Exception: $_"
    }
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
        [switch]$DoPush
    )

    Write-Host "`n Processing: $RepoPath"
    Push-Location $RepoPath

    if ($DoInit -and (Test-Path ".gitmodules")) {
        Write-Host "Initializing submodules..."
        Run-GitCommand -Command "git submodule update --init --recursive" -ErrorMessage "Failed to initialize submodules"
    }

    if ($DoPull) {
        Write-Host "Pulling latest changes..."
        Run-GitCommand -Command "git pull" -ErrorMessage "Failed to pull changes"
    }

    if ($DoSwitch) {
        Write-Host "Switching to branch: $BranchName"
        Run-GitCommand -Command "git rev-parse --verify $BranchName 2>$null" -ErrorMessage "Branch check failed"
        if ($LASTEXITCODE -eq 0) {
            Run-GitCommand -Command "git checkout $BranchName" -ErrorMessage "Failed to switch to existing branch"
        } else {
            Run-GitCommand -Command "git checkout -b $BranchName" -ErrorMessage "Failed to create new branch"
        }
    }

    if ($DoCommit) {
        git add .

        git diff --cached --quiet
        $hasStagedChanges = ($LASTEXITCODE -ne 0)

        git diff --quiet
        $hasUnstagedChanges = ($LASTEXITCODE -ne 0)

        if ($hasStagedChanges -or $hasUnstagedChanges) {
            Run-GitCommand -Command "git commit -m `"$CommitMessage`"" -ErrorMessage "Failed to commit changes"
            Write-Host "Committed changes."
        } else {
            Write-Host "No changes to commit."
        }
    }

    if ($DoPush) {
        Write-Host "Pushing changes..."
        Run-GitCommand -Command "git push --set-upstream origin $BranchName" -ErrorMessage "Failed to push changes"
    }

    Pop-Location
}

$currentPath = Get-Location
$repositories = Get-GitRepositories -StartPath $currentPath

if ($repositories.Count -eq 0) {
    Write-Host " No Git repositories found in $currentPath or its subdirectories."
} else {
    Write-Host " Found $($repositories.Count) repositories."

    foreach ($repo in $repositories) {
        Process-Repo -RepoPath $repo -BranchName $BranchName -CommitMessage $CommitMessage `
            -DoInit:$DoInit -DoPull:$DoPull -DoSwitch:$DoSwitch -DoCommit:$DoCommit -DoPush:$DoPush
    }

    # Optional: Parallel execution (requires PowerShell 7+)
    # $jobs = $repositories | ForEach-Object {
    #     Start-Job -ScriptBlock {
    #         param($r, $b, $m, $i, $p, $s, $c, $u)
    #         Process-Repo -RepoPath $r -BranchName $b -CommitMessage $m `
    #             -DoInit:$i -DoPull:$p -DoSwitch:$s -DoCommit:$c -DoPush:$u
    #     } -ArgumentList $_, $BranchName, $CommitMessage, $DoInit, $DoPull, $DoSwitch, $DoCommit, $DoPush
    # }
    # $jobs | Wait-Job | Receive-Job
}
