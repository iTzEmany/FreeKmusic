# Secondo parere da YouTube Music in «Da revisionare» — progetto

Fase 35. Stato: **approvato dall'utente il 22/10** (risposte in fondo). Prova dal vivo sul Motorola.

## Perché

«Da revisionare» (Libreria) raccoglie i brani per cui l'arricchimento online non ha trovato
nulla o ha lasciato dei buchi: copertina, album, anno, genere, testo. Oggi l'unica via è
«Riprova», che rifà lo stesso giro (iTunes + LRCLIB) e di solito rifallisce allo stesso modo,
oppure la modifica a mano. Molti di questi brani vengono da YouTube e YouTube Music li conosce:
ha album, artista, copertina grande, anno e numero di traccia.

L'utente vuole che la sezione faccia da sola un **secondo tentativo con YouTube Music**,
come succede all'import, e che applichi il risultato **solo se YouTube Music conferma** che è
proprio quel brano. Il lavoro a mano resta per i casi davvero dubbi.

## Cosa ha deciso l'utente

- Il secondo parere parte **solo da «Da revisionare» e da «Riprova»**, mai durante l'import
  (non tocca `QuietEnricher` né `downloadEnricherProvider`).
- Si applica **solo se YouTube Music conferma** il brano; altrimenti non si scrive nulla.
- Serve per tutto ciò che manca dall'arricchimento di base: copertina, artista, album e gli
  altri dati del brano.
- Testo e curiosità **non** vengono da YouTube Music (l'utente pensa che YouTube non li abbia).
  Per questi ha chiesto alternative a Wikipedia e a LRCLIB **senza chiavi API**: vedi
  «Domande aperte».

## Com'è oggi (fatti dal codice)

- Un brano è in lista se `enrichStatus` è 1 o 2 e: nulla trovato (2), oppure niente testo,
  niente copertina, o manca album/anno/genere (`review_queries.dart`, `ReviewReason`).
- **Non esiste una soglia di confidenza di iTunes.** `ItunesClient._pickBest` prende la riga
  migliore con pochi cancelli (titolo e artista devono combaciare almeno in parte). Il
  «non passa la confidenza» dell'utente, nel codice, è: iTunes non ha trovato nulla (stato 2)
  oppure ha trovato il brano ma senza alcuni campi. Il secondo parere copre entrambi.
- L'arricchimento **riempie solo i campi vuoti**, mai sovrascrive; con `userEdited` non tocca
  titolo, artista e album. Il secondo parere segue la stessa regola.
- «Riprova» (`ReviewActions.retry`) rimette `enrichStatus = 0` e avvia `enrichJobProvider`.
  **Difetto esistente:** se il lavoro si ferma prima di arrivare a un brano (annullato,
  «rallenta», errore di rete), quel brano resta a 0 e **sparisce dalla lista** (il filtro vuole
  1 o 2). Va corretto in questa fase, perché il secondo parere allunga il lavoro e rende il
  caso più frequente.
- Nessuna colonna registra fonte, confidenza o «già provato con YouTube Music».
- YouTube Music: `InnertubeClient.searchSongs` dà `YtResult` con videoId, titolo, artisti,
  album (`album` + `albumId`), durata, miniatura. La pagina album (`YtmCatalog.album`,
  in cache) dà anno, copertina a 544 px e l'elenco tracce con numero. **Non dà il genere.**
- Il confronto «è lo stesso brano?» con durata esiste già per l'import CSV:
  `scoreCandidate(ImportRow, YtResult)` in `track_matcher.dart`, con `sureThreshold = 0.80`.

## Obiettivi

1. All'apertura di «Da revisionare», per ogni brano in lista **mai controllato** con YouTube
   Music, parte in sottofondo il secondo parere, un brano alla volta.
2. «Riprova» fa il giro di base (iTunes + LRCLIB) e poi il secondo parere sui brani che hanno
   ancora buchi, anche se erano già stati controllati.
3. Se YouTube Music conferma, si riempiono i campi vuoti: artista, album, copertina, anno,
   numero di traccia. Il brano esce dalla lista se non gli manca più nulla.
4. Un brano non sparisce mai dalla lista per un lavoro interrotto.
5. La schermata mostra che il controllo è in corso e si può fermare.

## Non obiettivi

- Niente secondo parere all'import, nei download o in «Arricchisci» dalle Impostazioni
  o dall'album.
- Niente proposta da confermare a mano: o YouTube Music conferma e si applica, o non succede
  nulla (la modifica a mano resta com'è).
- Niente sostituzione di dati già presenti, nemmeno se YouTube Music la pensa diversamente.
- Niente nuove fonti per il testo o le curiosità finché l'utente non risponde alle domande.
- Niente nuovi pacchetti.

## Anti-obiettivi (fallimento anche se funziona)

- Un brano preso per un altro: copertina o album sbagliati scritti senza dirlo. Meglio un
  buco in più che un dato falso.
- Rallentare o bloccare la schermata o il lettore (tutto fuori dal thread UI).
- Martellare YouTube fino al «rallenta» ogni volta che si apre la sezione.
- Brani che scompaiono dalla lista senza essere stati sistemati.

## Come funziona

### Quando si dice «conferma» (scelta mia)

YouTube Music conferma un brano se tutte queste condizioni valgono:

- il risultato viene dalla ricerca **brani** (`searchSongs`), non video, e ha `albumId`;
- `scoreCandidate` (quello dell'import) costruito con titolo, artista, album e durata del brano
  locale dà **≥ `sureThreshold` (0.80)**;
- la durata del brano locale è nota e differisce di **al massimo 3 s** (come LRCLIB);
- se l'artista locale manca: titolo identico dopo `matchTitleKey` e nessun altro risultato
  sopra 0.80 con un artista diverso (niente omonimi).

Si valutano tutti i risultati della ricerca brani (fino a 5), si scartano quelli sopra
20 minuti e si prende il migliore che passa; la regola sugli omonimi richiede di averli
valutati tutti. Titolo e artista per la ricerca e il confronto sono quelli del brano locale
così come sono, anche se modificati a mano (sono la verità). Senza durata locale nessuna
conferma: il brano resta com'è.

### Cosa si scrive (scelta mia)

Solo campi vuoti, con le stesse regole di `EnrichmentService.apply` (`userEdited`, `albumKey`
ricalcolata, copertina per album solo se il file non c'è):

| Campo | Da dove | Condizione in più |
|---|---|---|
| artista | primo artista del risultato | solo se vuoto |
| album | `YtResult.album` | solo se vuoto |
| copertina | pagina album, 544 px | solo se `!hasCover` |
| anno | pagina album | solo se vuoto |
| numero di traccia | pagina album, riga con lo stesso videoId (o titolo) | solo se vuoto |

Se l'album locale **c'è ed è diverso** da quello di YouTube Music (confronto con
`matchTitleKey`), si scrive solo l'artista: copertina, anno e numero verrebbero da un'altra
uscita (singolo, raccolta). Scelta mia, prudente.

Il genere YouTube Music non lo ha: vedi «Domande aperte».

Dopo la scrittura `enrichStatus` diventa 1 (anche se iTunes non aveva trovato nulla). Se
YouTube Music non conferma, lo stato resta quello lasciato dal giro di base (2 se iTunes non
ha trovato nulla). Il numero di traccia si scrive ma non conta per uscire dalla lista (la lista
non lo guarda); un brano esce solo se non ha più nessuno dei motivi di `ReviewReason`. Una riga in `AppLog` per ogni brano confermato
(campi scritti, videoId) per poter ricostruire cosa è successo.

### Quando parte

- **Apertura della sezione:** se ci sono brani in lista mai controllati, parte da solo. Una
  sola volta per brano: l'insieme degli id già controllati sta nelle impostazioni, come quello
  di «Va bene così» (scelta mia: niente migrazione del DB). Un brano entra nell'insieme solo
  quando la ricerca su YouTube Music è andata a buon fine, che abbia confermato o no; un errore
  di rete o un «rallenta» non lo segnano, così il brano si riprova alla prossima apertura.
  «Riprova» non guarda l'insieme.
- **«Riprova»:** giro di base, poi secondo parere su chi ha ancora buchi, ignorando l'insieme.
  Vale anche per i brani a cui manca solo il testo o il genere: YouTube Music viene interrogato
  di nuovo a ogni «Riprova» (è un gesto dell'utente, il carico è accettabile).
- Se un altro arricchimento è in corso: all'apertura si aspetta in silenzio; su «Riprova»
  resta il messaggio «occupato» di oggi.
- Parte solo da questi due gesti (non c'è un interruttore «online» generale). Usa lo stesso `sourceCooldownProvider` della ricerca
  intelligente (oggi l'arricchimento non lo usa): se YouTube è in raffreddamento non parte, e
  al «rallenta» lo fa scattare, così anche la ricerca rallenta. Poi si ferma e lo dice; i
  brani non controllati restano tali.
- Ritmo: un brano alla volta, con il limitatore che l'arricchimento usa già. Una ricerca e al
  massimo una pagina album per brano (cache per `albumId`).

### Il difetto di «Riprova»

Non si azzera più `enrichStatus` prima del lavoro. Il lavoro riceve un'opzione «forza» che
salta il controllo `needsEnrichment` sullo stato 2. Lo stato si scrive solo quando il brano è
stato davvero provato. Un brano non raggiunto resta com'era, in lista.

### Interfaccia

Nella schermata «Da revisionare», sotto il titolo: una riga «Controllo con YouTube Music,
3 di 12» con un pulsante per fermare, finché il lavoro gira. A fine lavoro un messaggio breve:
«Aggiornati 5 brani con YouTube Music» (brani con almeno un campo scritto; niente se zero). Testi nei 6 ARB, con le regole di
`arb_test.dart`. Il resto della schermata non cambia.

## Vincoli

- Stack attuale, nessun pacchetto nuovo; solo endpoint senza chiave.
- Niente lavoro pesante nel thread UI; nessun `catch (_) {}` muto.
- Test con `-j 1`, ARB in 6 lingue, nessun separatore « · », « • », «→».
- I test non vanno in rete: YouTube Music finto (`test/support/fake_ytm.dart`).

## Cosa resta al costruttore

- Dove vive il passo: un metodo in `EnrichmentService` con un'opzione in `enrichMany`, oppure un
  servizio accanto. Basta che lo usi solo `ReviewActions` e l'apertura della sezione.
- Come esporre l'avanzamento alla schermata (lo stato di `enrichJobProvider` o un provider suo).
- La forma esatta di `ImportRow` costruito dal brano locale.

## Risposte dell'utente (22/10)

1. **Genere: da MusicBrainz.** Solo dopo una conferma di YouTube Music, solo se il campo è
   vuoto. Registrazione trovata con la ricerca filtrata (ufficiale, album, non live, durata
   entro 3 s quando c'è). **Aggiornato dopo le misure del 22/10:** i generi della registrazione
   sono poco votati e a volte sbagliati («jazz» con 1 voto per «Viva la Vida»), quindi si usano
   solo con **≥ 2 voti**; altrimenti il genere con più voti (≥ 1) dell'artista. Il genere si
   scrive con l'iniziale maiuscola come lo mostra già la libreria. Scelta mia: niente genere
   dall'album o dall'uscita, perché MusicBrainz li vota molto meno.
2. **Testo: dalla scheda «Testo» di YouTube Music**, dopo LRCLIB e solo per brani confermati
   (stesso videoId della conferma). Solo testo semplice: va in `lyrics` come oggi va il testo
   non sincronizzato di LRCLIB, mai in `syncedLyrics`. Scelta mia: si scarta un testo che
   contiene solo la riga dei crediti («Source: LyricFind» o simili) o meno di 3 righe.
3. **Curiosità: si fa**, come parte a sé della stessa fase, dopo il secondo parere. Due
   ripieghi senza chiave in `CuriosityFinder`, solo quando Wikipedia non dà nulla:
   - **artista:** la descrizione della pagina artista di YouTube Music (`YtmArtist.description`,
     già letta), con fonte il link della pagina artista;
   - **brano:** le note del **master** su **Discogs** (`api.discogs.com/masters/{id}`, campo
     `notes`, ripulito dal BBCode), raggiunto dal collegamento `discogs` del **release-group**
     della registrazione MusicBrainz già identificata. **Aggiornato dopo le misure del 22/10:**
     il collegamento sta sul release-group, non sull'uscita; le note delle uscite parlano della
     confezione e sono inutili; quelle del master parlano dell'**album**, e la scheda lo dice. Al massimo 1 richiesta Discogs per brano; un «rallenta»
     (429) si tratta come gli altri errori della parte brano. Note sotto 80 caratteri si
     scartano.
   La scheda delle curiosità mostra già la fonte (`Curiosity.source`): il link dice da dove
   viene il testo.
