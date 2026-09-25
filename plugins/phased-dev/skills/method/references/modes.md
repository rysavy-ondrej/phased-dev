# Modes compared

The three modes are consecutive stages of one project. The plan's *Mode
allocation* table says which part of the spec is built in which.

| Aspect | prototype | harnessing | production |
| --- | --- | --- | --- |
| Purpose | show it works end to end, fast and cheap | make it trustworthy | make it complete |
| Scope | main path, expected input, every seam touched once | tests, conformance, edge cases, error handling, shortcut removal | remaining features, robustness, performance, packaging, CI, portability, docs |
| Explicitly not | edge cases, harness, polish, secondary features | new features | — |
| Small test per task | one demonstration test on typical input | every named behaviour, incl. edge and malformed input | + fuzz targets for untrusted input |
| Implementer proves tests can fail | no | no — the verifier does | no — the verifier does |
| Verifier | works? does the demo test really exercise it? output honest on unhandled input? | mutation of every new test | mutation of every new test; hostile inputs |
| Verifier granularity | one per implementation group | one per task | one per task |
| Repair rounds | 1 | 3 | 3 |
| Comprehensive test | the phase's demonstration on sample data | exit criterion on the full data + conformance | + performance targets, fuzz runs |
| Phase review | one short combined review | tests + conformance lenses | seams, tests, robustness, conformance + critic |
| Commit / push | per task / per phase | per task / per phase | per task / per phase |

## Never relaxed

- The prime directive (the authority wins).
- Never lie in the output: unhandled input is refused or visibly skipped.
- A test that exists can fail.
- One commit per task; push per phase; linear history.
- Questions are recorded and answered; new features are recorded, not built on
  the side.
- Failure is a stop.

## Moving between modes

- **Prototype → harnessing** after the prototype exit demonstration passes.
  Plan the harnessing phases in detail from: the *Harnessing* column of the mode
  allocation, every `kind: hardening` entry with `Disposition: mode: harnessing`,
  and the prototype phases' backlog. Re-check every `UNVALIDATED.md` entry — new
  consumers disqualify leaves.
- **Harnessing → production** after conformance holds on the full data. Plan from
  the *Production* column, `mode: production` entries, and `planned` features.
- The current mode is recorded in `docs/STATUS.md`.
