# Features and deferred work

New feature requirements discovered after the spec was confirmed, and hardening
a phase deliberately did not build. Recording one here is how it is **neither
built inside an unrelated task nor forgotten**. Ids are never reused.

| File | Means |
| --- | --- |
| `BACKLOG.md` | something built has a defect or could be better |
| **this file** | something **not built yet**, and what will happen to it |

## Dispositions

Set by the owner at the phase's triage, never by the implementer:

- **proposed** — recorded, not yet ruled on
- **planned: Tn.m** — added as a task to a later phase of this cycle
- **mode: harnessing | production** — deferred to the first phase in that mode
  (typical for `kind: hardening`)
- **future cycle** — wanted, but after this cycle's release
- **rejected** — with the reason

## Entries

<!--
### F-1 — {{short name}}
**Kind:** feature | hardening. **Raised:** {{T2.3 | review | owner}}, {{date}}.
**What:** {{one or two sentences}}.
**Why now / why not now:** {{…}}.
**If reached before it exists:** {{the program refuses with … / skips and counts … / not reachable}}.
**Size and boundary:** {{S/M/L; the module and contract it plugs into}}.
**Disposition:** proposed
-->
