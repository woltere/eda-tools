#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
WORK_DIR=${WORK_DIR:-"$SCRIPT_DIR/work"}
ACT4_ROOT=${ACT4_ROOT:-"$WORK_DIR/riscv-arch-test"}

mkdir -p "$WORK_DIR"

if [ ! -d "$ACT4_ROOT/.git" ]; then
    git clone https://github.com/riscv/riscv-arch-test -b act4 "$ACT4_ROOT"
fi

echo "$ACT4_ROOT"
