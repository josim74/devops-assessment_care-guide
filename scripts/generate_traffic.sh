#!/usr/bin/env bash
# Generates normal traffic plus an optional error spike against the local app so the
# Application dashboard has something to show.
# Usage: ./scripts/generate_traffic.sh [--spike] [BASE_URL]
set -euo pipefail

SPIKE=false
if [[ "${1:-}" == "--spike" ]]; then
  SPIKE=true
  shift
fi
BASE_URL="${1:-http://localhost:8080}"

echo "==> Normal traffic (60 s)"
end=$((SECONDS + 60))
while [ "$SECONDS" -lt "$end" ]; do
  curl -s -o /dev/null "${BASE_URL}/"
  curl -s -o /dev/null "${BASE_URL}/health"
  sleep 0.2
done

if [ "$SPIKE" = true ]; then
  echo "==> Error spike: requests to unknown paths (404s, 60 s)"
  end=$((SECONDS + 60))
  while [ "$SECONDS" -lt "$end" ]; do
    curl -s -o /dev/null "${BASE_URL}/api/v1/does-not-exist"
    curl -s -o /dev/null "${BASE_URL}/"
    sleep 0.1
  done
fi
echo "==> Done"
