#!/usr/bin/env bash
# Guardia PreToolUse: nega ciò che è distruttivo o fuori dal progetto. Exit 2 + messaggio su stderr = negato.
# Un errore dello script non nega nulla (exit 0).
set -uo pipefail

input=$(cat)
tool=$(jq -r '.tool_name // empty' <<<"$input" 2>/dev/null) || exit 0
proj=${CLAUDE_PROJECT_DIR:-$PWD}
proj=$(cd "$proj" 2>/dev/null && pwd -P) || exit 0

deny() {
  echo "Guardia: $1" >&2
  exit 2
}

# percorso consentito per le scritture: dentro il progetto o nello scratchpad /tmp/claude-*
inside() {
  local p=$1
  case $p in /*) ;; *) p=$PWD/$p ;; esac
  p=$(realpath -m -- "$p" 2>/dev/null) || return 1
  case $p in
  "$proj" | "$proj"/*) return 0 ;;
  /tmp/claude-*) return 0 ;;
  "$HOME/.claude/projects/$(sed 's|[/.]|-|g' <<<"$proj")/memory"/*) return 0 ;; # memoria di Claude Code per questo progetto
  esac
  return 1
}

case $tool in
Edit | Write | MultiEdit | NotebookEdit)
  f=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input")
  [ -n "$f" ] || exit 0
  inside "$f" || deny "scrittura fuori dal progetto negata ($f). Lavora solo dentro $proj."
  case $(basename "$f") in .env | key.properties | *.jks | *.keystore) deny "file di segreti: non toccarlo." ;; esac
  ;;
Bash)
  c=$(jq -r '.tool_input.command // empty' <<<"$input")
  [ -n "$c" ] || exit 0
  grep -Eq '(^|[;&|[:space:]])sudo([[:space:]]|$)' <<<"$c" && deny "sudo: mettilo in «Tocca a te» per l'utente."
  if grep -Eq 'git[[:space:]]+push' <<<"$c"; then
      grep -Eq '(--force|--force-with-lease|--force-if-includes|[[:space:]]-[a-zA-Z]*f([[:space:]]|$)|--delete|[[:space:]]-d([[:space:]]|$)|--mirror|--prune|[[:space:]]\+[^[:space:]]+|[[:space:]]:[^[:space:]]+)' <<<"$c" && deny "git push forzato, che cancella o in mirror: negato."
  fi
  grep -Eq 'git[[:space:]]+(reset[[:space:]]+--hard|clean|checkout[[:space:]]+(--[[:space:]]+)?\.)' <<<"$c" && deny "comando git distruttivo: usa un'alternativa non distruttiva."
  grep -Eq '(^|[;&|[:space:]])git[[:space:]]+stash' <<<"$c" && deny "git stash nell'albero condiviso porta via il lavoro degli altri agenti: committa i tuoi file con git commit -- <file>, o usa un worktree."
  # dart format solo su file .dart elencati (D-434): una cartella riformatterebbe centinaia di file non tuoi
  if grep -Eq '(^|[;&|[:space:]])dart[[:space:]]+format' <<<"$c"; then
    args=$(grep -Eo 'dart[[:space:]]+format[^;&|]*' <<<"$c" | head -1 | sed -E 's/^dart[[:space:]]+format//')
    args=$(tr -d "\"'" <<<"$args")
    case $args in *'$('* | *'`'*) args="" ;; esac # file da una sostituzione (git diff --name-only): non verificabili qui
    for tok in $args; do
      case $tok in -* | *.dart | [0-9]*) ;; *) deny "dart format solo su file .dart elencati, mai su cartelle ($tok, D-434)." ;; esac
    done
    [ -z "$args" ] || grep -Eq '\.dart([[:space:]]|$)' <<<"$args" || deny "dart format senza file .dart elencati: indica i file che hai toccato (D-434)."
  fi
  grep -Eq '(curl|wget)[^|]*\|[[:space:]]*(ba)?sh' <<<"$c" && deny "esecuzione di script scaricati negata."
  grep -Eq '(^|[[:space:]])(mkfs|dd[[:space:]]+if=|shutdown|reboot)' <<<"$c" && deny "comando di sistema negato."
  # rm ricorsivo: ogni argomento deve stare dentro il progetto o nello scratchpad
  if grep -Eq '(^|[;&|[:space:]])rm[[:space:]]+(-[a-zA-Z]*[rR]|--recursive)' <<<"$c"; then
    for tok in $c; do
      case $tok in -* | rm | "&&" | ";" | "|") continue ;; esac
      case $tok in *'$'* | '~'* | '*') deny "rm -r con percorso non verificabile ($tok)." ;; esac
      case $tok in /* | ./* | ../* | [a-zA-Z0-9_.]*) inside "$tok" || deny "rm -r fuori dal progetto negato ($tok)." ;; esac
    done
  fi
  ;;
esac
exit 0
