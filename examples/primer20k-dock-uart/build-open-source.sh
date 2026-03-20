#!/bin/sh
set -eu

BUILD_DIR="build"
TOP_JSON="$BUILD_DIR/top.json"
PNR_JSON="$BUILD_DIR/top_pnr.json"
BITSTREAM="$BUILD_DIR/primer20k-dock-uart.fs"

mkdir -p "$BUILD_DIR"

# Debian Bookworm's Yosys (0.23) does not support `synth_gowin -family`.
yosys -p 'read_verilog src/uart_tx.v src/top.v; synth_gowin -top top -json build/top.json'

nextpnr-himbaechel \
  --json "$TOP_JSON" \
  --write "$PNR_JSON" \
  --device GW2A-LV18PG256C8/I7 \
  --vopt family=GW2A-18 \
  --vopt cst=constraints/primer20k-dock.cst

gowin_pack -d GW2A-18 -o "$BITSTREAM" "$PNR_JSON"

printf 'Built %s\n' "$BITSTREAM"
