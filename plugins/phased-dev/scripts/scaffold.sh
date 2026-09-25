#!/usr/bin/env bash
# Install the phased-dev templates into a project.
#
#   scaffold.sh <project-dir> [--force]
#
# Copies CLAUDE.md, docs/*, scripts/{method.conf,task-audit.sh,gate.sh,
# progress.sh,data-inventory.sh,measure.sh,check-env.sh,phase1-gate.sh} and
# .claude/workflows/run-phase.js. Never
# overwrites an existing file unless --force -- in particular it leaves an
# existing docs/CONCEPT.md (the owner's own notes) alone -- and prints what it
# skipped so nothing is clobbered silently.
set -eu
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tpl=$here/templates

dest=${1:-}; force=${2:-}
[ -n "$dest" ] && [ -d "$dest" ] || { echo "usage: scaffold.sh <project-dir> [--force]" >&2; exit 2; }

put() { # put <src> <dest-rel>
    local target=$dest/$2
    if [ -e "$target" ] && [ "$force" != "--force" ]; then echo "skip   $2 (exists)"; return; fi
    mkdir -p "$(dirname "$target")"; cp "$1" "$target"; echo "write  $2"
}

put "$tpl/CLAUDE.md" CLAUDE.md
for f in "$tpl"/docs/*.md; do put "$f" "docs/$(basename "$f")"; done
for s in task-audit.sh gate.sh progress.sh data-inventory.sh measure.sh check-env.sh; do put "$tpl/scripts/$s" "scripts/$s"; done
# method.conf gets the project's name (the directory name) for the phase reports.
name=$(basename "$(cd "$dest" && pwd)" | tr -c 'A-Za-z0-9_.\n-' '-')
if [ -e "$dest/scripts/method.conf" ] && [ "$force" != "--force" ]; then
    echo "skip   scripts/method.conf (exists)"
else
    mkdir -p "$dest/scripts"
    sed "s/^PROJECT=project /PROJECT=$name /" "$tpl/scripts/method.conf" >"$dest/scripts/method.conf"
    echo "write  scripts/method.conf (PROJECT=$name)"
fi
put "$tpl/scripts/phaseN-gate.sh" scripts/phase1-gate.sh
put "$tpl/workflows/run-phase.js" .claude/workflows/run-phase.js
put "$here/skills/gate/references/phase-report.md" docs/reports/TEMPLATE.md
chmod +x "$dest"/scripts/*.sh 2>/dev/null || true
mkdir -p "$dest/docs/history" "$dest/docs/measurements" "$dest/docs/reports"

echo
echo "Next: the owner writes docs/CONCEPT.md (if not already there), then run the"
echo "'start' skill. Set the project's commands in scripts/method.conf."
