#!/usr/bin/env python3
"""Controlla che le etichette cercate da scripts/perf_device.py esistano ancora nell'app.

Lo script di misura pilota il telefono (in italiano) cercando i nodi per testo; se una
scritta della UI cambia, la misura si rompe e lo si scopre solo misurando. Qui ogni
stringa/regex cercata sullo schermo deve corrispondere (re.search) ad almeno un valore di
lib/l10n/app_it.arb (segnaposto {x} e rami plural/select risolti), salvo le eccezioni sotto.

    scripts/check_perf_labels.py [percorso/app_it.arb]
Uscita 0 se tutto torna, 1 con l'elenco delle etichette orfane.
"""
import ast
import itertools
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, 'scripts/perf_device.py')

# Non vengono dall'ARB: pattern cercati (come scritti nello script) -> da dove vengono.
EXCEPTIONS = {
    # Titoli della libreria di prova (scripts/perf_library.py: «<Parole> <n>», es. «Notte 12»).
    r'^[A-Z].* \d+': 'titolo di un brano di scripts/perf_library.py',
    # Album della libreria di prova (scripts/perf_library.py: «Album 000 notte»).
    r'^Album \d+': 'album di scripts/perf_library.py',
}

CALLS = {'find', 'tap', 'target', 'tab', 'find_docks', 'tabs'}  # funzioni che cercano un nodo per testo


def strings(node):
    return [n.value for n in ast.walk(node) if isinstance(n, ast.Constant) and isinstance(n.value, str)]


def extract(tree):
    """Pattern cercati sullo schermo, f-string risolte con le costanti passate a tab/find_docks/tabs e ai for."""
    names = set()  # etichette passate a tab/find_docks/tabs (dock)
    loops = {}  # variabile del for -> costanti dell'iterabile
    for n in ast.walk(tree):
        if isinstance(n, ast.Call) and getattr(n.func, 'id', None) in ('tab', 'find_docks', 'tabs'):
            names.update(s for a in n.args for s in strings(a))
        if isinstance(n, ast.For) and isinstance(n.target, ast.Name):
            loops.setdefault(n.target.id, set()).update(strings(n.iter))
    pats = []

    def resolve(js):
        parts = []
        for v in js.values:
            if isinstance(v, ast.Constant):
                parts.append([v.value])
            elif isinstance(v, ast.FormattedValue) and isinstance(v.value, ast.Name):
                parts.append(sorted(loops.get(v.value.id) or names))
            else:
                parts.append(['.*'])
        return [''.join(p) for p in itertools.product(*parts)]

    def add(a):
        if isinstance(a, ast.Constant) and isinstance(a.value, str):
            pats.append(a.value)
        elif isinstance(a, ast.JoinedStr):
            pats.extend(resolve(a))

    for n in ast.walk(tree):
        if isinstance(n, ast.Call):
            f = n.func
            name = f.id if isinstance(f, ast.Name) else f.attr if isinstance(f, ast.Attribute) else None
            if name in ('find_docks', 'tab', 'tabs'):  # nomi nudi: etichette esatte
                pats.extend(f'^{x}$' for a in n.args for x in strings(a))
            elif name in CALLS and n.args:
                add(n.args[0])
            # re.match(pattern, l) su un nodo (non sull'output di adb)
            if name == 'match' and isinstance(f, ast.Attribute) and getattr(f.value, 'id', '') == 're' \
                    and len(n.args) > 1 and isinstance(n.args[1], ast.Name) and n.args[1].id == 'l':
                add(n.args[0])
        # Confronti esatti con l'etichetta di un nodo: l == 'Dispositivi'.
        if isinstance(n, ast.Compare) and isinstance(n.left, ast.Name) and n.left.id == 'l':
            for c in n.comparators:
                if isinstance(c, ast.Constant) and isinstance(c.value, str):
                    pats.append(f'^{c.value}$')
    # tabs(*('Cerca', ...)*3) e le tuple di sheets(): coppie (pattern, ..., shown) sono già prese da find/target.
    for n in ast.walk(tree):
        if isinstance(n, ast.Tuple) and n.elts and isinstance(n.elts[0], ast.Constant) \
                and isinstance(n.elts[0].value, str) and n.elts[0].value.startswith('^'):
            pats.extend(e.value for e in n.elts if isinstance(e, ast.Constant) and isinstance(e.value, str)
                        and e.value.startswith('^'))
    return sorted({p for p in pats if p})


def expand(s):
    """Un valore ARB -> testi possibili: segnaposto {x} -> «0», rami plural/select uno alla volta."""
    i = s.find('{')
    if i < 0:
        return [s]
    depth, j = 0, i
    while j < len(s):
        depth += s[j] == '{'
        depth -= s[j] == '}'
        if depth == 0:
            break
        j += 1
    inner, head, tail = s[i + 1:j], s[:i], s[j + 1:]
    m = re.match(r'\s*\w+\s*,\s*(plural|select)\s*,(.*)', inner, re.S)
    if m:
        branches = re.findall(r'\w+\s*\{((?:[^{}]|\{[^{}]*\})*)\}', m.group(2))
        mids = [x.replace('#', '0') for b in branches for x in expand(b)]
    else:
        mids = ['0']
    return [h + m_ + t for m_ in mids for h in [head] for t in expand(tail)]


def main():
    arb = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'lib/l10n/app_it.arb')
    with open(arb, encoding='utf-8') as f:
        values = [v for k, v in json.load(f).items() if not k.startswith('@') and isinstance(v, str)]
    texts = [t for v in values for t in expand(v)]
    with open(SCRIPT, encoding='utf-8') as f:
        labels = extract(ast.parse(f.read()))
    orphans = []
    for p in labels:
        if p in EXCEPTIONS:
            continue
        rx = re.compile(p)
        if not any(rx.search(t) for t in texts):
            orphans.append(p)
    print(f'{len(labels)} etichette in perf_device.py, {len(EXCEPTIONS)} eccezioni, {len(orphans)} orfane')
    for p in orphans:
        print(f'  orfana: {p!r}')
    if orphans:
        print(f'Nessun testo di {os.path.relpath(arb, ROOT) if arb.startswith(ROOT) else arb} le corrisponde: '
              'aggiorna scripts/perf_device.py (o EXCEPTIONS se viene dalla libreria di prova).')
    return 1 if orphans else 0


if __name__ == '__main__':
    sys.exit(main())
