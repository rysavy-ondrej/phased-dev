#!/usr/bin/env bash
# The phase-independent half of the phase gate. The agent running the gate spends
# its judgement on the phase's own exit criterion and on whether DIVERGENCES.md is
# still literally true; everything mechanical is here, where it does not drift.
#
#   scripts/gate.sh <phase>[<part-letter>]    e.g. 2, or 2A
#
# Exit 0 = passes. 1 = does not. 2 = cannot run.
set -u
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root" || exit 2
. "$root/scripts/method.conf" || exit 2

arg=${1:-}
[ -n "$arg" ] || { echo "usage: scripts/gate.sh <phase>[<part>]" >&2; exit 2; }
phase=${arg%%[A-Za-z]*}; part=${arg#"$phase"}

fail=0; checked=0
ok()  { checked=$((checked + 1)); printf 'ok    %s\n' "$1"; }
bad() { checked=$((checked + 1)); fail=$((fail + 1)); printf 'FAIL  %s\n' "$1"; }
out() { printf '%s\n' "$1" | tail -20 | sed 's/^/      /'; }

# A full scratch disk fails checks for reasons that are not the code's.
avail=$(df -Pk "${TMPDIR:-/tmp}" | awk 'NR==2 {print $4}')
if [ "${avail:-0}" -lt 1048576 ]; then bad "less than 1 GB free in ${TMPDIR:-/tmp} -- clear agent scratch before gating"; fi

# 1. Green, small-scale and gate-only commands.
for cmd in "${CHECKS[@]}" "${GATE_CHECKS[@]}"; do
    if o=$(bash -c "$cmd" 2>&1); then ok "$cmd"; else bad "$cmd"; out "$o"; fi
done

# 2. Deterministic suite: a test that passes twice and fails once is a defect.
if [ -n "${DETERMINISM_CMD:-}" ]; then
    sig() { bash -c "$DETERMINISM_CMD 2>&1 | $DETERMINISM_FILTER"; }
    a=$(sig); b=$(sig); c=$(sig)
    if [ -z "$a" ]; then bad "the determinism signature is empty -- the check graded nothing"
    elif [ "$a" = "$b" ] && [ "$b" = "$c" ]; then ok "suite deterministic over three runs"
    else bad "suite not deterministic over three runs"; out "$(printf '1:\n%s\n2:\n%s\n3:\n%s' "$a" "$b" "$c")"; fi
fi

# 3. This phase's boxes all ticked; no later phase's box ticked.
section() { awk -v h="$1" '$0 ~ "^## Phase "h" " {on=1; next} /^## / {on=0} on' "$PLAN"; }
if [ -n "$part" ]; then
    body=$(awk -v h="$phase$part" '$0 ~ "^### Part "h" " {on=1; next} /^##/ {on=0} on' "$PLAN")
else
    body=$(section "$phase")
fi
if [ -z "$body" ]; then bad "no section for phase $arg in $PLAN"
else
    open=$(printf '%s\n' "$body" | grep -oE "☐ \*\*${ID_RE}" | grep -oE "$ID_RE" | tr '\n' ' ')
    if [ -z "$open" ]; then ok "every task of phase $arg is ticked"; else bad "phase $arg has unticked tasks: $open"; fi
fi
later=$(awk -v p="$phase" '/^## Phase [0-9]+/ {split($3,a,/[^0-9]/); on=(a[1]+0 > p+0)} on' "$PLAN" | grep -oE "☑ \*\*${ID_RE}" | grep -oE "$ID_RE" | tr '\n' ' ')
if [ -z "$later" ]; then ok "no later phase has a ticked box"; else bad "later-phase tasks ticked early: $later"; fi

# 4. Project-wide invariant checks: add them here as the project grows. Each one
#    must be proven to bite (break the thing, watch the FAIL) before it lands.
#    Examples: output channel carries nothing but results under -v/--debug; two
#    runs over one input produce identical bytes; hostile inputs cause no crash.

# 5. The phase's own exit criterion, as a script.
pg="$root/scripts/phase${arg}-gate.sh"
if [ -x "$pg" ]; then
    if o=$("$pg" 2>&1); then ok "scripts/phase${arg}-gate.sh"; out "$o"; else bad "scripts/phase${arg}-gate.sh"; out "$o"; fi
else
    bad "no executable scripts/phase${arg}-gate.sh -- the exit criterion must be runnable, not narrated"
fi

echo "gate: $checked checks, $fail failure(s)"
[ "$fail" -eq 0 ]
