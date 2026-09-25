#!/usr/bin/env bash
# Working-agreement audit for one task (or one task of a batch), as a script
# rather than an agent: every check here is mechanical, and an agent asked to
# check the same list by hand drifts, tires, and spends tokens finding nothing.
#
#   scripts/task-audit.sh T1.3
#
# Exit 0 = clean. 1 = at least one deviation. 2 = cannot run.
set -u
export LC_ALL=C   # comm and sort must agree on one collation
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root" || exit 2
# shellcheck source=method.conf
. "$root/scripts/method.conf" || exit 2

task=${1:-}
[ -n "$task" ] || { echo "usage: scripts/task-audit.sh <task-id>" >&2; exit 2; }

fail=0; checked=0
ok()   { checked=$((checked + 1)); printf 'ok    %s\n' "$1"; }
bad()  { checked=$((checked + 1)); fail=$((fail + 1)); printf 'FAIL  %s\n' "$1"; }
note() { printf '%s\n' "$1" | sed 's/^/      /'; }

# A commit belongs to a task when the id appears in the comma-separated list its
# subject opens with: "T2.2: ..." or, for a batch, "T2.1, T2.2, T2.3: ...".
task_re=${task//./\\.}
subject_re="^(${ID_RE}, )*${task_re}(, ${ID_RE})*: "
mapfile -t commits < <(git log --format='%H' --extended-regexp --grep="$subject_re" "$MAIN")
if [ ${#commits[@]} -eq 0 ]; then
    bad "$task has no commit whose subject names it before the colon"
    echo "audit: $checked checks, $fail deviation(s)"; exit 1
fi
ok "$task has ${#commits[@]} commit(s) on $MAIN"

base=$(git rev-parse "${commits[-1]}^" 2>/dev/null) || { bad "cannot resolve parent of first $task commit"; exit 1; }
tip=${commits[0]}

for c in "${commits[@]}"; do
    short=$(git log -1 --format='%h %s' "$c")
    if git log -1 --format='%B' "$c" | grep -qE "$TRAILER_RE"; then ok "trailer present: $short"
    else bad "trailer missing: $short"; fi
done

# Every commit since this task began must belong to some task or phase, or work
# lands on main accounted to nothing and no per-task audit ever sees it.
unaccounted=$(git log --format='%h %s' "$base"..HEAD | grep -vE "^[0-9a-f]+ ((${ID_RE})(, ${ID_RE})*|P[0-9]+[A-Z]?): " || true)
if [ -z "$unaccounted" ]; then ok "every commit since $task began names a task"
else bad "commit(s) since $task began name no task"; note "$unaccounted"; fi

dirty=$(git status --porcelain)
if [ -z "$dirty" ]; then ok "working tree clean"; else bad "working tree is not clean"; note "$dirty"; fi

mapfile -t touched < <(git diff --name-only "$base".."$tip")
scratch=$(printf '%s\n' "${touched[@]}" | grep -E '\.(orig|rej|bak|tmp|swp)$|(^|/)nohup\.out$' || true)
if [ -z "$scratch" ]; then ok "no scratch files committed"; else bad "scratch files committed"; note "$scratch"; fi
protected=$(printf '%s\n' "${touched[@]}" | grep -E "$PROTECTED_RE" || true)
if [ -z "$protected" ]; then ok "protected paths untouched"; else bad "a protected path was modified"; note "$protected"; fi

# Nothing pushed before its phase gate; history forward-only.
if git rev-parse --verify --quiet "$REMOTE/$MAIN" >/dev/null; then
    if git merge-base --is-ancestor "$tip" "$REMOTE/$MAIN"; then
        bad "$task is already on $REMOTE/$MAIN -- pushed before its phase gate (fine only if STATUS.md says so)"
    else ok "$task is unpushed"; fi
    if [ -z "$(git log --format='%H' "$MAIN".."$REMOTE/$MAIN")" ]; then ok "$REMOTE/$MAIN is an ancestor of $MAIN"
    else bad "$REMOTE/$MAIN has commits $MAIN does not -- history diverged"; fi
else
    ok "no $REMOTE/$MAIN yet (nothing pushed)"
fi

# Plan markers: ☐ not started, ◐ committed and unverified, ☑ verified. Only a
# task's own commits may change its marker, and this task must be ◐ or ☑.
markers_at() { git show "$1:$PLAN" 2>/dev/null | grep -oE "(☐|◐|☑) \*\*${ID_RE}" | sed -E 's/ \*\*/ /' | sort; }
changed=$(comm -13 <(markers_at "$base") <(markers_at "$tip") | awk '{print $2}' | sort -u)
worked_on=$(git log --format='%s' "$base".."$tip" | sed 's/:.*//' | tr ',' '\n' | grep -oE "$ID_RE" | sort -u)
state=$(markers_at "$tip" | awk -v t="$task" '$2 == t {print $1}')
case "$state" in
    ◐|☑) ok "the plan marks $task $state" ;;
    *)   bad "the plan does not mark $task ◐ (committed) or ☑ (verified) -- found '${state:-nothing}'" ;;
esac
unvouched=$(comm -23 <(printf '%s\n' "$changed" | grep . ) <(printf '%s\n' "$worked_on"))
if [ -z "$unvouched" ]; then ok "every marker changed here belongs to a task with a commit here"
else bad "markers changed for $(echo "$unvouched" | tr '\n' ' ')with no commit doing that work"; fi

# Green, once each. Determinism re-runs belong to the gate.
for cmd in "${CHECKS[@]}"; do
    if out=$(bash -c "$cmd" 2>&1); then ok "$cmd"; else bad "$cmd"; note "$(printf '%s\n' "$out" | tail -25)"; fi
done

echo "audit: $checked checks, $fail deviation(s)"
[ "$fail" -eq 0 ]
