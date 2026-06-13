#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
OUT_DIR=${OUT_DIR:-"$SCRIPT_DIR/build/tests"}
TRACE_DIR="$OUT_DIR/traces"

mkdir -p "$OUT_DIR" "$TRACE_DIR"

status=0

for src in "$SCRIPT_DIR"/tests/*.S; do
    test_name=$(basename "$src" .S)
    echo "==> building $test_name"
    hex=$(OUT_DIR="$OUT_DIR" "$SCRIPT_DIR/build-program.sh" "$src" "$test_name")
    echo "==> running $test_name"
    if ! "$SCRIPT_DIR/run-sim.sh" "$hex" "$TRACE_DIR/$test_name.fst" 40000; then
        status=1
    fi
done

exit "$status"
