---
name: git-setup
description: Check git and the GitHub CLI (gh) — installed, identity set, signed in, repo on main with a reachable GitHub remote — and fix gaps with the owner's consent. Use before the first commit or push, when a push or gh fails, or when asked to set up git/GitHub.
---

# Git and GitHub setup

phased-dev commits after every task and pushes after every phase to **GitHub**,
and reads CI status through `gh`. So both `git` and `gh` must be installed, the
identity set, `gh` signed in, and the repository connected to GitHub.

## 1. Check

```bash
scripts/check-env.sh git
```

(In a project not yet scaffolded, run it from the plugin:
`<skill-dir>/../../templates/scripts/check-env.sh git` — `<skill-dir>` is this
skill's base directory.) It checks, without changing anything:

| Check | Needed because |
| --- | --- |
| `git` installed, ≥ 2.28 | commits; `init.defaultBranch` |
| `user.name` and `user.email` set | every commit carries an author |
| `gh` installed | pushes, repository creation, CI status |
| `gh auth status` signed in | pushes and API calls |
| a git repository, on `main` | the method's history is linear on `main` |
| `origin` is a GitHub URL the signed-in account can see | the phase push |

Every `FAIL` line comes with the install or configuration command for the
package manager it found. All green → report it in one line and stop.

## 2. Ask before changing anything

Collect everything missing and put it to the owner in **one** question
(AskUserQuestion): what is missing, why the method needs it, and the exact
commands that would fix it — including whether they need `sudo`. Options:

- **Install / configure it now** (recommended when the commands are routine);
- **I'll do it myself** — show the commands and stop;
- **Skip for now** — allowed only for what the next step does not need (e.g. no
  remote yet while the spec is being written); record it in `docs/STATUS.md`.

Never install, sign in, create a repository or change git configuration without
this consent.

## 3. Fix, with consent

- **Packages** (`git`, `gh`): run the command the check printed. On older
  Debian/Ubuntu `gh` needs GitHub's own apt repository first — follow
  <https://github.com/cli/cli/blob/trunk/docs/install_linux.md>; on macOS use
  Homebrew; on Windows work inside WSL2.
- **Identity**: ask for the name and email to use (never guess from anything
  else), then `git config --global user.name …` / `user.email …` — or `--local`
  if the owner wants it for this project only.
- **Sign-in**: `gh auth login` is interactive, so the **owner runs it** — in
  Claude Code by typing `! gh auth login` at the prompt, or in a terminal. Then
  re-check.
- **Repository**: `git init -b main` if there is none (ask first).
- **Remote**: ask for the owner/organisation, name and visibility (private by
  default), then `gh repo create <owner>/<name> --private --source . --remote
  origin`. Do not push yet — the first push happens at the first phase gate.

## 4. Re-check and record

Run `scripts/check-env.sh git` again; it must show no `FAIL`. Add the result to
`docs/ENVIRONMENT.md` (versions, account, remote) and mention anything skipped
in `docs/STATUS.md`.
