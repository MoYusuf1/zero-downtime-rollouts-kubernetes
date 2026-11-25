#!/usr/bin/env bash
# Wait until the app really answers through the Service. "rollout status" alone is not proof:
# without a readiness probe it reports done while the app is still warming up.
for i in $(seq 1 60); do
  if curl -fsS -m 1 http://127.0.0.1:18080/quote >/dev/null 2>&1; then
    echo "app answers after ${i}s: $(curl -fsS -m 1 http://127.0.0.1:18080/quote)"
    exit 0
  fi
  sleep 1
done
echo "app did not answer within 60s" >&2
exit 1
