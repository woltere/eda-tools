#!/bin/sh
set -eu

BUILD_DIR="build"
YOSYS_JSON="$BUILD_DIR/top-yosys.json"
DOT_FILE="$BUILD_DIR/top.dot"
SVG_FILE="$BUILD_DIR/top-netlistsvg.svg"

mkdir -p "$BUILD_DIR"

yosys -p 'read_verilog src/uart_tx.v src/top.v; hierarchy -top top; proc; opt; show -prefix build/top -format dot; write_json build/top-yosys.json'
netlistsvg "$YOSYS_JSON" -o "$SVG_FILE"

printf 'Generated %s\n' "$DOT_FILE"
printf 'Generated %s\n' "$SVG_FILE"
