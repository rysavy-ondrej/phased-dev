---
name: specify
description: Step 2 of the phased-dev method — design docs/SPEC.md top-down and interactively from the owner's (possibly abstract) concept. The agent proposes, the owner decides, level by level — understanding and scope, architecture and component boundaries, technology (language, SDK, frameworks, database, UI, platform), each component's contract and pattern, cross-cutting rules — presenting viable options with trade-offs at each major decision and not starting a level until the one above is confirmed. Use after start, to continue an unfinished spec, or when a spec decision must be revisited.
---

# Specify

**The agent designs; the owner decides.** The concept may say little more than
the goal. The spec is built from it top-down, one level at a time, and every
major decision is the owner's: the agent proposes viable options with their
trade-offs and a recommendation, the owner picks one or gives their own. Nothing
at a lower level is designed on an unconfirmed higher level.

Read `docs/CONCEPT.md`, `docs/SPEC.md` (its *Progress* table says where to
continue — this skill resumes at the first level not confirmed), the decision
log, and `docs/QUESTIONS.md`.

## The loop, at every level

1. **Draft** the level in `docs/SPEC.md`, using everything confirmed above it and
   everything the concept says. Where the concept already decides something (it
   names the language, the database, the platform), carry it in and mark its
   source — it still gets confirmed, but as a pre-filled choice, not an open one.
2. **Find the decision points**: the places where more than one design is viable
   and the choice matters — it changes cost, capability, risk, or what the owner
   will have to live with. Those are the owner's. Anything with a single viable
   option given what is confirmed is **obvious**: decide it, log it as
   `agent (obvious)`, and list it for veto.
3. **Present** each decision point as described in `references/decision-points.md`:
   2–4 viable options, each with what it is, what it costs, what it gives, when
   it is the wrong choice; your recommendation first. Ask with
   **AskUserQuestion** — up to four decision points per round, a preview (a small
   diagram or code sketch) where comparing shapes helps. The owner can always
   answer "Other" with their own suggestion; evaluate it honestly — if it has a
   problem, say so and ask again rather than silently adjusting it.
4. **Record** every answer in the level's text and in the *Decision log*
   (`D-n`, options considered, chosen, `owner` or `agent (obvious)`, date).
5. **Confirm the level**: show the owner a short summary of the level as it now
   stands, plus the obvious decisions you took for veto, and ask for
   confirmation. Set its row in *Progress* to `confirmed <date>` and commit
   (`P0: spec level <n> confirmed`). Then the next level.

**Ask only major questions.** A question the owner would answer "whatever you
think" is not a decision point — decide it, log it. A round of questions is at
most four; if a level has more, the level is too big or the options are too
fine-grained.

**Some choices need numbers.** When options differ mainly in speed, memory or
another measurable property and the difference is not obvious, propose to
**decide by measurement** instead of by opinion. If the owner agrees: keep two
or more candidates in the spec, all behind the **same contract** (if they cannot
share one, the choice is architectural and is decided now); add an `M-n` row to
`docs/MEASUREMENTS.md` with the question, the candidates, the workload and the
**decision rule** (criteria and thresholds, agreed now, before any number
exists); log the decision point as `pending M-n`. The level can still be
confirmed — as *confirmed, pending M-n* — and the `plan` schedules the
measurement before anything that depends on it (`measure` skill).

**Going back is allowed, silently changing is not.** If a lower level shows a
higher decision was wrong (a component cannot meet its contract in the chosen
technology), mark the higher level *reopened*, explain why, and put it back to
the owner as a decision point.

## The levels

**Level 0 — Understanding and scope.** Restate the concept concretely: goal,
users, main functionality as a short list of use cases, in and out of scope, the
scenario the prototype will demonstrate, the authority, priorities. For an
abstract concept this is where most of the interpretation happens, so decision
points here are *interpretations*: "by 'monitor the network' do you mean (a)
live capture, (b) reading capture files, (c) both?" Wishes for later go into
`FEATURES.md` as `future cycle`. If the owner has sample data, run `test-data`
(Part 1) now: a described corpus makes every later level more concrete, and
real examples settle interpretation questions faster than options do.

**Level 1 — Architecture.** The architectural style and why; the components,
each with one responsibility (a description that needs "and" is two); the
boundaries between them and to the outside world — names, direction and what
they carry, **not** yet the full contracts. Typical decision points: the style
(pipeline vs layered vs event-driven …), where a responsibility lives, a split
or merge of components, what is a component of its own. Present the options as
small diagrams. No dependency cycles.

**Level 2 — Technology.** Pre-filled from the concept: language, SDK/runtime,
frameworks, database/storage, user interface, target platforms and deployment,
build, test tooling and lint. Then the allowed libraries — few, maintained,
each justified against writing it. Technology is chosen *for the confirmed
architecture*: if the concept's technology cannot serve it, that is a decision
point, not a quiet substitution. Typical decision points: each unset concern,
each library with a credible alternative.

**Level 3 — Components and contracts**, one component at a time (or a few small
ones per round), in the order the plan will build them — boundaries used by many
first. For each: the pattern it follows and why; its contract written as code in
the chosen language (interface, trait, typed signatures) with inputs, outputs,
errors, pre/postconditions, ownership, an example and the contract test; its
behaviour rules, precise enough to test, citing the authority; its external
interface if it has one. Check each behaviour rule against the data described
in `docs/DATA.md` where it covers the rule; a rule no data shows is marked
*hypothesis* and its gap goes to `TEST_DATA.md`. Typical decision points: the shape of a contract (sync
vs async, push vs pull, error model), the pattern, a behaviour the authority
leaves ambiguous. If there is a reference implementation, read it here for each
component's observable behaviour (copy it to `docs/reference/`, mark it
protected in `scripts/method.conf`; fan large ones out to Explore agents that
return rules with file:line citations).

**Level 4 — Cross-cutting rules.** Complexity budget (function length, nesting,
parameters, module size, dependencies) and the lint that enforces it; one policy
each for errors, logging and configuration; quality targets per mode. Usually
few decision points — mostly the budget's numbers and the production targets.

## When the spec is confirmed

- Fill `CLAUDE.md`: *What this project is*, *Invariants* (behaviour rules a
  sensible design gets wrong by default, with citations), *Technology
  constraints*, the *Design rules* component table, *The output contract*, the
  language-specific *Non-negotiables*, *Conventions*.
- Fill `scripts/method.conf`: the real `CHECKS` (format, lint incl. the
  complexity rules, test), `GATE_CHECKS`, the determinism command.
- Test data: `docs/PROVENANCE.md` (origin, producing tool **and version**,
  regeneration, in git or not) and `docs/TEST_DATA.md` (missing, and which mode
  needs it).
- `grep -n '{{' CLAUDE.md docs/SPEC.md` shows nothing the spec needs.
- Final confirmation from the owner over the whole spec (a summary per level and
  the full decision log); mark every level confirmed; commit
  `P0: specification confirmed`. Then `plan`.

## Across sessions

The *Progress* table and the decision log are the state. A spec can be designed
over several sessions: `status` shows which level waits for the owner, and this
skill resumes at the first unconfirmed level. A level left *proposed* has its
open decision points recorded as `Q-n` entries (`Affects: spec level <n>`), so
nothing waits only in a conversation.
