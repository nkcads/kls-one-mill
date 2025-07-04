
GitHelper.ps1 — Recursive Git Automation for Repos with Submodules
==================================================================

GitHelper.ps1 is a PowerShell script designed to help you manage Git repositories with nested submodules easily and consistently.

It allows you to:
- Pull updates from remotes
- Switch or create branches recursively
- Commit changes across all levels of submodules
- Push everything to the appropriate remote
- Apply all of the above with one command

Features
--------
| Action                                      | Supported? |
|--------------------------------------------|------------|
| Pull latest code (`git pull`)              | ✅ Optional |
| Switch to a branch or create one           | ✅ Optional |
| Commit staged changes with one message     | ✅ Optional |
| Push changes to remote (`git push`)        | ✅ Optional |
| Fully recursive (supports nested submodules) | ✅ Yes    |

Prerequisites
-------------
- PowerShell (Windows, macOS, Linux with PowerShell Core)
- Git installed and available in PATH
- Proper `.gitmodules` configuration in your repository

Usage
-----
Basic Command:
```
.\GitHelper.ps1 [-BranchName "branch-name"] [-CommitMessage "commit message"] [-DoPull] [-DoSwitch] [-DoCommit] [-DoPush]
```

Command-Line Parameters:
| Parameter       | Type   | Description                                              | Example                             |
|-----------------|--------|----------------------------------------------------------|-------------------------------------|
| -BranchName     | String | The name of the branch to switch to or create             | -BranchName "dev/my-feature"        |
| -CommitMessage  | String | The commit message to use in all repos                   | -CommitMessage "Refactored modules" |
| -DoPull         | Switch | Perform `git pull` in every repository                   | -DoPull                             |
| -DoSwitch       | Switch | Checkout or create the specified branch in all repos     | -DoSwitch                           |
| -DoCommit       | Switch | Stage and commit all changes                             | -DoCommit                           |
| -DoPush         | Switch | Push changes to the remote                               | -DoPush                             |

Examples
--------
1. Pull, switch branch, commit, and push:
```
.\GitHelper.ps1 -BranchName "feature/login" -CommitMessage "Added login feature" -DoPull -DoSwitch -DoCommit -DoPush
```

2. Only switch to a branch:
```
.\GitHelper.ps1 -BranchName "bugfix/header-color" -DoSwitch
```

3. Commit and push without switching branches:
```
.\GitHelper.ps1 -CommitMessage "Hotfix: corrected typo" -DoCommit -DoPush
```

How It Works
------------
1. Initializes all submodules (`git submodule update --init --recursive`).
2. Applies selected actions (Pull, Switch, Commit, Push) in:
   - Main repository
   - All submodules
   - All nested submodules

Notes & Warnings
----------------
- Submodules must have valid remotes configured.
- Pushing requires remote write access.
- Does not handle merge conflicts — ensure clean working directories.

License
-------
Provided as-is. Use at your own risk.
