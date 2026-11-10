# Fase 102 — Podcast senza iscrizione e «Riprendi» con gli episodi

**Obiettivo:** aprire e ascoltare un podcast senza seguirlo, con ripresa dal punto lasciato, ed episodi in «Riprendi» in Home. **Cambi di comportamento voluti** (D-431, D-435, D-449, D-450). Schema DB v19.

**Prerequisiti:** fase 101 chiusa. Analisi F-106, F-107 e «Arrivo». Mockup approvati: `refactor/ascolto-quotidiano/mockup/podcast-anteprima.html`, `refactor/ascolto-quotidiano/mockup/riprendi.html`. Aree a rischio: **migrazione v19, query su `tracks`, audio handler** (review Opus del diff; suite completa in locale una volta prima della PR).

**Comando mirato:** `dart run build_runner build --delete-conflicting-outputs` poi `flutter test test/data/migration_test.dart test/data/track_repository_test.dart test/data/stream_rows_hidden_test.dart test/services/online/ytm_podcasts_test.dart test/providers/podcast_cooldown_test.dart test/services/podcast/`

## Task

### 102.1 — Schema v19: `podcasts.followed` (D-435)
- Colonna booleana, di serie vero (i podcast esistenti restano seguiti), migrazione in un solo passo e ripetibile. La lista Podcast, gli aggiornamenti dei feed e i conteggi mostrano solo i seguiti. Backup e ripristino portano la colonna (un backup v18 si ripristina con tutti seguiti).
- Test in `test/data/migration_test.dart` (stile delle righe 774 e 796): v18 → v19 con podcast ed episodi intatti e `followed = true`; passo ripetuto senza errori.

### 102.2 — Anteprima senza iscrizione (F-106, D-431, D-450)
- `PodcastService.peek` / `YtmPodcastSync.peek` pubblici (oggi `_read`): feed in memoria in un `FutureProvider.family`. Dalla lista di Scopri, YouTube Music e risultati (`podcasts_screen.dart:108`) ogni riga si apre: se seguito come oggi, altrimenti l'anteprima del mockup.
- Al primo play di un episodio il podcast si salva con `followed = false` (con l'episodio come riga, come per i seguiti), così la ripresa funziona anche senza iscrizione. «Segui» → `followed = true` e il pulsante diventa «Segui già»; ritoccato torna non seguito (gli episodi già ascoltati restano). Nessun download nell'anteprima.
- Le scritture dei podcast passano da un Ops (chiude anche il debito «scritture dei podcast dalla UI senza Ops» di `prossimi-lavori.md` §6 per le schermate toccate).
- Test `test/services/podcast/podcast_preview_test.dart`: salvato non seguito al primo play; «Segui già» ritoccato → non seguito; un non seguito non compare nella lista Podcast.

### 102.3 — «Riprendi» con gli episodi (F-107, D-449)
- `watchResumable` (`track_repository.dart:700-710`): `kind` 0 e 1, i 3 più recenti. La riga dell'episodio mostra il podcast e «riprendi da mm:ss · mancano N min» (ARB); il tocco riparte dal punto salvato (`resumeStartFor`) anche dopo aver ascoltato musica.
- `track_repository_test.dart:113` cambia apposta (entrano gli episodi); caso nuovo con un episodio di un podcast non seguito.

### 102.4 — Controlli di fase
`build_runner`; `flutter analyze`; comando mirato; **suite completa in locale una volta** (`sorveglia.sh --pesante`); metrica `kSchemaVersion` = 19; review Opus del diff; scheggia passo e fase; prova sul Mi A3 con aggiornamento sopra i dati esistenti (podcast seguiti intatti), anteprima, ascolto a metà, musica, ripresa da «Riprendi». Ripulire il telefono (senza toccare i file musicali).

**Fatto quando:** migrazione provata sopra dati veri, anteprima e ripresa funzionano senza iscrizione, «Riprendi» mostra l'episodio.

## Scelte dell'utente (8/11, dopo la fase 99)
- **D-470** (102.2): smettendo di seguire un podcast con episodi scaricati, un avviso chiede se tenerli o cancellarli; senza download nessuna domanda; nessuna pulizia automatica dei non seguiti.

## Esiti
- 102.1 (2026-11-09): `podcasts.followed` (schema v19, `addColumn` ripetibile con `PRAGMA table_info`); lista, aggiornamenti dei feed e pulizia automatica solo dei seguiti; il backup porta la colonna perché copia il DB (un backup v18 migra con tutti seguiti). Provato sul Mi A3 con aggiornamento sopra i dati: podcast seguito e 134 episodi intatti.
- 102.2: `peek` pubblici e `podcastPreviewProvider`; `PodcastPreviewScreen` da Scopri/YouTube Music/risultati; primo play → podcast salvato non seguito; «Segui»/«Segui già»; «Smetti di seguire» (anche dal dettaglio) con l'avviso di D-470 solo con download, «Elimina podcast» separato; scritture via `PodcastOps`. Aggiunto in corso d'opera lo **streaming degli episodi** (D-431 lo chiedeva, prima suonavano solo gli scaricati): riga `kind = 1` con percorso remoto, ripresa e «Riprendi» anche senza iscrizione né download; download e cancellazione riscrivono la stessa riga.
- 102.3: `watchResumable` con `kind` 0 e 1 (3 più recenti), senza gli episodi segnati come ascoltati; riga dell'episodio con podcast, «riprendi da» e «mancano».
- Review: Opus su schema/Riprendi (1 bug: episodio ascoltato restava in «Riprendi») e su handler/podcast (9 rilievi: collisione con le righe ombra kind 2, URL condivisi, rete che cade, URL cambiato, corse download/play, Jam, menu); scheggia di passo: 4 bug e test rinforzati. Tutto corretto con i test.
- 102.4: `flutter analyze` pulito; suite completa in locale: 5292 verdi, 2 test di `seek_characterization` instabili sotto carico (verdi da soli, non toccati dalla fase). Review di architettura Opus: corretti `isHttpAddress` unico, cicli di import, callback senza gestione degli errori, nome di un test; 4 voci di debito in `prossimi-lavori.md`. Prova sul Mi A3: tutti i flussi; corretti dopo la prova il segnalibro azzerato dopo una rete persa, «ascoltato» sull'episodio in corso, la riga di «Riprendi» (minuscola e TalkBack) e lo stato salvato nell'anteprima. Non provato sul telefono lo streaming di un episodio YouTube Music.

