# Why the rules exist

Each rule in this method was added after a measured failure in maestro-enjoy
(a Rust reimplementation of a Lua/tshark network-flow exporter, held to output
parity with the reference). Relax a rule only knowing what it was bought with.

## Token cost

| Observation | Rule it produced |
| --- | --- |
| Phase 0 cost 612M input tokens across 100 subagents. | Measure where tokens go before changing the process; guesses were wrong. |
| A "process lens" agent ran 22 times for ~47M tokens checking the working agreement by hand, and found nothing that was its own to find. | Mechanical checks are a script (`task-audit.sh`), run by the agent that finds things. |
| 748 of 927 test-suite runs were whole-suite runs — 7.5 per agent — because four prompts each said "run the suite". | Targeted tests for mutation proof; full suite once; determinism at the gate only. |
| Repair rounds re-ran full adversarial verification; one task spent three rounds and missed the same line each time. | A repair is rechecked against its problem list only. |
| The phase test re-derived eight universal checks in prose at ~13M tokens per run. | `gate.sh` does them; the agent judges the exit criterion. |
| 147 observations were collected in a phase and never triaged. | Observations go to `BACKLOG.md` or are not requested. |
| Phases 1 and 2 cost four and three gate rounds for being too broad. | Wide phases are split into parts (3A/3B/3C), each gated on its own. |
| Runs rediscovered prerequisites (missing library target, undocumented dependency, unused fixtures). | A readiness section per phase, written before the run. |
| Grouped verification (implement several tasks, verify once) saved real tokens, and the review panel still caught what slipped. | Batching is sound — the prototype profile makes it the default and plans it up front. |

## Hollow tests

| Observation | Rule |
| --- | --- |
| Seven hollow tests in phase 0: a guard blind to a manifest spelling, a stdout guard bypassable by a renamed import, a test under a logger where the pollution could not occur, a substring bleeding into the neighbouring flag's text, three wirings that could be swapped with all 110 tests green. | "Could this pass if the behaviour were broken?" — then prove it by mutation. |
| Changing three protocol numbers at once (43→143, 50→150, 51→151) left all 21 test binaries green: the fixtures were built from the constants under test. Seven instances across three gate rounds. | The self-referential fixture rule: literal data in fixtures; every magic-number table pinned to literals with citations. **Naming the failure mode in the constitution was worth more than any amount of re-verification — the next round had zero instances.** |
| Per-task mutation proof was dropped for grouped verification, and the front line missed a whole class repeatedly. | When mutation proof is delegated, the verifier is told it is *the main thing it is for*. |
| A reviewer mutated a destructuring pattern instead of the struct literal beside it, and proved nothing. | Mutate the exact construct the test names. |
| A gate check compared two empty streams (`"" = ""`) and passed. | A check whose setup failed prints "graded nothing" as a FAIL. |

## Honesty of the record

| Observation | Rule |
| --- | --- |
| A subagent died and its null verdict was read as a pass. | A dead agent verified nothing; the harness blocks on it. |
| Three gate runs recorded themselves clean and all three were refuted by an independent panel. | The gate's verdict is checked by someone other than the gate. |
| Documentation stated behaviour the code had deliberately removed, 113 lines above the code that refuted it; the phase blocked twice on such sentences. | Prose is verified like code. |
| A "known divergence" note was false. | Every DIVERGENCES claim is re-run at each gate. |
| STATUS quoted a commit count for a moving range and went stale twice. | Name the fixed base; let git do the arithmetic. |
| A checkbox was ticked for work not done, and a re-run then skipped it and reported success doing nothing. | Only the commit doing the work ticks its box; the audit enforces it. |
| A golden file turned out to be stale in two keys. | Goldens are data with provenance and known defects, recorded in PROVENANCE. |
| A pushed phase with an incomplete review panel. | Allowed only with STATUS saying so plainly; silence is the violation. |

## Scope and simplicity

| Observation | Rule |
| --- | --- |
| Memory-mapped input gave ~2x on a warm cache for SIGBUS on truncation and 110x resident memory. | Proportionate effort; the plain version wins unless a benchmark says otherwise; record the decision with its numbers. |
| An owner ruling was taken without a file in front of it that answered the question. | Before asking for a ruling, look for the evidence; record what the ruling was based on. |

## Operations

- `/tmp` filled to 100% with ~7.6 GB of subagent scratch and the gate failed on
  it. `gate.sh` checks free space first.
