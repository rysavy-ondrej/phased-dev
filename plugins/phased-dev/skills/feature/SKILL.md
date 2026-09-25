---
name: feature
description: Record a new requirement or deferred hardening in docs/FEATURES.md instead of building or forgetting it; keep the code refusing it visibly; the owner disposes of it (later phase, later mode, future cycle, rejected). Use when a new idea comes up mid-work or the user says park/later.
---

# Feature

New requirements appear once real code exists. Building them inside an
unrelated task breaks the plan and the budget; dropping them loses them.
Recording one costs a few lines.

## Is it a feature entry?

- **Yes:** something not in the current task's requirement that someone would
  want — a new capability, an option, a format, a protocol (`kind: feature`); or
  something the current mode deliberately skips that a later mode must do — an
  edge case, a harness, error polish, performance (`kind: hardening`).
- **No — it is a question** if you cannot tell whether the spec wants it
  (`question` skill).
- **No — it is a stop** if the current task's own requirement needs it: leaving
  it out would silently narrow the task.
- **No — it is a backlog item** if it is a defect in something already built.

## Record it

`docs/FEATURES.md` → *Entries*, next free id (never reused):

```markdown
### F-12 — <short name>
**Kind:** feature | hardening. **Raised:** <T2.3 | review | owner>, <YYYY-MM-DD>.
**What:** <one or two sentences>.
**Why now / why not now:** <…>.
**If reached before it exists:** <the program refuses with "… (F-12)" | skips and counts it on stderr | not reachable>.
**Size and boundary:** <S/M/L; the module and contract it plugs into>.
**Disposition:** proposed
```

Prototype work records its skipped hardening with `Disposition: mode:
harnessing` directly — the allocation already decided it; the owner confirms at
the gate.

## Keep the code honest

If input can reach the missing feature, the *If reached* line must be true in
code: a refusal naming the entry, or a counted, visible skip — never a plausible
default. Add a test only when the refusal protects a result from being wrong.

Commit the entry with the current task, or alone as `P<N>: record F-12`. Mention
the id in the progress line so the owner sees it.

## Disposition (owner only, at the phase gate)

- **planned: T4.3** — added as a task to a later phase of this cycle (write the
  task into the plan; it is prepared with that phase);
- **mode: harnessing | production** — picked up when that mode is planned;
- **future cycle** — wanted, after this cycle's release;
- **rejected** — with the reason; the entry stays.
