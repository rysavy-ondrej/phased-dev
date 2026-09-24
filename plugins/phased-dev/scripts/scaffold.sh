#!/usr/bin/env bash
# Install the phased-dev templates into a project, for one profile.
#
#   scaffold.sh <project-dir> <production|prototype> [--force]
#
# Copies CLAUDE.md, docs/*, scripts/{method.conf,task-audit.sh,gate.sh} and
# .claude/workflows/run-phase.js, keeping only the chosen profile's
# <!-- profile:X --> blocks. Never overwrites an existing file unless --force;
# prints what it skipped so nothing is clobbered silently.
set -eu
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tpl=$here/templates

dest=${1:-}; profile=${2:-}; force=${3:-}
case "$profile" in production|prototype) ;; *)
    echo "usage: scaffold.sh <project-dir> <production|prototype> [--force]" >&2; exit 2 ;;
esac
[ -d "$dest" ] || { echo "scaffold: $dest is not a directory" >&2; exit 2; }
other=$([ "$profile" = prototype ] && echo production || echo prototype)

# Drop the other profile's blocks, then the markers of this one.
filter() {
    awk -v drop="$other" -v keep="$profile" '
        $0 ~ "<!-- profile:" drop " -->"  { skip=1; next }
        $0 ~ "<!-- /profile:" drop " -->" { skip=0; next }
        $0 ~ "<!-- /?profile:" keep " -->" { next }
        !skip' "$1" | sed "s/{{PROFILE}}/$profile/g"
}

put() { # put <src> <dest-rel> [filter]
    local src=$1 rel=$2 target=$dest/$2
    if [ -e "$target" ] && [ "$force" != "--force" ]; then
        echo "skip   $rel (exists)"; return
    fi
    mkdir -p "$(dirname "$target")"
    if [ "${3:-}" = filter ]; then filter "$src" >"$target"; else cp "$src" "$target"; fi
    echo "write  $rel"
}

put "$tpl/CLAUDE.md" CLAUDE.md filter
for f in "$tpl"/docs/*.md; do
    name=$(basename "$f")
    [ "$name" = OUT_OF_SCOPE.md ] && [ "$profile" = production ] && continue
    put "$f" "docs/$name" filter
done
put "$tpl/scripts/task-audit.sh" scripts/task-audit.sh
put "$tpl/scripts/gate.sh" scripts/gate.sh
put "$tpl/scripts/phaseN-gate.sh" scripts/phase0-gate.sh
put "$tpl/workflows/run-phase.js" .claude/workflows/run-phase.js
if [ ! -e "$dest/scripts/method.conf" ] || [ "$force" = "--force" ]; then
    sed "s/^PROFILE=.*/PROFILE=$profile                 # production | prototype/" \
        "$tpl/scripts/method.conf" >"$dest/scripts/method.conf"
    echo "write  scripts/method.conf"
else
    echo "skip   scripts/method.conf (exists)"
fi
chmod +x "$dest"/scripts/*.sh 2>/dev/null || true
mkdir -p "$dest/docs/history"

echo
echo "Profile: $profile. Next: fill the {{placeholders}} (grep -rn '{{' CLAUDE.md docs),"
echo "set the commands in scripts/method.conf, and run the 'specify' then 'plan' skills."
