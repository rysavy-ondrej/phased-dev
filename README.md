# phased-dev

A development method for software built with Claude Code agents — from the
owner's concept notes, through a specification and an implementation plan, to
phased implementation and a finished product. Packaged as a Claude Code plugin.

Extracted from the maestro-enjoy project, where every rule was added after a
measured failure (`plugins/phased-dev/skills/method/references/lessons.md`).

**New here?** [HOWTO.md](HOWTO.md) walks through a project from the first concept
note to a pushed phase, step by step. [CHEATSHEET.md](CHEATSHEET.md) is the
one-page quick reference — it fits one A4 page at about 10 pt; from a browser,
print at 80–85 % scale.

## Install

phased-dev depends on the [caveman](https://github.com/JuliusBrussee/caveman)
plugin, which is installed with it. Add caveman's marketplace first — a
dependency from another marketplace is only resolved when that marketplace is
known:

```bash
claude plugin marketplace add JuliusBrussee/caveman
claude plugin marketplace add rysavy-ondrej/phased-dev
claude plugin install phased-dev@phased-dev
```

The last command installs `caveman@caveman` too (`+ 1 dependency: caveman`).
Without the first line it stops with *Dependency "caveman@caveman" … not found.
Is the "caveman" marketplace added?*. While this repository is private, the
machine needs git access to it (e.g. `gh auth login`).

To work on the plugin itself, clone it and add the local checkout instead:
`claude plugin marketplace add ./phased-dev`.

### Working with caveman

Caveman compresses the agent's chat to save tokens; files, commits and docs stay
in normal prose. phased-dev takes precedence where they meet: task-id commit
subjects, never compressing `CLAUDE.md` or `docs/`, its own verifier and
definition of done, the per-task progress line, and full sentences for decisions
put to the owner. See `plugins/phased-dev/skills/method/references/caveman.md`.

## How it works

1. **Concept** — you write `docs/CONCEPT.md` in your own words; it can be abstract.
2. **Spec** — designed top-down with you: scope → architecture and boundaries →
   technology → component contracts and patterns → cross-cutting rules. The agent
   proposes options with trade-offs; you decide each level.
3. **Plan** — what each **mode** builds, then phases 1..N with subphases A, B, C.
4. **Phases** — prepare (task order, questions answered) → implement (per task:
   tests, **commit**, independent verifier with suggested repairs, ☑) → gate
   (tests, review, **phase report** with how to try it) → **push**.

| Mode | Purpose |
| --- | --- |
| **prototype** | demonstrate the functionality end to end, quickly and cheaply |
| **harnessing** | make it trustworthy: tests, conformance, edge cases, errors |
| **production** | complete it: features, robustness, performance, packaging |

Also built in: sample-data analysis and synthetic test data (`test-data`),
decisions by measurement (`measure`), environment and GitHub checks
(`dev-env`, `git-setup`), progress and open questions (`status`), and clean
pause/resume at usage limits — all state is in git.

## Skills

| Skill | When |
| --- | --- |
| `/phased-dev:method` | overview; what comes next |
| `/phased-dev:start` | begin from concept notes |
| `/phased-dev:specify` | design the spec with you, level by level |
| `/phased-dev:plan` | mode allocation, phases, tasks |
| `/phased-dev:prepare-phase` | before each phase: order, questions, gate script |
| `/phased-dev:implement` | task → commit → verify → ☑, progress after each |
| `/phased-dev:gate` | tests, review, phase report, push |
| `/phased-dev:status` | where things stand, open questions, next step |
| `/phased-dev:question` · `feature` | record a question · a new idea |
| `/phased-dev:test-data` · `measure` | describe/generate test data · measure candidates |
| `/phased-dev:git-setup` · `dev-env` | check git/GitHub · the toolchain, install with consent |
| `/phased-dev:resume` · `registers` | continue after a pause · which document a gap belongs in |

## What a project gets

`plugins/phased-dev/scripts/scaffold.sh <dir>` (run by `start`) installs, never
overwriting an existing file:

```
CLAUDE.md                          the rules every agent reads
docs/CONCEPT.md                    template for your concept notes
docs/SPEC.md                       the design, level by level, with its decision log
docs/IMPLEMENTATION_PLAN.md        mode allocation, phases, subphases, tasks
docs/STATUS.md                     where the project is; pauses
docs/QUESTIONS.md FEATURES.md      questions and answers; new ideas and their fate
docs/DATA.md MEASUREMENTS.md       test data catalog; performance decisions
docs/ENVIRONMENT.md                machines, tools, versions
docs/BACKLOG.md DIVERGENCES.md UNVALIDATED.md PROVENANCE.md TEST_DATA.md
docs/reports/TEMPLATE.md           the phase report template
scripts/method.conf                project name, check commands, toolchain (TOOLS)
scripts/progress.sh                progress, open questions, next step
scripts/task-audit.sh gate.sh      per-task audit; per-phase gate
scripts/phase1-gate.sh             phase 1's runnable exit criterion
scripts/check-env.sh               platform, git/gh, tools
scripts/data-inventory.sh          first look at a data corpus
scripts/measure.sh                 wall time and peak memory over repeated runs
.claude/workflows/run-phase.js     unattended phase runner
```

The scripts are language-agnostic; `specify` fills `scripts/method.conf` with the
project's real build, lint and test commands.
