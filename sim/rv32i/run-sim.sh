#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
BUILD_DIR=${BUILD_DIR:-"$SCRIPT_DIR/build"}
SIM_BUILD_DIR="$BUILD_DIR/verilator"
HEX=${1:-}
TRACE=${2:-}
CYCLES=${3:-20000}

if [ -z "$HEX" ]; then
    echo "usage: $0 <program.hex> [trace.fst] [max-cycles]" >&2
    exit 1
fi

mkdir -p "$SIM_BUILD_DIR"

verilator \
  --cc \
  --build \
  --trace-fst \
  --timing \
  -Wall \
  -Wno-DECLFILENAME \
  -Wno-UNUSEDSIGNAL \
  -Wno-UNUSEDPARAM \
  -Wno-CASEINCOMPLETE \
  --Mdir "$SIM_BUILD_DIR" \
  --top-module rv32i_system \
  "$ROOT_DIR/rtl/rv32i/rv32i_core.sv" \
  "$SCRIPT_DIR/rv32i_system.sv" \
  "$SCRIPT_DIR/tb_top.cpp"

SIM_BIN="$SIM_BUILD_DIR/Vrv32i_system"

if [ -n "$TRACE" ]; then
    "$SIM_BIN" "+mem=$HEX" "+trace=$TRACE" "+cycles=$CYCLES"
else
    "$SIM_BIN" "+mem=$HEX" "+cycles=$CYCLES"
fi
