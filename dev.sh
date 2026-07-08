#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for lib_file in \
    "$SCRIPT_DIR/lib/config.sh" \
    "$SCRIPT_DIR/lib/core.sh" \
    "$SCRIPT_DIR/lib/network.sh" \
    "$SCRIPT_DIR/lib/runtime.sh"; do
    # shellcheck source=/dev/null
    source "$lib_file"
done

while IFS= read -r -d '' module_file; do
    # shellcheck source=/dev/null
    source "$module_file"
done < <(find "$SCRIPT_DIR/src/modules" -name '*.sh' -print0 | sort -z)

main "$@"
