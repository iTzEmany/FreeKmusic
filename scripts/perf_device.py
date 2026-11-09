#!/usr/bin/env python3
"""Misure della fase 28 su un telefono vero, con un'app separata.

Installa la build «perf» (pacchetto com.codecore.player.perf, dati suoi: la
libreria vera dell'utente non viene mai toccata), le dà la libreria di prova di
scripts/perf_library.py, poi misura: scansione, avvio a freddo, memoria e i
frame mentre scorre «Tutti i brani», «Album», la ricerca e (con --playback)
«In riproduzione», il lettore che cresce dal dock, l'anello, «Apri album», i fogli,
lo swipe del mini player e l'apertura del player. Tabella in build/perf/<etichetta>.md.

    scripts/perf_library.py
    scripts/perf_device.py <id-adb> --label prima
    scripts/perf_device.py <id-adb> --label dopo --no-push   # stessa libreria, solo l'app nuova

Con --real si misura invece l'app VERA (com.codecore.player) con la sua libreria, senza
toccare i dati: niente `pm clear`, niente push, nessuna scrittura su impostazioni o database
(l'APK ha CODECORE_PERF_REAL, che registra soltanto i frame); niente riproduzione. Vuole
--apk (o costruisce da sé senza CODECORE_PERF), gli scenari di serie sono quelli che non
dipendono dai nomi della libreria di prova (più gli avvii a freddo) e uno che non trova il
suo nodo viene saltato. Alla fine cancella perf/events.jsonl dall'app.

    scripts/perf_device.py <id-adb> --real --apk app-profile-real.apk --label vera

Prende lo schermo per qualche minuto. Con --playback suona brani muti: un'altra
app che sta suonando si mette in pausa.
"""
import argparse
import json
import math
import os
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

PKG = 'com.codecore.player.perf'
ACTIVITY = f'{PKG}/com.codecore.player.MainActivity'
REMOTE = f'/sdcard/Android/data/{PKG}/files'
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FRAME_60HZ = 1000 / 60

REAL_PKG = 'com.codecore.player'
REAL_DEFAULT = 'Pallino schede,Tutti i brani,Album,Ricerca «notte»'


class Device:
    def __init__(self, serial):
        self.serial = serial

    def adb(self, *args, check=True):
        r = subprocess.run(['adb', '-s', self.serial, *args], capture_output=True, text=True)
        if check and r.returncode != 0:
            raise RuntimeError(f'adb {" ".join(args)}: {r.stderr.strip()}')
        return r.stdout

    def sh(self, cmd, check=True):
        # The phone may be in use: a tap or a text meant for the app must never land in another one.
        if cmd.startswith('input ') and 'WAKEUP' not in cmd and 'MEDIA_PAUSE' not in cmd:
            focus = self.adb('shell', 'dumpsys window | grep mCurrentFocus', check=False)
            if f'{PKG}/' not in focus:
                raise RuntimeError(f'{PKG} not in front ({focus.strip()}): «{cmd}» not sent')
        return self.adb('shell', cmd, check=check)

    def now_ms(self):
        return int(self.sh('date +%s%3N').strip())

    def nodes(self):
        for _ in range(5):
            self.sh('rm -f /sdcard/cc_perf_ui.xml', check=False)
            self.sh('uiautomator dump /sdcard/cc_perf_ui.xml', check=False)
            raw = self.sh('cat /sdcard/cc_perf_ui.xml', check=False)
            if raw.strip().startswith('<?xml'):
                self.sh('rm -f /sdcard/cc_perf_ui.xml', check=False)
                out = []
                for n in ET.fromstring(raw).iter('node'):
                    label = (n.get('content-desc') or n.get('text') or '').strip()
                    m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', n.get('bounds', ''))
                    if m:
                        x1, y1, x2, y2 = map(int, m.groups())
                        out.append((label, n.get('class', ''), (x1 + x2) // 2, (y1 + y2) // 2))
                return out
            time.sleep(0.8)
        raise RuntimeError('uiautomator dump failed')

    def tap(self, pattern, cls=None, last=False):
        rx = re.compile(pattern)
        nodes = self.nodes()
        for label, c, x, y in (reversed(nodes) if last else nodes):
            if rx.search(label) and (cls is None or cls in c):
                self.sh(f'input tap {x} {y}')
                time.sleep(1.5)
                return
        raise RuntimeError(f'nothing on screen matches {pattern!r}')

    def flings(self, n=5):
        w, h = map(int, re.search(r'(\d+)x(\d+)', self.sh('wm size')).groups())
        x = w // 2
        for direction in ('up', 'down'):
            for _ in range(n):
                y1, y2 = (int(h * 0.7), int(h * 0.3)) if direction == 'up' else (int(h * 0.3), int(h * 0.7))
                self.sh(f'input swipe {x} {y1} {x} {y2} 120')
                time.sleep(0.4)

    def top(self):
        """Back to the top of the list on screen (it keeps its scroll between tabs)."""
        w, h = map(int, re.search(r'(\d+)x(\d+)', self.sh('wm size')).groups())
        for _ in range(2):
            self.sh(f'input swipe {w // 2} {int(h * 0.3)} {w // 2} {int(h * 0.7)} 120')
            time.sleep(0.4)

    def events(self):
        raw = self.sh(f'cat {REMOTE}/perf/events.jsonl', check=False)
        return [json.loads(l) for l in raw.splitlines() if l.strip().startswith('{')]


def build(real=False):
    # CODECORE_PERF in the environment makes gradle give the app the .perf package: never for --real.
    env = {k: v for k, v in os.environ.items() if k != 'CODECORE_PERF'}
    if not real:
        env['CODECORE_PERF'] = '1'
    define = 'CODECORE_PERF_REAL=true' if real else 'CODECORE_PERF=true'
    subprocess.run(['flutter', 'build', 'apk', '--profile', '--target-platform', 'android-arm64',
                    f'--dart-define={define}'], cwd=ROOT, env=env, check=True)
    return os.path.join(ROOT, 'build/app/outputs/flutter-apk/app-profile.apk')


def pct(values, p):
    """Nearest-rank percentile, as summarizeFrames in lib/core/frame_stats.dart."""
    if not values:
        return 0.0
    v = sorted(values)
    rank = max(1, min(len(v), math.ceil(p / 100 * len(v))))
    return v[rank - 1]


def summary(bursts):
    raw = [f for b in bursts for f in b.get('raw', [])]
    if not raw:
        return None
    build_ms, raster_ms = [f[0] for f in raw], [f[1] for f in raw]
    budget = min((b.get('budgetMs', FRAME_60HZ) for b in bursts), default=FRAME_60HZ)
    late = lambda limit: sum(1 for b, r in raw if b > limit or r > limit) / len(raw) * 100
    return {
        'frames': len(raw),
        'build': [pct(build_ms, p) for p in (50, 90, 99)],
        'raster': [pct(raster_ms, p) for p in (50, 90, 99)],
        'jank60': late(FRAME_60HZ),
        'jankBudget': late(budget),
        'budget': budget,
    }


def wait_for(dev, event, timeout_s):
    end = time.time() + timeout_s
    while time.time() < end:
        found = [e for e in dev.events() if e.get('event') == event]
        if found:
            return found[-1]
        time.sleep(3)
    raise RuntimeError(f'no «{event}» from the app within {timeout_s} s')


# Every scenario name, in order; the second tuple needs playback. gestures() asserts against it.
SCENARIOS = ('Pallino schede', 'Tutti i brani', 'Album', 'Libreria Tutto→Playlist→Album→Artisti',
             'Ricerca «notte»', 'Scroll Libreria', 'Lente Libreria', 'Scroll Tutti i brani', 'Cambio scheda',
             'Apri album', 'In riproduzione',
             'Lettore dal dock', 'Swipe mini player', 'Fogli', 'Apertura player')
PLAYBACK_SCENARIOS = set(SCENARIOS[SCENARIOS.index('In riproduzione'):])


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('device')
    ap.add_argument('--label', default=time.strftime('%Y%m%d-%H%M'))
    ap.add_argument('--no-build', action='store_true')
    ap.add_argument('--apk', help='an APK already built (e.g. from an older commit) instead of building')
    ap.add_argument('--no-push', action='store_true', help='keep the perf app data (library already scanned)')
    ap.add_argument('--runs', type=int, default=5, help='cold starts')
    ap.add_argument('--playback', action='store_true', help='also «In riproduzione» (plays silent tracks)')
    ap.add_argument('--only', help='run only these scenarios (exact names, comma separated, e.g. "Fogli,Apertura player"); '
                                   'skips the cold starts; the playback ones imply --playback')
    ap.add_argument('--real', action='store_true',
                    help='measure the real app (com.codecore.player) without touching its data; needs --apk or builds one')
    args = ap.parse_args()
    global PKG, ACTIVITY, REMOTE
    if args.real:
        PKG = REAL_PKG
        ACTIVITY = f'{PKG}/com.codecore.player.MainActivity'
        REMOTE = f'/sdcard/Android/data/{PKG}/files'
        args.no_push = True
        if args.no_build:
            sys.exit('--real: usa --apk (app-profile.apk potrebbe essere la build .perf) oppure lascia costruire')
        if args.playback:
            sys.exit('--real: niente --playback (scriverebbe ascolti veri)')
        if args.only is None:
            args.only = REAL_DEFAULT
    only = {n.strip() for n in args.only.split(',') if n.strip()} if args.only is not None else None
    if only is not None:
        bad = sorted(only - set(SCENARIOS)) or ([''] if not only else [])
        if bad:
            sys.exit(f'--only: nomi non validi {bad}; validi: ' + ', '.join(SCENARIOS))
        if not args.real:
            args.runs = 0
        if args.real and only & PLAYBACK_SCENARIOS:
            sys.exit('--real: niente scenari di riproduzione')
        args.playback = args.playback or bool(only & PLAYBACK_SCENARIOS)
    dev = Device(args.device)
    lib = os.path.join(ROOT, 'build/perf_library')
    if not args.no_push and not os.path.isdir(lib):
        sys.exit('manca la libreria di prova: scripts/perf_library.py')

    if args.apk:
        apk = os.path.abspath(args.apk)
    elif args.no_build:
        apk = os.path.join(ROOT, 'build/app/outputs/flutter-apk/app-profile.apk')
    else:
        apk = build(args.real)
    print(dev.adb('install', '-r', apk).strip().splitlines()[-1])
    # Android 13+: the notification prompt would cover the mini player once playback starts.
    dev.sh(f'pm grant {PKG} android.permission.POST_NOTIFICATIONS', check=False)
    model = dev.sh('getprop ro.product.model').strip()
    dev.sh('input keyevent KEYCODE_WAKEUP')

    if not args.no_push:
        assert PKG.endswith('.perf'), 'only the perf app may be cleared'
        dev.sh(f'pm clear {PKG}')
        dev.sh(f'mkdir -p {REMOTE}/Music')
        dev.adb('push', lib + '/.', f'{REMOTE}/Music/')
        # Android 15: folders adb creates belong to the shell user and the app cannot list them.
        dev.sh(f'chmod -R o+rX {REMOTE}/Music')
    else:
        dev.sh(f'rm -f {REMOTE}/perf/events.jsonl', check=False)
    dev.sh(f'am start -W -n {ACTIVITY}')
    scan = None
    if not args.no_push:
        scan = wait_for(dev, 'scan', 900)
        wait_for(dev, 'heavyColumns', 300)
        print(f'scansione: {scan["tracks"]} brani in {scan["ms"] / 1000:.1f} s')

    starts, first = [], []
    for _ in range(args.runs):
        dev.sh(f'am force-stop {PKG}')
        time.sleep(2)
        before = len([e for e in dev.events() if e.get('event') == 'firstFrame'])
        out = dev.sh(f'am start -W -n {ACTIVITY}')
        m = re.search(r'TotalTime:\s*(\d+)', out)
        if m:
            starts.append(int(m.group(1)))
        time.sleep(5)
        ff = [e for e in dev.events() if e.get('event') == 'firstFrame']
        if len(ff) > before:
            first.append(ff[-1]['ms'])
    time.sleep(3)

    windows = {}
    w, h = map(int, re.search(r'(\d+)x(\d+)', dev.sh('wm size')).groups())

    def gestures(name, setup, action):
        """Only short spans around each gesture are measured (not the idle between); setup does the lookups."""
        assert name in SCENARIOS, name
        if only and name not in only:
            if name == 'In riproduzione':  # starts the playback the later scenarios need
                setup(), action(lambda act, wait=0.8: (act(), time.sleep(wait)))
            return
        spans = []

        def timed(act, wait=0.8):
            t0 = dev.now_ms()
            act()
            time.sleep(wait)
            spans.append((t0, dev.now_ms()))
        timed.spans = spans
        try:
            setup()
            time.sleep(2.5)
            action(timed)
            time.sleep(1)
        except RuntimeError as e:
            if not args.real:
                raise
            return print(f'  {name}: saltato ({e})')
        windows[name] = (spans, True)
        print(f'  {name}: fatto')

    def find(pattern, cls=None, last=False):
        rx = re.compile(pattern)
        # A sheet still opening is not in the tree yet («Fogli» failed on «Etichette», 107.5).
        for attempt in range(4):
            if attempt:
                time.sleep(0.5)
            for label, c, x, y in (reversed(dev.nodes()) if last else dev.nodes()):
                if rx.search(label) and (cls is None or cls in c):
                    return x, y
        raise RuntimeError(f'nothing on screen matches {pattern!r}')

    pos = {}  # screen positions resolved in the setups, never inside a measured span

    def press(xy):
        dev.sh(f'input tap {xy[0]} {xy[1]}')

    def back():
        dev.sh('input keyevent KEYCODE_BACK')
        time.sleep(1.2)

    # The dock is the last match: the Library header has a «Cerca» button too.
    tab = lambda name: dev.tap(rf'^{name}$', cls='Button', last=True)

    def leave_search():
        # The open search field hides the tabs: BACK (keyboard, then field) until they are back.
        for _ in range(3):
            ns = dev.nodes()
            # The library lens keeps the dock visible but hides the tabs: close it too.
            if any(l == 'Libreria' and 'Button' in c for l, c, *_ in ns) and not any(l == 'Chiudi la ricerca' for l, *_ in ns):
                return
            dev.sh('input keyevent KEYCODE_BACK')
            time.sleep(1)

    def to_library_top():
        leave_search(), tab('Libreria'), dev.tap(r'^Tutto$'), dev.top()

    def find_docks(*names):
        pos['dock'] = {t: find(rf'^{t}$', cls='Button', last=True) for t in names}

    def tabs(*names):
        def action(timed):
            for t in names:
                timed(lambda: press(pos['dock'][t]), wait=0.5)
        return action

    def flings(timed, n=5):
        for direction in ('up', 'down'):
            for _ in range(n):
                y1, y2 = (int(h * 0.7), int(h * 0.3)) if direction == 'up' else (int(h * 0.3), int(h * 0.7))
                timed(lambda: dev.sh(f'input swipe {w // 2} {y1} {w // 2} {y2} 120'), wait=0.4)

    gestures('Pallino schede', lambda: find_docks('Libreria', 'Memoria', 'Home'),
             tabs('Libreria', 'Memoria', 'Home', 'Libreria', 'Home'))
    # Each of the next two starts from any screen (no --only dependency): to_library_top first.
    gestures('Tutti i brani', lambda: (to_library_top(), dev.tap(r'^Tutti i brani')), flings)
    gestures('Album', lambda: (to_library_top(), dev.tap(r'^Album$')), flings)

    def setup_library_tabs():
        to_library_top()
        pos['lib'] = {b: find(rf'^{b}$') for b in ('Tutto', 'Playlist', 'Album', 'Artisti')}

    def library_tabs(timed):
        for _ in range(3):
            for b in ('Tutto', 'Playlist', 'Album', 'Artisti'):
                timed(lambda: press(pos['lib'][b]), wait=0.6)
    gestures('Libreria Tutto→Playlist→Album→Artisti', setup_library_tabs, library_tabs)

    def setup_search():
        leave_search(), tab('Cerca')  # the search tab, not the Library lens: that one would keep the query
        dev.tap(r'', cls='EditText')

    def search(timed):
        timed(lambda: dev.sh('input text notte'), wait=2)
        flings(timed, 3)
    gestures('Ricerca «notte»', setup_search, search)

    # The four below start from any screen (no --only dependency) and end on the Library.
    gestures('Scroll Libreria', to_library_top, flings)

    def setup_lens():
        to_library_top()
        time.sleep(2.5)  # the header finishes expanding before its buttons are looked up
        pos['lens'] = find(r'^Cerca$', cls='Button')  # in tree order the header comes before the dock
        if pos['lens'][1] > h // 2:
            raise RuntimeError('the Library header (with its lens) is not on screen')
        press(pos['lens'])
        time.sleep(1)
        pos['close'] = find(r'^Chiudi la ricerca$')
        press(pos['close'])
        time.sleep(1)

    def lens_cycles(timed):
        for _ in range(4):
            timed(lambda: press(pos['lens']), wait=0.8)
            timed(lambda: press(pos['close']))
    gestures('Lente Libreria', setup_lens, lens_cycles)

    def slow_scroll(timed):
        # Slow drags (unlike the fast flings of «Tutti i brani»): the retracting bar follows the finger.
        for direction in (1, -1):
            for _ in range(4):
                a, b = (0.7, 0.3) if direction == 1 else (0.3, 0.7)
                timed(lambda: dev.sh(f'input swipe {w // 2} {int(h * a)} {w // 2} {int(h * b)} 700'), wait=0.4)
        dev.sh('input keyevent KEYCODE_BACK')
    gestures('Scroll Tutti i brani', lambda: (to_library_top(), dev.tap(r'^Tutti i brani')), slow_scroll)
    gestures('Cambio scheda', lambda: (leave_search(), find_docks('Cerca', 'Memoria', 'Home', 'Libreria')),
             tabs(*('Cerca', 'Memoria', 'Home', 'Libreria') * 3))

    def setup_album():
        leave_search(), tab('Libreria'), dev.tap(r'^Tutto$')
        pos['album'] = find(r'^Album \d+')

    def open_albums(timed):
        for _ in range(3):
            timed(lambda: press(pos['album']))
            timed(lambda: dev.sh('input keyevent KEYCODE_BACK'))
            time.sleep(0.7)
    gestures('Apri album', setup_album, open_albums)

    def setup_mini():
        mini_nodes = dev.nodes()
        y = next(y for l, c, x, y in mini_nodes if l == 'Dispositivi')
        pos['devices'] = next((x, y) for l, c, x, y in mini_nodes if l == 'Dispositivi')
        # The left half of the mini-player card (one Button since 43.1), clear of its action buttons.
        pos['mini'] = (next(x for l, c, x, yy in mini_nodes if '\n' in l
                            and c in ('android.view.View', 'android.widget.Button') and abs(yy - y) <= 24) // 2, y)

    def swipes(timed):
        x, y = pos['mini']
        for _ in range(3):
            for a, b in ((0.8, 0.2), (0.2, 0.8)):
                timed(lambda: dev.sh(f'input swipe {int(w * a)} {y} {int(w * b)} {y} 150'))

    def sheets(timed):
        # The player screen has no accessibility tree while it plays: its buttons are tried by label
        # once and then taken by screen fraction. Each sheet, which does have a tree, is checked by label.
        labels = [True]

        def target(rx, fx, fy):
            if labels[0]:
                try:
                    return find(rx)
                except RuntimeError:
                    labels[0] = False
            return int(w * fx), int(h * fy)

        for _ in range(3):
            press(pos['mini'])
            time.sleep(1.5)
            # A fresh install shows the Bluetooth permission card first («Cerca le Jam vicine»).
            for rx, fx, fy, shown in ((r'^Coda$', 0.85, 0.897, r'^Prossimi$'),
                                      (r'^Dispositivi$', 0.2, 0.897, r'^(Dispositivi vicini|Cerca le Jam vicine)')):
                xy = target(rx, fx, fy)
                timed(lambda: press(xy))
                find(shown)
                timed(lambda: dev.sh('input keyevent KEYCODE_BACK'))
                time.sleep(0.7)
            # The Bluetooth card can need a second BACK; untimed, and never past the player.
            for _ in range(2):
                if any(re.match(r'^Altre (azioni|opzioni)$', l) for l, *_ in dev.nodes()):
                    break
                dev.sh('input keyevent KEYCODE_BACK')
                time.sleep(0.7)
            xy = target(r'^Altre (azioni|opzioni)$', 0.89, 0.08)
            timed(lambda: press(xy))
            etichette = find(r'^Etichette')
            timed(lambda: press(etichette))
            find(r'^Nuova etichetta')
            timed(lambda: dev.sh('input keyevent KEYCODE_BACK'))
            time.sleep(0.7)
            back()  # the player

    def open_player(timed):
        # Alternating the gestures: a tap on the mini player and a fling up from it. A fling that
        # misses (it does now and then) is dropped from the measure and tried again.
        x, y = pos['mini']
        opened = {'tap': 0, 'fling': 0}
        for attempt in range(12):
            kind = 'tap' if opened['tap'] <= opened['fling'] else 'fling'
            if opened[kind] == 3:
                kind = 'fling' if kind == 'tap' else 'tap'
            act = (lambda: press((x, y))) if kind == 'tap' else (
                lambda: dev.sh(f'input swipe {x} {y} {x} {y - int(h * 0.25)} 80'))
            timed(act, wait=1.0)
            try:
                shown = dev.nodes()
            except RuntimeError:
                shown = []  # no accessibility tree: the player (always animating) is open
            if any(l == 'Dispositivi' and (xx, yy) == pos['devices'] for l, c, xx, yy in shown):
                timed.spans.pop()  # the mini player is still there: nothing opened
            else:
                opened[kind] += 1
                back()
            if opened['tap'] + opened['fling'] == 6:
                return
        raise RuntimeError(f'the mini player opened the player only {opened} times in 12 tries')

    if args.playback:
        def setup_playing():
            leave_search(), tab('Libreria'), dev.tap(r'^Tutto$'), dev.top(), dev.tap(r'^Tutti i brani')
            dev.tap(r'^[A-Z].* \d+')
            time.sleep(2)
            setup_mini()

        def play_open(timed):
            timed(lambda: press(pos['mini']), wait=2)
            timed(lambda: dev.sh('input keyevent KEYCODE_BACK'))
        gestures('In riproduzione', setup_playing, play_open)

        def dock_player(timed):
            for _ in range(3):
                timed(lambda: press(pos['mini']), wait=1.2)
                timed(lambda: dev.sh('input keyevent KEYCODE_BACK'), wait=1.5)
        gestures('Lettore dal dock', setup_mini, dock_player)
        gestures('Swipe mini player', setup_mini, swipes)
        gestures('Fogli', setup_mini, sheets)
        gestures('Apertura player', setup_mini, open_player)
        dev.sh('input keyevent KEYCODE_MEDIA_PAUSE', check=False)

    mem = dev.sh(f'dumpsys meminfo {PKG}')
    pss = re.search(r'TOTAL PSS:\s*(\d+)', mem) or re.search(r'^\s*TOTAL\s+(\d+)', mem, re.M)
    events = dev.events()
    bursts = [e for e in events if e.get('event') == 'burst']
    if args.real:
        dev.sh(f'rm -f {REMOTE}/perf/events.jsonl', check=False)

    lines = [f'# Misure fase 28 — {args.label}', '',
             f'Dispositivo: {model} ({args.device}), build profile, app `{PKG}`'
             f'{" (vera, dati intatti)" if args.real else " (separata)"}.', '']
    if scan:
        lines.append(f'- Scansione: {scan["tracks"]} brani in {scan["ms"] / 1000:.1f} s')
    if starts:
        lines.append(f'- Avvio a freddo (`am start -W`, TotalTime): mediana {sorted(starts)[len(starts) // 2]} ms '
                     f'su {len(starts)} ({", ".join(map(str, starts))})')
    if first:
        lines.append(f'- Da `main` al primo frame: mediana {sorted(first)[len(first) // 2]} ms')
    if pss:
        lines.append(f'- Memoria (PSS totale): {int(pss.group(1)) // 1024} MB')
    lines += ['', '| Scenario | Frame | build p50/p90/p99 ms | raster p50/p90/p99 ms | > 16,7 ms | > budget |',
              '|---|---|---|---|---|---|']
    def in_spans(spans, trim):
        if not trim:
            return [b for t0, t1 in spans for b in bursts if t0 <= b['t'] <= t1]
        # A burst has one timestamp (its flush) for frames that keep coming without a pause while
        # playing: spread them back from it at one budget each, keep those inside a span.
        # shortcut: estimated frame times, upgrade by timestamping frames in perf_probe (lib/).
        kept = []
        for b in bursts:
            raw, step = b.get('raw', []), b.get('budgetMs', FRAME_60HZ)
            for t0, t1 in spans:
                if t0 <= b['t'] <= t1 + 2500:
                    inside = [f for i, f in enumerate(raw) if t0 <= b['t'] - (len(raw) - 1 - i) * step <= t1]
                    kept.append({**b, 'raw': inside})
        return kept

    for name, (spans, trim) in windows.items():
        s = summary(in_spans(spans, trim))
        if s is None:
            lines.append(f'| {name} | 0 | – | – | – | – |')
            continue
        f3 = lambda v: '/'.join(f'{x:.1f}' for x in v)
        lines.append(f'| {name} | {s["frames"]} | {f3(s["build"])} | {f3(s["raster"])} | '
                     f'{s["jank60"]:.1f} % | {s["jankBudget"]:.1f} % ({s["budget"]:.1f} ms) |')
    out_dir = os.path.join(ROOT, 'build/perf')
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, f'{args.label}.md'), 'w') as f:
        f.write('\n'.join(lines) + '\n')
    with open(os.path.join(out_dir, f'{args.label}.events.jsonl'), 'w') as f:
        f.write('\n'.join(json.dumps(e) for e in events) + '\n')
    print('\n'.join(lines))


if __name__ == '__main__':
    main()
