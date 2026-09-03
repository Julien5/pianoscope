#!/usr/bin/env bash

# Sort C directories by average note frequency (lowest first) into a "sorted" subdirectory.

set -euo pipefail

INPUT=${1:?usage: sort-with-freq.sh <input-dir>}
[ -d "$INPUT" ] || { echo "not a dir: $INPUT" >&2; exit 1; }

declare -A avg
for d in "$INPUT"/C*; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    total=0; n=0
    for f in "$d"/note_*.wav; do
        [ -e "$f" ] || continue
        fr=$(python3 freq.py "$f" 2>/dev/null | cut -d' ' -f1) || continue
        total=$((total + fr)); n=$((n + 1))
    done
    ((n > 0)) && avg[$name]=$((total / n))
done

mapfile -t ranked < <(
    for name in "${!avg[@]}"; do printf '%s %s\n' "$name" "${avg[$name]}"; done \
    | sort -k2 -n -k1
)
[ "${#ranked[@]}" -gt 0 ] || { echo "no sortable C dirs in $INPUT" >&2; exit 1; }

rm -rf "$INPUT/sorted"
mkdir -p "$INPUT/sorted"
n=1
declare -a mapping
for entry in "${ranked[@]}"; do
    name=${entry%% *}
    cp -r "$INPUT/$name" "$INPUT/sorted/C$n"
    mapping+=("$name -> C$n")
    n=$((n + 1))
done
echo "wrote $(($n - 1)) dirs to $INPUT/sorted"
printf '%s\n' "${mapping[@]}"
