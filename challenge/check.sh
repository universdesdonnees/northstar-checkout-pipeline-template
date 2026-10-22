#!/usr/bin/env bash
# Checks the canary challenge. Run it from the root of your repository, in
# CloudShell, after a pipeline run on main that went through the canary.
#   bash challenge/check.sh
set -uo pipefail

PASS=0
FAIL=0
check() {
  if [ "$2" = "ok" ]; then
    echo "  PASS  $1"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $1 ($2)"
    FAIL=$((FAIL + 1))
  fi
}

echo "1. The canary manifests"
if [ -f k8s/canary/kustomization.yaml ]; then
  check "k8s/canary/kustomization.yaml exists" ok
  RENDERED=$(kubectl kustomize k8s/canary 2> /dev/null)
else
  check "k8s/canary/kustomization.yaml exists" "file not found"
  RENDERED=""
fi
RESULT=$(printf '%s' "$RENDERED" | python3 -c '
import sys, yaml
docs = [d for d in yaml.safe_load_all(sys.stdin) if d]
deps = [d for d in docs if d.get("kind") == "Deployment"]
if not deps:
    print("no-deployment"); sys.exit()
d = deps[0]
spec = d["spec"]
print(d["metadata"].get("name"), d["metadata"].get("namespace"), spec.get("replicas"),
      spec["selector"]["matchLabels"].get("track"),
      spec["template"]["metadata"]["labels"].get("track"),
      spec["template"]["metadata"]["labels"].get("app"))
' 2> /dev/null)
read -r NAME NS REPLICAS SEL_TRACK POD_TRACK POD_APP <<< "${RESULT:-none}"
[ "$NAME" = "checkout-canary" ] && check "the Deployment is named checkout-canary" ok || check "the Deployment is named checkout-canary" "found ${NAME:-nothing}"
[ "${NS:-}" = "prod" ] && check "it runs in the namespace prod" ok || check "it runs in the namespace prod" "found ${NS:-nothing}"
[ "${REPLICAS:-}" = "1" ] && check "it runs one Pod" ok || check "it runs one Pod" "found ${REPLICAS:-nothing}"
[ "${SEL_TRACK:-}" = "canary" ] && [ "${POD_TRACK:-}" = "canary" ] && check "it selects and labels Pods with track: canary" ok || check "it selects and labels Pods with track: canary" "selector ${SEL_TRACK:-none}, Pods ${POD_TRACK:-none}"
[ "${POD_APP:-}" = "checkout" ] && check "its Pods keep app: checkout, so the Service sends them traffic" ok || check "its Pods keep app: checkout" "found ${POD_APP:-nothing}"

echo "2. The workflows"
[ -x scripts/canary-share.sh ] && check "scripts/canary-share.sh exists and is executable" ok || check "scripts/canary-share.sh exists and is executable" "missing or not executable"
WORKFLOW=$(python3 -c '
import yaml
w = yaml.safe_load(open(".github/workflows/pipeline.yml"))
jobs = w.get("jobs", {})
canary = jobs.get("canary", {})
prod = jobs.get("deploy-production", {})
needs = canary.get("needs", [])
needs = [needs] if isinstance(needs, str) else needs
env = canary.get("environment")
env = env.get("name") if isinstance(env, dict) else env
pneeds = prod.get("needs", [])
pneeds = [pneeds] if isinstance(pneeds, str) else pneeds
print("yes" if canary else "no", "yes" if "deploy-staging" in needs else "no",
      env or "none", "yes" if "canary" in pneeds else "no")
' 2> /dev/null)
read -r HAS_CANARY AFTER_STAGING CANARY_ENV PROD_AFTER <<< "${WORKFLOW:-no no none no}"
[ "$HAS_CANARY" = "yes" ] && check "pipeline.yml has a job canary" ok || check "pipeline.yml has a job canary" "job not found"
[ "$AFTER_STAGING" = "yes" ] && check "the canary job waits for deploy-staging" ok || check "the canary job waits for deploy-staging" "needs does not list deploy-staging"
[ "$CANARY_ENV" = "production" ] && check "the canary job uses the environment production" ok || check "the canary job uses the environment production" "found $CANARY_ENV"
[ "$PROD_AFTER" = "yes" ] && check "deploy-production waits for the canary job" ok || check "deploy-production waits for the canary job" "needs does not list canary"
grep -q "delete deployment checkout-canary" .github/workflows/deploy.yml && check "deploy.yml removes the canary after the full rollout" ok || check "deploy.yml removes the canary after the full rollout" "no 'delete deployment checkout-canary' in deploy.yml"

echo "3. The last pipeline run on main"
REPO=$(git remote get-url origin | sed -E 's#(https://github.com/|git@github.com:)##; s#\.git$##')
RUN_ID=$(curl -s "https://api.github.com/repos/$REPO/actions/workflows/pipeline.yml/runs?branch=main&event=push&per_page=1" | jq -r '.workflow_runs[0].id')
RUN_SHA=$(curl -s "https://api.github.com/repos/$REPO/actions/runs/$RUN_ID" | jq -r '.head_sha[0:7]')
JOBS=$(curl -s "https://api.github.com/repos/$REPO/actions/runs/$RUN_ID/jobs?per_page=50")
CANARY_JOB=$(echo "$JOBS" | jq -r '[.jobs[] | select(.name == "Canary in production")][0] | .conclusion + " " + .completed_at')
PROD_JOB=$(echo "$JOBS" | jq -r '[.jobs[] | select(.name | startswith("Production"))][0] | .conclusion + " " + .started_at')
read -r CANARY_RESULT CANARY_END <<< "${CANARY_JOB:-none none}"
read -r PROD_RESULT PROD_START <<< "${PROD_JOB:-none none}"
[ "$CANARY_RESULT" = "success" ] && check "the job 'Canary in production' succeeded in run $RUN_ID" ok || check "the job 'Canary in production' succeeded" "found ${CANARY_RESULT:-none}"
[ "$PROD_RESULT" = "success" ] && check "the production job succeeded" ok || check "the production job succeeded" "found ${PROD_RESULT:-none}"
[[ "$PROD_START" > "$CANARY_END" ]] && check "production started after the canary ended" ok || check "production started after the canary ended" "canary ended $CANARY_END, production started $PROD_START"

echo "4. The cluster"
kubectl -n prod get deployment checkout-canary > /dev/null 2>&1 && check "the canary Deployment is gone from prod" "checkout-canary still exists" || check "the canary Deployment is gone from prod" ok
PROD_TAG=$(kubectl -n prod get deployment checkout -o jsonpath='{.spec.template.spec.containers[0].image}' | sed 's/.*://')
[ "$PROD_TAG" = "$RUN_SHA" ] && check "prod runs the image of the last run, $RUN_SHA" ok || check "prod runs the image of the last run" "prod runs $PROD_TAG, last run built $RUN_SHA"

echo
echo "$PASS passed, $FAIL failed"
