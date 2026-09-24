---
name: gate
description: Step 5 of the phased-dev method — close a phase: run scripts/gate.sh and the phase's exit criterion on real data, re-run every DIVERGENCES claim, review the phase (four lenses plus a critic in production, one combined review in prototype), triage findings into BACKLOG or OUT_OF_SCOPE, write STATUS and the phase history, and push only if the gate passed. Use when all tasks of a phase are committed and verified, or when asked whether a phase is done.
---

# Gate

A phase is not done when its tasks are; it is done when its exit criterion has
passed on real data and nothing blocking was found. The push to the remote is
the only gate, which makes it load-bearing.

## 1. The mechanical gate

```bash
scripts/gate.sh <N>        # or <N><part>, e.g. 3B
```

Checks and gate-only builds, three-run determinism, the phase's boxes all ticked
and no later phase's, free scratch space, and `scripts/phase<N>-gate.sh`. Every
FAIL is a problem. Do not re-check any of it by hand.

If this phase added a way to fail the script cannot see, add the check to
`gate.sh` (section 4) or the phase script now, and **prove it bites** — break the
thing, watch the FAIL, restore — before relying on it.

## 2. What needs judgement

Run by an agent (or yourself) with high effort, "be hard to satisfy":

1. **The exit criterion**, quoted from the plan, on the **real** data — all of it,
   not a sample. Measure any performance claim. Compare with the authority the
   way `CLAUDE.md` says it can be compared (semantic comparison when the
   authority's output is not byte-reproducible; byte comparison for our own
   output across runs).
2. **Every `docs/DIVERGENCES.md` claim is literally true** — run each one.
3. *Prototype*: every parked `OOS-n` behaves as its *If reached* line says.
4. `docs/UNVALIDATED.md`: no entry has gained a consumer this phase (the leaf
   rule).

Record actual commands and real output, not paraphrase. Fix nothing at this
step: the gate is a test, not a repair.

## 3. Review

- **production**: four lenses in parallel — *seams* (anything forcing a refactor
  later, leaking types), *tests* (hollow tests, mutation of the most important
  behaviour per task), *robustness* (crash paths, unchecked indexing, unbounded
  growth, diagnostics reaching the output channel), *conformance* (each task's
  requirement met / partial / unmet; every invariant it could touch) — then a
  **completeness critic** given all findings: what did everyone miss?
- **prototype**: one combined review: claims met, central assertions survive
  mutation, no path produces a plausible wrong result, nothing out of scope was
  built, nothing needed was parked, no seam forces a rewrite at graduation.

The `run-phase` workflow does steps 2–4 for you. A lens that died did not report
"nothing found"; the gate has not passed until it has reported.

## 4. Triage — or the findings evaporate

Check each observation and finding against the repository **now** (later tasks
fix some), drop duplicates, then:
- defects and improvements in what was built → `docs/BACKLOG.md` under
  `## Phase N`, numbered, one line each with severity, file/symbol, what is
  wrong, the later task that should settle it;
- *prototype*: features or hardening outside the question →
  `docs/OUT_OF_SCOPE.md`;
- **blockers are not triaged** — each becomes a remediation task in the plan
  (`### Phase N gate remediation`, `T<N>.<next>`), implemented with `implement`,
  and the gate is re-run from step 1.

Commit: `P<N>: triage the phase review`.

## 5. Record and push

- `docs/STATUS.md`: the phase row — what is established (with numbers), what the
  gate ran, what it still cannot see, what the next phase inherits. Then a short
  *what it cost and what it taught* section: gate rounds, the defect that
  defined the phase, a rule to add to `CLAUDE.md` if one shape of defect recurred.
  Naming a recurring failure in the constitution is worth more than any amount
  of re-verification.
- When a phase closes, move its long narrative to `docs/history/phase-<N>.md`;
  STATUS says where the project *is*.
- Tick the gate task if the plan has one — by the evidence, not the gate's own
  say-so.
- **Push only if the gate passed**, and only with the owner's go-ahead. Pushing
  a phase whose gate has not passed is allowed when someone needs the work, and
  then STATUS says plainly what failed. Silence about a failed gate is the
  violation.
- After the push, check CI is green before the next phase starts.

## Before the next phase

Run the next phase's readiness check (see `plan`) and write it into the plan.
