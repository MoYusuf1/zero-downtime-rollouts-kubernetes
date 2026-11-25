#!/usr/bin/env bash
# Roll the Deployment to a new image while the probe counts what users see.
# Usage: scripts/measure-rollout.sh <image-tag> <label> [rollout timeout]
set -uo pipefail
tag=$1 label=$2 timeout=${3:-120s}
mkdir -p evidence
run() { printf '\033[1;36m$ %s\033[0m\n' "$*"; "$@"; }

python3 scripts/probe.py --out "evidence/$label.jsonl" &
probe=$!
sleep 3   # a few seconds of normal traffic first
run kubectl -n rollouts set image deployment/quote app="quote:$tag"
run kubectl -n rollouts rollout status deployment/quote --timeout="$timeout"
status=$?
sleep 3   # and a few seconds after
kill -TERM "$probe"
wait "$probe"
exit $status
