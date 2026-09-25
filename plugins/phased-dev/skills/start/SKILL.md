---
name: start
description: Step 1: begin a project from the owner's concept notes (docs/CONCEPT.md, may be abstract) — check git, scaffold the repo, note what the concept already decides, hand over to specify. Use when starting a new project with this method.
---

# Start

The concept is the **owner's** document. This skill reads it and never rewrites
its substance; what it leaves open is settled later, level by level, in
`specify`.

## 1. Find the concept notes

Look for `docs/CONCEPT.md`, or notes the user points to (any file or pasted
text). If there are none, do not write a concept for them: scaffold (step 3) and
ask the owner to fill `docs/CONCEPT.md` — its template lists the headings this
skill looks for — then stop.

If the notes live elsewhere, copy them verbatim into `docs/CONCEPT.md` (keep the
owner's wording; add only headings where the structure is obvious).

## 2. Git and GitHub first

From the project directory, run the `git-setup` skill's check before anything
is written: `<skill-dir>/../../templates/scripts/check-env.sh git`. The project needs `git`
and `gh`, an identity, a repository on `main` — ask before creating one — and,
before the first push, a GitHub remote. Missing pieces are put to the owner as
the `git-setup` skill describes; the remote may wait until the spec is done, the
rest may not.

## 3. Scaffold

```bash
<skill-dir>/../../scripts/scaffold.sh <project-dir>
```

(`<skill-dir>` is this skill's base directory.) It installs `CLAUDE.md`, the
`docs/` templates, the `scripts/` and `.claude/workflows/run-phase.js`, and never
overwrites an existing file — the owner's concept is safe. It sets `PROJECT` in
`scripts/method.conf` from the directory name (phase reports are
`docs/reports/<PROJECT>_phase_<N>.md`); offer to change it if the project has a
better short name. If the project already has a `CLAUDE.md`, merge the
template's sections into it.

## 4. Read the concept — do not interrogate it

Concept notes are often abstract: a goal, the main functionality, a few
preferences. **That is expected, not a defect.** Filling the gaps is the
specification's job, done level by level with the owner (`specify`), not a
questionnaire here.

Read the notes and extract, for the specification to start from:
- **the goal** in one sentence, and the main functionality as the owner states it;
- **what the concept already decides** — language, SDK, database, UI, platform,
  an authority (reference implementation, standard, expected outputs), a
  constraint on data or deployment. These become *pre-filled* choices at the
  matching spec level, confirmed there;
- **contradictions** between statements — note them for level 0;
- **sample data** the owner mentions or supplies — note where it is and ask once
  whether it is sensitive; its analysis (`test-data`, Part 1) runs alongside
  level 0, so the spec can be checked against real examples.

Ask the owner something now **only** if the goal itself cannot be stated — then
one question, asking for it. Everything else waits for its level.

## 5. Hand over

Set `docs/STATUS.md` → "Mode: specification, level 0". Tell the owner in a few
lines: what you understood the goal to be, what the concept already decides, and
that the specification will now be designed top-down with them — understanding
and scope, architecture, technology, components, cross-cutting rules — with
their decision at each level. Then `specify`.
