#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
ACT4_ROOT=${ACT4_ROOT:-"$SCRIPT_DIR/work/riscv-arch-test"}
CONFIG_FILE=${CONFIG_FILE:-"$SCRIPT_DIR/config/rv32i-softcore/test_config.yaml"}
WORKDIR=${WORKDIR:-"$SCRIPT_DIR/work/act4-out"}
JOBS=${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}

if [ ! -d "$ACT4_ROOT/.git" ]; then
    echo "missing ACT4 checkout at $ACT4_ROOT" >&2
    echo "run verification/act4/clone-act4.sh first" >&2
    exit 1
fi

mkdir -p "$WORKDIR"

cd "$ACT4_ROOT"
CONFIG_FILES="$CONFIG_FILE" WORKDIR="$WORKDIR" make --jobs "$JOBS"
