# Phase report

Written by the `gate` skill when a phase is complete, as
`docs/reports/<PROJECT>_phase_<N>.md` (`PROJECT` from `scripts/method.conf`),
committed before the push and linked from `docs/STATUS.md`. It is for the
**owner and anyone who wants to try the software**: what exists now, how to run
it, and what it does and does not do yet.

Rules:
- **Every command in it was run** at the gate, on this commit, and every output
  is pasted from that run (trimmed with `…` where long, never edited). An example
  that was not run is not in the report.
- **Specified vs implemented is explicit.** Nothing planned is described as if
  it worked.
- Plain language first; details after. Normal prose even when caveman is on —
  it is a document.
- If the gate did not pass, the report still gets written, and says so at the
  top.

## Template

````markdown
# <Project> — phase <N>: <phase title>

**Mode:** prototype | harnessing | production · **Date:** <YYYY-MM-DD> ·
**Commit:** <short sha> · **Gate:** passed | FAILED (<what>) · **Pushed:** yes | no

## In short

<Three to five sentences: what the software can do now that it could not before
this phase, and the most important limitation.>

## What was done

| Task | What it delivered | Commit |
| --- | --- | --- |
| T<N>.1 | … | <sha> |

<Decisions taken during the phase that change what the owner sees: answered
questions (Q-n), measurement decisions (M-n → D-n), feature dispositions (F-n).>

## Try it

### Get it running

```bash
<the exact commands to build/install from a fresh clone, as run at the gate>
```

### <Section by kind of software — pick the ones that apply>

**Command-line tool** — usage as specified, and what is implemented:

```
<synopsis from the spec, e.g. logsum [OPTIONS] <LOGFILE>...>
```

| Command / option | Specified behaviour | Status |
| --- | --- | --- |
| `<LOGFILE>` | nginx combined log, plain | ✅ works |
| `--format json` | JSON report | ✅ works |
| `<LOGFILE>.gz` | gzipped input | ⏳ harnessing (F-3) — refused with "gzip not supported yet (F-3)" |
| `--top N` | top N URLs | ❌ not started — phase 4 |

Statuses: ✅ works (verified) · ⚠️ works, not validated (UNVALIDATED.md) ·
⏳ planned for a later phase or mode (says which) · ⛔ refused visibly until then
(names the F-n) · ❌ not started.

**Library** — the public API as specified vs implemented, and a runnable example.
**Service / API** — how to start it, each endpoint's status, `curl` examples.
**GUI / app** — how to launch it, which screens and actions work.
**Data pipeline** — input, output, how to run it on the sample data.

### Examples

```console
$ <command, as run at the gate>
<real output, trimmed with … if long>
```

<Two to five examples: the main scenario first (for a prototype, the
demonstration), then one showing a limitation behaving honestly.>

## Tests and evidence

- Gate: `scripts/gate.sh <N>` — <n checks, n failures>
- Phase exit criterion: <what was run, the result>
- Tests: <counts; for harnessing/production, conformance numbers>
- Measurements: <M-n results, if any>

## Known limitations

- <What does not work yet, and when it will (phase / mode / F-n)>
- <Divergences from the authority (DIVERGENCES.md) that a user would notice>

## Open items

- Questions still open: <Q-n, or none>
- Backlog added this phase: <count, most important one>

## Next

<The next phase and what it will add — or, at the end of a mode, what the next
mode will do.>
````
