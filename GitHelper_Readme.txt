
📘 GitHelper.ps1 — Recursive Git Automation for Repos with Submodules

GitHelper.ps1 is a PowerShell script designed to help you manage Git repositories with nested submodules easily and consistently.

It allows you to:
- ✅ Pull updates from remotes
- ✅ Initialize submodules recursively
- ✅ Switch or create branches recursively
- ✅ Commit changes across all levels of submodules
- ✅ Push everything to the appropriate remote
- ✅ Apply all of the above with one command

------------------------------------------------------------

🚀 Features

| Action                                        | Supported? |
|----------------------------------------------|------------|
| Initialize submodules (`git submodule update --init --recursive`) | ✅ Optional |
| Pull latest code (`git pull`)                | ✅ Optional |
| Switch to a branch or create one             | ✅ Optional |
| Commit staged changes with one message       | ✅ Optional |
| Push changes to remote (`git push`)          | ✅ Optional |
| Fully recursive (supports nested submodules) | ✅ Yes      |

------------------------------------------------------------

📂 Prerequisites

- PowerShell (Windows, macOS, Linux with PowerShell Core)
- Git installed and available in PATH
- Proper `.gitmodules` configuration in your repository

------------------------------------------------------------

🛠 Usage

Basic Command:
.\GitHelper.ps1 [-BranchName "branch-name"] [-CommitMessage "commit message"] [-DefaultBranch "develop"] [-DoInit] [-DoPull] [-DoSwitch] [-DoCommit] [-DoPush] [-DoResetDefault]

Parameters:

| Parameter       | Type   | Description                                              | Example                              |
|-----------------|--------|----------------------------------------------------------|--------------------------------------|
| -BranchName     | String | The name of the branch to switch to or create             | -BranchName "feature/my-feature"     |
| -CommitMessage  | String | The commit message to use in all repos                   | -CommitMessage "Update changes"      |
| -DefaultBranch  | String | Integration branch used by -DoResetDefault (default: develop) | -DefaultBranch "develop"        |
| -DoInit         | Switch | Initialize all submodules recursively                     | -DoInit                              |
| -DoPull         | Switch | Perform git pull in every repository                      | -DoPull                              |
| -DoSwitch       | Switch | Checkout or create the specified branch in all repos      | -DoSwitch                            |
| -DoCommit       | Switch | Stage and commit all changes                              | -DoCommit                            |
| -DoPush         | Switch | Push changes to the remote                                | -DoPush                              |
| -DoResetDefault | Switch | Switch every repo back to -DefaultBranch and pull --ff-only | -DoResetDefault                    |

  -DoResetMain is accepted as an alias for -DoResetDefault so older invocations keep working.
  IMPORTANT: it now resets to 'develop', not to 'main'. See the branch model below.

------------------------------------------------------------

✅ Examples

1. Initialize submodules, switch branch, commit, and push:
.\GitHelper.ps1 -BranchName "feature/login" -CommitMessage "Added login" -DoInit -DoSwitch -DoCommit -DoPush

2. Only initialize submodules and switch branch:
.\GitHelper.ps1 -BranchName "feature/init-only" -DoInit -DoSwitch

3. Pull updates and push without switching branch:
.\GitHelper.ps1 -DoPull -DoCommit -DoPush -CommitMessage "Update before release"

------------------------------------------------------------

⚙ How It Works

1. Optionally initializes all submodules (git submodule update --init --recursive).
2. Applies selected actions (Pull, Switch, Commit, Push) in:
   - The main repository
   - All submodules
   - All nested submodules recursively

------------------------------------------------------------

🌿 Branch model (since the branch reorganisation)

- develop = integration. This is where work happens, in every repo. It is the -DefaultBranch.
- main    = release. Fast-forwarded only when something ships, and tagged there.
- Submodule 'main' branches are stale and were never fast-forwarded, so DO NOT reset the tree
  to 'main'. -DoResetDefault targets 'develop' for exactly this reason.
- Vendored, SHA-pinned submodules (GeneralUtils/OpenXLSX) have no 'develop' and are skipped
  with a warning rather than getting a bogus local branch.

------------------------------------------------------------

❗ Notes & Warnings

- Submodules must have valid remotes configured.
- Pushing requires correct permissions on all remotes.
- This script does not handle merge conflicts — ensure working directories are clean.
- -DoResetDefault and switch-to-main-latest.ps1 both move submodules OFF the superproject-pinned
  commits and onto a branch tip. That yields an untested combination until it builds. To get the
  pinned (i.e. tested) tree back: git submodule update --init --recursive

------------------------------------------------------------

🔗 License

Provided as-is. Use at your own risk.
