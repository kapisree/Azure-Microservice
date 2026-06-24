#!/usr/bin/env bash
# Generate the pipeline dashboard.
# Usage: bash scripts/render-dashboard.sh [--root DIR] [--output DIR]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$ROOT_DIR"
dotnet run --project src/Tools/RenderDashboard --configuration Release -- "$@"

echo "[dashboard] Open docs/dashboard/index.html in a browser to view."
