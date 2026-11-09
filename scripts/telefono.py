#!/usr/bin/env python3
"""Prove a mano su un telefono con poche chiamate e output corto (mai il dump XML intero).

    scripts/telefono.py <serial> prepara            # sveglia, stayon, blocco (con $TELEFONO_PIN sblocca, sennò exit 3), app davanti, volume, Non disturbare
    scripts/telefono.py <serial> sblocca [PIN]      # sveglia, swipe, PIN (argomento o $TELEFONO_PIN, mai nel file); exit 0/1
    scripts/telefono.py <serial> avvia <package>    # avvia l'attività principale e attende il focus
    scripts/telefono.py <serial> testi [regex]      # nodi visibili «testo | x,y» (max 60 righe)
    scripts/telefono.py <serial> tocca <regex> [--attesa S]   # tocca il nodo (riprova S s, di serie 3); exit 1 + 10 testi simili
    scripts/telefono.py <serial> aspetta <regex> [S]          # attende che compaia (di serie 10 s); exit 0/1
    scripts/telefono.py <serial> foto <file.png>    # screenshot ridotto a 540 px (se c'è PIL)
    scripts/telefono.py <serial> audio              # c'è audio in uscita? stato PLAYING e package

Regola: prima `testi` e `tocca`; la foto solo per controllare l'aspetto.
Non cambia volume né impostazioni di sistema (a parte `svc power stayon usb`).
Base: la classe Device di perf_device.py (adb, sh, nodes), importata.
"""
import difflib
import os
import re
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from perf_device import Device  # noqa: E402


class Phone(Device):
    # The perf focus guard is tied to the perf package: here no check, taps go where the user's flow is.
    def sh(self, cmd, check=True):
        return self.adb('shell', cmd, check=check)

    def front(self):
        out = self.sh('dumpsys window | grep mCurrentFocus', check=False)
        m = re.search(r'(\S+)/(\S+?)\}', out)
        return f'{m.group(1)}/{m.group(2)}' if m else '?'

    def locked(self):
        out = self.sh('dumpsys window | grep -E "isKeyguardShowing|mDreamingLockscreen"', check=False)
        return bool(re.search(r'(isKeyguardShowing|mDreamingLockscreen)=true', out))

    def unlock(self, pin):
        self.sh('input keyevent KEYCODE_WAKEUP')
        time.sleep(1)
        w, h = map(int, re.search(r'(\d+)x(\d+)', self.sh('wm size')).groups())
        self.sh(f'input swipe {w // 2} {int(h * 0.8)} {w // 2} {int(h * 0.2)} 200')
        time.sleep(1)
        self.sh(f'input text {pin}')
        self.sh('input keyevent KEYCODE_ENTER')
        time.sleep(2)
        return not self.locked()

    def find(self, pattern, wait):
        rx, end = re.compile(pattern), time.time() + wait
        while True:
            nodes = [n for n in self.nodes() if n[0]]
            for n in nodes:
                if rx.search(n[0]):
                    return n, nodes
            if time.time() >= end:
                return None, nodes
            time.sleep(0.5)


def arg_after(args, flag, default):
    return float(args[args.index(flag) + 1]) if flag in args else default


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    d, cmd, args = Phone(sys.argv[1]), sys.argv[2], sys.argv[3:]
    if cmd == 'prepara':
        d.sh('input keyevent KEYCODE_WAKEUP')
        d.sh('svc power stayon usb', check=False)
        time.sleep(2)
        if d.locked():
            pin = os.environ.get('TELEFONO_PIN')
            if not pin:
                print('telefono bloccato: sbloccalo o passa il PIN (TELEFONO_PIN o `sblocca <PIN>`)')
                sys.exit(3)
            if not d.unlock(pin):
                print('sblocco fallito')
                sys.exit(3)
        vol = re.search(r'STREAM_MUSIC:.*?streamVolume:(\d+)|STREAM_MUSIC:.*?(?:Current|speaker\)?): *(\d+)',
                        d.sh('dumpsys audio', check=False), re.S)
        vol = next((g for g in vol.groups() if g), '?') if vol else '?'
        print(f'in primo piano: {d.front()}\nvolume musica: {vol}\nzen_mode: {d.sh("settings get global zen_mode").strip()}')
    elif cmd == 'sblocca':
        pin = args[0] if args else os.environ.get('TELEFONO_PIN')
        if not pin:
            sys.exit('serve il PIN: argomento o $TELEFONO_PIN')
        ok = d.unlock(pin)
        print('sbloccato' if ok else 'ancora bloccato')
        sys.exit(0 if ok else 1)
    elif cmd == 'avvia':
        pkg = args[0]
        out = d.sh(f'cmd package resolve-activity --brief {pkg}').strip().splitlines()
        comp = out[-1].strip() if out else ''
        if '/' not in comp:
            sys.exit(f'attività principale di {pkg} non trovata')
        d.sh(f'am start -n {comp}')
        for _ in range(20):
            if f'{pkg}/' in d.front():
                print(f'in primo piano: {comp}')
                return
            time.sleep(0.5)
        sys.exit(f'{pkg} non è andato in primo piano (ora: {d.front()})')
    elif cmd == 'testi':
        rx = re.compile(args[0]) if args else None
        rows = [f'{l} | {x},{y}' for l, _, x, y in d.nodes() if l and (not rx or rx.search(l))]
        print('\n'.join(rows[:60]) + (f'\n... altri {len(rows) - 60}' if len(rows) > 60 else ''))
    elif cmd == 'tocca':
        n, nodes = d.find(args[0], arg_after(args, '--attesa', 3))
        if not n:
            near = difflib.get_close_matches(args[0], [l for l, *_ in nodes], 10, 0) or [l for l, *_ in nodes][:10]
            print(f'nessun nodo per {args[0]!r}; simili:\n' + '\n'.join(near))
            sys.exit(1)
        d.sh(f'input tap {n[2]} {n[3]}')
        print(f'toccato: {n[0]} | {n[2]},{n[3]}')
    elif cmd == 'aspetta':
        n, _ = d.find(args[0], float(args[1]) if len(args) > 1 else 10)
        print(f'trovato: {n[0]} | {n[2]},{n[3]}' if n else 'non comparso')
        sys.exit(0 if n else 1)
    elif cmd == 'foto':
        png = subprocess.run(['adb', '-s', d.serial, 'exec-out', 'screencap', '-p'], capture_output=True).stdout
        try:
            import io
            from PIL import Image
            im = Image.open(io.BytesIO(png))
            im.resize((540, im.height * 540 // im.width)).save(args[0])
        except ImportError:  # shortcut: no PIL, saved full size
            open(args[0], 'wb').write(png)
        print(f'salvata {args[0]}')
    elif cmd == 'audio':
        s = d.sh('dumpsys media_session', check=False)
        playing = re.findall(r'package=(\S+).*?state=PlaybackState \{state=PLAYING', s, re.S)
        act = d.sh('dumpsys audio | grep -E "state:started|u/.* state:"', check=False)
        print('audio: ' + (f'PLAYING {", ".join(sorted(set(playing)))}' if playing else 'nessuna sessione in PLAYING'))
        print('\n'.join(l.strip() for l in act.splitlines()[:3]))
    else:
        sys.exit(__doc__)


if __name__ == '__main__':
    main()
