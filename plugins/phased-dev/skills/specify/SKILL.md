---
name: specify
description: Step 2 of the phased-dev method — derive docs/SPEC.md from the owner's concept and answered questions: architecture and components, languages, frameworks, allowed libraries, interfaces, precise behaviour, quality targets per mode, and decisions; fill CLAUDE.md's invariants, technology constraints and seams; locate test data. Every spec question must be answered and the owner must confirm the spec. Use after start, or when the spec needs writing or revising.
---

# Specify

The spec adds what the concept leaves open — **how** it will be built — and
must not contradict the concept. Read `docs/CONCEPT.md`, `docs/QUESTIONS.md`
(answered and open) and the authority, if there is one.

## 1. Read the authority for the contract

If there is a reference implementation, standard or golden output, copy it into
the repo (`docs/reference/`), mark it protected in `scripts/method.conf`
(`PROTECTED_RE`), and read it for the **observable contract**: inputs, outputs,
and every rule that decides the output. Do not plan to port it line by line. For
a large authority, fan the reading out to Explore agents by area, each returning
rules with file:line citations.

## 2. Draft `docs/SPEC.md`

Work through its sections, proposing a choice wherever the concept is silent and
giving the reason:

1. **Scope** — from the concept; later-cycle wishes become `F-n` entries
   (`feature` skill, disposition `future cycle`).
2. **Architecture** — components, data flow, and the **seams** (one interface per
   axis of change). Define the seams the product will need even if the prototype
   has one implementation behind each: a seam is cheap now and a rewrite later.
3. **Technology** — language(s), frameworks, build, targets, test tooling.
4. **Allowed libraries** — each with version, purpose, where it may be used,
   licence. This list is closed: nothing else gets used without an answered
   question. Prefer few, well-maintained libraries; say why each beats writing it.
5. **Interfaces** — CLI/API, formats, with examples.
6. **Behaviour** — rules precise enough to write a test from, each citing the
   authority. Verify each against real output where outputs exist; an unobserved
   rule is a hypothesis and is marked so.
7. **Quality targets per mode** — what counts as evidence of correctness,
   performance and robustness in prototype, harnessing and production.
8. **Decisions** — every choice someone may reopen, with the reason.

## 3. Ask, do not assume

Every choice the owner might reasonably make differently — language, framework,
a library, an architectural trade-off, a scope boundary — is a `Q-n` tagged
`Affects: spec`, with options and a recommendation. Ask them in one round
(AskUserQuestion). The spec is **not final while any `spec` question is open**;
answers go into the spec's text and *Decisions* table with the date.

## 4. Fill `CLAUDE.md`

- *Invariants*: the behaviour rules a sensible design gets **wrong by default**
  (an id that survives a reset, a quirky direction rule, a counter from an
  unexpected field, exact number formatting, preserved key order, data time vs
  wall time) — each with its citation and what breaks if "improved".
- *Technology constraints*, *Architecture seams*, *The output contract*, the
  language-specific *Non-negotiables*, *Conventions*.
- `scripts/method.conf`: the real `CHECKS` (format, lint, test), `GATE_CHECKS`,
  and the determinism command for the chosen toolchain.

## 5. Test data

`docs/PROVENANCE.md`: every data set — path, origin, the tool **and version** that
produced it, how to regenerate it, whether it is in git. `docs/TEST_DATA.md`:
what is missing and which mode needs it (the prototype usually needs only a
small sample; harnessing needs the full comparison set). Check goldens for
staleness and record known defects.

## 6. Confirm

`grep -n '{{' CLAUDE.md docs/SPEC.md` returns nothing that the spec needs. Show
the owner the architecture, the technology and library choices and the
invariants, and get confirmation; mark the spec `confirmed by owner on <date>`.
Then `plan`.
