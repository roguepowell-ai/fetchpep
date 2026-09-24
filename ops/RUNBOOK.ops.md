---
authority: claude-proposes
---

# Runbook

Steps written down because they happen rarely and fail expensively. **Order matters
throughout** — each step has something later that depends on it, and doing them out of order
is how you end up with two copies of a repo, or a Unity project inside a synced folder.

Every step ends with a `verify:` line. Run it. A step is not done because it looked like it
worked.

---

# Part 1 — The build machine, from nothing

## 1. Decide where the repo lives — before installing anything

The most expensive thing to get wrong, because everything after it sits inside it.

- **Not inside any cloud-synced folder.** [certain] `Library/` is thousands of files Unity
  regenerates constantly, git uses lock files, and sync clients can turn either into
  cloud-only placeholders that Unity and git then read as empty.
- **No spaces in the path.** A documented breaker for the Unity editor bridge.
- **Short.** Windows' 260-character path limit bites Unity and `node_modules`.
- **On Windows, check whether Desktop and Documents are redirected** into cloud storage
  first. They often are, without anyone having chosen it.

```
verify: the path has no space, is not under a sync client's root, and is short
```

## 2. Install the toolchain

```powershell
winget install --id Git.Git -e
winget install --id GitHub.GitLFS -e
winget install --id GitHub.cli -e
```

Git Bash arrives with Git for Windows and is needed later — the scripts in `checks/` are
bash and PowerShell cannot run them.

A GUI git client is optional and does not replace these. Claude Code drives the command line.

```
verify: in a NEW terminal — git --version && git lfs version && gh --version
```

## 3. Authenticate

```powershell
gh auth login
```

GitHub.com → HTTPS → authenticate with browser. [certain] Password authentication for git
operations was removed, so without this every push asks for a token.

```
verify: gh auth status   →   "Logged in to github.com"
```

## 4. Clone — once, to the path from step 1

```powershell
cd "<the path from step 1>"
gh repo clone roguepowell-ai/fetchpep
```

**Clone once.** A second clone elsewhere is how the contract ends up in a folder that is not
the repo.

```
verify: git -C fetchpep remote -v   →   roguepowell-ai/fetchpep
```

## 5. Place the contract

Anything written to the machine remotely lands in `_setup/`, because `.claude/` and
`.github/workflows/` are refused by remote tools — correctly, since those are the files that
grant execution.

```powershell
cd fetchpep
New-Item -ItemType Directory -Force -Path .claude\rules, .github\workflows | Out-Null
Move-Item _setup\rules\*.md    .claude\rules\
Move-Item _setup\settings.json .claude\settings.json
Move-Item _setup\checks.yml    .github\workflows\checks.yml
Remove-Item _setup -Recurse -Force
```

```
verify: (Get-ChildItem -Recurse -Force -File | Where-Object FullName -notmatch '\\\.git\\').Count   →   41
```

## 6. First commit and push

```powershell
git lfs install
git add -A
git commit -m "Contract: router, rules, state, specs, hooks, checks, CI"
git push -u origin main
```

```
verify: the Actions tab shows the "contract" workflow, and it is green
```

## 7. Branch protection — before any second commit

GitHub → Settings → Branches → add a rule on `main`: require a pull request, require the
`contract` status check.

Until this exists, every write-authority rule in the contract is advisory.

```
verify: a direct push to main is refused
```

## 8. Claude Code

Install on **this** machine. It is the build seat: it reads `CLAUDE.md`, loads the `paths:`
rules and runs the hooks. Nothing in `hooks/` does anything until it exists.

```
verify: run `claude` from the repo root and ask what CLAUDE.md section 2 says
```

---

# Part 2 — Unity

Do not start until Part 1 is green. A Unity project in the wrong folder is far more painful
to move than a repo of text files.

## 9. Unity CLI and the editor

```powershell
$env:UNITY_CLI_CHANNEL='beta'; irm https://public-cdn.cloud.unity3d.com/hub/prod/cli/install.ps1 | iex
```

Then in a new terminal: `unity auth login`, `unity install`, and `unity install-modules` for
**Android Build Support** and **iOS Build Support**.

```
verify: unity --version, and unity editors lists a 6.x with both modules
```

## 10. Create the project inside the repo

`unity projects create` targeting a subfolder of the repo. Not beside it, not elsewhere.

```
verify: git status shows the new Unity folders as untracked, not ignored entirely
```

## 11. Editor settings — before any asset exists

Project Settings → Editor:

| Setting | Value |
|---|---|
| Asset Serialization | **Force Text** — [certain] already Unity's default; confirm rather than assume |
| Version Control Mode | **Visible Meta Files** |

Retrofitting either after assets exist means regenerating them.

## 12. The editor bridge

```powershell
unity pipeline install
```

Open the project and leave the Editor running.

```
verify: unity status   →   "ready"
```

## 13. Mergetool

[certain] A plain three-way text merge silently breaks scenes. `.gitattributes` already
marks `.unity` and `.prefab` as `merge=unityyamlmerge`; the tool still has to be configured:

```powershell
git config merge.tool unityyamlmerge
git config mergetool.unityyamlmerge.trustExitCode false
git config mergetool.unityyamlmerge.cmd '"C:/Program Files/Unity/Hub/Editor/<version>/Editor/Data/Tools/UnityYAMLMerge.exe" merge -p "$BASE" "$REMOTE" "$LOCAL" "$MERGED"'
```

---

# Part 3 — Release

Not reachable until a signed build exists. Written before it is needed rather than during.

- **Android** — keystore created and **backed up twice, one copy offline, the day it is
  made**. It cannot be regenerated; losing it means never updating the app for anyone who
  installed it. Then signed AAB to the Play internal testing track.
- **iOS** — certificate and provisioning profile generated through Apple's web portal (works
  from Windows), uploaded to Unity Build Automation, which compiles on Unity's cloud Macs
  and outputs a signed IPA for App Store Connect.
- [certain] Personal Play accounts created after 13 Nov 2023 need 12 testers opted in for 14
  continuous days before production access. Internal testing does not. Plan for that clock
  to start when the closed beta does.
