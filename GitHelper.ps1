param (
    [string]$BranchName = "feature/my-branch",        # Branch name to switch/create
    [string]$CommitMessage = "Consistent commit",      # Commit message
    [switch]$DoPull,                                   # Optional: perform git pull
    [switch]$DoSwitch,                                 # Optional: switch/create branch
    [switch]$DoCommit,                                 # Optional: commit staged changes
    [switch]$DoPush                                    # Optional: push changes to remote
)

function Process-Repo {
    param (
        [string]$RepoPath,
        [string]$BranchName,
        [string]$CommitMessage
    )

    Write-Host "`n📁 Processing: $RepoPath"
    Set-Location $RepoPath

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

    # Process nested submodules
    $submodules = git config --file .gitmodules --get-regexp path | ForEach-Object { ($_ -split ' ')[1] }

    foreach ($submodule in $submodules) {
        $submodulePath = Join-Path $RepoPath $submodule
        if (Test-Path $submodulePath) {
            Process-Repo -RepoPath $submodulePath -BranchName $BranchName -CommitMessage $CommitMessage
        }
    }

    Set-Location -Path $PSScriptRoot
}

# Initialize submodules recursively (safe to run every time)
git submodule update --init --recursive

# Start from the current repository
Process-Repo -RepoPath (Get-Location).Path -BranchName $BranchName -CommitMessage $CommitMessage
