#!/usr/bin/env bash
# Test di convenzione veloci che la CI rifiuta e che in locale si dimenticano (arb, separatori, architettura, colori),
# più i golden quando il ramo tocca lib/ui. Gira da solo come hook pre-push (.githooks/pre-push).
# Uso: scripts/guardie.sh [base]   (base di serie: origin/master)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
base=${1:-origin/master}
tests=(test/l10n/arb_test.dart test/ui/no_separator_literals_test.dart test/ui/architecture_test.dart test/ui/no_stray_colors_test.dart)
if git diff --name-only "$base"...HEAD -- lib/ui | grep -q .; then
  tests+=(test/goldens/)
fi
python3 scripts/check_perf_labels.py
log=build/guardie.log
sorveglia=~/.claude/skills/obiettivo/scripts/sorveglia.sh
if [ -x "$sorveglia" ]; then
  "$sorveglia" --pesante 5m "$log" -- flutter test "${tests[@]}" || {
    echo "guardie rosse: dettagli in $log" >&2
    exit 1
  }
else
  flutter test "${tests[@]}"
fi
