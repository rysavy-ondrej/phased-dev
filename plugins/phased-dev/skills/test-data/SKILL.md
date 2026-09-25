---
name: test-data
description: Analyze an optional data corpus the owner provides (demo data, samples, captures, logs, datasets) and describe it in docs/DATA.md — structure, value distributions, cases present, sensitivity, and which spec behaviour it covers — then create synthetic test data from that description with deterministic, seeded generators whose output is validated independently. Use when the owner provides sample data, when a task or phase needs fixtures, when coverage has gaps (edge cases, malformed input), or when real data cannot be committed.
---

# Test data

Two jobs, usually in this order: **understand the data that exists** and
describe it so any agent can use it without re-reading it; then **make the data
that does not exist** — synthetic, reproducible, validated.

Read `docs/SPEC.md` (the formats and behaviour rules the data must exercise),
`docs/DATA.md`, `docs/PROVENANCE.md`, `docs/TEST_DATA.md`, and the current mode
in `docs/STATUS.md`.

## Part 1 — Analyze a corpus

The owner may provide a corpus: demo data, samples, real captures, logs, a
database dump. It is optional; without one, skip to Part 2 and derive the
structure from the spec.

### 1.1 Place it and protect it

- Keep the corpus where the owner put it, or under `data/<set>/`. Large or
  sensitive data stays **out of git** (`.gitignore`); `PROVENANCE.md` records
  where it came from and how to obtain it again. Ask before moving anything.
- Add its path to `PROTECTED_RE` in `scripts/method.conf` — no task edits it.
- Ask the owner once whether it is **sensitive** (personal data, credentials,
  real network traffic, customer data). If yes: descriptions contain statistics
  and structure, never raw values; examples in the card are synthetic look-alikes.

### 1.2 Profile it with scripts, not by reading

Reading files into the conversation is expensive and, for sensitive data,
wrong. Work outward from cheap to specific:

1. `scripts/data-inventory.sh <corpus>` — counts, formats, sizes, empty files,
   examples per type.
2. **Per format, a profiling script** using the right tool — `jq` / Python for
   JSON and CSV, `tshark`/`capinfos` for captures, `sqlite3` for databases, the
   format's own parser otherwise — that prints the structure and statistics
   listed in `references/dataset-card.md`. Sample large sets (state the sample
   and the seed). Keep useful profilers under `scripts/data/` so the card can be
   regenerated when the corpus changes.
3. Open individual records only to understand something the statistics cannot
   show, and only small ones.

### 1.3 Describe it — the dataset card

For each set, a card in `docs/DATA.md` following `references/dataset-card.md`:
what it is, its structure (schema/grammar, fields, types, units), distributions
and ranges, relationships and ordering, the **cases present** (typical,
boundary, empty, malformed, rare), quality problems, sensitivity and rules of
use, and **what it is good for** in each mode. Write it so an agent that never
saw the data can use it: which file to reach for when testing X.

### 1.4 Map it to the spec

Fill the *Coverage* table: for each behaviour rule and component in
`SPEC.md` §4, which files exercise it and which cases they contain. What no file
covers is a **gap** — a row in `TEST_DATA.md` and a synthesis target. If the
corpus shows behaviour the spec does not describe, or contradicts it, that is a
question (`question` skill), not something to fix quietly in the card.

Commit: `P0: describe corpus <set>` (or the phase prefix if during a phase).

## Part 2 — Create synthetic data

Synthetic data fills the gaps, replaces sensitive data that cannot be
committed, and supplies the edge and malformed cases no real sample contains.
The rules in `references/synthesis.md` are binding; the essentials:

1. **Generators, not blobs.** A small program under `tests/data-gen/` (or the
   language's fixture convention) produces the data from a **seed**. Same seed,
   same bytes. The generator is committed; small outputs may be committed too,
   large ones are generated at test time.
2. **Built from the card.** Structure, value ranges and distributions come from
   the dataset card (or the spec, when there is no corpus). Say in the
   generator's header which card and which spec rules it follows.
3. **Validated by something other than our code.** Every generated file is
   checked by an independent reader of its format — the reference tool, a
   standard parser, a schema validator. A fixture only our own parser accepts
   proves nothing.
4. **Expected results never come from the code under test.** Where the
   authority exists, run it on the synthetic input to produce the expected
   output. Otherwise derive the expectation by hand from the spec, state it
   literally in the test, and mark it. An expectation computed by our own
   implementation is a test that cannot fail.
5. **Depth by mode.** Prototype: a small, typical, realistic demo set — enough
   to show the functionality end to end. Harnessing: boundary, empty, rare and
   malformed cases, one generator per case family, and the coverage table filled.
   Production: large and hostile inputs, fuzz seeds, performance-sized sets.

Record every generated set: a card in `DATA.md` (kind: synthetic, generator,
seed, what it covers), a row in `PROVENANCE.md` (generator path and version,
seed, the validating tool and its version), and close the `TEST_DATA.md` gaps it
fills.

## When it runs

- **At `start` / `specify` level 0**, if the owner mentions or supplies data:
  Part 1, so the spec's behaviour rules can be checked against real examples.
- **At `specify` level 3**: behaviour rules are verified against the corpus
  where it covers them; unobserved rules are marked *hypothesis*.
- **At `prepare-phase`**: the phase's fixtures are chosen from `DATA.md`; missing
  ones become synthesis tasks in the phase (or are generated during preparation
  if small).
- **At the start of harnessing**: a synthesis pass for the edge and malformed
  cases the prototype skipped (`kind: hardening` entries in `FEATURES.md`).
- Whenever the owner adds data: re-run the inventory and update the card.
