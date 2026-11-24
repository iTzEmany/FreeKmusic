# Rete di sicurezza della grande revisione (giro 4, 22/11, test-strategist)

**Regola**: i test di caratterizzazione si scrivono e si committano verdi PRIMA di toccare il codice (primo task di ogni fase a rischio). Se un test cambia di proposito per una decisione (es. D-679), si aggiorna nello stesso commit del cambio e il commit cita la decisione.
**Schema DB**: oggi v20 (`app_database.dart:12`). Migrazioni previste: v21 strumentale (136), v22 browseId dell'album (140), v23 preferiti di album e playlist (141), v24 tombstone (146), ciascuna in un solo passo con un test in `test/data/migration_test.dart`.

| Fase | Caratterizzazione prima (file da estendere) | Test nuovi (uno per comportamento) | Golden | Metrica di arrivo |
|---|---|---|---|---|
| 135 | `services/audio/codecore_audio_handler_test.dart` (errore → successivo, azzeramento del contatore), `playback_persistence_test.dart` (restore senza play), `providers/karaoke_auto_test.dart` | permesso negato → coda ferma e un avviso; limite = 3; restore a freddo senza salto né popup; errori di fila in un messaggio; niente separazione prima del play; `karaokeOn` senza debounce (`data/settings_store_test.dart`); `_fileWanted` salta lo stream e `_fileBlock` viene prima di `fileIds` (`services/library/track_corrections_test.dart`) | no (banner: test di widget) | coda illeggibile: ≤ 3 tentativi, 1 popup |
| 136 | `services/online/enrich_engine_test.dart`, `enrich_status_characterization_test.dart`, `services/stream/stream_enrich_row_provider_test.dart` | `musicbrainz_client_queue_test.dart` nuovo (coda, cooldown 1-5-15 con clock finto, cache dei «non trovato»); 503 = limited; il finder dei paesi rispetta il cooldown; ISRC riusato; riga stream via `completeOne` senza sovrascrivere titolo e artista; completer con l'impostazione per la rete a consumo e la Jam; flag strumentale (lrclib e titolo) e salto di testi e karaoke; migrazione v21 | no | client finto: ≤ 1 richiesta MB per ISRC; secondo `completeOne` = 0 richieste; dopo un 503, 0 richieste fino a fine pausa |
| 137 | `services/backup/restore_service_test.dart`, `data/backup_merge_test.dart`, `backup_service_test.dart` (le playlist ci sono) | il merge elenca i brani non trovati; riavvio chiamato dopo «Sostituisci»; tocco ovunque sul popup apre il dialogo; `lastUpdateCheckDay` solo se il controllo riesce | no | N non trovati → lista di N |
| 138 | (UI) `ui/a11y_guidelines_test.dart` e `accessibility_characterization_test.dart` verdi | `showCcSheet` a tutta larghezza (un test per tutti i fogli); campi di ricerca senza autofocus; due pulsanti Tutto/Nessuno; «Come risolvere» diverso dal tocco sulla riga | sì: all_tracks, home, fogli, anteprima del tema | `grep "color: cc.bg"` nella testata di Tutti i brani = 0 |
| 139 | `ui/track_actions_test.dart`, `services/online/download_index_test.dart`, `providers/download_promotion_test.dart` | stato del brano a tabella (online/salvato/scaricato); il menu si aggiorna a download finito; scaricare = salvare (D-695); `DownloadBar` avanzamento → «Scaricato»; riga ombra senza azioni in conflitto | sì: track_actions, now_playing | `grep -rn downloadsProvider lib/ui` diminuisce (un solo widget) |
| 140 | `providers/play_online_test.dart`, `services/stream/stream_promoter_test.dart`, `data/library_queries_test.dart` + `stream_rows_hidden_test.dart`, `ui/folders_onboarding_characterization_test.dart` | modalità stream predefinita per tutti e `lite` = device; cartella dei download fissa; «scarica anche»; browseId salvato e brani mancanti dell'album; Jam: l'ospite salva online e locale dalla cache; migrazione v22; brani stream in LAN, export e Android Auto (D-674) | sì: album, onboarding | migrazione su un DB con brani locali: 0 righe modificate |
| 141 | `ui/collection_header_test.dart`, `collection_pages_test.dart`, `alpha_scroller_test.dart` (+offset), `data/backup_merge_tables_test.dart` | semantica delle icone per collezione; scorrimento per posizione sopra 100 elementi e assente sotto, con allargamento al tocco (D-694); preferiti di collezioni; andata e ritorno nel backup; migrazione v23 | sì: album, genere, artista, playlist | le 8 pagine con una sola testata |
| 142 | `data/resume_rows_test.dart`, `ui/home_screen_test.dart` | query «ultimo per macroarea»; `PlayContextKind.daylist` in coda con serializzazione stabile; la daylist suona col suo contesto; nuove uscite in un blocco proprio | sì: home | 2 colonne sul telefono e 3 su desktop (test sulla larghezza) |
| 143 | `ui/activity_log_screen_test.dart`, `core/issue_report_test.dart`, `goldens/activity_golden_test.dart` | Ferma/Annulla tutto (nascosti se non ci sono importazioni); «Segnala» precompilato dal Registro; ripiego «Copia testo» con client finto (il Worker fuori da `flutter test`) | sì: activity | invii solo da un tasto (grep) |
| 144 | `providers/translation_models_test.dart`, `ui/chinese_dictionary_tile_test.dart` | elenco con dimensioni e totale; scarica ed elimina i selezionati (servizi finti) | no | 20 lingue + CEDICT + Spleeter |
| 145 | (LAN in `services/share/` resta) | andata e ritorno del frammento `#`; playlist lunga → m3u8; testo con link YouTube Music | no | link per N brani sotto il limite scelto |
| 146 | `data/playlist_sync_repository_test.dart`, `services/share/playlist_sync_test.dart`, `sync_transport_test.dart`, merge del backup | simulazione a due DB: tombstone fra i «miei»; nessun tombstone verso dispositivi non miei; nessun file cancellato; convergenza di playlist, preferiti, salvati e impostazioni; migrazione v24 | no | stessi insiemi sui due DB, 0 file cancellati |

**147 — prove sul Motorola** (`scripts/telefono.py`, esito da «Esporta log»):
- L1/L2: permesso tolto → un avviso, banner e coda ferma; permesso ridato → i brani locali e la daylist suonano.
- L3: riavvio con coda illeggibile → 0 popup.
- L4: karaoke ancora acceso dopo il riavvio, nessuna separazione prima del play, promemoria dopo 20 minuti.
- L5: correzione di una riga stream senza `unsupported`.
- L6: un giorno di log con pochi 503 e nessun riarricchimento.
- Ripristino «Sostituisci» con processo nuovo; tocco sul popup della nuova versione.
- Aggiunte in streaming con i file locali intatti; barra di download; condivisione su WhatsApp; TalkBack con uiautomator.
- Volume a 0, pulizia finale.

**Comportamento invariato**: stessi dati in uscita per gli stessi dati in ingresso, salvo le deroghe D-662..D-698. Chiavi salvate e formato del backup stabili. Nessun file locale cancellato o spostato. Migrazioni senza perdita di righe.
**Da evitare**:
- test che verificano solo i mock (es. che il canale `restart` sia chiamato, senza effetto);
- un test per ciascuno dei 26 fogli;
- test di stringhe ARB, getter e collegamenti;
- test dal vivo sulla rete.
