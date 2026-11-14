#!/usr/bin/env bash
# Deletes everything the live E2E runs saved in test-results/: screenshots, videos, traces,
# logs, reports and defect videos. The hand-written defect write-ups (test-results/defects/)
# are kept unless you pass --all.
#   ./clean-e2e-results.sh          # clean generated files, keep test-results/defects/
#   ./clean-e2e-results.sh --all    # also delete test-results/defects/
#   ./clean-e2e-results.sh --dry-run  # only list what would be deleted
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS="$ROOT/test-results"
ALL=0
DRY=0
for arg in "$@"; do
  case "$arg" in
    --all) ALL=1 ;;
    --dry-run) DRY=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

[ -d "$RESULTS" ] || { echo "Nothing to clean: $RESULTS does not exist."; exit 0; }

if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^ppp-e2e'; then
  echo "The E2E stack is still running; wait for the run to finish first." >&2
  exit 1
fi

targets=()
for entry in "$RESULTS"/* "$RESULTS"/.[!.]*; do
  [ -e "$entry" ] || continue
  if [ "$ALL" -eq 0 ] && [ "$(basename "$entry")" = "defects" ]; then continue; fi
  targets+=("$entry")
done

[ "${#targets[@]}" -gt 0 ] || { echo "Nothing to clean."; exit 0; }

for target in "${targets[@]}"; do
  size="$(du -sh "$target" | cut -f1)"
  if [ "$DRY" -eq 1 ]; then
    echo "would delete $target ($size)"
  else
    rm -rf -- "$target"
    echo "deleted $target ($size)"
  fi
done
