#!/usr/bin/env bash
# Scatti delle schermate (golden fuori da `flutter test`): scripts/shots.sh [filtro sul nome]
# I PNG finiscono in test_shots/goldens/ (ignorata da git); aprili e confrontali con i token di docs/storico/fasi/fase-11-interfaccia-nuova.md.
set -uo pipefail
cd "$(dirname "$0")/.."
args=(test test_shots --update-goldens)
[ $# -ge 1 ] && args+=(--plain-name "$1")
flutter "${args[@]}" 2>&1 | tail -25
ls -1 test_shots/goldens/*.png 2>/dev/null
