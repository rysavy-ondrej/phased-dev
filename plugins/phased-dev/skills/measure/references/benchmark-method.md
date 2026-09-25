# Benchmark method and pitfalls

## The minimum for a trustworthy comparison

1. Decision rule fixed before measuring.
2. Candidates behind the same contract, driven by the same harness.
3. Identical, correct output from every candidate on the workload.
4. Representative workload, named from `DATA.md`, sizes stated.
5. Release/optimised build; same machine; environment recorded.
6. Warm-up runs discarded; enough measured runs that min–max spread is small
   next to the difference between candidates; median reported, not the best.
7. Raw data and reproduce commands committed with the report.

## Pitfalls seen in practice

| Pitfall | What it does | Guard |
| --- | --- | --- |
| **Warm cache only** | I/O-bound candidates look alike, or the one that benefits from the page cache looks far better. A memory-mapped reader measured ~2× faster warm — its best case, so an upper bound — while holding 110× the resident memory and dying with SIGBUS on a truncated file. | Measure cold and warm for anything touching files; report memory beside speed; ask what fails, not only what is fast. |
| **Timer resolution** | GNU `time` resolves 10 ms; a 5 ms run is noise. | Inputs large enough for ≥ 0.5 s per run, or a benchmark harness. |
| **Fast because wrong** | A candidate skips work (drops records, stops early). | Correctness check on the whole workload before timing. |
| **Dead-code elimination** | The compiler removes work whose result is unused; microbenchmarks show impossible speeds. | Consume results (`black_box`, write the output); cross-check with a whole-program run. |
| **Debug build** | Differences of 10–100× that vanish in release. | Build profile in the environment record; release only. |
| **Unrepresentative input** | Tiny or uniform input hides the cost that matters (hash collisions, cache misses, long tails). | Workload from real data or its synthetic look-alike; several sizes. |
| **Noisy machine** | Other load inflates variance. | Note the load; repeat; compare spreads; pin CPU if needed. |
| **Only one metric** | The faster candidate needs 10× memory, or scales worse. | Every metric the decision rule names, and peak memory always. |
| **Rule after results** | The criteria bend to fit the favourite. | The rule is in the report before the first run. |

## Tools by need

| Need | Tools |
| --- | --- |
| Whole-program wall time and peak RSS | `scripts/measure.sh` (GNU time), `hyperfine` |
| Microbenchmarks | criterion (Rust), pytest-benchmark (Python), JMH (Java), Google Benchmark (C++), `go test -bench` |
| Allocations, heap profile | heaptrack, valgrind massif, dhat, tracemalloc, the allocator's stats |
| CPU profile, where time goes | perf, flamegraphs, py-spy, the language profiler |
| Cold cache | `sync; echo 3 > /proc/sys/vm/drop_caches` (root, Linux) or a fresh file copy |

## Reading results

- Compare medians; a difference smaller than either candidate's spread is a tie.
- A tie on the primary criterion goes to the next criterion in the rule —
  usually simplicity (CLAUDE.md: functionality and simplicity before speed).
- State the environment in every sentence that quotes a number, or cite the
  report that does.
