# Unvalidated features

Things this program produces that **nobody has checked against an authority**.
Not known-wrong, not known-right: unverified.

| | |
| --- | --- |
| `DIVERGENCES.md` | We know we differ, and why. A decision. |
| **This file** | We do not know whether we match. An open question. |

Moving an entry from here to there, or closing it, is progress; the reverse never
happens.

## When a feature may ship unvalidated

All three, or it does not go in this file:

1. **No authority is reachable** — or obtaining one would move the baseline
   rather than confirm it.
2. **It is a leaf.** Nothing in the codebase reads its output, so a wrong answer
   stays one wrong field. *This is the load-bearing condition.* If something
   starts depending on an entry, the entry must be closed before that dependency
   lands.
3. **Its absence is visible.** A consumer can tell from this file that it is
   unvalidated.

## The register

<!-- ### `field.name` — one line
**Since:** task, date. **What is unvalidated:** ... **What is validated:** ...
**What would close it:** ... -->

## Closed entries
