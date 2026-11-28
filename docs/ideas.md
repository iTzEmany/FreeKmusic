# Idee
Scritto da `/ideas`. Stato: proposta · scelta · scartata · in sviluppo · fatta. Gli ID non si riusano; le idee scelte proseguono con `/kickoff feature I-xx`.
Fonti: mappa delle funzioni dal codice (28/11), confronto con Namida, Symfonium, Musicolet, Poweramp, Metrolist, Spotube (ricerca web del 28/11),
verifica nel codice dei casi d'uso. Le idee più vecchie stanno in [`13-idee-future.md`](13-idee-future.md); qui solo quelle nuove.

| ID | Tipo (base/incompleta/nuova) | Titolo | Perché | Valore | Costo | Stato | Data |
|---|---|---|---|---|---|---|---|
| I-01 | incompleta | Menu completo dei risultati online | Mancano preferito, vai all'album, dettagli, condividi, che i brani locali hanno | alto | M | scelta | 2026-11-28 |
| I-02 | incompleta | Puntate podcast nel menu come i brani | Niente playlist, coda, preferiti, condividi dal menu della puntata | medio | M | scelta | 2026-11-28 |
| I-03 | incompleta | Selezione multipla delle puntate | Niente «segna tutte ascoltate» o «scarica queste» | medio | M | scelta | 2026-11-28 |
| I-04 | incompleta | Conferma o annulla sulla cancellazione del file di una puntata | Si cancella subito, senza conferma né annulla | medio | S | scelta | 2026-11-28 |
| I-05 | incompleta | Annulla dopo l'eliminazione di una playlist (anche intelligente) | Solo conferma; le regole di una intelligente si perdono | medio | M | scelta | 2026-11-28 |
| I-06 | incompleta | Rinomina ed elimina dal menu dell'elenco playlist | Oggi bisogna aprire la playlist | medio | S | scelta | 2026-11-28 |
| I-07 | incompleta | Selezione multipla più ricca sui brani in streaming | Solo scarica o togli: niente preferiti né condivisione | medio | M | scelta | 2026-11-28 |
| I-08 | incompleta | Ricerca e filtri nelle puntate | Feed lunghi senza ricerca né «non ascoltate» / «scaricate» | medio | M | scelta | 2026-11-28 |
| I-09 | nuova | «Continua qui» fra dispositivi | Pausa sul telefono, ripresa sul PC dallo stesso punto | alto | M | scelta | 2026-11-28 |
| I-10 | nuova | Offline automatico | Preferiti, daylist e recenti scaricati da soli (Wi-Fi, in carica, tetto di spazio) | alto | M | scelta | 2026-11-28 |
| I-11 | nuova | Ripresa all'aggancio di auto o cuffie | La musica riparte da dove era quando si collega il Bluetooth | alto | M | scelta | 2026-11-28 |
| I-12 | nuova | Controllo della libreria | Copertine, testi, tag mancanti e file rotti, correzione in blocco | medio | M | scelta | 2026-11-28 |
| I-13 | nuova | «Versione migliore» di un brano | Sostituisce un file di bassa qualità tenendo playlist e ascolti | medio | M | scelta | 2026-11-28 |
| I-14 | nuova | Regole intelligenti «su questo dispositivo» | «Scaricato qui», «non ancora sul telefono» | medio | S | scelta | 2026-11-28 |
| I-15 | nuova | Trasloco su un telefono nuovo via LAN | Libreria, impostazioni e download in un tocco, senza cloud | medio | M | scelta | 2026-11-28 |
| I-16 | nuova | «Un anno fa oggi» | Brani ascoltati in questo periodo negli anni passati | basso | S | scelta | 2026-11-28 |
| I-17 | base | Voto a stelle e regola «voto» nelle playlist intelligenti | Ce l'hanno Namida e Symfonium | alto | S/M | proposta | 2026-11-28 |
| I-18 | base | Cartelle escluse dalla scansione | Suonerie e audio di chat fuori dalla libreria (esclusione non trovata nel codice, da confermare) | medio | S | proposta | 2026-11-28 |
| I-19 | base | EQ parametrico con profili AutoEQ per cuffie | Estende l'equalizzatore di oggi | medio | M | proposta | 2026-11-28 |
| I-20 | base | Trasmissione a Chromecast / DLNA | TV e casse; da conciliare con le uscite della Jam | medio | L | proposta | 2026-11-28 |
| I-21 | base | Invio degli ascolti a ListenBrainz / Last.fm | Facoltativo, solo in uscita; chiede un token personale (spirito «nessun account») | medio | S/M | proposta | 2026-11-28 |
| I-22 | base | Colori del player dalla copertina | Da conciliare con lo stile approvato (D-723..D-732) | basso | S | proposta | 2026-11-28 |
| I-23 | base | Visualizzatore audio | Effetto visivo durante l'ascolto | basso | M | proposta | 2026-11-28 |

Tagliate in questa tornata (non riproporre senza un motivo nuovo): server personale Subsonic/Jellyfin (nessun server), uscita USB verso DAC
(vicino al bit-perfect escluso), timer di spegnimento e ReplayGain (esistono), statistiche unite fra dispositivi (ascolti già sincronizzati),
«messa a punto per la musica italiana» (vaga), karaoke col solo testo (testi sincronizzati già presenti), invio a dispositivo e karaoke per gli
stream, annulla di «elimina dal dispositivo» (impossibile).

## I-01 — Menu completo dei risultati online
- Oggi: `onlineResultActions` (`lib/ui/widgets/track_actions.dart:827`) ha coda, playlist, libreria, scarica, artista; `onlineTrackActions` (:112) ha anche condividi.
- Da aggiungere dove ha senso: preferito (salva e mette il cuore), vai all'album (pagina album online), dettagli, condividi.
- Insieme a I-07 (stesso tema: le azioni dei brani non locali).

## I-02 — Puntate podcast nel menu come i brani
- Oggi: il menu della puntata (`lib/ui/screens/podcast/podcast_detail_screen.dart:410-445`) ha solo «segna ascoltata» ed «elimina file»; una puntata non scaricata nel menu brano ha solo coda e dettagli.
- Da aggiungere: playlist, coda, preferiti, condividi; tasto destro sul desktop come le altre righe.

## I-03 — Selezione multipla delle puntate
- Barra di selezione come nelle liste di brani: segna ascoltate / non ascoltate, scarica, elimina file.

## I-04 — Conferma o annulla sulla cancellazione del file di una puntata
- `podcast_detail_screen.dart:439-440` cancella subito. Piccolo: un passo `/pilot` basta.

## I-05 — Annulla dopo l'eliminazione di una playlist
- `playlist_detail_screen.dart:134-146` e `smart_playlist_screen.dart:63-75`: solo conferma. Il togliere un brano ha già lo snack «Annulla»: stesso schema.
- Attenzione: le fasi 162-164 toccano le stesse schermate; partire dopo la 164.

## I-06 — Rinomina ed elimina dal menu dell'elenco playlist
- `lib/ui/screens/playlists/playlists_screen.dart:23-72` (`showPlaylistMenu`): aggiungere rinomina ed elimina (da confermare cosa offre oggi). Piccolo: `/pilot`.

## I-07 — Selezione multipla più ricca sui brani in streaming
- `lib/ui/widgets/bulk_actions.dart:190-213`: per selezioni di brani in streaming solo scarica o togli; aggiungere preferiti e condividi.

## I-08 — Ricerca e filtri nelle puntate
- `podcast_detail_screen.dart:75-96`: campo di ricerca e filtri «non ascoltate», «scaricate»; ordine nuove/vecchie.

## I-09 — «Continua qui» fra dispositivi
- Il PC (o un altro telefono) fidato nella LAN prende brano, coda e posizione dell'altro dispositivo e riparte da lì; l'altro si ferma.
- Si appoggia ai dispositivi fidati e alla sync di oggi; nessun server. Rischio: conflitti di posizione e coda con brani in streaming.

## I-10 — Offline automatico
- Un tocco, o in automatico su Wi-Fi e in carica: scarica preferiti, daylist e brani recenti mancanti, con un tetto di spazio scelto dall'utente.
- Rischio: spazio e batteria sui telefoni; mai cancellare file dell'utente.

## I-11 — Ripresa all'aggancio di auto o cuffie
- Collegando un dispositivo Bluetooth scelto (auto, cuffie) la musica riparte dall'ultima coda; staccandolo si ferma.
- Rischio: limiti di Android agli avvii in background; serve un'opzione per dispositivo.

## I-12 — Controllo della libreria
- Una pagina che conta copertine, testi e tag mancanti, file rotti o spariti, flussi salvati senza file; azioni in blocco (arricchisci, cerca copertina, nascondi).
- La scrittura dei tag sui file resta solo su richiesta (SafeTagWriter).

## I-13 — «Versione migliore» di un brano
- Per un file di bassa qualità (bitrate basso, troncato) propone un download migliore e lo sostituisce tenendo playlist, ascolti, preferito; anteprima obbligatoria prima di cancellare il vecchio.

## I-14 — Regole intelligenti «su questo dispositivo»
- Campi nuovi nel linguaggio delle regole: scaricato qui, solo in streaming, non presente su un dispositivo fidato.
- Partire dopo la fase 164 (tocca le regole delle playlist intelligenti).

## I-15 — Trasloco su un telefono nuovo via LAN
- Un tocco dal telefono vecchio: libreria, impostazioni, playlist e file passano al nuovo nella LAN, senza cloud. Si appoggia a backup e condivisione di oggi.

## I-16 — «Un anno fa oggi»
- Dalla cronologia degli ascolti: i brani di questo periodo negli anni passati, come riga della Home o lista da suonare.
