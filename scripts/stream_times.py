#!/usr/bin/env python3
"""Tabella dei tempi dello streaming veloce dalle righe `stream timing` di freekmusic.log.

    scripts/stream_times.py --log ~/.local/share/<app>/freekmusic.log
    scripts/stream_times.py --adb <serial> [--last 10]
    scripts/stream_times.py --self-test
"""
import argparse
import re
import statistics
import subprocess
import sys

# getApplicationSupportDirectory() on Android; AppLog writes `<iso8601> <message>` per line.
REMOTE_LOG = 'files/freekmusic.log'
PKG = 'com.freekmusic.player'
PREP = ('spawn', 'downloaded', 'post', 'cached')
KV = re.compile(r'(\w+)=(\S+)')


def parse(text):
    """-> (rows, malformed): rows are dicts of the key=value pairs of each valid line."""
    rows, bad = [], 0
    for line in text.splitlines():
        if 'stream timing' not in line:
            continue
        kv = dict(KV.findall(line.split('stream timing', 1)[1]))
        try:
            if 'play' in kv:
                ok = kv['from'] in ('cache', 'file', 'url') and int(kv['play']) >= 0 and int(kv.get('gap', 0)) >= 0
            else:
                ok = 'key' in kv and all(kv[m] == '-' or int(kv[m]) >= 0 for m in PREP)
        except (KeyError, ValueError):
            ok = False
        if ok:
            rows.append(kv)
        else:
            bad += 1
    return rows, bad


def table(text, last):
    rows, bad = parse(text)
    series = [(m, [int(r[m]) for r in rows if r.get(m, '-') != '-']) for m in PREP]
    series += [(f'play ({f})', [int(r['play']) for r in rows if r.get('from') == f]) for f in ('cache', 'file', 'url')]
    series.append(('gap (end of track to first sound)', [int(r['gap']) for r in rows if 'gap' in r]))
    out = ['| metric | n | median ms | max ms |', '|---|---|---|---|']
    stats = {}
    for name, vals in series:
        v = vals[-last:]
        stats[name] = (len(v), statistics.median(v), max(v)) if v else (0, None, None)
        n, med, mx = stats[name]
        out.append(f'| {name} | {n} | {"-" if med is None else f"{med:g}"} | {"-" if mx is None else mx} |')
    out.append(f'\nMalformed `stream timing` lines ignored: {bad}')
    return '\n'.join(out), stats, bad


SAMPLE = '''2026-01-01T10:00:00.000 [INFO] stream timing key=a requested=1 attempt=1 spawn=100 downloaded=5000 post=300 cached=5400 result=ok
2026-01-01T10:00:01.000 [INFO] stream timing key=a play=40 from=cache
2026-01-01T10:00:02.000 [INFO] stream timing key=b requested=0 attempt=1 spawn=300 downloaded=- post=- cached=- result=failed
2026-01-01T10:00:03.000 [INFO] stream timing key=c requested=1 attempt=2 spawn=200 downloaded=7000 post=500 cached=7700 result=ok
2026-01-01T10:00:04.000 [INFO] stream timing key=c play=1200 from=url
2026-01-01T10:00:05.000 [INFO] stream timing key=d play=abc from=url
2026-01-01T10:00:05.500 [INFO] stream timing key=d play=10 from=cloud
2026-01-01T10:00:06.000 [INFO] unrelated line
2026-01-01T10:00:07.000 [INFO] stream timing key=e play=60 from=cache
2026-01-01T10:00:08.000 [INFO] stream timing key=f play=50 from=url gap=300
2026-01-01T10:00:09.000 [INFO] stream timing key=g play=50 from=cache gap=100
'''


def self_test():
    _, st, bad = table(SAMPLE, 10)
    assert bad == 2, bad
    assert st['gap (end of track to first sound)'] == (2, 200, 300)
    assert st['spawn'] == (3, 200, 300), st['spawn']
    assert st['downloaded'] == (2, 6000, 7000), st['downloaded']
    assert st['post'] == (2, 400, 500) and st['cached'] == (2, 6550, 7700)
    assert st['play (cache)'] == (3, 50, 60) and st['play (url)'] == (2, 625, 1200)
    assert st['play (file)'] == (0, None, None)
    _, st, _ = table(SAMPLE, 1)  # --last 1 keeps only the latest line per metric
    assert st['spawn'] == (1, 200, 200) and st['play (cache)'] == (1, 50, 50)
    print('OK')


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--log')
    ap.add_argument('--adb', metavar='SERIAL')
    ap.add_argument('--last', type=int, default=10)
    ap.add_argument('--self-test', action='store_true')
    a = ap.parse_args()
    if a.self_test:
        return self_test()
    if bool(a.log) == bool(a.adb):
        ap.error('serve esattamente uno tra --log e --adb')
    if a.log:
        with open(a.log, encoding='utf-8', errors='replace') as f:
            text = f.read()
    else:
        r = subprocess.run(['adb', '-s', a.adb, 'exec-out', 'run-as', PKG, 'cat', REMOTE_LOG],
                           capture_output=True, text=True, errors='replace')
        if r.returncode:
            sys.exit(f'adb: {r.stderr.strip()}')
        text = r.stdout
    print(table(text, a.last)[0])


if __name__ == '__main__':
    main()
