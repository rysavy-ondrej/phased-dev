#!/usr/bin/env bash
# The phase-independent half of the comprehensive phase test. The agent running
# the gate spends its judgement on the phase's own exit criterion; everything
# mechanical is here, where it does not drift.
#
#   scripts/gate.sh <phase>[<subphase>]    e.g. 2 (before the push), or 2A (checkpoint)
#
# Exit 0 = passes. 1 = does not. 2 = cannot run.
set -u
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root" || exit 2
. "$root/scripts/method.conf" || exit 2
# Registers carry example entries inside <!-- --> blocks; never count those.
uncomment() { awk '/<!--/ {c=1} !c; /-->/ {c=0}' "$1" 2>/dev/null; }

arg=${1:-}
[ -n "$arg" ] || { echo "usage: scripts/gate.sh <phase>[<subphase>]" >&2; exit 2; }
phase=${arg%%[A-Za-z]*}; sub=${arg#"$phase"}

fail=0; checked=0
ok()  { checked=$((checked + 1)); printf 'ok    %s\n' "$1"; }
bad() { checked=$((checked + 1)); fail=$((fail + 1)); printf 'FAIL  %s\n' "$1"; }
out() { printf '%s\n' "$1" | tail -20 | sed 's/^/      /'; }

# A full scratch disk fails checks for reasons that are not the code's.
avail=$(df -Pk "${TMPDIR:-/tmp}" | awk 'NR==2 {print $4}')
[ "${avail:-0}" -ge 1048576 ] || bad "less than 1 GB free in ${TMPDIR:-/tmp} -- clear agent scratch before gating"

# 1. Green.
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

# 3. Every task of this phase (or subphase) verified; nothing later started.
#    Headings: "# Prototype" (mode), "## Phase 2 — ...", "### Subphase 2A — ...".
body=$(awk -v p="$phase" -v s="$sub" '
    /^# / { on=0 }
    /^## Phase [0-9]+/ { split($3, a, /[^0-9]/); inph = (a[1] == p); on = inph && s == ""; next }
    /^### Subphase / { if (inph && s != "") on = ($3 == p s); next }
    /^## / { on=0 }
    on' "$PLAN")
if [ -z "$body" ]; then bad "no section for phase $arg in $PLAN"
else
    grep -q '^Prepared: [0-9]' < <(awk -v p="$phase" '/^## Phase [0-9]+/ {split($3,a,/[^0-9]/); on=(a[1]==p)} /^### Subphase/ {on=0} on' "$PLAN") \
        && ok "phase $phase is prepared" || bad "phase $phase has no 'Prepared: <date>' -- it was never prepared"
    open=$(printf '%s\n' "$body" | grep -oE "(☐|◐) \*\*${ID_RE}" | tr '\n' ' ')
    if [ -z "$open" ]; then ok "every task of $arg is verified (☑)"; else bad "$arg has tasks not verified: $open"; fi
fi
later=$(awk -v p="$phase" '/^## Phase [0-9]+/ {split($3,a,/[^0-9]/); on=(a[1]+0 > p+0)} on' "$PLAN" | grep -oE "(◐|☑) \*\*${ID_RE}" | tr '\n' ' ')
if [ -z "$later" ]; then ok "no later phase has started"; else bad "later-phase tasks already started: $later"; fi

# 4. No open question blocks the next step.
blocking=$(awk '/^## Open/ {on=1; next} /^## / {on=0} on' <(uncomment docs/QUESTIONS.md) | grep -c '\*\*Blocking:\*\* yes' || true)
[ "${blocking:-0}" -eq 0 ] && ok "no open blocking question" || bad "$blocking open blocking question(s) in docs/QUESTIONS.md"

# 5. Project-wide invariant checks: add them here as the project grows, each one
#    proven to bite before it lands (output channel clean under -v, identical
#    bytes across two runs, no crash on hostile input, ...).

# 6. The phase's own exit criterion, as a script (phase only, not a subphase checkpoint).
if [ -z "$sub" ]; then
    pg="$root/scripts/phase${phase}-gate.sh"
    if [ -x "$pg" ]; then
        if o=$("$pg" 2>&1); then ok "scripts/phase${phase}-gate.sh"; out "$o"; else bad "scripts/phase${phase}-gate.sh"; out "$o"; fi
    else
        bad "no executable scripts/phase${phase}-gate.sh -- the exit criterion must be runnable, not narrated"
    fi
fi

echo "gate: $checked checks, $fail failure(s)"
[ "$fail" -eq 0 ]
