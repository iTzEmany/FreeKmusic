# Fase 117 — Ripristino completo

## Obiettivo
«Unisci» porta su un altro dispositivo tutto ciò che sta nel backup: impostazioni, temi con l'immagine, storico degli ascolti, copertine automatiche, tag, playlist smart e podcast. Rifarlo non duplica niente. Download, ritocchi e rilascio sono nella [fase 118](fase-118-download-ritocchi-e-1-6-0.md).

## Riferimenti
- Decisioni D-545, D-546, D-552, D-554 (lettura del sqlite del backup), D-556 (divisione in due fasi). Richieste e diagnosi: `.claude/obiettivi/2026-11-11-richieste-utente.md`.
- Area: [`sync-backup-jam.md`](../architettura/sync-backup-jam.md) (Backup).
- Caso reale: un backup di Codecore (musica in `Android/data`) ripristinato su FreeKmusic (musica in `Music/FreeKmusic`), quindi percorsi diversi e solo «Unisci».

## Requisiti
| ID | Requisito | Pri | Criterio di accettazione |
|---|---|---|---|
| R-211 | «Unisci» applica `settings.json` del backup: vince il backup, tranne `kDeviceBoundKeys`; i temi personalizzati (`customThemes`) si uniscono per id, e a parità di id vince il backup (D-545) | I | test: un'impostazione cambiata nel backup arriva, `deviceId`/`deviceName`/`trustedDevices` restano quelli locali, un tema solo locale resta e un tema solo del backup arriva |
| R-212 | Il backup contiene l'immagine di sfondo dei temi personalizzati; il ripristino (completo e «Unisci») la rimette in `themeDir()` e riscrive `imagePath` col percorso del dispositivo | I | test: zip con `theme/<file>`; dopo l'unione il tema punta a un file esistente nel `themeDir()` locale |
| R-213 | Lo storico degli ascolti (`plays`) del backup arriva sui brani riconosciuti con `TrackResolver`; quelli non riconosciuti si saltano e si contano (D-546) | I | test: gli ascolti di un brano riconosciuto arrivano con `playedAt`, `msPlayed`, `context`, `contextName`; il resoconto riporta «N ascolti non collegati» |
| R-214 | Le copertine automatiche si collegano come quelle a mano: un brano locale senza copertina prende la `coverKey` del brano del backup, se il file esiste (anche `.webp`) | I | test: un brano con `coverSource` 0 nel backup e la copertina in `covers/` ce l'ha dopo l'unione; una copertina locale già presente non cambia |
| R-215 | Tag (`user_tags`, `track_tags`), playlist smart (`smart_playlists`) e podcast (`podcasts`, `podcast_episodes`) arrivano dall'unione | I | test: dopo l'unione esistono con gli stessi nomi, regole e iscrizioni; i tag sono sui brani riconosciuti |
| R-216 | «Unisci» due volte di fila non duplica niente: playlist (anche quelle rinominate «(ripristinata N)»), ascolti, tag, playlist smart, podcast, episodi, temi, radio, artisti | I | test: dopo la seconda unione il conteggio di ogni tabella toccata è uguale a quello dopo la prima |

## Architettura
- **Unione (R-211..R-216)**, in `restore_service.dart` (`mergeBackup`) e `backup_merge.dart` (`mergeUserData`):
  - `settings.json` si legge dallo zip e passa da `applySettingsJson` (già filtra `kDeviceBoundKeys`). Prima di applicarlo, `customThemes` si fonde per id con i temi locali. Le impostazioni si applicano dopo la transazione del DB: se il DB fallisce, le impostazioni non cambiano.
  - Le tabelle che non stanno in `user_data.json` (plays, tag, playlist smart, podcast) si leggono dal `codecore.sqlite` del backup, estratto in una cartella temporanea e aperto in **sola lettura** (pacchetto `sqlite3`, già dipendenza di drift). Il codice deve sopportare uno schema più vecchio: legge solo le colonne che esistono (`PRAGMA table_info`). Per tradurre gli id dei brani del backup in id locali si costruisce un `TrackRef` dalla riga `tracks` del backup, come fa `backup_queries.dart:215-219`, e si passa al `TrackResolver`.
  - Senza doppioni: ascolti per `(trackId, playedAt)`; tag per nome (già UNIQUE NOCASE); `track_tags` per coppia; playlist smart per nome e regole; podcast per `feedUrl` (UNIQUE); episodi per `(podcastId, guid)`. Playlist rinominata: si salva l'uuid del backup in una mappa persistente (o nella riga) per riconoscerla alla volta dopo; la scelta tocca all'implementer, purché passi R-216 senza toccare lo schema.
  - Copertine: `mergeUserData` collega anche `coverSource` 0. `TrackUserData` deve allora portare `coverKey` anche senza copertina a mano: nei backup vecchi manca, e lì il ripiego è la `cover_key` della riga del backup nel sqlite. `_coverFileExists` guarda anche `.webp`.
  - Immagine del tema: `createBackup` aggiunge `theme/*` allo zip. Il ripristino la copia in `themeDir()` e riscrive `imagePath` = `themeDir()/<basename>`.

## Rischi
| Rischio | Mitigazione | Segnale d'allarme |
|---|---|---|
| L'unione delle impostazioni sovrascrive qualcosa di legato al dispositivo che non sta in `kDeviceBoundKeys` (per esempio `jamBrokers`, cartelle, `downloadFolder`) | rileggere tutte le chiavi di `settings_store.dart` e allargare `kDeviceBoundKeys` dove serve, con un test | dopo l'unione la Jam o la scansione puntano a percorsi dell'altro dispositivo |
| Il sqlite di un backup vecchio ha uno schema diverso | lettura per colonne esistenti, test con un DB di schema v15 | eccezione SQL durante «Unisci» |
| Ascolti doppi se due ascolti diversi hanno lo stesso `playedAt` | chiave `(trackId, playedAt)`: due ascolti nello stesso millisecondo sono lo stesso | — |

## Task
- [ ] 117.1 Unione: impostazioni, temi con immagine, copertine automatiche, playlist senza doppioni (R-211, R-212, R-214, R-216 per playlist e temi). **Area a rischio (backup): `/code-review high`**
  - File: `lib/services/backup/backup_service.dart`, `restore_service.dart`, `user_data.dart`, `lib/data/repositories/backup_merge.dart`, `lib/data/settings/custom_theme.dart` (solo se serve per l'unione dei temi), test in `test/services/backup/` e `test/data/backup_merge_test.dart`
  - Passi: 1) `theme/*` nel backup, ripristino dell'immagine e riscrittura di `imagePath` (completo e unione); 2) `mergeBackup` legge `settings.json`, fonde `customThemes`, applica dopo il DB; rivedere `kDeviceBoundKeys`; 3) copertine con `coverSource` 0 e `.webp`; 4) playlist rinominata riconosciuta alla seconda unione; 5) un test «due volte» che copre tutto ciò che il task tocca
  - Comando mirato: `flutter test test/services/backup/ test/data/backup_merge_test.dart`
  - Fatto quando: i criteri di R-211, R-212, R-214 verdi, e R-216 per playlist, temi, radio e artisti
- [ ] 117.2 Unione: ascolti, tag, playlist smart, podcast dal sqlite del backup (R-213, R-215, R-216 per queste tabelle). **Area a rischio (backup): `/code-review high`**
  - File: nuovo `lib/services/backup/backup_db_reader.dart` (sola lettura, colonne esistenti), `restore_service.dart`, `backup_merge.dart` (o `backup_queries.dart`), `MergeReport` (+ ascolti non collegati), testo del resoconto nell'ARB (6 lingue)
  - Passi: 1) estrarre `codecore.sqlite` in una cartella temporanea e aprirlo in sola lettura; 2) mappa id del backup → id locale con `TrackResolver`; 3) inserimento senza doppioni nella stessa transazione di `mergeUserData`; 4) test con un DB di backup costruito nel test (anche con uno schema senza colonne recenti) e con l'unione ripetuta due volte
  - Comando mirato: `flutter test test/services/backup/ test/data/backup_merge_test.dart`
  - Fatto quando: i criteri di R-213, R-215 e R-216 verdi; prova sul Mi A3: backup fatto lì, poi spostata la cartella della musica (percorsi diversi), «Unisci» due volte, e statistiche, tag, playlist smart, podcast e tema con immagine presenti una volta sola

## Tocca a te
- Niente in questa fase: la prova vera sul Motorola si fa dopo la 1.6.0 (fase 118).

## Note di deviazione
