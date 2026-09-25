# Working with caveman

phased-dev depends on the [caveman](https://github.com/JuliusBrussee/caveman)
plugin (`caveman@caveman`), which is installed with it. Caveman cuts output
tokens by compressing the agent's **chat** into terse prose, and ships workflow
skills and compressed-output subagents. This file records how the two fit
together: which caveman parts are used as they are, and where phased-dev's
rules take precedence. The binding summary is in the project's `CLAUDE.md` →
*Working with caveman*; this is the reasoning behind it.

Checked against caveman 2.7.0.

## What caveman does

| Part | What it does | Fires |
| --- | --- | --- |
| `caveman` skill + hooks | compresses chat (levels lite/full/ultra/wenyan); SessionStart injects the rules, UserPromptSubmit reinforces them | every session of the **main** agent; subagents are not affected |
| Boundaries rule (in the skill) | code, comments, commits, docs, issue text, memory files and third-party messages stay in **normal prose** | always |
| Auto-Clarity (in the skill) | drops compression for security warnings, irreversible actions, multi-step sequences and anything compression would make ambiguous | always |
| `caveman-commit` | Conventional Commits message, compressed | "write a commit", "commit message", `/commit` |
| `caveman-compress` | rewrites a memory file (e.g. `CLAUDE.md`) in caveman prose | `/caveman-compress` or asked to compress a memory file |
| `caveman-review`, `cavecrew-reviewer` | one-line-per-finding review | "review this PR/diff" |
| `cavecrew-investigator`, `cavecrew-builder` | compressed locate-code and ≤2-file edit subagents | delegation choice |
| `lean-build`, `verify-and-stop`, `surgical-patch`, `safe-refactor`, `investigate-first`, `migration` | workflow disciplines | by description: feature work, validation, bug fixes, refactors, diagnosis, migrations |
| `caveman-init` | writes caveman rule files (AGENTS.md, Cursor, Copilot …) into the repo | `/caveman-init` only |
| `caveman-learn` | proposes cost fixes, can suggest trimming a heavy `CLAUDE.md` | asked |
| Cloud skills (`setup`, `discover`, `manage`, `optimize`, `evidence-review`) | Caveman Cloud spend tracking | asked; unrelated to phased-dev |

No skill or agent name collides: plugin skills are namespaced
(`phased-dev:implement`, `caveman:lean-build`).

## Where they agree — use caveman as is

- **Chat compression** saves the owner's and the session's tokens, which is
  what phased-dev's token discipline wants. Default level is fine.
- **Boundaries** already match phased-dev: every file this method writes —
  `CLAUDE.md`, `docs/*`, the plan, commits, reports — is persisted outside chat,
  so caveman keeps it in normal prose.
- **Subagents are not in caveman mode**, so implementer, verifier and review
  agents started by phased-dev work and report in normal prose.
- `surgical-patch` matches the repair step (narrowest fix plus the regression
  test), `lean-build` matches prototype mode (no polish, strict scope),
  `investigate-first` matches a blocked task's diagnosis, `safe-refactor` and
  `migration` fit their tasks. They may shape *how* a step is done.
- `cavecrew-investigator` is a good cheap way to locate code during a task.

## Where phased-dev takes precedence

| # | Conflict | Rule |
| --- | --- | --- |
| 1 | **Commit format.** `caveman-commit` writes Conventional Commits (`feat: …`); `task-audit.sh` requires `T2.3: …` with the trailer and fails anything else. | Commit subjects follow `CLAUDE.md` (task id first, trailer last). A commit-message skill may shape the body, never the subject. |
| 2 | **Compressing the rule files.** `caveman-compress` / `caveman-learn` may rewrite `CLAUDE.md` or docs. The scripts parse the plan markers, `Prepared:`, `**Blocking:** yes`, `**Disposition:**`, the measurement index — compression can break them silently — and rules lose force when shortened. | Never compress `CLAUDE.md`, `docs/**`, the plan, the spec or the registers. Cutting their cost is an owner decision, done by editing, and the scripts must still pass. |
| 3 | **What "done" means.** `verify-and-stop` builds the "smallest sufficient proof set"; `lean-build` stops "when acceptance passes". | Acceptance is the task's requirement and small test at the mode's depth; the proof set is the verifier template — mutation proof included. A workflow skill can make the work leaner, never the definition of done smaller. |
| 4 | **The verifier.** `cavecrew-reviewer` / `caveman-review` report one line per finding, without reproduction commands or suggested repairs, and are not adversarial. | Verifier, recheck and gate review lenses are general-purpose agents given phased-dev's prompts (`implement/references/verifier-prompt.md`, the `run-phase` workflow). A caveman reviewer may be an extra opinion, never the verification. |
| 5 | **Edits by subagent.** `cavecrew-builder` edits 1–2 files. | Allowed only inside the current task's scope; the main session still runs the tests, commits once per task and runs `task-audit.sh`. |
| 6 | **Progress narration.** Caveman: no progress note between tool calls. phased-dev: one progress line after every task. | The per-task progress line is a required report, not narration: one line, caveman style is fine (`T2.3 ☑ a1b2c3d 0 repairs — 4/7 — next T2.4`). Nothing else between calls. |
| 7 | **Decisions put to the owner.** Spec decision points, measurement decisions, feature dispositions, blocking questions: compressed options can be misread. | These fall under caveman's Auto-Clarity: each option in full, unambiguous sentences (what it is, gives, costs, wrong when). Compression resumes after the question. |

Also: `caveman-init` writes rule files for other agents (AGENTS.md …) into the
repo; run it only if the owner wants caveman for those tools too — it does not
touch `CLAUDE.md`. A project that wants caveman off entirely sets
`{"defaultMode": "off"}` in `.caveman.json` at the repository root; phased-dev
works the same either way.

## Installing

A cross-marketplace dependency needs the dependency's marketplace to be known,
so the caveman marketplace is added first:

```bash
claude plugin marketplace add JuliusBrussee/caveman
claude plugin marketplace add rysavy-ondrej/phased-dev
claude plugin install phased-dev@phased-dev     # installs caveman@caveman with it
```

Without the first line the install stops with `Dependency "caveman@caveman"
(required by phased-dev@phased-dev) not found. Is the "caveman" marketplace
added?` — add it and re-run the install. If caveman is already installed, the
existing install satisfies the dependency.
