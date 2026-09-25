---
name: registers
description: Maintain the phased-dev documentation registers — STATUS, QUESTIONS, FEATURES, BACKLOG, DIVERGENCES, UNVALIDATED, DATA, PROVENANCE, TEST_DATA and phase history — deciding which register a gap belongs in and keeping every claim true. Use when recording a known difference, an unchecked feature, a deferred defect, project status, or test-data provenance, or when unsure which document something belongs in.
---

# Registers

Every known gap is written down in exactly one place, with a reason, and every
claim in these files is as checkable as code. The templates are in the
project's `docs/` (scaffolded) or `<skill-dir>/../../templates/docs/`.

## Which register?

| The situation | Register | Meaning |
| --- | --- | --- |
| Something about what to build is undecided | `QUESTIONS.md` | a decision the owner owes |
| A new requirement, or work a mode deliberately skipped | `FEATURES.md` | not built yet, with a disposition |
| We built it and it has a defect or could be better, not blocking | `BACKLOG.md` | deferred work |
| We built it and it differs from the authority on purpose | `DIVERGENCES.md` | a decision, measured |
| We built it and nobody has checked it against anything | `UNVALIDATED.md` | an open question; leaves only |
| Test data: what it is, what it covers, which file for what | `DATA.md` | see the `test-data` skill |
| A choice decided by measurement; evidence for a performance claim | `MEASUREMENTS.md` + `measurements/M-n.md` | see the `measure` skill |
| Test data: where it came from, how to regenerate | `PROVENANCE.md` | |
| Test data we need and do not have | `TEST_DATA.md` | |
| Where the project is now; the current run; pauses | `STATUS.md` | present tense only |
| How it got here | `docs/history/phase-N.md` | moved whole when a phase closes |
| A choice someone may reopen | `SPEC.md` → *Decision log* | dated, with the measurement |

Moves are one-directional: QUESTIONS open → answered; FEATURES proposed →
planned / later mode / future cycle / rejected; UNVALIDATED → DIVERGENCES or
closed; BACKLOG → closed or DIVERGENCES. Never the reverse. Ids are never reused
in any register.

## Rules per register

**DIVERGENCES** — each entry: *What* (observable difference), *Why* (reason or
the authority's bug), *Measured* (how many, on which data), *Held by* (the test
that fails if the claim stops being true). Never used to get past a diff
nobody understands — that is a stop, not a divergence. Re-run at every gate.

**UNVALIDATED** — all three: no authority reachable; it is a **leaf** (nothing
in the code reads it); its status is visible. The leaf rule is load-bearing: when
something starts depending on an entry, close it before that dependency lands.
Before registering, look for an authority — one project filed an entry and then
found a vendored file that validated it. Closed entries move to *Closed entries*
with what closed them.

**BACKLOG** — numbered, numbers never reused; each line: severity, file and
symbol (line numbers drift), what is wrong, the plan task that should settle it.
Closed items are listed with the commit/task that closed them and the test that
holds them closed.

**QUESTIONS** — see the `question` skill. Every open question is answered before
the phase it affects is prepared; blocking ones stop the task at once.

**FEATURES** — see the `feature` skill. Dispositions are the owner's, given at
the phase gate.

**STATUS** — updated in the commit that changes what is true: the current mode;
*Current run* (phase, paused or not and why, next step on resume, blocked on);
one row per phase: state, what is established with numbers, what is not. Task
state itself lives in the plan's markers — `scripts/progress.sh` reads it, so
STATUS does not duplicate it. Never quote a number that
must be re-derived on every commit (e.g. "N commits unpushed"): name the fixed
base and let git compute it. If a gate did not pass and the work was pushed
anyway, say so here, plainly.

**PROVENANCE** — tool **and version** for every generated golden. A golden
regenerated with a different version is a new baseline, not a correction. Known
defects in the data are recorded with evidence and with which set is the
authority for which field instead.

## Prose is code

Help text, doc comments and these files are checked against behaviour. A
sentence that says what the code does not do is a defect, however correct the
code beside it. Where a documented number can drift from the code, add a test
that reads the document and fails when they disagree.
