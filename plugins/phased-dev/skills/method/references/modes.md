# Moving between modes

The *Modes* table in the project's `CLAUDE.md` says what each mode builds and how
hard it is verified. This file says how the project moves on.

- **Prototype → harnessing** when the prototype exit demonstration passes. Run
  `plan` again to detail the harnessing phases from: the *Harnessing* column of
  the mode allocation, every `kind: hardening` entry in `docs/FEATURES.md` with
  `Disposition: mode: harnessing`, and the prototype phases' backlog. Re-check
  `docs/UNVALIDATED.md`: new consumers disqualify leaves.
- **Harnessing → production** when conformance holds on the full data; plan from
  the *Production* column, `mode: production` entries and `planned` features.
- Record the new mode in `docs/STATUS.md`.

A prototype is typically 1–3 phases; more usually means harnessing work slipped
into it.
