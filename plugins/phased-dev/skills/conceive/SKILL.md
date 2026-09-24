---
name: conceive
description: Step 1 of the phased-dev method — turn an idea into a written concept (purpose, authority, priorities, scope, and for prototypes the question the prototype answers), choose the production or prototype profile, and scaffold the repository with the method's templates. Use when starting a new project or when the user wants to set up a repo with this method.
---

# Conceive

Goal: a `docs/CONCEPT.md` the owner agrees with, a chosen profile, and a
scaffolded repository. No code, no plan yet.

## 1. Ask only what cannot be inferred

Read what exists first (README, notes, a reference implementation, the user's
message). Then ask the owner — in one round, with AskUserQuestion where the
options are clear — only for what is missing:

1. **Purpose and consumer.** What does it do, and who or what reads its output?
2. **The authority.** What is normative when opinions differ: a reference
   implementation, a standard, golden outputs, a paper? Where is a copy? Which
   version produced any goldens? If there is none, say so — then the concept
   itself is the authority and invariants must be stated as testable claims.
3. **Profile.** production or prototype (see `../method/references/profiles.md`).
   Recommend one from the answers; the owner decides.
4. **Prototype only — the question.** One question with a yes/no or numeric
   answer, and the observable result that settles it. Push back on a vague
   question ("explore X"); a prototype without a question has no scope boundary,
   and the out-of-scope register cannot work without one.
5. **Priorities when they conflict** — the ordered list. Default:
   conformance > never crash / never lie > simplicity > speed.
6. **Constraints**: platforms, languages, dependency policy, where test data
   lives and whether it may be committed.

## 2. Scaffold

```bash
<skill-dir>/../../scripts/scaffold.sh <project-dir> <production|prototype>
```

(`<skill-dir>` is this skill's base directory.) It copies `CLAUDE.md`, the
`docs/` registers, `scripts/{method.conf,task-audit.sh,gate.sh,phase0-gate.sh}`
and `.claude/workflows/run-phase.js`, keeping only the chosen profile's text. It
never overwrites an existing file; if the project already has a `CLAUDE.md`,
merge the template's sections into it by hand rather than using `--force`.

If the project is not a git repository, ask before running `git init`.

## 3. Write the concept

Fill `docs/CONCEPT.md`. Then fill the top of `CLAUDE.md`: *What this project is*,
*What wins when they conflict*, and the prime directive's *authority* paragraph.
Leave invariants, seams and the output contract to `specify`.

Scope is two lists: **in** and **out**. For a prototype, every *out* item that is
a feature someone might reasonably expect becomes an `OOS-n` entry in
`docs/OUT_OF_SCOPE.md` now (use the `park` skill's format), so the register
starts with the boundaries the owner already drew.

Open questions go at the end of the concept, numbered. Each becomes a settled
decision when ruled on.

## 4. Stop for agreement

Show the owner the concept (a short summary plus the file path). Do not proceed
to `specify` until they agree: every later step inherits these answers.
