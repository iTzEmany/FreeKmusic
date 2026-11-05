# Handoff — 2026-11-05 (fase 85: debito della review della 83; prima la 84)

## Stato
**Fase 85 chiusa** (una PR, `docs/fase-85-debito-review-83.md`): `playContextProvider` segue l'handler (anche Android Auto); tetto delle schede in streaming in `shadowWaitProvider`; ricerca fallita visibile nei selettori; test a tappeto dei pulsanti; `libraryIndexProvider` in `library_providers.dart`; regola «Shuffle+ acceso» unica (`plusOn`).

**Fase 84 chiusa** (una PR). Dettagli ed esiti delle prove: `docs/fase-84-broker-e-debito-jam.md`.
- `kDefaultJamBrokers` = emqx, poi HiveMQ (D-383). Mosquitto era già fuori (D-328).
- Debito della fase 74 fatto: `JamLocalQueue`, `connectWithQuickRetry`, `isPastEnd`, nome dell'ospite uscito per tutta la Jam, test del nome unito.
- Prove a mano fatte dal vivo (5/11, rete di casa): Jam in LAN Motorola host + Mi A3 ospite; riserva fra broker (broker inesistente → HiveMQ); Sospendi 15 min con scadenza, «Fino alla fine della Jam», Blocca/Sblocca (Mi A3 host, Linux ospite col codice); Casuale+ col log; suggerito online in coda; «Proposta di correzione» (Accetta, Scarta, Ripristina dal Registro). Tutte OK.
- Motorola aggiornato all'APK debug di oggi, dati intatti; copia di sicurezza in `.backup-motorola/2026-11-05/` (1,35 GB).

Prompt di avvio (nuova chat nella cartella del progetto):
```
/obiettivo
```

## Da sapere
- Decisioni: fino a D-383 (la 85 non ne aggiunge). Le prove a due telefoni le fa l'agente via adb; il Motorola fa solo l'host in «Coda dell'host» e va tenuto sveglio (`KEYCODE_WAKEUP`, si sospende dopo 30 min).
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
1. **(Consigliato)** `JamMedia` fuori da `jam_providers.dart` (~190 righe di risoluzione dei file: `_remoteUri`, `_resolve`, `_localMeta`, `fetchCover`, `_precache`…), con un getter per dipendenza come `JamPart`.
2. Unificare le due code delle domande sulla cassa.
3. Ricerca «notte», build p99 (D-176); picco di ~54 ms alla prima visita di ogni scheda della Libreria (F-60).
