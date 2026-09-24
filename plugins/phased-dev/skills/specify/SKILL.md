---
name: specify
description: Step 2 of the phased-dev method — extract the observable contract from the authority into CLAUDE.md (invariants a sensible design gets wrong, architecture seams, output contract, code non-negotiables) and locate the test data (PROVENANCE, TEST_DATA). Use after conceive, or when a project needs its specification written or corrected.
---

# Specify

Goal: `CLAUDE.md` holds everything an implementer must not get wrong, each item
traceable to the authority; the test data is located, its provenance written.

Read `docs/CONCEPT.md` first. If the profile is prototype, keep *the question* in
view the whole time: specify what the question needs, and park the rest.

## 1. Read the authority — for the contract, not the design

Copy the authority into the repo if it is not there (`docs/reference/`), and
mark that path protected in `scripts/method.conf` (`PROTECTED_RE`). Then read it
to extract the **observable contract**: what goes in, what comes out, and every
rule that decides the output. Do not plan to port it line by line; the authority
is the spec, not the design.

For a large authority, fan the reading out to Explore agents by area, each
returning rules with file:line citations — not summaries.

## 2. Write the invariants

In `CLAUDE.md` → *Invariants*, list the rules a **sensible from-scratch design
gets wrong by default**. Not every rule — the ones where good instincts lead
astray: an id that survives a reset, a direction chosen by a quirky comparison, a
counter taken from an unexpected field, a number formatted with a specific
printf, key order that must be preserved, a time source that is data time and
not wall time. Each one:

- states the rule precisely enough to write a test from,
- cites the authority (file:line),
- says what goes wrong if the "better" design is used.

Where the authority is non-deterministic or buggy, say so, and say what we emit
instead (it becomes a `DIVERGENCES.md` entry). Where our design intentionally
extends the authority, say which part of the comparison is gated and which is
reported as an extension.

**Verify each invariant against the goldens**, not only the source. An invariant
you could not observe in real output is a hypothesis; mark it so.

## 3. Architecture seams

Identify the axes of change (where input comes from, which formats/protocols are
understood, how output is serialised, where it is delivered…). One interface per
axis, in the *Architecture seams* table, with the rule that adding to one never
touches another. Keep platform-specific code behind one seam.

Prototype: define the seams the graduated product will need, even if only one
implementation exists behind each. A seam is cheap now and a rewrite later; this
is what lets parked features plug in without restructuring.

## 4. Output contract and non-negotiables

- *The output contract*: what the output channel may carry, and nothing else;
  which terminal modes are exempt.
- *Non-negotiables*: never crash on input, never lie in the output, and the
  language-specific rules (error types, panics, unsafe, allocation policy).
  Prototype keeps "never crash" to *never crash silently or with a wrong result*;
  robustness beyond that is *Deferred hardening*.

## 5. Test data

Fill `docs/PROVENANCE.md` — every set: path, origin, the tool and **version**
that produced it, how to regenerate it, whether it is in git — and
`docs/TEST_DATA.md` with what is still missing and which phase needs it. If data
cannot be committed, write a fetch script for what is public and say where the
rest comes from.

Check goldens for staleness (schema drift, fields the current authority no longer
writes). Record known defects in PROVENANCE with which set is the authority for
which field instead.

## 6. Parked during specification (prototype)

Reading an authority always surfaces features the question does not need. Each
one: invoke the `park` skill (or write the `OOS-n` entry directly) and move on.
Do not write invariants for parked features.

## 7. Review

Before `plan`: every `{{placeholder}}` in `CLAUDE.md` is filled
(`grep -n '{{' CLAUDE.md`), and the owner has seen the invariants list — it is the
part of the specification most expensive to get wrong.
