# Lab notes

Observed values only. Run 1 is the captured run (screenshots). The repeats were run right after it on the same cluster.

## Run 1 · 2026-11-24

- Setup: kind v0.33.0, Kubernetes v1.37.0, 1 control plane and 2 workers, kube-proxy in nftables mode, Docker 29.10.0. App image 15.4 MB on disk (3.26 MB content). Each new pod needs about 5 s to warm up before it can serve.
- Probe: about 20 requests a second to the app through its NodePort. ok = HTTP 200 with total 1200. failed = error or no answer. wrong = HTTP 200 with a wrong total.
- Naive rollout v1 to v2 (no readiness probe): 147 requests, 79 ok, **68 failed**, 0 wrong. Errors for 3.8 s. Every failure was `Connection reset by peer`. Kubernetes printed `successfully rolled out` while the app was still failing; no v2 answer reached the probe before it stopped 3 s later. (`screenshots/4.png`)
- Safe rollout v1 to v2 (readiness probe, maxUnavailable 0, preStop sleep 5 s): 478 requests, 478 ok, **0 failed**, 0 wrong. (`screenshots/6.png`)
- Bad release v3-bad (health 200, quote 999, readiness 503): the rollout stalled with 1 new pod at 0/1 and `exceeded its progress deadline` after 30 s. 738 requests, 737 ok, 1 failed, **0 wrong**. The one failure was a connection reset in the last 0.3 s of the probe. (`screenshots/7.png`, `screenshots/8.png`)
- Rollback: `kubectl rollout undo` brought back v2; the app answered `{"total_cents":1200,"version":"v2"}`. (`screenshots/9.png`)
- Cleanup: no kind clusters and no kind containers left. (`screenshots/10.png`)

## Repeats

| Run | Requests | Failed | Wrong |
| --- | --- | --- | --- |
| Naive rollout, repeat 2 | 154 | 73 (3.9 s) | 0 |
| Naive rollout, repeat 3 | 147 | 72 (3.7 s) | 0 |
| Safe rollout, `make e2e` | 479 | 0 | 0 |
| Safe rollout, repeat 1 | 479 | 1 (connection reset about 2 s into the rollout) | 0 |
| Safe rollout, repeat 2 | 477 | 0 | 0 |
| Bad release, repeat 1 | 722 | 0 | 0 |
| Bad release, repeat 2 | 734 | 0 | 0 |
| `make e2e` after the e2e change: naive | 147 | 71 | 0 |
| `make e2e` after the e2e change: safe | 467 | 2 (connection resets 2.3 s into the rollout) | 0 |
| `make e2e` after the e2e change: bad release | 722 | 0 | 0 |

Totals: naive 284 failed of 595 (4 runs). Safe 3 failed of 2,380 (5 runs). Bad release 1 failed and 0 wrong of 2,916 (4 runs).

All 3 safe-rollout failures were connection resets about 2 s after `kubectl set image`, before the first new pod was ready, so no old pod had stopped yet. Cause not found.

## What broke along the way

- Port 8080 on my PC was already taken, so the app is on 18080.
- Every Service request failed at first, while direct pod requests worked. kube-proxy logged `Extension statistic revision 0 not supported, missing kernel module?`. The PC was running an older kernel than the one installed (`7.3.5-1` running, `7.3.5-2` installed), so the kernel could not load new modules. A reboot fixed it.
- `kubectl rollout status` said done before the naive app could answer. The deploy step now waits until the app answers through the Service.
- One naive repeat failed from the first request because the "app answers" check was answered by old pods that were still shutting down. The deploy step now waits for the old pods to be deleted. That run is not in the table.
