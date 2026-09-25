# Synthesis rules

Synthetic test data is code. It is reviewed, versioned and verified like code,
because a wrong fixture makes a test pass for the wrong reason.

## 1. Generators

- One generator per **case family** (typical traffic, boundary sizes, truncated
  records, malformed headers …), in `tests/data-gen/` or the language's fixture
  convention, using only libraries in the spec's *Allowed libraries* (adding
  one for generation is a question like any other).
- **Deterministic:** a seed argument; the same seed and generator version give
  identical bytes. Prove it once: generate twice, compare.
- **Header comment:** which dataset card and which spec rules it follows, the
  cases it produces, how to run it.
- **Small and literal where it matters.** For a boundary case, the generator
  writes the exact bytes or values with a comment citing the rule — the same
  rule as fixtures in `CLAUDE.md`: never build the case from the constant under
  test.
- **Realistic where it matters.** For typical data, sample from the
  distributions in the card (value ranges, mixes, cardinalities, ordering), so
  the demo and performance sets look like the owner's data.

## 2. Independent validation

Every generated file is accepted by a reader that is **not ours** before any test
relies on it:

| Data | Independent validator |
| --- | --- |
| Network captures | `tshark -r`, `capinfos` (and `editcap` for conversions) |
| JSON / NDJSON | `jq`, a JSON Schema validator against the spec's schema |
| CSV | the reference consumer, or Python's `csv` with the spec's dialect |
| Binary formats | the format's reference tool or library |
| Anything with an authority | the authority itself |

For **malformed** data the check is inverted: the independent reader must reject
it or report the damage in the expected way — otherwise the case is not the
case it claims to be.

The validation step is a script (`tests/data-gen/validate.sh` or equivalent) run
by the generator's own test, so a changed generator cannot produce unvalidated
output silently.

## 3. Expected outputs

In order of preference:

1. **The authority's output** on the synthetic input (reference implementation,
   standard tool). Record its version in `PROVENANCE.md`: a different version is
   a different baseline.
2. **Derived by hand from the spec**, written literally in the test, with the
   rule cited. Small cases only.
3. **Property checks** when neither is practical: invariants that must hold
   whatever the exact output (counts conserved, ordering preserved, round-trip
   identity, no crash, output parses).

Never: expected output produced by the code under test and pasted back in as the
expectation. That is the self-referential fixture at dataset scale — it cannot
fail. If there is no other source, the feature is unvalidated: register it in
`UNVALIDATED.md` (leaf rule applies).

## 4. Sensitive data

Synthetic look-alikes replace sensitive originals wherever data must be committed
or shown: same structure and statistics, invented values (reserved address
ranges — RFC 5737 / RFC 3849 for IP, `example.com` domains, obviously fake
names). Anonymising a real sample is a last resort and needs the owner's
agreement; record the method.

## 5. Size by mode

| Mode | Synthetic data |
| --- | --- |
| prototype | one small realistic demo set — the prototype exit runs on it |
| harnessing | case families for every boundary, empty, rare and malformed case the spec names; coverage table complete |
| production | large sets for performance targets, hostile inputs, fuzz corpora seeded from the generators |

## 6. Records

For each generated set: a card in `DATA.md` (kind synthetic, generator, seed,
cases, coverage), a `PROVENANCE.md` row (generator path and version, seed,
validator and version, expected-output source), and the `TEST_DATA.md` gaps it
closes.
