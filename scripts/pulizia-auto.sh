#!/usr/bin/env bash
# Pulizia di fine passo: sopra la soglia di disco usato (di serie 85 %) toglie le cache di build che si rifanno da sole.
# Passa da pulizia.sh (rifiuta file tracciati e percorsi fuori dal progetto). Mai build/metadata_god (Rust, lungo da rifare).
# Uso: scripts/pulizia-auto.sh [soglia %]
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
soglia=${1:-85}
uso=$(df --output=pcent . | tail -1 | tr -dc 0-9)
if [ "$uso" -lt "$soglia" ]; then
  echo "disco al $uso % (soglia $soglia %): niente da pulire"
  exit 0
fi
paths=()
for p in build/test_cache build/app/intermediates build/bench build/perf_library .dart_tool/flutter_build; do
  [ -e "$p" ] && paths+=("$p")
done
[ ${#paths[@]} -gt 0 ] || {
  echo "disco al $uso %: le cache sono già vuote; serve una pulizia a mano (pulizia.sh misura)"
  exit 0
}
~/.claude/skills/obiettivo/scripts/pulizia.sh via "${paths[@]}"
