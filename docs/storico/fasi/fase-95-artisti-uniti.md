# Fase 95 — Artisti con due profili uniti (refactor «superfici-e-ricerca»)

**Obiettivo:** due profili YouTube Music dello stesso artista si uniscono in una sola pagina, a mano o su rilevamento automatico, e si possono separare.

**Prerequisiti:** fase 94 chiusa. Mockup `refactor/superfici-e-ricerca/mockup/artista-unione.html`. Decisioni D-397, D-402, D-414. Rilievi F-89, F-90. Aree a rischio: schema drift e backup (`restore_service.dart`, `backup_merge.dart`).

**Comando mirato:** `flutter test test/ui/artist_page_test.dart test/ui/artist_screen_test.dart test/ui/artist_picker_sheet_test.dart test/ui/follow_button_test.dart test/data/follow_repository_test.dart test/data/backup_merge_test.dart test/services/backup/restore_service_test.dart test/services/online/ytm_artist_resolver_test.dart test/services/online/ytm_artist_parser_test.dart` più i test nuovi.

## Task

### 95.1 — Tabella degli alias (F-89, D-402)
- `artist_aliases` (profilo ytmId → profilo principale ytmId) e `artist_not_same` (coppie «Sono diversi», D-414) in `lib/data/db/tables.dart`; migrazione + `dart run build_runner build --delete-conflicting-outputs`; repository con unisci/separa (nessuna catena: l'alias punta sempre al principale).
- Entrambe le tabelle in backup e `backup_merge`, con test di ripristino; backup vecchi (fixture della 87) ripristinabili con tabelle vuote (D-397).
- Test: unisci, separa, catena A→B poi B→C risolta a C, ripristino da backup.

### 95.2 — Pagina unita (D-402, D-414)
- La pagina artista carica gli album di tutti i profili del gruppo e toglie i doppioni per titolo normalizzato + anno; nota «N profili uniti»; «Separa profili» nel menu. Caricamento fuori dal thread UI, richieste dentro il budget.
- Seguire/escludere (`FollowedArtists`, `lib/data/db/tables.dart:337-359`) vale per il gruppo: seguire il principale basta, escludere si applica a tutti i profili.
- Test: due profili con un album in comune → un solo album; seguito il principale → il secondo risulta seguito; separa → due pagine.

### 95.3 — «Unisci con…»
- Voce del menu che apre `lib/ui/screens/online/artist_picker_sheet.dart` e propone in cima il profilo probabile (stesso nome normalizzato). Test: proposta in cima; scelta di un profilo qualsiasi; annulla non cambia nulla.

### 95.4 — Rilevamento (F-90, D-402, D-414)
- In `lib/services/online/ytm_artist_resolver.dart:35-45` e dopo `searchArtists`: due profili con lo stesso nome normalizzato e senza alias → avviso nella pagina «Sembra lo stesso artista…: Unisci / Sono diversi». «Sono diversi» è salvato e non si ripropone mai.
- Test: avviso con due profili omonimi; nessun avviso con alias esistente o coppia «diversi»; nomi diversi → nessun avviso. Prova reale con Marco Castello e Luca Carocci (due profili ciascuno): unione, album senza doppioni, separazione.

### 95.5 — Controlli di fase
`flutter analyze`; comando mirato; golden della pagina artista rigenerati (`scripts/shots.sh`); review del diff (code-review high su migrazione e backup); scheggia. Motorola edge 40 (ZY22HKD85K) e Mi A3 (0d7ae9df206e) via adb: i due casi reali, seguire il gruppo, backup → ripristino.

**Fatto quando:** i controlli sopra sono fatti e scritti qui.

## Esiti
- **95.1**: schema v17 in un solo passo, `artist_aliases` (alias → principale, senza catene) e `artist_not_same` (coppia ordinata per byte UTF-8, `CHECK (a < b)`). `ArtistAliasRepository`: merge, split, dissolve, separate/rejoin, coppie «diversi». Backup e merge: nel merge vince la scelta locale (coppie «diversi» e gruppi locali non toccati), `createdAt` conservato, voci malformate scartate; backup vecchi → tabelle vuote.
- **95.2**: pagina unita con gli album di tutti i profili, doppioni (titolo normalizzato + anno, anche fra scaffali diversi) tolti, dal più recente; nota «N profili uniti»; «Separa profili» nel menu (foglio d'azioni di casa). Seguire vale per il gruppo; gli alias non diventano righe di `followed_artists`: il controllo delle nuove uscite scarica tutto il gruppo e salva sul principale; un alias appena unito non fa comparire la sua discografia come nuova. «Vedi tutto» apre solo la discografia del principale.
- **95.3**: «Unisci con…» con campo di ricerca (budget condiviso con Cerca), il profilo omonimo in cima, errori veri (offline, limite).
- **95.4**: avviso «Sembra lo stesso artista…: Unisci / Sono diversi»; una coppia «diversi» con qualsiasi membro dei due gruppi esclude la proposta; alias applicati in un solo punto (`pickYtmArtistWithAliases`, anche nell'auto-follow); un alias si apre sul principale.
- **95.6** (richiesta dell'utente, D-427): la nota «N profili uniti» apre i profili del gruppo con «Separa» per profilo e Annulla; pagina «Artisti uniti» (Impostazioni → Online → Nuove uscite) con i gruppi («Separa», «Separa tutto») e le coppie «Segnati come diversi» con «Rimuovi».
- **Code review high**: 3 giri (migrazione e backup 8 rilievi; pagina, rilevamento e seguiti 10 rilievi): tutti applicati.
- **Scheggia**: 600 operazioni casuali senza violare le invarianti; bug corretti: alias materializzati fra i seguiti (doppioni, churn dell'auto-follow), ordine UTF-8 contro il CHECK di SQLite, titoli di soli simboli, ordine dopo uno split; 7 mutanti sopravvissuti coperti.
- **Mi A3** (app vera, `install -r`): migrazione v16→v17 senza perdite (255 brani, 4 playlist, 14 seguiti). Marco Castello e Luca Carocci: avviso, Unisci («2 profili uniti», album senza doppioni), Separa, «Sono diversi» che non torna, «Unisci con…»; seguire il principale unito e smettere. Stato riportato com'era; restano due coppie «diversi» (Castello, Carocci), che ora si tolgono da «Artisti uniti».
- **Differenze dal mockup**: la nota non dice quanti doppioni sono stati tolti; l'avviso indica nome e iscritti invece del numero di album (un album in più costerebbe una richiesta); «Unisci con…» unisce con un tocco, senza scelta preselezionata.
- **Motorola**: rinviato alla fase 97 (D-419, D-420).
