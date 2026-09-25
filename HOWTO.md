# How to use phased-dev, step by step

This guide takes a project from nothing to a working, tested product with the
phased-dev plugin. It follows one small example throughout — **`logsum`, a tool
that summarises web-server access logs** — so each step shows what you type and
what you get back.

You do three things in this process: **write the concept**, **make the
decisions**, and **review results**. The agent does the rest: it designs,
proposes options, plans, implements, verifies, and reports.

---

## Contents

1. [Install](#1-install)
2. [Create the project and write the concept](#2-create-the-project-and-write-the-concept)
   — [check git and GitHub](#check-git-and-github)
3. [Start](#3-start)
4. [Design the specification together](#4-design-the-specification-together)
   — [set up the development tools](#set-up-the-development-tools)
5. [Describe your sample data (optional)](#5-describe-your-sample-data-optional)
6. [Plan: decide what goes in which mode](#6-plan-decide-what-goes-in-which-mode)
7. [Prepare a phase](#7-prepare-a-phase)
8. [Implement the phase](#8-implement-the-phase)
9. [While it runs: progress, questions, new features](#9-while-it-runs-progress-questions-new-features)
10. [Decisions that need measurement](#10-decisions-that-need-measurement)
11. [Pausing at a usage limit, and resuming](#11-pausing-at-a-usage-limit-and-resuming)
12. [Close the phase: gate and push](#12-close-the-phase-gate-and-push)
13. [Next phases, and moving to the next mode](#13-next-phases-and-moving-to-the-next-mode)
14. [Working with caveman](#14-working-with-caveman)
15. [Updating the plugin](#15-updating-the-plugin)
16. [Troubleshooting](#16-troubleshooting)
17. [Cheat sheet](#17-cheat-sheet)

---

## 1. Install

**You need:** Claude Code, `git`, and access to GitHub (don't worry if `gh` or
other tools are missing — `/phased-dev:git-setup` and `/phased-dev:dev-env` check
and offer to install them later). The phased-dev repository is private, so the
machine needs git access to it — `gh auth login` is the easy way. The scripts use `bash`, `awk` and GNU `time`, which Linux has; `node` is
needed by caveman's hooks.

Run these three commands in a shell, in this order:

```bash
claude plugin marketplace add JuliusBrussee/caveman
```

```bash
claude plugin marketplace add rysavy-ondrej/phased-dev
```

```bash
claude plugin install phased-dev@phased-dev
```

The last one prints `(+ 1 dependency: caveman)`: phased-dev installs the caveman
plugin with it. Caveman makes the agent's chat terse to save tokens; your files
stay in normal prose (see [section 14](#14-working-with-caveman)).

Check it worked:

```bash
claude plugin list
```

Both `caveman@caveman` and `phased-dev@phased-dev` should show `✔ enabled`.
Start a new Claude Code session so the skills load.

> **If the install says** *Dependency "caveman@caveman" … not found. Is the
> "caveman" marketplace added?* — you skipped the first command. Run it, then the
> install again.

---

## 2. Create the project and write the concept

Create an empty directory, make it a git repository, and open Claude Code in it:

```bash
mkdir logsum && cd logsum && git init -b main
```

Now write **`docs/CONCEPT.md`** — in your own words. It is the only document you
write yourself. It can be short and abstract: the goal and the main
functionality are enough. Anything you already know (a language, a database, a
platform, a reference to match, sample data) is worth writing down, because it
becomes a pre-filled choice you only confirm later.

Example:

```markdown
# Concept

## Purpose
A command-line tool that reads web-server access logs and prints a summary:
requests per hour, top URLs, status-code breakdown, slowest endpoints.

## Why
Our ops team greps logs by hand. We want a quick, reliable summary.

## Must do
- Read nginx "combined" format logs, plain or gzipped.
- Output a text report, and JSON for scripts.

## First milestone
Run it on one day's log and see a correct summary.

## Constraints and preferences
Python 3.12. Runs on Linux servers. No database.

## Sample data
Two anonymised days of logs in ~/samples/nginx/ (contain client IPs — sensitive).
```

You don't need to follow the headings — if you skip `docs/CONCEPT.md`
altogether, the next step creates a template for you to fill in.

### Check git and GitHub

The method commits after every task and pushes to GitHub after every phase, so
it needs `git` and the GitHub CLI `gh`. `start` checks them first; you can also
run the check on its own at any time:

```
/phased-dev:git-setup
```

It checks that `git` and `gh` are installed, your name and email are set, `gh`
is signed in, and the repository is on `main` with a GitHub remote your account
can reach. If something is missing it shows you the exact commands and **asks
before installing or changing anything**. Two things you do yourself:

- **Sign in to GitHub**: type `! gh auth login` at the Claude Code prompt (the
  `!` runs it in your shell) and follow the prompts.
- **Choose the repository** name and visibility when it offers to create one
  (`gh repo create …`, private by default). Nothing is pushed until the first
  phase is complete.

---

## 3. Start

In Claude Code, in the project directory:

```
/phased-dev:start
```

What happens:

- The repository is **scaffolded**: `CLAUDE.md` (the rules every agent follows),
  the `docs/` documents, the `scripts/` and a workflow. Existing files — your
  concept — are never overwritten.
- The agent reads your concept and tells you, in a few lines, **what it
  understood the goal to be** and **what the concept already decides** (here:
  Python 3.12, Linux, no database, sample data present and sensitive).
- It does **not** interrogate you. Gaps are filled in the next step, one level
  at a time.

What you get in the repository:

```
CLAUDE.md                        rules for every agent
docs/CONCEPT.md                  yours
docs/SPEC.md                     the specification (filled in step 4)
docs/IMPLEMENTATION_PLAN.md      the plan (step 6)
docs/QUESTIONS.md FEATURES.md    open questions; new feature ideas
docs/DATA.md MEASUREMENTS.md     test data catalog; performance decisions
docs/ENVIRONMENT.md              machines, tools and versions
docs/STATUS.md BACKLOG.md …      status and other registers
scripts/                         progress, audit, gate, environment, data and measurement tools
.claude/workflows/run-phase.js   for unattended runs (step 8)
```

---

## 4. Design the specification together

```
/phased-dev:specify
```

The specification is designed **top-down, in five levels**. At each level the
agent drafts, then asks you about the **decisions that matter** — with 2–4
options, what each gives and costs, and its recommendation first. You pick one,
or choose *Other* and write your own. The agent does not start the next level
until you confirm the current one.

| Level | What is decided | Example decision for logsum |
| --- | --- | --- |
| 0 — Understanding and scope | what the tool does, for whom, in/out of scope, what the prototype will demonstrate | "Does 'slowest endpoints' need response time, which the combined format lacks? (a) require `$request_time` in the log format, (b) drop the feature, (c) later cycle" |
| 1 — Architecture | style, components, boundaries between them | "Pipeline (reader → parser → aggregator → reporter) or a single-pass script?" — shown as small diagrams |
| 2 — Technology | language, SDK, frameworks, storage, UI, platform, libraries | Python 3.12 is pre-filled from your concept — you confirm it. "CLI framework: argparse (stdlib) or click?" |
| 3 — Components and contracts | each component's interface in code, its pattern, its rules | "Parser returns a typed record or a dict? Errors: skip-and-count or stop?" |
| 4 — Cross-cutting | complexity limits, error/logging policy, quality targets per mode | "Function length limit 50 lines, enforced by ruff?" |

Things you should know:

- **Only major questions reach you.** Choices with a single sensible option, or
  ones you'd answer "whatever you think", the agent decides itself. It lists
  them for your veto when you confirm the level.
- **You can go back.** If a later level shows an earlier decision was wrong, the
  agent marks that level *reopened* and asks again. It never changes it quietly.
- **It survives breaks.** `docs/SPEC.md` has a *Progress* table and a *Decision
  log*; run `/phased-dev:specify` again in a later session and it continues at
  the first unconfirmed level.
- **Performance choices can wait for numbers.** If two options differ mainly in
  speed or memory, the agent can propose deciding by measurement instead — see
  [section 10](#10-decisions-that-need-measurement).

The result is a confirmed `docs/SPEC.md` and a filled-in `CLAUDE.md`, including
the real build, lint and test commands in `scripts/method.conf`.

### Set up the development tools

Once the technology (level 2) is confirmed, the agent lists the tools it needs
in `scripts/method.conf` (for logsum: Python ≥ 3.12, ruff, pytest) and runs:

```
/phased-dev:dev-env
```

- It detects your **OS, architecture and package manager**, and checks three
  things: git and GitHub, the tools phased-dev's own scripts need, and the
  project's toolchain with minimum versions.
- For each missing tool it shows the install command and **asks you first**. It
  prefers per-user installs (rustup, uv, nvm) over system-wide ones, and you run
  anything that needs a password yourself (`! sudo …`).
- A tool that **does not exist for your OS** at all is not worked around. It
  becomes a question for you: build in CI or on another machine, use a container,
  or choose different technology.
- On **macOS**, the method's scripts need the GNU versions of a few tools
  (`brew install bash coreutils findutils gnu-time`). On **Windows**, work inside
  WSL2.

The result is recorded in `docs/ENVIRONMENT.md`, including how to set up another
machine the same way. The same check runs again before each phase, and before
each push. In a shell, `scripts/check-env.sh` shows it.

---

## 5. Describe your sample data (optional)

If you have sample data, the agent analyses it — usually during level 0, since
real examples settle questions faster. You can also run it yourself at any time:

```
/phased-dev:test-data
```

- It asks once whether the data is **sensitive** (for logsum: yes, client IPs).
  Sensitive data stays out of git and is described with statistics only.
- It profiles the data **with scripts** rather than reading it into the chat.
  `scripts/data-inventory.sh ~/samples/nginx` is the first look. It writes a
  *dataset card* in `docs/DATA.md`: structure, value ranges, which cases the data
  contains (typical, empty, malformed …), and what it is good for.
- It maps the data to the spec, so you can see which behaviour no sample covers.
  Those gaps are filled with **synthetic data**: seeded generators, checked by an
  independent tool (for logsum, e.g. a real log parser), with expected results
  never produced by the code under test.

No data? Skip this; synthetic data is generated from the spec when a phase needs
it.

---

## 6. Plan: decide what goes in which mode

```
/phased-dev:plan
```

The project passes through **three modes**, in order:

| Mode | Purpose |
| --- | --- |
| **prototype** | show the functionality working end to end, quickly and cheaply — no test harness, no edge cases |
| **harnessing** | make the prototype trustworthy — tests, conformance, edge cases, error handling |
| **production** | complete the product — remaining features, robustness, performance, packaging, docs |

First the agent proposes a **mode allocation**: for every part of the spec, what
the prototype does with it, what harnessing adds, what production adds. For
logsum, for example: *gzip input* — prototype: no; harnessing: yes, with a
truncated-gzip test; production: streaming for large files. **Confirm or adjust
it** — this decision sets the cost of the whole project.

Then the plan is written in `docs/IMPLEMENTATION_PLAN.md`:

- Phases numbered 1..N, split into **subphases** (1A, 1B …) when wide.
- **Subphase 1A builds the boundaries first**: every interface from the spec,
  connected end to end with the simplest implementation (a "walking skeleton").
  Later tasks fill in one component at a time.
- Tasks are small: one component or interface each, one visible result each.
- Only the prototype is planned in detail. Harnessing and production are
  outlined, because the prototype will teach you what they need.

Each task has a marker: **☐** not started · **◐** committed, not yet verified ·
**☑** verified.

---

## 7. Prepare a phase

Before each phase:

```
/phased-dev:prepare-phase
```

This fixes the **task order** and dependencies, groups tasks that touch the same
code, picks the test data from `docs/DATA.md`, writes the phase's test script
(`scripts/phase1-gate.sh`), and — most importantly for you — **collects every
open question that affects the phase and asks you now**, not halfway through a
task. It ends with `Prepared: <date>` in the plan. A phase without it is not
started.

---

## 8. Implement the phase

Two ways, same rules.

**In your session** (the default, and the cheaper one):

```
/phased-dev:implement
```

For each task, in the prepared order:

1. The agent implements it, with small tests at the mode's depth (in the
   prototype, one test showing it works).
2. It **commits** the task (`T1.3: parse the combined format`) and marks it ◐.
3. `scripts/task-audit.sh T1.3` checks the commit follows the rules.
4. An **independent verifier** agent checks the work and reports problems, each
   with a **suggested repair**.
5. Problems are repaired and rechecked (at most 1 round in the prototype, 3
   later).
6. The task is marked ☑, and you get one progress line:
   `T1.3 ☑ (a1b2c3d, 0 repairs) — 3/7 in phase 1 — next: T1.4`.

**Unattended**, for a whole phase — ask Claude to run the workflow:

```
Run the run-phase workflow for phase 1.
```

It does the same with agents and returns a summary. It uses many agents, so it
costs more; use it when you want to step away.

Commits happen after **every task**. Nothing is pushed until the phase is
complete ([step 12](#12-close-the-phase-gate-and-push)).

---

## 9. While it runs: progress, questions, new features

**Where are we?** At any time:

```
/phased-dev:status
```

You get the mode and phase, how many tasks are verified, whether the run is
paused or blocked, **every open question** (blocking ones first), decisions
waiting for you, and the next step. It then offers to take your answers to the
open questions. The same numbers come from the shell with `scripts/progress.sh`,
and `scripts/progress.sh questions` lists just the questions.

**Questions come up.** Not everything can be foreseen. The agent records each one
in `docs/QUESTIONS.md`:

- **Blocking** (the answer changes what gets built): the task stops and you are
  asked.
- **Non-blocking**: work continues on a stated assumption, and you answer before
  the next phase is prepared.

To record or answer one yourself: `/phased-dev:question`.

**New features come up too.** They are **not built on the side**. They go into
`docs/FEATURES.md` as `F-n` entries (or you add one: `/phased-dev:feature`). At
the end of the phase you decide each one:

- **planned** — a task in a later phase;
- **later mode** — picked up in harnessing or production;
- **future cycle** — after this release;
- **rejected**.

Until a feature exists, input that needs it is refused or skipped visibly. It is
never answered wrongly.

---

## 10. Decisions that need measurement

Some choices can only be made with numbers — for logsum, perhaps *"count URLs
with a dict, or with a probabilistic top-k sketch?"* During the spec, the agent
can propose keeping **both candidates** behind the same interface, with a
**decision rule agreed in advance** (e.g. "the sketch, unless its top-10 differs
from the exact count on the sample days"). It is recorded as `M-1` in
`docs/MEASUREMENTS.md`.

The plan then puts a measurement task **before** anything that depends on the
choice. That task runs:

```
/phased-dev:measure
```

1. It builds both candidates minimally.
2. It checks that they give the **same, correct** output.
3. It benchmarks them on your data with `scripts/measure.sh`, which reports wall
   time, peak memory, and whether the output is stable across runs.
4. It writes a reproducible report in `docs/measurements/M-1.md`.

**You decide** from the report. The choice goes into the spec's decision log, and
the tasks that waited for it can proceed.

---

## 11. Pausing at a usage limit, and resuming

Everything is stored in git — the task markers and the commits — so work can
stop at any moment without losing anything.

When a usage or rate limit is hit, the run **pauses cleanly**:

- it never leaves a half-done change committed;
- it records the pause and the reset time in `docs/STATUS.md`;
- it tells you when it can continue.

After the reset:

```
/phased-dev:resume
```

It rebuilds the state from git. It verifies any ◐ task first, because those are
committed but not yet checked, and then continues with the next ☐. If your setup
has a scheduler, the agent can offer to run the resume for you after the reset.

---

## 12. Close the phase: gate and push

When every task of the phase is ☑:

```
/phased-dev:gate
```

1. **Comprehensive tests**: `scripts/gate.sh 1` (build, lint, tests run three
   times for determinism, every task verified, no blocking question open) and the
   phase's own exit test on the real data. For the logsum prototype: *"run on one
   day's log, and the summary matches a hand-checked count."*
2. **Review**, sized to the mode: one short review for a prototype, more for
   later modes.
3. **Triage**: defects go to `docs/BACKLOG.md`, unbuilt things to
   `docs/FEATURES.md`. **You** decide the dispositions of new features and answer
   any open questions.
4. `docs/STATUS.md` is updated, and the phase is **pushed** — once per phase. The
   agent confirms with you the first time.

---

## 13. Next phases, and moving to the next mode

- **Next phase in the same mode**: `/phased-dev:prepare-phase`, then
  `/phased-dev:implement`, then `/phased-dev:gate` again.
- **The prototype is done** when its final demonstration passes. Then run
  `/phased-dev:plan` again. It plans the **harnessing** phases in detail from
  three sources: the harnessing column of the mode allocation, everything the
  prototype deliberately skipped (recorded in `docs/FEATURES.md`), and the
  backlog. Same later for **production**.

The cycle per phase, in short:

```
prepare-phase → implement (task → commit → verify → ☑, repeated) → gate → push
```

---

## 14. Working with caveman

Caveman makes the agent's **chat** short to save tokens. Your files, commits and
docs stay in normal prose. phased-dev's rules take precedence where they meet:

- Commit subjects stay `T1.3: …`, whatever caveman's commit skill suggests.
- `CLAUDE.md` and `docs/` are **never compressed**. The scripts read them.
- The verifier and the phase review use phased-dev's own prompts, not caveman's
  reviewers.
- Questions and options put to you are written in **full sentences**.

Useful commands:

- `/caveman lite` makes the chat less terse;
- `/caveman off` or "normal mode" turns it off for the session;
- a `.caveman.json` file containing `{"defaultMode": "off"}` in the project root
  turns it off for the project.

---

## 15. Updating the plugin

```bash
claude plugin marketplace update phased-dev
```

```bash
claude plugin update phased-dev@phased-dev
```

Restart Claude Code afterwards. Projects already scaffolded keep their copies of
the scripts and templates. To take a newer script, copy it from the plugin by
hand. Re-running the scaffold never overwrites existing files.

---

## 16. Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| `gh` not signed in, or push refused | `/phased-dev:git-setup`, then `! gh auth login` |
| A build tool is missing or too old | `/phased-dev:dev-env` (or `scripts/check-env.sh` in a shell) |
| Install says the caveman marketplace is missing | Run `claude plugin marketplace add JuliusBrussee/caveman`, then install again |
| `/phased-dev:…` commands don't appear | Start a new session after installing; check `claude plugin list` |
| Implement refuses to start | The phase isn't prepared (run `prepare-phase`), a blocking question is open (`status`), or the tree has uncommitted changes |
| `scripts/gate.sh` fails "graded nothing" | A check had no input to test — usually the phase gate script has no checks yet, or test data is missing |
| `task-audit.sh` fails on the commit subject | The subject must start with the task id and a colon (`T1.3: …`) and end with the trailer |
| Work stopped mid-phase | Run `/phased-dev:status` to see why, then `/phased-dev:resume` |
| The chat is too terse to follow | `/caveman lite` or `/caveman off` |

---

## 17. Cheat sheet

| When | Command |
| --- | --- |
| Once, to install | the three commands in [section 1](#1-install) |
| New project | write `docs/CONCEPT.md`, then `/phased-dev:start` |
| Check git / GitHub | `/phased-dev:git-setup` |
| Check or install dev tools | `/phased-dev:dev-env` (shell: `scripts/check-env.sh`) |
| Design the spec | `/phased-dev:specify` (repeat until every level is confirmed) |
| Sample data | `/phased-dev:test-data` |
| Plan | `/phased-dev:plan` |
| Each phase | `/phased-dev:prepare-phase` → `/phased-dev:implement` → `/phased-dev:gate` |
| Anytime: where are we? | `/phased-dev:status` (shell: `scripts/progress.sh`) |
| A question or a new idea | `/phased-dev:question`, `/phased-dev:feature` |
| A performance choice | `/phased-dev:measure` |
| After a pause | `/phased-dev:resume` |
| How the method works | `/phased-dev:method` |

Your part, in one line: **write the concept, make the decisions, review the
results.**
