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

## Esiti
