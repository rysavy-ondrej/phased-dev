---
name: gate
description: Step 6: close a phase — comprehensive tests, review, triage, owner decisions on questions and features, the phase report (docs/reports/<project>_phase_<N>.md: what was done, how to try it), STATUS, push. Use when every task of a phase is ☑.
---

# Gate

A phase is complete when its comprehensive tests pass, not when its tasks do.
The push happens here, once per phase.

## 1. Mechanical

```bash
scripts/gate.sh <N>
```

Green checks and gate-only builds, three-run determinism, the phase prepared and
every task ☑, nothing later started, no open blocking question, free scratch
space, and `scripts/phase<N>-gate.sh`. Every FAIL is a problem; do not re-check
any of it by hand. If the phase added a way to fail that the script cannot see,
add the check now and **prove it bites**.

## 2. Comprehensive test — judgement

By an agent (or yourself), high effort, "be hard to satisfy":

1. **The phase exit criterion** on the real data, all of it. Prototype: the
   demonstration runs and shows what it claims. Harnessing: the conformance
   comparison with the authority, the way `CLAUDE.md` says it can be compared.
   Production: plus the quality targets, measured with the `measure` skill's
   method (a report per target, cited in STATUS).
2. **Every `docs/DIVERGENCES.md` claim** is still literally true — run each.
3. **Unbuilt features** reached by input behave as their `FEATURES.md` entry says.
4. **`docs/UNVALIDATED.md`**: no entry gained a consumer this phase.

Actual commands and real output, not paraphrase. Fix nothing here.

## 3. Review, at the mode's depth

- **prototype** — one short combined review: does the phase demonstrate what it
  set out to, end to end? Is any output a plausible wrong answer? Was harness or
  edge-case work done that belongs to harnessing (cost)? Is a boundary missing
  or a contract bypassed that harnessing will need (rewrite risk)? Is anything
  over the complexity budget?
- **harnessing** — two lenses: *tests* (every new test can fail; fixtures not
  self-referential; coverage of every behaviour rule) and *conformance* (each
  task met / partly / unmet; every invariant it touches).
- **production** — four lenses (design — boundaries, contracts, patterns,
  complexity; tests; robustness; conformance) in parallel,
  then a completeness critic given all findings: what did everyone miss?

The lenses are general-purpose agents with phased-dev's prompts; a caveman
reviewer may add an opinion but is not a lens.

A lens that died has not reported "nothing"; the gate waits for it (see *Pausing*
in the `implement` skill).

## 4. Triage and owner decisions

Check each observation and finding against the code **now**, drop what is fixed
or duplicated, then:
- defects and improvements in what was built → `docs/BACKLOG.md` under
  `## Phase N`, numbered, with severity, file/symbol, and the task that should
  settle it;
- things not built → `docs/FEATURES.md` (`feature` skill);
- **blockers** → remediation tasks in this phase (`T<N>.<next>`), prepared and
  implemented, then the gate re-runs from step 1.

Then with the owner, in one round:
- every `F-n` with `Disposition: proposed` gets a disposition: **planned** (a task
  in a named later phase — add it), **mode: harnessing/production**, **future
  cycle**, or **rejected**;
- every open `Q-n` is answered (`scripts/progress.sh questions`) — the next
  phase cannot be prepared while one affecting it is open.

Commit as `P<N>: triage and dispositions`.

## 5. Phase report

Write `docs/reports/<PROJECT>_phase_<N>.md` (`PROJECT` from
`scripts/method.conf`) following the template in `docs/reports/TEMPLATE.md`
(the same as this skill's `references/phase-report.md`): what the phase
delivered, **how to try it** — for a CLI tool the usage as specified beside what
is actually implemented, for a library its API, for a service its endpoints —
real examples, the test evidence, known limitations and what comes next.

- **Run every command in it now**, on this commit, from a clean build, and paste
  the real output. An example that was not run does not go in.
- Every specified command, option, endpoint or feature appears with its status:
  works · works but unvalidated · planned (which phase/mode) · refused until then
  (which F-n) · not started.
- If the gate failed, write the report anyway and say so at the top.

Commit it with the STATUS update below, tell the owner where it is, and show the
*In short* and *Try it* sections.

## 6. Record, push

- `docs/STATUS.md`: the phase row — what is established (with numbers), what the
  gate cannot see yet, what the next phase inherits; a short *what it cost and
  what it taught* (repair rounds, the defect that recurred — if one did, name the
  rule in `CLAUDE.md`). Clear *Current run*. Move long narrative to
  `docs/history/phase-<N>.md`.
- Before the push, `scripts/check-env.sh git` shows no `FAIL` (signed in, a
  GitHub `origin` the account can reach); fix with `git-setup`.
- The phase report exists (`docs/reports/<PROJECT>_phase_<N>.md`) and STATUS
  links it.
- **Push** (`git push`) once the gate passes, confirming with the owner the first
  time. A push without a passing gate is allowed only when someone needs the
  work, with STATUS saying plainly what failed.
- Check CI after the push.

## 7. Next

- More phases in this mode → `prepare-phase` for phase N+1.
- **Last phase of a mode** (the prototype exit, or conformance reached): update
  the mode in `docs/STATUS.md`, then `plan` the next mode in detail from its
  allocation column, `mode:` dispositions and the backlog.
