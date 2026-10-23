#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/tmp/godot/godot}"
mkdir -p "$ROOT/build/web"
"$GODOT" --headless --path "$ROOT" --export-release "Web" "$ROOT/build/web/index.html"
echo "exported $ROOT/build/web/index.html"
