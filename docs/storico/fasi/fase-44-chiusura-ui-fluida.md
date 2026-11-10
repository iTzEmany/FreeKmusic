# Fase 44 — Chiusura (refactor «ui-fluida»)

**Obiettivo:** dimostrare con numeri che il refactor ha raggiunto i traguardi (fluidità, accessibilità, struttura),
registrare i risultati e ripulire.

**Prerequisiti:** fasi 38–43 chiuse. Misure di partenza in `build/perf/ui-fluida-prima.md` e
`docs/refactor/ui-fluida/misure.md`.

**Intoccabili (D-07):** schema del DB, chiavi delle impostazioni, file di tema e di backup; nessun pacchetto nuovo; protocolli LAN, Jam e sync compatibili. Dettagli e dispositivi: vedi `fase-38-rete-ui-fluida.md`.

**Comportamento invariato:** questa fase non cambia codice di prodotto. Se una misura fallisce, non si "aggiusta" qui: si
apre un passo nella fase che ne è responsabile (o si chiede all'utente di accettare la soglia, con una riga in `docs/decisioni.md`).

## Task

### 44.1 — Misure finali sul Mi A3
Comando (D-19, solo app perf, build profile, JAVA_HOME=/home/emanuele/.jdks/jbr-17.0.14, via `sorveglia.sh --pesante`):
`python3 scripts/perf_device.py 0d7ae9df206e --label ui-fluida-dopo --playback`. Il Motorola non si tocca.

**Fatto quando:** esiste `build/perf/ui-fluida-dopo.md`; la tabella in `misure.md` (prima · dopo 39 · dopo · soglia · ok/no) copre **ogni riga** della tabella soglie della fase 38: Pallino schede ≤ 2 %, Tutti i brani ≤ 1 %, Album ≤ 0,6 %, Ricerca ≤ 3 % e p99 ≤ 16 ms, Apri album ≤ 3 %, Fogli ≤ 3 %, Swipe mini player ≤ 2 %, Apertura player ≤ 3 % e p99 ≤ 33 ms, avvio a freddo ≤ 2400 ms, PSS ≤ 210 MB.

### 44.2 — Metriche di struttura
`python3 scripts/build_len.py lib/ui` e i grep della fase 38.

**Fatto quando:** `databaseProvider|RepositoryProvider` = 0 · `SnackBar(` = 1 · `AppBar(` = 1 · `Duration(milliseconds` ≤ 3 (solo nei token) · `build` ≤ 120 righe, 0 oltre 150; `flutter test test/ui/architecture_test.dart` verde con lista di eccezioni vuota.

### 44.3 — Verifiche finali
**Fatto quando:** `flutter analyze` pulito; `flutter test integration_test -d linux` verde (via `sorveglia.sh`); la CI della PR finale verde (suite completa, solo in CI); prova a mano su Mi A3 e Motorola (solo lettura sul Motorola) dei quattro momenti segnalati dall'utente: apertura del player, scorrimento delle liste, fogli e finestre, cambio di pagina o di scheda.

### 44.4 — Aggiornare `analisi.md`
Nuova sezione «Risultati» in `docs/refactor/ui-fluida/analisi.md`: per ogni F-NN, stato (fatto, con commit; nessuna azione per F-37/38/39); tabella prima/dopo; i cambi di comportamento avvenuti (D-04, D-11, D-12, D-13, D-14, D-15, D-16, D-17); eventuali soglie non raggiunte e perché.

**Fatto quando:** la sezione «Risultati» esiste (`grep -n "^## Risultati" docs/refactor/ui-fluida/analisi.md`) e ogni F-NN delle fasi 39–42 vi compare con un commit; `docs/PROGRESS.md` ha tutte le caselle 38–44 spuntate.

### 44.5 — Pulizia del disco
Cancellare l'APK profile, che non serve più: `~/.claude/skills/obiettivo/scripts/pulizia.sh via build/app/outputs/flutter-apk/app-profile.apk`. Solo con lo script di pulizia, non con cancellazioni a mano.

**Fatto quando:** `ls build/app/outputs/flutter-apk/app-profile.apk` risponde «No such file»; `build/perf/*.md` (le misure) restano.

### 44.6 — Nuova versione e tag (richiesta dell'utente, D-35)
Solo dopo 44.1–44.5 e con la CI verde su `master`:
1. Portare `pubspec.yaml` da `1.2.0+3` a `1.3.0+4`, a meno che l'utente non scelga un altro numero.
2. Aggiungere una voce al changelog o alle note di rilascio, se il progetto ne ha uno: fluidità, accessibilità, nuovo aspetto e i cambi di comportamento elencati in 44.4.
3. Creare il tag annotato `v1.3.0` sul commit di chiusura.
4. **Chiedere un sì all'utente prima di fare il push del tag.** Il push avvia `release.yml`, che costruisce gli APK, Linux e Windows e pubblica la release su GitHub.

**Fatto quando:** `git tag -l v1.3.0` lo mostra; dopo il sì, `gh run list -w release.yml -L 1` è verde e la release esiste (`gh release view v1.3.0`).

## Dalla fase 43
- **Pallino schede al 12 %** (era 3,9 % dopo la 39): la bisezione in `misure.md` lo colloca fra la fase 40 e la 42,
  non nella 43. In 44.1, prima delle misure finali, bisecare i commit 40–42 con
  `--only "Pallino schede"` e aprire il passo di correzione nella fase responsabile.
- **CoverBackdrop** (D-54): «Testi» e «Auto» usano ancora la sfumatura della copertina; il player è piatto.
  Decidere in 44.4 se allinearli o annotarlo come cambio rimandato.
- Soglie non raggiunte dopo la 43: tabella «Dopo la fase 43» in `misure.md`.
