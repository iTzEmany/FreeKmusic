# Fase 69e — Correzioni, cover e ripasso

**Obiettivo:**
- Titolo e artista si correggono da soli quando l'identità è sicura; negli altri casi diventano proposte da accettare nella scheda o nell'elenco «Da confermare».
- Le cover si riconoscono e le curiosità parlano dell'originale.
- La libreria già arricchita si ripassa una volta, e lo stesso riconoscimento vale per i brani online.
- In chiusura si misura sul Motorola e si rimisurano i testi.

**Prerequisiti:**
- Fase 69d chiusa.
- Da leggere: `docs/feature-riconoscimento.md` (Architettura §Flussi 2 e 3, §Dati, §Invarianti; Rischi K-RB-01, K-RB-05, K-RB-06, K-RB-08).
- Decisioni: D-299, D-301…D-304, D-307, D-308, D-314, D-318, D-319, D-320.

**Intoccabili:**
- schema DB v15 e formato del backup (D-280, D-319);
- un brano `userEdited` non cambia mai titolo né artista e non ha proposte aperte (invariante 1);
- testi dell'utente e copertine a mano.

**Comando mirato:** `flutter test test/services/recognition/ test/services/online/ test/services/tags/` più i test widget della scheda del brano e del Registro (i nomi vanno presi da `test/ui/`).

## Task

### 69e.1 — Correzioni e proposte (R-169, R-170, R-171, R-185, D-318)

#### Passo: `TrackCorrections`
- `TrackEditor.save` prende `markEdited` (di serie true, come oggi).
- Nuovo `TrackCorrections.apply(track, rec, {byUser})`: segue lo stesso percorso della modifica a mano, compreso il file se la modifica a mano lo scrive, con MBID e ISRC (R-185).
- La riga del Registro tiene il valore vecchio.
- Automatica (`sure`, brano non `userEdited`, valori diversi): `byUser: false`, il brano non viene segnato.
- Accettata: `byUser: true`, il brano viene segnato.
- Scartata: `rec.prop = dismissed`, la proposta non torna.

**Fatto quando:** ci sono test per l'automatica, l'accettata, la scartata (riarricchendo non ricompare) e il brano `userEdited` (niente), con lo scrittore finto che riceve MBID e ISRC.

#### Passo: Interfaccia
- Nella scheda del brano: «Proposta: Titolo – Artista» con Accetta e Scarta.
- Nel Registro/Arricchimento: «Da confermare (N)» con «Accetta tutte» (`watchProposals`, `json_extract`; K-RB-08: un JSON malformato si salta e si logga).
- Stringhe ARB in tutte le lingue e semantica per l'accessibilità.

**Fatto quando:**
- ci sono test widget della scheda e dell'elenco, compreso «Accetta tutte», che svuota l'elenco;
- `flutter analyze` è pulito.

### 69e.2 — Cover (R-172, R-173, R-174, D-302, D-303)

#### Passo: Riconoscere la cover e trovare l'originale
- Nuovo `lib/services/recognition/cover_detector.dart`:
  - attributo «cover» della relazione performance di MusicBrainz;
  - parole nel titolo del file (cover, arrangement, piano/orchestral version, remix, «by X» con X diverso dall'artista dell'originale).
- L'originale si prende dal work di MusicBrainz (`work(id)`); altrimenti dalla ricerca testuale del titolo pulito, scegliendo il più vecchio o il più popolare.
- Il risultato va in `rec.original`.

**Fatto quando:**
- il test a tabella è verde: 10 cover di Test.zip riconosciute, 10 titoli normali no;
- i test con fonti finte coprono il work e la ricerca.

#### Passo: Curiosità ed etichetta
- Per una cover senza pagina propria, le curiosità si cercano con l'identità dell'originale; se la cover ha una pagina sua, restano le sue.
- La scheda disegna «Cover di X – Y» leggendo `rec.original` (ARB). Il testo delle curiosità salvato non cambia (D-320).

**Fatto quando:** ci sono test della scelta delle curiosità (con e senza pagina) e il test widget dell'etichetta.

### 69e.3 — Ripasso e brani online (R-176, R-186, D-301)

#### Passo: Ripasso una volta sola
- `RecogPassIds`: brani con `enrich_status <> 0`, senza `rec` aggiornato (`COALESCE(json_extract(details,'$.rec.v'),0) < kRecogVersion`), con tag dubbi o parti vuote.
- Il segnalibro sta in shared_preferences e il ripasso va in sottofondo con il runner di oggi.
- Riempie solo i buchi.

**Fatto quando:**
- un brano completo con tag affidabili non viene ripassato;
- un brano con il canale come artista viene ripassato una volta sola;
- i campi pieni restano invariati;
- il segnalibro riprende dopo il riavvio.

#### Passo: Brani online
- Gli item `yt:` (coda, streaming, Jam) usano il passo 1b quando la loro scheda si mostra.
- La cover porta le curiosità dell'originale e l'etichetta.

**Fatto quando:** un test con un item `yt:` di una cover è verde.

### 69e.4 — Chiusura della feature (R-181, R-182)
- Esegui `flutter analyze` pulito e i test mirati verdi.
- Review di architettura con Opus e `/code-review high` sul diff dell'intera feature (69c…69e).
- Fai la scheggia in modalità fase sull'app avviata:
  - accetta o scarta di fretta;
  - modifica a mano durante il ripasso;
  - ripristino di un backup (una proposta scartata può tornare una volta, D-319: va bene).
- Rifai la prova su Test.zip (come in 69d.4) con le correzioni: conta automatiche, proposte, sbagliate e cover trovate.
- **Motorola** (copia di sicurezza del DB prima, come in 69b.4, e `install -r`):
  - misura del ritmo con il riconoscimento attivo per 15 minuti;
  - `enrichMinutes` aggiornato al numero misurato (R-181);
  - controlla che non ci siano `[E]` nel log.
- **Testi** (R-182): se LRCLIB risponde, conta i testi trovati su Test.zip prima (master di 69b) e dopo; se non risponde ancora, annotalo in «Rimandati».
- Aggiorna `docs/02-architettura.md` §«Arricchimento» con il riconoscimento, poi `docs/handoff.md` e `docs/PROGRESS.md`.

**Fatto quando:**
- c'è la PR con la CI verde;
- esiti numerici di Test.zip, del Motorola e dei testi sono in questo documento.

## Esiti di 69e.4
_(da scrivere)_

## Dopo questa feature
- R-187 Invio delle impronte ad AcoustID (chiave utente nelle impostazioni, mai nel repo).
- R-188 Riconoscimento dal microfono (solo Android, da misurare prima).
- Opus nell'impronta, quando symphonia lo supporterà (D-311).
