# Identità visiva «Anello», fase 2: le schermate interne — design

Data: 2026-10-22. Stato: approvato dall'utente il 22/10, con una modifica (filtri della Libreria come blocchi con icona).
Bozza visiva: `docs/superpowers/specs/2026-10-22-identita-anello-fase-2.html` (si apre nel browser, nessuna
rete tranne i due caratteri).
Parte da: `2026-10-22-identita-anello-design.md` (prima tornata) e dalle regole di
`.superpowers/sdd/2026-10-22-identita-anello/design-notes.md`, che valgono anche qui.

## Perché

La prima tornata ha dato all'app un carattere nella barra in basso, nel lettore e nella Home. Appena si
apre un album, una playlist, la Libreria o Cerca, però, si torna nella «brutta copia» di Spotify:

- sfondo tinto dietro una copertina grande al centro;
- il cerchio «play» d'accento a destra;
- righe di chip per filtrare;
- tessere colorate dei generi;
- scaffali orizzontali di copertine.

L'utente ha visto le bozze e ha chiesto di pianificare le fasi successive. La richiesta resta la stessa:
«semplice, non troppo stilizzato, e soprattutto funzionale», con un «carattere libertino, casual ma
anche elegante nelle microanimazioni».

Il carattere delle schermate interne non viene da segni nuovi. Viene da tre abitudini ripetute ovunque:

- **Allineato a sinistra.** Titolo, copertina e pulsanti partono dallo stesso margine, come in Home.
- **Pulsanti con le parole.** «Riproduci» e «Casuale» sono pillole con l'etichetta, non icone da
  indovinare.
- **Conteggi naturali.** «12 brani, 48 minuti», mai «Album · 2004 · 12 brani».

L'anello e il pallino restano rari.

## Inventario: cosa resta fuori dalla prima tornata

| Schermata | Com'è oggi | Quanto sa di Spotify |
|---|---|---|
| Dettaglio album, playlist, Preferiti, playlist intelligenti (`CollectionScaffold`) | Sfondo tinto, copertina grande al centro, titolo che entra nella barra, cerchio «play» a destra con l'icona casuale accanto | Molto |
| Artista locale (`artist_screen`) | Come sopra, con l'avatar tondo, «Più ascoltati» e una griglia di album | Molto |
| Artista online (`artist_page_screen`) | Foto tonda al centro, ascoltatori mensili, «Segui», scaffali orizzontali di uscite e artisti simili | Molto |
| Libreria | Titolo, due righe di chip (tipo e ordine), pulsante griglia, nove righe fisse in cima | Molto (è «La tua libreria») |
| Cerca, corpo della pagina | Tessere colorate dei generi, scheda «Risultato principale», scaffali di artisti e album | Molto |
| Radio | Campo di ricerca, sei sezioni, chip di paese e regione | Medio |
| Nuove uscite, Da revisionare | Barra in alto, chip orizzontali, `ListTile` | Medio |
| Podcast (elenco e dettaglio) | `ListTile` ed episodi con lo stato | Poco, Material generico |
| Impostazioni | Una sola pagina lunga, 13 gruppi in schede `surface1` | Poco, Material generico |
| Memoria | Titolo, 3 schede, 5 sezioni, righe con barra della quota | Poco |
| Foglio azioni del brano, altri 23 fogli, 39 finestre | `ListTile` separati da linee, intestazione «artista · album» | Poco, Material generico |
| Stati vuoti ed errori | Icona da 56 px, frase, uno o due pulsanti al centro | Poco, ma rumorosi |
| Jam, Cronologia, Statistiche, Tag, Artisti seguiti, Playlist, Pulizia, Condividi, Coda | Barre in alto, `ListTile`, schede, chip | Poco |
| Modalità auto, Testi, Equalizzatore, Editor del tema, Onboarding, Import | Schermate dedicate | Poco (restano fuori, vedi Non obiettivi) |

Errore di testo trovato ovunque: le stringhe «A · B».

- Nella riga meta degli album: `'${l.kindAlbum} · $meta'`.
- Nel sottotitolo delle righe: `parts.join(' · ')` in `track_row.dart`.
- Nell'intestazione del foglio azioni.

## Obiettivi

1. **Un'intestazione sola per tutte le raccolte.** `CollectionScaffold` perde lo sfondo tinto e la
   copertina al centro.
   - Telefono: copertina da 128 a sinistra, con accanto il nome in `headlineSmall` (Unbounded 24, fino a 3
     righe), il sottotitolo (artista o autore) e una riga meta in parole: «2004, 12 brani, 48 minuti».
     La parola «Album» sparisce: chi l'ha aperto lo sa.
   - Sotto, sullo stesso margine: pillola piena «Riproduci», pillola contornata «Casuale», poi il menu «⋯».
   - Il nome entra nella barra in alto scorrendo, come oggi.
   - Con il testo grande, o sotto i 360 dp, la copertina va sopra il nome, sempre a sinistra.
   - Desktop: copertina da 200 a sinistra, il resto accanto, nome in `displaySmall` (Unbounded 30).
   - Raccolta vuota: «Riproduci» e «Casuale» non si vedono, al loro posto c'è lo stato vuoto.
2. **Righe dei brani senza «·».** Sottotitolo con il solo artista. Nelle righe d'album l'artista compare
   solo se è diverso da quello dell'album, come oggi. L'album resta nella colonna su desktop e nel foglio
   azioni.
3. **Il brano in ascolto ha il pallino.** Nella riga del brano che suona:
   - il titolo è d'accento;
   - al posto del numero, o sopra l'angolo della copertina, c'è il pallino del logo, fermo.
   - Le barrette animate di `NowPlayingBars` spariscono: sono un'animazione a riposo, e l'unica ammessa
     è la rotazione della copertina.
4. **Libreria in una riga.** Un selettore a blocchi unico («Tutto, Playlist, Album, Artisti») al posto
   delle due righe di chip. *Richiesta dell'utente:* i blocchi sono simmetrici (stessa larghezza),
   arrotondati, e ognuno ha un'icona che lo rappresenta sopra il nome.
   - Sotto c'è una riga di testo: a sinistra il conteggio («148 album»), a destra l'ordine attuale
     («Recenti») che apre la scelta, e il pulsante elenco/griglia.
   - Le nove righe fisse diventano scorciatoie compatte con il conteggio, le stesse della Home, e si
     vedono solo in «Tutto».
   - Con l'ordine A–Z, le lettere fanno da intestazione.
5. **Cerca senza tessere né scaffali.**
   - A campo vuoto: le ricerche recenti, poi i generi come pillole di testo che vanno a capo.
   - Risultati: «Brani» (5 righe e «Tutti»), poi «Artisti», «Album» e «Playlist» (3 righe ciascuno e
     «Tutti»).
   - Niente «Risultato principale», niente caroselli.
6. **Artista come un album.** Stessa intestazione dell'obiettivo 1, con la foto tonda: il tondo
   dell'avatar non è l'anello e non ha varco.
   - Online: «1,2 milioni di ascoltatori al mese» nella riga meta, «Segui» come pillola contornata accanto
     a «Casuale».
   - Sezioni: «Più ascoltati» (5 righe), «Album» e «Singoli» (righe con copertina 56, anno e numero di
     brani), «Artisti simili» (3 righe con avatar), «Informazioni» (4 righe di testo e «Altro»).
   - Nessuno scaffale orizzontale.
7. **Impostazioni in un indice.**
   - Telefono: un elenco di 7 voci, e ogni voce apre la sua pagina. Sotto il nome di ogni voce c'è il
     valore attuale più utile («Notte, viola, italiano»).
   - Desktop: indice a sinistra, pagina a destra.
   - Le opzioni restano tutte quelle di oggi, nello stesso ordine dentro ogni pagina.
8. **Fogli più leggeri.** Il foglio azioni del brano ha:
   - un'intestazione con titolo, poi l'artista, poi l'album, su tre righe;
   - righe senza linee divisorie, con i gruppi separati da 8 dp di spazio;
   - le azioni che cancellano in fondo, nel colore `error`.

   Gli altri fogli seguono la stessa forma.
9. **Stati vuoti quieti.** Una frase, una riga di aiuto, al massimo un pulsante pieno, allineati a
   sinistra in cima allo spazio libero. Niente icona grande. Gli errori hanno la stessa forma con
   «Riprova».
10. **Intestazioni di sezione uguali ovunque.** `SectionHeader` com'è (`titleMedium`), con l'azione che
    si chiama sempre «Tutti» (oggi ci sono anche «Vedi tutti» e «Mostra tutti»). Una sezione vuota
    sparisce.
11. **Movimento coerente**, con i valori di `Motion` che ci sono già:
    - pressione `PressScale` 0,97;
    - righe che entrano con `EnterOnce` (dissolvenza e 8 px, sfalsate di 20 ms per le prime 12);
    - il riempimento del blocco attivo scorre al nuovo blocco in 180 ms (`easeOutCubic`, senza
      rimbalzo), e il contenuto cambia con `TabFade`;
    - foglio 250 ms; il cuore batte come oggi.

    Nient'altro si muove.

## Non obiettivi

- Nessun font, pacchetto o colore nuovo. Solo `CcColors`, `CcDims`, `Motion`/`CcMotion` e i caratteri
  di oggi.
- Nessuna funzione nuova e nessuna tolta. Cambiano solo l'impaginazione e le parole.
- Lettore, mini‑player, barra in basso, Home e barra laterale restano quelli della prima tornata.
- Modalità auto, Testi, Equalizzatore, Editor del tema, Onboarding e flusso di Import restano come sono.
  Prendono gratis le righe, i fogli e gli stati vuoti nuovi, se li usano.
- Le finestre di dialogo cambiano solo nei testi (via «·» e «→»). La forma (`surface1`, raggio 16) va
  già bene.
- Il menu col tasto destro su desktop resta un `showMenu` con i suoi divisori: su desktop è la forma
  che ci si aspetta.

## Anti‑obiettivi (sarebbe un fallimento anche se funziona)

- Mettere l'anello o il pallino su pulsanti, segmenti, voci di menu o intestazioni «per coerenza».
- Ricreare gli scaffali orizzontali di card uguali in un'altra forma (griglie a scorrimento laterale,
  caroselli).
- Pulsanti di sola icona dove oggi si deve indovinare (il cerchio «play» e l'icona casuale isolata).
- Tinte, sfumature, ombre, bagliori o bordi nuovi per «dare carattere».
- Etichette in MAIUSCOLO, sopratitoli, numeri di sezione, «A · B», «→».
- Qualcosa che si muove da solo, a parte la copertina nel lettore.

## Vincoli

- Temi: ogni schermata va provata in Notte, OLED e Chiaro, con almeno l'accento viola, uno chiaro
  (ambra o verde) e uno scuro sul Chiaro (rosa o rosso).
  - Il blocco attivo è `text` su `bg` (riempimento `text`, icona e scritta `bg`), non d'accento. Così
    funziona con tutti gli 8 accenti e non compete con «Riproduci». I blocchi spenti sono `surface1` con
    icona `textMuted` e scritta `text`.
- Testo al 150%:
  - l'intestazione delle raccolte va in colonna quando `larghezza / textScale < 300`;
  - i blocchi passano a una griglia 2×2 quando non entrano in una riga, invece di uscire dallo schermo;
  - le righe dei brani usano già l'altezza scalata (`trackRowExtent`).
- «Riduci animazioni»: con `ccDuration` a zero il blocco attivo salta senza scorrere, le righe compaiono
  senza salire e i fogli si aprono senza animazione.
- Desktop sopra 840 px:
  - le pagine interne hanno larghezza massima 960 (le Impostazioni 760 per la colonna di destra);
  - le righe dei brani tengono la colonna album e il passaggio del mouse;
  - l'indice delle Impostazioni segna la voce attiva con `surface2` e il testo in grassetto, senza
    pallino.
- Accessibilità:
  - ogni blocco è `Semantics(button, selected)` con il nome come etichetta (l'icona è decorativa);
  - il pallino del brano in ascolto non è l'unico segnale: la riga dice «In riproduzione» come oggi;
  - focus da tastiera visibile su pillole, blocchi e voci dell'indice.
- Prestazioni sul Mi A3: niente `BackdropFilter` e niente ombre. Togliere lo sfondo tinto alleggerisce
  il dettaglio. Le liste restano `SliverList` costruite al volo.
- Testi nuovi in tutti gli ARB (it, en, de, es, fr, pt), un solo agente alla volta. Le stringhe nuove
  sono poche: «Riproduci», «Casuale», «Tutto», le 7 voci dell'indice e le frasi degli stati vuoti.
- Golden: si rigenerano quelli che toccano le schermate cambiate, senza aggiungerne altri.

## Decisioni per schermata

### Intestazione delle raccolte (`CollectionScaffold`, `collection_header.dart`)

- Via `CoverBackdrop` da qui. Resta nel lettore, nella modalità auto e nei Testi.
- Copertina: raggio `rCard` 12 (album, playlist) o tonda (artista). Telefono 128, desktop 200.
- Testi:
  - nome in `headlineSmall` (Unbounded 24/600), al massimo 3 righe con ellissi;
  - sottotitolo in `bodyLarge` `textMuted`, toccabile se porta all'artista;
  - meta in `bodyMedium`.
- Azioni:
  - `FilledButton.icon` «Riproduci»;
  - `OutlinedButton.icon` «Casuale», che resta il `ShuffleModeButton` a tre stati (spento, casuale,
    Shuffle+) con il «+» e la pressione lunga di oggi; acceso, icona e testo sono d'accento;
  - poi `IconButton` «⋯» con il menu di oggi. Seguire, YouTube Music e scarica vanno nel menu o restano
    icone accanto a «⋯»: al massimo due icone.
- `PlayCircleButton` resta solo dove non c'è spazio per una parola (pagina del tag su desktop stretto,
  se serve). Altrimenti si toglie.
- `DiscHeader` resta («Disco 2», `labelLarge` `textMuted`).

### Righe dei brani (`track_row.dart`)

- Sottotitolo: solo l'artista (variante standard). La variante album resta com'è senza «·». Sulla
  pagina di un artista il sottotitolo è l'album, perché l'artista sarebbe ripetuto. *Scelta mia.*
- Brano in ascolto:
  - titolo `accent`;
  - nella variante album, il numero diventa il pallino (diametro 8, d'accento);
  - nella variante standard, il pallino sta sull'angolo in alto a destra della copertina, come il
    pallino delle schede sull'icona.

  È fermo. Con «Riduci animazioni» non cambia nulla.
- Altezze, cuore, durata, colonna album su desktop, selezione e trascinamento restano come oggi.

### Libreria (`library_screen.dart`)

- In alto: «Libreria» (`headlineSmall`), poi Attività, Cerca, «+» e «⋯» come oggi.
- Blocchi «Tutto, Playlist, Album, Artisti», uno per voce, tutti della stessa larghezza (`Expanded`).
  - Forma: raggio 16, altezza circa 64, icona da 22 sopra il nome in `labelLarge`.
  - Icone: Tutto `Icons.apps_rounded`, Playlist `Icons.queue_music_rounded`, Album `Icons.album_rounded`,
    Artisti `Icons.person_rounded`.
  - «Tutto» è la vista mista di oggi, quando nessun chip è acceso.
  - Se a testo grande non entrano in una riga, diventano una griglia 2×2. Mai a scorrimento.
- Riga conteggio e ordine:
  - a sinistra «148 album», «2.041 elementi» e simili, in `bodyMedium`;
  - a destra un `TextButton` con l'ordine attuale, che apre un piccolo menu «Recenti, A–Z, Aggiunti di
    recente», e l'icona elenco/griglia.
- Scorciatoie, solo in «Tutto»:
  - pillole `surface1` raggio 14 con nome e conteggio in `textMuted`, come in Home, che vanno a capo;
  - ordine: Preferiti, Tutti i brani, Cronologia, Podcast, Radio, Artisti seguiti, Tag, Statistiche,
    Da revisionare (solo se ce ne sono);
  - quelle a zero spariscono, tranne Preferiti e Tutti i brani.
- Con l'ordine A–Z, intestazione della lettera in `titleSmall` `accentSoft`. È Figtree, non Unbounded:
  Unbounded resta per i titoli grandi.
- Stati vuoti (permesso negato, nessuna cartella): forma dell'obiettivo 9, con «Aggiungi una cartella»
  come unico pulsante pieno.

### Cerca (corpo della pagina)

- Il campo resta nella barra in basso (prima tornata). In alto: «In libreria» / «Online» come blocchi a
  due voci (icone `Icons.library_music_rounded` e `Icons.public_rounded`), poi i chip Preferiti/Recenti come oggi, che sono filtri accendibili e non segmenti.
- Campo vuoto: «Cercati di recente» (righe con l'icona di ricerca e la ✕), poi «Generi» come pillole di
  testo `surface1` che vanno a capo. Niente colore calcolato dal nome. `GenreScreen` resta, con
  l'intestazione dell'obiettivo 1 senza copertina.
- Risultati: sezioni in colonna, «Tutti» apre l'elenco intero già filtrato.

### Artista (locale e online)

- Intestazione dell'obiettivo 1 con avatar tondo da 128 (desktop 200).
- Locale: «Più ascoltati» (5 righe), «Album» resta `AlbumGrid` (le copertine sono il modo giusto per
  riconoscere i propri album).
- Online: sezioni come in Obiettivi 6. `ReleaseCarousel` e `ArtistCarousel` diventano liste di righe
  (riuso di `TrackRow` dove sono brani, una riga semplice con copertina 56 per uscite e artisti).
  `ListenBar` resta in basso.

### Impostazioni (`settings_screen.dart`)

Indice di 7 voci, ognuna con il valore attuale sotto:

| Voce | Contiene i gruppi di oggi | Riga sotto (esempio) |
|---|---|---|
| Aspetto e lingua | Aspetto, Lingua | Notte, viola, italiano |
| Riproduzione | Riproduzione | Dissolvenza 3 s, normalizzazione accesa |
| Libreria | Libreria, Pulizia | 2 cartelle, 2.041 brani |
| Online e download | Online, Nuove uscite, Download, Modelli di traduzione | Download solo con Wi‑Fi |
| Rete e dispositivi | Rete locale, Dispositivi fidati | 1 dispositivo fidato |
| Backup | Backup | Ultimo backup ieri |
| Avanzate e info | Avanzate, Info | Versione 1.6 |

- Ogni pagina è l'elenco di oggi (`ListTile`, `SwitchListTile` dentro la scheda `surface1`), senza il
  titolo del gruppo quando il gruppo è uno solo.
- Desktop: indice largo 280 a sinistra, pagina a destra (larghezza massima 760). La voce attiva ha
  `surface2`.
- Le scorciatoie che oggi aprono un punto preciso delle Impostazioni aprono la pagina giusta.

### Fogli e finestre

- Foglio azioni del brano (`track_actions.dart`):
  - intestazione con `TrackArt` 56, titolo `titleSmall`, artista `bodyMedium`, album `bodySmall`
    `textFaint`;
  - gruppi di oggi separati da spazio invece che da `Divider`.
- Gli altri 23 `showModalBottomSheet`: stessa regola (niente `Divider` fra righe, titolo del foglio in
  `titleMedium` a sinistra, niente icona grande in cima).
- Finestre: solo i testi.

### Stati vuoti ed errori (`empty_state.dart`, `error_state.dart`)

- Allineati a sinistra, margine 16, a 24 dp dal contenuto sopra:
  - frase in `titleSmall`;
  - aiuto in `bodyMedium`;
  - un `FilledButton`, e un secondo solo come `TextButton`.
- Il parametro `icon` resta, ma non si disegna più. Si toglie in una pulizia successiva, se nessuno lo
  usa.
- Esempi di frase: «Nessun preferito, per ora», con l'aiuto «Tocca il cuore su un brano e lo trovi
  qui.».

### Le altre schermate

- Radio, Nuove uscite, Da revisionare, Statistiche: le righe di `ChoiceChip` a scelta unica con al
  massimo 4 voci diventano il selettore a blocchi, ognuno con la sua icona. Se le voci sono di più
  (paesi, artisti), restano chip che vanno a capo, non a scorrimento.
- Podcast, Artisti seguiti, Tag, Playlist, Cronologia, Memoria, Pulizia, Jam, Coda: prendono le
  intestazioni, i fogli e gli stati vuoti nuovi. Le stringhe con «·» si riscrivono.
- Pagina del tag: intestazione dell'obiettivo 1 senza copertina.

## Fasi (ognuna si può rilasciare da sola)

1. **Fase 2.1, Raccolte e righe** (album, playlist, Preferiti, playlist intelligenti, artista locale).
   Circa 6 task:
   - intestazione nuova in `CollectionScaffold`;
   - pillole «Riproduci» e «Casuale»;
   - meta e sottotitoli senza «·»;
   - pallino del brano in ascolto;
   - stati vuoti ed errori;
   - golden e prova sul Mi A3.
2. **Fase 2.2, Libreria.** Circa 5 task:
   - widget del selettore a blocchi con icona, riusato dopo;
   - riga conteggio e ordine;
   - scorciatoie;
   - lettere su A–Z;
   - desktop, golden e prova.
3. **Fase 2.3, Fogli.** Circa 4 task:
   - foglio azioni del brano;
   - gli altri fogli;
   - testi di finestre e menu;
   - prova.
4. **Fase 2.4, Cerca e artista online.** Circa 5 task:
   - corpo di Cerca a campo vuoto;
   - risultati senza scaffali;
   - intestazione dell'artista online;
   - sezioni in righe;
   - golden e prova.
5. **Fase 2.5, Impostazioni.** Circa 4 task:
   - indice e pagine sul telefono;
   - due colonne su desktop;
   - scorciatoie verso le pagine;
   - golden e prova.
6. **Fase 2.6, Il resto.** Circa 6 task:
   - blocchi in Radio, Nuove uscite, Da revisionare e Statistiche;
   - testi senza «·» nelle altre schermate;
   - Podcast e Memoria;
   - Jam e Coda;
   - controllo finale dei temi a testo 150%;
   - prova.

## Cosa resta al costruttore

- I nomi e la posizione dei widget nuovi. Proposta: `SegmentedBlocks` in `lib/ui/widgets/`, con l'icona obbligatoria per ogni voce; il pallino
  del brano in ascolto come `NowPlayingDot` accanto a `RingProgress`, così il disegno del pallino è uno.
- La soglia esatta per mettere l'intestazione in colonna, nei limiti dei vincoli.
- Quali righe fisse della Libreria contano qualcosa: oggi alcune non hanno un conteggio pronto. Se
  calcolarlo costa, la pillola mostra solo il nome.

## Decisioni (confermate dall'utente il 22/10)

1. **Un solo nuovo posto per il pallino: il brano in ascolto in una lista.** *Scelta mia.* Il pallino
   vuol dire «sei qui»: nella barra (la scheda), nella barra laterale (la pagina), nell'anello (il punto
   del brano). Nella lista vuol dire la stessa cosa. Si vede al massimo una volta per schermata, ed è
   fermo. In cambio spariscono le barrette animate. Nessun altro posto nuovo.
2. **Pulsanti con la parola, a sinistra.** *Scelta mia.* «Riproduci» pieno e «Casuale» contornato, al
   posto del cerchio d'accento a destra. È la differenza più visibile da Spotify, e a testo grande si
   legge meglio di un'icona.
3. **Niente sfondo tinto nelle raccolte.** *Scelta mia.* È il tratto più «Spotify» e costa sul Mi A3.
   Il colore lo porta già la copertina.
4. **«Album» sparisce dalla riga meta.** *Scelta mia.* Il tipo si capisce dal contesto e libera spazio
   per anno, brani e minuti.
5. **Libreria: si tiene «Tutto».** La bozza della prima tornata mostrava «Brani, Album, Artisti,
   Playlist». Si tiene la vista mista di oggi e «Tutti i brani» resta una scorciatoia. Confermato
   dall'utente.
6. **Lettere della Libreria in Figtree, non in Unbounded.** *Scelta mia.* La bozza della prima tornata
   le aveva in Unbounded, ma le regole riservano Unbounded ai titoli grandi.
7. **Album dell'artista locale come griglia, quelli online come righe.** *Scelta mia.* I propri album si
   riconoscono dalla copertina. Le uscite online sono spesso singoli, e in righe si vedono anno e brani.
8. **Impostazioni in 7 voci.** *Scelta mia.* I 13 gruppi di oggi stanno in una pagina sola che non
   finisce mai. Raggruppati per argomento, si arriva a ogni opzione con al massimo un tocco in più e lo
   stato si vede dall'indice. Confermato dall'utente.
9. **Blocco attivo in `text`, non in accento.** *Scelta mia.* L'accento resta per l'azione
   («Riproduci») e per lo stato acceso («Casuale» acceso, cuore). Così una schermata non ha mai due cose
   d'accento che competono.
10. **Il menu col tasto destro su desktop non cambia.** *Scelta mia.* Solo i testi.

11. **Filtri come blocchi con icona.** *Richiesta dell'utente.* Ovunque compaia il selettore (Libreria,
    Cerca, Radio, Nuove uscite, Da revisionare, Statistiche) i blocchi hanno la stessa larghezza, gli
    angoli arrotondati e un'icona sopra il nome. L'icona aiuta a riconoscere la voce, non la sostituisce.

## Risposte dell'utente (22/10)

1. **Righe dei brani:** solo l'artista nel sottotitolo. L'album resta nel foglio azioni e nella colonna
   su desktop.
2. **Impostazioni:** indice con 7 pagine.
3. **Libreria:** «Tutto, Playlist, Album, Artisti», come blocchi simmetrici con icona.
4. **Brano in ascolto nelle liste:** pallino e titolo d'accento.
5. **Cerca:** «Risultato principale» si toglie; il primo risultato è la prima riga.

La disposizione dei mockup (voci, schermate, riproduzione) è approvata così com'è.
