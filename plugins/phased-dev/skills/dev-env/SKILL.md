---
name: dev-env
description: Check the development environment against what the project needs — operating system and architecture, the tools the phased-dev scripts require, and the project's toolchain from the spec (language, SDK, frameworks, database, build and test tools, versions) — detect tools that are missing, too old, or not available for this OS at all, and with the owner's consent install what can be installed; record the environment in docs/ENVIRONMENT.md. Use after the technology level of the spec is confirmed, before the first phase, when moving to a new machine, or when a build fails for environment reasons.
---

# Development environment

The spec chooses a technology; this skill makes sure **this machine** can build,
test and run it — or says early and plainly that it cannot.

## 1. Check

```bash
scripts/check-env.sh
```

It reports the platform (OS, distribution, architecture, WSL, package manager)
and three groups, each line `ok`, `WARN` or `FAIL` with an install command:

- **git and GitHub** — see the `git-setup` skill.
- **method scripts** — bash ≥ 4.3, GNU `find`, `numfmt` and `sha256sum`
  (coreutils), GNU `time`, `file`, and `node` for the caveman hooks. Stock macOS
  lacks most of these; Homebrew provides them (`bash`, `findutils`,
  `coreutils`, `gnu-time`), with the GNU versions put first in `PATH`. Native
  Windows is not supported — use WSL2.
- **project toolchain** — the `TOOLS` list in `scripts/method.conf`: one entry
  per tool, `name|version command|minimum version|purpose|install hint`.

## 2. Keep `TOOLS` in step with the spec

When `docs/SPEC.md` §3 (Technology) is confirmed — and whenever it changes —
translate it into `TOOLS`: every language runtime, SDK, compiler, framework CLI,
database server, build tool, linter and test tool the spec names, with the
version the spec requires. Include tools the tests need (a reference
implementation, a format validator from `docs/DATA.md`, a benchmark harness
from `docs/MEASUREMENTS.md`). Prefer the tool's own installer where that is the
normal route (rustup, uv/pyenv, nvm, sdkman) and put it in the install-hint
field.

## 3. Compatibility with this OS

For each missing or failing tool, decide which of three cases it is:

| Case | Example | What happens |
| --- | --- | --- |
| **Installable here** | `cargo` missing on Linux | step 4 |
| **Available only in another form** | GNU tools on macOS (Homebrew, `g`-prefixed or in `gnubin`); a Linux-only tool under WSL2; a different package name | step 4, with the form stated |
| **Not available for this OS at all** | a Windows-only SDK on Linux; an Apple toolchain on Linux; a target architecture this machine cannot build for | **a question for the owner** |

The third case is never worked around quietly. Record a `Q-n`
(`docs/QUESTIONS.md`, blocking for the tasks that need the tool) with the
options — for example: build and test on another machine or in CI; a container
or VM; cross-compilation; or a different technology choice (which reopens spec
level 2). If it arises while the spec is being written, it is simply part of the
level 2 decision: an option this machine cannot build is marked as such.

Also check the **target platforms** from the spec against this machine: code
that must run on a platform you cannot test here needs CI or another machine to
test it, and that belongs in the plan.

## 4. Install, with consent

Put the install plan to the owner in **one** question (AskUserQuestion): each
tool, the exact command, whether it needs `sudo` or changes the system
(packages, `PATH`, shell profile), and the alternatives. Options: install all
now (recommended when routine) · let me choose · I'll do it myself (show the
commands) · stop.

Then:
- prefer user-level or project-local installs (rustup, uv, nvm, a project
  virtualenv) over system-wide changes;
- install the versions the spec pins, not simply the latest;
- commands that need a password or an interactive login are run by the owner
  (`! <command>` at the Claude Code prompt, or a terminal);
- never edit shell profiles or `PATH` without saying exactly what changes.

## 5. Re-check and record

Run `scripts/check-env.sh` again until there is no `FAIL` (or every remaining
one has an answered question). Then fill `docs/ENVIRONMENT.md`: platform, every
tool with its version and how it was installed, what differs from the target
platforms, and how to set up another machine the same way. Commit it
(`P<n>: record the development environment`).
