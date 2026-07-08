#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT="${1:-$ROOT/dist/PVE-Tools.sh}"
VERSION="$(cat "$ROOT/VERSION")"

mkdir -p "$(dirname "$OUTPUT")"

{
    echo '#!/bin/bash'
    echo
    echo "# PVE-Tools Pro v$VERSION"
    echo "# Build: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "# SPDX-License-Identifier: GPL-3.0-only"
    echo "# Copyright (C) 2026 Ciriu Networks"
    echo

    for lib_name in config.sh core.sh network.sh runtime.sh; do
        lib_file="$ROOT/lib/$lib_name"
        if [[ ! -f "$lib_file" ]]; then
            echo "Missing lib file: $lib_file" >&2
            exit 1
        fi
        echo "# [lib] $lib_name"
        cat "$lib_file"
        echo
    done

    while IFS= read -r -d '' module_file; do
        rel="${module_file#$ROOT/src/modules/}"
        echo "# [module] $rel"
        cat "$module_file"
        echo
    done < <(find "$ROOT/src/modules" -name '*.sh' -print0 | sort -z)

    echo 'main "$@"'
    echo
} > "$OUTPUT"

chmod +x "$OUTPUT"

total_lines=$(wc -l < "$OUTPUT")
total_size=$(wc -c < "$OUTPUT")
echo "Built: $OUTPUT"
echo "  Lines: $total_lines | Size: $(( total_size / 1024 ))KB"
