#!/usr/bin/env bash
# Phase <N> exit criterion, runnable. Written at the phase's FIRST task, before
# the code it grades, so it fails until the phase is done and cannot be bent to
# fit what was built.
#
# Rules for every check below:
#   * grade real output on real data, never an empty stream ("" = "" passes);
#   * when a check's setup fails, print FAIL "graded nothing", never ok;
#   * prove each check bites before relying on it.
set -u
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root" || exit 2
fail=0; checked=0
ok()  { checked=$((checked + 1)); printf 'ok    %s\n' "$1"; }
bad() { checked=$((checked + 1)); fail=$((fail + 1)); printf 'FAIL  %s\n' "$1"; }

# --- the exit criterion, quoted from the plan -------------------------------
# "<quote>"

# check 1: ...

echo "phase gate: $checked checks, $fail failure(s)"
[ "$fail" -eq 0 ]
