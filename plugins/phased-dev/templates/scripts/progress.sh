#!/usr/bin/env bash
# Where the implementation is, from the plan and git alone -- the basis for
# progress reports and for resuming after a pause.
#
#   scripts/progress.sh          whole plan
#   scripts/progress.sh next     just the next step, one line (for resume)
#   scripts/progress.sh questions  the open questions, one line each
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
    echo "unpushed commits: $(git rev-list --count "$REMOTE/$MAIN".."$MAIN")"
fi
paused=$(uncomment docs/STATUS.md | grep -m1 '^- Paused:' || true)
[ -n "$paused" ] && echo "status: ${paused#- }"
echo "next: $(next_step)"
