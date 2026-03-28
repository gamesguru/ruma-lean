#!/usr/bin/env bash
set -e

RUSTC="$1"
shift

CMD=("$RUSTC")

if command -v sccache > /dev/null 2>&1; then
    CMD=(sccache "$RUSTC")
fi

if command -v mold > /dev/null 2>&1; then
    # Do not use mold if cross-compiling to webassembly or riscv (SP1)
    if [[ "$*" == *"wasm32"* ]] || [[ "$*" == *"riscv"* ]]; then
        : # skip mold
    else
        CMD+=("-C" "link-arg=-fuse-ld=mold")
    fi
fi

exec "${CMD[@]}" "$@"
