#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
ELF_DIR=${1:-}
OUT_DIR=${OUT_DIR:-"$SCRIPT_DIR/work/verilator-act4"}
REPORT="$OUT_DIR/results.jsonl"

if [ -z "$ELF_DIR" ]; then
    echo "usage: $0 <elf-directory>" >&2
    exit 1
fi

mkdir -p "$OUT_DIR"
: > "$REPORT"

status=0
count=0
passed=0

for elf in "$ELF_DIR"/*.elf; do
    [ -e "$elf" ] || continue
    name=$(basename "$elf" .elf)
    hex=$(OUT_DIR="$OUT_DIR/hex" "$ROOT_DIR/sim/rv32i/elf-to-hex.sh" "$elf" "$name")
    if "$ROOT_DIR/sim/rv32i/run-sim.sh" "$hex" "$OUT_DIR/$name.fst" 200000; then
        echo "{\"test\":\"$name\",\"status\":\"pass\"}" >> "$REPORT"
        passed=$((passed + 1))
    else
        echo "{\"test\":\"$name\",\"status\":\"fail\"}" >> "$REPORT"
        status=1
    fi
    count=$((count + 1))
done

echo "ACT4 Verilator summary: $passed / $count passed"
exit "$status"
