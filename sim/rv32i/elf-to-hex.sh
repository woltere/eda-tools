#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
OUT_DIR=${OUT_DIR:-"$SCRIPT_DIR/build"}
OBJCOPY=${OBJCOPY:-riscv64-unknown-elf-objcopy}
RAM_SIZE=${RAM_SIZE:-65536}

if [ "$#" -lt 1 ]; then
    echo "usage: $0 <input.elf> [output-stem]" >&2
    exit 1
fi

ELF=$1
STEM=${2:-$(basename "$ELF" .elf)}
BIN="$OUT_DIR/$STEM.bin"
HEX="$OUT_DIR/$STEM.hex"

mkdir -p "$OUT_DIR"
"$OBJCOPY" -O binary "$ELF" "$BIN"
"$SCRIPT_DIR/elf2hex.py" "$BIN" "$HEX" --size "$RAM_SIZE"

echo "$HEX"
