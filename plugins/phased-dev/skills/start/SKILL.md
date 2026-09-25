---
name: start
description: Step 1 of the phased-dev method — take the owner's concept notes (docs/CONCEPT.md, written by a human), scaffold the repository with the method's templates, check the concept for gaps and contradictions, and turn them into questions for the owner. Use when beginning a project from concept notes, or when the user wants to set up a repository with this method.
---

# Start

The concept is the **owner's** document. This skill reads it, never rewrites
its substance, and turns what is missing into questions.

## 1. Find the concept notes

Look for `docs/CONCEPT.md`, or notes the user points to (any file or pasted
text). If there are none, do not write a concept for them: scaffold (step 2) and
ask the owner to fill `docs/CONCEPT.md` — its template lists the headings this
skill looks for — then stop.

If the notes live elsewhere, copy them verbatim into `docs/CONCEPT.md` (keep the
owner's wording; add only headings where the structure is obvious).

## 2. Scaffold

```bash
<skill-dir>/../../scripts/scaffold.sh <project-dir>
```

(`<skill-dir>` is this skill's base directory.) It installs `CLAUDE.md`, the
`docs/` registers and templates, `scripts/` (`method.conf`, `task-audit.sh`,
`gate.sh`, `progress.sh`, `phase1-gate.sh`) and `.claude/workflows/run-phase.js`.
It never overwrites an existing file, so the owner's concept is safe. If the
project already has a `CLAUDE.md`, merge the template's sections into it. Ask
before `git init` in a directory that is not a repository.

## 3. Read the concept for gaps

Check it against what the later steps need. For each, is it stated, implied, or
missing?

- purpose and consumer of the output
- **the authority** — what decides correctness (reference implementation,
  standard, golden outputs, or the concept itself)
- must-do list, and what is out of scope
- **what the prototype must demonstrate** (the first milestone)
- constraints: platform, language, libraries, data, deployment
- priorities when goals conflict (default: correctness > honesty/robustness >
  simplicity > speed)

Also look for **contradictions** between statements, and for requirements too
vague to test ("fast", "robust") — ask for a number or an example.

## 4. Write the questions

Each gap, contradiction or vague requirement becomes an entry in
`docs/QUESTIONS.md` → *Open*, tagged `Affects: concept` or `Affects: spec`, with
options and a recommendation where you can give one. Keep them few and sharp —
merge related gaps; do not ask what the concept already answers.

Ask them in one round (AskUserQuestion for the ones with clear options, plain
text for the rest). Record each answer under *Answered* with the date. If an
answer changes the concept, propose the edit to `docs/CONCEPT.md` and let the
owner accept it — it stays their document.

## 5. Hand over

Fill the top of `CLAUDE.md` (*What this project is*, *What wins when they
conflict*, the authority paragraph) from the concept. Set `docs/STATUS.md` to
"Mode: specification". Then `specify`.
