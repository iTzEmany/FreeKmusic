#!/usr/bin/env python3
"""Checks the relative links of the living docs (docs/guida, docs/architettura,
docs/fasi, docs/00-INDICE.md, docs/storico/README.md; not the whole archive)
and the size of the guide images (< 300 KB). Exit 1 on any problem."""
import os
import re
import sys

docs = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', 'docs'))
files = []
for folder in ('guida', 'architettura', 'fasi'):
    d = os.path.join(docs, folder)
    if os.path.isdir(d):
        files += [os.path.join(d, n) for n in sorted(os.listdir(d)) if n.endswith('.md')]
files += [os.path.join(docs, '00-INDICE.md'), os.path.join(docs, 'storico', 'README.md')]

bad = []
for path in files:
    text = open(path, encoding='utf-8').read()
    text = re.sub(r'```.*?```', '', text, flags=re.S)  # links inside code blocks are examples
    for target in re.findall(r'\]\(([^)#\s]+)(?:#[^)]*)?\)', text):
        if re.match(r'[a-z]+:', target):
            continue
        if not os.path.exists(os.path.normpath(os.path.join(os.path.dirname(path), target))):
            bad.append(f'{os.path.relpath(path, docs)}: link {target} non esiste')
img = os.path.join(docs, 'guida', 'img')
if os.path.isdir(img):
    for name in os.listdir(img):
        if os.path.getsize(os.path.join(img, name)) > 300 * 1024:
            bad.append(f'guida/img/{name}: più di 300 KB')
print('\n'.join(bad) or 'ok')
sys.exit(1 if bad else 0)
