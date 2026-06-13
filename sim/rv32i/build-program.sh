#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
OUT_DIR=${OUT_DIR:-"$SCRIPT_DIR/build"}
RAM_SIZE=${RAM_SIZE:-65536}
CC=${CC:-riscv64-unknown-elf-gcc}
OBJCOPY=${OBJCOPY:-riscv64-unknown-elf-objcopy}
OBJDUMP=${OBJDUMP:-riscv64-unknown-elf-objdump}
CFLAGS=${CFLAGS:--march=rv32i_zicsr -mabi=ilp32 -nostdlib -nostartfiles -ffreestanding -Wl,--build-id=none}

if [ "$#" -lt 1 ]; then
    echo "usage: $0 <source.[S|c]> [output-stem]" >&2
    exit 1
fi

SRC=$1
STEM=${2:-$(basename "$SRC")}
STEM=${STEM%.*}

mkdir -p "$OUT_DIR"

ELF="$OUT_DIR/$STEM.elf"
BIN="$OUT_DIR/$STEM.bin"
HEX="$OUT_DIR/$STEM.hex"
DIS="$OUT_DIR/$STEM.objdump"

"$CC" $CFLAGS -I"$SCRIPT_DIR/tests/common" -T"$SCRIPT_DIR/link.ld" "$SRC" -o "$ELF"
"$OBJCOPY" -O binary "$ELF" "$BIN"
"$OBJDUMP" -d "$ELF" > "$DIS"
"$SCRIPT_DIR/elf2hex.py" "$BIN" "$HEX" --size "$RAM_SIZE"

echo "$HEX"
