# phased-dev

A development method for software built with Claude Code agents — from the
owner's concept notes, through a specification and an implementation plan, to
phased implementation and a finished product. Packaged as a Claude Code plugin.

Extracted from the maestro-enjoy project, where every rule was added after a
measured failure (`plugins/phased-dev/skills/method/references/lessons.md`).

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

## The flow

1. **Concept** — the owner writes `docs/CONCEPT.md` in their own words; it can
   be abstract.
2. **Spec** — designed top-down and interactively: understanding and scope →
   architecture and component boundaries → technology (language, SDK,
   frameworks, database, UI, platform) → each component's contract and pattern →
   cross-cutting rules. At each level the agent proposes viable options with
   trade-offs; the owner chooses or suggests their own, and confirms the level
   before the next begins.
3. **Plan** — proposes which parts of the spec are built in which **mode**, then
   phases 1..N with subphases A, B, C.
4. **Implementation**, phase by phase: prepare (fix task order, answer questions)
   → implement (per task: small tests, **commit**, independent verifier with
   suggested repairs, ☑) → comprehensive tests, review, triage → **push**.

### Three modes, in order

| Mode | Purpose |
| --- | --- |
| **prototype** | demonstrate the functionality end to end, quickly and cheaply — no harness, no edge cases |
| **harnessing** | make the prototype trustworthy: tests, conformance, edge cases, error handling |
| **production** | complete the product: remaining features, robustness, performance, packaging, docs |

The mode sets test depth, verification strength and review size. It never
relaxes honesty of the output, tests that can fail, commit per task, or
"failure is a stop".

## Skills

| Skill | When |
| --- | --- |
| `/phased-dev:method` | overview; what comes next |
| `/phased-dev:start` | begin from concept notes: scaffold, note what the concept decides |
| `/phased-dev:specify` | design the spec with the owner, level by level; resumes at the first unconfirmed level |
| `/phased-dev:plan` | spec → mode allocation, phases, tasks |
| `/phased-dev:prepare-phase` | before each phase: order, groups, questions answered, gate script |
| `/phased-dev:implement` | implement a phase: task → commit → verify → ☑, progress after each |
| `/phased-dev:gate` | finish a phase: comprehensive tests, review, triage, push |
| `/phased-dev:status` | where the implementation is, open questions, next step |
| `/phased-dev:question` | record or answer a question |
| `/phased-dev:feature` | record a new requirement → later phase, later mode, or future cycle |
| `/phased-dev:test-data` | describe the owner's sample data; generate synthetic test data from it |
| `/phased-dev:measure` | decide between candidate methods by measuring speed and memory; report for the owner |
| `/phased-dev:resume` | continue after a usage/rate limit or an interruption |
| `/phased-dev:registers` | which document a gap belongs in |

## Test data

The owner can supply a corpus of demo data or samples (optional). The
`test-data` skill profiles it with scripts — not by reading it into the
conversation — and writes a dataset card per set in `docs/DATA.md`: structure,
distributions, cases present, sensitivity, and which spec behaviour it covers.
Gaps are filled with synthetic data from seeded generators, validated by an
independent reader of the format; expected results come from the authority or
the spec, never from the code under test.

## Decisions by measurement

When the choice of a method, algorithm, data structure or library depends on
speed or memory, the spec keeps several candidates behind one contract and an
`M-n` entry with a decision rule agreed in advance. The plan runs the
measurement before anything depends on the choice. The `measure` skill checks
the candidates give the same correct output, benchmarks them on representative
data, writes a reproducible report, and the owner decides.

## Progress, pause and resume

All state is in git. Each task in the plan is ☐ (not started), ◐ (committed, not
yet verified) or ☑ (verified). `scripts/progress.sh` prints the picture and the
next step; `scripts/progress.sh questions` lists the open questions. When a usage
or rate limit is hit, the run pauses cleanly and records it in
`docs/STATUS.md`; `resume` verifies any ◐ task first, then continues.

## What a project gets

`plugins/phased-dev/scripts/scaffold.sh <dir>` (run by `start`) installs, never
overwriting an existing file:

```
CLAUDE.md                        the rules every agent reads
docs/CONCEPT.md                  template for the owner's concept notes
docs/SPEC.md                     architecture, technology, allowed libraries, behaviour
docs/IMPLEMENTATION_PLAN.md      mode allocation, phases, subphases, tasks
docs/QUESTIONS.md FEATURES.md    questions and answers; new features with dispositions
docs/DATA.md                     data catalog: what the test data is, covers, how to make more
docs/MEASUREMENTS.md             choices decided by measurement; reports in docs/measurements/
docs/STATUS.md BACKLOG.md DIVERGENCES.md UNVALIDATED.md PROVENANCE.md TEST_DATA.md
scripts/method.conf              the project's check commands
scripts/task-audit.sh            per-task audit (commit form, markers, green)
scripts/gate.sh                  per-phase mechanical gate
scripts/progress.sh              progress, open questions, next step
scripts/data-inventory.sh        first look at a data corpus (counts, formats, sizes)
scripts/measure.sh               repeated runs: wall time, peak memory, output hash
scripts/phase1-gate.sh           template for a phase's runnable exit criterion
.claude/workflows/run-phase.js   unattended phase runner
```

The scripts are language-agnostic: set `CHECKS`, `GATE_CHECKS` and the
determinism command in `scripts/method.conf` (defaults are for Rust/cargo).
