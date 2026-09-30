#!/usr/bin/env bash
# Where the implementation is, from the plan and git alone -- the basis for
# progress reports and for resuming after a pause.
#
#   scripts/progress.sh          whole plan
#   scripts/progress.sh next     just the next step, one line (for resume)
#   scripts/progress.sh questions  the open questions, one line each
#   scripts/progress.sh run [N]  the run panel for phase N (default: the phase
#                                of the next step): subphases, tasks, and every
#                                agent logged for them, by step
#   scripts/progress.sh log <label> <model> <result> [tokens] [time]
#                                record one agent in the run log. label as the
#                                run-phase workflow names them (scope:P3,
#                                impl:T3.1+T3.2, verify:T3.1, repair1:T3.1,
#                                recheck1:T3.1, record:T3.1, checkpoint:3A,
#                                phase-test:P3, review:tests, triage:P3,
#                                report:P3); result ok|fail|died|running;
#                                tokens like 8200 or 8.2k; time like 95, 1m35s.
#                                A later line for the same label replaces it.
#   scripts/progress.sh log --clear [N]   forget the log (of phase N)
#
# The run log is telemetry, not state: it lives in the git directory
# (never committed, never makes the tree dirty) and losing it loses nothing
# the plan and git do not also record.
set -u
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root" || exit 2
. "$root/scripts/method.conf" || exit 2
# Registers carry example entries inside <!-- --> blocks; never count those.
uncomment() { awk '/<!--/ {c=1} !c; /-->/ {c=0}' "$1" 2>/dev/null; }

# One line per task: mode phase subphase marker id title
tasks=$(awk '
    /^# (Prototype|Harnessing|Production)/ { mode=tolower($2); next }
    /^## Phase [0-9]+/ { split($3, a, /[^0-9]/); ph=a[1]; sp="-"; next }
    /^### Subphase / { sp=$3; next }
    /^- (☐|◐|☑) \*\*T[0-9]+\.[0-9]+/ {
        m=$2; id=$3; sub(/^\*\*/, "", id); sub(/\.$/, "", id)
        t=$0; sub(/^- [^ ]+ \*\*[^ ]+ /, "", t); sub(/\*\*.*/, "", t)
        print mode, ph, sp, m, id, t
    }' "$PLAN")

next_step() {
    local l
    l=$(printf '%s\n' "$tasks" | awk '$4 == "◐" {print; exit}')
    [ -n "$l" ] && { set -- $l; echo "verify $5 (phase $2, $1)"; return; }
    l=$(printf '%s\n' "$tasks" | awk '$4 == "☐" {print; exit}')
    [ -n "$l" ] && { set -- $l; echo "implement $5 (phase $2, $1)"; return; }
    echo "all planned tasks verified"
}

if [ "${1:-}" = next ]; then next_step; exit 0; fi

runlog="$(git rev-parse --git-dir 2>/dev/null || echo .git)/phased-dev/run.tsv"

# The phase an agent label belongs to: from T3.4, P3 or 3A inside it.
label_phase() {
    local l=${1#*:}
    [[ $l =~ ^T([0-9]+)\. || $l =~ ^P([0-9]+)$ || $l =~ ^([0-9]+)[A-Z]$ ]] \
        && echo "${BASH_REMATCH[1]}"
}

if [ "${1:-}" = log ]; then
    shift
    if [ "${1:-}" = --clear ]; then
        [ -f "$runlog" ] || exit 0
        if [ -n "${2:-}" ]; then
            awk -F'\t' -v p="$2" '$2 != p' "$runlog" > "$runlog.tmp" && mv "$runlog.tmp" "$runlog"
        else
            rm -f "$runlog"
        fi
        exit 0
    fi
    [ $# -ge 3 ] || { echo "usage: $0 log <label> <model> <ok|fail|died|running> [tokens] [time]" >&2; exit 2; }
    case $3 in ok|fail|died|running) ;; *) echo "result must be ok, fail, died or running" >&2; exit 2 ;; esac
    ph=$(label_phase "$1")
    [ -n "$ph" ] || { echo "label '$1' names no task, subphase or phase (T3.1, 3A, P3)" >&2; exit 2; }
    mkdir -p "$(dirname "$runlog")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date +%s)" "$ph" "$1" "$2" "$3" "${4:--}" "${5:--}" >> "$runlog"
    exit 0
fi

if [ "${1:-}" = run ]; then
    ph=${2:-$(next_step | sed -n 's/.*(phase \([0-9]*\),.*/\1/p')}
    [ -n "$ph" ] || ph=$(printf '%s\n' "$tasks" | awk 'END {print $2}')
    [ -n "$ph" ] || { echo "no phase to show"; exit 1; }
    { printf '%s\n' "$tasks" | awk -v p="$ph" '$2 == p {print "T", $0}'
      [ -f "$runlog" ] && awk -F'\t' -v p="$ph" 'BEGIN {OFS="\t"} $2 == p {print "A", $0}' "$runlog"
    } | awk -v ph="$ph" '
        function secs(t,   s, n) {                 # 95 | 1m35s | 1h2m -> seconds
            if (t == "-" || t == "") return -1
            if (t ~ /^[0-9]+$/) return t + 0
            s = 0
            while (match(t, /^[0-9]+[hms]/)) {
                n = substr(t, 1, RLENGTH - 1) + 0; u = substr(t, RLENGTH, 1)
                s += (u == "h") ? n * 3600 : (u == "m") ? n * 60 : n
                t = substr(t, RLENGTH + 1)
            }
            return s
        }
        function toks(t) {                         # 8200 | 8.2k | 1.1M -> tokens
            if (t == "-" || t == "") return -1
            if (t ~ /[kK]$/) return substr(t, 1, length(t) - 1) * 1000
            if (t ~ /[mM]$/) return substr(t, 1, length(t) - 1) * 1000000
            return t + 0
        }
        function ftok(n) { return n < 0 ? "-" : n >= 1000000 ? sprintf("%.1fM", n / 1e6) : n >= 1000 ? sprintf("%.1fk", n / 1000) : n "" }
        function ftime(s) { return s < 0 ? "-" : s >= 3600 ? sprintf("%dh%02dm", s / 3600, (s % 3600) / 60) : s >= 60 ? sprintf("%dm%02ds", s / 60, s % 60) : s "s" }
        function mark(r) { return r == "ok" ? "✓" : r == "fail" ? "✗" : r == "died" ? "†" : "…" }
        function stepname(k) {
            k = (k ~ /^repair/) ? "repair" : (k ~ /^recheck/) ? "recheck" : k
            return (k == "scope") ? "Scope" : (k == "impl") ? "Implement" : (k == "verify") ? "Verify" : \
                   (k == "repair") ? "Repair" : (k == "recheck") ? "Recheck" : (k == "record") ? "Record" : \
                   (k == "checkpoint") ? "Checkpoint" : (k == "phase-test") ? "Phase test" : \
                   (k == "review") ? "Review" : (k == "triage") ? "Triage" : (k == "report") ? "Report" : k
        }
        $1 == "T" {                                # T mode phase sub marker id title...
            mode = $2; s = $4; id = $6
            if (!(s in seen)) { seen[s] = 1; subs[++ns] = s }
            ntask[s]++; tid[s, ntask[s]] = id; tmark[id] = $5
            n++; if ($5 == "☑") v++; if ($5 == "◐") c++
            next
        }
        $1 == "A" {                                # A epoch phase label model result tokens time
            split($0, f, "\t"); lab = f[4]
            if (!(lab in idx)) { idx[lab] = ++na; order[na] = lab }
            model[lab] = f[5]; res[lab] = f[6]; tk[lab] = toks(f[7]); tm[lab] = secs(f[8])
        }
        END {
            for (i = 1; i <= na; i++) {
                l = order[i]; nag++
                if (tk[l] >= 0) T += tk[l]; if (tm[l] >= 0) S += tm[l]
                k = l; sub(/:.*/, "", k); st = stepname(k)
                if (!(st in sseen)) { sseen[st] = 1; steps[++nst] = st }
                sn[st]++; if (res[l] == "ok") sok[st]++
                slist[st, sn[st]] = l
                # the task trail: every task id named in the label
                ids = l; sub(/^[^:]*:/, "", ids); m = split(ids, a, "+")
                for (j = 1; j <= m; j++) trail[a[j]] = trail[a[j]] " " k mark(res[l])
            }
            printf "Phase %s (%s) — %d/%d ☑", ph, mode, v, n
            if (c) printf " · %d ◐", c
            if (n - v - c) printf " · %d ☐", n - v - c
            printf " · %d agent%s", nag, nag == 1 ? "" : "s"
            if (T > 0) printf " · %s tokens", ftok(T)
            if (S > 0) printf " · %s", ftime(S)
            print ""
            for (i = 1; i <= ns; i++) {
                s = subs[i]; done = 0
                for (j = 1; j <= ntask[s]; j++) if (tmark[tid[s, j]] == "☑") done++
                printf "\n  %s  %d/%d\n", (s == "-" ? "tasks" : "Subphase " s), done, ntask[s]
                for (j = 1; j <= ntask[s]; j++) {
                    id = tid[s, j]
                    printf "    %s %-7s%s\n", tmark[id], id, trail[id]
                }
            }
            if (!na) { print "\n  (no agents logged for this phase)"; exit }
            print "\n  Agents by step"
            for (i = 1; i <= nst; i++) {
                st = steps[i]
                for (j = 1; j <= sn[st]; j++) {
                    l = slist[st, j]
                    printf "  %-11s %-6s %s %-26s %-8s %7s %7s\n", (j == 1 ? st : ""), \
                        (j == 1 ? sok[st] + 0 "/" sn[st] : ""), mark(res[l]), l, model[l], ftok(tk[l]), ftime(tm[l])
                }
            }
            print "\n  ✓ ok  ✗ problems found / failed  † died (limit)  … running"
        }'
    exit 0
fi
if [ "${1:-}" = questions ]; then
    awk '/^## Open/ {on=1; next} /^## / {on=0} !on {next}
         /^### Q-/ { if (q) print q; sub(/^### /, ""); q=$0 }
         /\*\*Blocking:\*\* yes/ { q=q"  [BLOCKING]" }
         /\*\*Affects:\*\*/ { a=$0; sub(/.*\*\*Affects:\*\* */, "", a); sub(/\. *\*\*.*/, "", a); q=q"  (affects "a")" }
         END { if (q) print q }' <(uncomment docs/QUESTIONS.md)
    exit 0
fi

[ -n "$tasks" ] || { echo "no tasks found in $PLAN"; exit 1; }
printf '%s\n' "$tasks" | awk '
    { key=$1" / phase "$2 ($3 != "-" ? " / "$3 : "") ; if (key != last) { if (last) summary(); last=key; n=v=c=0; list="" }
      n++; if ($4=="☑") v++; if ($4=="◐") c++; list=list"  "$4" "$5 }
    function summary() { printf "%-34s %d/%d verified%s\n   %s\n", last, v, n, (c ? ", "c" awaiting verification" : ""), list }
    END { if (last) summary() }'

echo
open_q=$(awk '/^## Open/ {on=1; next} /^## / {on=0} on' <(uncomment docs/QUESTIONS.md) | grep -c '^### Q-' || true)
blk_q=$(awk '/^## Open/ {on=1; next} /^## / {on=0} on' <(uncomment docs/QUESTIONS.md) | grep -c '\*\*Blocking:\*\* yes' || true)
prop_f=$(uncomment docs/FEATURES.md | grep -c '^\*\*Disposition:\*\* proposed' || true)
meas=$(awk -F'|' '/^\| M-[0-9]+/ { s=$5; gsub(/^ +| +$/, "", s); if (s != "decided") n++ } END { print n+0 }' <(uncomment docs/MEASUREMENTS.md))
echo "questions open: ${open_q:-0} (${blk_q:-0} blocking) · features awaiting a disposition: ${prop_f:-0} · measurements not decided: ${meas:-0}"
if git rev-parse --verify --quiet "$REMOTE/$MAIN" >/dev/null; then
    echo "unpushed commits: $(git rev-list --count "$REMOTE/$MAIN..$MAIN")"
fi
paused=$(uncomment docs/STATUS.md | grep -m1 '^- Paused:' || true)
[ -n "$paused" ] && echo "status: ${paused#- }"
echo "next: $(next_step)"
