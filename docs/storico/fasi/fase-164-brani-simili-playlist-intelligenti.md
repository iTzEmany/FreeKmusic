# Fase 164 — Brani simili nelle playlist intelligenti

## Obiettivo
La pagina di una playlist intelligente mescola ai suoi brani brani online simili che l'utente non ha, coerenti con le regole della playlist, come
già fanno le pagine genere; un interruttore per playlist (acceso di base) li toglie. Fuori: il Casuale+ della coda (invariato), ricerche di genere
o anno per candidato (nessuna richiesta di rete in più).

## Riferimenti
Refactor `../storico/refactor/playlist-aggiungi-e-casuale/analisi.md` (F-08, «Direzione», «Rete»). Decisioni D-756, D-757, D-758; D-380 (mix delle pagine genere), D-437, D-468 («Non mi piace»).
Architettura: `../architettura/riproduzione-e-coda.md` («Shuffle+ e simili»). Specifica visiva: pagina genere di oggi
(`lib/ui/screens/search/genre_screen.dart`), nessun mockup nuovo.
Codice: `genreMix`, `genreMixOf`, `interleave`, `GenreMixOff` (`lib/services/shuffle_plus/genre_mix.dart`), `genreMixProvider`
(`lib/providers/shuffle_plus_providers.dart:373`), `RadioFill.take` (`accept`, `radio_fill.dart:59`), `SuggestionPool.take`
(`suggestion_pool.dart:150`), `chooseSeeds` (`seed_resolver.dart`); regole: `RuleExpr` e nodi (`lib/services/library/rules/rule_ast.dart`),
`RuleField`; `smartTracksProvider` (`lib/providers/smart_playlist_providers.dart`), `SmartPlaylistScreen`
(`lib/ui/screens/smart/smart_playlist_screen.dart`), editor `smart_playlist_editor.dart`; `YtResult` (titolo, artisti, album, durata).

## Task
- [x] 164.1 Il risultato online rispetta le regole?
  - File: nuovo `lib/services/library/rules/rule_online.dart` (funzione pura `bool onlineMatches(RuleExpr rules, YtResult r)`), test
    `test/services/library/rule_online_test.dart`.
  - Passi: 1) artista (`RuleContains`/`RuleIn` su `artist`, `albumArtist`: confronto come la ricerca, maiuscole e accenti ignorati), album,
    durata (`RuleNumber` in secondi); 2) `RuleNot` di questi si applica; 3) campi non verificabili (genere, anno, nazionalità, etichetta, bpm) e
    di sola libreria (ascolti, aggiunto, ultimo ascolto, cartella, formato, bitrate, tag, flag) contano come rispettati, anche sotto `RuleNot`;
    4) `RuleAnd`/`RuleOr` composti di conseguenza.
  - Comando mirato: `flutter test test/services/library/`
  - Fatto quando: casi per ogni campo, esclusione, «tutte» e «una qualsiasi» con regole ignorate; test delle regole di oggi verdi.
- [x] 164.2 Mix della playlist intelligente
  - File: `genre_mix.dart` (`genreMix` riceve un `accept` opzionale passato a `RadioFill.take`; senza, invariato), `shuffle_plus_providers.dart`
    (nuovo `smartMixProvider` gemello di `genreMixProvider`: brani da `smartTracksProvider`, `accept` = `onlineMatches` sulle regole della
    playlist, stessi motivi di stop), test `genre_mix_test.dart`, `genre_mix_provider_test.dart` (o un file gemello).
  - Passi: 1) semi solo dai brani della playlist; 2) candidati scartati dal controllo della 164.1; 3) il limite della playlist conta solo i
    brani della libreria; 4) «Non mi piace» e memoria di 30 giorni come oggi (già nel pool).
  - Comando mirato: `flutter test test/services/shuffle_plus/genre_mix_test.dart test/providers/genre_mix_provider_test.dart`
  - Fatto quando: test del mix intelligente verdi; i test di caratterizzazione della pagina genere (162.1) verdi senza modifiche.
- [x] 164.3 Righe nella pagina e interruttore nell'editor
  - File: `smart_playlist_screen.dart` (righe con `interleave` e gli stessi widget, segnaposto e scritte di stop di `genre_screen.dart`; Play
    suona la lista mista come la pagina genere), `smart_playlist_editor.dart` (`SwitchListTile` «Aggiungi brani simili che non hai»),
    `settings_store.dart` (insieme `smartMixOff` di id, fuori da sync e ripristino come `playlistShuffles`, voce tolta con la playlist),
    ARB 6 lingue, test `test/ui/smart_playlists_test.dart`, `settings_store_test.dart`.
  - Passi: 1) con l'interruttore acceso le righe online compaiono come nella pagina genere; 2) spento: pagina come oggi (test della 162.1);
    3) stessi comandi di riga delle pagine genere; 4) TalkBack come le righe della pagina genere.
  - Comando mirato: `flutter test test/ui/smart_playlists_test.dart test/data/settings_store_test.dart test/services/share/settings_sync_test.dart test/services/backup/restore_service_test.dart`
  - Fatto quando: test verdi; `flutter analyze` e `flutter gen-l10n` senza diff.
- [x] 164.4 Prova dal vivo, documenti, chiusura del refactor
  - Passi: 1) Linux sotto `xvfb-run` con `FREEKMUSIC_NON_UNIQUE=1` e HOME finto (regole del profilo): foglio «Aggiungi» confrontato con
    `../storico/refactor/playlist-aggiungi-e-casuale/mockup/variante-a.html` (stati b, c, d, dialogo desktop), Casuale di una playlist dopo riavvio, playlist
    intelligente con righe suggerite; 2) Mi A3 via `~/.claude/scripts/device.sh` (volume 0, mai toccare i file musicali): stessi flussi più un
    brano da Cerca in due playlist in modalità dispositivo; 3) `../architettura/riproduzione-e-coda.md` (Casuale salvato per playlist, mix delle
    playlist intelligenti) e `../architettura/ui-e-design.md` (foglio a scelta multipla); indice per area di `../decisioni.md` con D-749..D-758; 4) cartella del refactor archiviata in `../storico/refactor/playlist-aggiungi-e-casuale/` (anche i mockup) e riga in `../decisioni.md`
    che chiude il refactor.
  - Comando mirato: il comando delle metriche in `analisi.md` («Rete», «Metriche di chiusura»)
  - Fatto quando: esito delle prove scritto qui sotto; test mirati verdi; `flutter analyze` pulito.

## Tocca a te
- [ ] Provare a mano sul tuo telefono i tre flussi dopo il rilascio.

## Note di deviazione

- **164.1** `onlineMatches` valuta a tre stati (vero, falso, ignorato): un `RuleAnd` di soli termini ignorati è ignorato; `RuleNot` di un termine ignorato resta ignorato (D-756); in un `RuleOr` un lato ignorato rende vera l'alternativa. Album o durata mancanti nel risultato sono ignorati; senza artisti si usa il canale senza « - Topic». Il testo libero (`RuleText`) si controlla su titolo, artisti e album. Dalla review: il «Non» sopra un «E» non lo rendeva ignorato quando tutti i termini lo erano (corretto).
- **164.2** `genreMix` riceve `accept` opzionale (senza, invariato); `smartMixProvider` legge le regole della playlist. Dalla review: il mix non seguiva le modifiche alle regole (ora si ricalcola) e all'apertura a freddo partiva prima dei brani (corretto).
- **164.3** Interruttore `smartMixOff` nell'editor, salvato con «Salva» (non al tocco); righe e comandi come la pagina genere. Playlist create dal foglio e poi annullate restano vuote (D-752).
- **164.4 Prove dal vivo (28/11).** Linux sotto Xvfb (HOME finto, `FREEKMUSIC_NON_UNIQUE=1`) e Redmi Note 9 Pro `8bbad1cd` al posto del Mi A3 (occupato da un'altra sessione; volume 0, solo l'app, file di prova tolti a fine prova).
  - Foglio «Aggiungi alla playlist» (Linux e Redmi): scelta multipla, filtro senza maiuscole, «Crea «testo»» (tre tocchi = una playlist, spuntata), pulsante 0/1/2/3, messaggi, «Già presente» solo se ci sono tutti i brani; ingressi: menu del brano, selezione multipla, risultato online in Cerca. Scarti dal mockup A, minori: niente sottotitolo «Nuova playlist, vuota» sotto «Crea», niente «Creane una con la riga qui sopra» nello stato vuoto, titolo «Aggiungi a playlist…».
  - Casuale di una playlist (Linux): resta dopo il riavvio, aggiunta, rimozione, riordino e ordinamento; il pulsante agisce sul player avviato con Play e con il tocco di una riga; la cancellazione toglie la voce.
  - Brano da Cerca in due playlist in modalità streaming (Redmi): in entrambe. In modalità dispositivo non provato (telefono bloccato, nessun file del PIN per lo sblocco automatico): in «Tocca a te».
  - Playlist intelligente con brani simili: con file di prova da 8 s nessun seme si risolve su YouTube Music (corrispondenza su durata) e la pagina resta senza righe né scritta; con durate vere (Linux) 3 righe «Suggerito» fra i brani. Limite già presente nella pagina genere: se non si trova nessun simile la pagina non lo dice (in `../prossimi-lavori.md`). Aggiunta una difesa: un passo iniziale che fallisce ora finisce con la scritta di stop e un `AppLog`, non in silenzio.
