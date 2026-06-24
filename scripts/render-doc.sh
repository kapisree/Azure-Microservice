#!/usr/bin/env bash
# scripts/render-doc.sh - Render a markdown doc to styled HTML.
# Async, never blocks the user's save.
set -euo pipefail
FILE="${1:-}"
[ -z "$FILE" ] && exit 0
[ -f "$FILE" ] || exit 0
mkdir -p docs/dashboard
LOG=docs/dashboard/.render-log
echo "[$(date -u +%FT%TZ)] render-doc start: $FILE" >> "$LOG"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
(cd "$ROOT_DIR" && dotnet run --project src/Tools/RenderDoc --configuration Release -- --source "$FILE" >> "$LOG" 2>&1 \
   || echo "[render-doc] failed (non-blocking): $FILE" >> "$LOG") &
disown || true
