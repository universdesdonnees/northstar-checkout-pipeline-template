#!/usr/bin/env bash
# Sends N requests to the checkout of a namespace and counts how many of
# them reach the new version. It fails if no request or every request
# reaches the new version, because a canary must receive a small share.
# Usage: scripts/canary-share.sh <namespace> <new-version> <number-of-requests>
set -uo pipefail

NAMESPACE="$1"
NEW_VERSION="$2"
REQUESTS="${3:-40}"

HOST=$(kubectl -n "$NAMESPACE" get service checkout -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
NEW=0
OLD=0
for _ in $(seq 1 "$REQUESTS"); do
  VERSION=$(curl -s --max-time 5 "http://$HOST/api/info" | jq -r '.version' 2>/dev/null)
  if [ "$VERSION" = "$NEW_VERSION" ]; then
    NEW=$((NEW + 1))
  else
    OLD=$((OLD + 1))
  fi
  sleep 0.2
done

echo "$NEW of $REQUESTS requests reached the canary $NEW_VERSION, $OLD reached the stable version."
if [ "$NEW" -eq 0 ]; then
  echo "::error::No request reached the canary. Is its Pod ready and selected by the Service?"
  exit 1
fi
if [ "$OLD" -eq 0 ]; then
  echo "::error::Every request reached the new version. This is not a canary."
  exit 1
fi
