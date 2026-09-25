#!/usr/bin/env bash
# First look at a data corpus, cheaply: what is there, how much, in what formats.
# The test-data skill starts from this instead of opening files one by one.
#
#   scripts/data-inventory.sh <corpus-dir> [max-examples-per-type]
#
# Prints: totals, a breakdown by extension and by detected type (`file`), the
# size range per extension, the largest files, empty files, and a few example
# paths per extension. Reads only metadata and file headers -- never contents
# into the output -- so it is safe on sensitive data.
set -u
dir=${1:-}; ex=${2:-3}
[ -n "$dir" ] && [ -d "$dir" ] || { echo "usage: scripts/data-inventory.sh <corpus-dir> [examples]" >&2; exit 2; }
export LC_ALL=C

list=$(mktemp) || exit 2
trap 'rm -f "$list"' EXIT
# size<TAB>extension<TAB>path, regular files only
find "$dir" -type f -printf '%s\t%f\t%p\n' 2>/dev/null |
    awk -F'\t' '{ n=$2; e="(none)"; if (n ~ /\./ && n !~ /^\.[^.]*$/) { e=tolower(n); sub(/.*\./, "", e) } print $1 "\t" e "\t" $3 }' >"$list"

files=$(wc -l <"$list")
[ "$files" -gt 0 ] || { echo "no files under $dir"; exit 1; }
human() { numfmt --to=iec --suffix=B "$1" 2>/dev/null || echo "${1}B"; }

echo "corpus: $dir"
echo "files:  $files   total: $(human "$(awk -F'\t' '{s+=$1} END {print s}' "$list")")"
echo
echo "by extension:   count      total        min        max"
awk -F'\t' '{ c[$2]++; t[$2]+=$1; if (!($2 in mn) || $1<mn[$2]) mn[$2]=$1; if ($1>mx[$2]) mx[$2]=$1 }
    END { for (e in c) printf "%s\t%d\t%d\t%d\t%d\n", e, c[e], t[e], mn[e], mx[e] }' "$list" |
    sort -t$'\t' -k2,2nr | while IFS=$'\t' read -r e c t mn mx; do
        printf '  %-12s %7d %10s %10s %10s\n' "$e" "$c" "$(human "$t")" "$(human "$mn")" "$(human "$mx")"
    done

if command -v file >/dev/null; then
    echo
    echo "by detected type (file -b, first 200 files per extension):"
    awk -F'\t' '{ if (seen[$2]++ < 200) print $3 }' "$list" | tr '\n' '\0' |
        xargs -0 -r file -b 2>/dev/null | sed 's/,.*//' | sort | uniq -c | sort -rn | head -15 | sed 's/^/  /'
fi

echo
echo "largest files:"
sort -t$'\t' -k1,1nr "$list" | head -5 | while IFS=$'\t' read -r s e p; do printf '  %10s  %s\n' "$(human "$s")" "$p"; done

empty=$(awk -F'\t' '$1==0' "$list" | wc -l)
[ "$empty" -gt 0 ] && echo && echo "empty files: $empty"

echo
echo "examples per extension:"
awk -F'\t' -v k="$ex" '{ if (n[$2]++ < k) print "  [" $2 "] " $3 }' "$list" | sort
