# Handoff — 2026-11-08 (fase 99 chiusa: debito di 429, chiave artista, scaffali, paesi)

## Stato
**Fase 99 chiusa** (una PR, `docs/fase-99-debito-artisti.md`): `budgetedYtm` (`lib/services/online/budgeted_call.dart`) per le tre copie di «budget + pausa dopo un 429»; `artistKey` unica in `track_matcher.dart`, formato salvato; `mergeArtistShelves`/`groupShelvesProvider` in `lib/providers/artist_shelves_providers.dart`; `_watchWithCountries` con un timer di 300 ms che non si riavvia e la cache della mappa paese → artisti. Nessun cambio di comportamento, a parte i 300 ms dei paesi.

Prompt di avvio (nuova chat nella cartella del progetto):
```
/obiettivo fase 100
```

## Da sapere per la 100
- **100.1:** `RadioFill` resta sotto `RadioGate` e non sotto `budgetedYtm`: la radio ha la sua politica, e `genre_mix_test` deve restare invariato. Il doc della fase è già corretto.
- **100.3:** budget e caricamento della top già decisi (D-466: senza budget, una richiesta, audio solo del prossimo, «Caricamento…» con i salti veloci). L'helper chiave → grafie va estratto da `countryArtistsOf`.
- **Alias:** le pagine degli alias non spendono budget (D-465). Il blocco giusto sta nel fetch di `_cached`.
- **Formattazione:** solo i file nuovi, a 80 colonne (D-464).
- **Debito nuovo:** «Dalla review di architettura della fase 99» in `prossimi-lavori.md`. `artistKey` va spostata in `lib/core/` all'inizio della 101.
- Prossimi obiettivi: fase 100 (consigliata), poi 101–105 e la 106 in ordine.

---

# Handoff — 2026-11-08 (fase 98 chiusa: rete del refactor «ascolto-quotidiano»)

## Stato
**Fase 98 chiusa** (PR #128, `docs/fase-98-rete-ascolto.md`): `dart format` dei 4 file (D-434); `scripts/perf_device.py` tutto a `gestures()`, «Album» gira da solo, «Anello» tolto; test di caratterizzazione per 429/budget, chiave artista, scaffali uniti, paesi in `watchByRules`, backup (formato di oggi e campi sconosciuti). `lib/` invariata salvo formattazione.

Prompt di avvio (nuova chat nella cartella del progetto):
```
/obiettivo fase 99
```

## Da sapere per la 99
- I test della 98 non si cambiano nella 99 (analisi §Rete). Valori veri fissati, diversi dall'analisi: «Unisci con…» spende **1** unità di budget (non 2); `AC/DC` → chiave `ac` (la «/» separa gli artisti). `artist_key_test.dart` ha un helper `key()` da ripuntare su `artistKey` (una riga).
- `groupShelvesProvider` è importato dal file della schermata: spostandolo in `lib/providers/` cambia solo l'import del test.
- La guardia `gen` di `_watchWithCountries` non ha un test (non pilotabile dall'API pubblica): con il debounce della 99 scrivi lì il test «risposta vecchia dopo una nuova» e «annullato con query in volo».
- Prossimi obiettivi: fase 99 (consigliata, debito sulla strada di 100–104), poi 100–105 in ordine.

---

# Handoff — 2026-11-07 (refactor «ascolto-quotidiano» pianificato: fasi 98–105)

## Stato
**Refactor «ascolto-quotidiano» pianificato** (D-428…D-455): fasi 98–105 in `docs/fase-98…105-*.md`, spunte in `PROGRESS.md`, righe in `00-INDICE.md`. Contiene le funzioni chieste dall'utente il 7/11 (coda di simili da Cerca, Play/Shuffle dell'artista, «non mi piace» brano o artista, podcast senza iscrizione, «Riprendi» con gli episodi, testi a mano e sincronia spegnibile, Memoria, daylist) e il debito §6 «Media» di `prossimi-lavori.md`, lo script delle misure e la formattazione di 4 file.

Prompt di avvio (nuova chat nella cartella del progetto):
```
/obiettivo fase 98
```

## Da sapere
- Analisi, scelte, architettura di arrivo, rete e metriche: `docs/refactor/ascolto-quotidiano/analisi.md` (F-103…F-122).
- Mockup approvati (D-453): `docs/refactor/ascolto-quotidiano/mockup/indice.html` (10 schermate). Sono la specifica visiva.
- Schema DB v19 solo nella fase 102 (`podcasts.followed`, D-435). Nessun pacchetto nuovo (D-442).
- `dart format` solo sui 4 file della 98.1 e sui file toccati: gli altri ~495 file non formattati restano così (D-434).
- Prove sul Mi A3 via adb, poi ripulire (D-455).
- Domande e messaggi all'utente sempre in italiano.
- Fase 106 aggiunta l'8/11 (refactor «testi-traslitterati», D-456…D-462): traslitterazione dei testi asiatici, dopo la 103. Analisi `docs/refactor/testi-traslitterati/analisi.md`, mockup `docs/refactor/testi-traslitterati/mockup/testo-traslitterato.html`.

---

# Handoff — 2026-11-05 (fase 87: rete del refactor superfici-e-ricerca; prima la 86, 85, 84)

## Stato
**Fase 87 chiusa** (PR #113, `docs/fase-87-rete-superfici.md`): test di caratterizzazione (regole, backup v14, ordine manuale, Bayou, schede della shell, risultati fusi, ordinamento, salto A–Z), 17 golden, 4 scenari di fluidità nuovi, base del Mi A3 negli Esiti. `lib/` invariata. Debito trovato: **88.5b** (DB in attesa più nuovo non rifiutato dal ripristino). Base del Motorola rinviata (D-419).

Prompt di avvio (nuova chat nella cartella del progetto):
```
/obiettivo fase 88
```

**Fase 86 chiusa** (una PR, `docs/fase-86-jam-media.md`): `JamMedia` (`lib/providers/jam_media.dart`) fuori da `JamController`, `jam_providers.dart` da 1271 a 1073 righe, 7 test unitari nuovi in `jam_media_test.dart`.

**Fase 85 chiusa** (una PR, `docs/fase-85-debito-review-83.md`): `playContextProvider` segue l'handler (anche Android Auto); tetto delle schede in streaming in `shadowWaitProvider`; ricerca fallita visibile nei selettori; test a tappeto dei pulsanti; `libraryIndexProvider` in `library_providers.dart`; regola «Shuffle+ acceso» unica (`plusOn`).

**Fase 84 chiusa** (una PR). Dettagli ed esiti delle prove: `docs/fase-84-broker-e-debito-jam.md`.
- `kDefaultJamBrokers` = emqx, poi HiveMQ (D-383). Mosquitto era già fuori (D-328).
- Debito della fase 74 fatto: `JamLocalQueue`, `connectWithQuickRetry`, `isPastEnd`, nome dell'ospite uscito per tutta la Jam, test del nome unito.
- Prove a mano fatte dal vivo (5/11, rete di casa): Jam in LAN Motorola host + Mi A3 ospite; riserva fra broker (broker inesistente → HiveMQ); Sospendi 15 min con scadenza, «Fino alla fine della Jam», Blocca/Sblocca (Mi A3 host, Linux ospite col codice); Casuale+ col log; suggerito online in coda; «Proposta di correzione» (Accetta, Scarta, Ripristina dal Registro). Tutte OK.
- Motorola aggiornato all'APK debug di oggi, dati intatti; copia di sicurezza in `.backup-motorola/2026-11-05/` (1,35 GB).


## Da sapere
- Refactor «superfici-e-ricerca» pianificato (D-384…D-418): fasi 87–97; analisi in `docs/refactor/superfici-e-ricerca/analisi.md`, mockup approvati in `docs/refactor/superfici-e-ricerca/mockup/` (`indice.html`). Prossima: `/obiettivo fase 88`.
- Decisioni: fino a D-418. Le prove a due telefoni le fa l'agente via adb; il Motorola fa solo l'host in «Coda dell'host» e va tenuto sveglio (`KEYCODE_WAKEUP`, si sospende dopo 30 min).
- In LAN non c'è un «Entra» da ospite: si preme «Jam» sulla riga dell'altro telefono e **chi accetta diventa host**.
- «Sospendi» e «Blocca» esistono solo nel dialogo della richiesta in arrivo, non per un ospite già dentro.
- Il launcher del Mi A3 oggi è `com.codecore.player/.IconArancioDark` (non più `IconAmbraDark`).

## Da riprovare o capire
- `shadowWaitProvider` tiene le `phases` del preparer che c'era quando è partito: se `streamPreparerProvider` si rifà, un download vivo può dire «Non disponibile» dopo il tetto (già così prima della 85).
- Il `try/catch` di `resumeLastQueue` non ha più un test (il vecchio forzava l'errore con `onContext`, tolto).
- Dal telefono il primo CONNECT a HiveMQ con mezza attesa (~5 s) è fallito 2 volte su 2, poi è entrato al giro dopo; il codice compare 35–40 s dopo «Invita». Valutare un'attesa intera per il primo tentativo su un broker diverso dal primo.
- La lista «Rete e dispositivi» dal vivo è sembrata non aggiornarsi dopo «Sblocca», ma il test widget dice di sì (`ListenableBuilder` sul gate): forse un dump di uiautomator vecchio.
- «Ripristina» di una correzione accettata rimette il titolo ma lascia il brano «modificato a mano» (`userEdited`): niente più proposte per lui. Voluto?
- Sul Mi A3 restano 4 righe `missing=1` (copie di prova cancellate) e 13 righe ombra di streaming: si tolgono da sole con la pulizia della libreria, o a mano.
- Il «+» di Casuale+ si scrive ~400 ms dopo; una Jam della cassa aperta prima del ripristino all'avvio potrebbe salvare la modalità sbagliata (non visto).

## Tocca a te
- **Motorola (D-419, da domani o a fine fasi)**: collegalo via USB; la base si misura con `python3 scripts/perf_device.py ZY22HKD85K --label base --playback` (JAVA_HOME=~/.jdks/jbr-17.0.14) sul codice di master prima della 88, o si accetta una base più tarda.
- **Scelta**: il Registro (e Da confermare) si apre solo dal foglio attività, che compare solo mentre qualcosa gira. Vuoi un ingresso fisso (Impostazioni o ⋮ della Libreria)?
- **A vista sul Mi A3**: la copertina che resta tonda chiudendo il player, la dissolvenza fra le pagine, la lente della Libreria.
- **Mi A3**: l'amico «emanuele-Aspire-A515-45» in «Jam a distanza»; toglilo a mano se non ti serve.
- Quando confermi che il Motorola va bene: si può cancellare `.backup-motorola/2026-11-05/`.
- Dalle fasi 66–69: fase 67 sul Motorola, scoperta su /16, fase 66 a mano, ascolto 57.7, 69.4 «Scarica» che sparisce a foglio aperto, APK di release con NewPipe, tag `v1.3.0`.

## Dispositivi
- **Motorola edge 40** `ZY22HKD85K`: libreria vera. Solo `install -r`; mai disinstallare né `pm clear`. 120 Hz.
- **Mi A3** `0d7ae9df206e`: si disinstalla solo con `-k`; mai cancellare i file musicali; l'app vera è `com.codecore.player` (69 brani), le misure sull'app `.perf`; volume della musica a 0; PIN nelle memorie.
- **JBL**: si spengono da sole dopo circa 20 minuti senza suono.
- Su entrambi i telefoni: mai toccare la rotazione o le impostazioni di sistema.
- **Misure**: `python3 scripts/perf_device.py <id> --label <l> [--no-build --no-push --apk <apk>] [--only "A,B"]`.
- **APK**: si compila con `JAVA_HOME=~/.jdks/jbr-17.0.14` (`docs/gotchas.md`).

## Rinviato
- **Due code per le domande sulla cassa** (`SpeakerMonitor._pending` e la coda della UI): da unificare.
- 53.10 completamento intero sul Motorola (circa 1 brano al minuto).
- Il messaggio «perché niente Shuffle+» (D-87) su un album da 1 brano; gli interruttori del completamento che fermano il giro manuale.
- Il debito dello streaming, in fondo a `docs/fase-47-jam-online.md`.

## Prossimi obiettivi
1. **(Consigliato)** Fase 88 e seguenti: il refactor «superfici-e-ricerca» (fasi 87–97, piano già scritto).
2. Unificare le due code delle domande sulla cassa (`SpeakerMonitor._pending` e la coda della UI).
3. Ricerca «notte», build p99 (D-176); picco di ~54 ms alla prima visita di ogni scheda della Libreria (F-60).
