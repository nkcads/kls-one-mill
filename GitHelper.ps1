param (
    [string]$BranchName = "feature/my-branch",
    [string]$CommitMessage = "Consistent commit",
    [switch]$DoInit,         # New: Initialize submodules and checkout all
    [switch]$DoPull,
    [switch]$DoSwitch,
    [switch]$DoCommit,
    [switch]$DoPush
)

function Process-Repo {
    param (
        [string]$RepoPath,
        [string]$BranchName,
        [string]$CommitMessage
    )

    Write-Host "`n📁 Processing: $RepoPath"
    Set-Location $RepoPath

    if ($DoInit) {
        Write-Host "🔗 Initializing submodules..."
        git submodule update --init --recursive
    }

    if ($DoPull) {
        Write-Host "🔄 Pulling latest changes..."
        git pull
    }

    if ($DoSwitch) {
        Write-Host "🌿 Switching to branch: $BranchName"
        git checkout -B $BranchName
    }

    if ($DoCommit) {
        git add .
        $status = git diff --cached --quiet
        if ($LASTEXITCODE -ne 0) {
            git commit -m "$CommitMessage"
            Write-Host "✅ Committed changes."
        } else {
            Write-Host "ℹ️  No changes to commit."
        }
    }

    if ($DoPush) {
        Write-Host "🚀 Pushing branch '$BranchName'..."
        git push --set-upstream origin $BranchName
    }

    $submodules = git config --file .gitmodules --get-regexp path | ForEach-Object { ($_ -split ' ')[1] }

    foreach ($submodule in $submodules) {
        $submodulePath = Join-Path $RepoPath $submodule
        if (Test-Path $submodulePath) {
            Process-Repo -RepoPath $submodulePath -BranchName $BranchName -CommitMessage $CommitMessage
        }
    }

    Set-Location -Path $PSScriptRoot
}

if ($DoInit) {
    git submodule update --init --recursive
}

Process-Repo -RepoPath (Get-Location).Path -BranchName $BranchName -CommitMessage $CommitMessage
