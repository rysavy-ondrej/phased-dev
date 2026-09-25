#!/usr/bin/env bash
# Run one candidate's command repeatedly and report wall time and peak memory.
# The measure skill runs this once per candidate on the same input, then
# compares the summaries. It is deliberately simple; language benchmark
# harnesses (criterion, pytest-benchmark, JMH, hyperfine) are used where finer
# resolution is needed.
#
#   scripts/measure.sh [-n runs] [-w warmup] [-l label] [-o results.csv] -- <command...>
#
# Per run: wall seconds, peak RSS (KiB), exit status, and a hash of stdout, so a
# candidate that is fast because it is wrong -- or not deterministic -- shows.
# Appends one CSV row per run to -o (label,run,wall_s,peak_rss_kib,exit,stdout_sha256).
# Exit 0 = every run succeeded. 1 = a run failed. 2 = cannot run.
set -u
export LC_ALL=C
runs=10; warm=1; label=candidate; out=
while [ $# -gt 0 ]; do
    case "$1" in
        -n) runs=$2; shift 2 ;;
        -w) warm=$2; shift 2 ;;
        -l) label=$2; shift 2 ;;
        -o) out=$2; shift 2 ;;
        --) shift; break ;;
        *) echo "usage: scripts/measure.sh [-n runs] [-w warmup] [-l label] [-o csv] -- <command...>" >&2; exit 2 ;;
    esac
done
[ $# -gt 0 ] || { echo "measure: no command given (put it after --)" >&2; exit 2; }
[ -x /usr/bin/time ] || { echo "measure: GNU time (/usr/bin/time) is required for peak memory" >&2; exit 2; }

tmp=$(mktemp -d) || exit 2
trap 'rm -rf "$tmp"' EXIT
[ -n "$out" ] && [ ! -s "$out" ] && echo "label,run,wall_s,peak_rss_kib,exit,stdout_sha256" >"$out"

one() { # one <run-number> -> prints "wall rss exit sha"
    /usr/bin/time -f '%e %M' -o "$tmp/t" "$@" >"$tmp/o" 2>"$tmp/e"
    local rc=$?
    read -r w m <"$tmp/t" 2>/dev/null || { w=NA; m=NA; }
    # GNU time prepends "Command exited with non-zero status" on failure
    [ "$rc" -ne 0 ] && { w=$(tail -1 "$tmp/t" | cut -d' ' -f1); m=$(tail -1 "$tmp/t" | cut -d' ' -f2); }
    echo "$w $m $rc $(sha256sum <"$tmp/o" | cut -c1-16)"
}

for ((i = 1; i <= warm; i++)); do one "$@" >/dev/null; done

failed=0
: >"$tmp/rows"
for ((i = 1; i <= runs; i++)); do
    read -r w m rc sha < <(one "$@")
    echo "$w $m $rc $sha" >>"$tmp/rows"
    [ "$rc" -eq 0 ] || failed=1
    [ -n "$out" ] && echo "$label,$i,$w,$m,$rc,$sha" >>"$out"
done

stat() { # column -> "min median max"
    awk -v c="$1" '{print $c}' "$tmp/rows" | sort -g | awk '{a[NR]=$1} END {
        med = (NR % 2) ? a[(NR+1)/2] : (a[NR/2] + a[NR/2+1]) / 2
        printf "%s %s %s", a[1], med, a[NR] }'
}
read -r wmin wmed wmax < <(stat 1)
read -r mmin mmed mmax < <(stat 2)
hashes=$(awk '{print $4}' "$tmp/rows" | sort -u | wc -l)

printf '%s: %d runs (+%d warm-up)\n' "$label" "$runs" "$warm"
printf '  wall s     min %-10s median %-10s max %s\n' "$wmin" "$wmed" "$wmax"
printf '  peak KiB   min %-10s median %-10s max %s\n' "$mmin" "$mmed" "$mmax"
printf '  stdout     %s\n' "$([ "$hashes" -eq 1 ] && echo "identical across runs ($(awk 'NR==1{print $4}' "$tmp/rows"))" || echo "DIFFERS across runs ($hashes distinct) -- not deterministic")"
awk -v m="$wmed" 'BEGIN { exit !(m < 0.5) }' &&
    echo "  WARNING    median below 0.5 s: GNU time resolves 10 ms -- use a larger input or a benchmark harness"
[ "$failed" -eq 0 ] || echo "  FAIL: at least one run exited non-zero -- see the csv"
[ "$failed" -eq 0 ]
