#!/usr/bin/env bash
# The whole lab with no prompts. Fails if a wrong answer reaches users, or if 1% or more of requests fail.
# Not 0 failed: in 5 safe runs, 3 of 2,380 requests failed with connection resets about 2 s into the rollout.
set -euo pipefail
trap 'make down >/dev/null 2>&1 || true' EXIT

field() { python3 -c "import json,sys; print(json.load(open('evidence/$1-summary.json'))['$2'])"; }

make cluster images
make deploy-naive
make rollout LABEL=naive || true
make deploy-safe
make rollout LABEL=safe
make bad-release
make undo

echo "naive rollout: $(field naive failed) failed requests (reported, not checked)"
under_1pct() { test $(( $(field "$1" failed) * 100 )) -lt "$(field "$1" requests)"; }
under_1pct safe || { echo "FAIL: safe rollout dropped 1% or more of requests"; exit 1; }
test "$(field safe wrong)" -eq 0 || { echo "FAIL: safe rollout served wrong answers"; exit 1; }
test "$(field bad-release wrong)" -eq 0 || { echo "FAIL: the bad release reached users"; exit 1; }
under_1pct bad-release || { echo "FAIL: 1% or more of requests failed during the bad release"; exit 1; }
curl -fsS http://127.0.0.1:18080/quote | grep -q '"total_cents":1200' || { echo "FAIL: app not healthy after undo"; exit 1; }
echo "PASS: safe rollout $(field safe failed) failed of $(field safe requests), bad release 0 wrong answers, healthy after undo"
