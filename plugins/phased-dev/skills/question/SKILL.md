---
name: question
description: Record a question that arises during concept review, specification, planning or implementation in docs/QUESTIONS.md, decide whether it blocks the current task, and get it answered by the owner at the right time. Use when something about what to build is ambiguous or undecided, when a library outside the allowed list seems needed, or when the user asks to record or answer questions.
---

# Question

Not everything can be anticipated. A question recorded is a decision the owner
makes; a question not recorded is a decision an agent made silently.

## Is it a question?

Yes, if the answer changes what gets built and the concept, spec and plan do not
settle it: an ambiguous requirement, two reasonable designs, a library not in
*Allowed libraries*, behaviour of the authority that looks like a bug, a scope
boundary. Not a question: anything the documents or the authority answer — look
first.

## Record it

`docs/QUESTIONS.md` → *Open*, next free id (never reused):

```markdown
### Q-7 — <the question, one line>
**Raised:** <T2.3 | spec §4 | review>, <YYYY-MM-DD>. **Affects:** <phase 3 | T2.3 | spec>. **Blocking:** yes | no
**Options:** (a) … (b) … — **Recommended:** (a), because …
**Assumption meanwhile:** <non-blocking only: what the work assumes until answered>
```

## Blocking or not

- **Blocking** — the answer changes what the current task builds, or a wrong
  guess would be expensive to undo. Stop the task (commit nothing half-done),
  ask the owner now, record the pause in STATUS if the owner is not available.
- **Non-blocking** — proceed on the stated assumption, and mention it in the
  task's commit message. It must still be answered before the next phase is
  prepared (`prepare-phase` and `gate` enforce this).

## Answer it

Ask with AskUserQuestion when there are clear options (batch several questions
in one round), plain text otherwise. Move the entry to *Answered*:

```markdown
### Q-7 — <question>
**Answer:** <…> — <owner>, <YYYY-MM-DD>. **Consequence:** <spec §4 updated | new task T3.5 | assumption held, none>
```

If the answer contradicts the assumption work proceeded on, the fix is a task —
added to the current phase if it is still open, otherwise to the next.
