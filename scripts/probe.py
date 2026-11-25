#!/usr/bin/env python3
"""Send about 20 requests a second to the app and count what users would see.

Stops on SIGTERM or after --seconds. Prints one summary line and writes every result to --out.
ok = HTTP 200 with the right total. wrong = HTTP 200 with a wrong total. failed = error or no answer.
"""
import argparse, json, signal, time, urllib.request

EXPECTED = 1200
p = argparse.ArgumentParser()
p.add_argument('--url', default='http://127.0.0.1:18080/quote')
p.add_argument('--seconds', type=float, default=0, help='0 = run until stopped')
p.add_argument('--out', required=True)
a = p.parse_args()

running = True
signal.signal(signal.SIGTERM, lambda *_: globals().update(running=False))
counts = {'ok': 0, 'failed': 0, 'wrong': 0}
versions, first_bad, last_bad = {}, None, None
start = time.time()

with open(a.out, 'w') as log:
    while running and (not a.seconds or time.time() - start < a.seconds):
        t = time.time()
        rec = {'t': round(t, 3)}
        try:
            with urllib.request.urlopen(a.url, timeout=1) as r:
                body = json.load(r)
            rec.update(status=r.status, version=body.get('version'), total=body.get('total_cents'))
            versions[rec['version']] = versions.get(rec['version'], 0) + 1
            kind = 'ok' if body.get('total_cents') == EXPECTED else 'wrong'
        except Exception as e:
            rec['error'] = type(e).__name__ + ': ' + str(e)[:80]
            kind = 'failed'
        rec['result'] = kind
        counts[kind] += 1
        if kind != 'ok':
            first_bad = first_bad or t
            last_bad = t
        log.write(json.dumps(rec) + '\n')
        time.sleep(max(0, 0.05 - (time.time() - t)))

total = sum(counts.values())
summary = dict(requests=total, **counts, versions=versions, seconds=round(time.time() - start, 1),
               bad_window_seconds=round(last_bad - first_bad, 1) if first_bad else 0)
with open(a.out.replace('.jsonl', '-summary.json'), 'w') as f:
    json.dump(summary, f)
print(f"probe: {total} requests | {counts['ok']} ok | {counts['failed']} failed | {counts['wrong']} wrong answers"
      f" | versions seen: {', '.join(f'{k} ({v})' for k, v in sorted(versions.items()))}")
