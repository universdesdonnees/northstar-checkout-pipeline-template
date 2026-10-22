#!/usr/bin/env bash
# Smoke test of a deployed checkout. It passes when /health answers 200 and
# /api/info shows the expected version. It retries for about two minutes.
# Usage: scripts/smoke-test.sh http://<load-balancer-name> <expected-version>
set -uo pipefail

URL="$1"
EXPECTED="$2"

for ATTEMPT in $(seq 1 20); do
  HEALTH=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$URL/health")
  VERSION=$(curl -s --max-time 5 "$URL/api/info" | jq -r '.version' 2>/dev/null)
  echo "Attempt $ATTEMPT: /health answered ${HEALTH}, /api/info shows version ${VERSION:-none}"
  if [ "$HEALTH" = "200" ] && [ "$VERSION" = "$EXPECTED" ]; then
    echo "Smoke test passed: $URL runs version $EXPECTED"
    exit 0
  fi
  sleep 6
done

echo "::error::Smoke test failed: $URL does not answer with version $EXPECTED"
exit 1
