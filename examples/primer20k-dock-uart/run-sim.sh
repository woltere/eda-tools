#!/bin/sh
set -eu

BUILD_DIR="build/sim"
OBJ_DIR="$BUILD_DIR/obj_dir"
WAVEFORM_PATH="${1:-$BUILD_DIR/top.fst}"
CYCLES="${2:-70000}"
TB_CPP="$(pwd)/sim/tb_top.cpp"

case "$WAVEFORM_PATH" in
  *.fst)
    TRACE_FLAG="--trace-fst"
    ;;
  *.vcd)
    TRACE_FLAG="--trace"
    ;;
  *)
    echo "Unsupported waveform extension for $WAVEFORM_PATH" >&2
    echo "Use a .fst or .vcd filename." >&2
    exit 1
    ;;
esac

mkdir -p "$BUILD_DIR"

verilator \
  --cc \
  --build \
  --exe \
  "$TRACE_FLAG" \
  --top-module top \
  -Mdir "$OBJ_DIR" \
  -o sim-top \
  src/top.v \
  src/uart_tx.v \
  "$TB_CPP"

"$OBJ_DIR/sim-top" "$WAVEFORM_PATH" "$CYCLES"

printf 'Waveform ready: %s\n' "$WAVEFORM_PATH"
